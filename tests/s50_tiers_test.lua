-- s50 tiers : un parc de fours (type d'entité furnace) dont le successeur n'est pas débloqué réclame sa recherche
-- (rang_wanted) au-delà de Am.RESEARCH_MIN pièces ; en dessous, ou règle éteinte, rien. Aucun nom dans la règle.
-- Usage : lua5.2 tests/s50_tiers_test.lua (depuis la racine du mod)
package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")
local Cap = require("shared.ai3.capital")
local Am = require("shared.ai3.amelioration")

local MP = {
  ["f-a"] = { type = "furnace", group = "g", w = 2, h = 2, energy = "burner", cats = { smelting = true }, speed = 1, item = "f-a" },
  ["f-b"] = { type = "furnace", group = "g", w = 2, h = 2, energy = "burner", cats = { smelting = true }, speed = 2, item = "f-b" },
  ["m-a"] = { type = "assembling-machine", group = "h", w = 3, h = 3, energy = "electric", cats = { c = true }, speed = 1, item = "m-a" },
  ["m-b"] = { type = "assembling-machine", group = "h", w = 3, h = 3, energy = "electric", cats = { c = true }, speed = 2, item = "m-b" },
}
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; print("[S50-TIERS] ECHEC : " .. m) end end
local function run(name, n, continu)
  local ms = {}
  for i = 1, n do ms[i] = { id = i, name = name, working = true } end
  local ctx = { proto = function() return nil end, unit_cost = function() return 5 end, stock = {}, weights = {},
    mproto = function(x) return MP[x] end, machines = { "f-a", "f-b", "m-a", "m-b" }, continu = continu,
    available = function(it) return it ~= "f-b" and it ~= "m-b" end }
  local _, blocked = Cap.replace_candidates(L, { machines = ms }, ctx)
  return blocked[1]
end
local b = run("f-a", Am.RESEARCH_MIN, true)
check(b and b.rang_want == true and b.causes[1] == "f-b", "four en nombre : successeur voulu")
b = run("f-a", Am.RESEARCH_MIN - 1, true)
check(b and not b.rang_want, "four sous le seuil : rien")
b = run("f-a", 40, nil)
check(b and not b.rang_want, "regle eteinte : rien")
b = run("m-a", 40, true)
check(b and not b.rang_want, "assembleur (type hors PIECE_FIRST_TYPES) : rien")
print(string.format("[S50-TIERS] %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
