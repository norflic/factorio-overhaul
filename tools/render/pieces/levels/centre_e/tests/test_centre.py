"""Tests hors Blender du kit du CENTRE DE COMMANDEMENT (lot F5-A, 27/10). Python 3.9.

    py -3.9 tools/render/pieces/levels/centre_e/tests/test_centre.py      -> « [F5-CENTRE] n OK, 0 ECHEC(S) »

Contrôles : contrat des 16 modules d'âge (ep00 à ep15), lecture en 3 mots sans mot répété, silhouettes (plan, étages,
toit) recopiées du registre, deux âges voisins de même taille de plans différents, emprises de shared/levels/config.lua,
profil (une pose, niveau = âge, aucune pièce paire), variantes de piece.py, construction à blanc de chaque âge (Geo
factice : chaque appel compté, aucune géométrie) avec porte, satellites, mât et détail fin.
"""
import math
import os
import re
import sys
import types

ICI = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.dirname(ICI)
COMMUN = os.path.join(os.path.dirname(KIT), "commun")
MOD = os.path.normpath(os.path.join(KIT, "..", "..", "..", "..", ".."))


class Vector(tuple):
    def __new__(cls, v=(0, 0, 0)):
        return tuple.__new__(cls, tuple(float(x) for x in v))

    x = property(lambda s: s[0])
    y = property(lambda s: s[1])
    z = property(lambda s: s[2])

    def __add__(self, o):
        return Vector(a + b for a, b in zip(self, o))

    def __sub__(self, o):
        return Vector(a - b for a, b in zip(self, o))

    def __mul__(self, k):
        return Vector(a * k for a in self)

    __rmul__ = __mul__

    def __truediv__(self, k):
        return Vector(a / k for a in self)

    def cross(self, o):
        a, b = self, o
        return Vector((a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]))

    @property
    def length(self):
        return math.sqrt(sum(a * a for a in self))

    def normalized(self):
        return self / (self.length or 1.0)

    def normalize(self):
        return None

    def lerp(self, o, t):
        return self + (Vector(o) - self) * t


class Matrix:
    def __init__(self, *a, **k):
        pass

    Diagonal = Rotation = Translation = Identity = staticmethod(lambda *a, **k: Matrix())

    def __matmul__(self, o):
        return self if isinstance(o, Matrix) else o


mu = types.ModuleType("mathutils")
mu.Vector, mu.Matrix = Vector, Matrix
sys.modules["mathutils"] = mu
sys.modules["bpy"] = types.ModuleType("bpy")
sys.modules["bmesh"] = types.ModuleType("bmesh")
for d in (KIT, COMMUN):
    if d not in sys.path:
        sys.path.insert(0, d)
import epoques as E  # noqa: E402
import corps  # noqa: E402
import piece  # noqa: E402
import profil  # noqa: E402

OK, KO = [0], [0]


def check(cond, msg):
    if cond:
        OK[0] += 1
        print("[F5-CENTRE] OK     " + msg)
    else:
        KO[0] += 1
        print("[F5-CENTRE] ECHEC  " + msg)


class FakeGeo:
    def __init__(self, M):
        self.M = M
        self.stack = [Matrix()]
        self.count = {}
        self.halos = []

    def __getattr__(self, name):
        def f(*a, **k):
            w = k.get("what", name)
            self.count[w] = self.count.get(w, 0) + 1
            return None
        return f


class AutoM(dict):
    def __missing__(self, k):
        return k

    def __contains__(self, k):
        return True


corps.mats_habilles = lambda M, hab: M

# 1. contrat, triplets, silhouettes
mots = []
for e in range(0, 16):
    m = E.module(e)
    check(hasattr(m, "mat") and hasattr(m, "FOYER") and hasattr(m, "NOM"), "ep%02d : contrat (NOM, FOYER, mat)" % e)
    hab = E.habillage(m)
    if e:
        check(m.TRIPLET == E.TRIPLETS[e], "ep%02d : TRIPLET du registre" % e)
        check(E.silhouette(hab) == E.SILHOUETTES[e], "ep%02d : silhouette %s du registre" % (e, E.SILHOUETTES[e]))
        mots += list(E.TRIPLETS[e])
check(len(mots) == len(set(mots)) == 45, "lecture en 3 mots : 45 mots, aucun répété")
for e in range(2, 16):
    if E.COTE[e] == E.COTE[e - 1]:
        check(E.SILHOUETTES[e][0] != E.SILHOUETTES[e - 1][0],
              "âges %d et %d (même emprise %d×%d) : plans différents (%s, %s)" % (
                  e - 1, e, E.COTE[e], E.COTE[e], E.SILHOUETTES[e - 1][0], E.SILHOUETTES[e][0]))
check(len({s[0] for s in E.SILHOUETTES.values()}) >= 5, "au moins 5 plans différents sur les 15 âges")

# 2. emprises de shared/levels/config.lua
cfg = open(os.path.join(MOD, "shared", "levels", "config.lua"), encoding="utf-8").read()
mm = re.search(r"command\s*=\s*\{\s*era\s*=\s*\{([^}]*)\}", cfg)
eras = [int(x) for x in mm.group(1).split(",")] if mm else []
check(len(eras) == 5 and all(E.COTE[e] == eras[(e - 1) // 3] for e in range(1, 16)),
      "emprises = shared/levels/config.lua (command era %s)" % eras)

# 3. profil et variantes
check(profil.POSES == ("F",) and all(profil.compositions(e) == [("F", False)] for e in range(1, 16)),
      "profil : une pose F, une composition par âge (niveau = âge)")
check(not any(profil.est_piece_paire(e, "hr-cen-e%02d-centre-main.png" % e) for e in range(1, 16)),
      "profil : aucune pièce paire")
V = piece.PIECE["variants"]
check(sorted(n for n in V if n.startswith("e")) == ["e%02d-centre" % e for e in range(1, 16)],
      "piece.py : 15 variantes eNN-centre")
check(sorted(n for n in V if n.startswith("k")) == ["k%d-centre" % s for s in range(4, 9)], "piece.py : témoins k4 à k8")
check(all(V["e%02d-centre" % e]["level"] == e and V["e%02d-centre" % e]["side"] == E.COTE[e] for e in range(1, 16)),
      "piece.py : niveau = âge, emprise du registre")

# 4. construction à blanc
for e in list(range(1, 16)) + ["k4", "k8"]:
    ee = 0 if isinstance(e, str) else e
    side = int(e[1]) if isinstance(e, str) else E.COTE[e]
    m = E.module(ee)
    g = FakeGeo(AutoM())
    c = corps.Ctx(g, ee, m, side, E.habillage(m))
    try:
        corps.centre(g, c)
        n = g.count
        ok = (n.get("vantail", 0) == 1 and n.get("sat_fut", 0) == (4 if side >= 6 else 2) and c.n_fin > 20
              and n.get("fenetre", 0) >= 4 and len(c.z_etages) == c.n_etages)
        check(ok, "âge %s : construction à blanc (porte 1, satellites %d, fenêtres %d, détail fin %d, étages %d)" % (
            e, n.get("sat_fut", 0), n.get("fenetre", 0), c.n_fin, len(c.z_etages)))
    except Exception as ex:  # noqa: BLE001
        check(False, "âge %s : construction à blanc : %r" % (e, ex))

print("[F5-CENTRE] %d OK, %d ECHEC(S)" % (OK[0], KO[0]))
sys.exit(1 if KO[0] else 0)
