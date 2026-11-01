"""Pièce de rendu « icône de la blende » (lot ICONE-BLENDE, 30/10). S'exécute DANS Blender, par
tools/render/blender/render_piece.py, appelé par icones.py sous le verrou de rendu (jamais Blender directement).

Une scène = les 4 tas (icône + 3 images d'objet) côte à côte, centres en (ECART × (i − 1,5), 0) tuiles. Formes et
matières : reglages.py (même modèle que le gisement S8 de directions.py). Hasard : random.Random par morceau, graine
fixe ; aucun ordre de dictionnaire.
"""
import math
import os
import random
import sys

import bpy
import bmesh

ICI = os.path.dirname(os.path.abspath(__file__))
for p in (ICI, os.path.dirname(ICI)):
    if p not in sys.path:
        sys.path.insert(0, p)
import reglages as R  # noqa: E402
import directions as D  # noqa: E402

PIECE = {"name": "icone-blende", "variants": {"tas": {}}, "margin_px": 32}

# Clivage de la sphalérite : dodécaèdre rhombique {110}
NORMALES_110 = []
for _a in (1.0, -1.0):
    for _b in (1.0, -1.0):
        NORMALES_110 += [(_a, _b, 0.0), (_a, 0.0, _b), (0.0, _a, _b)]


def _rot(rng):
    """Matrice de rotation au hasard (3 angles d'Euler)."""
    a, b, c = (rng.uniform(0, 2 * math.pi) for _ in range(3))
    ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    rx = ((1, 0, 0), (0, ca, -sa), (0, sa, ca))
    ry = ((cb, 0, sb), (0, 1, 0), (-sb, 0, cb))
    rz = ((cc, -sc, 0), (sc, cc, 0), (0, 0, 1))

    def mul(m, n):
        return tuple(tuple(sum(m[i][k] * n[k][j] for k in range(3)) for j in range(3)) for i in range(3))
    return mul(rz, mul(ry, rx))


def _app(m, v):
    return tuple(m[i][0] * v[0] + m[i][1] * v[1] + m[i][2] * v[2] for i in range(3))


