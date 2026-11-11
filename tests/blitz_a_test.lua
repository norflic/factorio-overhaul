-- BLITZ-A : points 8, 9 de l'audit des 50 angles morts (pilier 1). Usage : lua5.2 tests/blitz_a_test.lua
package.path = "./?.lua;" .. package.path
local Dm = require("shared.ai3.demande")
local Sa = require("shared.ai3.saturation")
local ok, ko = 0, 0
local function check(c, m) if c then ok = ok + 1 else ko = ko + 1; print("ECHEC : " .. m) end end
local function suite()
  local f = {}
  f[#f + 1] = Sa.WINDOW == 4 or "point 8 : fenetre de saturation a 4 pentes"
  f[#f + 1] = Dm.Y_FLOOR == 0 or "point 9 : pas de production fictive"
  local r = Dm.step(Dm.new(), { stock_mu = 1000, free_mu = 1000, Y = 0, cands = {} })
  f[#f + 1] = (r.cap == 0) or "point 9 : base a l'arret, plafond nul"
  f[#f + 1] = (r.tmax_sleep == r.tmax_sleep and r.tmax_sleep ~= math.huge) or "point 9 : tmax_sleep fini sans production"
  local bad = {}
  for _, v in ipairs(f) do if v ~= true then bad[#bad + 1] = v end end
  return bad
end
local bad = suite()
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite verte")
local function mutant(name, apply, undo)
  apply(); local okm, b = pcall(suite); undo()
  check(not okm or #b > 0, "mutant non tue : " .. name)
end
mutant("fenetre 10", function() Sa.WINDOW = 10 end, function() Sa.WINDOW = 4 end)
mutant("Y_FLOOR 10", function() Dm.Y_FLOOR = 10 end, function() Dm.Y_FLOOR = 0 end)
print(("BLITZ-A : %d OK, %d ECHEC(S)"):format(ok, ko))
if ko > 0 then os.exit(1) end
