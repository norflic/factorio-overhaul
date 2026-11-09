--[[
  Lot COLLECTE-CHAMP : banc HORS JEU de la collecte des coffres de sortie du champ SOUS leur seuil quand ils comblent un manque mesuré
  (shared/team/collecte.lua : C.useful, C.low_due). Lancement : lua5.2 tests/collecte_basse_test.lua (depuis la racine du mod).
  Cas mesuré (graine 123456789, votre équipe, 42 à 87 min) : 21 coffres tenant 1 946 à 2 281 plaques, 15 sous le seuil de 200, manque
  « iron-plate 369 à 615 » : aucune tâche de collecte (« sans tâche, la sortie dort »).
]]
package.path = "./?.lua;" .. package.path
local C = require("shared.team.collecte")
local passes, failures = 0, 0
local QUIET = false
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1 if not QUIET then print("  ECHEC : " .. m) end end end

local function body()
  QUIET = true
  local f0 = failures
  local net = { ["a-plate"] = -500, ["b-plate"] = 20, ["c-ore"] = -10 }
  check(C.useful({ ["a-plate"] = 120 }, net) == 120, "m1 120 plaques utiles")
  check(C.useful({ ["a-plate"] = 900 }, net) == 500, "m2 borne au manque")
  check(C.useful({ ["b-plate"] = 300 }, net) == 0, "m3 sans manque (solde positif)")
  check(C.useful({ ["z-plate"] = 300 }, net) == 0, "m4 objet inconnu du manque")
  check(C.useful({ ["a-plate"] = 100, ["c-ore"] = 50 }, net) == 110, "m5 somme des manques")
  check(C.low_due({ ["a-plate"] = 40 }, net), "m6 seuil 40 atteint")
  check(not C.low_due({ ["a-plate"] = 39 }, net), "m7 sous le seuil 40")
  check(not C.low_due({ ["a-plate"] = 300 }, nil), "m8 sans manque mesure")
  check(C.LOW_MAX == 3, "m9 borne par pensee")
  QUIET = false
  return failures - f0
end
print("== regle")
body()
check(C.useful(nil, { x = -1 }) == 0 and C.useful({}, {}) == 0, "entrees vides")
local seq1, seq2 = {}, {}
for i = 1, 2 do
  local t = i == 1 and seq1 or seq2
  for _, k in ipairs(C.sorted({ b = 1, a = 2, c = 3 })) do t[#t + 1] = k end
end
check(table.concat(seq1) == table.concat(seq2) and table.concat(seq1) == "abc", "ordre trie")
local c = 0
debug.sethook(function() c = c + 1 end, "", 1000)
local contents = {}
for i = 1, 30 do contents["item" .. i] = i * 10 end
local net = {}
for i = 1, 30 do net["item" .. i] = -(i * 7) end
for _ = 1, 100 do C.low_due(contents, net) end
debug.sethook()
check(c * 1000 / 100 < 5000, "cout : moins de 5 000 instructions par coffre de 30 objets (" .. (c * 10) .. ")")

print("== mutants")
local f = io.open("shared/team/collecte.lua", "rb")
local src = f:read("*a")
f:close()
local mutants = {
  { "seuil a 0", "C.LOW_MIN = 40", "C.LOW_MIN = 0" },
  { "pas de borne au manque", "math.min(contents[item], -s)", "contents[item]" },
  { "solde positif compte", "type(s) == \"number\" and s < 0 then", "type(s) == \"number\" then" },
  { "seuil strict", "return C.useful(contents, net) >= C.LOW_MIN", "return C.useful(contents, net) > C.LOW_MIN" },
  { "tout objet compte", "if type(s) == \"number\" and s < 0 then total = total + math.min(contents[item], -s) end", "total = total + contents[item]" },
  { "borne par pensee", "C.LOW_MAX = 3", "C.LOW_MAX = 100" },
}
for _, m in ipairs(mutants) do
  local a, b = src:find(m[2], 1, true)
  if not a then check(false, "motif introuvable : " .. m[1])
  else
    local chunk = load(src:sub(1, a - 1) .. m[3] .. src:sub(b + 1), "=mut", "t")
    local Cm = chunk and chunk()
    if not Cm then check(false, "mutant illisible : " .. m[1])
    else
      local Ca = C
      C = Cm
      local p0, f0 = passes, failures
      local n = body()
      passes, failures = p0, f0
      C = Ca
      QUIET = false
      check(n > 0, "mutant detecte : " .. m[1])
    end
  end
end
print(string.format("[COLLECTE-BASSE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
