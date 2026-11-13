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

-- p2 : un refus du plan ne ferme pas un champ qui porte des bandes
check(Ch.refuse_goes_on(true, "refuse", true, 1, 0) == true, "p2 : cadre, refus, bande écartée, une partie migrée : la suivante part")
check(Ch.refuse_goes_on(true, "refuse", true, 0, 2) == true, "p2 : cadre, refus, bande écartée, des bandes produisent : la suivante part")
check(Ch.refuse_goes_on(true, "refuse", true, 0, 0) == false, "p2 : rien de migré ni produit : abandon et pause comme avant")
check(Ch.refuse_goes_on(true, "refuse", false, 1, 1) == false, "p2 : plafond des bandes écartées atteint : fermeture comme avant (pas de boucle)")
check(Ch.refuse_goes_on(true, "annule", true, 1, 1) == false, "p2 : autre cause qu'un refus du plan : comme avant")
check(Ch.refuse_goes_on(false, "refuse", true, 1, 1) == false, "p2 : treillis sans cadre : comme avant")
check(mig:find("local goes_on = Ch.refuse_goes_on(st.frame ~= nil, why, recorded, st.done, st.produced)", 1, true) ~= nil, "p2 : failed() lit la règle")
check(mig:find("if st.fails >= CFG.max_fails and goes_on then", 1, true) ~= nil and mig:find("elseif st.fails >= CFG.max_fails then", 1, true) ~= nil,
  "p2 : la fermeture ne vient qu'après la règle")
check(mig:find("st.bad[#st.bad + 1] = st.band_key; recorded = true", 1, true) ~= nil, "p2 : « écartée » n'est vrai que sous le plafond CFG.max_bad")

-- p3 : table des nouveaux essais du remplacement purgée
local S = require("shared.team.foreuse_swap")
local exp = S.retry_expired({ ["3:4"] = 100, ["1:2"] = 50, ["9:9"] = 101, ["5:5"] = 7 }, 100)
check(#exp == 3 and exp[1] == "1:2" and exp[2] == "3:4" and exp[3] == "5:5", "p3 : entrées échues (tick <= maintenant), triées ; l'entrée à venir reste")
check(#S.retry_expired({}, 10) == 0 and #S.retry_expired(nil, 10) == 0, "p3 : table vide ou absente")
check(#S.retry_expired({ a = 11 }, 10) == 0, "p3 : essai encore retenu (t0 < retry) : gardé")
local sw = read("script/team/foreuse_swap.lua")
check(sw:find("for _, k in ipairs(S.retry_expired(st.retry, tick)) do st.retry[k] = nil end", 1, true) ~= nil, "p3 : Swap.think purge au départ d'une passe")

print(string.format("[S40-CHAMP] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
