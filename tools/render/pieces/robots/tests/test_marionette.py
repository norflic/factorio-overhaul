"""Tests purs de la marionnette et des 3 états clés (lot RB-V0), hors Blender : py -3.9 -B tools/render/pieces/robots/tests/test_marionette.py
Contrôles : IK exacte, pied d'appui fixe à ±1 px HR dans le repère du sol, aucun pied hors de portée, cycle bouclé, déterminisme, os tous
présents pour chaque maille (modele() joué avec un faux lot), plus des mutants (cycle faussé, phase décalée) qui doivent être refusés.
"""
import importlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import formes as F  # noqa: E402
import geo as G  # noqa: E402
import marionette as Mr  # noqa: E402

PX = 64.0
OK = [0, 0]


def ctl(cond, texte):
    OK[0 if cond else 1] += 1
    if not cond:
        print("ECHEC :", texte)


def glissement_px(mod, n=240):
    """Plus grand écart (px HR, sur le sol) d'un pied d'appui pendant son appui, en suivant le corps qui avance de PAS par cycle."""
    pire = 0.0
    noms = sorted(mod.squelette(0.0).marques)
    for nom in noms:
        ref = None
        for i in range(n):
            ph = i / float(n)
            m = mod.squelette(ph).marques[nom]
            if m["appui"]:
                x = m["pied"][0] + ph * mod.PAS
                # une nouvelle période d'appui commence après un vol : on repart de ce point
                if ref is None:
                    ref = (x, m["pied"][1], m["pied"][2])
                pire = max(pire, abs(x - ref[0]) * PX, abs(m["pied"][1] - ref[1]) * PX, abs(m["pied"][2] - ref[2]) * PX)
            else:
                ref = None
    return pire


class FauxLot:
    def __init__(self, nom):
        self.nom = nom
        self.n = 0
        self.v = 0

    def put(self, mat, mesh, xf=None):
        v, f, u = mesh
        ctl(len(v) == len(u), "sommets et UV de longueur différente sur %s" % self.nom)
        ctl(all(max(ff) < len(v) for ff in f), "face hors maille sur %s" % self.nom)
        self.n += 1
        self.v += len(v)


class FausseMat(dict):
    def __missing__(self, k):
        return k


def controle_ik():
    h, p = (0.0, 0.0, 1.0), (0.3, 0.1, 0.0)
    g, tendu = Mr.ik2(h, p, 0.8, 0.7, (1.0, 0.0, 0.0))
    ctl(not tendu, "IK : pied atteignable marqué tendu")
    ctl(abs(G.length(G.sub(g, h)) - 0.8) < 1e-9, "IK : longueur du segment 1")
    ctl(abs(G.length(G.sub(g, p)) - 0.7) < 1e-9, "IK : longueur du segment 2")
    ctl(g[0] > 0.0, "IK : le genou n'est pas du côté du pôle")
    ctl(Mr.ik2(h, (5.0, 0.0, 0.0), 0.8, 0.7, (1.0, 0.0, 0.0))[1], "IK : pied hors de portée non signalé")


def controle_robot(nom):
    mod = importlib.import_module(nom)
    a = mod.squelette(0.37)
    b = mod.squelette(0.37)
    ctl(a.local == b.local, "%s : deux appels ne donnent pas le même squelette" % nom)
    z = mod.squelette(0.0)
    u = mod.squelette(1.0)
    for k in z.local:
        d = max(abs(z.local[k][i][j] - u.local[k][i][j]) for i in range(4) for j in range(4))
        ctl(d < 1e-6, "%s : le cycle ne boucle pas à l'os %s (%g)" % (nom, k, d))
    g = glissement_px(mod)
    ctl(g <= 1.0, "%s : pied d'appui qui glisse de %.3f px HR" % (nom, g))
    tendus = [(i, k) for i in range(120) for k, m in mod.squelette(i / 120.0).marques.items() if m["tendu"]]
    ctl(not tendus, "%s : pied hors de portée %s" % (nom, tendus[:3]))
    ctl(not any(m["tendu"] for m in mod.squelette(None).marques.values()), "%s : pied hors de portée à l'arrêt" % nom)
    # à tout instant au moins la moitié des pieds portent (un pied sur 2 pour le Lévite)
    for i in range(120):
        m = mod.squelette(i / 120.0).marques
        n = sum(1 for v in m.values() if v["appui"])
        ctl(n >= len(m) // 2, "%s : phase %d/120, %d pied(s) en appui sur %d" % (nom, i, n, len(m)))
    # chaque maille a son os ; le modèle ne dépend pas de la phase
    lots = Mr.Lots(None, nom, lambda S, n_: FauxLot(n_))
    mod.modele(lots, FausseMat(), G.Rnd(7))
    inconnus = [k for k in lots.lots if k not in a.local]
    ctl(not inconnus, "%s : mailles sur des os inconnus %s" % (nom, inconnus))
    sommets = sum(l.v for l in lots.lots.values())
    return g, sommets, lots.n


def controle_mutants():
    """Le contrôle du glissement doit refuser un cycle faussé."""
    class Mutant:
        PAS = 1.0

        @staticmethod
        def squelette(ph):
            sq = Mr.Squelette()
            dx, dz, appui, u = Mr.pied(ph, 0.0, 0.9, 0.6, 0.1)      # le corps avance de 1 mais le pied recule de 0,9 : il glisse
            sq.marques["x"] = {"pied": (dx, 0.0, dz), "appui": appui, "tendu": False}
            return sq
    ctl(glissement_px(Mutant) > 1.0, "mutant : un pied qui glisse n'est pas vu")

    class Mutant2:
        PAS = 1.0

        @staticmethod
        def squelette(ph):
            sq = Mr.Squelette()
            dx, dz, appui, u = Mr.pied(ph, 0.0, 1.0, 0.6, 0.1)
            sq.marques["x"] = {"pied": (dx, 0.0, dz + (0.05 if appui else 0.0) * math.sin(ph * 7.0)), "appui": appui, "tendu": False}
            return sq
    ctl(glissement_px(Mutant2) > 1.0, "mutant : un pied qui décolle pendant l'appui n'est pas vu")


def main():
    controle_ik()
    controle_mutants()
    for nom in ("trotte", "levite", "couronne"):
        g, s, n = controle_robot(nom)
        print("[RB-V0] %s : glissement max %.4f px HR, %d pièces, %d sommets" % (nom, g, n, s))
    _ = F
    print("[RB-V0] BILAN : %d OK, %d ECHEC(S)" % tuple(OK))
    return 1 if OK[1] else 0


if __name__ == "__main__":
    sys.exit(main())
