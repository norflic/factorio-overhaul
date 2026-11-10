--[[
  Lot HYGIENE-ACTIVE (décision du DC du 10/11) : règle pure du retrait d'un poteau (shared/team/hygiene_regle.lua).
    §1 Hr.feuille_retirable : feuille et isolé retirables ; refus par cause (box MAXED, projet non fini, pièce du plan, chaîne des
       foreuses, posé par un joueur, pas une feuille, consommateur propre, couvrant non alimenté) ; priorité des causes ;
    §2 Hr.sur_gisement_plan / Hr.candidats_ordonnes : le remplaçant hors gisement, libre, à portée de fil de TOUS les voisins, couvrant
       tous les consommateurs propres ; le plus proche ; déterminisme (candidats dans un autre ordre : même choix) ; causes dominantes ;
    §3 Hr.budget : 4 retraits par impulsion, reste ;
    §4 mutants : couvrant non alimenté accepté, projet non fini retiré, remplaçant hors portée accepté, budget ignoré : chacun refusé
       par les MÊMES détecteurs que les règles.
  Usage : lua5.2 tests/hygiene_regle_test.lua   (depuis la racine du mod ; moins d'une seconde)
]]
package.path = "./?.lua;" .. package.path
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function section(name) print("== " .. name) end

local Hr = require("shared.team.hygiene_regle")

---------------------------------------------------------------------------------------------------
-- Détecteurs partagés (règles et mutants passent par les MÊMES fonctions)
---------------------------------------------------------------------------------------------------
--- Une règle de feuille `rule` tient-elle les 4 engagements ? Rend la liste des manquements.
local function feuille_contrat(rule)
  local bad = {}
  local base = { fils = 1, consommateurs = 2, consommateurs_propres = 0, couvrant_alimente = true, projet_fini = true }
  local function with(over) local p = {} for k, v in pairs(base) do p[k] = v end for k, v in pairs(over) do p[k] = v end return p end
  if not rule(base) then bad[#bad + 1] = "feuille saine refusee" end
  if rule(with({ couvrant_alimente = false })) then bad[#bad + 1] = "couvrant non alimente accepte" end
  if rule(with({ projet_fini = false })) then bad[#bad + 1] = "projet non fini retire" end
  if rule(with({ consommateurs_propres = 1 })) then bad[#bad + 1] = "consommateur propre retire" end
  if rule(with({ fils = 2 })) then bad[#bad + 1] = "non-feuille retiree" end
  return bad
end

--- Un plan de remplacement `plan` tient-il ses engagements sur la scène de référence ? Rend la liste des manquements.
local scene = {
  sur_gisement = true, portee_fil = 7.5, portee_alim = 2.5,
  voisins = { { dx = -5, dy = 0 }, { dx = 4, dy = 3 } },
  couverts = { { dx = 2, dy = 0, w = 3, h = 3 } },
}
local function cands(list)
  local out = {}
  for _, c in ipairs(list) do out[#out + 1] = { dx = c[1], dy = c[2], hors_gisement = c[3], libre = c[4] } end
  return out
end
local function plan_contrat(plan)
  local bad = {}
  local function run(list) local p = {} for k, v in pairs(scene) do p[k] = v end p.candidats = cands(list) return plan(p) end
  -- (1, 0) : à 6 de (-5, 0) et à 4,24 de (4, 3) ; couvre la boîte 22..25 ? dx 2 ± 1,5 -> 0,5..3,5 ; 1 + 2,5 = 3,5 > 0,5 et 1 - 2,5 < 3,5 : oui
  local c = run({ { 1, 0, true, true } })
  if not (c and c.dx == 1 and c.dy == 0) then bad[#bad + 1] = "candidat valable refuse" end
  -- hors portée du premier voisin : (4, 0) est à 9 de (-5, 0) (et couvre bien la boîte : 4 - 2,5 = 1,5 < 3,5)
  if run({ { 4, 0, true, true } }) then bad[#bad + 1] = "remplacant hors portee accepte" end
  -- sur gisement
  if run({ { 1, 0, false, true } }) then bad[#bad + 1] = "remplacant sur gisement accepte" end
  -- place prise
  if run({ { 1, 0, true, false } }) then bad[#bad + 1] = "place prise acceptee" end
  -- couverture perdue : (-2, 0) couvre-t-il 0,5..3,5 ? -2 + 2,5 = 0,5 : intervalle ouvert, non
  if run({ { -2, 0, true, true } }) then bad[#bad + 1] = "couverture perdue acceptee" end
  return bad
end

--- Un budget `budget` tient-il ses engagements ?
local function budget_contrat(budget)
  local bad = {}
  local cfg = { max_retraits = 4 }
  local ok, reste = budget(0, cfg)
  if not (ok and reste == 4) then bad[#bad + 1] = "budget neuf" end
  ok, reste = budget(3, cfg)
  if not (ok and reste == 1) then bad[#bad + 1] = "budget a 3" end
  ok, reste = budget(4, cfg)
  if ok or reste ~= 0 then bad[#bad + 1] = "budget epuise accepte" end
  ok, reste = budget(9, cfg)
  if ok or reste ~= 0 then bad[#bad + 1] = "budget depasse accepte" end
  return bad
end

---------------------------------------------------------------------------------------------------
section("§1 Hr.feuille_retirable")
---------------------------------------------------------------------------------------------------
local ok, why = Hr.feuille_retirable({ fils = 1, consommateurs = 1, consommateurs_propres = 0, couvrant_alimente = true })
check(ok and why == "feuille", "feuille au couvrant alimenté : retirable (" .. tostring(why) .. ")")
ok, why = Hr.feuille_retirable({ fils = 0, consommateurs = 0, consommateurs_propres = 0 })
check(ok and why == "isole", "poteau isolé sans consommateur : retirable, cause « isole »")
ok, why = Hr.feuille_retirable({ fils = 0, consommateurs = 0, consommateurs_propres = 0, projet_fini = true })
check(ok, "projet_fini = vrai (hors de tout projet) ne bloque pas")
ok, why = Hr.feuille_retirable({ fils = 1, consommateurs = 1, consommateurs_propres = 0, couvrant_alimente = false })
check(not ok and why == "couvrant non alimente", "couvrant non alimenté : refus (" .. tostring(why) .. ")")
ok, why = Hr.feuille_retirable({ fils = 1, consommateurs = 0, consommateurs_propres = 0, couvrant_alimente = false })
check(ok, "aucun consommateur : le couvrant n'a pas à être alimenté")
ok, why = Hr.feuille_retirable({ fils = 1, consommateurs = 1, consommateurs_propres = 1, couvrant_alimente = true })
check(not ok and why == "consommateur propre", "consommateur propre : refus")
ok, why = Hr.feuille_retirable({ fils = 2, consommateurs = 0, consommateurs_propres = 0 })
check(not ok and why == "pas une feuille", "deux fils : pas une feuille")
ok, why = Hr.feuille_retirable({ fils = 0, projet_fini = false })
check(not ok and why == "projet non fini", "projet non fini : refus")
ok, why = Hr.feuille_retirable({ fils = 0, piece_plan = true })
check(not ok and why == "piece du plan", "pièce bâtie d'un plan fini : refus (le réseau vivant la reposerait)")
ok, why = Hr.feuille_retirable({ fils = 0, chaine_foreuses = true })
check(not ok and why == "chaine des foreuses", "chaîne des foreuses : refus")
ok, why = Hr.feuille_retirable({ fils = 0, box_maxed = true })
check(not ok and why == "box MAXED", "box MAXED : refus")
ok, why = Hr.feuille_retirable({ fils = 0, pose_par_joueur = true })
check(not ok and why == "pose par un joueur", "poteau posé par un joueur : refus")
ok, why = Hr.feuille_retirable({ fils = 5, box_maxed = true, projet_fini = false, consommateurs_propres = 3 })
check(not ok and why == "box MAXED", "priorité des causes : la structurelle d'abord (" .. tostring(why) .. ")")
check(#feuille_contrat(Hr.feuille_retirable) == 0, "contrat de la feuille tenu : " .. table.concat(feuille_contrat(Hr.feuille_retirable), ", "))

---------------------------------------------------------------------------------------------------
section("§2 Hr.sur_gisement_plan / Hr.candidats_ordonnes")
---------------------------------------------------------------------------------------------------
check(#plan_contrat(Hr.sur_gisement_plan) == 0, "contrat du remplaçant tenu : " .. table.concat(plan_contrat(Hr.sur_gisement_plan), ", "))
local p = {}
for k, v in pairs(scene) do p[k] = v end
p.candidats = cands({ { 1, 1, true, true }, { 1, 0, true, true }, { -1, 0, false, true }, { 2, 0, true, false }, { -3, 0, true, true } })
local c = Hr.sur_gisement_plan(p)
check(c and c.dx == 1 and c.dy == 0, "le plus proche des valables : (1, 0) (" .. tostring(c and c.dx) .. ", " .. tostring(c and c.dy) .. ")")
-- déterminisme : les mêmes candidats dans l'ordre inverse
local rev = {}
for i = #p.candidats, 1, -1 do rev[#rev + 1] = p.candidats[i] end
p.candidats = rev
local c2 = Hr.sur_gisement_plan(p)
check(c2 and c2.dx == 1 and c2.dy == 0, "ordre inverse des candidats : même choix")
-- égalité de distance : dx puis dy croissants
p.candidats = cands({ { 0, 1, true, true }, { 1, 0, true, true }, { 0, -1, true, true } })
c = Hr.sur_gisement_plan(p)
-- (0, -1) : à 5,1 de (-5, 0), à 5,66 de (4, 3) ; couvre 0,5..3,5 × -1,5..1,5 ? x : 0 + 2,5 > 0,5 et 0 - 2,5 < 3,5 ; y : -1 + 2,5 > -1,5 et -1 - 2,5 < 1,5 : oui
check(c and c.dx == 0 and c.dy == -1, "égalité de distance : dx puis dy croissants -> (0, -1) (" .. tostring(c and c.dx) .. ", " .. tostring(c and c.dy) .. ")")
-- causes
local _, cause = Hr.sur_gisement_plan({ sur_gisement = false })
check(cause == "pas sur gisement", "pas sur gisement : " .. tostring(cause))
_, cause = Hr.sur_gisement_plan({ sur_gisement = true, voisins = {}, candidats = cands({ { 1, 0, true, true } }) })
check(cause == "aucun voisin de fil", "sans voisin : c'est une feuille, pas un remplacement (" .. tostring(cause) .. ")")
_, cause = Hr.sur_gisement_plan({ sur_gisement = true, voisins = scene.voisins, candidats = {} })
check(cause == "aucun candidat", "aucun candidat : " .. tostring(cause))
p.candidats = cands({ { 1, 0, false, true }, { 1, 1, false, true }, { -3, 0, true, true } })
_, cause = Hr.sur_gisement_plan(p)
check(cause == "remplacant : sur gisement", "cause dominante (2 sur gisement, 1 hors portée) : " .. tostring(cause))
p.candidats = cands({ { 1, 0, nil, nil } })
_, cause = Hr.sur_gisement_plan(p)
check(cause == "remplacant : sur gisement", "champs du moteur absents : refusés en strict (" .. tostring(cause) .. ")")
-- candidats ordonnés (géométrie seule, champs du moteur inconnus laissés au moteur)
local list, refus = Hr.candidats_ordonnes({ voisins = scene.voisins, portee_fil = 7.5, portee_alim = 2.5, couverts = scene.couverts,
  candidats = { { dx = 3, dy = 0 }, { dx = 1, dy = 0 }, { dx = -3, dy = 0 }, { dx = 1, dy = 1 }, { dx = -2, dy = 0 } } })
check(#list == 2 and list[1].dx == 1 and list[1].dy == 0 and list[2].dx == 1 and list[2].dy == 1,
  "candidats géométriques triés du plus proche au plus loin ; (3, 0) et (-3, 0) hors portée d'un voisin (" .. #list .. ")")
check(refus["hors portee de fil"] == 2 and refus["couverture perdue"] == 1, "rejets comptés par cause")
-- un remplaçant qui ne relie qu'un voisin sur deux n'est jamais retenu (topologie conservée)
p.candidats = cands({ { -1, 2, true, true } }) -- à 4,5 de (-5, 0), à 5,1 de (4, 3) : couvre (x : -1 + 2,5 = 1,5 > 0,5) -> valable
check(Hr.sur_gisement_plan(p) ~= nil, "candidat qui relie les deux voisins et couvre : retenu")
p.candidats = cands({ { 1, -4, true, true } }) -- à 7,2 de (-5, 0), à 7,6 de (4, 3) : un seul voisin relié ; couvre (y : -4 + 2,5 = -1,5 : non)
check(Hr.sur_gisement_plan(p) == nil, "un seul voisin relié sur deux : refus")

---------------------------------------------------------------------------------------------------
section("§3 Hr.budget")
---------------------------------------------------------------------------------------------------
check(#budget_contrat(Hr.budget) == 0, "contrat du budget tenu : " .. table.concat(budget_contrat(Hr.budget), ", "))
check(Hr.CFG.max_retraits == 4, "4 retraits par impulsion (prudence, mesure au banc)")
check(Hr.CFG.max_sondes >= 8, "au moins 8 sondes du moteur par poteau")
local b_ok, b_reste = Hr.budget(2)
check(b_ok and b_reste == 2, "cfg absent : Hr.CFG")

---------------------------------------------------------------------------------------------------
section("§4 mutants")
---------------------------------------------------------------------------------------------------
-- (m1) couvrant non alimenté accepté
local function m1(p) local q = {} for k, v in pairs(p) do q[k] = v end q.couvrant_alimente = true return Hr.feuille_retirable(q) end
local bad = feuille_contrat(m1)
check(#bad == 1 and bad[1] == "couvrant non alimente accepte", "mutant m1 (couvrant non alimenté accepté) détecté : " .. table.concat(bad, ", "))
-- (m2) projet non fini retiré
local function m2(p) local q = {} for k, v in pairs(p) do q[k] = v end q.projet_fini = nil return Hr.feuille_retirable(q) end
bad = feuille_contrat(m2)
check(#bad == 1 and bad[1] == "projet non fini retire", "mutant m2 (projet non fini retiré) détecté : " .. table.concat(bad, ", "))
-- (m3) remplaçant hors portée : la portée de fil n'est plus exigée
local function m3(p) local q = {} for k, v in pairs(p) do q[k] = v end q.portee_fil = 1000 return Hr.sur_gisement_plan(q) end
bad = plan_contrat(m3)
check(#bad == 1 and bad[1] == "remplacant hors portee accepte", "mutant m3 (remplaçant hors portée) détecté : " .. table.concat(bad, ", "))
-- (m3 bis) couverture non exigée
local function m3b(p) local q = {} for k, v in pairs(p) do q[k] = v end q.couverts = {} return Hr.sur_gisement_plan(q) end
bad = plan_contrat(m3b)
check(#bad == 1 and bad[1] == "couverture perdue acceptee", "mutant m3 bis (couverture perdue) détecté : " .. table.concat(bad, ", "))
-- (m4) budget ignoré
local function m4(n, cfg) return true, math.max(0, cfg.max_retraits - n) end
bad = budget_contrat(m4)
check(#bad == 2 and bad[1] == "budget epuise accepte", "mutant m4 (budget ignoré) détecté : " .. table.concat(bad, ", "))

print(string.format("hygiene_regle_test : %d OK, %d ECHEC", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
