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


def roche(rng, taille, aplat=0.55, n_coupes=3, cassure=(0.55, 0.85), creux=0, creux_prof=(0.22, 0.42)):
    """Roche facettée : icosphère (2 subdivisions) bosselée, aplatie, fond à plat. Renvoie (sommets, faces).

    creux (lot design-minerai-monazite, 30/10 ; 0 par défaut = roche d'avant, AUCUN tirage de hasard en plus) : nombre
    d'ENCOCHES (creux concaves) : une roche vanilla (fer, cuivre, pierre) a des rentrants et des arêtes, pas la
    silhouette convexe d'un galet."""
    encoches = []
    for _ in range(creux):
        ex, ey, ez = rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.1, 0.9)
        n = math.sqrt(ex * ex + ey * ey + ez * ez) or 1.0
        encoches.append((ex / n, ey / n, ez / n, math.cos(math.radians(rng.uniform(28, 46))), rng.uniform(*creux_prof)))
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
        for ex, ey, ez, c0, prof in encoches:
            t = v.co.x * ex + v.co.y * ey + v.co.z * ez
            if t > c0:
                u = (t - c0) / (1.0 - c0)
                k *= 1.0 - prof * u * u * (3 - 2 * u)
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


def coin(rng, taille, haut):
    """Éclat EN COIN (lot design-minerai-monazite, 30/10 : la monazite cristallise en prismes en coin) : base
    polygonale irrégulière à 5 ou 6 côtés, dessus plus étroit et INCLINÉ (une arête haute, l'autre basse) ; biseau en
    modificateur. Un éclat facetté, à arêtes franches, ni galet rond ni cube."""
    nb = rng.randint(5, 6)
    a0 = rng.uniform(0, 2 * math.pi)
    base = []
    for i in range(nb):
        a = a0 + 2 * math.pi * i / nb + rng.uniform(-0.35, 0.35)
        r = 0.5 * taille * rng.uniform(0.62, 1.08)
        base.append((r * math.cos(a), 0.8 * r * math.sin(a)))
    k = rng.uniform(0.45, 0.72)
    ox, oy = rng.uniform(-0.12, 0.12) * taille, rng.uniform(-0.12, 0.12) * taille
    pa = rng.uniform(0, 2 * math.pi)
    dx, dy = math.cos(pa), math.sin(pa)
    bas = rng.uniform(0.25, 0.5)
    verts = [(x, y, 0.0) for x, y in base]
    for x, y in base:
        xt, yt = x * k + ox, y * k + oy
        s_ = (xt * dx + yt * dy) / (0.5 * taille) * 0.5 + 0.5
        verts.append((xt, yt, haut * (bas + (1 - bas) * max(0.0, min(1.0, s_))) * rng.uniform(0.92, 1.06)))
    faces = [list(range(nb - 1, -1, -1)), list(range(nb, 2 * nb))]
    for i in range(nb):
        j = (i + 1) % nb
        faces.append([i, j, nb + j, nb + i])
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


