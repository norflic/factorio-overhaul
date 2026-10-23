"""FORMES DES GRANDES PIÈCES DE LA LIGNÉE (passe 5, troisième temps du kit, 23/10). Python PUR (importable hors
Blender : accroches.py, outils ; corps.py s'en sert dans Blender). FICHIER DU KIT, gelé pour les constructeurs.

Consigne (orchestrateur, 23/10, 9 h 36, après la ronde 2 : écarts plafonnés vers 3 sur 5, « même forme », « même
silhouette », « même socle », « même plan ») : Clash of Clans change aussi la FORME de la base d'un niveau à l'autre.
Une époque choisit donc, depuis son seul fichier, la FORME de quatre grandes pièces de la lignée, en gardant la
disposition (coupole au centre, canons vers l'avant, trémie au sud), les points d'accroche et la précision :

    HABILLAGE = dict(forme_plateforme=…, forme_coupole=…, forme_jupe=…, forme_tremie=…, …)

Valeur : None (forme de la lignée, code d'origine : empreinte de construction IDENTIQUE) | "nom" | dict(forme="nom",
option=…). Contrat complet (formes, options, matières par défaut, ce qui bouge pour l'époque) : en tête de epoques.py,
section « FORMES ». Ce module donne les CONTOURS et les HAUTEURS (Python pur) ; corps.py dessine.

Repères : socle en tuiles de jeu (x, yn vers le nord ; Blender : y = yn × 1,414) ; tête dans son repère (canons vers +Y,
coupole centrée en (0, 0, zs), demi-axes R, 1,06 R).
"""
import math

SQ2 = math.sqrt(2.0)

FORMES = {
    "forme_plateforme": ("octogone", "carre", "rond", "hexagone", "bastions", "pierre", "gradins", "pilotis"),
    "forme_coupole": ("dome", "dome_bas", "tour", "pyramide", "bulbe", "cloche", "anneau", "coque"),
    "forme_jupe": ("blindee", "conique", "colonnade", "ecailles"),
    "forme_tremie": ("caisson", "tambour", "silo", "entonnoir"),
}
# options permises par clé (toutes facultatives ; None = défaut de la forme). Les matières nomment une clé de
# kit.materials ou de ep.matieres, lue dans la palette HABILLÉE (elles suivent donc capots, acier, etc.).
OPTIONS = {
    "forme_plateforme": ("hauteur", "flanc", "flanc2", "dessus", "lisere", "crenaux", "garde_corps", "niveaux",
                         "assises"),
    "forme_coupole": ("hauteur", "mat", "mat2", "pans", "lisere", "epi", "verre"),
    "forme_jupe": ("mat", "mat2", "n"),
    "forme_tremie": ("mat", "mat2"),
}


def option(hab, cle):
    """Réglage normalisé de la clé de forme `cle` (« forme_plateforme »…) : None (forme de la lignée) ou
    dict(forme=…, options…). La première forme de FORMES[cle] est celle de la lignée : la nommer revient à None."""
    v = hab.get(cle) if hab else None
    if not v:
        return None
    if isinstance(v, str):
        v = dict(forme=v)
    v = dict(v)
    f = v.get("forme")
    if f not in FORMES[cle]:
        raise ValueError("%s : forme %r inconnue (%s)" % (cle, f, ", ".join(FORMES[cle])))
    inconnues = sorted(set(v) - set(OPTIONS[cle]) - {"forme"})
    if inconnues:
        raise KeyError("%s : option(s) inconnue(s) %s (permises : %s)" % (cle, ", ".join(inconnues),
                                                                          ", ".join(OPTIONS[cle])))
    if f == FORMES[cle][0] and len(v) == 1:
        return None
    return v


def formes(hab):
    """Les quatre réglages de forme d'un habillage (dict clé -> None | dict)."""
    return {k: option(hab, k) for k in FORMES}


# ------------------------------------------------------------------------------------------------
# Géométrie plane (tuiles de jeu)
# ------------------------------------------------------------------------------------------------
def _cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def enveloppe(pts):
    """Enveloppe convexe (sens direct)."""
    p = sorted(set((round(x, 6), round(y, 6)) for x, y in pts))
    if len(p) < 3:
        return p
    lo, hi = [], []
    for q in p:
        while len(lo) >= 2 and _cross(lo[-2], lo[-1], q) <= 0:
            lo.pop()
        lo.append(q)
    for q in reversed(p):
        while len(hi) >= 2 and _cross(hi[-2], hi[-1], q) <= 0:
            hi.pop()
        hi.append(q)
    return lo[:-1] + hi[:-1]


