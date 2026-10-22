"""Mitrailleuse « industriel lourd » : socles et têtes des niveaux témoins (lot V3-S). S'exécute DANS Blender.

Échelle d'emprise proposée par l'orchestrateur (charte §6.2) : niveau 11 (époque 6, ère II) 3×3 ; niveau 21
(époque 11, ère IV) 5×5 ; niveau 29 (époque 15, ère V) 6×6 ; niveau 30 = niveau 29 + pièce.

Forme (3e passage). Deux essais rejetés par l'auteur avant tout envoi, sur planche au zoom 1 à côté du réacteur
et du silo vanilla : une dalle carrée puis une casemate octogonale, toutes deux couvertes d'une grille régulière
de plaques, se lisaient comme un DALLAGE, pas comme une tourelle (silhouette carrée, aucun volume arrondi, pas de
dégradé de lumière). Le vanilla lourd (réacteur, silo, centrifugeuse) se lit par des VOLUMES ARRONDIS (cylindres,
dômes) qui prennent la lumière de l'ouest, des gaines annelées en arc, des pieds d'ancrage qui cassent la
silhouette et des recoins sombres. D'où :
  socle = fût cylindrique cerclé (couronne d'orientation au sommet), 4 béquilles d'ancrage vers les angles
          (patins boulonnés, vérins), modules entre les béquilles (munitions, réservoirs, générateur,
          condensateurs selon l'époque) reliés au fût par des gaines et des tuyaux ;
  tête  = tourelle cylindrique blindée (bandes de blindage verticales, cerclages rivetés, toit chanfreiné),
          masque avant, canons rotatifs en sponsons, tambours ou magasins, machinerie arrière.

Systèmes fonctionnels, CUMULÉS (charte §6.2) :
  ère I   tête à canons, alimentation en munitions, socle pivotant ;
  ère II  blindage frontal, refroidissement des canons, canons jumelés ;
  ère III chargeur automatique, conduits et câblage, viseur ;
  ère IV  générateur, tourelle secondaire, radiateurs ;
  ère V   plusieurs tourelles secondaires, réserve d'énergie visible, blindage à plaques multiples.
Kit d'époque (bible §5) en ACCENTS seulement : époque 6 piles d'isolateurs (céramique patinée) et bobinage de
cuivre, arc cyan ; époque 11 ailettes de titane (radiateurs), lignes bleu-blanc ; époque 15 canon de couronne,
or blanc patiné, lumière blanc doré.

Socle (base_picture, couche lower-object) : rien de haut près du bord nord ; pièce du niveau pair : bande avant
(F46).
"""
import math

from mathutils import Matrix, Vector

import parts as PT
from kit import SQ2, TAU

V = Vector
SIDE = {6: 3, 11: 5, 15: 6}
SYSTEMS = {
    6: ["tête à canons", "alimentation (tambours, bandes, caisse)", "socle pivotant (fût, couronne dentée)",
        "blindage frontal (masque, boucliers)", "refroidissement (jaquettes perforées, réservoir et gaines)",
        "canons jumelés (2 × 4 tubes)"],
    11: ["tête à canons", "alimentation (magasins, bandes)", "socle pivotant", "blindage frontal et latéral",
         "refroidissement (jaquettes, réservoirs, gaines)", "canons jumelés (2 × 6 tubes)",
         "chargeur automatique (barillets, convoyeur)", "conduits et câblage", "viseur et télémètre",
         "générateur (socle et tête)", "tourelle secondaire", "radiateurs (titane)"],
    15: ["tête à canons", "alimentation (magasins, bandes)", "socle pivotant", "blindage frontal",
         "refroidissement", "canons jumelés + canon de couronne (3 × 6 tubes)", "chargeur automatique",
         "conduits et câblage", "viseur et télémètre", "générateur", "tourelles secondaires (4)", "radiateurs",
         "réserve d'énergie visible (condensateurs)", "blindage à plaques multiples"],
}
# socle : rayon et hauteur du fût, hauteur de la couronne, béquilles (x, y du patin, largeur)
BASE = {
    6: dict(R=1.1, h=0.42, rh=0.1, foot=(1.24, 1.68), lw=0.22),
    11: dict(R=1.82, h=0.7, rh=0.14, foot=(2.1, 2.9), lw=0.34),
    15: dict(R=2.22, h=0.82, rh=0.16, foot=(2.5, 3.5), lw=0.4),
}
RING_TOP = {e: BASE[e]["h"] + BASE[e]["rh"] for e in BASE}
HEAD = {
    6: dict(R=0.7, hh=0.1, zt=1.5, cap=0.12),
    11: dict(R=1.12, hh=0.14, zt=2.55, cap=0.2),
    15: dict(R=1.42, hh=0.16, zt=3.1, cap=0.24),
}


def _halo(g, pts, power):
    col = g.M["_emit_rgb"]
    for p in pts:
        g.halo(p, col, power)


