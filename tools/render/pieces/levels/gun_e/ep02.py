"""Époque 2 · Forge (ère I, 2×2, niveaux 3 et 4). Constructeur : PLAGE BASSE. S'exécute DANS Blender.

Catalogue (fo-logs/2026-10-22_V3E/catalogue/DA_PAR_EPOQUE.md, §B époque 2) : « fer, boulons, bouclier ».
PORTÉ TEL QUEL de la passe 3 (gun_e_bas, commit 4c57982 : design.py, ages.py, parts4.py ; outil de portage, code d'origine mot pour
mot) sur le kit commun gun_e : seul le CORPS a changé (corps.py : plateforme de caillebotis, colonne, coupole, nacelle
et masque de la lignée ; kit.py : palette et règles de reflets communes).
Corrections de design de la QUATRIÈME PASSE (23/10, constructeur de la plage basse) :
  - bouclier : GRAND bouclier crénelé de tôle forgée claire, en arc de 7 pans devant toute la tête (canons
    compris), qui dépasse au-dessus de la coupole et devant elle (consigne du DC) ;
  - foyer : foyer de forge OUVERT, lit de braises irrégulier visible de dessus, hotte réduite au nord ;
  - arme : faisceau forgé de 3 tubes (règle d'or 1) au lieu d'un fût unique, manchon sur la moitié arrière, couronne
    plate carrée à 4 boulons et oreilles (pose N : un « T ») ;
  - 2×2 : moins de pièces, plus grosses (plus de râtelier, de baquet ni de lanterne ; enclume et soufflet plus
    grands) ; foyers rouge-orange de forge (famille 6 à 22° mesurée) ; chanfrein de plateforme 0,6.
Emplacements remplis : arme (faisceau forgé de 3 tubes par flanc, culasse à levier, manivelle, caisse cerclée et
bande), masque (grand bouclier crénelé en arc), grands volumes du socle (foyer ouvert de briques, soufflet, enclume),
liaisons (fer noir à brides carrées), plaques rapportées, foyers, pièce paire (2 mantelets).
"""
import math

from mathutils import Matrix, Vector

import corps
import formes as F
import parts as PT
import parts2 as P2
import parts3 as P3
from corps import Y, at
from kit import SQ2, TAU, axv, basis

V = Vector

EPOQUE = 2
NOM = "Forge"
KIN = 1   # rang dans l'ère I (0, 1, 2) : puissance croissante dans l'ère (catalogue §A.5)
# passe 4 : rouge-orange de forge (famille 6 à 22° MESURÉE ; les cœurs saturés tirent la teinte vers le jaune,
# d'où une teinte nominale plus rouge que la cible)
FOYER = dict(rgb=(1.0, 0.13, 0.025))
CANON = dict(L=0.85, nb=3, rb=0.05, rr=0.08)
# passe 4 : chanfrein de plateforme d'époque (remplissage, catalogue §A.5 ; silhouette distincte des voisines)
PLATEFORME = dict(chanfrein=0.6)
# passe 5, ronde 1 (consigne du DC du 23/10 : « une autre évolution » d'un âge à l'autre, pas des accessoires) : TOUT
# le corps passe à la FORGE : pont de TÔLES de fer martelé gris à gros rivets, coupole et capots de fer martelé
# (C1 ≥ 60 demandé par les juges : fer gris moyen, pas noir), plaques de BRIQUE réfractaire rouge (nacelle, masque,
# tourelleau, bandes de la couronne), acier de structure en fer noir forgé, rivets de fer clair.
HABILLAGE = dict(jupe_cerclage="fer_noir", tremie="bolted", pochoirs=False, munitions=("brass", "rawiron"),
                 chapeau="fer_clair_f", capots=("fer_martele", "brique"), acier=("fer_noir", "fer_clair_f"),
                 rivets="fer_clair_f", joints="mortier", danger=("brique", "fer_noir"), peinture="brique",
                 tourelleau="brique", grille_nacelle="fer_noir",
                 # ronde 3 (DC, 23/10 9 h 50 : « trop uniforme en terme de palette ») : fer gris DOMINANT, BRIQUE rouge en
                 # couleur SECONDAIRE bien visible (pavage de briques du pont, plaques de la nacelle), braise rouge en
                 # accent ; le pont de tôles grises se confondait avec le fer du corps
                 plateforme=dict(motif="dalles", pas=0.17, joint=0.02, mat="brique_pave", mat2="brique_pave2",
                                 fond="mortier", bord="fer_noir", boulons=None, relief=0.45))
# style d'époque de la passe 3 (emplacements E1 à E5) : noms de matières de kit.materials
ST = dict(jacket="forge", brake="crown", drive="crank", band="blackiron", recv_mats=("fer_martele", "rawiron"),
          recv_sig="lever", feed="crate_belt", skirt="blackiron", appl="brique", gmask=("bolted", "rawiron"),
          arm=("bolted", "blackiron"), cap="brass", mask="shield", jacket_f=0.6, col=("bolted", "blackiron"),
          nac=("bolted", "rawiron"), arr="row", barrel="blackiron")


