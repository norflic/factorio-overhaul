--[[
  Sprint s40, grappe « champ » : règles pures ajoutées à shared/team/champ.lua et shared/team/foreuse_swap.lua, et leur branchement
  (lecture du texte des scripts). Lancement : lua5.2 tests/s40_champ_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(c, msg) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end end
local function read(p) local h = assert(io.open(p, "rb")); local s = h:read("*a"); h:close(); return s end

local Ch = require("shared.team.champ")
local mig = read("script/team/migration_champ.lua")

-- p1 : bandes écartées relues à la fin de l'ordre
check(Ch.bad_round(2, 1, nil) == true, "p1 : des bandes écartées, une bande produit, aucun tour encore : relire")
check(Ch.bad_round(0, 3, nil) == false, "p1 : aucune bande écartée : fin comme avant")
check(Ch.bad_round(2, 0, nil) == false, "p1 : rien n'a produit : fin comme avant (Th.order_end décide : replanifier ou abandon)")
check(Ch.bad_round(2, 1, 1) == false, "p1 : le dernier tour n'a posé aucune bande de plus : fin (pas de boucle)")
check(Ch.bad_round(1, 2, 1) == true, "p1 : une bande de plus depuis le dernier tour : relire encore")
check(Ch.bad_round(nil, nil, nil) == false, "p1 : entrées absentes : fin")
check(mig:find("Ch.bad_round(#(st.bad or {}), st.produced, st.bad_at)", 1, true) ~= nil, "p1 : begin_band lit la règle à l'ordre épuisé")
check(mig:find("st.bad, st.bad_at = nil, st.produced", 1, true) ~= nil, "p1 : le tour vide st.bad et date le tour")

print(string.format("[S40-CHAMP] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