def drum_quad(R, ang, w, z0, z1, off=0.0):
    """Quadrilatère tangent au fût de rayon R à l'angle ang (normale vers l'extérieur)."""
    d = V((math.cos(ang), math.sin(ang), 0.0))
    t = V((-math.sin(ang), math.cos(ang), 0.0))
    c = d * (R + 0.034 + off)
    return [c - t * w / 2 + V((0, 0, z0)), c + t * w / 2 + V((0, 0, z0)), c + t * w / 2 + V((0, 0, z1)),
            c - t * w / 2 + V((0, 0, z1))]


def slit_ring(g, R, z, n, emat):
    """Fentes lumineuses autour du fût de la tête (secteur avant laissé au masque) : petits foyers nombreux."""
    for k in range(n):
        a = math.pi / 2 + 0.75 + (TAU - 1.5) * (k + 0.5) / n
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        g.box(d * (R + 0.04), (0.1, 0.012, 0.035), emat, "flat", R=R3, what="fente")
        g.box(d * (R + 0.046) + V((0, 0, 0.034)), (0.13, 0.02, 0.02), g.M["steel"], "hard", R=R3, what="visiere")


def armored_drum(g, R, z0, z1, mats, n_strips, band_mat):
    """Cylindre blindé : âme sombre, bandes de blindage verticales (plaques tangentes, rivets sur les chants),
    cerclages rivetés en bas et en haut. Le dégradé de lumière du cylindre donne le volume."""
    M = g.M
    g.cyl((0, 0, (z0 + z1) / 2), "z", R, z1 - z0, M["seam"], n=64, style="smooth", what="ame")
    h = z1 - z0
    w = TAU * R / n_strips
    for k in range(n_strips):
        a = TAU * (k + 0.5) / n_strips
        d = V((math.cos(a), math.sin(a), 0.0))
        t = V((-math.sin(a), math.cos(a), 0.0))
        R3 = Matrix((t, d, V((0, 0, 1)))).transposed()
        m = mats[g.rng.randrange(len(mats))]
        th = 0.034 * (1 + 0.3 * (g.rng.random() - 0.5))
        c = d * (R + th / 2 - 0.004) + V((0, 0, z0 + h * 0.5))
        g.box(c, (w * 0.9, th, h * 0.82), m, "hard", R=R3, what="bande_blindage")
        for zz in (z0 + h * 0.16, z0 + h * 0.84):
            for s in (-1, 1):
                p = d * (R + th) + t * (s * w * 0.36) + V((0, 0, zz))
                g.dome(p, d, 0.02, M["rivet"])
    for zz in (z0 + h * 0.045, z1 - h * 0.045):
        g.tube_shell((0, 0, zz), "z", R + 0.05, R - 0.02, h * 0.09, band_mat, n=64, what="cerclage")
        nb = int(TAU * R / 0.13)
        for k in range(nb):
            a = TAU * k / nb
            d = V((math.cos(a), math.sin(a), 0.0))
            g.dome(d * (R + 0.05) + V((0, 0, zz)), d, 0.018, M["rivet"])


def leg(g, R, zb, foot, lw, M):
    """Béquille d'ancrage : poutre en caisson du fût vers l'angle, patin boulonné, vérin vertical."""
    fx, fy = foot
    d = V((fx, fy, 0.0)).normalized()
    p0 = d * (R * 0.92)
    p1 = V((fx, fy, 0.0)) - d * 0.12
    t = V((-d.y, d.x, 0.0))
    hw = lw / 2
    z0a, z0b = zb * 0.12, zb * 0.82
    z1a, z1b = 0.04, 0.16 + lw * 0.3
    pts = [p0 - t * hw + V((0, 0, z0a)), p1 - t * hw * 0.8 + V((0, 0, z1a)), p1 + t * hw * 0.8 + V((0, 0, z1a)),
           p0 + t * hw + V((0, 0, z0a)),
           p0 - t * hw + V((0, 0, z0b)), p1 - t * hw * 0.8 + V((0, 0, z1b)), p1 + t * hw * 0.8 + V((0, 0, z1b)),
           p0 + t * hw + V((0, 0, z0b))]
    g.hexa(pts, M["armor2"], "soft", "bequille")
    for s in (-1, 1):
        for k in range(5):
            f = (k + 0.5) / 5
            p = p0.lerp(p1, f) + t * s * (hw * (1 - 0.2 * f) + 0.004)
            zc = (z0a + (z1a - z0a) * f + z0b + (z1b - z0b) * f) / 2
            g.dome(p + V((0, 0, zc)), t * s, 0.018, M["rivet"])
    pw = lw * 1.9
    g.box((fx, fy, 0.05), (pw, pw * SQ2 * 0.8, 0.1), M["armor"], "hard", what="patin")
    for kx in (-1, 1):
        for ky in (-1, 1):
            g.bolt((fx + kx * pw * 0.36, fy + ky * pw * SQ2 * 0.3, 0.1), (0, 0, 1), 0.03, M["steel"])
    jx, jy = fx - d.x * lw * 0.9, fy - d.y * lw * 0.9
    jh = z1b + 0.18
    g.cyl((jx, jy, 0.1 + jh * 0.3), "z", lw * 0.28, jh * 0.6, M["steel"], n=14, what="verin")
    g.cyl((jx, jy, 0.1 + jh * 0.75), "z", lw * 0.16, jh * 0.4, M["brass"], n=12, what="tige")
    g.cyl((jx, jy, 0.12 + jh), "z", lw * 0.3, 0.05, M["armor2"], n=12, style="hard", what="chape")
    return p0, p1