def matieres(metal, M):
    """Tôle de bouclier forgée (acier martelé plus clair que le corps, arêtes usées très claires : le bouclier se lit
    au zoom 1 comme la tôle claire de la mitrailleuse vanilla) et fer chaud (bout de barre sortant du foyer)."""
    metal("forgeplate", (0.46, 0.43, 0.38), rough=0.46, met=0.45, grain=0.24, gscale=30.0, rust=(0.22, 0.08, 0.03),
          ra=0.16, dirt=0.8, stain=0.6, sscale=5.0, wear=2.8, streak=0.45, mottle=0.35)
    # passe 5 : matières du CORPS de forge (grandes masses peu métalliques : un métal pur reste sombre sous ce soleil)
    rust = (0.24, 0.085, 0.03)
    # ronde 2 (test des écarts de la ronde 1 : la forge lue « petit poste sombre rafistolé », prise pour le pionnier) :
    # FER GRIS clair martelé, froid et métallique, à l'opposé du bois brun du pionnier (C1 ≥ 60 des juges) ; les
    # grandes masses montent d'environ 45 %, le fer noir de structure reste sombre mais moins noir
    metal("fer_martele", (0.37, 0.35, 0.325), rough=0.5, met=0.4, grain=0.3, gscale=22.0, rust=rust, ra=0.14,
          dirt=0.7, stain=0.45, sscale=5.0, wear=2.2, mottle=0.45)
    metal("tole_forge", (0.3, 0.29, 0.27), rough=0.55, met=0.4, grain=0.3, gscale=22.0, rust=rust, ra=0.2,
          dirt=0.75, stain=0.5, sscale=5.0, wear=1.6, mottle=0.4)
    metal("tole_forge2", (0.25, 0.24, 0.225), rough=0.55, met=0.4, grain=0.3, gscale=22.0, rust=rust, ra=0.28,
          dirt=0.75, stain=0.5, sscale=5.0, wear=1.6, mottle=0.4)
    metal("fer_noir", (0.1, 0.095, 0.088), rough=0.5, met=0.5, grain=0.3, rust=rust, ra=0.22, dirt=0.7, stain=0.4,
          wear=2.4)
    metal("fer_clair_f", (0.36, 0.34, 0.31), rough=0.45, met=0.45, grain=0.12, dirt=0.4, stain=0.1, wear=0.8,
          reflet="fin")
    # ronde 3 : briques plus franches (rouge brique, moins sales) et pavés du pont en deux tons
    metal("brique_pave", (0.42, 0.135, 0.065), rough=0.85, met=0.0, grain=0.4, gscale=26.0, dirt=0.6, stain=0.45,
          sscale=5.0, wear=0.8, mottle=0.35)
    metal("brique_pave2", (0.34, 0.1, 0.05), rough=0.85, met=0.0, grain=0.4, gscale=26.0, dirt=0.6, stain=0.45,
          sscale=5.0, wear=0.8, mottle=0.35)
    metal("brique", (0.46, 0.14, 0.065), rough=0.85, met=0.0, grain=0.4, gscale=26.0, dirt=0.85, stain=0.6, sscale=5.0,
          wear=0.8, mottle=0.35)
    metal("mortier", (0.1, 0.085, 0.07), rough=0.9, met=0.0, grain=0.2, dirt=0.4, stain=0.0)


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


# ------------------------------------------------------------------------------------------------
# Socle : grands volumes de l'âge (foyer de briques à hotte et conduit carré, soufflet, enclume, râtelier)
# ------------------------------------------------------------------------------------------------
def socle(g, c):
    M = g.M
    x0, x1, y0, y1, h = c.tremie_box
    # voyants de la trémie (petit groupe, jamais en rangée)
    F.lamp_group(g, (x0 + 0.07, y0 - 0.03, h * 0.62), (1, 0, 0), (0, -1, 0), M["emit"], n=2)
    socle_forge(g)
    # collecteur au pied de la colonne, dans la liaison de l'âge
    corps.collecteur(g, c, lambda g_, pts, r: link(g_, EPOQUE, pts, r))


