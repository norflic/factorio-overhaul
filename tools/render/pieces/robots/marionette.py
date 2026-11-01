"""MARIONNETTE des robots (lot RB-V0, 31/10) : pièces RIGIDES posées sur des os, jamais d'armature (une machine n'a pas de
peau, et le rendu reste octet à octet, tools/render/README.md). Un os est un EMPTY de Blender ; ses enfants sont les mailles
de la pièce, modélisées dans son repère : la patine (coordonnées « objet ») reste collée à la pièce d'une image à l'autre.

La partie calcul (repères, IK analytique à 2 segments, cycle de marche fonction de la phase) est du Python pur, testée hors
Blender (tests/test_marionette.py). Seule incarner() importe bpy.

Cycle de marche, repère du robot, +X vers l'avant, le corps avance de PAS par cycle :
  appui (fraction beta) : le pied est FIXE au sol, donc recule de PAS × beta par rapport au corps ;
  vol (1 - beta)        : il revient devant, levé de `leve` au milieu.
En jeu : distance_per_frame = PAS / nombre d'images, et le pied d'appui ne glisse pas.
"""
import math

IDENT = ((1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0), (0.0, 0.0, 1.0, 0.0), (0.0, 0.0, 0.0, 1.0))


# ------------------------------------------------------------------------------------------------ matrices 4 × 4
def mm(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)) for i in range(4))


def chaine(*ms):
    r = ms[0]
    for m in ms[1:]:
        r = mm(r, m)
    return r


def app(m, p):
    return (m[0][0] * p[0] + m[0][1] * p[1] + m[0][2] * p[2] + m[0][3],
            m[1][0] * p[0] + m[1][1] * p[1] + m[1][2] * p[2] + m[1][3],
            m[2][0] * p[0] + m[2][1] * p[1] + m[2][2] * p[2] + m[2][3])


def tr(x, y, z):
    return ((1.0, 0.0, 0.0, x), (0.0, 1.0, 0.0, y), (0.0, 0.0, 1.0, z), (0.0, 0.0, 0.0, 1.0))


def rx(a):
    s, c = math.sin(a), math.cos(a)
    return ((1.0, 0.0, 0.0, 0.0), (0.0, c, -s, 0.0), (0.0, s, c, 0.0), (0.0, 0.0, 0.0, 1.0))


def ry(a):
    s, c = math.sin(a), math.cos(a)
    return ((c, 0.0, s, 0.0), (0.0, 1.0, 0.0, 0.0), (-s, 0.0, c, 0.0), (0.0, 0.0, 0.0, 1.0))


def rz(a):
    s, c = math.sin(a), math.cos(a)
    return ((c, -s, 0.0, 0.0), (s, c, 0.0, 0.0), (0.0, 0.0, 1.0, 0.0), (0.0, 0.0, 0.0, 1.0))


def ech(k):
    return ((k, 0.0, 0.0, 0.0), (0.0, k, 0.0, 0.0), (0.0, 0.0, k, 0.0), (0.0, 0.0, 0.0, 1.0))


def autour(c, m):
    """Rotation m autour du point c (au lieu de l'origine)."""
    return chaine(tr(c[0], c[1], c[2]), m, tr(-c[0], -c[1], -c[2]))


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _unit(a):
    n = math.sqrt(_dot(a, a))
    if n < 1e-12:
        raise ValueError("vecteur nul")
    return (a[0] / n, a[1] / n, a[2] / n)


def repere(o, x_dir, haut=(0.0, 0.0, 1.0), echelle_x=1.0):
    """Repère d'origine o, axe X le long de x_dir, Z au plus près de `haut`. echelle_x étire la seule maille X (filament)."""
    x = _unit(x_dir)
    h = haut if abs(_dot(x, _unit(haut))) < 0.98 else (1.0, 0.0, 0.0)
    y = _unit(_cross(h, x))
    z = _cross(x, y)
    return ((x[0] * echelle_x, y[0], z[0], o[0]), (x[1] * echelle_x, y[1], z[1], o[1]), (x[2] * echelle_x, y[2], z[2], o[2]),
            (0.0, 0.0, 0.0, 1.0))


# ------------------------------------------------------------------------------------------------ IK à 2 segments
def ik2(hanche, pied, l1, l2, pole):
    """Genou d'une chaîne hanche → genou → pied de longueurs l1, l2, du côté de `pole` (direction). Rend (genou, tendu) :
    tendu = vrai si le pied est hors de portée (distance ramenée à la portée : le pied ne serait plus atteint)."""
    d_vec = _sub(pied, hanche)
    d = math.sqrt(_dot(d_vec, d_vec))
    tendu = d > l1 + l2 - 1e-6 or d < abs(l1 - l2) + 1e-6
    d2 = max(abs(l1 - l2) + 1e-6, min(l1 + l2 - 1e-6, d))
    e = _unit(d_vec)
    n = _sub(pole, tuple(e[i] * _dot(pole, e) for i in range(3)))
    n = _unit(n)
    a = (l1 * l1 - l2 * l2 + d2 * d2) / (2.0 * d2)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    return tuple(hanche[i] + e[i] * a + n[i] * h for i in range(3)), tendu


