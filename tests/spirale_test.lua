--[[
  Sortie de spirale (shared/team/spirale.lua), règle PURE non branchée. États de la partie du DC sur 0.6.58
  (fo-logs/2026-11-07_PARTIE-DC-0658/factorio-current-1415.log, votre équipe) :
    - 157,7 à 177 min : 2 PNJ, effectif de départ 12, fer libre 0 ([FO-DEFENSE]), pierre saturée ([FO-IA3C] « sature [copper-plate
      stone] ») ;
    - 153,5 min : fer libre 28 ([FO-DEFENSE]).
  Fer d'une recrue : kit (pistolet 5 fer + 10 chargeurs ; 194 chargeurs au coffre, [FO-REARMEMENT]) + (10 + effectif) fer
  (shared/team/org.lua:1083) : 5 + 12 = 17 à 2 PNJ (HYPOTHÈSE : pistolet absent du coffre, chargeurs présents).
  Lancement : lua5.2 tests/spirale_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Sp = require("shared.team.spirale")

local quiet = false
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else
    failures = failures + 1
    if not quiet then print("  ECHEC : " .. msg) end
  end
end

local NEED = 17
local function suite()
  local d = Sp.decide({ workers = 2, floor = 12, iron = 0, recruit_iron = NEED, stone_saturated = true })
  check(d.hold == 0 and d.mine and d.stop_stone and not d.unarmed,
    "partie du DC, 157-177 min (2 PNJ, fer 0, pierre saturee) : minage d'urgence du fer, plus de pierre ; pas de recrue sans arme a 2")
  local d28 = Sp.decide({ workers = 2, floor = 12, iron = 28, recruit_iron = NEED, stone_saturated = true })
  check(d28.hold == NEED and Sp.iron_for_others(28, d28) == 28 - NEED and not d28.mine and not d28.stop_stone,
    "153,5 min (fer 28) : 17 gardes pour la recrue, 11 pour les autres ; assez pour une recrue : ni minage, ni arret de la pierre")
  local d10 = Sp.decide({ workers = 2, floor = 12, iron = 10, recruit_iron = NEED })
  check(d10.hold == 10 and Sp.iron_for_others(10, d10) == 0 and d10.mine,
    "fer 10 < 17 : tout le fer garde pour la recrue (les autres ne voient rien), minage d'urgence")
  local d1 = Sp.decide({ workers = 1, floor = 12, iron = 0, recruit_iron = NEED })
  check(d1.unarmed and d1.mine, "1 PNJ, fer 0 : recrue sans arme (parite avec les factions, planner.lua:943-947)")
  local up = Sp.decide({ workers = 12, floor = 12, iron = 0, recruit_iron = NEED, stone_saturated = true })
  check(up.hold == 0 and not up.mine and not up.unarmed and not up.stop_stone, "a l'effectif de depart : la regle ne fait rien")
  local nf = Sp.decide({ workers = 2, floor = 0, iron = 0, recruit_iron = NEED })
  check(nf.hold == 0 and not nf.mine, "sans effectif de depart connu (factions) : rien")
  check(Sp.decide(nil).hold == 0 and Sp.iron_for_others(5, nil) == 5, "entrees absentes : rien, le fer reste a tous")
  local ns = Sp.decide({ workers = 2, floor = 12, iron = 0, recruit_iron = NEED, stone_saturated = false })
  check(not ns.stop_stone and ns.mine, "pierre non saturee : la pierre continue")
end

suite()
local base_fail = failures

local real = Sp.decide
local killed, total = 0, 0
local function mutant(name, f)
  total = total + 1
  Sp.decide = f
  local p0, f0 = passes, failures
  quiet = true
  local ok = pcall(suite)
  quiet = false
  Sp.decide = real
  local caught = (failures > f0) or not ok
  passes, failures = p0, f0
  if caught then killed = killed + 1 else print("  MUTANT SURVIVANT : " .. name) end
end
mutant("aucune part gardee (avant)", function(s) local d = real(s) d.hold = 0 return d end)
mutant("tout le fer garde (plus que le besoin d'une recrue)", function(s) local d = real(s) if s and (s.workers or 0) < (s.floor or 0) then d.hold = s.iron or 0 end return d end)
mutant("regle aussi au-dessus de l'effectif de depart", function(s)
  local t = {} for k, v in pairs(s or {}) do t[k] = v end
  if t.floor then t.floor = math.max(t.floor, (t.workers or 0) + 1) end
  return real(t)
end)
mutant("recrue sans arme a 2 PNJ", function(s) local d = real(s) if s and (s.workers or 0) <= 2 and (s.iron or 0) < (s.recruit_iron or 0) then d.unarmed = true end return d end)
mutant("pas de minage d'urgence", function(s) local d = real(s) d.mine = false return d end)
mutant("pierre jamais arretee", function(s) local d = real(s) d.stop_stone = false return d end)
mutant("pierre arretee meme non saturee", function(s) local d = real(s) d.stop_stone = d.mine return d end)

print(string.format("[SPIRALE] MUTANTS : %d / %d refuses", killed, total))
print(string.format("[SPIRALE] BILAN : %d OK, %d ECHEC(S)%s", passes, failures + (total - killed), base_fail > 0 and " (suite de base en echec)" or ""))
os.exit((failures == 0 and killed == total) and 0 or 1)
