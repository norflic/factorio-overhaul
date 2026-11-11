--[[
  Lot BLITZ-B (audit des 50 angles morts, pilier 3) : banc HORS JEU.
  Lancement : lua5.2 tests/blitz_b_test.lua (depuis la racine du mod).
    §29 : une recherche sans unité payée depuis plus de 3 min lâche les laboratoires (Im.STALL) ; mutant : 8 min.
    §28 : un laboratoire de plus dès qu'il reste plus de 180 s de laboratoire (Ia3.LAB_WINDOW_S) ; mutant : 600 s.
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; print("  ECHEC : " .. m) end end
local MIN = 3600

-- §29 : règle pure de shared/ai3/impayable.lua
local Im = require("shared.ai3.impayable")
local function stall_ok(I)
  local lab = { tech = "t", started = 0 }
  return I.should_stall(lab, 3 * MIN + 1, false, nil) == true and I.should_stall(lab, 3 * MIN, false, nil) == false
end
check(Im.STALL == 3 * MIN, "§29 Im.STALL vaut 3 min : " .. tostring(Im.STALL))
check(stall_ok(Im), "§29 au-delà de 3 min sans unité payée : arrêt ; à 3 min : pas encore")
do -- mutant : l'ancienne durée de 8 min
  local saved = Im.STALL; Im.STALL = 8 * MIN
  check(not stall_ok(Im), "§29 mutant 8 min détecté")
  Im.STALL = saved
end

-- §28 : constante lue dans le texte de script/ai3/cerveau.lua (le module exige le moteur)
local function window_of(src) return tonumber(src:match("\nIa3%.LAB_WINDOW_S%s*=%s*(%d+)")) end
local fh = assert(io.open("script/ai3/cerveau.lua", "r")); local src = fh:read("*a"); fh:close()
local function window_ok(s) return window_of(s) == 180 end
check(window_ok(src), "§28 Ia3.LAB_WINDOW_S vaut 180 : " .. tostring(window_of(src)))
check(not window_ok((src:gsub("(\nIa3%.LAB_WINDOW_S%s*=%s*)%d+", "%1600"))), "§28 mutant 600 s détecté")
-- 2 labos dès qu'il reste plus de 180 s (formule de cerveau.lua:592 : ceil(secs / fenêtre))
check(math.min(3, math.max(1, math.ceil(300 / window_of(src)))) == 2, "§28 300 s restantes : 2 laboratoires")

print(string.format("blitz_b : %d réussis, %d échecs", pass, fail))
if fail > 0 then os.exit(1) end
