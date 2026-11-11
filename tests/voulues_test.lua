--[[
  Tests hors jeu du lot RECHERCHE-BRAS (A) : script/ai3/voulues.lua (objets voulus déclarés par un module, lus par le cerveau de
  recherche) et son branchement dans script/ai3/cerveau.lua. Usage :   lua5.2 tests/voulues_test.lua
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
end
local function read_file(path) local fh = assert(io.open(path, "rb")); local s = fh:read("*a"); fh:close(); return s end
local function keys(t) local o = {} for k in pairs(t or {}) do o[#o + 1] = k end table.sort(o) return table.concat(o, ",") end

local function battery(V)
  local f = { team = { ia3 = {} } }
  check(V.wanted(f) == nil, "rien de déclaré : nil")
  check(V.set(f, "mall", { "splitter", "underground-belt", "splitter" }, 100) == true, "set : l'état change")
  check(keys(V.wanted(f)) == "splitter,underground-belt", "wanted : objets triés, sans doublon")
  check(V.set(f, "mall", { "underground-belt", "splitter" }, 200) == false, "set identique : pas de changement (même liste dans un autre ordre)")
  check(f.team.ia3.voulues.mall.tick == 100, "set identique : le tick d'origine est gardé")
  check(V.set(f, "autre", { fast = true }, 300) == true and keys(V.wanted(f)) == "fast,splitter,underground-belt", "table { objet = vrai } acceptée, sources réunies")
  check(V.set(f, "mall", { "splitter" }, 400) == true and keys(V.wanted(f)) == "fast,splitter", "set remplace la liste de la source")
  check(V.clear(f, "autre") == true and keys(V.wanted(f)) == "splitter", "clear retire la source")
  check(V.clear(f, "autre") == false, "clear d'une source absente : faux")
  check(V.set(f, "mall", {}, 500) == true and V.wanted(f) == nil and f.team.ia3.voulues == nil, "liste vide : la source est retirée, plus d'état")
  check(V.set({}, "mall", { "x" }) == false and V.set(nil, "mall", { "x" }) == false, "équipe sans cerveau : rien, pas d'erreur")
  check(V.set(f, 12, { "x" }) == false, "source non texte refusée")
  check(V.wanted({}) == nil and V.wanted(nil) == nil, "wanted sans cerveau : nil")
  check(V.wanted({ team = { ia3 = { voulues = { vide = { tick = 1, items = {} } } } } }) == nil, "source sans objet : nil, pas une table vide")
  -- Lot TESTS-VERTS : l'ordre GARDÉ par set (lu tel quel par set identique et par wanted) est trié, sans dépendre de l'ordre de pairs : avec
  -- deux objets, l'ordre de pairs de lua5.2 tombait trié et le mutant « set ne trie pas » survivait (voulues.lua inchangée depuis 0ac4778e)
  local g = { team = { ia3 = {} } }
  V.set(g, "mall", { "m7", "a2", "q5", "c9", "z1", "b4", "k3", "e8", "x6" }, 1)
  check(table.concat(g.team.ia3.voulues.mall.items, ",") == "a2,b4,c9,e8,k3,m7,q5,x6,z1", "set : liste gardée triée")
end

local src = read_file("script/ai3/voulues.lua")
local V0 = dofile("script/ai3/voulues.lua")
battery(V0)

local brain = read_file("script/ai3/cerveau.lua")
local function wiring(b)
  check(b:find('local Voulues = require("script.ai3.voulues")', 1, true) ~= nil, "cerveau.lua requiert voulues")
  check(b:find("local vw = Voulues.wanted(f)", 1, true) ~= nil and b:find("for _, k in ipairs(sorted_keys(vw)) do m[k] = true end", 1, true) ~= nil,
    "cerveau.lua : les objets voulus rejoignent `wanted` avant General.choose_tech")
  local i = b:find("local vw = Voulues.wanted(f)", 1, true)
  local j = b:find("General.choose_tech(f, force, st, book, w, tick, view, wanted)", 1, true)
  check(i and j and i < j, "cerveau.lua : fusion avant le choix de la recherche")
end
wiring(brain)

local function sub(s, a, b) local i, j = s:find(a, 1, true); assert(i, a); return s:sub(1, i - 1) .. b .. s:sub(j + 1) end
local mutants = {
  { "set ne trie pas", "mod", sub(src, "return sorted_keys(set)", "local o = {} for k in pairs(set) do o[#o + 1] = k end return o") },
  { "set remplace toujours (tick perdu)", "mod", sub(src, "if cur and table.concat(cur.items, \",\") == table.concat(list, \",\") then return false end", "") },
  { "clear garde l'état vide", "mod", sub(src, "if next(st.voulues) == nil then st.voulues = nil end", "") },
  { "liste vide gardée", "mod", sub(src, "if #list == 0 then return Voulues.clear(f, source) end", "") },
  { "wanted ignore les autres sources", "mod", sub(src, "for _, src in ipairs(sorted_keys(st.voulues)) do", "for _, src in ipairs({ sorted_keys(st.voulues)[1] }) do") },
  { "wanted rend {} au lieu de nil", "mod", sub(src, "return any and out or nil", "return out") },
  { "cerveau : objets voulus non fusionnés", "wiring", sub(brain, "for _, k in ipairs(sorted_keys(vw)) do m[k] = true end", "") },
  { "cerveau : fusion après le choix", "wiring", sub(sub(brain, "local vw = Voulues.wanted(f)", "local vw = nil"), "General.choose_tech(f, force, st, book, w, tick, view, wanted)", "General.choose_tech(f, force, st, book, w, tick, view, wanted) local vw2 = Voulues.wanted(f)") },
}
local refused = 0
for _, m in ipairs(mutants) do
  local before = failures
  quiet = true
  local ok = pcall(function()
    if m[2] == "mod" then battery(assert(load(m[3], "=mutant"))()) else wiring(m[3]) end
  end)
  quiet = false
  local killed = (failures > before) or not ok
  failures = before
  if killed then refused = refused + 1; passes = passes + 1 else failures = failures + 1; print("  ECHEC : mutant SURVIVANT : " .. m[1]) end
end
print(string.format("  mutants refuses : %d sur %d", refused, #mutants))
print(string.format("[VOULUES] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