def tank(g, c, r, L, axis, M, band=None):
    """Réservoir horizontal cerclé : virole, fonds bombés, cerclages, berceaux."""
    a = V(axis).normalized()
    c = V(c)
    g.cyl(c, a, r, L, M["armor"], n=28, style="smooth", what="reservoir")
    for s in (-1, 1):
        g.cyl(c + a * s * (L / 2 + r * 0.12), a * s, r * 0.92, r * 0.24, M["armor"], n=28, r2=r * 0.55,
              style="smooth", what="fond")
    for f in (-0.32, 0.32):
        g.tube_shell(c + a * f * L, a, r + 0.02, r - 0.02, 0.05, band or M["brass"], n=28, what="cerclage")
        g.box(c + a * f * L - V((0, 0, r * 0.75)), (0.05 if abs(a.x) > 0.5 else r * 1.6,
                                                      r * 1.6 if abs(a.x) > 0.5 else 0.05, r * 0.6), M["armor2"],
              "hard", what="berceau")
    g.cyl(c + V((0, 0, r + 0.03)), (0, 0, 1), r * 0.25, 0.08, M["steel"], n=12, what="trou_homme")


# ------------------------------------------------------------------------------------------------
# Socle
# ------------------------------------------------------------------------------------------------
def socle(g, e, piece=False):
    M = g.M
    B = BASE[e]
    R, h, rh = B["R"], B["h"], B["rh"]
    fx, fy = B["foot"]
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg(g, R, h, (sx * fx, sy * fy), B["lw"], M)
    g.cyl((0, 0, 0.04), "z", R + 0.12, 0.08, M["armor2"], n=64, style="soft", what="semelle")
    nb = int(TAU * (R + 0.08) / 0.14)
    for k in range(nb):
        a = TAU * k / nb
        g.bolt(((R + 0.07) * math.cos(a), (R + 0.07) * math.sin(a), 0.08), (0, 0, 1), 0.022, M["steel"])
    armored_drum(g, R, 0.08, h, [M["armor2"], M["armor2"], M["khaki"]], max(12, int(TAU * R / 0.34)), M["steel"])
    PT.slewing_ring(g, R - 0.04, h, rh)
    {6: _socle6, 11: _socle11, 15: _socle15}[e](g, B, piece)


def _socle6(g, B, piece):
    M = g.M
    # avant : caisse de munitions cerclée et bande vers le fût
    PT.crate(g, (0.0, -1.72, 0.0), (0.7, 0.46, 0.32))
    PT.belt(g, [(0.0, -1.58, 0.36), (0.0, -1.32, 0.44), (0.0, -1.1, 0.36)])
    for sx in (-1, 1):
        PT.crate(g, (sx * 0.62, -1.62, 0.0), (0.36, 0.4, 0.22), mat=M["armor2"])
    # armoire électrique à fenêtre éclairée (arc cyan) sur le fût, face sud
    PT.glow_grille(g, drum_quad(B["R"], -math.pi / 2 - 0.5, 0.3, 0.12, 0.34, 0.03), 3, M["emit_soft"])
    # est : réservoir de refroidissement, gaines de cuivre vers le fût
    tank(g, (1.32, -0.05, 0.2), 0.17, 0.9, (0, 1, 0), M)
    g.hose([(1.28, 0.3, 0.36), (1.2, 0.38, 0.56), (1.02, 0.3, 0.32)], 0.04, M["copper"])
    g.hose([(1.28, -0.4, 0.36), (1.2, -0.5, 0.54), (1.0, -0.42, 0.3)], 0.04, M["copper"])
    # ouest : boîte de jonction, isolateurs (accent d'époque 6), câbles
    PT.hull(g, -1.48, -1.1, -0.46, 0.36, 0.0, 0.32, ins=(0.02, 0.02, 0.02), panel=0.25, mats=[M["armor2"], M["khaki"]])
    for dy in (-0.24, 0.0, 0.24):
        PT.insulators(g, (-1.29, dy - 0.05, 0.32), 4, 0.04)
    for dy in (-0.12, 0.12):
        g.box((-1.29, dy - 0.05, 0.32 + 4 * 0.034 + 0.02), (0.022, 0.13, 0.022), M["emit"], "flat", what="arc")
    PT.cable_run(g, [(-1.3, 0.4, 0.3), (-1.18, 0.5, 0.36), (-1.05, 0.45, 0.3)], 2, 0.02, 0.045,
                 [M["rubber"], M["redcable"]])
    for sx in (-1, 1):
        PT.crate(g, (sx * 0.5, 1.62, 0.0), (0.56, 0.4, 0.2), mat=M["armor2"] if sx < 0 else M["khaki"])
    for sx in (-1, 1):
        PT.lamp(g, (sx * 1.2, -1.62, 0.1), (0, -0.4, 1), 0.03, M["amber"])
    _halo(g, [(-0.9, -1.7, 0.3), (0.9, -1.7, 0.3), (0.0, -1.2, 0.5)], 18.0)


