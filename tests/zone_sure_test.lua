--[[
  Zone sûre du départ des factions (lot EQUILIBRE) : règle pure shared/faction/zone_sure.lua + son branchement dans
  script/faction/war.lua sur le moteur simulé. Usage : lua5.2 tests/zone_sure_test.lua
]]
package.path = "./?.lua;" .. package.path
local Z = require("shared.faction.zone_sure")
local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end

local hq = { x = 100, y = -200 }
check(Z.RADIUS > Z.OLD_RADIUS and Z.RADIUS >= 3 * Z.OLD_RADIUS, "rayon agrandi (>= 3 x l'ancien)")
-- pires nids vus au retour du DC (88, 112, 137, 174 tuiles) : tous dedans
for _, d in ipairs({ 88, 112, 137, 174, 200, 255 }) do check(Z.inside(hq, hq.x + d, hq.y, nil), "nid a " .. d .. " dans la zone") end
check(Z.inside(hq, hq.x + Z.RADIUS, hq.y), "bord exact : dedans")
check(not Z.inside(hq, hq.x + Z.RADIUS + 0.5, hq.y), "juste au-dela : dehors")
check(not Z.inside(hq, hq.x + 200, hq.y + 200), "coin du carre (282 tuiles) : dehors, la zone est un disque")
local a = Z.area(hq)
check(a[1][1] == hq.x - Z.RADIUS and a[2][2] == hq.y + Z.RADIUS, "carre englobant")
-- chunks
check(Z.chunk_touches(hq, 3, -7), "chunk du QG")
check(Z.chunk_touches(hq, 3 + 8, -7), "chunk a 8 chunks : touche encore")
check(not Z.chunk_touches(hq, 3 + 10, -7), "chunk a 10 chunks : ne touche pas")
check(not Z.chunk_touches(hq, 3 + 8, -7 + 8), "chunk diagonal a 8+8 : ne touche pas")
check(Z.which({ { x = 5000, y = 5000 }, hq }, hq.x + 50, hq.y) == 2, "which : second QG")
check(Z.which({ hq }, 9999, 0) == nil, "which : hors zone")
local n, d = Z.nearest(hq, { { x = 100 + 300, y = -200 }, { x = 100, y = -200 + 120 } })
check(n and n.y == -80 and math.abs(d - 120) < 1e-9, "nearest")
check(Z.nearest(hq, {}) == nil, "nearest vide")

-- Mutants de la règle : chacun doit être vu par au moins un contrôle ci-dessus (copie locale réécrite)
local function mutant(name, patch)
  local M = {}
  for k, v in pairs(Z) do M[k] = v end
  patch(M)
  local killed = false
  if not (M.RADIUS >= 3 * M.OLD_RADIUS) then killed = true end
  for _, dd in ipairs({ 88, 174, 255 }) do if not M.inside(hq, hq.x + dd, hq.y) then killed = true end end
  if M.inside(hq, hq.x + 200, hq.y + 200) then killed = true end
  if not M.inside(hq, hq.x + M.RADIUS, hq.y) then killed = true end
  if M.inside(hq, hq.x + M.RADIUS + 0.5, hq.y) then killed = true end
  if M.chunk_touches(hq, 13, -7) then killed = true end
  if not M.chunk_touches(hq, 11, -7) then killed = true end
  check(killed, "mutant refuse : " .. name)
end
mutant("ancien rayon 80", function(M) M.RADIUS = 80 end)
mutant("carre au lieu du disque", function(M)
  M.inside = function(h, x, y, r) r = r or M.RADIUS return math.abs(x - h.x) <= r and math.abs(y - h.y) <= r end end)
mutant("bord exclu", function(M)
  M.inside = function(h, x, y, r) r = r or M.RADIUS local dx, dy = x - h.x, y - h.y return dx * dx + dy * dy < r * r - 1 end end)
mutant("chunk teste par son centre", function(M)
  M.chunk_touches = function(h, cx, cy, r) return M.inside(h, cx * 32 + 16, cy * 32 + 16, r and r - 40 or M.RADIUS - 40) end end)
mutant("chunk jamais touche", function(M) M.chunk_touches = function() return false end end)

print(string.format("[ZONE-SURE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
