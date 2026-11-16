-- Lot AMELIO-CONTINUE : règle pure shared/ai3/amelio_continue.lua. Usage : lua5.2 tests/amelio_continue_test.lua
package.path = "./?.lua;" .. package.path
local AC = require("shared.ai3.amelio_continue")
local R = require("shared.ai3.reglages")
local fails, passes = 0, 0
local function check(c, m) if c then passes = passes + 1 else fails = fails + 1; print("  ECHEC : " .. m) end end
-- types lus aux réglages (aucun nom ici)
local belt, drill, furn = R.RANG_TYPES[3], R.AMELIO_DRILL.type, nil
for t, r in pairs(R.AMELIO_PRIO) do if r == 3 then furn = t end end
check(AC.rank(belt) < AC.rank(drill) and AC.rank(drill) < AC.rank(furn), "priorité tapis < foreuses < fours")
check(AC.rank("inconnu") > AC.rank(furn), "type absent après tous")
local types = { [1] = furn, [2] = belt, [3] = drill, [4] = belt, [5] = "autre" }
local list = {}
for id = 5, 1, -1 do list[#list + 1] = { id = id } end
local out = AC.order(list, function(m) return types[m.id] end, 3)
check(#out == 3, "borne N")
local ids = {}
for _, m in ipairs(out) do ids[#ids + 1] = m.id end
check(table.concat(ids, ",") == "2,3,4", "garde tapis puis foreuse, trié par id (" .. table.concat(ids, ",") .. ")")
local out2 = AC.order(list, function(m) return types[m.id] end, 3)
local ids2 = {}
for _, m in ipairs(out2) do ids2[#ids2 + 1] = m.id end
check(table.concat(ids, ",") == table.concat(ids2, ","), "déterminisme")
-- Lot TIERS-MACHINES : 600 tapis ne chassent plus les fours du relevé (part de chaque rang présent)
do
  local big, ty = {}, {}
  for id = 1, 700 do big[#big + 1] = { id = id }; ty[id] = belt end
  for id = 701, 760 do big[#big + 1] = { id = id }; ty[id] = furn end
  local o = AC.order(big, function(m) return ty[m.id] end, 600)
  local nf, nb = 0, 0
  for _, m in ipairs(o) do if ty[m.id] == furn then nf = nf + 1 else nb = nb + 1 end end
  check(#o == 600 and nf == 60 and nb == 540, "part par rang : 60 fours gardés, 540 tapis (" .. nf .. "/" .. nb .. ")")
end
-- majz-0716 : les pièces d'une zone Maj + Z (fours aux numéros 741-760) entrent toutes au relevé, avant les parts des rangs
do
  local big, ty = {}, {}
  for id = 1, 700 do big[#big + 1] = { id = id }; ty[id] = belt end
  for id = 701, 760 do big[#big + 1] = { id = id }; ty[id] = furn end
  local z = function(m) return m.id > 740 end
  local o = AC.order(big, function(m) return ty[m.id] end, 30, z)
  local nz = 0
  for _, m in ipairs(o) do if m.id > 740 then nz = nz + 1 end end
  check(#o == 30 and nz == 20, "zone d'abord : les 20 fours de la zone dans un relevé de 30 (" .. nz .. ")")
  local o2 = AC.order(big, function(m) return ty[m.id] end, 10, z)
  local all = true
  for _, m in ipairs(o2) do if m.id <= 740 then all = false end end
  check(#o2 == 10 and all, "borne plus petite que la zone : seulement des pièces de la zone")
  local o3 = AC.order(big, function(m) return ty[m.id] end, 600)
  local o4 = AC.order(big, function(m) return ty[m.id] end, 600, function() return false end)
  local same = #o3 == #o4
  for i = 1, #o3 do if o3[i].id ~= o4[i].id then same = false end end
  check(same, "sans zone : relevé inchangé")
end
local w = AC.kit_want({ b = 30, a = 2 }, { a = 1, b = 4 }, 12)
check(#w == 2 and w[1][1] == "a" and w[1][2] == 1 and w[2][1] == "b" and w[2][2] == 8, "quota de kit borné et trié")
check(#AC.kit_want({ a = 3 }, { a = 5 }) == 0, "kit déjà au stock : rien à fabriquer")
-- Lot n100-kits : sans borne donnée, le kit est la réserve entière du lot (déjà bornée par Cap.pool), jamais 12 (réf. 0.9.9 : kit de 12
-- pour une réserve de 40 ; la matière reste bornée par le stock libre, Bm.best).
local w40 = AC.kit_want({ b = 40 }, { b = 3 })
check(#w40 == 1 and w40[1][2] == 37, "n100-kits : kit = réserve du lot moins le stock (" .. tostring(w40[1] and w40[1][2]) .. ")")
check(AC.KIT_CAP == nil, "n100-kits : plus de borne propre au kit")
check(AC.pile_permits(false, 0) and AC.pile_permits(true, 1) and not AC.pile_permits(true, 0), "pile : kit au stock passe")
local st = {}
local n = 0
for _ = 1, AC.LOGS + 5 do if AC.log_ok(st) then n = n + 1 end end
check(n == AC.LOGS, "journal borné")
print(string.format("amelio_continue_test : %d ok, %d echec(s)", passes, fails))
if fails > 0 then os.exit(1) end
