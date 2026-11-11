--[[
  IA3-a (préparation, lot IA3-0) : test hors jeu de la règle « recherche d'abord, rien d'impayable »
  (shared/ai3/recherche.lua ; docs/IA3_CERVEAU.md §6.2 ; revue B3).

  Données RÉELLES : recettes vanilla + mod (tests/fixtures/recipes_ia1e.lua), livre de la main (shared/team/book.lua)
  filtré comme en jeu par les recettes ACTIVES de la force (une faction au niveau L a les technologies de
  T.unlocks[0..L], tests/fixtures/tech_ai3.lua), niveaux T.research.

  Ce qu'il prouve :
    1. niveaux 1 à 3 payables à la main au niveau précédent ; niveau 4 IMPAYABLE (pack chimique) (K6, défaut C1) ;
    5. généricité (aucun nom de pack dans le module).

  Usage : lua5.2 tests/ai3_recherche_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local A = require("shared.ai3.recherche")
local Book = require("shared.team.book")
local T = require("shared.team.config")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[AI3-RECHERCHE] ECHEC : " .. msg) end
end

local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
local techs = dofile("tests/fixtures/tech_ai3.lua")

-- Recettes actives d'une faction au niveau L : celles qu'aucune technologie ne débloque, plus celles des technologies
-- de T.unlocks[0..L] (comme unlock() de script/team/team.lua).
local unlocked_by = {}
for tname, t in pairs(techs) do for _, r in ipairs(t.unlocks or {}) do unlocked_by[r] = unlocked_by[r] or {} ; unlocked_by[r][tname] = true end end
local function book_at(level)
  local have = {}
  for l = 0, level do for _, tn in ipairs(T.unlocks[l] or {}) do have[tn] = true end end
  return Book.new(recipes, { allowed = function(name)
    local by = unlocked_by[name]
    if not by then return true end
    for tn in pairs(by) do if have[tn] then return true end end
    return false
  end })
end

-- Sources de matières premières de l'ancien cerveau (SOURCE de shared/team/planner.lua).
local SOURCE = { ["coal"] = true, ["stone"] = true, ["iron-ore"] = true, ["copper-ore"] = true, ["iron-plate"] = true,
  ["copper-plate"] = true, ["steel-plate"] = true, ["stone-brick"] = true }
local function obtainable(item) return SOURCE[item] == true end

-- 1. Payabilité des niveaux.
for level = 0, 3 do
  local book = book_at(level)
  local ok, causes = A.level_status(book, T.research[level + 1], obtainable)
  if level < 3 then
    check(ok, string.format("niveau %d payable à la main au niveau %d (causes : %s)", level + 1, level, table.concat(causes, ", ")))
  else
    local chem = false
    for _, c in ipairs(causes) do if c == "chemical-science-pack" then chem = true end end
    check(not ok and chem, "niveau 4 impayable sans pétrole, cause « chemical-science-pack » (" .. table.concat(causes, ", ") .. ")")
  end
end

-- 5. Généricité.
do
  local f = assert(io.open("shared/ai3/recherche.lua", "rb"))
  local src = f:read("*a")
  f:close()
  local hits = {}
  for _, lvl in ipairs(T.research) do
    for _, it in ipairs(lvl) do if src:find('"' .. it[1] .. '"', 1, true) then hits[#hits + 1] = it[1] end end
  end
  check(#hits == 0, "généricité : aucun nom de pack dans le module (" .. table.concat(hits, ", ") .. ")")
end

print(string.format("[AI3-RECHERCHE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
