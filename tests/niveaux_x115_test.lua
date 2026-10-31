--[[
  Lot EQUILIBRE (retour du DC du 31/10) : « x1.15 de stats par niveau et non par âge » pour les défenses, les fours, les
  foreuses et la vie des bâtiments ; portée des tourelles augmentée. Lit shared/levels/config.lua. Pur Lua.
  Usage : lua5.2 tests/niveaux_x115_test.lua
]]
package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")
local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end

local function stat(fam, last, op)
  for _, st in ipairs(L.families[L.by_key[fam].index].stats) do
    if st.path[#st.path] == last then return st end
  end
end

--- Règle : la statistique `st` vaut v1 × 1,15^(n-1) à chaque niveau (rapport 1,15 entre deux niveaux consécutifs).
local function est_x115(st, apply)
  if not st then return false, "statistique absente" end
  for n = 2, 30 do
    local r = apply(st, 100, n) / apply(st, 100, n - 1)
    if math.abs(r - 1.15) > 1e-9 then return false, "niveau " .. n .. " : rapport " .. r end
  end
  return true
end

local regle = {
  { "gun", "max_health" }, { "laser", "max_health" }, { "wall", "max_health" }, { "drill", "max_health" },
  { "furnace", "max_health" }, { "assembler", "max_health" }, { "drill", "mining_speed" }, { "furnace", "crafting_speed" }, { "assembler", "crafting_speed" },
}
for _, r in ipairs(regle) do
  local ok, why = est_x115(stat(r[1], r[2]), L.apply_stat)
  check(ok, r[1] .. " " .. r[2] .. " : x1,15 par niveau", why)
end
-- le centre : 15 niveaux
do
  local st = stat("command", "max_health")
  check(math.abs(L.apply_stat(st, 3000, 15) / 3000 - 1.15 ^ 14) < 1e-9, "centre : vie x1,15 par niveau (niveau 15 = x7,07)")
end
-- dégâts : table livrée = 1,15^(n-1) arrondi
local D = require("shared.tirs.degats")
for _, k in ipairs({ "gun", "laser" }) do
  local st = stat(k, "damage_modifier")
  local ok = true
  for n = 1, 30 do if math.abs(L.apply_stat(st, 1, n) - 1.15 ^ (n - 1)) > 0.006 * 1.15 ^ (n - 1) + 0.006 then ok = false end end
  check(ok, k .. " : dégâts x1,15 par niveau (à l'arrondi du centième)")
end
check(math.abs(D.mult(30) - 57.58) < 1e-9, "dégâts niveau 30 : x57,58")
-- portée : plus grande qu'avant (0,25 par niveau) et bornée
for _, k in ipairs({ "gun", "laser" }) do
  local st = stat(k, "range")
  check(st.op == "add" and st.k > 0.25 and st.k <= 0.5, k .. " : portée par niveau entre 0,25 (exclu) et 0,5")
end
-- énergie : plus lente que la vitesse (le niveau ne devient pas gratuit)
for _, k in ipairs({ "drill", "furnace" }) do
  local e = stat(k, "energy_usage")
  local v = stat(k, k == "drill" and "mining_speed" or "crafting_speed")
  check(L.apply_stat(e, 1, 30) < L.apply_stat(v, 1, 30) and L.apply_stat(e, 1, 30) > 1, k .. " : puissance < vitesse au niveau 30")
end
-- déterminisme : mêmes résultats d'un appel à l'autre, sans appel de puissance
check(L.apply_stat(stat("gun", "max_health"), 400, 30) == L.apply_stat(stat("gun", "max_health"), 400, 30), "déterminisme")

-- Cadence de plan des gabarits : la courbe d'avant, toujours au plus la cadence réelle
for _, c in ipairs({ { "drill", "mining_speed", 0.10 }, { "furnace", "crafting_speed", 0.08 }, { "assembler", "crafting_speed", 0.08 } }) do
  local st = stat(c[1], c[2])
  check(math.abs(L.plan_stat(st, 1, 7) - (1 + c[3] * 6)) < 1e-9, c[1] .. " : plan du niveau 7 = courbe d'avant")
  for n = 1, 30 do if L.plan_stat(st, 1, n) > L.apply_stat(st, 1, n) + 1e-9 then check(false, c[1] .. " : plan au-dessus du reel au niveau " .. n) end end
end
check(L.plan_stat(stat("gun", "max_health"), 400, 2) == L.apply_stat(stat("gun", "max_health"), 400, 2), "sans plan : la statistique")

-- Faisceau du laser (max_length vanilla 24) : portée incluse, niveau 1 inchangé, entier
check(L.beam_length(24, 24) == 24, "faisceau : portee 24 dans 24, inchange")
check(L.beam_length(20, 24) == 24, "faisceau : portee plus courte, inchange")
check(L.beam_length(35.6, 24) == 38, "faisceau : portee 35,6 -> 38")
check(L.beam_length(40, 24) >= 40 and L.beam_length(40, 24) % 1 == 0, "faisceau : atteint la portee, entier")

-- Mutants : l'ancien comportement doit être refusé
local anciens = {
  { "vie lineaire +15 %", { op = "mul", k = 0.15, path = { "max_health" } } },
  { "vie lineaire +20 %", { op = "mul", k = 0.20, path = { "max_health" } } },
  { "x1,15 par age (deux niveaux)", { op = "pow", k = 0.0724, path = { "max_health" } } },
  { "x1,10 par niveau", { op = "pow", k = 0.10, path = { "max_health" } } },
}
for _, m in ipairs(anciens) do
  check(not est_x115(m[2], L.apply_stat), "mutant refuse : " .. m[1])
end
print(string.format("[X115] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