def morceau(rng, rayon):
    """Bloc de matrice : icosphère (3 subdivisions) taillée par des plans de clivage {110} tournés au hasard (facettes
    planes larges, comme une cassure de blende), bosselée à basse fréquence, aplatie, fond à plat. Renvoie
    (sommets, faces, hauteur, sommet_haut) en unités du morceau centré à l'origine (fond à z = 0)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    m = _rot(rng)
    normales = [_app(m, (x / math.sqrt(2.0), y / math.sqrt(2.0), z / math.sqrt(2.0))) for x, y, z in NORMALES_110]
    idx = list(range(12))
    rng.shuffle(idx)
    coupes = [(normales[i], rng.uniform(*R.CASSURE)) for i in idx[:rng.randint(*R.COUPES)]]
    bosses = [(_app(_rot(rng), (0.0, 0.0, 1.0)), rng.uniform(-R.BOSSES, R.BOSSES), rng.uniform(0.5, 0.9))
              for _ in range(4)]
    sx = rayon * rng.uniform(0.92, 1.10)
    sy = rayon * rng.uniform(0.80, 1.00)
    sz = rayon * rng.uniform(*R.APLAT)
    verts = []
    for v in bm.verts:
        p = (v.co.x, v.co.y, v.co.z)
        k = 1.0
        for c, a, s in bosses:
            d2 = (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2
            k *= 1.0 + a * math.exp(-d2 / (s * s))
        q = (p[0] * k, p[1] * k, p[2] * k)
        for n, d in coupes:
            pr = q[0] * n[0] + q[1] * n[1] + q[2] * n[2]
            if pr > d:
                f = d / pr
                q = (q[0] * f, q[1] * f, q[2] * f)
        f = rng.uniform(0.985, 1.015)
        verts.append((q[0] * sx * f, q[1] * sy * f, q[2] * sz * f))
    faces = [[v.index for v in fa.verts] for fa in bm.faces]
    bm.free()
    z0 = min(v[2] for v in verts)
    zb = z0 + 0.22 * (max(v[2] for v in verts) - z0)          # fond enfoui (posé sur le sol, pas une bille)
    verts = [(x, y, max(0.0, z - zb)) for x, y, z in verts]
    return verts, faces


def tetra(rng, taille):
    """Tétraèdre tronqué (même solide que gisement.tetra de S8), sommets bruités ; centré à l'origine, orienté au
    hasard. Renvoie (sommets, faces) avec faces orientées vers l'extérieur."""
    T = ((1.0, 1.0, 1.0), (1.0, -1.0, -1.0), (-1.0, 1.0, -1.0), (-1.0, -1.0, 1.0))
    t = rng.uniform(*R.CRISTAL_TRONC)
    verts, idx = [], {}
    for i in range(4):
        for j in range(4):
            if i != j:
                idx[(i, j)] = len(verts)
                verts.append(tuple(T[i][k] + t * (T[j][k] - T[i][k]) for k in range(3)))
    b = R.CRISTAL_BRUIT * math.sqrt(3.0) * 2.0
    verts = [tuple(v[k] + rng.uniform(-b, b) for k in range(3)) for v in verts]
    faces = []
    for i in range(4):
        faces.append([idx[(i, j)] for j in range(4) if j != i])
    for f in range(4):
        a, bb, c = [j for j in range(4) if j != f]
        faces.append([idx[(a, bb)], idx[(bb, a)], idx[(bb, c)], idx[(c, bb)], idx[(c, a)], idx[(a, c)]])
    m = _rot(rng)
    k = taille / (2.0 * math.sqrt(2.0))       # arête du tétraèdre de référence = 2√2
    out = [tuple(x * k for x in _app(m, v)) for v in verts]
    ok = []
    for fa in faces:
        p0, p1, p2 = out[fa[0]], out[fa[1]], out[fa[2]]
        u = [p1[q] - p0[q] for q in range(3)]
        w = [p2[q] - p0[q] for q in range(3)]
        n = (u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0])
        mc = [sum(out[q][r] for q in fa) / len(fa) for r in range(3)]
        ok.append(fa if n[0] * mc[0] + n[1] * mc[1] + n[2] * mc[2] >= 0 else list(reversed(fa)))
    return out, ok


# ------------------------------------------------------------------------------------------------
# Matières : couleurs de directions.MAT (S8), en matière minérale
# ------------------------------------------------------------------------------------------------
def _entree(p, nom, val):
    if nom in p.inputs:
        p.inputs[nom].default_value = val


