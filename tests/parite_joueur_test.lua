-- joueur-parite : règle pure du journal [FO-PARITE-JOUEUR] (shared/team/parite_joueur.lua). lua5.2 tests/parite_joueur_test.lua
package.path = "./?.lua;" .. package.path
local P = require("shared.team.parite_joueur")
local pass, fail = 0, 0
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1 print("  ECHEC : " .. m) end end
local rows = {
  { key = "amber", workers = 8, outposts = 4, drills = 30, smelters = 4, techs = 10 },
  { key = "azure", workers = 9, outposts = 5, drills = 35, smelters = 6, techs = 11 },
  { key = "player", workers = 13, outposts = 6, drills = 41, smelters = 8, techs = 12 },
}
local avg = P.average(rows)
check(avg.n == 2 and avg.workers == 8.5 and avg.drills == 32.5 and avg.techs == 10.5, "moyenne des factions seules")
local line = P.line(rows, 30.4)
check(line:find("minute 30", 1, true) and line:find("votre equipe workers=13 outposts=6 drills=41", 1, true), "ligne : votre equipe")
check(line:find("moyenne de 2 faction(s) workers=8.5", 1, true) ~= nil, "ligne : moyenne")
check(P.line({ rows[1] }, 5) == nil, "sans votre equipe : aucune ligne")
check(P.average({ rows[3] }) == nil and P.line({ rows[3] }, 5):find("moyenne de 0 faction(s) -", 1, true) ~= nil, "sans faction : moyenne absente")
print(string.format("[PARITE-JOUEUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
