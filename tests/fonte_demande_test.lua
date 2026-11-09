--[[
  Tests hors jeu du lot FONTE-CUIVRE (shared/team/fonte_demande.lua : un four dont le minerai n'est plus demandé n'est plus complété
  quand une autre entrée demandée attend). Usage : lua5.2 tests/fonte_demande_test.lua
  1. la règle pure ; 2. le câblage (outposts.lua et worker.lua passent le stock, la règle ne vaut que pour un minerai) ; 3. mutants.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function read_src(path)
  local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local function load_rule(src) return assert(load(src, "@fonte_demande"))() end

local function facts(Fd)
  local f = {}
  local stock = { A = 0, B = 120, C = 0 }
  local function st(i) return stock[i] end
  f.demanded = Fd.refill({ demanded = true, other_waiting = true }) and 1 or 0
  f.dropped = Fd.refill({ demanded = false, other_waiting = true }) and 1 or 0
  f.kept_alone = Fd.refill({ demanded = false, other_waiting = false }) and 1 or 0
  f.nil_in = Fd.refill(nil) and 1 or 0
  f.ow_yes = Fd.other_waiting("A", { "A", "B" }, st) and 1 or 0
  f.ow_second = Fd.other_waiting("C", { "A", "B" }, st) and 1 or 0 -- le premier est vide, le second attend
  f.ow_self = Fd.other_waiting("B", { "A", "B" }, st) and 1 or 0
  f.ow_none = Fd.other_waiting("A", { "A", "C" }, st) and 1 or 0
  f.ow_empty = Fd.other_waiting("A", {}, st) and 1 or 0
  f.ow_nil = Fd.other_waiting("A", nil, st) and 1 or 0
  -- cas de la mesure : cuivre plus demandé, minerai de fer au coffre
  local s2 = { ["iron-ore"] = 216, ["copper-ore"] = 64 }
  f.case_copper = Fd.refill({ demanded = false, other_waiting = Fd.other_waiting("copper-ore", { "iron-ore" }, function(i) return s2[i] end) }) and 1 or 0
  f.case_iron = Fd.refill({ demanded = true, other_waiting = Fd.other_waiting("iron-ore", { "iron-ore" }, function(i) return s2[i] end) }) and 1 or 0
  s2["iron-ore"] = 0
  f.case_noiron = Fd.refill({ demanded = false, other_waiting = Fd.other_waiting("copper-ore", { "iron-ore" }, function(i) return s2[i] end) }) and 1 or 0
  return f
end

local PATH = "shared/team/fonte_demande.lua"
local F0 = facts(load_rule(read_src(PATH)))
print("== 1. Règle")
check(F0.demanded == 1, "entrée demandée : complétée")
check(F0.dropped == 0, "entrée plus demandée, une autre demandée attend : plus complétée")
check(F0.kept_alone == 1 and F0.nil_in == 1, "aucune autre entrée qui attend (ou pas d'entrée) : rien ne change")
check(F0.ow_yes == 1 and F0.ow_second == 1 and F0.ow_self == 0 and F0.ow_none == 0 and F0.ow_empty == 0 and F0.ow_nil == 0, "autre entrée demandée avec du stock : seule celle-là compte (pas soi, pas un stock vide)")
check(F0.case_copper == 0, "cas mesuré : cuivre plus demandé, 216 minerais de fer au coffre : le four au cuivre n'est plus complété")
check(F0.case_iron == 1 and F0.case_noiron == 1, "le fer demandé est complété ; sans minerai de fer au coffre, le cuivre continue")

print("== 2. Câblage")
local out = read_src("script/faction/outposts.lua")
local wk = read_src("script/team/worker.lua")
check(out:find('require("shared.team.fonte_demande")', 1, true) ~= nil, "outposts : la règle est chargée")
check(out:find("function Outposts.smelt_loads(f, products, list, released, stock_of)", 1, true) ~= nil, "smelt_loads reçoit le stock")
check(out:find("if stock_of and not T.smelter_inputs[c.name] then", 1, true) ~= nil, "la règle ne vaut que pour un minerai (la plaque de l'acier garde sa règle)")
check(out:find("Fd.other_waiting(c.name, items, stock_of)", 1, true) ~= nil and out:find("and wanted and not stuck(s, c)", 1, true) ~= nil, "le four n'est pas complété quand la règle le refuse")
check(out:find("carrier.get_item_count(item) end)) do", 1, true) ~= nil, "le service lit le stock du porteur")
check(wk:find("Outposts.smelt_loads(f, products, nil, rel, function(item) return Stock.count(f, item) end)", 1, true) ~= nil, "le porteur emporte selon le stock du coffre")

print("== 3. Mutants")
local killed, total = 0, 0
local function mutant(name, from, to)
  total = total + 1
  local src = read_src(PATH)
  local i, j = src:find(from, 1, true)
  if not i then check(false, "mutant '" .. name .. "' : texte introuvable") return end
  local ok, F = pcall(function() return facts(load_rule(src:sub(1, i - 1) .. to .. src:sub(j + 1))) end)
  local changed = not ok
  if ok then for k, v in pairs(F0) do if F[k] ~= v then changed = true end end end
  if check(changed, "mutant refusé : " .. name) then killed = killed + 1 end
end
mutant("l'entrée demandée n'est pas protégée", "if a.demanded then return true end", "")
mutant("rien ne change n'est plus vrai", "return not a.other_waiting", "return false")
mutant("l'entrée coupée même seule", "return not a.other_waiting", "return a.demanded")
mutant("soi compte comme autre", "if d ~= item and", "if")
mutant("stock vide compte", "(stock_of(d) or 0) > 0", "true")
mutant("seule la dernière entrée compte", "if d ~= item and (stock_of(d) or 0) > 0 then return true end", "if d ~= item then return (stock_of(d) or 0) > 0 end")
print(string.format("   mutants refusés : %d / %d", killed, total))
check(killed == total, "tous les mutants refusés")
print(string.format("[FONTE-DEMANDE] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refusés", passes, failures, killed, total))
os.exit(failures == 0 and 0 or 1)
