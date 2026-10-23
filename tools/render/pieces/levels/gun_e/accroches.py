"""POINTS D'ACCROCHE des SUPERSTRUCTURES d'époque (passe 5, deuxième temps du kit, 23/10). Python PUR (importable hors
Blender ; corps.accroche s'en sert dans Blender). FICHIER GELÉ pour les constructeurs.

    py -3.9 tools/render/pieces/levels/gun_e/accroches.py [--epoque N] [--json]

Une SUPERSTRUCTURE d'époque change le CONTOUR du bâtiment (tour, flèche, chaudière, torchère, cristal, antenne, anneau,
couronne) : consigne du Directeur Créatif du 23/10 (« les designs changent vraiment beaucoup d'une évolution à une
autre »). Ce module dit OÙ elle peut se poser sans heurter la lignée, et COMBIEN de place elle y a, pour chaque taille
2 à 6 (cotes.TAILLES) et pour le canon de l'époque (son CANON, sinon le canon du témoin cotes.CANON_TEMOIN).

Repères (ceux de corps.py) :
  SOCLE : (x, yn) en tuiles de jeu, yn vers le NORD, origine au centre de l'entité ; se pose avec
          « with corps.at(g, x, yn): … » ; au sol, une distance se mesure en unités Blender (= tuiles en x ; en y, une
          tuile de jeu vaut 1,414 unité : corps.Y). Les rayons libres ci-dessous sont des rayons AU SOL en unités
          Blender (un disque au sol de ce rayon tient dans la place libre).
  TÊTE  : repère de la tête (unités Blender, canons vers +Y, z vers le haut) ; la tête TOURNE (poses N et E) : tout ce
          qui s'y pose tourne avec elle.

Points d'accroche (clés du dictionnaire rendu par calcul()) :
  coin_NO, coin_NE   coins ARRIÈRE du pont (socle) : place libre entre la colonne, son échelle et le bord du pont ;
  coin_SO, coin_SE   coins AVANT du pont (socle) : ce sont AUSSI les places de la pièce du niveau pair (c.T["piece"],
                     carré nominal ±0,3 × s tuile) ; deux places : « libre » (niveau impair seul) et « hors_piece » (ce
                     qui reste à côté du carré de la pièce paire) ; une superstructure avant doit laisser ce carré, ou
                     être la base sur laquelle la pièce paire se pose (à dire dans le retour du constructeur) ;
  tremie_O, tremie_E de part et d'autre de la TRÉMIE (socle) : entre la trémie, la colonne (et le collecteur qui la
                     ceinture côté sud), le bord avant du pont et le carré de la pièce paire ;
  coupole            SOMMET de la coupole (tête) : place libre entre le tourelleau, la trappe, le masque avant et la
                     nacelle ; « z » est la hauteur de la coque à cet endroit ; « entre_canons » est la largeur libre
                     entre les culasses (une superstructure plus large que cela, au-dessus de zg - hr, toucherait les
                     canons) ;
  couronne           ANNEAU autour de la jupe (tête) : rayons r0 à r1 (r1 = rayon de la semelle de la colonne : l'anneau
                     reste au-dessus de la colonne et ne passe jamais sur les coins), hauteurs z0 à z1 (sous le masque,
                     la nacelle et les berceaux) ; « aucune place » aux petites tailles quand z1 <= z0.

Pour chaque point du socle :
  x, yn            centre de la plus grande place libre (tuiles de jeu) ;
  r                rayon libre au sol (unités Blender ; marge de 0,03 comprise) ;
  dx, dy           demi-dégagements le long de x et de y Blender depuis le centre (rectangle libre centré) ;
  h_max            hauteur maximale (unités Blender) pour ne pas heurter la tête qui TOURNE au-dessus (sa partie la
                   plus basse qui passe à cette distance de l'axe : canons, caisses d'alimentation, berceaux, nacelle,
                   masque) ; None : hors de la volée de la tête, hauteur libre ;
  h_ajour          hauteur au-delà de laquelle une forme AJOURÉE (anneau, treillis, arche) posée là se projette hors du
                   pont, sur le vide du sprite, et y enferme un TROU (ilots.py bloquant) : au-dessus, la remplir d'un
                   voile ou la fermer. En projection, une hauteur z vaut z unités de y Blender vers le nord (45°).
RÈGLES : (1) une superstructure se POSE sur le pont (aucune pièce qui flotte : ilots.py) ; (2) elle reste dans sa place
libre, rayon r et h_max compris (sinon elle traverse la tête qui tourne) ; (3) h_max dépend du CANON de l'époque :
calcul(cote, canon=ep.CANON) ; (4) la précision ne baisse pas (règle d'or 4) : une grande superstructure porte plus de
pièces, jamais de plus grosses ; (5) la couleur d'accent ne porte jamais seule l'identité (règle d'or 3).
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import cotes  # noqa: E402
import silhouettes as SIL  # noqa: E402

SQ2 = math.sqrt(2.0)
MARGE = 0.03
PAS = 0.01


def _Y(yn):
    return yn * SQ2


def _poly_plateforme(T, side, chanfrein=None, forme=None):
    """Contour du pont (Blender) ; forme : réglage normalisé de forme_plateforme (silhouettes.option), None :
    octogone de la lignée (code d'origine, mêmes valeurs)."""
    if forme is not None:
        return [(x, _Y(y)) for x, y in SIL.plateforme(side, T, chanfrein, forme)["contour"]]
    P_ = T["plateforme"]
    cf = P_["chanfrein"] if chanfrein is None else chanfrein
    cb = cf * 0.8
    hx = side / 2.0 - P_["retrait"]
    hy = side / 2.0 - P_["retrait"]
    fy = P_["avant"]
    poly = [(-hx + cf, -fy), (hx - cf, -fy), (hx, -fy + cf), (hx, hy - cb), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb), (-hx, -fy + cf)]
    return [(x, _Y(y)) for x, y in poly]


