--[[
  Lot RECHARGE : plantage après rechargement d'une partie neuve en colonne à tapis (revue-migrations, 3/11).
  P.size (shared/team/plan.lua) lit DECLARED, table LOCALE non sauvegardée que Champ.data (script/team/champ.lua) remplit au runtime.
  Après un rechargement, avant le premier appel de Champ.data, P.size("splitter") n'avait ni BASE ni famille de niveaux : M.spec rendait nil
  et M.size levait « attempt to index local 's' (a nil value) ». Ce banc recharge plan.lua à NEUF (DECLARED vide), comme on_load, et vérifie :
  1. les emprises de toutes les pièces nommées par Champ.data, SANS aucune déclaration ;
  2. qu'elles sont identiques à celles que Champ.data déclarerait (répartiteur 2 × 1 vers le nord, tourné est/ouest) ;
  3. le défaut d'origine (mutant : source sans la règle -> plantage reproduit) et 4 mutants de la règle ;
  4. garde-fou : tout appel de P.declare_size est connu (un nouvel appel exige sa couverture au rechargement, voir 1).
  Pur, aucune API Factorio. Usage, depuis la racine du mod :   lua5.2 tests/recharge_test.lua
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local SRC = read("shared/team/plan.lua")

--- plan.lua rechargé à NEUF (DECLARED vide) depuis une source donnée ; modules.lua reste celui du dépôt (ses tables sont des données).
local function fresh(src)
  local fn, err = load(src, "=plan", "t")
  if not fn then return nil, err end
  local ok, m = pcall(fn)
  if not ok then return nil, m end
  return m
end

local function size(P, name, dir)
  local ok, w, h = pcall(P.size, name, dir)
  if not ok then return nil, w end
  return w, h
end

-- (nom, direction) -> (w, h) attendus : répartiteur 2 × 1 vers le nord et le sud, 1 × 2 vers l'est et l'ouest (prototypes vanilla : 2 × 1)
local SPLITTERS = { "splitter", "fast-splitter", "express-splitter" }
local EXPECT_DIR = { [0] = { 2, 1 }, [2] = { 1, 2 }, [4] = { 2, 1 }, [6] = { 1, 2 } }
local UNDERGROUNDS = { "underground-belt", "fast-underground-belt", "express-underground-belt" }
-- pièces que Champ.data déclare (T.DRILL_ELECTRIC, D.POLES, D.ARM, D.CHEST, sinks de T.outposts) : toutes connues de modules.lua
local OTHERS = { ["electric-mining-drill"] = 3, ["small-electric-pole"] = 1, ["medium-electric-pole"] = 1, ["inserter"] = 1,
  ["iron-chest"] = 1, ["stone-furnace"] = 2, ["transport-belt"] = 1 }

local function suite(P, label)
  local ok, bad = 0, {}
  local function c(cond, m) if cond then ok = ok + 1 else bad[#bad + 1] = m end end
  c(P ~= nil, label .. " : plan.lua chargé")
  if not P then return ok, bad end
  for _, n in ipairs(SPLITTERS) do
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local w, h = size(P, n, d)
      c(w == EXPECT_DIR[d][1] and h == EXPECT_DIR[d][2], string.format("%s : %s dir %d -> %s x %s (attendu %d x %d)", label, n, d, tostring(w), tostring(h), EXPECT_DIR[d][1], EXPECT_DIR[d][2]))
    end
    local w, h = size(P, n, nil)
    c(w == 2 and h == 1, label .. " : " .. n .. " sans direction -> 2 x 1")
  end
  for _, n in ipairs(UNDERGROUNDS) do
    for _, d in ipairs({ 0, 2 }) do
      local w, h = size(P, n, d)
      c(w == 1 and h == 1, label .. " : " .. n .. " -> 1 x 1")
    end
  end
  for n, s in pairs(OTHERS) do
    local w, h = size(P, n, 0)
    c(w == s and h == s, label .. " : " .. n .. " -> " .. s .. " x " .. s)
  end
  -- tuiles d'un répartiteur projeté (relevé d'un projet de bande après rechargement)
  local ok2, tiles = pcall(P.tiles_of, { name = "splitter", x = 10, y = 20, dir = 2 })
  c(ok2 and #tiles == 2, label .. " : tiles_of(répartiteur est) -> 2 tuiles")
  if ok2 and #tiles == 2 then
    -- 1 de large, 2 de haut : centre (10, 20) -> x0 = round(9.5) = 10 (ou 9), y0 = round(19) = 19 ; deux tuiles dans la même colonne
    c(tiles[1][1] == tiles[2][1] and tiles[1][2] ~= tiles[2][2], label .. " : les 2 tuiles d'un répartiteur est/ouest sont dans une colonne")
  end
  return ok, bad
end

---------------------------------------------------------------------------------------------------
-- 1. État neuf (aucune déclaration) : la règle livrée
---------------------------------------------------------------------------------------------------
local P0 = fresh(SRC)
local ok, bad = suite(P0, "neuf")
pass = pass + ok
for _, m in ipairs(bad) do check(false, m) end

---------------------------------------------------------------------------------------------------
-- 2. Même résultat que la déclaration de Champ.data (P.declare_size(sp.name, sp.w or 2, sp.h or 1, true))
---------------------------------------------------------------------------------------------------
local P1 = fresh(SRC)
for _, n in ipairs(SPLITTERS) do P1.declare_size(n, 2, 1, true) end
for _, n in ipairs(SPLITTERS) do
  for _, d in ipairs({ 0, 2, 4, 6 }) do
    local w0, h0 = size(P0, n, d)
    local w1, h1 = size(P1, n, d)
    check(w0 == w1 and h0 == h1, string.format("déclaré = non déclaré : %s dir %d (%s x %s contre %s x %s)", n, d, tostring(w0), tostring(h0), tostring(w1), tostring(h1)))
  end
end

---------------------------------------------------------------------------------------------------
-- 3. Mutants : le défaut d'origine est reproduit, et la règle est contrôlée
---------------------------------------------------------------------------------------------------
local RULE_START = SRC:find('  if name:find(T.LOGISTIC_TYPES.splitter, 1, true) and not M.spec(name) then', 1, true)
check(RULE_START ~= nil, "la règle du répartiteur est dans plan.lua")
local RULE_END = RULE_START and select(2, SRC:find("\n  end\n", RULE_START, true))
local function mutate(replacement)
  return SRC:sub(1, RULE_START - 1) .. replacement .. SRC:sub(RULE_END + 1)
end
if RULE_START and RULE_END then
  local function must_fail(label, src)
    local P = fresh(src)
    local _, b = suite(P, label)
    check(#b > 0, "mutant refusé : " .. label)
  end
  -- M0 : la source d'avant (sans règle) : le plantage d'origine
  local Porig = fresh(mutate(""))
  local w, err = size(Porig, "splitter", 0)
  check(w == nil and tostring(err):find("nil value", 1, true) ~= nil, "défaut d'origine reproduit : P.size(splitter) plante sans déclaration (" .. tostring(err) .. ")")
  must_fail("sans règle", mutate(""))
  must_fail("directions inversées", mutate('  if name:find(T.LOGISTIC_TYPES.splitter, 1, true) and not M.spec(name) then\n    if dir == 2 or dir == 6 then return 2, 1 end\n    return 1, 2\n  end\n'))
  must_fail("est seul tourné", mutate('  if name:find(T.LOGISTIC_TYPES.splitter, 1, true) and not M.spec(name) then\n    if dir == 2 then return 1, 2 end\n    return 2, 1\n  end\n'))
  must_fail("carré 1 x 1", mutate('  if name:find(T.LOGISTIC_TYPES.splitter, 1, true) and not M.spec(name) then return 1, 1 end\n'))
  must_fail("jamais tourné", mutate('  if name:find(T.LOGISTIC_TYPES.splitter, 1, true) and not M.spec(name) then return 2, 1 end\n'))
end

---------------------------------------------------------------------------------------------------
-- 4. Garde-fou : tous les appels de P.declare_size sont connus
---------------------------------------------------------------------------------------------------
-- Un appel dans une FONCTION lue plus tard (comme Champ.data) laisse P.size planter après rechargement tant que la pièce n'est pas
-- connue de modules.lua / EXTRA ou couverte comme ci-dessus. Ajouter un appel : l'ajouter ici ET couvrir la pièce dans la section 1.
local KNOWN_CALLS = {
  ["shared/team/plan.lua"] = 1,    -- la définition
  ["script/team/build.lua"] = 1,   -- niveau du module (mur), exécuté à chaque chargement
  ["script/team/champ.lua"] = 3,   -- dans Champ.data : répartiteur (couvert par plan.lua), souterrain, pièces de BASE
  ["script/team/quartiers.lua"] = 1, -- lot TV-ARCHI : niveau du module (tourelle du pôle, 2 × 2), exécuté à chaque chargement, comme le mur
  ["script/team/traversee.lua"] = 2, -- lot TRAVERSEE : Trav.underground déclare le souterrain choisi (1 × 1), couvert au rechargement (UNDERGROUNDS, section 1)
}
-- Lot TESTS-GIT (0.6.64) : lignes comptées par tests/depot.lua (fichiers de git ls-files, comme git grep -c ; sans git, le disque,
-- annoncé par une ligne [ENVIRONNEMENT]). Avant : sans git, la commande ne rendait RIEN et le garde-fou disait à tort « n'a plus
-- d'appel » pour les trois fichiers.
local D = require("tests.depot")
local _, found, nfiles, source = D.grep("declare_size(", { "script", "shared", "prototypes" })
if source == "disque" then D.env("garde-fou declare_size (git grep)", nfiles > 0) end
if nfiles > 0 then
  for _, path in ipairs((function() local k = {} for p in pairs(found) do k[#k + 1] = p end table.sort(k) return k end)()) do
    local n = found[path]
    check(KNOWN_CALLS[path] == n, string.format("declare_size : %s contient %d appel(s), %s attendu(s) (nouvel appel : le couvrir au rechargement)", path, n, tostring(KNOWN_CALLS[path])))
  end
  for path in pairs(KNOWN_CALLS) do check(found[path] ~= nil, "declare_size : " .. path .. " n'a plus d'appel (mettre à jour le garde-fou)") end
else
  check(false, "declare_size : aucun fichier Lua lu (source : " .. source .. ") : garde-fou non joué")
end

print(string.format("[RECHARGE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
