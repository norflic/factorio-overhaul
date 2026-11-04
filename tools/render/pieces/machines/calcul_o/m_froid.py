"""LE FROID du calcul (lot CALCUL-DESIGN, 01/11) : groupe froid (âge 10, 4×4), tour de refroidissement (âge 10, 5×5), unité
cryogénique (âge 12, 5×5, le givre se voit de loin). Raccords au nord (entrée) et au sud (sortie).
"""
import math

import geo as G
import organes as O
import palettes as P

D = O.D


def pompe(k, x, y, mat, r=0.13):
    """Pompe de circulation (DA-CALCUL, 4/11) : socle, moteur couché nord-sud, volute ronde au sud ; un tuyau y finit (plus
    aucun tuyau dessiné ne touche le bord : les raccords sont tracés par le moteur dans les 4 directions)."""
    k.bz("noir", x, y + 0.1, 0.04, 0.34, 0.66, 0.06)
    k.moteur("car2", x, y + 0.24, 0.1, 0.36, r, axe="y")
    k.axe(mat, (x, y - 0.14, 0.1 + r), (x, y - 0.04, 0.1 + r), r * 1.25, 18)
    k.cyl(mat, x, y - 0.09, 0.1 + r, 0.1 + r * 2.6, r * 0.42, 12)


def ecran(k, x, y, z, l, h):
    """Écran de contrôle allumé sur une face sud (DA-CALCUL : lueur de travail lisible, D2) : cadre noir, dalle lumineuse."""
    k.b("noir", (x, y - 0.006, z), (l + 0.05, 0.014, h + 0.05))
    k.b("ecran", (x, y - 0.015, z), (l, 0.006, h))


def colonne_lumineuse(k, x, y, z, vert="voyant_v"):
    """Colonne lumineuse de machine (rouge, orange, VERT allumé au travail) sur un dessus."""
    k.cyl("noir", x, y, z, z + 0.12, 0.014, 6)
    for i, m_ in enumerate(("rouge", "orange", vert)):
        k.cyl(m_, x, y, z + 0.12 + 0.07 * i, z + 0.185 + 0.07 * i, 0.04, 12)
    k.cyl("noir", x, y, z + 0.33, z + 0.35, 0.042, 12)


def lueurs_travail(S, M):
    """Matières des lueurs de travail ajoutées le 4/11 (écran cyan, rampe de LED blanc froid)."""
    M["ecran"] = P.lueur(S, "c_ecran", (0.14, 0.72, 1.0), 1.9, 0.55, part=0.3, echelle=36.0)
    M["led"] = P.lueur(S, "c_led", (0.72, 0.9, 1.0), 2.2, 0.55, part=0.2, echelle=30.0)


