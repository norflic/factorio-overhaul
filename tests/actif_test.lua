-- Lot COMPAGNONS-ACTIFS : règles pures de shared/team/actif.lua (peur = attaque en cours, retour rapide, délai d'affectation).
-- lua5.2 tests/actif_test.lua
package.path = "./?.lua;" .. package.path
local A = require("shared.team.actif")

local ok, ko = 0, 0
local function check(c, msg)
  if c then ok = ok + 1 else ko = ko + 1 print("  ECHEC : " .. msg) end
end

-- recent_deaths : seules les morts non « home » de moins de A.FEAR_TICKS, près de la polyligne, comptées une fois
local pts = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 20, y = 0 } }
local deaths = {
  { x = 5, y = 3, t = 1000 },             -- récente, près
  { x = 15, y = 2, t = 1000 - A.FEAR_TICKS }, -- ancienne
  { x = 10, y = 1, t = 1000, home = true }, -- au QG : jamais
  { x = 200, y = 200, t = 1000 },         -- loin de la route
}
check(A.recent_deaths(deaths, pts, 32, 1000) == 1, "une seule mort récente près de la route")
check(A.recent_deaths(deaths, pts, 32, 1000 + A.FEAR_TICKS) == 0, "plus de A.FEAR_TICKS : plus récente")
check(A.recent_deaths(nil, pts, 32, 1000) == 0, "sans morts : 0")
check(A.recent_deaths({ { x = 0, y = 31, t = 1000 } }, pts, 32, 1000) == 1, "à 31 tuiles d'un point : comptée")
check(A.recent_deaths({ { x = 0, y = 40, t = 1000 } }, pts, 32, 1000) == 0, "à 40 tuiles : non")

-- calm : tâche proche, morts de l'heure, aucune récente
check(A.calm(false, 2, 0) == true, "proche, 2 morts anciennes : jugée sans morts")
check(A.calm(true, 2, 0) == false, "lointaine : règle d'IA3-k gardée")
check(A.calm(false, 2, 1) == false, "attaque en cours (mort récente) : règle gardée")
check(A.calm(false, 0, 0) == false, "aucune mort : rien à changer")

-- calm_info : morts retirées, bloqué seulement si la menace seule bloque
local i = A.calm_info({ blocked = true, max_d = 900, goal_d = 900, deaths = 2, far = false }, 100, 50, 600)
check(i.deaths == 0 and i.blocked == false and i.max_d == 100 and i.goal_d == 50 and i.far == false, "entrée sans morts")
check(A.calm_info({ blocked = true }, 700, 0, 600).blocked == true, "menace seule au-dessus du seuil : bloqué")

-- retry : danger, fuite, abri -> A.RETRY_DANGER ; sinon la règle d'avant
check(A.retry("danger", false, 1800) == A.RETRY_DANGER and A.retry("fuite", true, 1800) == A.RETRY_DANGER
  and A.retry("abri", false, 1800) == A.RETRY_DANGER, "abandon pour danger : retour en 10 s")
check(A.retry("chemin", false, 1800) == 1800 and A.retry("chemin", true, 1800) == 3600 and A.retry(nil, false, 1800) == 1800,
  "autres échecs : 30 s, 60 s pour le fond")
check(A.RETRY_DANGER < 1800, "plus court qu'avant")

-- note_claim / report_line
local st = {}
A.note_claim(st, 30) A.note_claim(st, 600) A.note_claim(st, -5)
check(st.n == 3 and st.sum == 630 and st.max == 600 and st.fast == 2, "délais cumulés (négatif ramené à 0)")
local line = A.report_line("ecarlate", 36000, st, 2, 5, { calm = 3, calm_go = 2 })
check(line:find("[FO-ACTIF] ecarlate", 1, true) and line:find("2 PNJ libre", 1, true) and line:find("5 tache", 1, true)
  and line:find("moyen 3.5 s", 1, true) and line:find("max 10.0 s", 1, true), "ligne du bilan : " .. line)
check(A.report_line("x", 0, {}, 0, 0, {}):find("0 prise", 1, true) ~= nil, "bilan vide sans erreur")

-- Types du moteur seulement, triés (déterminisme)
for k = 2, #A.REPAIR_TYPES do check(A.REPAIR_TYPES[k - 1] < A.REPAIR_TYPES[k], "types triés") end
check(A.TURRET_REPAIR_BELOW > 60 and A.TURRET_REPAIR_BELOW <= 100, "seuil des tourelles au-dessus de celui de l'infrastructure")

-- Mutants : chaque règle fausse est vue
local function mutant(name, f)
  local saved = A[name]
  A[name] = f
  local seen = false
  if name == "calm" then seen = A.calm(true, 2, 0) == true or A.calm(false, 2, 1) == true end
  if name == "recent_deaths" then seen = A.recent_deaths(deaths, pts, 32, 1000 + A.FEAR_TICKS) ~= 0 end
  if name == "retry" then seen = A.retry("danger", false, 1800) ~= A.RETRY_DANGER end
  A[name] = saved
  check(seen, "mutant refusé : " .. name)
end
mutant("calm", function(far, d, r) return d > 0 end)
mutant("recent_deaths", function(dd, p, r, t) local n = 0 for _, d in ipairs(dd) do if not d.home then n = n + 1 end end return n end)
mutant("retry", function(fail, fond, base) return base end)

print(string.format("[ACTIF] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