def _garde_gauche(pts, a, b, d):
    """Partie de pts à GAUCHE de a->b (intérieur d'un polygone direct), rentrée de d."""
    ex, ey = b[0] - a[0], b[1] - a[1]
    L = math.hypot(ex, ey)
    if L < 1e-12:
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


def rentre(poly, d):
    """Polygone convexe direct rentré de d : intersection des demi-plans rentrés (exacte même quand un pan est plus
    court que le retrait : le pan disparaît au lieu de retourner le polygone, défaut du premier essai, socle de pierre
    sans dalles). Les sommets confondus sont fusionnés ; le premier sommet est le plus proche de poly[0]."""
    if d <= 0:
        return list(poly)
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    pts = [(min(xs) - 1, min(ys) - 1), (max(xs) + 1, min(ys) - 1), (max(xs) + 1, max(ys) + 1), (min(xs) - 1, max(ys) + 1)]
    n = len(poly)
    for i in range(n):
        pts = _garde_gauche(pts, poly[i], poly[(i + 1) % n], d)
        if len(pts) < 3:
            return []
    out = []
    for p in pts:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 1e-7:
            out.append(p)
    if len(out) > 1 and math.hypot(out[0][0] - out[-1][0], out[0][1] - out[-1][1]) <= 1e-7:
        out.pop()
    k = min(range(len(out)), key=lambda i: math.hypot(out[i][0] - poly[0][0], out[i][1] - poly[0][1]))
    return out[k:] + out[:k]


def dedans(p, poly, d=0.0):
    """p dans le polygone convexe direct poly, à au moins d du bord."""
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        ex, ey = b[0] - a[0], b[1] - a[1]
        L = math.hypot(ex, ey)
        if L < 1e-12:
            continue
        if ((p[0] - a[0]) * -ey + (p[1] - a[1]) * ex) / L < d:
            return False
    return True


def octogone(hx, hy, fy, cf, cb):
    return [(-hx + cf, -fy), (hx - cf, -fy), (hx, -fy + cf), (hx, hy - cb), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb), (-hx, -fy + cf)]


def _colonne_dedans(poly, T, marge=0.06):
    """La semelle de la colonne (cercle Blender R + 0,16, ellipse en tuiles) tient-elle dans poly ?"""
    Rs = T["colonne"]["R"] + 0.16 + marge
    return all(dedans((Rs * math.cos(a), Rs * math.sin(a) / SQ2), poly) for a in [k * math.pi / 24 for k in range(48)])