def froid(S, k):
    """GROUPE FROID : deux gros corps d'échangeur couchés bleu (eau glacée) et orange (eau chaude), compresseur à vis et
    moteur à ailettes entre eux, batterie de deux ventilateurs au nord. DA-CALCUL (4/11) : les lignes d'eau finissent dans
    deux pompes internes (elles touchaient les bords nord et sud) ; lueur de travail : pupitre à écran cyan et colonne
    lumineuse au sud-ouest, rampe de LED sur le condenseur."""
    M = k.M = P.matieres(S, "hitech")
    lueurs_travail(S, M)
    k.sol("noir", 4, h=0.06, ch=0.22)
    for x in (-1.6, 1.6):
        k.bz("car2", x, -0.3, 0.06, 0.22, 4.4, 0.16)
    # évaporateur (eau glacée), bas sud
    k.echangeur(-0.1, -1.72, 0.2, 2.9, 0.45, "bleu", "acier_clair", cerc=5)
    k.echangeur(0.35, -0.5, 0.2, 2.0, 0.36, "orange", "acier_clair", cerc=3)
    k.tuyau("bleu", [(-1.2, -1.72, 1.1), (-1.2, -1.72, 1.34), (-1.2, 0.2, 1.34), (-1.45, 0.5, 1.34), (-1.45, 0.74, 0.62)], r=0.1, coude=0.22,
            brides=[(-1.2, -1.72, 1.18), (-1.2, -0.4, 1.34)], bride_mat="acier")
    pompe(k, -1.45, 0.86, "bleu")
    k.tuyau("orange", [(0.9, -0.5, 0.92), (0.9, -0.5, 1.2), (1.72, -0.5, 1.2), (1.72, -1.9, 1.2), (1.4, -2.64, 0.9), (1.4, -2.64, 0.44)], r=0.08,
            coude=0.22, bride_mat="acier", brides=[(0.9, -0.5, 1.0), (1.72, -1.2, 1.2), (1.4, -2.64, 0.52)])
    pompe(k, 1.4, -2.55, "orange")
    # pupitre à écran et colonne lumineuse au sud-ouest (lueur de travail)
    k.caisson("car2", -1.38, -2.36, 0.06, 0.56, 0.24, 0.9, 0.02)
    ecran(k, -1.38, -2.48, 0.66, 0.42, 0.26)
    for i in range(4):
        k.voyant("voyant_v" if i != 2 else "voyant_o", -1.53 + i * 0.1, -2.49, 0.4, 0.016)
    colonne_lumineuse(k, -1.2, -2.32, 0.96)
    # compresseur à vis : carter ovale, moteur à ailettes, lignes de gaz en cuivre
    k.echangeur(-0.22, 0.72, 0.5, 1.12, 0.3, "car2", "acier", cerc=1)
    k.moteur("car", 0.9, 0.72, 0.42, 0.85, 0.34)
    k.bz("noir", 0.2, 0.72, 0.06, 2.7, 0.75, 0.44)
    k.tuyau("cuivre", [(-0.55, 0.72, 1.08), (-0.55, 0.72, 1.32), (0.2, 0.15, 1.32), (0.2, -0.5, 0.95)], r=0.04, coude=0.16, brides=[(-0.55, 0.72, 1.14)], bride_mat="acier")
    k.tuyau("cuivre", [(0.05, 0.72, 1.08), (0.05, 0.1, 1.28), (-0.6, -1.0, 1.18), (-0.6, -1.72, 1.1)], r=0.03, coude=0.16, brides=[])
    k.vanne("acier", "rouge", (-1.2, -0.12, 1.42), 0.055)
    # condenseur au nord : caisson bas et 2 ventilateurs sur le dessus
    k.caisson("car", 0.2, 2.15, 0.06, 3.0, 1.2, 1.24, 0.1)
    k.b("noir", (0.2, 1.545, 1.12), (2.6, 0.014, 0.07))
    k.b("led", (0.2, 1.535, 1.12), (2.5, 0.006, 0.042))
    k.persiennes("acier", -0.3, 1.54, 0.18, 1.8, 0.78, 10)
    k.ventilo(-0.55, 2.18, 1.36, 0.42, corps="noir")
    k.ventilo(0.72, 2.18, 1.36, 0.42, corps="noir", ph=(k.phase + 0.37) % 1.0)
    k.armoire("car2", 1.2, 1.53, 0.18, 0.62, 0.8, 0.16, lampe="voyant")
    k.voyant("voyant_v", 1.32, 1.5, 0.92, 0.02)
    # manomètres et panneaux au sud
    for x in (-0.9, 0.4):
        k.axe("noir", (x, -2.2, 0.75), (x, -2.28, 0.75), 0.07, 14)
        k.axe("acier_clair", (x, -2.28, 0.75), (x, -2.295, 0.75), 0.05, 14)
        k.axe("noir", (x, -2.1, 0.6), (x, -2.2, 0.75), 0.013, 5)
    k.plaque("plaque", -0.25, -2.18, 0.72, 0.42, 0.14)