def _socle11(g, B, piece):
    M = g.M
    # avant : magasin + convoyeur (chargeur automatique) vers le fût
    PT.hull(g, -0.6, 0.6, -3.05, -2.35, 0.0, 0.46, ins=(0.03, 0.03, 0.05), panel=0.3, mats=[M["khaki"], M["armor"]])
    PT.belt(g, [(0.0, -2.42, 0.5), (0.0, -2.0, 0.62), (0.0, -1.62, 0.52)])
    for sx in (-1, 1):
        g.box((sx * 0.12, -2.0, 0.42), (0.04, 0.85, 0.06), M["steel"], "hard", R=Matrix.Rotation(-0.1, 3, "X"),
              what="rail")
    # ouest : générateur à radiateur de titane éclairé, échappement, fentes bleu-blanc
    PT.hull(g, -2.45, -1.86, -1.25, 1.15, 0.0, 0.62, ins=(0.03, 0.03, 0.03), panel=0.3, mats=[M["armor2"], M["khaki"]])
    PT.radiator(g, (-2.47, -0.05, 0.06), 2.0, 0.48, 0.1, rz=-math.pi / 2, fin_mat=M["accent"], glow=M["emit_soft"])
    PT.exhaust(g, (-2.15, 0.75, 0.62), 0.09, 0.42)
    for k in range(3):
        g.box((-2.15, -0.9 + k * 0.18, 0.625), (0.4, 0.05, 0.012), M["emit_soft"], "flat", what="fente")
    PT.hatch(g, (-2.15, 0.15, 0.62), 0.14)
    PT.cable_run(g, [(-1.95, 0.5, 0.62), (-1.88, 0.6, 0.7), (-1.78, 0.55, 0.6)], 3, 0.02, 0.045,
                 [M["rubber"], M["redcable"], M["rubber"]])
    for a in (-math.pi / 2 - 0.42, -math.pi / 2 + 0.42):
        PT.glow_grille(g, drum_quad(B["R"], a, 0.38, 0.18, 0.55, 0.03), 4, M["emit_soft"])
    # est : réservoirs de refroidissement, gaines, tuyau à brides
    tank(g, (2.17, -0.75, 0.3), 0.26, 1.15, (0, 1, 0), M)
    tank(g, (2.17, 0.75, 0.3), 0.26, 1.15, (0, 1, 0), M)
    g.hose([(2.05, -0.3, 0.58), (1.95, -0.32, 0.86), (1.75, -0.25, 0.55)], 0.05, M["copper"])
    g.hose([(2.05, 1.1, 0.58), (1.92, 1.1, 0.84), (1.68, 0.95, 0.55)], 0.05, M["copper"])
    g.pipe([(2.05, -1.55, 0.3), (2.0, -1.9, 0.3), (1.6, -2.1, 0.3), (1.1, -2.0, 0.42)], 0.05, M["steel"],
           fl_mat=M["brass"], bolt_mat=M["rivet"])
    # nord : radiateurs de titane
    PT.radiator(g, (0.0, 2.75, 0.0), 0.9, 0.3, 0.1, rz=math.pi, fin_mat=M["accent"])
    # patins avant : voyants ambre, caisses, lignes bleu-blanc
    for sx in (-1, 1):
        PT.lamp(g, (sx * 2.02, -2.8, 0.1), (0, -0.4, 1), 0.034, M["amber"])
        PT.crate(g, (sx * 1.3, -2.62, 0.0), (0.56, 0.5, 0.26))
        g.box((sx * 1.3, -2.88, 0.14), (0.3, 0.012, 0.03), M["emit_soft"], "flat", what="ligne")
        PT.crate(g, (sx * 0.95, 2.95, 0.0), (0.7, 0.42, 0.2), mat=M["armor2"])
    _halo(g, [(-1.7, -2.9, 0.4), (1.7, -2.9, 0.4), (0.0, -2.3, 0.7), (-2.2, 0.0, 0.6)], 22.0)