# ------------------------------------------------------------------------------------------------
# PLATEFORME
# ------------------------------------------------------------------------------------------------
def plateforme(side, T, chanfrein=None, o=None):
    """Géométrie de la plateforme (tuiles de jeu). Rend dict :
      forme       nom ;
      contour     contour extérieur au sol (liste (x, yn), sens direct ; pas forcément convexe : bastions) ;
      dessus      polygones CONVEXES du dessus du pont (motif de l'époque), à la hauteur H ;
      niveaux     [(polygone convexe, z0, z1, rôle)] : volumes pleins (plinthe, gradins, tours, tablier) ;
      H           hauteur du dessus du pont (unités Blender) ; dz : surélévation de la colonne et de la trémie
                  (H - 0,045 : la semelle dépasse du pont comme sur l'octogone) ; tremie_z0 : pied de la trémie ;
      hx, hy, fy  demi-côtés et face sud.
    o : réglage de forme_plateforme (option()) ; None : octogone de la lignée."""
    P_ = T["plateforme"]
    cf = P_["chanfrein"] if chanfrein is None else chanfrein
    hx = side / 2.0 - P_["retrait"]
    hy = side / 2.0 - P_["retrait"]
    fy = P_["avant"]
    tx = T["tremie"][1]
    s = side - 2
    if o is None:
        poly = octogone(hx, hy, fy, cf, cf * 0.8)
        return dict(forme="octogone", contour=poly, dessus=[poly], niveaux=[(poly, 0.0, 0.045, "tablier")], H=0.045,
                    dz=0.0, tremie_z0=0.0, hx=hx, hy=hy, fy=fy)
    f = o["forme"]
    out = dict(forme=f, hx=hx, hy=hy, fy=fy)
    if f in ("carre", "pilotis", "pierre", "bastions"):
        c = {"carre": 0.08 + 0.02 * s, "pilotis": 0.1 + 0.02 * s, "pierre": 0.05, "bastions": 0.08 + 0.02 * s}[f]
        poly = octogone(hx, hy, fy, c, c)
    elif f == "rond":
        ro = hx
        pts = [(ro * math.cos(math.pi * 2 * k / 48), ro * math.sin(math.pi * 2 * k / 48)) for k in range(48)]
        lg = tx + 0.12
        pts += [(-lg, -fy), (lg, -fy)]
        poly = enveloppe(pts)
    elif f == "hexagone":
        a = max(tx + 0.16, 0.5 * hx)
        yc = (hy - fy) / 2.0
        while True:
            poly = [(-a, -fy), (a, -fy), (hx, yc), (a, hy), (-a, hy), (-hx, yc)]
            if _colonne_dedans(poly, T) or a >= hx - 0.05:
                break
            a += 0.02
    elif f == "gradins":
        poly = octogone(hx, hy, fy, cf, cf * 0.8)
    else:
        raise ValueError(f)
    out["contour"] = poly
    if f == "carre":
        H = o.get("hauteur") or 0.045
        out.update(dessus=[poly], niveaux=[(poly, 0.0, H, "tablier")], H=H)
    elif f == "rond":
        H = o.get("hauteur") or (0.1 + 0.015 * s)
        out.update(dessus=[rentre(poly, 0.07)], niveaux=[(poly, 0.0, H, "plinthe")], H=H)
    elif f == "hexagone":
        H = o.get("hauteur") or (0.07 + 0.01 * s)
        out.update(dessus=[rentre(poly, 0.06)], niveaux=[(poly, 0.0, H, "plinthe")], H=H)
    elif f == "pierre":
        H = o.get("hauteur") or (0.13 + 0.025 * s)
        out.update(dessus=[rentre(poly, 0.09)], niveaux=[(poly, 0.0, H, "plinthe")], H=H)
    elif f == "pilotis":
        H = o.get("hauteur") or (0.2 + 0.04 * s)
        out.update(dessus=[poly], niveaux=[(poly, H - 0.05, H, "plancher")], H=H)
    elif f == "gradins":
        n = o.get("niveaux") or (2 if side <= 3 else 3)
        w = 0.14 + 0.03 * s
        t = 0.05 + 0.012 * s
        niv = []
        for k in range(n):
            pk = rentre(poly, k * w) if k else poly
            niv.append((pk, 0.0, (k + 1) * t, "gradin%d" % k))
        H = n * t
        # le dernier gradin doit contenir la semelle de la colonne
        while not _colonne_dedans(niv[-1][0], T, 0.02) and w > 0.06:
            w -= 0.01
            niv = [((rentre(poly, k * w) if k else poly), 0.0, (k + 1) * t, "gradin%d" % k) for k in range(n)]
        out.update(dessus=[rentre(niv[-1][0], 0.05)], niveaux=niv, H=H, pas=w)
    elif f == "bastions":
        H = o.get("hauteur") or 0.045
        q = 0.2 + 0.06 * s
        hb = 0.16 + 0.035 * s
        niv = [(poly, 0.0, H, "tablier")]
        for sx in (-1, 1):
            x0, x1 = sorted((sx * hx, sx * (hx - 2 * q)))
            tour = [(x0, hy - 2 * q), (x1, hy - 2 * q), (x1, hy), (x0, hy)]
            niv.append((tour, 0.0, hb, "bastion"))
        out.update(dessus=[poly], niveaux=niv, H=H, bastion=(q, hb))
    out["dz"] = max(0.0, out["H"] - 0.045)
    out["tremie_z0"] = 0.0 if f == "gradins" else out["dz"]
    return out


def z_pont(geo, x, yn):
    """Hauteur du dessus du socle (pont, gradin, plinthe ou tour) au point (x, yn) en tuiles de jeu ; 0 hors du pont."""
    z = 0.0
    for poly, z0, z1, role in geo["niveaux"]:
        if role != "plancher" and dedans((x, yn), poly):
            z = max(z, z1)
        elif role == "plancher" and dedans((x, yn), poly):
            z = max(z, z1)
    return z


