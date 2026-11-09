--[[
  Lot FER-D-ABORD : banc HORS JEU de Th.iron_waits / Th.raw_holds (shared/team/thermique.lua) et de leur branchement dans start_next
  (script/team/migration_champ.lua, contrôle de texte). Lancement : lua5.2 tests/fer_d_abord_test.lua (depuis la racine du mod).
  Cas mesuré (graine 123456789, votre équipe) : « avant-poste 1 (iron) : migration en veille (plaques) » toute la partie pendant que les bandes de
  charbon et de pierre (tier 1, sans garde de plaques) partent : 10 foreuses de fer sur 1 935 tuiles à 60 et 100 min.
]]
package.path = "./?.lua;" .. package.path
local Th = require("shared.team.thermique")
local passes, failures = 0, 0
local QUIET = false
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1 if not QUIET then print("  ECHEC : " .. m) end end end

local function body()
  QUIET = true
  local f0 = failures
  check(Th.iron_waits(0, "plaques") == true, "m1 tier 0 refuse faute de plaques")
  check(Th.iron_waits(1, "plaques") == false, "m2 tier 1 : pas une attente de fer")
  check(Th.iron_waits(0, "courant") == false, "m3 autre cause de refus")
  check(Th.iron_waits(nil, "plaques") == true, "m4 tier absent = 0")
  check(Th.raw_holds(1, false, true) == true, "m5 brut retenu")
  check(Th.raw_holds(1, true, true) == false, "m6 brut VOULU : jamais retenu")
  check(Th.raw_holds(0, false, true) == false, "m7 tier 0 jamais retenu")
  check(Th.raw_holds(1, false, false) == false, "m8 rien n'attend : brut libre")
  check(Th.raw_holds(1, false, nil) == false, "m9 drapeau absent")
  QUIET = false
  return failures - f0
end
print("== regle")
body()
local c = 0
debug.sethook(function() c = c + 1 end, "", 1000)
for i = 1, 1000 do Th.iron_waits(i % 2, "plaques") Th.raw_holds(i % 2, false, true) end
debug.sethook()
check(c < 50, "cout : moins de 50 instructions par appel (" .. c .. ")")
print("== branchement (texte de start_next)")
local f = io.open("script/team/migration_champ.lua", "rb")
local mig = f:read("*a")
f:close()
check(mig:find("Th.raw_holds(it.tier, it.wanted, iron_waiting)", 1, true) ~= nil, "le gisement brut est retenu par Th.raw_holds")
check(mig:find("if Th.iron_waits(it.tier, why) then iron_waiting = true end", 1, true) ~= nil, "le refus « plaques » d'un gisement de plaques leve le drapeau")
local a = mig:find("local iron_waiting = false", 1, true)
local b = mig:find("Th.raw_holds(it.tier", 1, true)
local d = mig:find("Th.iron_waits(it.tier", 1, true)
check(a and b and d and a < b and b < d, "drapeau pose avant la boucle, lu en tete de boucle, ecrit apres Mg.start_ok")
print("== mutants")
local f2 = io.open("shared/team/thermique.lua", "rb")
local src = f2:read("*a")
f2:close()
local mutants = {
  { "tier 1 attend le fer", "return (tier or 0) == 0 and why == \"plaques\"", "return why == \"plaques\"" },
  { "autre cause", "and why == \"plaques\"", "and why ~= nil" },
  { "voulu retenu", "and (tier or 0) == 1 and not wanted", "and (tier or 0) == 1" },
  { "tier 0 retenu", "(tier or 0) == 1 and not wanted", "(tier or 0) <= 1 and not wanted" },
  { "drapeau ignore", "return iron_waiting == true and", "return true and" },
}
for _, m in ipairs(mutants) do
  local x, y = src:find(m[2], 1, true)
  if not x then check(false, "motif introuvable : " .. m[1])
  else
    local chunk = load(src:sub(1, x - 1) .. m[3] .. src:sub(y + 1), "=mut", "t")
    local Tm = chunk and chunk()
    if not Tm then check(false, "mutant illisible : " .. m[1])
    else
      local Ta = Th
      Th = Tm
      local p0, f0 = passes, failures
      local n = body()
      passes, failures = p0, f0
      Th = Ta
      QUIET = false
      check(n > 0, "mutant detecte : " .. m[1])
    end
  end
end
print(string.format("[FER-D-ABORD] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
