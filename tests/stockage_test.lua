--[[
  Lot STOCKAGE (remarque du DC du 5/11, essai 0.6.53, 177 min : « les coffres restent des coffres en fer et pas en acier [...] il y a visiblement une
  limite en fait de coffres posés [...] les ressources se posent par terre [...] Il n'y a pas d'utilisation logique infinie de coffres ») :
  banc HORS JEU de la décision « que faire quand le stock se remplit ».
  Cas construits sur la partie du DC (fo-logs/2026-11-05_PARTIE-DC-ESSAI/factorio-current-2032.log) : coffre du QG 96 cases, annexes de 32 cases
  (coffre en fer), bloc de 48 places, 197 à 234 coffres en fer EN MAIN de 130 à 166 min, stock 1 472 / 1 472 cases à 172 min.
  Lancement : lua5.2 tests/stockage_test.lua (racine du mod, moins d'une seconde).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local A = require("shared.team.annexe")
local ok_sg, Sg = pcall(require, "shared.team.stockage")
if not ok_sg then Sg = nil end

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

-- Échelle des coffres d'annexe, du plus grand au plus petit (données : { cases }). Indices : 1 acier (48), 2 fer (32), 3 bois (16).
local LADDER = { { slots = 48 }, { slots = 32 }, { slots = 16 } }

--- Décision de la règle d'AVANT (production : shared/team/annexe.lua + T.annex, et Stock.grow de script/team/stock.lua) sur un cas : un coffre
--- n'est POSÉ que si A.need_chest le demande ET qu'une place du bloc est libre (sinon : « bloque », nouvel essai dans T.annex.retry ticks).
local function old_rule(c)
  if not A.need_chest(c.used, c.size, c.n, c.early, c.cap) then return "rien" end
  if (c.free_places or 0) <= 0 then return "bloque" end
  return "poser"
end

-- Cas DC : 172 min, 46 annexes en fer (bloc de 48 places : 2 places occupées par d'autres bâtiments), stock plein, dépôt refusé, 234 coffres en
-- fer en main, aucun en acier.
local DC = { used = 1568, size = 1568, n = 46, cap = 48, free_places = 0, early = true, hand = { 0, 234, 0 }, makeable = { true, true, true },
  annexes = { [2] = 46 } }
-- Cas DC avec de l'acier en main : les coffres en fer doivent passer en acier.
local DC_STEEL = { used = 1568, size = 1568, n = 46, cap = 48, free_places = 0, early = true, hand = { 10, 234, 0 }, makeable = { true, true, true },
  annexes = { [2] = 46 } }
-- Bloc plein de coffres en ACIER : il faut un anneau de plus.
local FULL_STEEL = { used = 2400, size = 2400, n = 48, cap = 48, free_places = 0, early = true, hand = { 5, 100, 0 }, makeable = { true, true, true },
  annexes = { [1] = 48 } }
-- Rien en main, stock plein : fabriquer le meilleur coffre fabricable.
local EMPTY_HAND = { used = 800, size = 800, n = 20, cap = 48, free_places = 28, early = true, hand = { 0, 0, 0 }, makeable = { true, true, true },
  annexes = { [2] = 20 } }
-- Stock à 50 % sans dépôt refusé : rien.
local CALM = { used = 400, size = 800, n = 20, cap = 48, free_places = 28, early = false, hand = { 0, 50, 0 }, makeable = { true, true, true },
  annexes = { [2] = 20 } }
-- Places libres, acier et fer en main : poser l'ACIER (le plus grand).
local FREE_BOTH = { used = 700, size = 800, n = 20, cap = 48, free_places = 28, early = false, hand = { 3, 50, 0 }, makeable = { true, true, true },
  annexes = { [2] = 20 } }

---------------------------------------------------------------------------------------------------
section("1. Règle d'avant (production) sur les cas du DC : constat (test ROUGE du lot : fo-logs/2026-11-05_STOCKAGE/test_rouge.txt, 27709509)")
---------------------------------------------------------------------------------------------------
check(old_rule(DC) == "bloque", "constat : stock plein, bloc saturé, coffres en fer en main : la règle d'avant ne pose RIEN (" .. old_rule(DC) .. ")")
check(old_rule({ used = 1600, size = 1600, n = 48, cap = 48, free_places = 0, early = true }) == "rien",
  "constat : 48 annexes, la règle d'avant ne demande même plus de coffre (plafond T.annex.max = " .. T.annex.max .. ")")
check(T.annex.kinds[1].slots == 32 and #T.annex.kinds == 2, "constat : l'échelle d'avant est fer (32 cases) puis bois (16), sans acier (48)")

---------------------------------------------------------------------------------------------------
section("2. Règle du lot (shared/team/stockage.lua)")
---------------------------------------------------------------------------------------------------
if not check(Sg ~= nil, "module shared/team/stockage.lua présent") then
  print(string.format("[STOCKAGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
  os.exit(1)
end
local function d(c) return Sg.decide(c, LADDER) end
local a1, k1 = d(DC)
check(a1 == "anneau", "DC (fer partout, fer seul en main, bloc plein) : un anneau de plus (" .. tostring(a1) .. ")")
local a2, k2 = d(DC_STEEL)
check(a2 == "ameliorer" and k2 == 1, "DC avec de l'acier en main : un coffre en fer passe en ACIER (" .. tostring(a2) .. ", " .. tostring(k2) .. ")")
local a3 = d(FULL_STEEL)
check(a3 == "anneau", "bloc plein de coffres en acier : un anneau de plus (" .. tostring(a3) .. ")")
local a4, k4 = d(EMPTY_HAND)
check(a4 == "fabriquer" and k4 == 1, "rien en main : fabriquer le plus grand coffre fabricable, l'acier (" .. tostring(a4) .. ", " .. tostring(k4) .. ")")
check(d(CALM) == "rien", "stock à 50 % sans dépôt refusé : rien")
local a6, k6 = d(FREE_BOTH)
check(a6 == "poser" and k6 == 1, "places libres, acier et fer en main : poser l'acier (" .. tostring(a6) .. ", " .. tostring(k6) .. ")")
-- sans acier fabricable ni en main (recette fermée), bloc plein de fer : un anneau, jamais une « amélioration » vers le fer
local a7 = d({ used = 1568, size = 1568, n = 48, cap = 48, free_places = 0, early = true, hand = { 0, 40, 0 }, makeable = { false, true, true },
  annexes = { [2] = 48 } })
check(a7 == "anneau", "bloc plein de fer, acier ni en main ni fabricable : un anneau (" .. tostring(a7) .. ")")
-- un bloc de bois, du fer en main : le bois passe en fer
local a8, k8 = d({ used = 900, size = 900, n = 48, cap = 48, free_places = 0, early = true, hand = { 0, 40, 0 }, makeable = { false, true, true },
  annexes = { [3] = 10, [2] = 38 } })
check(a8 == "ameliorer" and k8 == 2, "bloc plein avec des coffres en bois, du fer en main : le bois passe en fer (" .. tostring(a8) .. ", " .. tostring(k8) .. ")")
-- anneaux : places du 2e anneau plus loin que le 1er, aucune place commune ; borne
local r1, r2 = Sg.ring_slots(1, 1, 1, 1), Sg.ring_slots(1, 1, 1, 2)
local seen, common, far1, near2 = {}, 0, 0, 1e9
for _, p in ipairs(r1) do seen[p[1] .. ":" .. p[2]] = true; far1 = math.max(far1, math.abs(p[2])) end
for _, p in ipairs(r2) do if seen[p[1] .. ":" .. p[2]] then common = common + 1 end; near2 = math.min(near2, math.abs(p[2])) end
check(#r1 == A.capacity(1, 1, 1) and #r2 > 0 and common == 0 and near2 > far1,
  "anneau 1 = le bloc d'avant (" .. #r1 .. " places) ; anneau 2 plus loin, sans place commune (" .. #r2 .. " places)")
check(Sg.capacity(1, 1, 1, 3) == #r1 + #r2 + #Sg.ring_slots(1, 1, 1, 3), "capacité = somme des anneaux ouverts")
-- fabrication en parallèle : l'acier fabricable et plus grand que le fer en main ; rien quand l'acier est déjà en main ou pas fabricable
check(Sg.craft(DC, LADDER) == 1, "DC : de la place tout de suite (anneau, coffres en fer en main) ET l'acier fabriqué en parallèle")
check(Sg.craft(DC_STEEL, LADDER) == nil and Sg.craft(CALM, LADDER) == nil, "acier déjà en main, ou stock calme : rien à fabriquer")
check(Sg.craft({ used = 1568, size = 1568, n = 48, cap = 48, free_places = 0, early = true, hand = { 0, 40, 0 }, makeable = { false, true, true },
  annexes = { [2] = 48 } }, LADDER) == nil, "acier non fabricable, bloc de fer : rien de plus grand à fabriquer")
local plafond = Sg.capacity(1, 1, 1, Sg.MAX_RINGS)
check(plafond >= 5 * 48 and d({ used = 9000, size = 9000, n = plafond, cap = plafond, free_places = 0, early = true, hand = { 5, 0, 0 },
  makeable = { true, true, true }, annexes = { [1] = plafond }, rings = Sg.MAX_RINGS }) == "rien",
  "borne de sécurité : " .. Sg.MAX_RINGS .. " anneaux, " .. plafond .. " coffres (" .. plafond * 48 .. " cases en acier)")

---------------------------------------------------------------------------------------------------
section("3. Mutants de la règle du lot")
---------------------------------------------------------------------------------------------------
local f0 = io.open("shared/team/stockage.lua", "rb")
local SRC = f0:read("*a")
f0:close()
local function facts(M)
  local function dd(c) local a, k = M.decide(c, LADDER) return tostring(a) .. ":" .. tostring(k) end
  return table.concat({ dd(DC), dd(DC_STEEL), dd(FULL_STEEL), dd(EMPTY_HAND), dd(CALM), dd(FREE_BOTH),
    dd({ used = 9000, size = 9000, n = 240, free_places = 0, early = true, hand = { 5, 0, 0 }, makeable = { true, true, true },
      annexes = { [1] = 240 }, rings = M.MAX_RINGS }),
    tostring(M.craft(DC, LADDER)), tostring(M.craft(DC_STEEL, LADDER)), tostring(#M.ring_slots(1, 1, 1, 2)),
    tostring(M.ring_slots(1, 1, 1, 2)[1][2]) }, "|")
end
local F0 = facts(Sg)
local function mutate(from, to)
  local s2, n = SRC:gsub(from:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), (to:gsub("%%", "%%%%")), 1)
  assert(n == 1, "mutant introuvable : " .. from)
  return s2
end
local MUTANTS = {
  { "jamais d'amélioration", mutate('if s and k_hand < s then return "ameliorer", k_hand end', "") },
  { "jamais d'anneau", mutate('if math.max(1, math.floor(num(c.rings))) < Sg.MAX_RINGS then return "anneau" end', "") },
  { "pose du plus petit", mutate('if num(c.free_places) > 0 then return "poser", k_hand end', 'if num(c.free_places) > 0 then return "poser", #ladder end') },
  { "anneaux sans borne", mutate('if math.max(1, math.floor(num(c.rings))) < Sg.MAX_RINGS then return "anneau" end', 'return "anneau"') },
  { "fabrique même en main", mutate("if k_hand and k_hand <= k_make then return nil end", "") },
  { "anneau 2 sur l'anneau 1", mutate("local shift = (ring - 1) * Sg.RING_STEP", "local shift = 0") },
}
local killed = 0
for _, m in ipairs(MUTANTS) do
  local ok, Fm = pcall(function() return facts(assert(load(m[2], "@shared.team.stockage"))()) end)
  local seen = (not ok) or Fm ~= F0
  if seen then killed = killed + 1 end
  check(seen, "mutant « " .. m[1] .. " » vu")
end
print(string.format("[STOCKAGE] mutants : %d/%d vus", killed, #MUTANTS))

print(string.format("[STOCKAGE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
