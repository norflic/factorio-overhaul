--[[
  Lot BLOCAGE-LABOS : cause d'un laboratoire arrêté (shared/ai3/labo_cause.lua), règle pure, noms d'objets INVENTÉS.
    §1 une unité couverte : pas de blocage ; §2 en route ; §3 fabricable ; §4 impayable (avec raison) ; §5 inconnu ;
    §6 ordre trié, signature stable, texte ; §7 aucun nom réel, aucun pairs décisionnel ; §8 mutants refusés.
  Usage : lua5.2 tests/labo_cause_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read("shared/ai3/labo_cause.lua")

local function load_src(src)
  local f = load(src, "=labo_cause", "t")
  if not f then return nil end
  local ok, M = pcall(f)
  if not ok then return nil end
  return M
end

local ok_n, ko_n = 0, 0
local function check(cond, msg)
  if cond then ok_n = ok_n + 1 else ko_n = ko_n + 1 print("[LABO-CAUSE] ECHEC " .. msg) end
end

-- Les 12 contrôles du banc, rejouables sur une source mutée : rend le nombre d'échecs.
local function suite(Lc)
  local fails = 0
  local function c(cond) if not cond then fails = fails + 1 end end
  local ing = { { "zeta", 1 }, { "alpha", 2 }, { "mu", 1 } }
  local feas = { zeta = true, alpha = false, mu = nil }
  local function feasible(p) return feas[p] end
  local function reason(p) return p == "alpha" and "site refuse" or nil end

  -- §1 tout couvert
  local l = Lc.diagnose({ ingredients = ing, stock = { zeta = 1, alpha = 2, mu = 5 } })
  c(#Lc.blocking(l) == 0 and Lc.signature(l) == "" and Lc.text(l) == "")
  -- exactement le seuil : need vaut pour "stock"
  l = Lc.diagnose({ ingredients = { { "p", 3 } }, stock = { p = 3 } })
  c(l[1].kind == "stock")
  l = Lc.diagnose({ ingredients = { { "p", 3 } }, stock = { p = 2 }, feasible = function() return true end })
  c(l[1].kind == "fabricable")
  -- §2 en route : stock + en cours couvrent
  l = Lc.diagnose({ ingredients = { { "p", 3 } }, stock = { p = 1 }, incoming = { p = 2 }, feasible = function() return false end })
  c(l[1].kind == "en_cours")
  l = Lc.diagnose({ ingredients = { { "p", 3 } }, stock = { p = 1 }, incoming = { p = 1 }, feasible = function() return false end })
  c(l[1].kind == "impayable")
  -- §4 impayable + raison seulement pour impayable
  l = Lc.diagnose({ ingredients = ing, stock = {}, feasible = feasible, reason = reason })
  c(l[1].pack == "alpha" and l[1].kind == "impayable" and l[1].reason == "site refuse")
  c(l[2].pack == "mu" and l[2].kind == "inconnu" and l[2].reason == nil)
  c(l[3].pack == "zeta" and l[3].kind == "fabricable" and l[3].reason == nil)
  -- §6 texte et signature
  local t = Lc.text(l)
  c(t:find("pack alpha ni en stock ni fabricable (site refuse)", 1, true) ~= nil and t:find("pack zeta fabricable, attendu (0/1)", 1, true) ~= nil)
  local s1 = Lc.signature(l)
  c(s1 == Lc.signature(Lc.diagnose({ ingredients = ing, stock = {}, feasible = feasible, reason = reason })))
  c(s1 ~= Lc.signature(Lc.diagnose({ ingredients = ing, stock = { zeta = 1 }, feasible = feasible, reason = reason })))
  -- sans fonctions : tout est "inconnu", jamais d'erreur
  l = Lc.diagnose({ ingredients = ing })
  c(#l == 3 and l[1].kind == "inconnu")
  -- la raison d'un pack fabricable n'est pas jointe ; la raison change la signature (journal au changement de raison)
  l = Lc.diagnose({ ingredients = { { "p", 1 } }, stock = {}, feasible = function() return true end, reason = function() return "r" end })
  c(l[1].reason == nil)
  local a1 = Lc.signature(Lc.diagnose({ ingredients = { { "p", 1 } }, feasible = function() return false end, reason = function() return "r1" end }))
  local a2 = Lc.signature(Lc.diagnose({ ingredients = { { "p", 1 } }, feasible = function() return false end, reason = function() return "r2" end }))
  c(a1 ~= a2)
  return fails
end

local Lc = assert(load_src(SRC), "labo_cause.lua ne se charge pas")
check(suite(Lc) == 0, "§1-§6 la suite passe sur la source")
-- la suite compte 13 contrôles ; elle ne doit pas être vide
check(select(2, SRC:gsub("function Lc%.", "")) == 4, "quatre fonctions publiques")

-- §7 anti-échelle : aucun nom d'objet, aucun pairs
local function strip(src) return (src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")) end
local code = strip(SRC)
check(not code:find("pairs%(") or not code:gsub("ipairs%(", ""):find("pairs%("), "§7 aucun pairs décisionnel")
for _, nom in ipairs({ "science%-pack", "iron", "copper", "chemical", "plastic", "petrol" }) do
  check(not code:find(nom), "§7 aucun nom d'objet : " .. nom)
end

-- §8 mutants : chacun doit casser la suite
local MUT = {
  { "have >= need", "have > need" },
  { "have + coming >= need", "have + coming > need" },
  { "ok == true then kind = \"fabricable\"", "ok ~= false then kind = \"fabricable\"" },
  { "ok == false then kind = \"impayable\"", "ok == nil then kind = \"impayable\"" },
  { "kind == \"impayable\" and input.reason", "input.reason" },
  { "if e.kind ~= \"stock\"", "if true" },
  { "return a.pack < b.pack", "return a.pack > b.pack" },
  { "e.reason or \"\"", "\"\"" },
}
local refused = 0
for i, m in ipairs(MUT) do
  local a, b = SRC:find(m[1], 1, true)
  if not a then
    check(false, "§8 mutant " .. i .. " : motif absent")
  else
    local mutated = SRC:sub(1, a - 1) .. m[2] .. SRC:sub(b + 1)
    local M = load_src(mutated)
    local killed = (M == nil) or (select(2, pcall(suite, M)) ~= 0)
    if killed then refused = refused + 1 end
    check(killed, "§8 mutant " .. i .. " NON refusé : " .. m[1])
  end
end
print(string.format("[LABO-CAUSE] mutants refusés : %d sur %d", refused, #MUT))
print(string.format("[LABO-CAUSE] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
