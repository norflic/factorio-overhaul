"""PONT d'un corps de lignée (lot K0, 23/10) : motifs du dessus (caillebotis, planches, dalles, tôles), liseré,
tables par défaut des FORMES de pont, hasard local, arêtes, parapets, garde-corps, filets, flancs et troncs. Sorti de
gun_e/corps.py SANS changer une ligne (corps.py réimporte ces noms ; le dessin de la plateforme de la mitrailleuse,
corps.plateforme et corps._plateforme_forme, reste dans gun_e car il évite la trémie et la pièce paire). Contours et
hauteurs des formes : silhouettes.py. S'exécute DANS Blender."""
import math

from mathutils import Matrix, Vector

from kit import SQ2
from repere import Y

V = Vector


MOTIFS = ("caillebotis", "planches", "dalles", "toles")
PONT_DEFAUT = dict(motif="caillebotis", mat="grate", mat2=None, fond="tablier", bord="steel_dk", boulons="steel_hi",
                   lisere=None, pas=None, joint=None, relief=0.0)
# pas (tuiles de jeu) et joint (unités Blender) par défaut de chaque motif ; précision (règle d'or 4) : planches de
# 0,16 t, dalles de 0,28 t (tôles 0,22 à 0,30), tôles rivetées de 0,5 t (rivets de 0,016)
PAS_DEFAUT = {"planches": 0.16, "dalles": 0.28, "toles": 0.5}
JOINT_DEFAUT = {"planches": 0.014, "dalles": 0.016, "toles": 0.02}


def pont_cfg(hab):
    """Réglage du pont depuis la clé « plateforme » (None : caillebotis de la lignée, code d'origine)."""
    v = hab.get("plateforme")
    if not v:
        return None
    if isinstance(v, str):
        v = dict(motif=v)
    inconnues = sorted(set(v) - set(PONT_DEFAUT))
    if inconnues:
        raise KeyError("habillage plateforme : clé(s) inconnue(s) %s (permises : %s)"
                       % (", ".join(inconnues), ", ".join(sorted(PONT_DEFAUT))))
    cfg = dict(PONT_DEFAUT)
    cfg.update(v)
    if cfg["motif"] not in MOTIFS:
        raise ValueError("habillage plateforme : motif %r inconnu (%s)" % (cfg["motif"], ", ".join(MOTIFS)))
    return cfg


def _demi_plan(pts, a, b, d):
    """Garde la partie de pts à GAUCHE de a->b (intérieur d'un polygone direct), rentrée de d."""
    ex, ey = b[0] - a[0], b[1] - a[1]
    L = math.hypot(ex, ey)
    if L < 1e-9:
        return pts
    nx, ny = -ey / L, ex / L

    def s(p):
        return (p[0] - a[0]) * nx + (p[1] - a[1]) * ny - d
    out = []
    for i in range(len(pts)):
        p, q = pts[i], pts[(i + 1) % len(pts)]
        sp, sq = s(p), s(q)
        if sp >= 0:
            out.append(p)
        if (sp >= 0) != (sq >= 0):
            t = sp / (sp - sq)
            out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    return out


def _decoupe(pts, poly, d=0.0):
    """Polygone convexe pts découpé par le polygone convexe direct poly rentré de d."""
    for i in range(len(poly)):
        pts = _demi_plan(pts, poly[i], poly[(i + 1) % len(poly)], d)
        if len(pts) < 3:
            return []
    return pts


def _aire(pts):
    return 0.5 * sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                     for i in range(len(pts)))


def _dedans(p, poly, d=0.0):
    return all((p[0] - poly[i][0]) * -(poly[(i + 1) % len(poly)][1] - poly[i][1])
               + (p[1] - poly[i][1]) * (poly[(i + 1) % len(poly)][0] - poly[i][0])
               >= d * math.hypot(poly[(i + 1) % len(poly)][0] - poly[i][0], poly[(i + 1) % len(poly)][1] - poly[i][1])
               for i in range(len(poly)))