def _seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    t = 0.0 if L2 < 1e-12 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def _inside(p, poly):
    x, y = p
    ins = False
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < x0 + (x1 - x0) * (y - y0) / (y1 - y0):
            ins = not ins
    return ins


def _d_poly(p, poly):
    """Distance signée au bord du polygone (positive dedans)."""
    d = min(_seg_dist(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))
    return d if _inside(p, poly) else -d


def _d_rect(p, r):
    x0, x1, y0, y1 = r
    dx = max(x0 - p[0], 0.0, p[0] - x1)
    dy = max(y0 - p[1], 0.0, p[1] - y1)
    if dx == 0.0 and dy == 0.0:
        return -min(p[0] - x0, x1 - p[0], p[1] - y0, y1 - p[1])
    return math.hypot(dx, dy)


def _d_disc(p, c, r):
    return math.hypot(p[0] - c[0], p[1] - c[1]) - r


def obstacles_socle(T, side):
    """Obstacles au sol du socle de lignée (repère Blender), dans l'ordre de corps.socle : colonne (semelle, goussets),
    échelle, collecteur côté sud (10 époques sur 14 l'utilisent : compté partout), trémie (nervures, porte, poignées),
    goulotte. Rend (liste de (nom, fonction distance), carrés des pièces paires)."""
    B = T["colonne"]
    R = B["R"]
    ob = [("colonne", lambda p: _d_disc(p, (0.0, 0.0), R + 0.16))]
    a = B["echelle"]
    rl = R * math.cos(math.pi / B["n"]) + 0.06
    ob.append(("echelle", lambda p: _d_disc(p, (rl * math.cos(a), rl * math.sin(a)), 0.17)))
    rc = R + 0.12 + 0.02 * (side - 2)
    rp = 0.044 + 0.01 * (side - 2)

    def coll(p):
        ang = math.atan2(p[1], p[0])
        if -2.94 - 0.12 <= ang <= -0.2 + 0.12:
            return abs(math.hypot(p[0], p[1]) - rc) - rp - 0.02
        return 9.0
    ob.append(("collecteur", coll))
    x0, x1, yn0, y1, h = T["tremie"]
    ob.append(("tremie", lambda p: _d_rect(p, (x0 - 0.02, x1 + 0.02, _Y(yn0) - 0.07, y1))))
    gw = T["goulotte_w"]
    ob.append(("goulotte", lambda p: _d_rect(p, (-gw / 2 - 0.03, gw / 2 + 0.03, y1, -(R - 0.1)))))
    P = T["piece"]
    s = max(1.0, P["s"])
    pieces = [(sx * P["x"] - 0.3 * s, sx * P["x"] + 0.3 * s, _Y(P["yn"] - 0.3 * s), _Y(P["yn"] + 0.3 * s))
              for sx in (-1, 1)]
    return ob, pieces


