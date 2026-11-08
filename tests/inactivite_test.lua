--[[
  Lot ZERO-IDLE-3 : mesure des causes d'inactivité (shared/ai3/inactivite.lua), règle pure. Lancement : lua5.2 tests/inactivite_test.lua
  (depuis la racine du mod). Mutants : MUT=1..5 casse la règle (le banc doit alors échouer).
]]
package.path = "./?.lua;" .. package.path
local I = require("shared.ai3.inactivite")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
end
local function eq(a, b, msg) check(a == b, msg .. " (obtenu " .. tostring(a) .. ", attendu " .. tostring(b) .. ")") end

local mut = tonumber(os.getenv("MUT") or "0")
if mut == 1 then I.empty_reason = function(st) return "rien" end end
if mut == 2 then local d = I.dt; I.dt = function(seen, tick) return 60 end end
if mut == 3 then local n = I.note; I.note = function(acc, key, dt, tick) acc = n(acc, key, dt, tick); acc.total = acc.total - dt; return acc end end
if mut == 4 then local l = I.line; I.line = function(...) local s = l(...); return s and (s:gsub("PNJ%-s", "x")) end end
if mut == 5 then I.due = function() return true end end

print("== dt")
eq(I.dt(nil, 1000), 60, "premiere pensee : une periode")
eq(I.dt(940, 1000), 60, "ecart de 60")
eq(I.dt(900, 1000), 100, "ecart de 100 (jetons refuses entre deux)")
eq(I.dt(1000, 1000), 60, "meme tick : une periode")
eq(I.dt(100, 5000), 60, "ecart au-dela de DT_MAX : une periode (PNJ revenu de loin)")

print("== raison d'une prise vide")
eq(I.empty_reason({ free = 0, cannot = 0, ranked = 0 }), "rien", "aucune tache libre")
eq(I.empty_reason({ free = 5, cannot = 4, ranked = 0 }), "role", "le PNJ ne sait pas les faire")
eq(I.empty_reason({ free = 5, cannot = 1, ranked = 0 }), "indice", "indiquees a un autre PNJ")
eq(I.empty_reason({ free = 5, cannot = 0, ranked = 3, matiere = 3, tried = 0, first_kind = "craft" }), "matiere:craft", "matiere stricte non libre")
eq(I.empty_reason({ free = 5, cannot = 0, ranked = 3, matiere = 0, tried = 2, first_kind = "mine" }), "reserve:mine", "reservation refusee")
eq(I.empty_reason({ free = 5, cannot = 0, ranked = 3, matiere = 1, tried = 2, first_kind = "extend" }), "mixte:extend", "mixte")

print("== cumul et ligne")
local acc
acc = I.note(acc, "sans-tache:rien", 60, 0)
acc = I.note(acc, "sans-tache:rien", 60, 60)
acc = I.note(acc, "jetons", 30, 120)
eq(acc.total, 150, "total en ticks")
eq(acc.count["sans-tache:rien"], 2, "compte")
check(not I.due(acc, 3599), "pas encore une minute")
check(I.due(acc, 3600), "une minute")
local line = I.line("scarlet", 3, acc, 8, 3600)
check(line ~= nil and line:find("%[FO%-INACTIF%-CAUSE%] scarlet minute 3"), "ligne d'en-tete")
check(line:find("sans%-tache:rien 2 s %(2%)") ~= nil, "cause principale en tete : " .. tostring(line))
check(line:find("PNJ 8 | perdu 2 PNJ%-s sur 480") ~= nil, "denominateur : PNJ x fenetre : " .. tostring(line))
check(line:find("jetons 0 s %(1%)") ~= nil, "cause secondaire")
check(I.line("x", 1, nil, 8, 3600) == nil, "rien a dire sans accumulateur")
check(I.line("x", 1, { ticks = {}, count = {}, total = 0 }, 8, 3600) == nil, "rien a dire a zero")

print(string.format("[INACTIVITE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