# ------------------------------------------------------------------------------------------------
# COUPOLE : profil de révolution (repère de la tête ; facteur de R en x, de 1,06 R en y ; hauteur au-dessus de zs)
# ------------------------------------------------------------------------------------------------
def coupole(o, R, rz):
    """Profil de la coupole : dict(rho(t) facteur du rayon, zeta(t) hauteur au-dessus de zs, pans (None : ronde ;
    n : n pans plats), cassures (t des arêtes vives), hmax, forme). t va de 0 (équateur) à 1 (sommet).
    o None : demi-ellipsoïde de la lignée (rho = cos, zeta = rz sin)."""
    f = "dome" if o is None else o["forme"]
    k = (o or {}).get("hauteur") or 1.0
    pans = None
    cass = ()
    if f == "dome":
        def rho(t):
            return math.cos(t * math.pi / 2)

        def zeta(t):
            return rz * k * math.sin(t * math.pi / 2)
    elif f == "dome_bas":
        hb = 0.7 * rz * k

        def rho(t):
            return math.cos(t * math.pi / 2)

        def zeta(t):
            return hb * math.sin(t * math.pi / 2)
    elif f == "tour":
        hw = 0.8 * rz * k
        tw = 0.6

        def rho(t):
            return 0.88 if t <= tw else 0.88 * (1.0 - (t - tw) / (1.0 - tw))

        def zeta(t):
            return hw * min(1.0, t / tw)
        cass = (tw,)
    elif f == "pyramide":
        pans = (o or {}).get("pans") or 8
        ha = 1.25 * rz * k
        tc = 0.86

        def rho(t):
            return 0.97 - 0.7 * (t / tc) if t <= tc else 0.27 * (1.0 - (t - tc) / (1.0 - tc))

        def zeta(t):
            return ha * min(1.0, t / tc)
        cass = (tc,)
    elif f == "bulbe":
        hb = 1.6 * rz * k

        def rho(t):
            return 0.975 * (1.0 - t) ** 1.4 * (0.92 + 2.4 * t)

        def zeta(t):
            return hb * t
    elif f == "cloche":
        hb = 1.35 * rz * k

        def rho(t):
            if t <= 0.5:
                return 0.95 - 0.06 * (t / 0.5)
            return 0.89 * math.cos((t - 0.5) / 0.5 * math.pi / 2)

        def zeta(t):
            if t <= 0.5:
                return 0.7 * hb * (t / 0.5)
            return 0.7 * hb + 0.3 * hb * math.sin((t - 0.5) / 0.5 * math.pi / 2)
    elif f == "anneau":
        hb = 0.85 * rz * k

        def rho(t):
            return 0.6 * math.cos(t * math.pi / 2)

        def zeta(t):
            return hb * math.sin(t * math.pi / 2)
    elif f == "coque":
        hb = 1.08 * rz * k
        p = 3.0

        def rho(t):
            return max(0.0, math.cos(t * math.pi / 2)) ** (2.0 / p)

        def zeta(t):
            return hb * max(0.0, math.sin(t * math.pi / 2)) ** (2.0 / p)
    else:
        raise ValueError(f)
    hmax = max(zeta(i / 100.0) for i in range(101))
    # demi-axe en y en part de R : 1,06 (ellipse de la lignée) ; 1,0 pour les formes cerclées d'anneaux ou de créneaux
    ry = 1.0 if f in ("tour", "cloche", "anneau") else 1.06
    return dict(forme=f, rho=rho, zeta=zeta, pans=pans, cassures=cass, hmax=hmax, ry=ry)


def facteur_pans(th, pans, phase=0.0):
    """Facteur radial d'un polygone régulier à `pans` côtés (sommets à 1) ; 1 pour une coupole ronde."""
    if not pans:
        return 1.0
    a = 2 * math.pi / pans
    u = (th - phase) % a - a / 2
    return math.cos(a / 2) / math.cos(u)


def haut_coupole(prof, R, x, y):
    """Hauteur de la coque (au-dessus de zs) au point (x, y) du repère de la tête ; None hors de la coupole."""
    ry = prof.get("ry", 1.06)
    r = math.hypot(x / R, y / (ry * R))
    th = math.atan2(y / ry, x)
    sf = facteur_pans(th, prof["pans"], math.pi / prof["pans"] if prof["pans"] else 0.0)
    best = None
    for i in range(400, -1, -1):
        t = i / 400.0
        if prof["rho"](t) * sf >= r:
            best = prof["zeta"](t)
            break
    return best


def tremie(o, T):
    """Boîte de la trémie (inchangée : x0, x1, yn de la face sud, y Blender de la face nord, hauteur) et forme."""
    return dict(forme="caisson" if o is None else o["forme"], boite=T["tremie"])
