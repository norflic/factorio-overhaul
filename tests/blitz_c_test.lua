-- BLITZ-C : points du pilier 4 de l'audit des 50 angles morts (tests purs)
package.path = "./?.lua;" .. package.path
local Mel = require("shared.team.melange")
local fails = 0
local function check(c, m) if not c then fails = fails + 1; print("ECHEC " .. m) end end

-- point 40 : mel_ok retenu par nom ; relu au changement de nom, ancienne marque booléenne relue
check(Mel.needs_check(nil, "drill-a") == true, "40 : jamais contrôlée -> à lire")
check(Mel.needs_check("drill-a", "drill-a") == false, "40 : même nom -> pas relue")
check(Mel.needs_check("drill-a", "drill-b") == true, "40 : nom changé -> relue")
check(Mel.needs_check(true, "drill-a") == true, "40 : ancienne marque booléenne -> relue")
-- mutant : l'ancienne règle (not mel_ok) ne relit pas après un changement de nom
local function mutant(mel_ok, name) return not mel_ok end
check(mutant("drill-a", "drill-b") ~= Mel.needs_check("drill-a", "drill-b"), "40 : le mutant doit être tué")

if fails > 0 then print("blitz_c : " .. fails .. " echec(s)"); os.exit(1) end
print("blitz_c : OK")
