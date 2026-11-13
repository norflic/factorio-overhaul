--[[
  Sprint s40, axe « décision » (shared/ai3/projets.lua) : plans du livre refaits pour rien pendant le dépliage des projets.
    p2 : plafond de fabrications de la pensée atteint (E.crafts = P.MAX_CRAFTS) : P.want ne planifie plus que le manque (1 plan), même résultat ;
    p3 : une fabrication qui tient en un morceau ne refait pas le plan qui a servi à mesurer son énergie, même tâche.
  Lancement, depuis la racine du mod :   lua5.2 tests/s40_decision_test.lua
]]
package.path = "./?.lua;" .. package.path
local Book = require("shared.team.book")
local P = require("shared.ai3.projets")

local book = Book.new(dofile("tests/fixtures/recipes.lua"))
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end

-- Livre compteur : mêmes réponses que le livre, nombre de plans relevé.
local plans = 0
local counted = setmetatable({ plan = function(_, wants, stock) plans = plans + 1 return book:plan(wants, stock) end }, { __index = book })

local ITEM = "burner-mining-drill"
local function stock() return { ["iron-plate"] = 500, stone = 500, ["copper-plate"] = 500, coal = 500 } end
local function ser(t)
  if type(t) ~= "table" then return tostring(t) end
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(ks) do if t[k] ~= 0 then out[#out + 1] = tostring(k) .. "=" .. ser(t[k]) end end -- (une case à 0 vaut une case absente)
  return "{" .. table.concat(out, ",") .. "}"
end
local function run(bk, crafts, n)
  local E = P.context(stock(), bk, { open = {} }, {})
  E.crafts = crafts
  local proj = { id = 7, key = "essai" }
  local ok = P.want(E, proj, { { ITEM, n } }, 50, false, "t")
  return E, ok, proj
end

check(book:handcraftable(ITEM), "l'objet d'essai se fabrique à la main")

-- p2 : plafond atteint.
plans = 0
local E, ok, proj = run(counted, P.MAX_CRAFTS, 3)
check(plans == 1, "plafond atteint : un seul plan du livre (celui du manque), relevé " .. plans)
check(ok == false and #E.tasks == 0 and E.crafts == P.MAX_CRAFTS, "plafond atteint : rien n'est fabriqué, le besoin n'est pas servi")
check(E.raw[ITEM] and E.raw[ITEM].n == 3 and (proj.missing or {})[ITEM] == 3, "plafond atteint : l'objet reste un manque du projet (3)")
check(ser(E.avail) == ser(stock()), "plafond atteint : le stock virtuel est intact")
-- matière qui manque ET plafond atteint : les manques bruts sont ceux du plan entier
plans = 0
local Ep = P.context({ stone = 500 }, counted, { open = {} }, {})
Ep.crafts = P.MAX_CRAFTS
P.want(Ep, { id = 8, key = "pauvre" }, { { ITEM, 2 } }, 50, false, "t")
local want_raw = book:plan({ { ITEM, 2 } }, { stone = 500 }).raw
local same = true
for k, v in pairs(want_raw) do if not (Ep.raw[k] and Ep.raw[k].n == math.ceil(v)) then same = false end end
check(same and next(want_raw) ~= nil and plans == 1, "plafond atteint, matière absente : manques bruts du plan entier, un seul plan (" .. plans .. ")")

print(string.format("[S40-DECISION] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