def _socle15(g, B, piece):
    M = g.M
    # avant : magasin + convoyeur
    PT.hull(g, -0.7, 0.7, -3.65, -2.75, 0.0, 0.54, ins=(0.03, 0.03, 0.05), panel=0.3, mats=[M["khaki"], M["armor"]])
    PT.belt(g, [(0.0, -2.82, 0.58), (0.0, -2.4, 0.72), (0.0, -1.98, 0.6)])
    for sx in (-1, 1):
        g.box((sx * 0.14, -2.4, 0.5), (0.04, 0.95, 0.06), M["steel"], "hard", R=Matrix.Rotation(-0.1, 3, "X"),
              what="rail")
    # ouest : réserve d'énergie (bancs de condensateurs) et câbles
    PT.hull(g, -2.97, -2.28, -1.55, 1.45, 0.0, 0.22, ins=(0.02, 0.02, 0.02), panel=0.3, mats=[M["armor2"]])
    PT.capacitors(g, (-2.62, -0.05, 0.22), 2, 6, 0.13, 0.42, M["emit"])
    for a in (-math.pi / 2 - 0.5, -math.pi / 2, -math.pi / 2 + 0.5):
        PT.glow_grille(g, drum_quad(B["R"], a, 0.42, 0.2, 0.66, 0.03), 4, M["emit_soft"])
    PT.cable_run(g, [(-2.2, 1.05, 0.62), (-1.98, 1.0, 0.72), (-1.8, 0.85, 0.5)], 3, 0.02, 0.045,
                 [M["rubber"], M["redcable"], M["rubber"]])
    PT.cable_run(g, [(-2.2, -1.15, 0.62), (-1.98, -1.1, 0.72), (-1.8, -0.95, 0.5)], 2, 0.02, 0.045,
                 [M["redcable"], M["rubber"]])
    # est : générateur, radiateur éclairé, échappements, réservoir, gaines
    PT.hull(g, 2.3, 2.95, -1.6, 0.35, 0.0, 0.7, ins=(0.03, 0.03, 0.03), panel=0.3, mats=[M["armor2"], M["khaki"]])
    PT.radiator(g, (2.96, -0.62, 0.08), 1.7, 0.52, 0.1, rz=math.pi / 2, fin_mat=M["accent"], glow=M["emit_soft"])
    for yy in (-1.25, 0.0):
        PT.exhaust(g, (2.62, yy, 0.7), 0.1, 0.45)
    for k in range(3):
        g.box((2.62, -0.88 + k * 0.17, 0.705), (0.44, 0.05, 0.012), M["emit_soft"], "flat", what="fente")
    tank(g, (2.62, 1.3, 0.3), 0.27, 1.2, (0, 1, 0), M)
    g.hose([(2.45, 1.65, 0.6), (2.3, 1.6, 0.9), (2.05, 1.4, 0.6)], 0.055, M["copper"])
    g.hose([(2.4, 0.2, 0.7), (2.3, 0.1, 0.95), (2.1, -0.05, 0.62)], 0.055, M["copper"])
    # nord : radiateurs
    PT.radiator(g, (0.0, 3.3, 0.0), 1.0, 0.32, 0.1, rz=math.pi, fin_mat=M["accent"])
    # patins avant : tourelles secondaires (ère V : plusieurs tourelles secondaires), caisses, voyants
    for sx in (-1, 1):
        PT.mini_turret(g, (sx * 2.42, -3.38, 0.1), 0.95, sx * 0.35, M["emit"])
        PT.crate(g, (sx * 1.45, -3.2, 0.0), (0.66, 0.56, 0.3))
        PT.crate(g, (sx * 1.1, 3.6, 0.0), (0.9, 0.46, 0.2), mat=M["armor2"])
        PT.lamp(g, (sx * 2.42, 3.38, 0.1), (0, 0.3, 1), 0.034, M["amber"])
    if piece:
        # niveau 30 : deux armoires de condensateurs blindées sur la bande avant (toujours visible, F46), fentes
        # lumineuses, câbles vers le magasin
        for sx in (-1, 1):
            cx = sx * 1.12
            PT.hull(g, cx - 0.32, cx + 0.32, -4.15, -3.72, 0.0, 0.5, ins=(0.03, 0.03, 0.03), panel=0.24,
                    mats=[M["armor2"], M["armor"]])
            for k in range(3):
                g.box((cx + (k - 1) * 0.18, -4.165, 0.3), (0.09, 0.012, 0.16), M["emit"], "flat", what="fente")
            PT.capacitors(g, (cx, -3.94, 0.5), 3, 1, 0.075, 0.18, M["emit"])
            PT.cable_run(g, [(cx, -3.74, 0.42), (cx * 0.85, -3.62, 0.5), (cx * 0.62, -3.5, 0.4)], 2, 0.02, 0.045,
                         [M["rubber"], M["redcable"]])
        _halo(g, [(-1.12, -4.4, 0.3), (1.12, -4.4, 0.3)], 18.0)
    _halo(g, [(-2.0, -3.6, 0.6), (2.0, -3.6, 0.6), (0.0, -2.9, 0.9), (-2.5, 0.0, 0.8)], 26.0)