def mat_blende(nom, stops, rough, marbrure=12.0, relief=0.15, relief_echelle=45.0, sss=0.0, dirt=0.45,
               reflet=(0.80, 0.36, 0.30), niveau=0.30, grain=0.0):
    """Principled : couleur marbrée (rampe `stops` = [(position, couleur linéaire)] sur un bruit en coordonnées
    d'objet), rugosité variable, relief fin de cassure (bump), indice 2,37 (sphalérite) à éclat atténué, reflet teinté,
    diffusion interne rouge facultative (sss)."""
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    n1 = N.new("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = marbrure
    n1.inputs["Detail"].default_value = 4.0
    n1.inputs["Roughness"].default_value = 0.55
    L.new(tc.outputs["Object"], n1.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], tuple(stops[0][1]) + (1.0,)
    els[1].position, els[1].color = stops[-1][0], tuple(stops[-1][1]) + (1.0,)
    for pos, col in stops[1:-1]:
        e = els.new(pos)
        e.color = tuple(col) + (1.0,)
    L.new(n1.outputs["Fac"], ramp.inputs["Fac"])
    col = ramp.outputs["Color"]
    if grain > 0:
        # grain fin de l'albédo (± grain), la « matière » des icônes vanilla (essai 5 : faces unies, mates)
        n3 = N.new("ShaderNodeTexNoise")
        n3.inputs["Scale"].default_value = 70.0
        n3.inputs["Detail"].default_value = 6.0
        n3.inputs["Roughness"].default_value = 0.65
        L.new(tc.outputs["Object"], n3.inputs["Vector"])
        g = N.new("ShaderNodeMapRange")
        g.inputs["From Min"].default_value = 0.3
        g.inputs["From Max"].default_value = 0.7
        g.inputs["To Min"].default_value = 1.0 - grain
        g.inputs["To Max"].default_value = 1.0 + grain
        L.new(n3.outputs["Fac"], g.inputs["Value"])
        gm = N.new("ShaderNodeVectorMath")
        gm.operation = "SCALE"
        L.new(col, gm.inputs[0])
        L.new(g.outputs["Result"], gm.inputs["Scale"])
        col = gm.outputs["Vector"]
    if dirt > 0:
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.05
        ao.samples = 8
        dm = N.new("ShaderNodeMapRange")
        dm.inputs["To Min"].default_value = 1.0 - dirt
        dm.inputs["To Max"].default_value = 1.0
        L.new(ao.outputs["AO"], dm.inputs["Value"])
        mul = N.new("ShaderNodeVectorMath")
        mul.operation = "SCALE"
        L.new(col, mul.inputs[0])
        L.new(dm.outputs["Result"], mul.inputs["Scale"])
        col = mul.outputs["Vector"]
    L.new(col, p.inputs["Base Color"])
    # rugosité : plus mate dans le sombre, plus lisse sur les plages claires (éclat résineux par plages)
    rr = N.new("ShaderNodeMapRange")
    rr.inputs["From Min"].default_value = 0.3
    rr.inputs["From Max"].default_value = 0.7
    rr.inputs["To Min"].default_value = rough * 1.6
    rr.inputs["To Max"].default_value = rough * 0.7
    L.new(n1.outputs["Fac"], rr.inputs["Value"])
    L.new(rr.outputs["Result"], p.inputs["Roughness"])
    _entree(p, "Metallic", 0.0)
    _entree(p, "IOR", 2.37)
    _entree(p, "Specular IOR Level", niveau)   # essai 2 : facettes saumon trop brillantes (0,5 = indice tel quel)
    # reflet TEINTÉ (essai 1 : reflets blancs du ciel sur les facettes planes, « plastique » ; l'éclat résineux de la
    # blende renvoie une lumière chaude)
    _entree(p, "Specular Tint", (reflet[0], reflet[1], reflet[2], 1.0))
    if sss > 0:
        _entree(p, "Subsurface Weight", sss)
        _entree(p, "Subsurface Radius", (1.0, 0.22, 0.06))
        _entree(p, "Subsurface Scale", 0.03)
        if "Subsurface Color" in p.inputs:
            p.inputs["Subsurface Color"].default_value = tuple(stops[-1][1]) + (1.0,)
    if relief > 0:
        n2 = N.new("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = relief_echelle
        n2.inputs["Detail"].default_value = 6.0
        n2.inputs["Roughness"].default_value = 0.6
        L.new(tc.outputs["Object"], n2.inputs["Vector"])
        bp = N.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = relief
        bp.inputs["Distance"].default_value = 0.01
        L.new(n2.outputs["Fac"], bp.inputs["Height"])
        L.new(bp.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def _objet(S, nom, verts, faces, mat, lisse):
    me = bpy.data.meshes.new(nom)
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    o = bpy.data.objects.new(nom, me)
    S.piece_collection().objects.link(o)
    o.data.materials.append(mat)
    if lisse is not None:
        S.smooth(o, lisse)
    return o


def build(S, C, variant):
    c = lambda nom: D.MAT[nom]["color"]  # noqa: E731
    # essai 3 : corps saumon et pailleté (relief fin trop fort, reflet chaud partout) : lu « cuivre ». Corps NOIR
    # dominant veiné de brun et de rubis (la matrice noire de S8), relief plus doux, reflet atténué.
    noire, brune, rubis_c, ambre_c = c("blende_noire"), c("blende_brune"), c("blende_rubis_r"), c("blende_ambre_r")
    # essai 5 : bonne lecture (matrice sombre, tétraèdres rubis et ambre) mais faces unies : marbrure plus fine, grain
    # de l'albédo, relief de cassure un peu plus marqué. Essai 6 : corps brun-rouille trop clair, sans contraste sur la
    # terre dirt-4 (le sol de la garantie de la blende), facettes mauves (reflet du ciel) : corps NOIR-brun dominant,
    # éclat atténué et plus mat ; cristaux plus lumineux (le contraste vient d'eux, comme le charbon tient par son noir).
    corps = mat_blende("icb_corps", [(0.50, noire), (0.64, brune), (0.82, rubis_c)], rough=0.38, marbrure=17.0,
                       relief=0.22, relief_echelle=60.0, grain=0.30, niveau=0.22)
    corps_rouge = mat_blende("icb_corps_rouge", [(0.42, noire), (0.58, brune), (0.76, rubis_c)], rough=0.36,
                             marbrure=15.0, relief=0.22, relief_echelle=60.0, grain=0.30, sss=0.15, niveau=0.22)
    rubis = mat_blende("icb_rubis", [(0.35, rubis_c), (0.75, tuple(min(1.0, 1.5 * x) for x in rubis_c))],
                       rough=0.22, marbrure=16.0, relief=0.10, sss=0.35, dirt=0.25)
    ambre = mat_blende("icb_ambre", [(0.35, ambre_c), (0.75, tuple(min(1.0, 1.3 * x) for x in ambre_c))],
                       rough=0.22, marbrure=16.0, relief=0.10, sss=0.35, dirt=0.25)
    cristaux = {"blende_rubis_r": rubis, "blende_ambre_r": ambre}
    for i, tas in enumerate(R.TAS):
        cx = R.ECART * (i - 1.5)
        for k, (x, y, rayon, n_cr) in enumerate(tas):
            rayon *= R.GROSSIT
            rng = random.Random(R.GRAINE + 1000 * i + k)
            v, f = morceau(rng, rayon)
            bx, by, _ = C.tile_to_blender(cx + R.RESSERRE * x, R.RESSERRE * y)
            az = rng.uniform(0, 2 * math.pi)
            ca, sa = math.cos(az), math.sin(az)
            vv = [(px * ca - py * sa + bx, px * sa + py * ca + by, pz) for px, py, pz in v]
            mat = corps_rouge if rng.random() < 0.35 else corps
            _objet(S, "icb_%d_%d" % (i, k), vv, f, mat, 12)
            # cristaux : posés sur le haut du morceau (sommets les plus hauts), enfouis d'une part de leur hauteur
            hauts = sorted(vv, key=lambda q: -q[2])[:max(8, len(vv) // 6)]
            for j in range(n_cr):
                q = hauts[rng.randrange(len(hauts))]
                # vers le bord du morceau pour le 2e cristal : druse qui déborde, pas une pointe au centre
                tx = q[0] + (q[0] - bx) * rng.uniform(0.0, 0.5 if j else 0.2)
                ty = q[1] + (q[1] - by) * rng.uniform(0.0, 0.5 if j else 0.2)
                t = rayon * rng.uniform(*R.CRISTAL_TAILLE) * (1.0 if j == 0 else 0.8)
                tv, tf = tetra(rng, t)
                z0 = min(p[2] for p in tv)
                h = max(p[2] for p in tv) - z0
                dz = q[2] - z0 - rng.uniform(*R.CRISTAL_ENFOUI) * h
                tv = [(p[0] + tx, p[1] + ty, max(0.0, p[2] + dz)) for p in tv]
                o = _objet(S, "icb_%d_%d_cr%d" % (i, k, j), tv, tf, cristaux[R.CRISTAUX[rng.randrange(len(R.CRISTAUX))]], None)
                S.bevel(o, 0.006 * rayon / 0.2, 1)
