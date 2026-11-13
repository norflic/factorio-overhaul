--[[
  Sprint s41 (labos) : laboratoires qui grandissent avec les plaques qui dorment (Dp.rebase, shared/ai3/depenses.lua) et construction par
  robots voulue (shared/ai3/chantier_robots.lua). Usage : lua5.2 tests/s41_labos_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Dp = require("shared.ai3.depenses")
local Cr = require("shared.ai3.chantier_robots")
local passes, failures = 0, 0
local function check(c, msg)
  if c then passes = passes + 1 else failures = failures + 1 print("[S41-LABOS] ECHEC : " .. msg) end
end

-- 1. Dp.rebase : la base n'avance que cible atteinte, plaques qui dorment, laboratoires nourris.
check(Dp.rebase(3, 7, 7, 4, true) == 7, "cible atteinte, nourris : la base avance")
check(Dp.rebase(3, 6, 7, 4, true) == 3, "cible pas atteinte : base gardée (pas le défaut D1)")
check(Dp.rebase(3, 7, 7, 4, false) == 3, "laboratoires affamés : base gardée")
check(Dp.rebase(3, 7, 7, 0, true) == 3, "rien ne dort : base gardée")
check(Dp.rebase(nil, 7, 7, 4, true) == nil, "pas de base : rien")
check(Dp.rebase(3, 7, nil, 4, true) == 3, "pas de cible : base gardée")
check(Dp.rebase(7, 7, 7, 4, true) == 7, "déjà à la base : inchangée")

-- 2. Suite de pensées : sans nourrir, plafond base + LABS_MAX ; nourris, la cible grandit jusqu'au plafond de l'appelant, jamais au-delà.
local function sim(fed, cap, steps)
  local base, target, now = nil, nil, 3
  for _ = 1, steps do
    base = Dp.rebase(base, now, target, Dp.LABS_MAX, fed)
    target, base = Dp.labs_target(base, now, Dp.LABS_MAX, cap, target)
    now = math.min(target, now + 1) -- un laboratoire posé par pensée
  end
  return now, target
end
local n0 = sim(false, 25, 60)
check(n0 == 3 + Dp.LABS_MAX, "affamés : base + LABS_MAX au plus (" .. n0 .. ")")
local n1, t1 = sim(true, 25, 60)
check(n1 == 25 and t1 == 25, "nourris : jusqu'au plafond de l'appelant (" .. n1 .. ")")
local n2 = sim(true, 9, 60)
check(n2 == 9, "nourris : jamais au-delà du plafond (" .. n2 .. ")")
-- la cible ne recule jamais et ne monte que d'un pas de LABS_MAX au plus au-dessus des présents
do
  local base, target, now, ok = nil, nil, 3, true
  for _ = 1, 40 do
    base = Dp.rebase(base, now, target, 2, true)
    local prev = target
    target, base = Dp.labs_target(base, now, 2, 25, target)
    if prev and target < prev then ok = false end
    if target - now > Dp.LABS_MAX then ok = false end
    now = math.min(target, now + 1)
  end
  check(ok, "cible monotone, pas borné")
end

-- 3. Cr.wanted : objets sans aucune recette ouverte, lus par une liste opaque (aucun nom du jeu).
local list = { { item = "x", recipe = "rx" }, { item = "y", recipe = "ry1" }, { item = "y", recipe = "ry2" } }
local w = Cr.wanted(list, function() return false end)
check(w and w.x and w.y, "tout fermé : les deux objets voulus")
w = Cr.wanted(list, function(r) return r == "ry2" end)
check(w and w.x and not w.y, "une recette ouverte suffit : l'objet n'est plus voulu")
check(Cr.wanted(list, function() return true end) == nil, "tout ouvert : nil")
check(Cr.wanted({}, function() return false end) == nil, "liste vide : nil")
check(Cr.wanted(nil, nil) == nil, "sans liste : nil")
check(#Cr.TYPES == 2, "deux types du moteur")

print(string.format("[S41-LABOS] %d OK, %d echec(s)", passes, failures))
if failures > 0 then os.exit(1) end