# ------------------------------------------------------------------------------------------------
# Tête (repère de la tête : canons vers +Y)
# ------------------------------------------------------------------------------------------------
def motor(g, c, r, L):
    """Moteur électrique bobiné (époque 6) : carter à ailettes, bobinage de cuivre apparent, flasque boulonnée."""
    M = g.M
    x, y, z = c
    g.cyl((x, y, z), "y", r, L, M["armor2"], n=28, style="soft", what="moteur")
    nf = int((L * 0.55) / 0.04)
    for k in range(nf):
        g.tube_shell((x, y - L / 2 + 0.04 + k * 0.04, z), "y", r + 0.035, r - 0.01, 0.016, M["steel"], n=28,
                     what="ailette")
    for k in range(5):
        g.torus((x, y + L / 2 - 0.05 - k * 0.034, z), "y", r + 0.006, 0.017, M["copper"], n=28, m=6, what="bobinage")
    g.cyl((x, y - L / 2 - 0.04, z), "y", r * 0.85, 0.08, M["armor"], n=24, style="soft", what="flasque")
    for k in range(8):
        a = TAU * k / 8
        d = V((math.cos(a), 0, math.sin(a)))
        g.dome(V((x, y - L / 2 - 0.08, z)) + d * r * 0.68, V((0, -1, 0)), 0.018, M["rivet"])
    g.cyl((x, y - L / 2 - 0.1, z), "y", r * 0.3, 0.06, M["brass"], n=12, what="moyeu")


def turret_body(g, e):
    """Fût de la tête : couronne sombre, tourelle cylindrique blindée, toit chanfreiné, masque avant."""
    M = g.M
    H = HEAD[e]
    R, hh, zt, cap = H["R"], H["hh"], H["zt"], H["cap"]
    z0 = RING_TOP[e]
    g.cyl((0, 0, z0 + hh * 0.5), "z", R + 0.08, hh, M["seam"], n=56, style="soft", what="fut")
    zh = z0 + hh
    armored_drum(g, R, zh, zt, [M["armor"], M["armor"], M["khaki"]], max(14, int(TAU * R / 0.3)), M["brass"])
    g.cyl((0, 0, zt + cap / 2), "z", R + 0.02, cap, M["armor"], n=64, r2=R * 0.82, style="soft", what="toit")
    nb = int(TAU * R * 0.8 / 0.14)
    for k in range(nb):
        a = TAU * k / nb
        g.dome((R * 0.78 * math.cos(a), R * 0.78 * math.sin(a), zt + cap), (0, 0, 1), 0.02, M["rivet"])
    PT.hull(g, -R * 0.62, R * 0.62, R * 0.55, R + 0.2, zh + 0.04, zt - 0.06, ins=(0.04, 0.02, R * 0.32), panel=0.26,
            mats=[M["armor2"], M["armor"]])
    return zh, zt + cap


def _tete6(g):
    M = g.M
    zh, zr = turret_body(g, 6)
    zg = zh + 0.5 * (HEAD[6]["zt"] - zh)
    slit_ring(g, HEAD[6]["R"], zh + 0.18, 6, M["emit"])
    for sx in (-1, 1):
        x = sx * 0.9
        PT.receiver(g, x, -0.36, 0.48, zg - 0.17, zg + 0.17, 0.3)
        PT.gatling(g, x, 0.48, zg, 1.1, 4, 0.04, 0.085, 0.42)
        PT.hull(g, x - 0.19, x + 0.19, 0.44, 0.52, zg - 0.22, zg + 0.24, ins=(0.02, 0.01, 0.02), panel=0.2,
                mats=[M["armor"]])
        PT.drum(g, (sx * 1.18, -0.12, zg), (1, 0, 0), 0.19, 0.16)
        PT.belt(g, [(sx * 1.16, -0.02, zg + 0.2), (sx * 1.07, 0.06, zg + 0.26), (sx * 0.95, 0.1, zg + 0.21)])
        PT.lamp(g, (sx * 0.3, 0.2, zr), (0, 0.3, 1), 0.03, M["emit"])
        PT.cable_run(g, [(sx * 0.1, -0.98, zg + 0.36), (sx * 0.42, -0.62, zr + 0.02), (sx * 0.74, -0.32, zg + 0.2)],
                     2, 0.018, 0.04, [M["rubber"], M["redcable"]])
    motor(g, (0.0, -1.06, zg), 0.25, 0.42)
    g.box((0.0, -1.02, zg + 0.3), (0.3, 0.2, 0.1), M["armor2"], "hard", what="bornes")
    ztop = 0
    for sx in (-1, 1):
        ztop = PT.insulators(g, (sx * 0.09, -1.02, zg + 0.35), 5, 0.042)
    g.box((0.0, -1.02, ztop - 0.012), (0.11, 0.024, 0.026), M["emit"], "flat", what="arc")
    PT.hatch(g, (-0.18, -0.2, zr), 0.14)
    PT.sight(g, (0.2, 0.0, zr), 0.18, 0.2, 0.11, M["emit"], lenses=1)