def profil_tete(T, canon):
    """Parties BASSES de la tête qui tournent : (nom, rayon horizontal extérieur depuis l'axe, z du dessous). Repris
    de corps.tete et corps.canon_lignee (canon de lignée : culasse, moteur, rosette, couronne de bouche, masque de
    canon, caisse d'alimentation)."""
    H = dict(T["tete"])
    H.update(canon)
    R, zs, rz = H["R"], H["zs"], H["rz"]
    gx, zg = H["gx"], H["zg"]
    y0, y1 = H["recv"]
    wr, hr = H["wr"], H["hr"]
    L, rb, rr = H["L"], H["rb"], H["rr"]
    N_ = T["nacelle"]
    bx = R * 0.62
    yb0 = -R - N_["recul"]
    bw, bl, bh = 0.32 * wr / 0.4, 0.75 * L / 1.95, 0.5 * hr / 0.23
    xo = gx + wr / 2 + 0.05 + 0.02 + bw
    Lm = 0.3 + hr * 0.6
    ym = y0 - 0.2 - hr * 0.3 - Lm / 2 - 0.11
    rt = rr + rb + 0.028
    return [
        ("jupe", R + 0.07, T["colonne"]["h"] + T["colonne"]["rh"]),
        ("nacelle", math.hypot(bx, yb0), zs - N_["bas"]),
        ("masque", math.hypot(R * 0.5, R + 0.25), zs - 0.18),
        ("berceaux", math.hypot(gx + wr / 2, max(abs(y0 - 0.34), y1 + 0.2)), zs - 0.2),
        ("moteur", math.hypot(gx + hr * 0.81, ym), zg - hr * 0.81),
        ("caisse_alim", math.hypot(xo, max(abs(y0 - 0.1), y0 - 0.1 + bl)), zg - bh * 0.62),
        ("masque_canon", math.hypot(gx + wr * 0.72, y1 + 0.07), zg - hr * 1.3),
        ("canons", math.hypot(gx + rt + 0.022, y1 + L + 0.02), zg - rt - 0.022),
    ], H


def _h_max(prof, d_in):
    """Hauteur libre sous la tête qui tourne pour une place dont le point le plus proche de l'axe est à d_in."""
    zs_ = [z for _, ro, z in prof if ro > d_in]
    return round(min(zs_) - 0.04, 3) if zs_ else None


def _meilleur(region, dist):
    """Point de la région (boîte Blender x0, x1, y0, y1) qui maximise la distance libre ; rend (x, y, d)."""
    x0, x1, y0, y1 = region
    best = (None, None, -1.0)
    nx = max(1, int((x1 - x0) / PAS))
    ny = max(1, int((y1 - y0) / PAS))
    for i in range(nx + 1):
        x = x0 + (x1 - x0) * i / nx
        for j in range(ny + 1):
            y = y0 + (y1 - y0) * j / ny
            d = dist((x, y))
            if d > best[2]:
                best = (x, y, d)
    return best


def _degagement(p, dist, ux, uy):
    k = 0.0
    while k < 6.0 and dist((p[0] + ux * (k + PAS), p[1] + uy * (k + PAS))) > 0.0:
        k += PAS
    return k


