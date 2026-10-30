"""Tests HORS Blender du kit machines (lot DESIGN-CALCUL CALC-MACHINES-AMONT) : chaque essai se construit à sec
(géométrie pure, matières factices), reste dans son emprise, ne dépasse pas O ≤ 0,40 × côté au-dessus du bord nord
(charte DA_FACTORIO §3.1), porte au moins 26 petites pièces par tuile² d'emprise × 0,8 (loi vanilla, §3.2), pose une
bride au droit de CHAQUE raccord de fluide du prototype, et la construction est déterministe.

    py -3.9 -B tools/render/pieces/machines/tests/test_machines.py
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(BASE, "commun"))
import geo  # noqa: E402
import organes  # noqa: E402

SQ2 = organes.SQ2
# machine : (dossier, préfixe, côté, raccords (x, y de jeu vers le SUD), variantes)
MACHINES = {
    "cryogenique": ("cryogenique", "cryo_", 5, [(-1, 3), (1, 3), (-2, -3), (0, -3), (2, -3)], "abc"),
    "imprimante": ("imprimante", "impr_", 3, [(0, -2)], "abc"),
    "frittage": ("frittage", "fritt_", 3, [(0, -2), (0, 2)], "abc"),
    "four_arc": ("four_arc", "arc_", 4, [(-0.5, -2.5)], "abc"),
}
OK, KO = [0], [0]


def check(cond, msg):
    if cond:
        OK[0] += 1
    else:
        KO[0] += 1
        print("ECHEC :", msg)


class Mat:
    def __init__(self, n):
        self.name = n


class FM(dict):
    def __missing__(self, k):
        return Mat(k)


class FS:
    def __init__(self):
        self.halos = []

    def halo_light(self, *a, **k):
        self.halos.append(a)


def construire(dossier, pref, var):
    d = os.path.join(BASE, dossier)
    if d not in sys.path:
        sys.path.insert(0, d)
    for m in [m for m in sys.modules if m.startswith(pref)]:
        del sys.modules[m]
    lot = geo.Lot(None, "t")
    k = organes.Kit(lot, FM(), 1)
    importlib.import_module(pref + var).build(FS(), k)
    return lot, k


def main():
    for nom, (dossier, pref, cote, raccords, variantes) in sorted(MACHINES.items()):
        for v in variantes:
            lot, k = construire(dossier, pref, v)
            vs = [p for part in lot.parts.values() for p in part[1]]
            xs = [p[0] for p in vs]
            ys = [p[1] / SQ2 for p in vs]
            haut = max(p[1] * 0.7071 + p[2] * 0.7071 for p in vs)
            tag = "%s/%s" % (nom, v)
            check(min(xs) >= -cote / 2 - 1e-6 and max(xs) <= cote / 2 + 1e-6, "%s : sort de l'emprise en x" % tag)
            # tolérance 0,06 tuile : brides des raccords posées SUR le bord (le tuyau du joueur s'y branche)
            check(min(ys) >= -cote / 2 - 0.06 and max(ys) <= cote / 2 + 0.06, "%s : sort de l'emprise en y (%.3f..%.3f)"
                  % (tag, min(ys), max(ys)))
            check(haut - cote / 2 <= 0.40 * cote + 1e-6, "%s : dépasse de %.2f au-dessus du bord nord (max %.2f)"
                  % (tag, haut - cote / 2, 0.4 * cote))
            check(k.petites >= 26 * cote * cote * 0.8, "%s : %d petites pièces < %d" % (tag, k.petites, 26 * cote * cote * 0.8))
            # une bride (disque) au bord, au droit de chaque raccord : on cherche des sommets au bord à ± 0,2 en x
            for (rx, ry) in raccords:
                yb = -ry / abs(ry) * cote / 2
                pres = [p for p in vs if abs(p[0] - rx) < 0.25 and abs(p[1] / SQ2 - yb) < 0.05 and 0.1 < p[2] < 0.6]
                check(len(pres) > 20, "%s : pas de bride au raccord (%g, %g)" % (tag, rx, ry))
            lot2, k2 = construire(dossier, pref, v)
            vs2 = [p for part in lot2.parts.values() for p in part[1]]
            check(vs == vs2, "%s : construction non déterministe" % tag)
            print("[MACHINES] %-14s %d pièces, %d petites, dépasse %.2f" % (tag, lot.n, k.petites, haut - cote / 2))
    print("[MACHINES] BILAN : %d OK, %d ECHEC(S)" % (OK[0], KO[0]))
    sys.exit(1 if KO[0] else 0)


if __name__ == "__main__":
    main()