# ------------------------------------------------------------------------------------------------ cycle de marche
def lisse(u):
    return u * u * (3.0 - 2.0 * u)


def pied(phase, decalage, pas, beta, leve):
    """Position d'un pied par rapport à sa place neutre, dans le repère du corps en marche. phase None : à l'arrêt.
    Rend (dx, dz, appui, u) : u = avancement dans la phase courante (0 à 1)."""
    if phase is None:
        return 0.0, 0.0, True, 0.0
    p = (phase + decalage) % 1.0
    if p < beta:
        return pas * (beta / 2.0 - p), 0.0, True, p / beta
    u = (p - beta) / (1.0 - beta)
    return pas * beta * (lisse(u) - 0.5), leve * math.sin(math.pi * u), False, u


def pied_monde(phase, decalage, pas, beta, x0=0.0):
    """Abscisse du pied dans le repère du SOL (corps en x = phase × pas) ; constante tant que le pied est en appui."""
    return x0 + phase * pas + pied(phase, decalage, pas, beta, 0.0)[0]


# ------------------------------------------------------------------------------------------------ directions du jeu
PROJ = math.sqrt(0.5)      # apply_projection (F121, E70) : compression verticale de la vue


def direction_jeu(k, n, d_tuiles):
    """Image k d'une feuille à n directions : le moteur attend une rotation UNIFORME θ = 2π·k/n depuis le nord, sens horaire
    (tools/render/pieces/levels/gun_e/feuilles.py, orientation_image). Rend (cap Blender, pas Blender) : pour que le pied d'appui ne
    glisse pas à l'écran quand l'unité avance de d_tuiles par cycle, la longueur parcourue dans la scène dépend de la direction
    (une tuile vers le nord vaut 1 / PROJ unité de scène). Une seule distance_per_frame par prototype : d_tuiles / images."""
    th = 2.0 * math.pi * k / n
    return math.pi / 2.0 - th, d_tuiles / math.sqrt(math.sin(th) ** 2 + (PROJ * math.cos(th)) ** 2)


Z_PIECE = 40.0     # hauteur de rendu des pièces de pattes : loin du sol, ni ombre portée, ni occlusion


def repere_ecran(z):
    """Repère d'une pièce de patte de géant : +X vers le BAS de l'écran, +Y vers la gauche de l'écran, origine en hauteur z. Le moteur fait tourner la pièce dans
    le plan de l'écran : rendue à plat face à la caméra, sa longueur en unités est sa longueur en tuiles à l'écran."""
    bas = (0.0, -PROJ, -PROJ)
    return repere((0.0, 0.0, z), bas, (0.0, -PROJ, PROJ))


# ------------------------------------------------------------------------------------------------ squelette
class Squelette:
    """Hiérarchie d'os (équivalent pur des empties) : chaque os a un parent et une matrice locale."""

    def __init__(self):
        self.ordre = []
        self.parent = {}
        self.local = {}
        self.marques = {}     # points nommés (repère du robot) : pieds, pour les planches et les tests

    def os(self, nom, parent=None, m=IDENT):
        if nom in self.local:
            raise ValueError("os en double : %s" % nom)
        if parent is not None and parent not in self.local:
            raise ValueError("parent inconnu : %s" % parent)
        self.ordre.append(nom)
        self.parent[nom] = parent
        self.local[nom] = m
        return nom

    def monde(self, nom):
        m = self.local[nom]
        p = self.parent[nom]
        while p is not None:
            m = mm(self.local[p], m)
            p = self.parent[p]
        return m


class Lots:
    """Un Lot de geo.py par os. lots("corps") rend le lot de l'os ; n : nombre de pièces posées."""

    def __init__(self, S, prefixe, fabrique):
        self.S = S
        self.prefixe = prefixe
        self.fabrique = fabrique
        self.lots = {}

    def __call__(self, nom):
        if nom not in self.lots:
            self.lots[nom] = self.fabrique(self.S, "%s_%s" % (self.prefixe, nom))
        return self.lots[nom]

    @property
    def n(self):
        return sum(l.n for l in self.lots.values())


def incarner(sq, lots):
    """Crée les empties, puis les objets (un par matière et par os) enfants de leur os. Blender seulement."""
    import bpy
    from mathutils import Matrix
    scene = bpy.context.scene
    emp = {}
    for nom in sq.ordre:
        e = bpy.data.objects.new("os_" + nom, None)
        scene.collection.objects.link(e)
        if sq.parent[nom] is not None:
            e.parent = emp[sq.parent[nom]]
        e.matrix_basis = Matrix(sq.local[nom])
        emp[nom] = e
    for nom in sorted(lots.lots):
        if nom not in emp:
            raise ValueError("maille sur un os inconnu : %s" % nom)
        for ob in lots.lots[nom].flush():
            ob.parent = emp[nom]
    bpy.context.view_layer.update()