def _prisme(g, pts, z0, z1, m, style, what):
    n = len(pts)
    vs = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        fs.append((i, j, n + j, n + i))
    g._add(m, style, vs, fs, what)


def _motif(g, M, cfg, P, zb, ins, graine):
    """Motif du pont sur le polygone convexe direct P (Blender), rentré de ins sous les cornières ; zb : dessus du
    tablier. Hasard LOCAL (graine) : le tirage du reste du bâtiment ne change pas."""
    import random
    rng = random.Random(graine)
    mats = [M[cfg["mat"]]] + ([M[cfg["mat2"]]] if cfg["mat2"] else [])
    motif = cfg["motif"]
    xs = [p[0] for p in P]
    ys = [p[1] for p in P]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    if motif == "caillebotis":
        hx = (x1 - x0) / 2.0
        xc = (x0 + x1) / 2.0
        nb = int((2 * hx - 0.1) / 0.09)
        for i in range(nb):
            x = xc - hx + 0.05 + (i + 0.5) * (2 * hx - 0.1) / nb
            band = _decoupe([(x - 0.015, y0 - 1), (x + 0.015, y0 - 1), (x + 0.015, y1 + 1), (x - 0.015, y1 + 1)], P, ins)
            if band:
                _prisme(g, band, zb, zb + 0.024, mats[i % len(mats)], "flat", "lame")
        return
    pas = cfg["pas"] or PAS_DEFAUT[motif]
    jt = cfg["joint"] if cfg["joint"] is not None else JOINT_DEFAUT[motif]
    ep_ = 0.022
    if motif == "planches":
        wy = pas * SQ2
        nrow = int(math.ceil((y1 - y0) / wy)) + 1
        for j in range(nrow):
            ya = y0 + j * wy
            yb = ya + wy
            xa = x0 - rng.random() * 0.5
            while xa < x1:
                L = 0.5 + 0.5 * rng.random()
                xb = xa + L
                q = _decoupe([(xa + jt / 2, ya + jt / 2), (xb - jt / 2, ya + jt / 2), (xb - jt / 2, yb - jt / 2),
                              (xa + jt / 2, yb - jt / 2)], P, ins)
                if q and _aire(q) > 0.004:
                    th = ep_ * (1.0 + cfg["relief"] * (rng.random() - 0.5))
                    _prisme(g, q, zb, zb + th, mats[rng.randrange(len(mats))], "hard", "planche")
                    if cfg["boulons"]:
                        for xx in (xa + 0.045, xb - 0.045):
                            for f in (0.3, 0.7):
                                p = (xx, ya + wy * f)
                                if _dedans(p, q, 0.012):
                                    g.dome((p[0], p[1], zb + th), (0, 0, 1), 0.014, M[cfg["boulons"]], what="clou")
                xa = xb
        return
    # dalles et tôles : grille alignée sur le centre (symétrique), cases de pas × pas tuiles de jeu
    px, py = pas, pas * SQ2
    i0, i1 = int(math.floor(x0 / px)) - 1, int(math.ceil(x1 / px)) + 1
    j0, j1 = int(math.floor(y0 / py)) - 1, int(math.ceil(y1 / py)) + 1
    for i in range(i0, i1):
        for j in range(j0, j1):
            xa, xb = i * px + jt / 2, (i + 1) * px - jt / 2
            ya, yb = j * py + jt / 2, (j + 1) * py - jt / 2
            q = _decoupe([(xa, ya), (xb, ya), (xb, yb), (xa, yb)], P, ins)
            if not q or _aire(q) < 0.004:
                continue
            th = ep_ * (1.0 + cfg["relief"] * (rng.random() - 0.5))
            m = mats[rng.randrange(len(mats))] if len(mats) > 1 else mats[0]
            _prisme(g, q, zb, zb + th, m, "hard", "dalle_pont" if motif == "dalles" else "tole_pont")
            if motif == "toles" and cfg["boulons"]:
                for p in ((xa + 0.035, ya + 0.035), (xb - 0.035, ya + 0.035), (xb - 0.035, yb - 0.035),
                          (xa + 0.035, yb - 0.035), ((xa + xb) / 2, ya + 0.035), ((xa + xb) / 2, yb - 0.035)):
                    if _dedans(p, q, 0.012):
                        g.dome((p[0], p[1], zb + th), (0, 0, 1), 0.016, M[cfg["boulons"]], what="rivet_pont")


