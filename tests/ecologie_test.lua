-- Lot ECOLOGIE-5 : mise à l'échelle des réglages de carte au nombre d'équipes (shared/faction/ecologie.lua).
package.path = "./?.lua;" .. package.path
local E = require("shared.faction.ecologie")
local ok, fail = 0, 0
local function check(c, m) if c then ok = ok + 1 else fail = fail + 1; print("ECHEC " .. m) end end
local function ms()
  return { enemy_evolution = { pollution_factor = 9e-7 }, pollution = { enemy_attack_pollution_consumption_modifier = 1, ageing = 1 },
    enemy_expansion = { min_expansion_cooldown = 14400, max_expansion_cooldown = 216000 } }
end
local function near(a, b) return math.abs(a - b) <= 1e-12 * math.max(1, math.abs(b)) end
local m = ms()
local s = E.apply(m, 5, nil)
check(s == 5, "echelle 5")
check(near(m.enemy_evolution.pollution_factor, 9e-7 / 5), "evolution / 5")
check(near(m.pollution.enemy_attack_pollution_consumption_modifier, 5), "consommation x 5")
check(near(m.pollution.ageing, 2), "vieillissement x 2")
check(m.enemy_expansion.min_expansion_cooldown == 28800 and m.enemy_expansion.max_expansion_cooldown == 432000, "delais x 2")
-- idempotent : la même échelle ne multiplie pas deux fois
s = E.apply(m, 5, s)
check(near(m.enemy_evolution.pollution_factor, 9e-7 / 5) and near(m.pollution.ageing, 2), "pas deux fois")
-- passage à 3 équipes puis retour à 1 : retour exact aux valeurs de la carte
s = E.apply(m, 3, s)
check(near(m.enemy_evolution.pollution_factor, 9e-7 / 3) and near(m.pollution.enemy_attack_pollution_consumption_modifier, 3), "5 -> 3")
check(near(m.pollution.ageing, 2), "vieillissement garde a 3")
s = E.apply(m, 1, s)
local r = ms()
check(near(m.enemy_evolution.pollution_factor, r.enemy_evolution.pollution_factor) and near(m.pollution.ageing, 1)
  and m.enemy_expansion.min_expansion_cooldown == 14400 and m.enemy_expansion.max_expansion_cooldown == 216000, "retour a la carte")
-- carte réglée par le joueur : relatif à ses valeurs
local c = ms(); c.pollution.ageing = 0.5
E.apply(c, 5, nil)
check(near(c.pollution.ageing, 1), "relatif a la carte")
check(E.factors(1, nil) == nil, "une equipe : rien")
print(string.format("ecologie_test : %d OK, %d ECHEC(S)", ok, fail))
if fail > 0 then os.exit(1) end