def _place_socle(nom, region, dist, poly, prof, geo=None):
    x, y, d = _meilleur(region, dist)
    if x is None or d <= MARGE:
        return dict(nom=nom, place=False)
    r = d - MARGE
    dxp = _degagement((x, y), dist, 1, 0)
    dxm = _degagement((x, y), dist, -1, 0)
    dyp = _degagement((x, y), dist, 0, 1)
    dym = _degagement((x, y), dist, 0, -1)
    # bord nord du pont au-dessus du centre (y Blender du dernier point du pont vers le nord)
    yn_bord = y + _degagement((x, y), lambda p: _d_poly(p, poly), 0, 1)
    out = dict(nom=nom, place=True, x=round(x, 3), yn=round(y / SQ2, 3), r=round(r, 3),
               dx=round(min(dxp, dxm) - MARGE, 3), dy=round(min(dyp, dym) - MARGE, 3),
               h_max=_h_max(prof, math.hypot(x, y) - r),
               h_ajour=round(max(0.0, yn_bord - (y + r)), 3))
    if geo is not None:
        # forme de pont : hauteur du sol à poser (dessus du pont, d'un gradin ou d'une tour d'angle) ; h_max et
        # h_ajour se comptent depuis le sol de la scène (z = 0), pas depuis z_sol
        out["z_sol"] = round(SIL.z_pont(geo, x, y / SQ2), 3)
    return out