def tour(S, k):
    """TOUR DE REFROIDISSEMENT : hyperboloïde de béton tachée, sur couronne de poteaux en V (vide en bas où l'on voit le
    ruissellement), bassin, collecteurs bleu et orange, échelle et passerelle sommitale. La bouche fume (animation à part)."""
    M = k.M = P.matieres(S, "hitech")
    M["eau_lum"] = P.lueur(S, "c_eau", (0.06, 0.2, 0.36), 0.28, 0.25, part=0.85, echelle=8.0)
    cx, cy = 0.0, 0.0
    # bassin
    k.rev("beton", cx, cy, [(0.0, 2.42), (0.22, 2.42), (0.22, 2.28), (0.1, 2.26), (0.1, 0.0)], 56)
    k.rev("eau_lum", cx, cy, [(0.18, 2.26), (0.18, 0.0)], 56)
    # poteaux en V
    n = 24
    r0, r1 = 2.05, 1.72
    z1 = 0.92
    for i in range(n):
        a = math.tau * i / n
        for dj in (-0.5, 0.5):
            b = a + dj * math.tau / n
            k.axe("beton", (cx + r0 * math.cos(a), cy + r0 * math.sin(a), 0.2), (cx + r1 * math.cos(b), cy + r1 * math.sin(b), z1), 0.045, 7)
    # coque : profil hyperbolique, ruissellement sombre, lèvre épaissie, le dedans noir
    prof = []
    H = 4.45
    for i in range(0, 13):
        t = i / 12.0
        z = z1 + (H - z1) * t
        r = 1.2 + 0.56 * ((t - 0.72) / 0.72) ** 2 + 0.16 * t ** 3
        prof.append((z, r))
    k.rev("beton", cx, cy, prof, 56, cap=False)
    k.rev("beton", cx, cy, [(z1 - 0.1, prof[0][1] + 0.05), (z1 + 0.02, prof[0][1] + 0.05), (z1 + 0.02, prof[0][1])], 56, cap=False)
    k.rev("noyau", cx, cy, [(H - 0.5, prof[-1][1] - 0.08), (H - 0.02, prof[-1][1] - 0.02)], 48, cap=False)
    k.rev("noyau", cx, cy, [(H - 0.62, 0.001), (H - 0.5, prof[-1][1] - 0.08)], 48, cap=False)
    k.tore("beton", cx, cy, H, prof[-1][1] + 0.005, 0.045, 56, 8)
    # bande de danger sur la lèvre et cerclages discrets
    for z, r in prof[3:11:3]:
        k.rev("noir", cx, cy, [(z - 0.008, r + 0.002), (z + 0.008, r + 0.002)], 56, cap=False)
    # ventilateur d'appoint dans la bouche (mobile) et moteur sur poutre
    k.axe("noir", (cx - 1.28, cy, H - 0.2), (cx + 1.28, cy, H - 0.2), 0.03, 6)
    k.axe("noir", (cx, cy - 1.28, H - 0.2), (cx, cy + 1.28, H - 0.2), 0.03, 6)
    k.ventilo(cx, cy, H - 0.1, 0.88, corps="noir", lame="acier_clair", lames=8, garde=False)
    k.cyl("car2", cx, cy, H - 0.24, H - 0.02, 0.16, 12)
    # échelle et cage extérieures, passerelle en haut, au sud
    k.echelle("acier", 0.68, -prof[3][1] - 0.15, 0.2, H - 0.05, 0.16)
    k.rambarde("acier", [(0.2, -prof[-1][1] - 0.2, H - 0.02), (1.1, -prof[-1][1] - 0.1, H - 0.02)], 0.2, 0.3)
    k.bz("acier", 0.65, -prof[-1][1] - 0.15, H - 0.05, 1.0, 0.24, 0.03)
    # collecteurs : eau chaude monte, eau froide part
    k.tuyau("orange", [(0.0, 3.55, 0.3), (0.0, 2.4, 0.3), (-1.75, 2.4, 0.3), (-1.75, -0.2, 0.3)], r=0.13, coude=0.3, bride_mat="acier",
            brides=[(0.0, 3.2, 0.3), (-1.2, 2.4, 0.3), (-1.75, 1.0, 0.3)])
    k.tuyau("bleu", [(1.8, 0.5, 0.26), (2.05, -2.0, 0.26), (0.0, -3.0, 0.26), (0.0, -3.55, 0.26)], r=0.13, coude=0.4, bride_mat="acier",
            brides=[(2.0, -1.2, 0.26), (0.0, -3.3, 0.26)])
    k.vanne("acier", "rouge", (-1.0, 2.4, 0.35), 0.07)
    k.vanne("acier", "bleu", (1.2, -2.42, 0.34), 0.07)
    # pompes au sud-ouest
    for x in (-1.8, -1.2):
        k.moteur("car", x, -3.0, 0.08, 0.45, 0.16)
        k.bz("noir", x, -3.0, 0.0, 0.5, 0.42, 0.1)
    k.tuyau("bleu", [(-1.8, -2.82, 0.28), (-1.8, -2.4, 0.28), (-0.4, -2.4, 0.28)], r=0.06, coude=0.2, brides=[])
    k.armoire("car2", 1.75, -3.25, 0.0, 0.8, 0.7, 0.3, lampe="voyant")