def _lisere(g, M, cfg, p0, p1, nrm, z):
    """Liseré lumineux (clé plateforme.lisere) sur le dessus de la cornière, côté intérieur."""
    d = p1 - p0
    L = d.length
    d = d.normalized()
    R = Matrix((d, V((-d.y, d.x, 0)), V((0, 0, 1)))).transposed()
    g.box((p0 + p1) / 2 - nrm * 0.07 + V((0, 0, z + 0.003)), (L * 0.96, 0.012, 0.006), M[cfg["lisere"]], "flat", R=R,
          what="lisere")


# motif du dessus par défaut de chaque forme quand l'époque ne donne pas la clé « plateforme » (qui l'emporte)
PONT_FORME = {
    "carre": None,                                                  # caillebotis de la lignée
    "bastions": None,
    "rond": dict(motif="toles", mat="grate", boulons="rivet"),
    "hexagone": dict(motif="dalles", mat="grate", joint=0.012, boulons=None),
    "pierre": dict(motif="dalles", mat="stone2", mat2="stone", fond="seam", boulons=None, pas=0.3, relief=0.5),
    "gradins": dict(motif="dalles", mat="steel_dk", mat2="armor2", fond="seam", boulons=None, pas=0.3),
    "pilotis": dict(motif="planches", mat="wood", mat2="wood2", boulons="rivet"),
}
# matières par défaut (flanc, flanc2) de chaque forme, lues dans la palette HABILLÉE (elles suivent capots, acier…)
FLANC_FORME = {
    "carre": ("hazy", "steel_dk"),       # garde-corps : lisses (jaune de danger), poteaux et plinthes
    "bastions": ("armor", "steel_dk"),   # tours d'angle blindées
    "rond": ("olive", "steel_dk"),       # tôles rivetées de la jupe du pont, collerette
    "hexagone": ("steel_dk", "armor2"),  # panneaux des flancs, noyau et biseau
    "pierre": ("stone2", "stone"),       # assises de pierre, créneaux
    "gradins": ("steel_dk", "armor2"),   # gradins pairs, impairs
    "pilotis": ("wood", "wood2"),        # pieux, poutres de rive
}
# précision (règle d'or 4) : pièces de taille constante, plus nombreuses aux grandes tailles
MERLON = (0.075, 0.1, 0.08)              # hauteur, largeur, créneau
GARDE_CORPS_H = 0.16


class _hasard_local:
    """`with _hasard_local(g, graine):` : la forme dessine avec son PROPRE tirage au sort (g.rng remplacé), pour ne pas
    déplacer le hasard du reste du bâtiment."""

    def __init__(self, g, graine):
        self.g, self.graine = g, graine

    def __enter__(self):
        import random
        self.old = self.g.rng
        self.g.rng = random.Random(self.graine)

    def __exit__(self, *exc):
        self.g.rng = self.old


class _a_blanc:
    """`with _a_blanc(g):` : dessine SANS rien ajouter (g._add muet) ; sert à rejouer la pièce d'origine qu'une forme
    remplace, pour que g.rng avance EXACTEMENT comme dans la lignée : le reste du bâtiment (plaques, jeu des épaisseurs)
    reste celui de la lignée (passe 5 : un trou de 9 px au pied du canon 5×5 venait de ce décalage, 6 px sur le
    témoin)."""

    def __init__(self, g):
        self.g = g

    def __enter__(self):
        self.g._add = lambda *a, **k: None

    def __exit__(self, *exc):
        del self.g._add


def _PB(poly):
    return [(x, Y(y)) for x, y in poly]


