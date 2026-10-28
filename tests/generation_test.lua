--[[
  Tests hors jeu du lot ENERGIE : choix de la source d'énergie (shared/ai3/generation.lua). Usage : lua5.2 tests/generation_test.lua
  Vérifie : meilleur kW / coût choisi ; candidats écartés avec raison (gabarit, puissance, objet impossible, coût) ; déterminisme ;
  un générateur 3 fois meilleur ajouté aux données est choisi, son nom lu aux données ; MUTANTS.
]]
package.path = "./?.lua;" .. package.path
local G = require("shared.ai3.generation")
local A = require("shared.ai3.automatiser")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

section("1. Données réelles : la vapeur est le seul candidat posable")
local power = A.power_candidates()
check(#power == 1, "un candidat lu aux gabarits de pose (" .. #power .. ")")
local res = G.choose(power)
check(res.pick ~= nil, "un choix existe sur les données vanilla")
local steam = A.template(A.PLANT.gen, A.PLANT.args)
check(res.pick and math.abs(res.pick.kw - steam.out_kw) < 1e-6, "puissance lue au gabarit : " .. tostring(steam.out_kw) .. " kW")
check(steam.out_kw == 1800, "une chaudière et deux machines : 1 800 kW")

section("2. Règle pure")
local function c(name, kind, kw, cost, extra)
  local t = { name = name, kind = kind, kw = kw, cost = cost, template = true }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end
local base = { c("a", "x", 1800, { { "i", 100 } }), c("b", "y", 6000, { { "i", 100 } }), c("z", "x", 5000, { { "i", 1000 } }) }
local r = G.choose(base)
check(r.pick.name == "b", "kW / coût le plus haut : b")
check(r.ranked[1].name == "b" and r.ranked[2].name == "a" and r.ranked[3].name == "z", "classement par valeur décroissante")
local r2 = G.choose({ c("n", "reactor", 40000, { { "i", 10 } }, { template = false }), c("s", "gen", 1800, { { "i", 100 } }) })
check(r2.pick.name == "s" and r2.rejected[1].name == "n" and r2.rejected[1].reason:find("gabarit"), "sans gabarit de pose : écarté avec sa raison")
local r3 = G.choose({ c("n", "reactor", 40000, { { "i", 10 } }, { missing = { "uranium" } }), c("s", "gen", 1800, { { "i", 100 } }) })
check(r3.pick.name == "s" and r3.rejected[1].reason:find("uranium"), "objet impossible : écarté, l'objet est nommé")
local r4 = G.choose({ c("p", "solar", 0, { { "i", 10 } }) })
check(r4.pick == nil and r4.rejected[1].reason == "puissance nulle", "puissance nulle : écarté")
local r5 = G.choose({ c("q", "x", 100, {}) })
check(r5.pick == nil and r5.rejected[1].reason == "coût inconnu", "coût inconnu : écarté")
local r6 = G.choose({ c("b", "x", 100, { { "i", 10 } }), c("a", "x", 100, { { "i", 10 } }) })
check(r6.pick.name == "a", "égalité : le nom le plus petit")
local pr = function(o) return o == "rare" and 100 or 1 end
local r7 = G.choose({ c("a", "x", 1000, { { "rare", 10 } }), c("b", "x", 1000, { { "i", 100 } }) }, pr)
check(r7.pick.name == "b", "le prix des objets compte (rare cher)")
check(G.choose({}).pick == nil and G.choose(nil).pick == nil, "aucun candidat : aucun choix")
local d1, d2 = G.describe(G.choose(base)), G.describe(G.choose(base))
check(d1 == d2 and d1:find("choix b"), "description déterministe, nom lu aux données")

section("3. Généralisation : un générateur 3 fois meilleur ajouté aux données est choisi")
local more = {}
for _, x in ipairs(power) do more[#more + 1] = x end
more[#more + 1] = { name = "generateur-ajoute", kind = "generator", kw = power[1].kw * 3.5, cost = power[1].cost, template = true }
local rg = G.choose(more)
check(rg.pick.name == "generateur-ajoute", "le candidat ajouté est choisi : " .. tostring(rg.pick.name))
check(G.describe(rg):find("generateur%-ajoute"), "son nom est écrit au journal")

section("4. Mutants")
do
  local with, without = { c("n", "reactor", 40000, { { "i", 10 } }) }, { c("n", "reactor", 40000, { { "i", 10 } }, { template = false }) }
  check(G.choose(with).pick ~= nil and G.choose(without).pick == nil, "mutant « gabarit ignoré » : détecté")
  local cheap = { c("a", "x", 1800, { { "i", 1 } }), c("b", "x", 3000, { { "i", 1000 } }) }
  check(G.choose(cheap).pick.name == "a", "mutant « puissance brute seule » : détecté (le coût l'emporte)")
  local missing = { c("n", "reactor", 40000, { { "i", 10 } }, { missing = { "u" } }) }
  check(G.choose(missing).pick == nil, "mutant « objet impossible ignoré » : détecté")
  local shuffled = { base[3], base[1], base[2] }
  check(G.choose(shuffled).pick.name == G.choose(base).pick.name, "ordre d'entrée sans effet (déterminisme)")
end

print(string.format("[GENERATION] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