def _tete11(g):
    M = g.M
    zh, zr = turret_body(g, 11)
    R = HEAD[11]["R"]
    zg = zh + 0.48 * (HEAD[11]["zt"] - zh)
    slit_ring(g, R, zh + 0.22, 10, M["emit"])
    for sx in (-1, 1):
        x = sx * 1.42
        PT.receiver(g, x, -0.66, 0.8, zg - 0.27, zg + 0.27, 0.46)
        PT.gatling(g, x, 0.8, zg, 1.65, 6, 0.06, 0.15, 0.7, coil=M["emit"], brake=True)
        PT.hull(g, x - 0.3, x + 0.3, 0.76, 0.86, zg - 0.34, zg + 0.36, ins=(0.02, 0.01, 0.03), panel=0.22,
                mats=[M["armor"]])
        x0, x1 = sorted((sx * 1.68, sx * 2.12))
        PT.hull(g, x0, x1, -0.75, 0.3, zg - 0.45, zg + 0.2, ins=(0.02, 0.02, 0.03), panel=0.26,
                mats=[M["khaki"], M["armor2"]])
        PT.belt(g, [(sx * 1.9, -0.1, zg + 0.24), (sx * 1.76, 0.04, zg + 0.36), (sx * 1.52, 0.1, zg + 0.31)])
        PT.drum(g, (sx * 1.42, -0.92, zg), (1, 0, 0), 0.24, 0.34)
        PT.lamp(g, (sx * 0.5, 0.3, zr), (0, 0.3, 1), 0.032, M["emit"])
        PT.cable_run(g, [(sx * 0.35, -1.42, zg + 0.6), (sx * 0.75, -1.05, zr + 0.02), (sx * 1.15, -0.66, zg + 0.3)], 3,
                     0.018, 0.04, [M["rubber"], M["redcable"], M["rubber"]])
        g.box((sx * (R + 0.06), 0.0, zh + 0.25), (0.014, 0.9, 0.026), M["emit_soft"], "flat", what="ligne")
    # générateur arrière : caisson, radiateur de titane éclairé, échappements
    PT.hull(g, -0.82, 0.82, -1.88, -1.0, zh + 0.04, zg + 0.55, ins=(0.04, 0.05, 0.03), panel=0.3,
            mats=[M["armor2"], M["khaki"]])
    PT.radiator(g, (0.0, -1.89, zh + 0.12), 1.36, 0.62, 0.1, rz=0.0, fin_mat=M["accent"], glow=M["emit_soft"])
    for sx in (-1, 1):
        PT.exhaust(g, (sx * 0.58, -1.55, zg + 0.55), 0.075, 0.42)
    for k in range(2):
        g.box((0.0, -1.62 + k * 0.2, zg + 0.555), (0.5, 0.05, 0.012), M["emit_soft"], "flat", what="fente")
    PT.sight(g, (-0.4, 0.15, zr), 0.32, 0.34, 0.2, M["emit"], lenses=2)
    g.box((0.0, 0.5, zr + 0.06), (1.2, 0.1, 0.1), M["armor2"], "hard", what="telemetre")
    for sx in (-1, 1):
        g.cyl((sx * 0.6, 0.5, zr + 0.06), "x", 0.07, 0.08, M["steel"], n=14, what="telemetre_bout")
        g.cyl((sx * 0.6, 0.56, zr + 0.06), "y", 0.045, 0.012, M["emit"], n=12, style="flat", what="lentille")
    PT.mini_turret(g, (0.36, -0.42, zr), 0.8, 0.0, M["emit"])
    PT.hatch(g, (-0.42, -0.4, zr), 0.16)