def _bellows(g, x, yn0, yn1, w, M):
    """Soufflet de forge : planche basse sur tréteaux, plis de cuir en accordéon, planche haute inclinée (charnière
    côté tuyère, au nord), levier de bois, tuyère de fer vers le foyer."""
    y0, y1 = Y(yn0), Y(yn1)
    L = y1 - y0
    # contour en poire (large au sud, pointe au nord vers la tuyère) dans le repère (x local, y local depuis y0)
    out = [(-w / 2, 0.0), (w / 2, 0.0), (w * 0.5, L * 0.45), (w * 0.2, L * 0.92), (-w * 0.2, L * 0.92),
           (-w * 0.5, L * 0.45)]
    zl = 0.12

    def zu(yl, f):  # plan de la planche haute : 0,1 au nord (charnière), 0,3 au sud
        return zl + f * (0.07 + 0.2 * (1 - yl / L))

    def layer(f0, f1, k, mat, what):
        vs = [(x + px * k, y0 + py, zu(py, f0)) for px, py in out] + \
             [(x + px * k, y0 + py, zu(py, f1)) for px, py in out]
        n = len(out)
        fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + j, n + i))
        g._add(mat, "soft", vs, fs, what)
    # tréteaux
    for f in (0.2, 0.7):
        for s in (-1, 1):
            g.box((x + s * w * 0.36, y0 + L * f, zl / 2 - 0.01), (0.04, 0.04, zl - 0.02), M["wood2"], "hard",
                  what="pied")
        g.box((x, y0 + L * f, zl - 0.03), (w * 0.86, 0.05, 0.03), M["wood"], "hard", what="traverse")
    # planche basse
    vs = [(x + px, y0 + py, zl - 0.03) for px, py in out] + [(x + px, y0 + py, zl) for px, py in out]
    n = len(out)
    fs = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    g._add(M["wood"], "hard", vs, fs, "planche")
    # plis de cuir (accordéon : alternance large / rentré)
    nf = 6
    for k in range(nf):
        layer(k / nf, (k + 1) / nf, 1.0 if k % 2 == 0 else 0.86, M["leather"], "pli")
    # planche haute (bois, ferrures)
    layer(1.0, 1.0, 1.0, M["wood"], "planche_haute")
    vs = [(x + px * 1.02, y0 + py, zu(py, 1.0)) for px, py in out] + \
         [(x + px * 1.02, y0 + py, zu(py, 1.0) + 0.03) for px, py in out]
    g._add(M["wood"], "hard", vs, fs, "planche_haute")
    for f in (0.18, 0.46, 0.74):
        yy = y0 + L * f
        g.box((x, yy, zu(L * f, 1.0) + 0.036), (w * (0.96 if f < 0.5 else 0.9), 0.04, 0.012), M["rawiron"], "hard",
              R=Matrix.Rotation(math.atan2(0.2, L), 3, "X"), what="ferrure")
        for s in (-1, 1):
            g.dome((x + s * w * 0.36, yy, zu(L * f, 1.0) + 0.044), (0, 0, 1), 0.015, M["rivet"])
    # levier : perche de bois du bout sud vers le haut, poignée transversale
    p0 = V((x, y0 + 0.04, zu(0.04, 1.0) + 0.03))
    p1 = V((x - 0.03, y0 - 0.08, zu(0.04, 1.0) + 0.05))
    g.cyl(p0, (1, 0, 0), 0.026, 0.06, M["rawiron"], n=10, what="charniere")
    # tuyère de fer au nord
    tip = V((x, y0 + L * 0.92, zl + 0.08))
    g.cyl(tip + V((0, 0.07, 0)), (0, 1, 0), 0.06, 0.14, M["rawiron"], n=12, r2=0.032, style="soft", what="tuyere")
    return tip + V((0, 0.14, 0))