def cryo(S, k):
    """UNITÉ CRYOGÉNIQUE : trois vases de Dewar noirs dont le bas blanchit de givre, colonne centrale haute, tuyaux gainés de
    givre, turbine de détente, anneau cyan. Ce qui se lit de loin : du noir, du blanc de glace, du cyan."""
    M = k.M = P.matieres(S, "supra")
    M["cyan"] = P.lueur(S, "c_cyan", (0.08, 0.86, 1.0), 4.0, 0.55, part=0.5, echelle=12.0)
    # givre en dégradé sur les corps : une matière mélange noir et givre selon la hauteur (bruit)
    k.sol("car2", 5, h=0.08, ch=0.3)
    def dewar(x, y, z1, r, gz):
        k.cuve("car", x, y, 0.08, z1, r, 0.4, 36)
        k.rev("givre", x, y, [(0.08, r + 0.012), (gz * 0.72, r + 0.012), (gz, r + 0.002)], 36, cap=False)
        for z in (gz * 0.3, gz * 0.62):
            k.rev("givre", x, y, [(z - 0.06, r + 0.012), (z, r + 0.028), (z + 0.06, r + 0.012)], 36, cap=False)
        k.cerclages("plaque", x, y, (gz + 0.1, z1 - r * 0.6), r, e=0.02, h=0.035, segs=36)
        k.rev("plaque", x, y, [(z1 - 0.04, 0.18), (z1 + 0.05, 0.18), (z1 + 0.05, 0.1)], 16, cap=True)
    dewar(-1.45, 1.4, 2.95, 0.72, 1.25)
    dewar(1.25, 1.75, 2.45, 0.62, 1.1)
    # grande colonne de séparation au centre, chrome et noir, anneau cyan
    k.cuve("car", -0.08, 0.3, 0.08, 4.1, 0.46, 0.5, 32)
    k.cerclages("plaque", -0.08, 0.3, (1.0, 1.7, 2.4, 3.1), 0.46, e=0.018, h=0.03)
    k.tore("cyan", -0.08, 0.3, 3.5, 0.5, 0.018, 36, 6)
    k.tore("chrome", -0.08, 0.3, 3.5, 0.62, 0.035, 40, 8)
    k.rev("givre", -0.08, 0.3, [(0.08, 0.475), (0.86, 0.475), (1.02, 0.462)], 32, cap=False)
    k.cyl("chrome", -0.08, 0.3, 4.1, 4.5, 0.05, 8)
    # turbine de détente (sud-est) et compresseur (sud-ouest)
    k.echangeur(1.4, -1.65, 0.1, 1.4, 0.42, "givre", "plaque", cerc=2)
    k.rev("chrome", 1.92, -1.65, [(0.92, 0.22), (1.05, 0.26), (1.14, 0.16), (1.22, 0.05)], 20)
    k.caisson("car2", -1.42, -1.72, 0.08, 1.7, 1.25, 0.82, 0.06)
    k.moteur("noir", -1.42, -2.4, 0.28, 1.1, 0.2, ailette="plaque")
    k.persiennes("plaque", -1.42, -2.34, 0.13, 0.0001, 0.0001, 1)
    k.ventilo(-1.42, -1.72, 0.95, 0.44, corps="noir")
    k.armoire("noir", 0.1, -3.32, 0.08, 0.72, 0.84, 0.32, lampe="cyan")
    k.voyant("voyant_o", 0.24, -3.34, 0.76, 0.02)
    # lignes de givre : gros tuyaux gainés qui lient tout
    k.tuyau("givre", [(-1.45, 0.65, 1.6), (-1.45, 0.3, 1.6), (-0.55, 0.3, 1.6)], r=0.1, coude=0.2, bride_mat="plaque", brides=[(-1.0, 0.3, 1.6)])
    k.tuyau("givre", [(1.25, 1.1, 1.3), (1.25, 0.3, 1.3), (0.38, 0.3, 1.3)], r=0.1, coude=0.2, bride_mat="plaque", brides=[(0.8, 0.3, 1.3)])
    k.tuyau("givre", [(-0.05, -0.15, 1.1), (-0.05, -1.25, 1.1), (0.7, -1.65, 1.0)], r=0.09, coude=0.22, bride_mat="plaque")
    k.tuyau("car2", [(-1.0, -1.1, 0.88), (-1.0, -0.2, 2.3), (-0.55, 0.05, 2.3)], r=0.07, coude=0.18, bride_mat="plaque", brides=[(-1.0, -0.7, 1.6)])
    # DA-CALCUL (4/11) : les arrivées nord et les trois départs sud touchaient les bords (justes face au nord seulement) ;
    # les deux lignes d'arrivée sortent maintenant du sol, à l'intérieur de l'emprise (raccords : tracés par le moteur)
    k.tuyau("car2", [(0.5, 2.75, 0.0), (0.5, 2.75, 0.26), (0.5, 2.5, 0.26), (0.5, 2.0, 0.9), (0.15, 0.8, 1.0)], r=0.08, coude=0.2, bride_mat="plaque",
            brides=[(0.5, 2.75, 0.12), (0.5, 2.25, 0.55)])
    k.tuyau("car2", [(-0.5, 2.8, 0.0), (-0.5, 2.8, 0.26), (-0.5, 2.3, 0.26), (-0.8, 1.72, 0.5)], r=0.08, coude=0.2, bride_mat="plaque",
            brides=[(-0.5, 2.8, 0.12), (-0.8, 1.72, 0.5)])
    k.vanne("plaque", "rouge", (0.5, 2.62, 0.3), 0.045)
    k.vanne("plaque", "rouge", (-0.5, 2.55, 0.3), 0.045)
    k.vanne("plaque", "rouge", (-1.0, 0.3, 1.68), 0.05)
    k.vanne("plaque", "rouge", (0.8, 0.3, 1.38), 0.05)
    k.echelle("plaque", -0.08, -0.17, 0.08, 3.5, 0.18)
    k.rambarde("plaque", [(-0.6, -0.25, 3.5), (0.5, -0.25, 3.5)], 0.2, 0.28)