def _tete15(g):
    M = g.M
    zh, zr = turret_body(g, 15)
    H = HEAD[15]
    R = H["R"]
    zg = zh + 0.45 * (H["zt"] - zh)
    slit_ring(g, R, zh + 0.26, 14, M["emit"])
    # blindage à plaques multiples : seconde couche sur le masque avant, joncs d'or blanc
    for sx in (-1, 1):
        g.box((sx * R * 0.64, R + 0.06, (zh + H["zt"]) / 2), (0.05, 0.3, H["zt"] - zh - 0.2), M["accent"],
              "hard", what="jonc_or")
    q = [V((R * 0.62, R + 0.2, zh + 0.04)), V((-R * 0.62, R + 0.2, zh + 0.04)),
         V((-R * 0.58, R + 0.2 - R * 0.32, H["zt"] - 0.06)), V((R * 0.58, R + 0.2 - R * 0.32, H["zt"] - 0.06))]
    g.panels(PT.lift(PT.face_quad(q, 0.05, 0.95, 0.08, 0.92), 0.03), 3, 2, M["armor2"], t=0.05, gap=0.03,
             rivet_mat=M["steel"], rivet_r=0.03, rivet_step=0.22, rivet_inset=0.055)
    for sx in (-1, 1):
        x = sx * 1.78
        PT.receiver(g, x, -0.8, 0.95, zg - 0.3, zg + 0.3, 0.52)
        PT.gatling(g, x, 0.95, zg, 2.0, 6, 0.07, 0.18, 0.85, coil=M["emit"], brake=True)
        PT.hull(g, x - 0.34, x + 0.34, 0.9, 1.0, zg - 0.38, zg + 0.38, ins=(0.02, 0.01, 0.03), panel=0.22,
                mats=[M["armor"]])
        x0, x1 = sorted((sx * 2.08, sx * 2.58))
        PT.hull(g, x0, x1, -0.88, 0.4, zg - 0.55, zg + 0.24, ins=(0.02, 0.02, 0.03), panel=0.28,
                mats=[M["khaki"], M["armor2"]])
        PT.belt(g, [(sx * 2.32, -0.14, zg + 0.28), (sx * 2.14, 0.02, zg + 0.42), (sx * 1.84, 0.12, zg + 0.34)])
        PT.drum(g, (sx * 1.78, -1.12, zg), (1, 0, 0), 0.28, 0.4)
        PT.cable_run(g, [(sx * 0.45, -1.7, zg + 0.75), (sx * 0.9, -1.3, zr + 0.02), (sx * 1.45, -0.8, zg + 0.32)], 3,
                     0.02, 0.045, [M["rubber"], M["redcable"], M["rubber"]])
        PT.lamp(g, (sx * 0.62, 0.55, zr), (0, 0.3, 1), 0.034, M["emit"])
        g.box((sx * (R + 0.06), 0.0, zh + 0.3), (0.014, 1.1, 0.026), M["emit_soft"], "flat", what="ligne")
    # canon de couronne sur berceau blindé
    zc = zr + 0.36
    PT.hull(g, -0.44, 0.44, -0.3, 0.8, zr, zr + 0.3, ins=(0.04, 0.04, 0.12), panel=0.26, mats=[M["armor2"], M["armor"]])
    PT.receiver(g, 0.0, -0.25, 0.8, zc - 0.24, zc + 0.2, 0.46)
    PT.gatling(g, 0.0, 0.8, zc, 1.85, 6, 0.065, 0.16, 0.8, coil=M["emit"], brake=True)
    PT.hull(g, -0.3, 0.3, 0.76, 0.86, zr + 0.02, zc + 0.3, ins=(0.02, 0.01, 0.03), panel=0.2, mats=[M["armor"]])
    for sx in (-1, 1):
        PT.piston(g, (sx * 0.32, 0.4, zr + 0.04), (sx * 0.38, 0.78, zr + 0.24), 0.03)
        g.box((sx * 0.45, 0.06, zr + 0.18), (0.03, 1.3, 0.03), M["accent"], "hard", what="jonc_or")
    # réserve d'énergie arrière : baie de condensateurs, grilles éclairées
    bq = PT.hull(g, -1.05, 1.05, -2.36, -1.16, zh + 0.04, zg + 0.62, ins=(0.04, 0.05, 0.03), panel=0.3,
                 mats=[M["armor2"], M["khaki"]])
    PT.capacitors(g, (0.0, -1.84, zg + 0.62), 6, 2, 0.11, 0.32, M["emit"])
    back = [V((-1.05, -2.36, zh + 0.04)), V((1.05, -2.36, zh + 0.04)), bq[1], bq[0]]
    for (s0, s1) in ((0.08, 0.3), (0.39, 0.61), (0.7, 0.92)):
        PT.glow_grille(g, PT.lift(PT.face_quad(back, s0, s1, 0.3, 0.75), 0.03), 4, M["emit_soft"])
    for sx in (-1, 1):
        PT.exhaust(g, (sx * 0.98, -1.4, zg + 0.62), 0.085, 0.42)
        PT.mini_turret(g, (sx * 0.66, -0.74, zr), 0.82, 0.0, M["emit"])
        PT.radiator(g, (sx * 1.07, -1.76, zh + 0.1), 0.55, 0.55, 0.1, rz=sx * math.pi / 2, fin_mat=M["accent"],
                    glow=M["emit_soft"])
    PT.sight(g, (-0.78, 0.45, zr), 0.3, 0.32, 0.18, M["emit"], lenses=2)
    PT.hatch(g, (0.7, 0.3, zr), 0.15)


def tete(g, e):
    {6: _tete6, 11: _tete11, 15: _tete15}[e](g)