def _hearth(g, x0, x1, yn0, yn1, h, M, E, flue=0.2, hotte=0.4):
    """Foyer de forge OUVERT en briques (passe 4 : « gros foyer de forge », lisible au zoom 1) : cornières de fer,
    grand lit de braises rougeoyantes sous des blocs de charbon (le foyer se voit de dessus, de jour), barre de fer
    chauffée au rouge et tenailles, hotte en tronc de pyramide sur la seule partie NORD (hotte : part de la
    profondeur), conduit CARRÉ (pas de cheminée ronde : elle appartient à la vapeur)."""
    y0, y1 = Y(yn0), Y(yn1)
    g.box(((x0 + x1) / 2, (y0 + y1) / 2, h / 2), (x1 - x0, y1 - y0, h), M["seam"], "flat", what="massif")
    B = [V((x0, y0, 0.0)), V((x1, y0, 0.0)), V((x1, y1, 0.0)), V((x0, y1, 0.0))]
    T = [V((x0, y0, h)), V((x1, y0, h)), V((x1, y1, h)), V((x0, y1, h))]
    for q in ([B[0], B[1], T[1], T[0]], [B[1], B[2], T[2], T[1]], [B[3], B[0], T[0], T[3]]):
        F.courses(g, q, [M["brick"], M["brick2"], M["brick"]])
    # margelle de briques posées à plat, lit de braises au centre
    rim = 0.08
    for (a, b, c, d) in ((x0, x1, y0, y0 + rim), (x0, x1, y1 - rim, y1), (x0, x0 + rim, y0, y1), (x1 - rim, x1, y0, y1)):
        F.courses(g, [V((a, c, h)), V((b, c, h)), V((b, d, h)), V((a, d, h))], [M["brick2"], M["brick"]],
                  bw=0.13, bh=0.065)
    bx0, bx1, by0, by1 = x0 + rim, x1 - rim, y0 + rim, y1 - rim
    g.box(((bx0 + bx1) / 2, (by0 + by1) / 2, h - 0.01), (bx1 - bx0, by1 - by0, 0.02), M["void"], "flat", what="bac")
    # braises : plaques lumineuses séparées par les blocs de charbon (chaque plaque < 0,02 t² : le lit se lit comme un
    # grand foyer sans faire un aplat lumineux unique)
    # cœur rouge au centre (tache irrégulière, pas une grille) : quelques braises entre les blocs, fissures
    # rougeoyantes ; le pourtour du lit reste du charbon noir
    cbx, cby = (bx0 + bx1) / 2, (by0 + by1) / 2
    ex, ey = (bx1 - bx0) * 0.36, (by1 - by0) * 0.34
    rng = g.rng
    for i in range(9):
        a = TAU * i / 9 + 0.35 * rng.random()
        rr = 0.35 + 0.6 * ((i * 5) % 9) / 9.0
        g.box((cbx + math.cos(a) * ex * rr, cby + math.sin(a) * ey * rr, h + 0.002),
              (0.05 + 0.03 * rng.random(), 0.035 + 0.025 * rng.random(), 0.01), E, "flat",
              R=Matrix.Rotation(rng.random() * math.pi, 3, "Z"), what="braise")
    g.box((cbx, cby, h + 0.002), (0.09, 0.07, 0.01), E, "flat", R=Matrix.Rotation(0.5, 3, "Z"), what="braise")
    nx, ny = 4, max(5, int((by1 - by0) / 0.1))
    for i in range(nx + 1):
        for j in range(ny + 1):
            px = bx0 + (bx1 - bx0) * i / nx + 0.025 * ((j % 2) * 2 - 1)
            py = by0 + (by1 - by0) * j / ny
            dc = ((px - cbx) / ex) ** 2 + ((py - cby) / ey) ** 2
            if dc < 0.45 and (i + j) % 2:
                continue
            F.lump(g, (px, py, h - 0.004), 0.042 + 0.012 * rng.random(), M["basalt"], sz=0.55, n=7, m=4,
                   what="charbon")
    # barre de fer chauffée au rouge sortant du lit vers l'est, tenailles posées sur la margelle
    g.box(((bx0 + x1) / 2 + 0.06, (by0 + by1) / 2 - 0.08, h + 0.03), (x1 - bx0 + 0.04, 0.032, 0.032), M["rawiron"],
          "hard", what="barre")
    g.box((bx0 + (bx1 - bx0) * 0.45, (by0 + by1) / 2 - 0.08, h + 0.03), ((bx1 - bx0) * 0.5, 0.036, 0.036), E,
          "flat", what="fer_rouge")
    g.cyl((x1 + 0.02, (by0 + by1) / 2 + 0.12, h + 0.025), (1, 0.25, 0), 0.012, 0.24, M["rawiron"], n=6,
          what="tenaille")
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    # cornières de fer aux arêtes verticales, ceinture boulonnée, gueules du cendrier au sud
    for (px, py) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1)):
        g.box((px, py, h / 2), (0.045, 0.045, h + 0.01), M["rawiron"], "hard", what="corniere")
    for zz in (0.07, h - 0.05):
        g.box(((x0 + x1) / 2, y0 - 0.008, zz), (x1 - x0 + 0.02, 0.016, 0.035), M["rawiron"], "hard", what="ceinture")
        for k in range(3):
            g.dome((x0 + (x1 - x0) * (k + 0.5) / 3, y0 - 0.018, zz), (0, -1, 0), 0.016, M["brass"])
    # hotte sur la partie nord seulement (2 poteaux avant), conduit carré haut
    yh0 = y1 - (y1 - y0) * hotte
    zh0, zh1 = h + 0.2, h + 0.36
    ins = 0.04
    for (px, py) in ((x0 + ins, yh0 + ins), (x1 - ins, yh0 + ins)):
        g.cyl((px, py, (h + zh0) / 2 + 0.005), "z", 0.022, zh0 - h + 0.01, M["blackiron"], n=8, what="poteau")
    PT.hull(g, x0 + 0.01, x1 - 0.01, yh0, y1 - 0.01, zh0, zh1, ins=((x1 - x0) * 0.28, (y1 - yh0) * 0.25,
            (y1 - yh0) * 0.25), panel=0.22, mats=[M["rawiron"], M["blackiron"]], rivet_step=0.11)
    g.box((cx, (yh0 + y1) / 2, zh0 + 0.015), (x1 - x0 + 0.02, y1 - yh0 + 0.02, 0.03), M["blackiron"], "hard",
          what="rebord")
    fw = 0.15
    fy = (yh0 + y1) / 2
    PT.hull(g, cx - fw / 2, cx + fw / 2, fy - fw / 2, fy + fw / 2, zh1 - 0.01, zh1 + flue, ins=(0.0, 0.0, 0.0),
            panel=0.2, mats=[M["blackiron"], M["rawiron"]], faces="tsew", rivet_step=0.11)
    for zz in (zh1 + flue * 0.45, zh1 + flue * 0.85):
        g.box((cx, fy, zz), (fw + 0.03, fw + 0.03, 0.035), M["rawiron"], "hard", what="frette")
    g.box((cx, fy, zh1 + flue + 0.01), (fw + 0.06, fw + 0.06, 0.03), M["rawiron"], "hard", what="chapeau")
    g.box((cx, fy, zh1 + flue + 0.026), (fw - 0.03, fw - 0.03, 0.006), M["soot"], "flat", what="suie")
    return (cx, y0, 0.1)


