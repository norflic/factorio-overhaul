package.path = "./?.lua;" .. package.path
local B = require("shared.team.bande_brute")
local fails = 0
local function check(c, m) if not c then fails = fails + 1; print("ECHEC : " .. m) end end
local ok, cap = B.ok(36, 0, 2, false)
check(ok == false and cap == 2, "bande sans four de 36 foreuses pour 2 paires refusee")
check(B.ok(2, 0, 2, false) == true, "bande sans four a la hauteur des paires acceptee")
check(B.ok(1, 0, 0, false) == true, "au moins une foreuse")
check(B.ok(36, 24, 2, false) == true, "bande a fours (plaques) inchangee")
check(B.ok(36, 0, 2, true) == true, "bande voulue par la capitalisation inchangee")
if fails > 0 then error(fails .. " echec(s)") end
print("s45_pierre_test OK")
