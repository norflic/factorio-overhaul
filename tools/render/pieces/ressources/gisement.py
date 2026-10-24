"""Pièce de rendu « feuille de gisement » (lot M1, 24/10) : s'exécute DANS Blender, par
tools/render/blender/render_piece.py (via feuille.py et le verrou de rendu ; jamais Blender directement).

La variante est le nom d'une direction de directions.py (« A », « B », « C »). La scène pose, en UN rendu, une grille
de cellules espacées de directions.PAS tuiles :
  - lignes 0 à 7 : les 8 stades (ligne 0 = le plus riche), colonnes 0 à 7 : les 8 variantes ;
  - ligne 8 : 4 cellules d'icônes (icône, puis 3 images d'objet au sol ou sur tapis).
Cellule (ligne r, colonne c) : centre au sol en tuiles de jeu (PAS × (c − 3,5), PAS × (r − 4)) ; feuille.py recadre
chaque cellule en 128 × 128 px autour de ce centre (position de l'entité = centre de la tuile).

Conventions de tools/render/README.md (1 unité = 1 tuile en X ; une tuile vers le sud = 1/cos 45° unité en Y).
Hasard local déterministe (random.Random, graine par direction, stade et variante) ; aucun ordre de dictionnaire.
"""
import math
import os
import random
import sys

import bpy
import bmesh

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import directions as D  # noqa: E402

PIECE = {"name": "gisement", "variants": {k: {} for k in sorted(D.DIRECTIONS)}, "margin_px": 32}


def centre_cellule(r, c):
    """Centre au sol (tuiles de jeu, y vers le sud) de la cellule (ligne r, colonne c)."""
    return (D.PAS * (c - 3.5), D.PAS * (r - 4.0))


# ------------------------------------------------------------------------------------------------
# Maillages
# ------------------------------------------------------------------------------------------------
def _objet(nom, verts, faces, mat, S, lisse=None):
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


def _transforme(verts, rx, rz, tx, ty, tz):
    """Rotation autour de X (inclinaison) puis de Z (azimut), puis translation."""
    out = []
    cx, sx = math.cos(rx), math.sin(rx)
    cz, sz = math.cos(rz), math.sin(rz)
    for x, y, z in verts:
        y, z = y * cx - z * sx, y * sx + z * cx
        x, y = x * cz - y * sz, x * sz + y * cz
        out.append((x + tx, y + ty, z + tz))
    return out


def roche(rng, taille, aplat=0.55, n_coupes=3, cassure=(0.55, 0.85)):
    """Roche facettée : icosphère (2 subdivisions) bosselée, aplatie, fond à plat. Renvoie (sommets, faces)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    sx = taille * rng.uniform(0.8, 1.2)
    sy = taille * rng.uniform(0.7, 1.1)
    sz = taille * aplat * rng.uniform(0.75, 1.2)
    verts = []
    # bosses à deux échelles : trois plans de coupe (faces de cassure) + bruit fin par sommet
    coupes = [(rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0, 1), rng.uniform(*cassure))
              for _ in range(n_coupes)]
    for v in bm.verts:
        k = rng.uniform(0.92, 1.08)
        for ax, ay, az, d in coupes:
            n = math.sqrt(ax * ax + ay * ay + az * az) or 1.0
            p = (v.co.x * ax + v.co.y * ay + v.co.z * az) / n
            if p > d:
                k *= d / p
        x, y, z = v.co.x * k * sx, v.co.y * k * sy, v.co.z * k * sz
        z = max(z, -0.15 * sz)
        verts.append((x, y, z + 0.15 * sz))
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, faces


def grain(rng, taille):
    """Petit grain (icosphère sans subdivision)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=0, radius=1.0)
    verts = []
    for v in bm.verts:
        k = rng.uniform(0.75, 1.25)
        verts.append((v.co.x * taille * k, v.co.y * taille * k, max(v.co.z, -0.2) * taille * 0.6 * k + 0.12 * taille))
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, faces