def _anvil(g, x, yn, M, k=1.0):
    """Enclume sur billot cerclé, marteau posé (k : échelle)."""
    y = Y(yn)
    g.cyl((x, y, 0.1 * k), "z", 0.15 * k, 0.2 * k, M["wood"], n=14, style="soft", what="billot")
    g.tube_shell((x, y, 0.16 * k), "z", 0.15 * k + 0.012, 0.13 * k, 0.03, M["rawiron"], n=24, what="cercle")
    z = 0.2 * k
    g.box((x, y, z + 0.03 * k), (0.2 * k, 0.15 * k, 0.06 * k), M["blackiron"], "soft", what="semelle")
    g.box((x, y, z + 0.08 * k), (0.12 * k, 0.09 * k, 0.05 * k), M["blackiron"], "soft", what="taille")
    g.box((x - 0.01 * k, y, z + 0.13 * k), (0.26 * k, 0.12 * k, 0.06 * k), M["blackiron"], "soft", what="table")
    g.box((x - 0.01 * k, y, z + 0.163 * k), (0.24 * k, 0.1 * k, 0.008), M["steel_hi"], "flat", what="face")
    g.cyl((x + 0.18 * k, y, z + 0.135 * k), (1, 0, 0), 0.05 * k, 0.14 * k, M["blackiron"], n=12, r2=0.008,
          style="soft", what="bigorne")
    g.box((x - 0.07 * k, y, z + 0.167 * k), (0.025, 0.025, 0.004), M["void"], "flat", what="trou")
    g.box((x + 0.02 * k, y - 0.02 * k, z + 0.185 * k), (0.08 * k, 0.04 * k, 0.035 * k), M["steel"], "hard",
          what="marteau")
    g.cyl((x - 0.06 * k, y - 0.09 * k, z + 0.18 * k), (-0.8, -0.6, 0.0), 0.012, 0.2 * k, M["wood"], n=6, what="manche")


def socle_forge(g):
    M = g.M
    E = M["emit"]
    # passe 4 (2×2 : MOINS de pièces, PLUS grosses) : un grand foyer ouvert à l'ouest, un soufflet au nord-ouest, une
    # grande enclume à l'est, le râtelier de plaques au nord-est ; plus de baquet, de lanterne ni de lingot
    # ouest (toujours visible, à toutes les poses) : FOYER OUVERT de briques, lit de braises, hotte nord et conduit
    _hearth(g, -1.02, -0.5, -0.56, 0.4, 0.3, M, E, flue=0.4, hotte=0.34)
    # nord-ouest : soufflet de cuir, tuyère au sud dans le foyer
    g.push((-0.72, Y(0.7), 0.0), rz=math.pi)
    _bellows(g, 0.0, -0.3, 0.3, 0.46, M)
    g.pop()
    # est : grande enclume sur billot (face d'acier claire), lingot rougeoyant posé dessus
    _anvil(g, 0.74, -0.12, M, k=1.6)
    g.box((0.7, Y(-0.12) - 0.03, 0.58), (0.15, 0.06, 0.025), E, "flat", what="lingot")
    for xx in (-0.92, -0.6):
        g.box((xx, Y(-0.56) - 0.024, 0.15), (0.1, 0.01, 0.07), E, "flat", what="gueule")
        g.box((xx, Y(-0.56) - 0.03, 0.2), (0.13, 0.025, 0.022), M["rawiron"], "hard", what="linteau")
    g.halo((-0.76, Y(-0.08), 0.5), M["_emit_rgb"], 12.0)
    g.halo((0.7, Y(-0.12), 0.7), M["_emit_rgb"], 5.0)


