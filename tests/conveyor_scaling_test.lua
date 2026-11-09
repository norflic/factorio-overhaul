-- Banc hors jeu du lot CONVEYOR-SCALING : montée de palier des convoyeurs (shared/team/conveyor_scaling.lua).
--   lua5.2 tests/conveyor_scaling_test.lua      -> [CONVEYOR-SCALING] BILAN : N OK, 0 ECHEC(S)
-- §1 capacité ; §2 ordre par sorte et saturation ; §3 palier non activé, débit inconnu ; §4 budget et attente ; §5 tressage ;
-- §6 ligne de journal ; §7 déterminisme ; §8 mutants (chaque règle cassée est vue par un contrôle).
package.path = "./?.lua;" .. package.path
local Cs = dofile("shared/team/conveyor_scaling.lua")

local ok_n, fail_n = 0, 0
local function check(cond, what, detail)
  if cond then ok_n = ok_n + 1 else
    fail_n = fail_n + 1
    print("ECHEC " .. what .. (detail and (" : " .. tostring(detail)) or ""))
  end
end
local function ids(list) local out = {}; for _, s in ipairs(list) do out[#out + 1] = tostring(s.id) end; return table.concat(out, ",") end
local function near(a, b) return math.abs(a - b) < 1e-9 end

-- Paliers fictifs (vitesses seules : la règle ne connaît aucun nom) : J = 0,03125, R = 0,0625, B = 0,09375
local J, R, B = 0.03125, 0.0625, 0.09375

-- §1 capacité : un tapis entier de vitesse 0,03125 porte 15 objets/s ; une voie 7,5
check(near(Cs.capacity(J), 15), "capacité tapis jaune 15/s", Cs.capacity(J))
check(near(Cs.capacity(R), 30), "capacité tapis rouge 30/s")
check(near(Cs.capacity(J, 1), 7.5), "capacité d'une voie 7,5/s")
check(Cs.capacity(0) == 0 and Cs.capacity(nil) == 0 and Cs.capacity("x") == 0, "vitesse invalide : 0")

-- §2 ordre : troncs d'abord, puis sorties de fonderie, puis liaisons, bandes, autres ; à sorte égale le plus saturé d'abord
local SEG = {
  { id = "f1", kind = "autre", flow = 14, len = 10, tier_now = J, tier_target = R, item = "r" },
  { id = "b1", kind = "bande", flow = 13, len = 30, tier_now = J, tier_target = R, item = "r" },
  { id = "t2", kind = "tronc", flow = 10, len = 40, tier_now = J, tier_target = R, item = "r" },          -- 67 %
  { id = "s1", kind = "sortie-fonderie", flow = 14.5, len = 18, tier_now = J, tier_target = R, item = "r" },
  { id = "t1", kind = "tronc", flow = 14, len = 20, tier_now = J, tier_target = R, item = "r" },          -- 93 %
  { id = "l1", kind = "liaison", flow = 12, len = 12, tier_now = J, tier_target = R, item = "r" },
  { id = "t3", kind = "tronc", flow = 5, len = 50, tier_now = J, tier_target = R, item = "r" },           -- 33 % : laissé
}
local ranked, left = Cs.rank(SEG, Cs.CFG)
check(ids(ranked) == "t1,t2,s1,l1,b1,f1", "ordre : tronc (saturé d'abord), sortie-fonderie, liaison, bande, autre", ids(ranked))
check(#left == 1 and left[1].id == "t3" and left[1].why:find("pas saturé", 1, true), "tronc à 33 % laissé (pas saturé)", left[1] and left[1].why)
check(near(ranked[1].fill, 14 / 15), "remplissage rendu (14/15)")
check(ranked[1].prio == 1 and ranked[3].prio == 2 and ranked[4].prio == 3, "priorités de sorte 1, 2, 3")
check(SEG[1].id == "f1" and SEG[3].kind == "tronc", "la liste d'entrée n'est pas modifiée")
-- seuil exact : 60 % passe, 59 % reste
local r60 = Cs.rank({ { id = 1, kind = "tronc", flow = 9, len = 1, tier_now = J, tier_target = R, item = "r" } })
local _, l59 = Cs.rank({ { id = 1, kind = "tronc", flow = 8.85, len = 1, tier_now = J, tier_target = R, item = "r" } })
check(#r60 == 1 and #l59 == 1, "seuil : 60 % monte, 59 % reste")
-- débit par voie : un segment à une voie (lanes = 1) sature deux fois plus vite
local r1 = Cs.rank({ { id = 1, kind = "autre", flow = 5, len = 1, lanes = 1, tier_now = J, tier_target = R, item = "r" } })
check(#r1 == 1 and near(r1[1].fill, 5 / 7.5), "débit sur une voie : 5/s remplit 67 % d'une voie jaune")
-- sorte inconnue : « autre »
local rk = Cs.rank({ { id = 1, kind = "zzz", flow = 14, len = 1, tier_now = J, tier_target = R, item = "r" } })
check(rk[1].kind == "autre" and rk[1].prio == 5, "sorte inconnue classée « autre »")

-- §3 palier cible non activé (nil ou pas plus rapide), débit inconnu, longueur nulle
local _, l3 = Cs.rank({
  { id = "a", kind = "tronc", flow = 14, len = 10, tier_now = J, tier_target = nil, item = "r" },
  { id = "b", kind = "tronc", flow = 14, len = 10, tier_now = J, tier_target = J, item = "r" },
  { id = "c", kind = "tronc", flow = nil, len = 10, tier_now = J, tier_target = R, item = "r" },
  { id = "d", kind = "tronc", flow = 14, len = 0, tier_now = J, tier_target = R, item = "r" },
  { id = "e", kind = "tronc", flow = 14, len = 10, tier_now = nil, tier_target = R, item = "r" },
  "pas une table",
})
check(#l3 == 6, "six segments laissés", #l3)
check(l3[1].why == "pas de palier cible activé" and l3[2].why == "pas de palier cible activé", "palier cible absent ou égal : laissé")
check(l3[3].why == "débit inconnu", "débit inconnu : laissé")
check(l3[4].why == "aucune tuile" and l3[5].why == "palier actuel inconnu" and l3[6].why == "segment invalide", "autres raisons")
check(#Cs.rank(nil) == 0 and #Cs.rank({}) == 0, "liste vide ou absente : rien")

-- §4 budget : le kit paie dans l'ordre, le reste attend, rien n'est retiré du classement
-- kit de 45 : t1 prend 20, reste 25 < 40 : t2 attend sans min_pieces ; le kit restant ne dort pas, s1 (18) le prend (zéro inactivité)
local plan = Cs.budget(ranked, { r = 45 })
check(ids(plan.pay) == "t1,s1" and plan.waiting[1].id == "t2" and plan.waiting[1].have == 25, "sans min_pieces : t2 (40) attend avec 25 en kit, s1 passe", ids(plan.pay))
check(#plan.waiting == 4, "quatre segments en attente", #plan.waiting)
local plan8 = Cs.budget(ranked, { r = 45 }, { min_pieces = 8 })
check(ids(plan8.pay) == "t1,t2", "min_pieces 8 : t2 commence avec 25 pièces (le reste suit)", ids(plan8.pay))
check(plan8.waiting[1].id == "s1" and plan8.waiting[1].have == 0, "le kit est débité : s1 n'a plus rien")
check(plan8.short[1].item == "r" and plan8.short[1].n == 15 + 18 + 12 + 30 + 10, "manque total par objet (t2 : 15, puis 18 + 12 + 30 + 10)", plan8.short[1] and plan8.short[1].n)
local kit = { r = 45 }
Cs.budget(ranked, kit)
check(kit.r == 45, "le kit de l'appelant n'est pas modifié")
local empty = Cs.budget(ranked, {})
check(#empty.pay == 0 and #empty.waiting == 6 and empty.short[1].n == 130, "kit vide : tout attend, rien n'est retiré (130 pièces manquent)")
local noitem = Cs.budget({ { id = 1, kind = "tronc", len = 5 } }, { r = 100 })
check(#noitem.pay == 0 and #noitem.waiting == 1, "segment sans objet cible : en attente")
-- deux objets cibles distincts : chacun son compte
local two = Cs.budget({ { id = 1, kind = "tronc", len = 5, item = "r" }, { id = 2, kind = "tronc", len = 5, item = "b" } }, { r = 5, b = 2 })
check(#two.pay == 1 and two.short[1].item == "b" and two.short[1].n == 3, "objets distincts : b manque de 3")

-- §5 tressage : 2 tuiles × 4 voies avec deux paliers de souterrains (portées 5 et 7)
local br, why = Cs.braid(2, 4, { tiers = { { reach = 5 }, { reach = 7 } } })
check(br ~= nil, "2 tuiles × 4 voies : possible avec 2 paliers", why)
if br then
  check(#br.columns == 2 and br.columns[1].k == 2 and br.columns[2].k == 2, "deux voies par colonne")
  check(br.period == 4, "période de 4 tuiles (2k)")
  local a, b2 = br.columns[1].lanes[1], br.columns[1].lanes[2]
  check(a.exit == 0 and a.entry == 1 and a.hidden == 2 and b2.exit == 2 and b2.entry == 3 and b2.tier ~= a.tier, "voie 1 : sortie 0, entrée 1, cachée 2 ; voie 2 décalée de 2, autre palier")
  check(br.columns[2].lanes[2].lane == 4, "voies numérotées 1..4")
end
-- avec la portée seule (un palier) : une voie par colonne, pas de gain
local b1 = Cs.braid(2, 2, { underground_reach = 5 })
check(b1 and b1.columns[1].k == 1 and b1.columns[1].lanes[1].tier == nil and b1.period == 1, "un seul palier : tapis de surface, pas de souterrain")
local b3, w3 = Cs.braid(2, 4, { underground_reach = 5 })
check(b3 == nil and w3:find("paliers de souterrains distincts", 1, true), "un seul palier : 4 voies dans 2 tuiles impossible", w3)
local b4, w4 = Cs.braid(2, 5, { tiers = { { reach = 5 }, { reach = 7 } } })
check(b4 == nil and w4:find("> 4 (2 × 2 tuiles)", 1, true), "5 voies > 2 × largeur : impossible", w4)
local b5, w5 = Cs.braid(2, 4, { tiers = { { reach = 5 }, { reach = 2 } } })
check(b5 == nil and w5:find("portée", 1, true), "portée 2 < 3 : impossible", w5)
local b6 = Cs.braid(1, 3, { tiers = { { reach = 5 }, { reach = 5 }, { reach = 5 } } })
check(b6 and b6.columns[1].k == 3 and b6.period == 6 and b6.columns[1].lanes[3].hidden == 4, "1 tuile × 3 voies : 3 paliers de portée ≥ 5, période 6")
local b7 = Cs.braid(3, 4, { tiers = { { reach = 5 }, { reach = 7 } } })
check(b7 and b7.columns[1].k == 2 and b7.columns[2].k == 1 and b7.columns[3].k == 1, "3 tuiles × 4 voies : la première colonne tresse, les autres restent en surface")
check(Cs.braid(0, 1) == nil and Cs.braid(2, 0) == nil, "largeur ou voies nulles : nil")

-- §6 ligne de journal
local line = Cs.line("azure", { { kind = "tronc", id = 12, len = 40 }, { kind = "sortie-fonderie", id = 7, len = 18 } }, { { item = "r", n = 30 } })
check(line == "[FO-CONVOYEURS] azure : montée de palier : tronc 12 (40 tuiles) puis sortie-fonderie 7 (18 tuiles) ; en attente : r x30", "ligne attendue", line)
check(Cs.line("azure", {}, {}) == "[FO-CONVOYEURS] azure : montée de palier : rien à monter", "rien à monter")

-- §7 déterminisme : même entrée dans l'ordre inverse, même sortie ; égalité parfaite départagée par l'identifiant
local rev = {}
for i = #SEG, 1, -1 do rev[#rev + 1] = SEG[i] end
check(ids(Cs.rank(rev)) == ids(ranked), "ordre inverse en entrée : même classement")
local tie = Cs.rank({ { id = "z", kind = "tronc", flow = 14, len = 5, tier_now = J, tier_target = R }, { id = "m", kind = "tronc", flow = 14, len = 5, tier_now = J, tier_target = R } })
check(ids(tie) == "m,z", "égalité : identifiant croissant")
check(ids(Cs.budget(ranked, { r = 1000 }).pay) == ids(ranked), "kit sans limite : l'ordre du classement est gardé")

-- §8 mutants : chaque règle cassée serait vue par au moins un contrôle ci-dessus (on l'applique, on vérifie l'échec, on restaure)
local function mutant(name, apply, restore, probe)
  apply()
  local seen = not probe()
  restore()
  check(seen, "mutant vu : " .. name)
end
-- (a) priorité tronc perdue : toutes les sortes au même rang
local ORDER = Cs.ORDER
mutant("priorité tronc perdue", function() Cs.ORDER = { tronc = 1, ["sortie-fonderie"] = 1, liaison = 1, bande = 1, autre = 1 } end,
  function() Cs.ORDER = ORDER end, function() return ids(Cs.rank(SEG)) == "t1,t2,s1,l1,b1,f1" end)
-- (b) saturation ignorée : seuil à 0
local FILL = Cs.CFG.min_fill
mutant("saturation ignorée", function() Cs.CFG.min_fill = 0 end, function() Cs.CFG.min_fill = FILL end,
  function() local _, l = Cs.rank(SEG, Cs.CFG); return #l == 1 end)
-- (c) budget qui retire sans kit : un faux budget qui paie tout
local BUDGET = Cs.budget
mutant("budget sans kit", function() Cs.budget = function(r) return { pay = r, waiting = {}, short = {} } end end, function() Cs.budget = BUDGET end,
  function() local p = Cs.budget(ranked, {}); return #p.pay == 0 and #p.waiting == 6 end)
-- (d) tressage hors portée accepté : portée minimale ignorée (reach 2 pour 2 voies)
local BRAID = Cs.braid
mutant("tressage hors portée accepté", function()
  Cs.braid = function(w, l, cfg) local t = {}; for i, x in ipairs(cfg.tiers) do t[i] = { reach = 99 } end; return BRAID(w, l, { tiers = t }) end
end, function() Cs.braid = BRAID end, function() return Cs.braid(2, 4, { tiers = { { reach = 5 }, { reach = 2 } } }) == nil end)
-- (e) capacité fausse : facteur d'une voie (240) pris pour le tapis entier
local FACTOR = Cs.BELT_FACTOR
mutant("capacité fausse", function() Cs.BELT_FACTOR = 240 end, function() Cs.BELT_FACTOR = FACTOR end,
  function() return near(Cs.capacity(J), 15) end)
-- (f) tressage à un palier accepté : 4 voies dans 2 tuiles avec une seule portée
mutant("tressage à un seul palier accepté", function()
  Cs.braid = function(w, l, cfg) return BRAID(w, l, { tiers = { { reach = cfg.underground_reach }, { reach = cfg.underground_reach } } }) end
end, function() Cs.braid = BRAID end, function() return Cs.braid(2, 4, { underground_reach = 5 }) == nil end)

print(string.format("[CONVEYOR-SCALING] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
