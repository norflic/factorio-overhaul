--[[
  Lot EXPLORATION-FER : banc HORS JEU de shared/ai3/sites_avance.lua (sites du type clé gardés d'avance). Lancement : lua5.2 tests/sites_avance_test.lua
  Cas mesuré : fer, 1 avant-poste, 1 site connu (ou 0) -> l'exploration part (avant : seulement à « sites 0 » et « plein », 11 à 24 min).
]]
package.path = "./?.lua;" .. package.path
local S = require("shared.ai3.sites_avance")
local passes, failures = 0, 0
local QUIET = false
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1 if not QUIET then print("  ECHEC : " .. m) end end end

local function body()
  QUIET = true
  local f0 = failures
  check(S.wanted({ outposts = 1, sites = 1 }) == 2, "m1 un site connu : on en veut deux")
  check(S.wanted({ outposts = 1, sites = 0 }) == 2, "m2 aucun site")
  check(S.wanted({ outposts = 1, sites = 2 }) == 0, "m3 deux sites : rien")
  check(S.wanted({ outposts = 0, sites = 0 }) == 0, "m4 pas d'avant-poste : rien")
  check(S.wanted({ outposts = 1, sites = 0, threat = true }) == 0, "m5 QG menace")
  check(S.wanted({ outposts = 1, sites = 0, hold = true }) == 0, "m6 retenue")
  check(S.short(1, 1, 2) and not S.short(2, 1, 2), "m7 anticipation")
  check(not S.short(1, 1, nil) and S.short(0, 1, nil), "m8 sans anticipation : la regle d'avant")
  check(not S.short(0, 0, 2), "m9 aucun besoin : fermee")
  QUIET = false
  return failures - f0
end

print("== regle")
body()
check(S.wanted({}) == 0 and S.wanted(nil) == 0, "entree vide")
check(S.wanted({ outposts = 3, sites = 5 }) == 0, "beaucoup de sites : rien")
local keep = S.ON
S.ON = false
check(S.wanted({ outposts = 1, sites = 0 }) == 0, "interrupteur eteint : rien")
S.ON = keep
local c = 0
debug.sethook(function() c = c + 1 end, "", 1000)
for i = 1, 1000 do S.wanted({ outposts = 2, sites = i % 3 }) S.short(i % 3, 1, 2) end
debug.sethook()
check(c * 1000 / 1000 < 100, "cout : moins de 100 instructions par appel (" .. (c * 1000 / 1000) .. ")")

print("== mutants")
local f = io.open("shared/ai3/sites_avance.lua", "rb")
local src = f:read("*a")
f:close()
local mutants = {
  { "seuil a 1", "S.MIN_SITES = 2", "S.MIN_SITES = 0" },
  { "pas de test des sites", "if (a.sites or 0) >= S.MIN_SITES then return 0 end", "" },
  { "menace ignoree", "or a.threat or a.hold then", "or a.hold then" },
  { "retenue ignoree", "a.threat or a.hold then", "a.threat then" },
  { "sans avant-poste", "if (a.outposts or 0) < 1 then return 0 end", "" },
  { "anticipation toujours", "return soon ~= nil and (available or 0) < soon", "return true" },
  { "besoin ignore", "if (need or 0) <= 0 then return false end", "" },
}
for _, m in ipairs(mutants) do
  local a, b = src:find(m[2], 1, true)
  if not a then check(false, "motif introuvable : " .. m[1])
  else
    local chunk = load(src:sub(1, a - 1) .. m[3] .. src:sub(b + 1), "=mut", "t")
    local Sm = chunk and chunk()
    if not Sm then check(false, "mutant illisible : " .. m[1])
    else
      local Sa = S
      S = Sm
      local p0, f0 = passes, failures
      local n = body()
      passes, failures = p0, f0
      S = Sa
      QUIET = false
      check(n > 0, "mutant detecte : " .. m[1])
    end
  end
end
print(string.format("[SITES-AVANCE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
