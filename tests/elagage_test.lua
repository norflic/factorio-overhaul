--[[ Lot P1-ELAGAGE : banc HORS JEU de shared/team/elagage.lua. Lancement : lua5.2 tests/elagage_test.lua (racine du mod).
  Foreuses simulées : seules celles sans ressource sous elles sont démontées ; ronde découpée (PER_SLICE par tranche) ;
  ronde suivante seulement après EVERY ; foreuse invalide ignorée. ]]
package.path = "./?.lua;" .. package.path
local E = require("shared.team.elagage")
local fails = 0
local function ok(c, m) if not c then fails = fails + 1 print("ECHEC : " .. m) end end

local drills, cut = {}, {}
for i = 1, 45 do drills[i] = { id = i, valid = (i ~= 7), left = (i % 3 == 0) and 0 or 5 } end
local io = {
  list = function() local l = {} for i, d in ipairs(drills) do l[i] = d end return l end,
  valid = function(d) return d.valid end,
  left = function(d) return d.left end,
  retire = function(d) cut[#cut + 1] = d.id d.valid = false end,
}
local st, tick = {}, 0
ok(E.step(st, tick, io) == 6, "tranche 1 : 6 foreuses epuisees parmi les 20 premieres")
ok(st.next == E.SLICE, "tranche suivante a SLICE")
ok(E.step(st, 10, io) == 0, "rien avant la tranche suivante")
E.step(st, E.SLICE, io) E.step(st, 2 * E.SLICE, io)
ok(#cut == 15, "15 foreuses epuisees demontees, aucune autre (" .. #cut .. ")")
for _, id in ipairs(cut) do ok(id % 3 == 0, "foreuse " .. id .. " demontee a tort") end
ok(st.queue == nil and st.next == 2 * E.SLICE + E.EVERY, "ronde finie : la suivante a EVERY")
drills[1].left = 0
ok(E.step(st, 2 * E.SLICE + E.EVERY - 1, io) == 0, "pas de ronde avant EVERY")
ok(E.step(st, 2 * E.SLICE + E.EVERY, io) == 1, "nouvelle ronde : la foreuse 1 epuisee depuis est demontee")
ok(#cut == 16 and drills[7].valid == false, "foreuse invalide jamais demontee")
for _, id in ipairs(cut) do ok(id ~= 7, "foreuse invalide demontee") end
if fails > 0 then print("elagage_test : " .. fails .. " echec(s)") os.exit(1) end
print("elagage_test : OK")