def _places_amas(rng, n, centres, etendue, ecart, deja):
    """n positions groupées en AMAS (lot design-minerai-monazite) : chacune près d'un des centres (écart gaussien
    `etendue`), à `ecart` au moins des autres ; les pièces vanilla se touchent et laissent des trous, au lieu d'un
    semis régulier dans un disque."""
    out = []
    essais = 0
    while len(out) < n and essais < 600:
        essais += 1
        cx, cy = centres[rng.randrange(len(centres))]
        x, y = cx + rng.gauss(0, etendue), cy + rng.gauss(0, etendue)
        if x * x + y * y > 0.78 ** 2:
            continue
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
    # AMAS (lot design-minerai-monazite ; seulement si la direction a « amas ») : centres tirés une fois par cellule
    amas = d.get("amas")
    if amas:
        n_c = max(1, _compte(amas, stade, 1.0, rng))
        centres = _places(rng, n_c, rayon * 0.62, 0.30, []) or [(0.0, 0.0)]
        etendue = d.get("amas_etendue", 0.16)
        serre = d.get("amas_serre", 0.7)

        def places(n, ray, ecart, deja):
            return _places_amas(rng, n, centres, etendue, ecart * serre, deja)
    else:
        def places(n, ray, ecart, deja):
            return _places(rng, n, ray, ecart, deja)
    gros = d.get("gros")          # (comptes par stade, facteur de taille) : les premières pièces posées sont grosses
    n_gros = _compte(gros[0], stade, 1.0, rng) if gros else 0
    # roches de pied / matrice
    n_roche = _compte(d["roches"], stade, e, rng) + (2 if icone else 0)
    for i, (gx, gy) in enumerate(places(n_roche, rayon, 0.22, occupe)):
        occupe.append((gx, gy))
        t = rng.uniform(*d["roche_taille"]) * (1.25 if icone else 1.0)
        if gros and i < n_gros:
            t *= gros[1]
        v, f = roche(rng, t, aplat=D.ROCHE_APLAT.get(cle, 0.55), n_coupes=D.ROCHE_COUPES.get(cle, 3),
                     cassure=D.ROCHE_CASSURE.get(cle, (0.55, 0.85)), creux=D.ROCHE_CREUX.get(cle, 0))
        pose(v, f, mats[rng.choice(d["roche_mats"])], gx, gy, "%s_roche%d" % (tag, i), lisse=D.ROCHE_LISSE.get(cle, 38))
    # éclats en coin (lot design-minerai-monazite ; seulement si la direction a « coins »)
    if d.get("coins"):
        gros_c = d.get("gros_coins")    # comme « gros », pour les éclats en coin
        n_gros_c = _compte(gros_c[0], stade, 1.0, rng) if gros_c else 0
        n_coin = _compte(d["coins"], stade, e, rng) + (2 if icone else 0)
        for i, (gx, gy) in enumerate(places(n_coin, rayon, 0.20, occupe)):
            occupe.append((gx, gy))
            t = rng.uniform(*d["coin_taille"]) * (1.2 if icone else 1.0)
            if gros_c and i < n_gros_c:
                t *= gros_c[1]
            v, f = coin(rng, t, rng.uniform(*d["coin_haut"]) * (t / d["coin_taille"][1]) ** 0.5)
            bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
            vv = _transforme(v, rng.uniform(0.0, 0.30), rng.uniform(0, 2 * math.pi), bx, by, -0.012)
            o = _objet("%s_coin%d" % (tag, i), vv, f, mats[rng.choice(d["coin_mats"])], S)
            S.bevel(o, 0.010, 1)
            objs.append(o)
    # blocs de métal
    n_bloc = _compte(d["blocs"], stade, e, rng) + (3 if icone and max(d["blocs"]) else 0)
    for i, (gx, gy) in enumerate(places(n_bloc, rayon, 0.24, occupe)):
        occupe.append((gx, gy))
        t = rng.uniform(*d["bloc_taille"]) * (1.2 if icone else 1.0)
        v, f = bloc(rng, t, rng.uniform(*d["bloc_haut"]))
        pose(v, f, mats[rng.choice(d["bloc_mats"])], gx, gy, "%s_bloc%d" % (tag, i), biseau=0.018)
    # touffes de lames (inclinées en éventail depuis un même pied)
    n_touffe = _compte(d["touffes"], stade, e, rng) + (2 if icone and max(d["touffes"]) else 0)
    for i, (gx, gy) in enumerate(places(n_touffe, rayon * 0.9, 0.26, occupe)):
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
        for gx, gy in (_places_amas(rng, n_g, centres, etendue * 1.6, 0.05, []) if amas
                       else _places(rng, n_g, rayon * 1.12, 0.05, [])):
            v, f = grain(rng, rng.uniform(0.022, 0.045))
            ajoute(rng.choice(d["grain_mats"]), v, f, gx, gy)
        fins = d.get("fins", D.FINS)
        if fins:
            d = dict(d, fin_mats=d.get("fin_mats", D.FIN_MATS))
            n_f = _compte(fins, stade, 1.0, rng)
            for _ in range(n_f):
                if amas:
                    # tapis autour des amas (lot design-minerai-monazite) : une traînée irrégulière, pas un disque
                    ax, ay = centres[rng.randrange(len(centres))]
                    fx, fy = ax + rng.gauss(0, etendue * 1.9), ay + rng.gauss(0, etendue * 1.9)
                    if fx * fx + fy * fy > 0.80 ** 2:
                        continue
                    v, f = grain(rng, rng.uniform(0.016, 0.026))
                    ajoute(rng.choice(d["fin_mats"]), v, f, fx, fy)
                    continue
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
    # réglages facultatifs de ICONE (lot X1-TITANE, ilménite) ; valeurs par défaut = celles du tungstène (inchangé)
    for i in range(rng.randint(*ic.get("roches", (2, 3)))):
        a = rng.uniform(0, 2 * math.pi)
        gx, gy = 0.28 * math.cos(a), 0.22 * math.sin(a)
        v, f = roche(rng, rng.uniform(*ic.get("roche_taille", (0.24, 0.32))), aplat=ic.get("roche_aplat", 0.75),
                     n_coupes=ic.get("roche_coupes", 7), cassure=ic.get("roche_cassure", (0.35, 0.7)),
                     creux=ic.get("roche_creux", 0))
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
    # plaquettes (ilménite, lot X1-TITANE) : seulement si ICONE en demande ; le tungstène n'en a pas
    for j in range(ic.get("blocs", 0)):
        a = rng.uniform(0, 2 * math.pi)
        gx, gy = 0.18 * math.cos(a), 0.14 * math.sin(a)
        v, f = bloc(rng, rng.uniform(*ic["bloc_taille"]), rng.uniform(*ic["bloc_haut"]))
        bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
        vv = _transforme(v, 0.0, rng.uniform(0, 2 * math.pi), bx, by, 0.0)
        o = _objet("%s_bloc%d" % (tag, j), vv, f, mats[rng.choice(ic["bloc_mats"])], S)
        S.bevel(o, 0.02, 1)
        objs.append(o)
    # éclats en coin (lot design-minerai-monazite) : seulement si ICONE en demande
    for j in range(ic.get("coins", 0)):
        a = rng.uniform(0, 2 * math.pi)
        rr = 0.0 if j == 0 else 0.24
        gx, gy = rr * math.cos(a), 0.8 * rr * math.sin(a)
        t = rng.uniform(*ic["coin_taille"])
        v, f = coin(rng, t, rng.uniform(*ic["coin_haut"]))
        bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
        vv = _transforme(v, rng.uniform(0.0, 0.25), rng.uniform(0, 2 * math.pi), bx, by, -0.015)
        o = _objet("%s_coin%d" % (tag, j), vv, f, mats[rng.choice(ic["coin_mats"])], S)
        S.bevel(o, 0.016, 1)
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