def _aretes(PB):
    """Arêtes d'un polygone direct (Blender) : (début, fin, normale SORTANTE)."""
    n = len(PB)
    for i in range(n):
        pa = V((PB[i][0], PB[i][1], 0.0))
        pb = V((PB[(i + 1) % n][0], PB[(i + 1) % n][1], 0.0))
        d = pb - pa
        if d.length < 0.05:
            continue
        t = d.normalized()
        yield pa, pb, V((t.y, -t.x, 0.0))


def _Rx(d):
    t = d.normalized()
    return Matrix((t, V((-t.y, t.x, 0)), V((0, 0, 1)))).transposed()


def _parapet(g, pa, pb, nrm, z, w, hp, mat, merlons=None, what="parapet"):
    """Muret plein le long de pa -> pb (côté intérieur), créneaux (hauteur, largeur, créneau) facultatifs. Plein : il
    n'enferme aucun jour, même au bord nord."""
    d = pb - pa
    L = d.length
    if L < 0.06:
        return
    R = _Rx(d)
    t = d.normalized()
    g.box((pa + pb) / 2 - nrm * (w / 2) + V((0, 0, z + hp / 2)), (L, w, hp), mat, "hard", R=R, what=what)
    if merlons:
        hm, wm, gap = merlons
        k = int((L + gap) / (wm + gap))
        if k < 1:
            return
        s0 = (L - (k * wm + (k - 1) * gap)) / 2
        for j in range(k):
            u = s0 + wm / 2 + j * (wm + gap)
            g.box(pa + t * u - nrm * (w / 2) + V((0, 0, z + hp + hm / 2)), (wm, w, hm), mat, "hard", R=R,
                  what="merlon")


def _garde_corps(g, pa, pb, nrm, z, hg, lisse, poteau):
    """Garde-corps : poteaux tous les 0,3 au plus, lisse haute, sous-lisse, plinthe. JAMAIS sur un bord nord (le jour
    entre les lisses s'ouvrirait sur le vide du sprite : trou enfermé) : là, _parapet."""
    d = pb - pa
    L = d.length
    t = d.normalized()
    R = _Rx(d)
    k = max(1, int(math.ceil(L / 0.3)))
    for j in range(k + 1):
        p = pa + t * (L * j / k) - nrm * 0.035
        g.box(p + V((0, 0, z + hg / 2)), (0.026, 0.026, hg), poteau, "hard", R=R, what="poteau")
    m = (pa + pb) / 2 - nrm * 0.035
    g.box(m + V((0, 0, z + hg - 0.012)), (L, 0.026, 0.024), lisse, "hard", R=R, what="lisse")
    g.box(m + V((0, 0, z + hg * 0.52)), (L, 0.02, 0.02), lisse, "hard", R=R, what="lisse")
    g.box(m + V((0, 0, z + 0.022)), (L, 0.014, 0.044), poteau, "hard", R=R, what="plinthe")


def _filet(g, mat, pa, pb, nrm, z, ins=0.02, w=0.012):
    """Liseré lumineux fin le long d'une arête (option « lisere » des formes)."""
    d = pb - pa
    g.box((pa + pb) / 2 - nrm * ins + V((0, 0, z + 0.003)), (d.length * 0.97, w, 0.006), mat, "flat", R=_Rx(d),
          what="lisere")


def _quad_flanc(pa, pb, z0, z1):
    """Quadrilatère d'un flanc vertical (sens direct vu de l'extérieur pour une arête d'un polygone direct)."""
    return [pa + V((0, 0, z0)), pb + V((0, 0, z0)), pb + V((0, 0, z1)), pa + V((0, 0, z1))]


def _tronc(g, A, B, z0, z1, mat, style="hard", what="biseau"):
    """Tronc de prisme entre le polygone A (z0) et le polygone B (z1), sommets appariés ; prisme de B si leurs nombres
    de sommets diffèrent."""
    if len(A) != len(B):
        _prisme(g, B, z0, z1, mat, style, what)
        return
    n = len(A)
    vs = [(x, y, z0) for x, y in A] + [(x, y, z1) for x, y in B]
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g._add(mat, style, vs, fs, what)
