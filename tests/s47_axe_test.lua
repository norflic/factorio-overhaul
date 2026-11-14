package.path = "./?.lua;" .. package.path
local Ax = require("shared.team.champ_axe")
local n, bad = 0, 0
local function check(c, m) if c then n = n + 1 else bad = bad + 1; print("ECHEC : " .. m) end end
check(Ax.step(nil, 10, nil) == "first", "premier plan")
check(Ax.step(nil, 10, 10) == "wait", "verrou : un plan par tick")
check(Ax.step({ axe = "y", tick = 10 }, 10, 9) == "wait", "autre axe jamais au tick du premier")
check(Ax.step({ axe = "y", tick = 10 }, 11, 10) == "other", "autre axe au tick suivant")
check(Ax.step({ axe = "x", tick = 11, final = true }, 12, 11) == "final", "axe gagnant refait")
check(Ax.better({ drills = 5, chests = 0 }, nil) == false, "pas de plan : axe long garde")
print(string.format("s47 axe : %d OK, %d ECHEC(S)", n, bad))
os.exit(bad == 0 and 0 or 1)