def calcul(side, canon=None, chanfrein=None, hab=None):
    """Places libres des points d'accroche à la taille `side` (2 à 6), pour le canon `canon` (dict L, nb, rb, rr ;
    défaut : cotes.CANON_TEMOIN), le chanfrein avant de la plateforme (défaut : celui de la taille) et les FORMES de
    l'habillage `hab` (passe 5, troisième temps : clés forme_plateforme et forme_coupole ; None : formes de la lignée,
    valeurs d'origine). Avec une forme de pont, chaque place du socle porte aussi z_sol (hauteur où poser)."""
    T = cotes.TAILLES[side]
    canon = canon or cotes.CANON_TEMOIN[side]
    fo = SIL.formes(hab or {})
    fp = fo["forme_plateforme"]
    geo = SIL.plateforme(side, T, chanfrein, fp) if fp is not None else None
    poly = _poly_plateforme(T, side, chanfrein, fp)
    ob, pieces = obstacles_socle(T, side)
    prof, H = profil_tete(T, canon)

    def dist(p, avec_pieces=False):
        d = _d_poly(p, poly)
        for _, f in ob:
            d = min(d, f(p))
        if avec_pieces:
            for r in pieces:
                d = min(d, _d_rect(p, r))
        return d
    hx = side / 2.0
    hy = _Y(side / 2.0)
    out = {}
    for nom, (sx, sy) in (("coin_NO", (-1, 1)), ("coin_NE", (1, 1)), ("coin_SO", (-1, -1)), ("coin_SE", (1, -1))):
        reg = (0.0, hx, 0.0, hy) if sx > 0 else (-hx, 0.0, 0.0, hy)
        if sy < 0:
            reg = (reg[0], reg[1], -hy, 0.0)
        # coins : on écarte la bande centrale de la trémie (place « tremie_* » à part)
        x0, x1, y0, y1 = reg
        if sy < 0:
            xt = T["tremie"][1] + 0.05
            x0, x1 = (max(x0, xt), x1) if sx > 0 else (x0, min(x1, -xt))
        out[nom] = _place_socle(nom, (x0, x1, y0, y1), dist, poly, prof, geo)
        if sy < 0:
            out[nom]["hors_piece"] = _place_socle(nom + "_hors_piece", (x0, x1, y0, y1),
                                                  lambda p: dist(p, True), poly, prof, geo)
            out[nom]["piece"] = [round(v, 3) for v in pieces[0 if sx < 0 else 1]]
    x0, x1, yn0, y1, h = T["tremie"]
    for nom, sx in (("tremie_O", -1), ("tremie_E", 1)):
        # entre la trémie et le carré de la pièce paire (au-delà, c'est la place du coin avant)
        pc = pieces[1 if sx > 0 else 0]
        xa, xb = (x1 + 0.02, min(hx, pc[0])) if sx > 0 else (max(-hx, pc[1]), x0 - 0.02)
        # bande de la trémie : entre la face sud du pont et la face nord de la trémie
        reg = (xa, xb, _Y(-T["plateforme"]["avant"]), y1)
        out[nom] = _place_socle(nom, reg, lambda p: dist(p, True), poly, prof, geo)
    # --- tête : sommet de la coupole
    R, zs, rz = H["R"], H["zs"], H["rz"]
    Tt = T["tourelleau"]
    N_ = T["nacelle"]
    bx = R * 0.62
    yb0, yb1 = -R - N_["recul"], -R * 0.5
    mw = R * 0.5
    obt = [lambda p: _d_disc(p, (-R * 0.32, -R * 0.12), Tt["r"] + Tt["av"] + Tt["lentille"][1] + 0.03),
           lambda p: _d_disc(p, (R * 0.34, -R * 0.2), T["trappe"] + 0.02),
           lambda p: _d_rect(p, (-mw, mw, R * 0.55, R + 0.25)),
           lambda p: _d_rect(p, (-bx, bx, yb0, yb1))]

    fc = fo["forme_coupole"]
    prc = SIL.coupole(fc, R, rz) if fc is not None else None
    if prc is not None:
        # bord utile d'une coupole de forme : rayon (normalisé) où la pente dépasse 1,2 en descendant du sommet
        ryc = prc["ry"]
        r_lim = 0.0
        for i in range(400, 0, -1):
            t, t2 = i / 400.0, (i - 1) / 400.0
            dr = (prc["rho"](t2) - prc["rho"](t)) * R
            dzz = prc["zeta"](t) - prc["zeta"](t2)
            if dr > 1e-9 and dzz / dr > 1.2:
                break
            r_lim = max(r_lim, prc["rho"](t2))

    def dist_c(p):
        d = min(f(p) for f in obt)
        if prc is not None:
            sf = SIL.facteur_pans(math.atan2(p[1] / ryc, p[0]), prc["pans"],
                                  math.pi / prc["pans"] if prc["pans"] else 0.0)
            rn = math.hypot(p[0] / R, p[1] / (ryc * R))
            if rn >= r_lim * sf:
                return -1.0
            return min(d, (r_lim * sf - rn) * R)
        e = 1.0 - (p[0] / R) ** 2 - (p[1] / (R * 1.06)) ** 2
        if e <= 0.15:
            return -1.0
        # bord utile de la coque : là où la pente reste douce (e >= 0,15)
        de = (math.sqrt(e) - math.sqrt(0.15)) * R
        return min(d, de)
    x, y, d = _meilleur((-R, R, -R * 1.06, R * 1.06), dist_c)
    if x is None or d <= MARGE:
        out["coupole"] = dict(nom="coupole", place=False)
    else:
        if prc is not None:
            zc = zs + (SIL.haut_coupole(prc, R, x, y) or 0.0)
        else:
            e = max(0.0, 1.0 - (x / R) ** 2 - (y / (R * 1.06)) ** 2)
            zc = zs + rz * math.sqrt(e)
        out["coupole"] = dict(nom="coupole", place=True, x=round(x, 3), y=round(y, 3),
                              z=round(zc, 3), r=round(d - MARGE, 3),
                              entre_canons=round(2 * (H["gx"] - H["wr"] / 2 - 0.03), 3),
                              z_canons=round(H["zg"] - H["hr"], 3))
    # --- tête : couronne autour de la jupe
    rt = T["colonne"]["h"] + T["colonne"]["rh"]
    z0 = rt + 0.08
    z1 = min(zs - 0.2, zs - 0.18, zs - N_["bas"]) - 0.02
    r0, r1 = R + 0.08, T["colonne"]["R"] + 0.16
    out["couronne"] = dict(nom="couronne", place=bool(z1 > z0 + 0.02 and r1 > r0 + 0.02), r0=round(r0, 3),
                           r1=round(r1, 3), z0=round(z0, 3), z1=round(z1, 3))
    out["_profil_tete"] = [(n, round(ro, 3), round(z, 3)) for n, ro, z in prof]
    return out


