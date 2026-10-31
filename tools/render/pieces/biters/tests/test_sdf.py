"""Contrôles de la sculpture implicite (lot RB-V0), hors Blender : py -3.9 -B tools/render/pieces/biters/tests/test_sdf.py"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import sdf  # noqa: E402

ok = ko = 0


def check(nom, cond, info=""):
    global ok, ko
    ok, ko = ok + bool(cond), ko + (not cond)
    print(("OK   " if cond else "ECHEC ") + nom, info)


# Sphère : maillage fermé (Euler = 2), rayon juste, faces vers l'extérieur.
f = sdf.Forme("sphere", ((-1.2, -1.2, -1.2), (1.2, 1.2, 1.2)), 0.04)
f.groupe("a").append(sdf.Ell((0, 0, 0), (1, 1, 1)))
V, Q, nb = sdf.extraire(f)
r = np.linalg.norm(V, axis=1)
check("rayon de la sphère à une fraction de voxel", abs(r.mean() - 1) < 0.01 and r.std() < 0.01, "%.4f ±%.4f" % (r.mean(), r.std()))
aretes = np.concatenate([Q[:, [0, 1]], Q[:, [1, 2]], Q[:, [2, 3]], Q[:, [3, 0]]])
tri = np.sort(aretes, axis=1)
uniq, cnt = np.unique(tri, axis=0, return_counts=True)
check("maillage fermé (chaque arête vue 2 fois)", (cnt == 2).all(), str(np.bincount(cnt)))
check("caractéristique d'Euler 2", len(V) - len(uniq) + len(Q) == 2, str(len(V) - len(uniq) + len(Q)))
a, b, c = V[Q[:, 0]], V[Q[:, 1]], V[Q[:, 2]]
n = np.cross(b - a, c - a)
check("faces tournées vers l'extérieur", ((n * a).sum(axis=1) > 0).mean() > 0.999)
check("bande étroite : moins de points calculés que la grille", nb < 61 ** 3, str(nb))

# Bande étroite contre grille pleine : même surface.
vol, o, h, _ = sdf.echantillonne(f.champ, *f.boite, 0.04, bloc=1)
V2, Q2 = sdf.surface_nets(vol, o, h)
check("même surface qu'en grille pleine", len(V) == len(V2) and np.abs(np.sort(V, axis=0) - np.sort(V2, axis=0)).max() < 1e-4)

# Segment : le ventre grossit le milieu, pas les bouts.
os_ = sdf.Os((0, 0, 0), (1, 0, 0), 0.1, 0.1, ventre=0.05)
d = os_.d(np.array([[0.5, 0.15, 0.0], [-0.1, 0.0, 0.0]], np.float32))
check("ventre du segment", abs(d[0]) < 1e-5 and abs(d[1]) < 1e-5, str(d))

# Relief : positif sur une sphère, négatif dans un creux ; ouverture 1 à l'air libre.
pp = np.array([[1, 0, 0]], np.float32)
ov, rl = sdf.creux_et_relief(f, pp, pp, 0.2)
check("relief positif sur une bosse, ouverture 1", rl[0] > 0 and ov[0] > 0.99, "%.3f %.3f" % (rl[0], ov[0]))
f3 = sdf.Forme("c", ((-2, -2, -2), (2, 2, 2)), 0.1)
f3.groupe("a").append(sdf.Fn(lambda q: q[:, 2] - 0.0))
f3.creuse(sdf.Ell((0, 0, 0.05), (0.15, 0.15, 0.15)), k=0.0)
ov, rl = sdf.creux_et_relief(f3, np.array([[0, 0, -0.1]], np.float32), np.array([[0, 0, 1]], np.float32), 0.2)
check("relief négatif dans un creux, ouverture < 1", rl[0] < 0 and ov[0] < 1, "%.3f %.3f" % (rl[0], ov[0]))

# Volumes écartés par bloc : même champ qu'en calcul complet près de la surface.
g = sdf.Forme("g", ((-1, -1, -1), (1, 1, 1)), 0.02)
gv = g.groupe("a")
for i in range(6):
    gv.append(sdf.Os((i * 0.3 - 0.8, 0, 0), (i * 0.3 - 0.5, 0.2, 0), 0.1, 0.07, k=0.05))
pts = np.random.default_rng(1).uniform(-0.3, 0.3, (4000, 3)).astype(np.float32) * np.array([3, 1, 1], np.float32)
vrai = g.champ(pts)
garde = np.abs(vrai) < 0.04
check("champ par blocs = champ complet", np.abs(g.champ(pts, g.selection(pts, 0.12))[garde] - vrai[garde]).max() < 1e-5, str(int(garde.sum())))

# Union lisse : plus proche que le min, soustraction : retire.
check("union lisse", sdf.smin(np.array([0.0]), np.array([0.0]), 0.1)[0] < 0)
f2 = sdf.Forme("creux", ((-1.2, -1.2, -1.2), (1.2, 1.2, 1.2)), 0.04)
f2.groupe("a").append(sdf.Ell((0, 0, 0), (1, 1, 1)))
f2.creuse(sdf.Ell((1, 0, 0), (0.5, 0.5, 0.5)), k=0.0)
check("creux", f2.champ(np.array([[0.9, 0, 0]], np.float32))[0] > 0 and f2.champ(np.array([[-0.9, 0, 0]], np.float32))[0] < 0)

# Repère : q revient aux coordonnées de repos après rotation et translation.
rep = sdf.Repere((1, 2, 3), sdf.rot_z(0.7))
p = rep.monde((0.3, -0.2, 0.5))
check("repère de repos", np.allclose(rep.q(p[None, :])[0], (0.3, -0.2, 0.5), atol=1e-5))
# Peau : le bruit est déterministe.
check("bruit déterministe", sdf.Bruit(5)(np.array([[1.3, 2.2, 0.4]]))[0] == sdf.Bruit(5)(np.array([[1.3, 2.2, 0.4]]))[0])

print("[SDF] BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
sys.exit(1 if ko else 0)