# ------------------------------------------------------------------------------------------------
# Liaisons (E2) : tuyau de fer noir à brides CARRÉES à 4 boulons (aucun cuivre)
# ------------------------------------------------------------------------------------------------
def link(g, e, ctrl, r=0.05, kind=None):
    """Liaison d'une machine à la colonne (catalogue, rubrique « Tuyaux » de la forge)."""
    M = g.M
    P = F.polyline_pts(ctrl)
    S_ = g.spline(P, 8)
    S_, T = g.tube(S_, r * 0.8, M["blackiron"], n=12, what="tuyau")
    for i in (0, len(S_) // 2, len(S_) - 1):
        Rr = F.Ry(T[i])
        g.box(S_[i], (r * 2.6, 0.03, r * 2.6), M["rawiron"], "hard", R=Rr, what="bride")
        for sx_ in (-1, 1):
            for sz_ in (-1, 1):
                g.dome(S_[i] + Rr @ V((sx_ * r * 0.9, 0.016, sz_ * r * 0.9)), T[i], 0.014, M["brass"])
    return P


def arch_hose(g, e, p0, p1, lift, r):
    """Liaison de la tête qui PASSE PAR-DESSUS la coupole (visible à toutes les poses), dans le style d'époque."""
    p0, p1 = V(p0), V(p1)
    m = (p0 + p1) / 2
    m.z = max(p0.z, p1.z) + lift
    q0 = p0.lerp(m, 0.5)
    q0.z = m.z - lift * 0.25
    q1 = m.lerp(p1, 0.5)
    q1.z = m.z - lift * 0.25
    return link(g, e, [p0, q0, m, q1, p1], r, kind="arch")


# ------------------------------------------------------------------------------------------------
# Pièce du niveau 4 : 2 mantelets d'acier appuyés chacun contre une pile de 2 caisses cerclées
# ------------------------------------------------------------------------------------------------
def piece(g, c):
    M = g.M
    side = c.side
    cx = c.T["piece"]["x"]
    cy = -cx
    # dalle sous chaque pièce, raccordée à la plateforme : aucun jour enfermé entre la pièce, les caisses et la trémie
    for sx in (-1, 1):
        xa, xb = sorted((sx * (cx - 0.3 - 0.07 * side), sx * (cx + 0.2 + 0.03 * side)))
        corps.dalle(g, xa, xb, Y(cy - 0.24 - 0.02 * side), Y(cy + 0.34 + 0.06 * side))
    for sx in (-1, 1):
        with at(g, sx * (cx + 0.06), cy - 0.08, sx * -0.4):
            PT.crate(g, (0.0, 0.2, 0.0), (0.36, 0.26, 0.18), mat=M["wood"])
            PT.crate(g, (0.01, 0.2, 0.185), (0.3, 0.22, 0.15), mat=M["wood2"])
            mantlet(g, (0.0, -0.04, 0.0), 0.0, w=0.54, h=0.4)
    _halo(g, [(-cx, Y(cy), 0.3), (cx, Y(cy), 0.3)], 6.0)


def mantlet(g, c, rz, w=0.36, h=0.28):
    """Mantelet d'acier (forge) : bouclier plat sur pieds, riveté, à créneau de visée, appuyé contre 2 caisses."""
    M = g.M
    g.push(c, rz=rz)
    t = 0.04
    PT.hull(g, -w / 2, w / 2, -t / 2, t / 2, 0.0, h, ins=(0.0, 0.0, 0.0), panel=0.2, mats=[M["bolted"], M["rawiron"]],
            faces="tsn", rivet_step=0.1)
    g.box((0, -t / 2 - 0.004, h * 0.72), (0.07, 0.01, 0.04), M["void"], "flat", what="creneau")
    for s in (-1, 1):
        g.box((s * w * 0.36, t / 2 + 0.07, h * 0.3), (0.03, 0.16, 0.025), M["blackiron"], "hard",
              R=Matrix.Rotation(0.75, 3, "X"), what="bequille")
        g.box((s * w * 0.36, t / 2 + 0.13, 0.015), (0.06, 0.06, 0.03), M["blackiron"], "hard", what="semelle")
    g.box((0, -t / 2 - 0.01, h - 0.02), (w + 0.02, 0.02, 0.035), M["rawiron"], "hard", what="rebord")
    g.pop()


# ------------------------------------------------------------------------------------------------
# Arme (E1) : UN canon forgé par flanc
# ------------------------------------------------------------------------------------------------
def arme(g, c, x, sx):
    w_forge(g, ST, c.H, x, sx)


def w_forge(g, st, H, x, sx):
    """Époque 2 (passe 4) : FAISCEAU FORGÉ de 3 gros tubes d'acier (corps.rosette, règle d'or 1 : les tubes séparés
    et leur rosace restent visibles), manchon de fer forgé sur la moitié arrière seulement, cerclé de frettes
    boulonnées tous les 0,12 t, couronne de bouche plate en fer noirci à 4 boulons et oreilles (pose N : un « T »),
    frein hydraulique sous le faisceau ; culasse carrée rivetée à levier, manivelle, caisse cerclée et bande."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    breech(g, st, x, y0, y1, zg - hr, zg + hr, wr)
    Ld = 0.26 + hr * 0.6
    drive(g, st, (x, y0 - Ld / 2 + 0.03, zg), hr * 0.78, Ld)
    L, nb, rb, rr = H["L"], H["nb"], H["rb"], H["rr"]
    pos = corps.rosette(g, x, y1, zg, L, nb, rb, rr, mat=M["steel"], phase=math.pi / 2, colliers=(0.74,),
                        collier_mat=M["blackiron"], bouts=False)
    rs = rr + rb + 0.024
    # manchon de fer forgé (moitié arrière au plus : corps.JAQUETTE_MAX), frettes boulonnées au pas de 0,12
    Lj = L * min(0.46, corps.JAQUETTE_MAX)
    # ronde 2 : manchon en fer martelé gris clair (fer brut sombre en ronde 1 : la forge se lisait « poste sombre »)
    g.cyl((x, y1 + Lj / 2, zg), "y", rs, Lj, M["fer_martele"], n=28, style="smooth", what="manchon")
    nfr = max(2, int(Lj / 0.12) + 1)
    for i in range(nfr):
        yy = y1 + 0.03 + (Lj - 0.06) * i / (nfr - 1)
        g.tube_shell((x, yy, zg), "y", rs + 0.024, rs - 0.01, 0.04, M["blackiron"], n=28, what="frette")
        F.bolts_ring(g, (x, yy, zg), (0, 1, 0), rs + 0.026, 4, M["brass"], r=0.015, phase=0.785, skip_down=-0.2)
    # couronne de bouche PLATE en fer noirci (carrée, plus large que le faisceau), oreilles
    yb = y1 + L
    wc = 2 * (rr + rb) + 0.07
    g.box((x, yb - 0.035, zg), (wc, 0.07, wc), M["blackiron"], "hard", what="couronne")
    F.ears(g, x, yb - 0.035, zg, wc / 2 + 0.03, 0.07, wc * 0.7, M["rawiron"], vent=False)
    for sxx in (-1, 1):
        for szz in (-1, 1):
            g.bolt((x + sxx * wc * 0.36, yb + 0.001, zg + szz * wc * 0.36), (0, 1, 0), 0.014, M["steel_hi"])
    corps.bouche(g, x, yb + 0.002, zg, pos, rb, M["rawiron"], rr + rb * 0.6, w=0.02)
    # frein hydraulique sous le faisceau (cylindre et collier avant)
    zr = zg - rs - 0.04
    g.cyl((x, y1 + 0.22, zr), "y", 0.038, 0.42, M["blackiron"], n=14, what="frein_recul")
    g.box((x, y1 + 0.4, (zr + zg) / 2 - 0.01), (0.06, 0.045, rs + 0.03), M["rawiron"], "hard", what="collier")
    # masque de canon : plaque de fer forgé rivetée
    PT.hull(g, x - wr * 0.75, x + wr * 0.75, y1 - 0.04, y1 + 0.06, zg - hr * 1.3, zg + hr * 1.4, ins=(0.02, 0.01, 0.03),
            panel=0.2, mats=[M["fer_martele"], M["rawiron"]], rivet_step=0.1)
    xo = x + sx * (wr / 2 - 0.005)
    feed(g, st, H, x, sx, xo)


def breech(g, st, x, y0, y1, z0, z1, w):
    """Culasse blindée (lignée PT.receiver) habillée par l'époque : levier d'armement à pommeau de laiton."""
    M = g.M
    mats = [M[k] for k in st["recv_mats"]]
    T = PT.receiver(g, x, y0, y1, z0, z1, w, mats=mats)
    g.box((x + w * 0.52, (y0 + y1) / 2 - 0.08, (z0 + z1) / 2), (0.02, 0.2, 0.02), M["blackiron"], "hard",
          R=Matrix.Rotation(0.5, 3, "X"), what="levier")
    g.cyl((x + w * 0.52, (y0 + y1) / 2 - 0.16, z1 + 0.03), "x", 0.02, 0.04, M["brass"], n=8, what="pommeau")
    return T


def drive(g, st, c, r, L):
    """Organe arrière du canon : MANIVELLE (carter de fer noirci à nervures, flasque, bras et poignée de laiton)."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z), "y", r, L, M["blackiron"], n=20, style="soft", what="carter")
    for k in range(3):
        g.tube_shell((x, y - L / 2 + 0.04 + k * (L - 0.08) / 2, z), "y", r + 0.015, r - 0.01, 0.025,
                     M["rawiron"], n=20, what="nervure")
    g.cyl((x, y - L / 2 - 0.025, z), "y", r * 0.8, 0.05, M["rawiron"], n=20, style="soft", what="flasque")
    F.bolts_ring(g, (x, y - L / 2 - 0.05, z), (0, -1, 0), r * 0.6, 6, M["brass"], r=0.015)
    # manivelle : bras, poignée laiton
    g.box((x, y - L / 2 - 0.07, z - r * 0.4), (0.03, 0.02, r * 1.2), M["blackiron"], "hard", what="bras")
    g.cyl((x + 0.04, y - L / 2 - 0.07, z - r), "x", 0.016, 0.09, M["brass"], n=8, what="poignee")


def feed(g, st, H, x, sx, xo):
    """Alimentation : caisse cerclée de fer posée sur le bras, bande de cartouches laiton."""
    M = g.M
    y0, y1 = H["recv"]
    zg, hr, wr = H["zg"], H["hr"], H["wr"]
    c = V((xo + sx * 0.08, y0 + 0.12, zg - hr * 0.6))
    PT.crate(g, tuple(c), (0.16, 0.2, 0.14), mat=M["wood"])
    PT.belt(g, [(xo + sx * 0.08, y0 + 0.16, zg - hr * 0.6 + 0.16), (xo, y0 + 0.24, zg + 0.1),
                (x + sx * wr * 0.3, y0 + 0.3, zg + hr + 0.02)], scale=0.8)


# ------------------------------------------------------------------------------------------------
# Masque (remplace celui de la lignée) : BOUCLIER COURBE CRÉNELÉ
# ------------------------------------------------------------------------------------------------
def masque(g, c):
    """Passe 4 : GRAND BOUCLIER CRÉNELÉ de tôle forgée claire, en arc de 7 pans qui enveloppe tout l'avant de la tête,
    canons compris (les faisceaux le traversent) ; il DÉPASSE au-dessus de la coupole (merlons) et devant elle : c'est
    la silhouette de l'époque au zoom 1 (consigne du DC, 23/10). Pans légèrement évasés vers l'extérieur (la face
    rivetée se voit d'en haut à toutes les poses), tôles rivetées sur les deux faces, rebord, un merlon par pan,
    fentes de visée, colliers de passage autour des faisceaux (aucun jour), console annulaire rivetée qui relie le pied
    du bouclier à la jupe (aucune pièce qui flotte)."""
    M = g.M
    H = c.H
    R, zs, rz = H["R"], H["zs"], H["rz"]
    gx, zg = H["gx"], H["zg"]
    rs = H["rr"] + H["rb"] + 0.024
    Rs = gx + rs + 0.07
    zb = zs - 0.24
    Hs = zs + rz + 0.15 - zb
    th = 0.045
    evase = 0.16
    n = 7
    half = math.radians(72)
    # les pans s évasent : à leur sommet le rayon vaut Rs + Hs sin(évasement) ; largeur prise au sommet (aucune fente)
    segw = 2 * (Rs + Hs * math.sin(evase)) * math.sin(half / n) * 1.04
    for i in range(n):
        a = math.pi / 2 - half + 2 * half * (i + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0.0))
        g.push(tuple(d * Rs + V((0, 0, zb))), rz=a - math.pi / 2, rx=-evase)
        g.box((0, 0, Hs / 2), (segw, th, Hs), M["blackiron"], "hard", what="bouclier")
        nv = max(2, int(round(Hs / 0.27)))
        front = [V((segw / 2, th / 2, 0.0)), V((-segw / 2, th / 2, 0.0)), V((-segw / 2, th / 2, Hs)),
                 V((segw / 2, th / 2, Hs))]
        back = [V((-segw / 2, -th / 2, 0.0)), V((segw / 2, -th / 2, 0.0)), V((segw / 2, -th / 2, Hs)),
                V((-segw / 2, -th / 2, Hs))]
        # face avant rivetée ; face arrière en tôles lisses (2×2 : moins de pièces, plus grosses)
        for q, rm in ((front, M["rivet"]), (back, None)):
            g.panels(q, 1, nv, M["forgeplate"], t=0.016, gap=0.018, rivet_mat=rm, rivet_r=0.017,
                     rivet_step=0.12, mats=[M["forgeplate"], M["forgeplate"], M["bolted"]])
        g.box((0, 0, Hs + 0.014), (segw + 0.01, th + 0.05, 0.028), M["rawiron"], "hard", what="rebord")
        mw = segw * 0.56
        g.box((0, 0, Hs + 0.028 + 0.075), (mw, th + 0.03, 0.15), M["forgeplate"], "hard", what="merlon")
        g.box((0, 0, Hs + 0.028 + 0.155), (mw + 0.02, th + 0.045, 0.018), M["rawiron"], "hard", what="chaperon")
        for s_ in (-1, 1):
            g.dome((0, s_ * (th / 2 + 0.016), Hs + 0.1), (0, s_, 0), 0.016, M["rivet"])
        if i in (2, 4):
            g.box((0, th / 2 + 0.018, Hs * 0.66), (segw * 0.5, 0.008, 0.03), M["void"], "flat", what="visee")
            g.box((0, th / 2 + 0.024, Hs * 0.66 + 0.032), (segw * 0.62, 0.02, 0.016), M["rawiron"], "hard",
                  what="sourcil")
        g.pop()
        # console annulaire : du pied du pan au collier de la jupe
        g.push((0, 0, zb + 0.02), rz=a - math.pi / 2)
        g.box((0, (R + Rs) / 2 - 0.02, 0.0), (segw * 0.9 * (R + Rs) / (2 * Rs) + 0.04, Rs - R + 0.08, 0.05),
              M["blackiron"], "hard", what="console")
        g.dome((0, (R + Rs) / 2, 0.028), (0, 0, 1), 0.016, M["brass"])
        g.pop()
    # colliers de passage autour des faisceaux (à la traversée du bouclier)
    for s_ in (-1, 1):
        yy = math.sqrt(max(0.0, Rs * Rs - gx * gx)) + (zg - zb) * math.tan(evase)
        g.cyl((s_ * gx, yy, zg), "y", rs + 0.05, 0.11, M["blackiron"], n=28, style="soft", what="collier_passage")
        F.bolts_ring(g, (s_ * gx, yy + 0.057, zg), (0, 1, 0), rs + 0.032, 6, M["brass"], r=0.015)


# ------------------------------------------------------------------------------------------------
# Tête : liaisons en arc, plaques rapportées
# ------------------------------------------------------------------------------------------------
def tete(g, c):
    M = g.M
    H = c.H
    R = H["R"]
    side = c.side
    # liaisons de la tête (nacelle -> canons) : elles passent EN ARC au-dessus de la tête
    zt = H["zs"] + H["rz"] * 0.42
    for sx in (-1, 1):
        arch_hose(g, EPOQUE, (sx * 0.15, -R - 0.06, zt + 0.02),
                  (sx * (H["gx"] - 0.03), H["recv"][0] + 0.1, H["zg"] + H["hr"] + 0.03),
                  0.1 + 0.03 * (side - 2), 0.034 + 0.008 * (side - 2))
    # plaques rapportées de la coupole (ère I : moins de pièces, plus grosses)
    appl = M[ST["appl"]]
    n1 = 2
    for i in range(n1):
        th = 0.45 + (math.pi - 0.9) * (i + 0.5) / n1
        P2.applique(g, c.Pf, c.Nf, th, 0.3, 0.22 + 0.03 * (side - 2), 0.18 + 0.03 * (side - 2), appl, M)