def table(canon_par_cote=None, chanfreins=None):
    return {s: calcul(s, (canon_par_cote or {}).get(s), (chanfreins or {}).get(s)) for s in range(2, 7)}


def _ligne(p):
    if not p.get("place"):
        return "aucune place"
    if "dx" not in p:
        return ""
    hm = "libre" if p["h_max"] is None else "%.2f" % p["h_max"]
    return "(x %+.2f, yn %+.2f) r %.2f dx %.2f dy %.2f h_max %s h_ajour %.2f%s" % (
        p["x"], p["yn"], p["r"], p["dx"], p["dy"], hm, p["h_ajour"],
        (" z_sol %.2f" % p["z_sol"]) if "z_sol" in p else "")


def _valeur(v):
    """Littéral Python, y compris dict(clé=…) imbriqués (HABILLAGE des époques)."""
    import ast
    if isinstance(v, ast.Call) and getattr(v.func, "id", "") == "dict":
        return {k.arg: _valeur(k.value) for k in v.keywords}
    if isinstance(v, ast.Tuple):
        return tuple(_valeur(x) for x in v.elts)
    return ast.literal_eval(v)


def _litteraux(e):
    """CANON, CANON_PAR_COTE, PLATEFORME et HABILLAGE de epNN.py, lus comme littéraux (le module importe mathutils :
    Blender)."""
    import ast
    with open(os.path.join(HERE, "ep%02d.py" % e), encoding="utf-8") as f:
        tree = ast.parse(f.read())
    out = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            nom = node.targets[0].id
            if nom in ("CANON", "CANON_PAR_COTE", "PLATEFORME", "HABILLAGE"):
                try:
                    out[nom] = _valeur(node.value)
                except ValueError:
                    pass
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--epoque", type=int, default=0, help="canon de cette époque (sinon le témoin)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--habillage", default="", help="habillage d'essai (habillages.py) : formes du pont et de la coupole")
    a = ap.parse_args()
    sides = range(2, 7)
    canon, chf, hab = None, None, None
    if a.habillage:
        import habillages
        hab = habillages.PRESETS[a.habillage]["HABILLAGE"]
    if a.epoque:
        import epoques as E
        ep = _litteraux(a.epoque)
        s = E.COTE[a.epoque]
        sides = [s]
        canon = ep.get("CANON") or ep.get("CANON_PAR_COTE", {}).get(s)
        chf = (ep.get("PLATEFORME") or {}).get("chanfrein")
        hab = hab or ep.get("HABILLAGE")
    res = {s: calcul(s, canon, chf, hab) for s in sides}
    if a.json:
        print(json.dumps(res, indent=1, ensure_ascii=False))
        return
    for s in sides:
        r = res[s]
        print("=== taille %d×%d%s%s" % (s, s, (" (époque %d)" % a.epoque) if a.epoque else " (canon du témoin)",
                                        (" habillage %s" % a.habillage) if a.habillage else ""))
        for k in ("coin_NO", "coin_NE", "coin_SO", "coin_SE", "tremie_O", "tremie_E"):
            print("  %-9s %s" % (k, _ligne(r[k])))
            if "hors_piece" in r[k]:
                print("  %-9s %s   (carré de la pièce paire : x %.2f..%.2f, y Blender %.2f..%.2f)" % (
                    "  hors pièce", _ligne(r[k]["hors_piece"]), *r[k]["piece"]))
        c = r["coupole"]
        if c["place"]:
            print("  coupole   (x %+.2f, y %+.2f, z %.2f) r %.2f ; entre les culasses %.2f au-dessus de z %.2f"
                  % (c["x"], c["y"], c["z"], c["r"], c["entre_canons"], c["z_canons"]))
        else:
            print("  coupole   aucune place")
        k = r["couronne"]
        print("  couronne  r %.2f..%.2f, z %.2f..%.2f%s" % (k["r0"], k["r1"], k["z0"], k["z1"],
                                                          "" if k["place"] else " : aucune place"))


if __name__ == "__main__":
    main()