def lame(rng, longueur, largeur, ep):
    """Lame tabulaire de wolframite : prisme à section hexagonale aplatie (largeur × épaisseur), terminé en biseau
    (coupe oblique du cristal monoclinique). Base à z = 0, axe +Z."""
    sec = []
    for i in range(6):
        a = math.pi / 3 * i
        sec.append((0.5 * largeur * math.cos(a), 0.5 * ep * math.sin(a)))
    pente = rng.uniform(0.35, 0.8) * (1 if rng.random() < 0.5 else -1)
    verts = [(x, y, -0.04) for x, y in sec]
    verts += [(x, y, longueur + pente * x) for x, y in sec]
    faces = [list(range(5, -1, -1)), list(range(6, 12))]
    for i in range(6):
        j = (i + 1) % 6
        faces.append([i, j, 6 + j, 6 + i])
    return verts, faces


def bloc(rng, taille, haut):
    """Bloc de métal : cuboïde légèrement irrégulier (le biseau est un modificateur)."""
    lx = taille * rng.uniform(0.75, 1.15)
    ly = taille * rng.uniform(0.55, 0.95)
    h = haut
    verts = []
    for z in (0.0, h):
        for x, y in ((-lx / 2, -ly / 2), (lx / 2, -ly / 2), (lx / 2, ly / 2), (-lx / 2, ly / 2)):
            j = rng.uniform(-0.12, 0.12) * h if z > 0 else 0.0
            verts.append((x, y, z + j))
    faces = [[3, 2, 1, 0], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return verts, faces


# ------------------------------------------------------------------------------------------------
# Placement
# ------------------------------------------------------------------------------------------------
def _places(rng, n, rayon, ecart, deja):
    """n positions (tuiles de jeu, relatives au centre) dans un disque, à `ecart` au moins des autres."""
    out = []
    essais = 0
    while len(out) < n and essais < 400:
        essais += 1
        a = rng.uniform(0, 2 * math.pi)
        r = rayon * math.sqrt(rng.random())
        x, y = r * math.cos(a), r * math.sin(a)
        if all((x - px) ** 2 + (y - py) ** 2 >= ecart ** 2 for px, py in deja + out):
            out.append((x, y))
    return out


def _compte(seq, stade, echelle, rng):
    v = seq[stade] * echelle
    n = int(v)
    if rng.random() < v - n:
        n += 1
    return n


def cellule(S, C, mats, lave, d, cle, r, c, stade, rng, icone=False):
    cx, cy = centre_cellule(r, c)
    e = D.ECHELLE.get(cle, 1.0)
    rayon = d["rayon"] * (0.75 if icone else 1.0)
    objs = []
    occupe = []

    def pose(verts, faces, mat, gx, gy, nom, lisse=None, biseau=None):
        bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
        rz = rng.uniform(0, 2 * math.pi)
        vv = _transforme(verts, 0.0, rz, bx, by, 0.0)
        o = _objet(nom, vv, faces, mat, S, lisse)
        if biseau:
            S.bevel(o, biseau, 1)
        objs.append(o)
        return o

    tag = "%s_%d_%d" % (cle, r, c)
    # roches de pied / matrice
    n_roche = _compte(d["roches"], stade, e, rng) + (2 if icone else 0)
    for i, (gx, gy) in enumerate(_places(rng, n_roche, rayon, 0.22, occupe)):
        occupe.append((gx, gy))
        t = rng.uniform(*d["roche_taille"]) * (1.25 if icone else 1.0)
        v, f = roche(rng, t, aplat=D.ROCHE_APLAT.get(cle, 0.55), n_coupes=D.ROCHE_COUPES.get(cle, 3),
                     cassure=D.ROCHE_CASSURE.get(cle, (0.55, 0.85)))
        pose(v, f, mats[rng.choice(d["roche_mats"])], gx, gy, "%s_roche%d" % (tag, i), lisse=D.ROCHE_LISSE.get(cle, 38))
    # blocs de métal
    n_bloc = _compte(d["blocs"], stade, e, rng) + (3 if icone and max(d["blocs"]) else 0)
    for i, (gx, gy) in enumerate(_places(rng, n_bloc, rayon, 0.24, occupe)):
        occupe.append((gx, gy))
        t = rng.uniform(*d["bloc_taille"]) * (1.2 if icone else 1.0)
        v, f = bloc(rng, t, rng.uniform(*d["bloc_haut"]))
        pose(v, f, mats[rng.choice(d["bloc_mats"])], gx, gy, "%s_bloc%d" % (tag, i), biseau=0.018)
    # touffes de lames (inclinées en éventail depuis un même pied)
    n_touffe = _compte(d["touffes"], stade, e, rng) + (2 if icone and max(d["touffes"]) else 0)
    for i, (gx, gy) in enumerate(_places(rng, n_touffe, rayon * 0.9, 0.26, occupe)):
        occupe.append((gx, gy))
        n_l = rng.randint(*d["lames"])
        az0 = rng.uniform(0, 2 * math.pi)
        for j in range(n_l):
            L = rng.uniform(*d["lame_long"]) * (1.2 if icone else 1.0)
            v, f = lame(rng, L, rng.uniform(*d["lame_larg"]), rng.uniform(*d["lame_ep"]))
            incl = math.radians(rng.uniform(*d["lame_incl"]))
            az = az0 + 2 * math.pi * j / max(1, n_l) + rng.uniform(-0.5, 0.5)
            bx, by, _ = C.tile_to_blender(cx + gx + rng.uniform(-0.07, 0.07), cy + gy + rng.uniform(-0.07, 0.07))
            vv = _transforme(v, incl, az, bx, by, 0.0)
            # rotation propre de la lame autour de son axe : appliquée avant par un tour de Z
            o = _objet("%s_lame%d_%d" % (tag, i, j), vv, f, mats[rng.choice(d["lame_mats"])], S)
            S.bevel(o, 0.006, 1)
            objs.append(o)
    # filons de lave (C) : bandes basses émissives au sol, entre les roches
    if lave is not None and d.get("filons"):
        n_f = _compte(d["filons"], stade, 1.0, rng) + (1 if icone else 0)
        for i, (gx, gy) in enumerate(_places(rng, n_f, rayon * 0.8, 0.18, [])):
            L = rng.uniform(0.18, 0.34)
            v, f = bloc(rng, L, 0.02)
            v = [(x, y * 0.25, z) for x, y, z in v]
            pose(v, f, lave, gx, gy, "%s_filon%d" % (tag, i))
    # grains (cendre, éclats) : quelques gros grains, puis le TAPIS de grains fins (le « sable » des minerais
    # vanilla qui lie le gisement au sol) ; un maillage par matière et par cellule (milliers de grains)
    if not icone:
        acc = {}
        def ajoute(nom_mat, v, f, gx, gy):
            bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
            vv = _transforme(v, 0.0, rng.uniform(0, 2 * math.pi), bx, by, 0.0)
            V, F = acc.setdefault(nom_mat, ([], []))
            base = len(V)
            V.extend(vv)
            F.extend([[base + k for k in face] for face in f])
        n_g = _compte(d["grains"], stade, e, rng)
        for gx, gy in _places(rng, n_g, rayon * 1.12, 0.05, []):
            v, f = grain(rng, rng.uniform(0.022, 0.045))
            ajoute(rng.choice(d["grain_mats"]), v, f, gx, gy)
        fins = d.get("fins", D.FINS)
        if fins:
            d = dict(d, fin_mats=d.get("fin_mats", D.FIN_MATS))
            n_f = _compte(fins, stade, 1.0, rng)
            for _ in range(n_f):
                a = rng.uniform(0, 2 * math.pi)
                r = rayon * 1.15 * math.sqrt(rng.random())
                v, f = grain(rng, rng.uniform(0.016, 0.026))
                ajoute(rng.choice(d["fin_mats"]), v, f, r * math.cos(a), r * math.sin(a))
        for nom_mat in sorted(acc):
            V, F = acc[nom_mat]
            objs.append(_objet("%s_grains_%s" % (tag, nom_mat), V, F, mats[nom_mat], S))
    return objs


def cellule_icone(S, C, mats, d, cle, c, rng):
    """Cellule d'ICÔNE (ronde 3 : l'icône tirée d'une cellule de gisement se lisait « tas de cailloux gris ») : une
    grosse druse (5 à 7 lames, 2 à 2,5 fois la taille du gisement) sur 2 ou 3 blocs du pied, en gros plan comme les
    icônes vanilla (icons/iron-ore.png : 3 ou 4 gros morceaux qui remplissent le cadre)."""
    cx, cy = centre_cellule(D.STADES, c)
    ic = D.ICONE.get(cle, {})
    objs = []
    tag = "%s_icone%d" % (cle, c)
    for i in range(rng.randint(2, 3)):
        a = rng.uniform(0, 2 * math.pi)
        gx, gy = 0.28 * math.cos(a), 0.22 * math.sin(a)
        v, f = roche(rng, rng.uniform(0.24, 0.32), aplat=0.75, n_coupes=7, cassure=(0.35, 0.7))
        bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
        vv = _transforme(v, 0.0, rng.uniform(0, 2 * math.pi), bx, by, 0.0)
        objs.append(_objet("%s_roche%d" % (tag, i), vv, f, mats[rng.choice(ic.get("roche_mats", d["roche_mats"]))],
                           S, D.ROCHE_LISSE.get(cle, 38)))
    n_l = rng.randint(*ic.get("lames", (5, 7)))
    az0 = rng.uniform(0, 2 * math.pi)
    k = ic.get("echelle", 2.2)
    for j in range(n_l):
        L = rng.uniform(*d["lame_long"]) * k
        v, f = lame(rng, L, rng.uniform(*d["lame_larg"]) * k * 0.8, rng.uniform(*d["lame_ep"]) * k * 0.8)
        incl = math.radians(rng.uniform(5, 38))
        az = az0 + 2 * math.pi * j / n_l + rng.uniform(-0.4, 0.4)
        bx, by, _ = C.tile_to_blender(cx + rng.uniform(-0.1, 0.1), cy + rng.uniform(-0.08, 0.08))
        vv = _transforme(v, incl, az, bx, by, 0.0)
        o = _objet("%s_lame%d" % (tag, j), vv, f, mats[rng.choice(ic.get("lame_mats", d["lame_mats"]))], S)
        S.bevel(o, 0.01, 1)
        objs.append(o)
    return objs


def build(S, C, variant):
    cle = variant
    d = D.DIRECTIONS[cle]
    mats = {}
    for nom in sorted(D.MAT):
        m = D.MAT[nom]
        mats[nom] = S.mat_metal("m1_" + nom, m["color"], rough=m["rough"], metallic=m["met"], grain=m["grain"],
                                grain_scale=m["gscale"], dirt=m["dirt"], dirt_distance=0.08)
    lave = None
    if d.get("effet") == "lave":
        lave = S.mat_emissive("m1_lave", D.LAVE["color"], strength=D.LAVE["strength"], base=D.LAVE["base"],
                              main_scale=0.0)
    lignes = int(os.environ.get("FO_M1_LIGNES", str(D.STADES + 1)))
    icones_seules = os.environ.get("FO_M1_ICONES_SEULES") == "1"
    if not icones_seules:
        for r in range(min(lignes, D.STADES)):
            for c in range(D.COLONNES):
                rng = random.Random(D.GRAINE[cle] * 1000 + r * 37 + c)
                cellule(S, C, mats, lave, d, cle, r, c, r, rng)
    if lignes > D.STADES or icones_seules:
        for c in range(4):
            rng = random.Random(D.GRAINE[cle] * 1000 + 900 + c)
            if cle in D.ICONE:
                cellule_icone(S, C, mats, d, cle, c, rng)
            else:
                cellule(S, C, mats, lave, d, cle, D.STADES, c, 0, rng, icone=True)
