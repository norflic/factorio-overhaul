"""Enveloppes cibles par rang d'époque et budget de recouvrement D1-3 (lot V1, bible des époques).

Entrées : mesures vanilla de silhouettes_vanilla.txt (pose de référence), plafonds proposés.
Sortie : tableau des dépassements au-dessus de l'emprise par rang (1 à 15) et, pour l'époque 15,
l'aire visée, l'intersection maximale avec le niveau 1 et la part du niveau 1 qui doit être laissée vide
pour que IoU(niveau 1, niveau 30) <= 0,45 (marge sous le seuil 0,50 de D1-3).

IoU = I / (A1 + A30 - I)  =>  IoU <= t  <=>  I <= t / (1 + t) * (A1 + A30)
"""

T = 0.45
# famille : (emprise, A1 mesurée, O1 mesuré, bas mesuré sous l'emprise, O15 plafond, L15 largeur, remplissage e15)
FAM = [
    ("centre", 4, 10.82, 0.41, 0.05, 3.60, 3.90, 0.55),
    ("mitrailleuse", 2, 3.28, 0.84, -0.28, 2.40, 2.20, 0.55),
    ("laser", 2, 2.26, 1.02, -0.31, 2.60, 2.10, 0.50),
    ("mur (droit horizontal)", 1, 1.24, 0.25, 0.55, 1.00, 1.00, 0.75),
    ("foreuse (nord)", 3, 4.99, 0.38, -0.02, 1.60, 3.20, 0.55),
    ("four", 2, 3.60, 0.28, 0.02, 1.60, 2.20, 0.60),
    ("assembleur 2", 3, 6.98, 0.06, -0.06, 1.50, 3.10, 0.60),
]

print("Dépassement au-dessus de l'emprise (tuiles) par rang d'époque : O(e) = O1 + (O15 - O1) * (e - 1) / 14")
print("rang | " + " | ".join(f[0] for f in FAM))
for e in range(1, 16):
    vals = []
    for name, size, a1, o1, bot, o15, w15, fill in FAM:
        vals.append(f"{o1 + (o15 - o1) * (e - 1) / 14:.2f}")
    print(f"{e:4d} | " + " | ".join(vals))
print()
print("Pas par époque : " + ", ".join(f"{f[0]} {(f[5] - f[3]) / 14:.3f}" for f in FAM))
# Largeur visuelle maximale : de la largeur vanilla mesurée (niveau 1) à L15
L1 = {"centre": 3.41, "mitrailleuse": 1.95, "laser": 1.72, "mur (droit horizontal)": 1.00, "foreuse (nord)": 2.94,
      "four": 1.97, "assembleur 2": 2.56}
# Part du niveau 1 laissée vide à l'époque 15 (budget ci-dessous arrondi aux 5 % supérieurs)
V15 = {"centre": 25, "mitrailleuse": 20, "laser": 5, "mur (droit horizontal)": 25, "foreuse (nord)": 20, "four": 30,
       "assembleur 2": 35}
print()
print("Largeur visuelle maximale L(e) (tuiles) et vide minimal V(e) (% du masque du niveau 1, nul jusqu'à l'époque 9)")
print("rang | " + " | ".join(f[0] for f in FAM))
for e in range(1, 16):
    vals = []
    for name, size, a1, o1, bot, o15, w15, fill in FAM:
        lv = L1[name] + (w15 - L1[name]) * (e - 1) / 14
        vv = 0 if e <= 9 else round(V15[name] * (e - 9) / 6)
        vals.append(f"{lv:.2f} / {vv:2d} %")
    print(f"{e:4d} | " + " | ".join(vals))
print()
print("Budget D1-3 à l'époque 15 (IoU visé <= 0,45)")
for name, size, a1, o1, bot, o15, w15, fill in FAM:
    h = size + o15 + max(0.0, bot)
    a30 = w15 * h * fill
    imax = T / (1 + T) * (a1 + a30)
    vide = max(0.0, 1 - imax / a1)
    inclus = a1 / a30  # IoU si le niveau 30 contenait entièrement le niveau 1
    print(f"  {name:24s} A1 {a1:5.2f}  boîte e15 {w15:.2f} x {h:.2f}  A30 ~ {a30:5.2f}  I max {imax:5.2f}"
          f"  -> laisser vide >= {vide * 100:3.0f} % du niveau 1  (IoU si inclusion totale : {inclus:.2f})")
