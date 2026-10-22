"""Mitrailleuse « haute technologie à la Factorio » (explorateur de style, lot V3-S), REPRISE du 22/10 après la
critique de l'orchestrateur sur les essais de 8 h 50 : niveaux témoins 11, 21, 29 et pièce du niveau 30. Python
PUR (aucun bpy) : géométrie par ht_geo.B, briques par ht_kit, matériaux décrits ici, instanciés par ht_blender.py.

Ce qui change par rapport au premier essai (dalle de béton à fenêtres) :
  1. PLUS DE DALLE. Le socle est un AFFÛT BLINDÉ ROND à gradins (comme l'artillerie vanilla) entouré de VOLUMES
     posés au sol : cuve-cœur sphérique (réacteur vanilla), générateur bobiné, batterie de radiateurs, cellules,
     réservoirs, pompes, magasin de munitions, gaines annelées de cuivre. Un simple tablier bas (caillebotis, 4 cm)
     relie les volumes : il est presque entièrement couvert. Contour irrégulier, gaines qui débordent (F42).
  2. LA TÊTE DOMINE et se lit comme une ARME : coque ronde à glacis, masque frontal, deux faisceaux rotatifs longs
     (4, 6 puis 8 canons), chemises perforées, culasses, tambours-chargeurs et bandes de cartouches laiton,
     tourelles secondaires (ère IV et V), viseur. Elle grandit avec l'ère (largeur, longueur des canons, hauteur).
  3. MATÉRIAUX MÊLÉS à la manière du vanilla : acier brun rouillé (ancre : cheminée V0), tôles peintes patinées
     olive et crème (réacteur, assembleuse), acier nu à arêtes brillantes, cuivre des gaines, laiton des cerclages
     et des cartouches, bandes de danger.
  4. RELIEF : gradins de l'affût, nervures en saillie, tête surélevée, pièces en saillie qui projettent des ombres.
  5. DÉTAIL CONSTANT PAR TUILE : les pièces (tôles ~0,4, boulons, rivets, grilles) ont la MÊME taille absolue à
     tous les niveaux ; un grand niveau en a donc plus, il n'est jamais un agrandissement d'échelle.
Une TOURELLE, pas un bâtiment : aucune fenêtre ; la lumière vient d'orifices (hublots ronds, fentes de chemise,
jauges de cellules, grilles de radiateur), en petits foyers séparés.

Repère et couches : voir ht_geo.py. Le socle (base_picture, 1 direction) est dessiné avant la tête : dans le cercle
balayé par la tête, le socle reste plus bas que les parties tournantes (vérifié par ht_apercu.sweep_conflicts) ;
les volumes hauts sont à l'ARRIÈRE (nord), l'avant (sud) reste bas.
"""
import math

import ht_geo as G
from ht_geo import TD, TAU, Rx, Ry, Rz
from ht_kit import (TONES, AMBER, EPOCH_GLOW, floor_conduit, capacitor, radiator_block, crate, pipe_run, lamp_post, hose_arc,
                    cable_bundle, hatch, tank_h, big_hose, pump, conveyor, shroud, drum_mag, secondary_turret, sensor,
                    spline)

np = G.np

# ------------------------------------------------------------------------------------------------
# Niveaux
# ------------------------------------------------------------------------------------------------
LEVELS = {
    11: {"epoch": 6, "era": 2, "side": 3},
    21: {"epoch": 11, "era": 4, "side": 5},
    29: {"epoch": 15, "era": 5, "side": 6},
    30: {"epoch": 15, "era": 5, "side": 6},
}
HALO_GAIN = {11: 0.55, 21: 0.8, 29: 1.0, 30: 1.0}
HALO_EXTRA = 1.0
HALO_POWER = 18.0          # puissance de chaque source du halo de nuit (W, relative : renormalisée par ht_post)


def variants():
    v = {}
    for lv in (11, 21, 29):
        v["n%02d-socle" % lv] = {"level": lv, "part": "socle"}
        for d in ("N", "E"):
            v["n%02d-tete-%s" % (lv, d)] = {"level": lv, "part": "tete", "dir": d}
    v["n30-socle"] = {"level": 30, "part": "socle"}
    return v


VARIANTS = variants()
DIR_ANGLE = {"N": 0.0, "E": -math.pi / 2, "S": math.pi, "O": math.pi / 2}

# ------------------------------------------------------------------------------------------------
# Palette (couleurs LINÉAIRES ; paramètres de fo_scene.mat_metal). Corps : acier brun rouillé (cheminée V0).
# Les tôles peintes (olive, crème) sont patinées, rouillées sur les bords, jamais propres.
# ------------------------------------------------------------------------------------------------
RUST = (0.15, 0.055, 0.02)


def palette(epoch):
    M = {
        "body": dict(kind="metal", color=(0.2, 0.168, 0.128), rough=0.45, metallic=0.35, grain=0.22, grain_scale=48.0,
                     rust=RUST, rust_amount=0.38, rust_scale=10.0, dirt=0.7, dirt_distance=0.5),
        "plate": dict(kind="metal", color=(0.27, 0.225, 0.17), rough=0.4, metallic=0.4, grain=0.22, grain_scale=52.0,
                      rust=RUST, rust_amount=0.32, rust_scale=11.0, dirt=0.7, dirt_distance=0.45),
        "plate_l": dict(kind="metal", color=(0.34, 0.285, 0.21), rough=0.38, metallic=0.4, grain=0.22,
                        grain_scale=50.0, rust=RUST, rust_amount=0.28, rust_scale=11.0, dirt=0.7, dirt_distance=0.45),
        "plate2": dict(kind="metal", color=(0.135, 0.118, 0.096), rough=0.5, metallic=0.3, grain=0.22, grain_scale=45.0,
                       rust=RUST, rust_amount=0.4, rust_scale=9.0, dirt=0.75, dirt_distance=0.5),
        # tôle peinte olive patinée (assembleuse, réservoirs vanilla)
        "olive": dict(kind="metal", color=(0.27, 0.235, 0.095), rough=0.6, metallic=0.0, grain=0.22, grain_scale=48.0,
                      rust=RUST, rust_amount=0.26, rust_scale=9.0, dirt=0.7, dirt_distance=0.45),
        # peinture crème patinée (réacteur vanilla)
        "cream": dict(kind="metal", color=(0.52, 0.47, 0.32), rough=0.55, metallic=0.0, grain=0.22, grain_scale=46.0,
                      rust=RUST, rust_amount=0.22, rust_scale=8.0, dirt=0.7, dirt_distance=0.45),
        # acier nu usé : arêtes et reflets francs
        "steel": dict(kind="metal", color=(0.30, 0.275, 0.24), rough=0.28, metallic=0.95, grain=0.3, grain_scale=60.0,
                      rust=RUST, rust_amount=0.18, rust_scale=8.0, dirt=0.7),
        "dark": dict(kind="metal", color=(0.03, 0.027, 0.024), rough=0.6, metallic=0.4, grain=0.25, grain_scale=45.0,
                     dirt=0.5),
        "gun": dict(kind="metal", color=(0.2, 0.185, 0.165), rough=0.25, metallic=0.9, grain=0.22, grain_scale=60.0,
                    rust=RUST, rust_amount=0.2, rust_scale=7.0, dirt=0.6),
        "bolt": dict(kind="metal", color=(0.38, 0.33, 0.26), rough=0.42, metallic=0.85, grain=0.12, grain_scale=70.0,
                     dirt=0.3),
        "brass": dict(kind="metal", color=(0.46, 0.33, 0.14), rough=0.36, metallic=0.95, grain=0.2, grain_scale=60.0,
                      rust=RUST, rust_amount=0.22, rust_scale=6.0, dirt=0.55),
        "copper": dict(kind="metal", color=(0.40, 0.18, 0.085), rough=0.4, metallic=0.95, grain=0.22, grain_scale=55.0,
                       rust=RUST, rust_amount=0.18, rust_scale=6.0, dirt=0.6),
        "haz_y": dict(kind="metal", color=(0.40, 0.26, 0.02), rough=0.62, metallic=0.15, grain=0.35, grain_scale=45.0,
                      rust=RUST, rust_amount=0.4, rust_scale=6.0, dirt=0.75),
        "haz_k": dict(kind="metal", color=(0.028, 0.026, 0.023), rough=0.7, metallic=0.2, grain=0.3, grain_scale=45.0,
                      dirt=0.5),
        "rubber": dict(kind="metal", color=(0.035, 0.032, 0.03), rough=0.72, metallic=0.0, grain=0.15, grain_scale=60.0,
                       dirt=0.4),
        "cable_r": dict(kind="metal", color=(0.2, 0.035, 0.015), rough=0.6, metallic=0.0, grain=0.2, grain_scale=60.0,
                        dirt=0.5),
        "grille": dict(kind="metal", color=(0.05, 0.044, 0.038), rough=0.6, metallic=0.5, grain=0.2, grain_scale=50.0,
                       dirt=0.4),
        "case": dict(kind="metal", color=(0.5, 0.36, 0.14), rough=0.32, metallic=0.95, grain=0.15, grain_scale=70.0,
                     dirt=0.4),
        "glow": dict(kind="emit", color=EPOCH_GLOW[epoch], strength=1.0),
        "amber": dict(kind="emit", color=AMBER, strength=1.0),
        "heat": dict(kind="emit", color=(1.0, 0.36, 0.05), strength=1.0),
    }
    if epoch == 6:
        M["accent"] = dict(kind="metal", color=(0.40, 0.36, 0.29), rough=0.45, metallic=0.0, grain=0.22,
                           grain_scale=55.0, rust=RUST, rust_amount=0.2, rust_scale=7.0, dirt=0.8)
    elif epoch == 11:
        M["accent"] = dict(kind="metal", color=(0.27, 0.26, 0.24), rough=0.4, metallic=0.8, grain=0.24,
                           grain_scale=55.0, rust=RUST, rust_amount=0.15, rust_scale=7.0, dirt=0.75)
    else:
        M["accent"] = dict(kind="metal", color=(0.46, 0.37, 0.20), rough=0.34, metallic=0.95, grain=0.22,
                           grain_scale=55.0, rust=RUST, rust_amount=0.2, rust_scale=6.0, dirt=0.65)
    return M


GRIME = {"body": (0.75, 0.55), "plate": (0.75, 0.55), "plate_l": (0.75, 0.55), "plate2": (0.65, 0.5),
         "olive": (0.75, 0.55), "cream": (0.6, 0.55), "steel": (0.25, 0.3), "gun": (0.2, 0.2), "brass": (0.18, 0.2),
         "copper": (0.18, 0.2), "haz_y": (0.25, 0.35), "accent": (0.22, 0.28), "case": (0.12, 0.1),
         "haz_k": (0.2, 0.2), "dark": (0.2, 0.2), "grille": (0.15, 0.15)}

# usure additive (peinture écaillée vers l'acier nu, ht_blender.add_grime) : part maximale du mélange
WEAR = {"body": 0.6, "plate": 0.5, "plate_l": 0.4, "plate2": 0.65, "olive": 0.55, "cream": 0.35, "haz_y": 0.4}

PLATE_W = 0.42        # largeur d'une tôle d'armure (unités) : la même à tous les niveaux
PLATE_H = 0.3


# ------------------------------------------------------------------------------------------------
# Briques nouvelles
# ------------------------------------------------------------------------------------------------
def ring_plates(b, R, z0, z1, mats=("plate", "plate", "plate_l", "olive"), skip=None, bolts=True, th=0.04,
                cone_r1=None, phase=0.0, tone_seed=0, rivets=None):
    """Tôles d'armure boulonnées autour d'un fût (R, de z0 à z1) ou d'un tronc de cône (R en bas, cone_r1 en haut).
    Tôles de largeur PLATE_W et de hauteur PLATE_H (constantes) : plus le fût est grand, plus il y en a.
    skip(a) -> True : secteur laissé libre (angle a du centre de la tôle)."""
    r1 = R if cone_r1 is None else cone_r1
    h = z1 - z0
    slant = math.hypot(h, R - r1)
    rows = max(1, int(round(slant / PLATE_H)))
    for row in range(rows):
        t0, t1 = row / rows, (row + 1) / rows
        tm = (t0 + t1) / 2
        rr = R + (r1 - R) * tm
        zc = z0 + h * tm
        n = max(6, int(round(TAU * rr / PLATE_W)))
        w = TAU * rr / n - 0.04
        off = 0.5 * (row % 2) + phase
        for i in range(n):
            a = TAU * (i + 0.5 + off) / n
            if skip and skip(a):
                continue
            ca, sa = math.cos(a), math.sin(a)
            u = np.array([-sa, ca, 0.0])
            v = np.array([-ca * (r1 - R), -sa * (r1 - R), h])
            v /= np.linalg.norm(v)
            nrm = np.cross(u, v)
            Rm = np.stack([u, v, nrm], 1)
            c = np.array([ca * rr, sa * rr, zc]) + nrm * th / 2
            k = (i * 7 + row * 3 + tone_seed) % len(mats)
            b.box(mats[k], c, (w, slant / rows - 0.035, th), R=Rm, bev=0.012)
            if bolts:
                # petites viroles (R < 1,3) : 2 boulons en diagonale ; grandes : 4 (plafond anti-bouillie D3 <= 45)
                for su in (-1, 1):
                    for sv in ((-1, 1) if R >= 1.3 else (su,)):
                        p = c + u * su * (w / 2 - 0.045) + v * sv * (slant / rows / 2 - 0.05) + nrm * (th / 2 + 0.004)
                        b.bolt("bolt", p, r=0.019, h=0.014, axis=nrm)
            if rivets if rivets is not None else R > 1.3:
                # rivets le long du bord bas de la tôle (grandes viroles : grandes tôles rivetées)
                nr = max(2, int((w - 0.16) / (0.075 if R < 2.0 else 0.06)))
                for j in range(nr):
                    for sv in (-1, 1):
                        q = c + u * (-(w - 0.16) / 2 + (j + 0.5) * (w - 0.16) / nr) + sv * v * (slant / rows / 2 - 0.035) + nrm * (th / 2 + 0.003)
                        b.cyl("bolt", q, 0.011, 0.01, axis=nrm, n=6, bev=0)


def ribs(b, R, z0, z1, n, depth=0.14, w=0.07, mat="plate2", phase=0.0, skip=None, top_r=None):
    """Nervures verticales (goussets triangulaires) en saillie autour d'un fût : relief et ombres internes."""
    for i in range(n):
        a = TAU * (i + phase) / n
        if skip and skip(a):
            continue
        ca, sa = math.cos(a), math.sin(a)
        Rm = Rz(a)
        r_top = R if top_r is None else top_r
        poly = [(0.0, z0), (depth, z0), (0.012, z1)]
        # prisme dans le plan radial (x local = radial, y local = z), épaisseur w selon la tangente
        M = Rm @ np.array([[1.0, 0, 0], [0, 0, 1.0], [0, 1.0, 0]])
        b.prism(mat, poly, -w / 2, w / 2, R=M, t=(ca * R, sa * R, 0.0), bev=0.01)
        b.bolt("bolt", (ca * (R + depth * 0.45), sa * (R + depth * 0.45), z0 + (z1 - z0) * 0.35), r=0.018, h=0.012,
               axis=(ca, sa, 0.0))


def mount(b, R0, z_top, tiers, n_ribs, vents=0, glow_vents=0, haz=True, lamps=0, vent_tiers=(0,)):
    """AFFÛT BLINDÉ (le « socle pivotant ») : gradins circulaires (tiers = [(rayon, hauteur), ...] de bas en haut),
    tôles boulonnées sur chaque gradin, nervures en saillie, grilles d'aération (certaines lumineuses) sur le
    secteur avant, bande de danger sur le rebord, couronne de roulement laiton et boulons du dessus."""
    z = 0.0
    for k, (r, h) in enumerate(tiers):
        b.cyl("plate2", (0, 0, z + h / 2), r, h, n=max(48, int(r * 30)), bev=0.02)
        front = (lambda a: -2.6 < a - TAU * (a > math.pi) < -0.55) if (k in vent_tiers and vents) else None
        ring_plates(b, r, z + 0.02, z + h - 0.02, skip=front, tone_seed=k * 5)
        # rebord du gradin : cornière et boulons
        b.cyl("body", (0, 0, z + h + 0.015), r + 0.03, 0.03, n=max(48, int(r * 30)), bev=0.008)
        nb = int(TAU * r / 0.16)
        for i in range(nb):
            a = TAU * (i + 0.5) / nb
            b.bolt("bolt", (math.cos(a) * (r - 0.05), math.sin(a) * (r - 0.05), z + h + 0.03), r=0.02)
        if k == 0:
            ribs(b, r, z, z + h * 0.95, n_ribs, depth=0.16)
        if k in vent_tiers:
            if vents:
                # grilles sur le secteur avant (face à la caméra)
                for i in range(vents):
                    a = -2.55 + (2.55 - 0.6) * (i + 0.5) / vents
                    ca, sa = math.cos(a), math.sin(a)
                    u = np.array([-sa, ca, 0.0])
                    b.vent_face("plate", "steel", "glow" if i % max(1, vents // max(1, glow_vents)) == 0 and glow_vents
                                else "dark", (ca * (r + 0.01), sa * (r + 0.01), z + h * 0.5), u, (0, 0, 1),
                                min(0.42, TAU * r / (vents * 1.8)), h * 0.62, max(3, int(h * 0.62 / 0.075)))
        z += h
    if haz:
        # bande de danger du rebord supérieur (secteur avant)
        r = tiers[-1][0]
        n = int(TAU * r / 0.3)
        for i in range(n):
            a = TAU * (i + 0.5) / n
            if math.sin(a) > -0.15:
                continue
            ca, sa = math.cos(a), math.sin(a)
            u = np.array([-sa, ca, 0.0])
            p = np.array((ca * (r + 0.005), sa * (r + 0.005), z - 0.07))
            w = TAU * r / n
            b.hazard_band("haz_y", "haz_k", p - u * w / 2, p + u * w / 2, width=0.1, th=0.012, normal=(ca, sa, 0.0),
                          n=2)
    # feux de position ronds sur le rebord (secteur avant), comme les feux de la fosse du silo vanilla
    rims = [(tiers[-1][0], z - 0.02, 0.0)]
    if lamps >= 999:      # feux de gradin abandonnés : effet guirlande (rendu r6)
        zz = 0.0
        for k, (rk, hk) in enumerate(tiers[:-1]):
            zz += hk
            if k % 2 == 0:
                rims.append((rk, zz + 0.01, 0.5))
    for (r, zr, ph) in (rims if lamps else []):
        for i in range(lamps):
            a = math.pi + math.pi * (i + 0.5 + ph) / lamps
            if a >= TAU:
                continue
            ca, sa = math.cos(a), math.sin(a)
            nrm = np.array([ca * 0.7, sa * 0.7, 0.7])
            p = np.array([ca * (r - 0.02), sa * (r - 0.02), zr])
            b.cyl("steel", p, 0.06, 0.05, axis=nrm, n=14, bev=0.006)
            b.cyl("glow", p + nrm * 0.03, 0.046, 0.016, axis=nrm, n=12, bev=0)
    # dessus : couronne de roulement (cachée par la tête, sauf le bord)
    r = tiers[-1][0]
    b.cyl("steel", (0, 0, z + 0.012), r - 0.1, 0.024, n=72, bev=0.006)
    b.cyl("dark", (0, 0, z + 0.02), r - 0.22, 0.02, n=72, bev=0)
    return z


def curb(b, R, w=0.16, h=0.07):
    """Bordure annulaire au pied de l'affût : cornière boulonnée, bande de danger sur le secteur avant."""
    b.cyl("body", (0, 0, h / 2), R + w, h, n=max(48, int(R * 30)), bev=0.012)
    nb = int(TAU * (R + w / 2) / 0.2)
    for i in range(nb):
        a = TAU * (i + 0.5) / nb
        b.bolt("bolt", (math.cos(a) * (R + w * 0.6), math.sin(a) * (R + w * 0.6), h + 0.004), r=0.019)
    n = int(TAU * (R + w) / 0.26)
    for i in range(n):
        a = TAU * (i + 0.5) / n
        if math.sin(a) > -0.3:
            continue
        ca, sa = math.cos(a), math.sin(a)
        u = np.array([-sa, ca, 0.0])
        p = np.array((ca * (R + w + 0.004), sa * (R + w + 0.004), h * 0.5))
        ww = TAU * (R + w) / n
        b.hazard_band("haz_y", "haz_k", p - u * ww / 2, p + u * ww / 2, width=h * 0.7, th=0.008, normal=(ca, sa, 0.0),
                      n=2)


def hoist(b, a, R, z_top, w=0.4, depth=0.34):
    """MONTE-CHARGE À MUNITIONS plaqué sur l'affût (angle a) : gaine verticale boulonnée en saillie du sol au
    rebord, porte de visite, bande de danger, goulotte au sommet, conduite d'huile. Casse la monotonie des anneaux
    et projette une ombre interne (relief, critique point 4)."""
    ca, sa = math.cos(a), math.sin(a)
    u = np.array([-sa, ca, 0.0])
    n_ = np.array([ca, sa, 0.0])
    Rm = np.stack([u, n_, np.array([0, 0, 1.0])], 1)
    c = np.array([ca * (R + depth / 2 - 0.06), sa * (R + depth / 2 - 0.06), z_top / 2])
    b.box("plate2", c, (w, depth, z_top + 0.06), R=Rm, bev=0.02)
    f = c + n_ * (depth / 2 + 0.012)
    b.box("plate", f + np.array([0, 0, z_top * 0.1]), (w - 0.08, 0.025, z_top * 0.6), R=Rm, bev=0.01)
    for sv in (-1, 1):
        for su in (-1, 1):
            b.bolt("bolt", f + u * su * (w / 2 - 0.07) + np.array([0, 0, z_top * 0.1 + sv * z_top * 0.27]), r=0.017,
                   h=0.012, axis=n_)
    b.hazard_band("haz_y", "haz_k", f - u * (w / 2 - 0.03) + np.array([0, 0, z_top * 0.48]),
                  f + u * (w / 2 - 0.03) + np.array([0, 0, z_top * 0.48]), width=0.08, th=0.008, normal=n_)
    b.box("dark", f + np.array([0, 0, -z_top * 0.33]), (w * 0.5, 0.02, 0.05), R=Rm, bev=0)
    b.box("steel", c + np.array([0, 0, z_top / 2 + 0.05]), (w + 0.04, depth + 0.04, 0.05), R=Rm, bev=0.01)
    b.cyl("copper", c + u * (w / 2 + 0.04) + n_ * 0.05, 0.03, z_top, n=8, bev=0)
    for t in (0.25, 0.75):
        b.box("steel", c + u * (w / 2 + 0.04) + n_ * 0.05 + np.array([0, 0, (t - 0.5) * z_top]), (0.07, 0.07, 0.03),
              R=Rm, bev=0)


def apron(b, side, cf, cb, z=0.045, inset=0.0):
    """Tablier bas (4,5 cm) qui relie les volumes : caillebotis (barreaux), cornières, boulons ; jamais une dalle
    lisse. Rentré de `inset` et à grands chanfreins : le contour du bâtiment est fait par les VOLUMES posés au sol
    (qui le débordent), pas par un carré plat."""
    hx, hy = side / 2.0 - inset, (side / 2.0 - inset) * TD
    poly = [(-hx + cf, -hy), (hx - cf, -hy), (hx, -hy + cf * TD), (hx, hy - cb * TD), (hx - cb, hy), (-hx + cb, hy),
            (-hx, hy - cb * TD), (-hx, -hy + cf * TD)]
    b.prism("grille", poly, 0.0, z * 0.5, bev=0.0)
    # barreaux du caillebotis (pas de 0,09), coupés exactement au contour (intersection verticale / polygone)
    n = int((2 * hx - 0.1) / 0.09)
    m = len(poly)
    for i in range(n):
        x = -hx + 0.05 + (i + 0.5) * (2 * hx - 0.1) / n
        ys = []
        for j in range(m):
            (x0, y0), (x1, y1) = poly[j], poly[(j + 1) % m]
            if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
                ys.append(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
        if len(ys) < 2:
            continue
        ya, yb = min(ys) + 0.06, max(ys) - 0.06
        if yb > ya:
            b.box("plate2", (x, (ya + yb) / 2, z * 0.5 + 0.012), (0.03, yb - ya, 0.024), bev=0)
    m = len(poly)
    for i in range(m):
        p0, p1 = poly[i], poly[(i + 1) % m]
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        L = math.hypot(dx, dy)
        a = math.atan2(dy, dx)
        nx, ny = -dy / L, dx / L
        cx, cy = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        b.box("body", (cx + nx * 0.04, cy + ny * 0.04, z * 0.5 + 0.02), (L - 0.04, 0.08, z + 0.005), R=Rz(a), bev=0.008)
        k = max(2, int(L / 0.28))
        for j in range(k):
            t = (j + 0.5) / k
            b.bolt("bolt", (p0[0] + dx * t + nx * 0.04, p0[1] + dy * t + ny * 0.04, z + 0.028), r=0.018)
    return poly


def core_vessel(b, c, r, glow_ports=3, paint="cream"):
    """CUVE-CŒUR (à la manière du réacteur vanilla) : sphère peinte patinée sur berceau, cerclages rivetés,
    trappes rondes boulonnées, hublots RONDS lumineux (petits foyers), bride sommitale et vanne, piquages pour les
    gaines. Fonction : réserve et conversion d'énergie de la tourelle."""
    x, y, z = c
    # berceau : anneau et 4 pieds
    b.cyl("plate2", (x, y, 0.08), r * 0.7, 0.16, n=36, bev=0.015)
    for k in range(4):
        a = TAU * (k + 0.5) / 4
        px, py = x + math.cos(a) * r * 0.62, y + math.sin(a) * r * 0.62
        b.box("body", (px, py, (z - r * 0.5) / 2 + 0.08), (0.14, 0.14, z - r * 0.5), R=Rz(a), bev=0.01)
        b.box("plate", (px, py, 0.05), (0.26, 0.26, 0.1), R=Rz(a), bev=0.01)
        for s in (-1, 1):
            b.bolt("bolt", (px + s * 0.08, py, 0.105), r=0.018)
    b.sphere(paint, (x, y, z), r, n=40, m=20)
    # cerclages (latitudes) rivetés
    for lat in (-0.35, 0.05, 0.45):
        zz = z + r * math.sin(lat)
        rr = r * math.cos(lat)
        b.torus("steel", (x, y, zz), rr + 0.004, 0.022, n=56, m=6)
        nb = int(TAU * rr / 0.13)
        for i in range(nb):
            a = TAU * i / nb
            p = np.array([x + math.cos(a) * rr * 1.02, y + math.sin(a) * rr * 1.02, zz + 0.03])
            n_ = np.array([math.cos(a) * math.cos(lat), math.sin(a) * math.cos(lat), math.sin(lat)])
            b.bolt("bolt", p, r=0.016, h=0.012, axis=n_)
    # méridiens de tôle (joints) sur la face sud
    for a in (-2.2, -1.57, -0.94):
        pts = []
        for k in range(12):
            t = -0.9 + 1.8 * k / 11
            pts.append((x + math.cos(a) * math.cos(t) * (r + 0.006), y + math.sin(a) * math.cos(t) * (r + 0.006),
                        z + math.sin(t) * (r + 0.006)))
        b.tube("plate2", pts, 0.012, n=6)
    # hublots ronds lumineux sur la face sud-ouest et sud (petits foyers)
    for k in range(glow_ports):
        a = -1.57 + (k - (glow_ports - 1) / 2) * 0.42
        lat = 0.18 + 0.12 * (k % 2)
        n_ = np.array([math.cos(a) * math.cos(lat), math.sin(a) * math.cos(lat), math.sin(lat)])
        p = np.array([x, y, z]) + n_ * r
        b.cyl("steel", p, 0.11, 0.05, axis=n_, n=20, bev=0.008)
        b.cyl("dark", p + n_ * 0.026, 0.085, 0.012, axis=n_, n=18, bev=0)
        b.cyl("glow", p + n_ * 0.03, 0.065, 0.012, axis=n_, n=16, bev=0)
        for i in range(6):
            aa = TAU * i / 6
            F = G.frame_from_axis(n_)
            q = p + (F[:, 0] * math.cos(aa) + F[:, 1] * math.sin(aa)) * 0.085 + n_ * 0.028
            b.bolt("bolt", q, r=0.012, h=0.01, axis=n_)
        b.light(p + n_ * 0.15, (1, 1, 1), 1.0)
    # trappe ronde boulonnée (face sud-est)
    a, lat = -0.75, -0.05
    n_ = np.array([math.cos(a) * math.cos(lat), math.sin(a) * math.cos(lat), math.sin(lat)])
    p = np.array([x, y, z]) + n_ * r
    b.cyl("plate", p, r * 0.3, 0.06, axis=n_, n=24, bev=0.01)
    F = G.frame_from_axis(n_)
    for i in range(10):
        aa = TAU * i / 10
        b.bolt("bolt", p + (F[:, 0] * math.cos(aa) + F[:, 1] * math.sin(aa)) * r * 0.25 + n_ * 0.035, r=0.016,
               h=0.012, axis=n_)
    b.box("dark", p + n_ * 0.04, (0.16, 0.03, 0.03), R=F, bev=0)
    # bride sommitale, vanne
    b.cyl("steel", (x, y, z + r + 0.02), r * 0.32, 0.08, n=24, bev=0.01)
    b.cyl("plate2", (x, y, z + r + 0.1), r * 0.16, 0.12, n=16, bev=0.008)
    b.torus("cable_r", (x, y, z + r + 0.2), r * 0.18, 0.02, n=20, m=6)
    nb = 12
    for i in range(nb):
        aa = TAU * i / nb
        b.bolt("bolt", (x + math.cos(aa) * r * 0.27, y + math.sin(aa) * r * 0.27, z + r + 0.065), r=0.016)


def generator(b, c, L, r, axis="x", glow=True):
    """GÉNÉRATEUR BOBINÉ couché : carcasse cerclée à bobines de cuivre apparentes, flasques boulonnés, volant
    d'inertie, pattes de fixation, boîte à bornes et faisceau de câbles, fentes de chaleur (petits foyers)."""
    x, y, z0 = c
    zc = z0 + r + 0.08
    ax = np.array([1.0, 0, 0]) if axis == "x" else np.array([0, 1.0, 0])
    perp = np.array([0, 1.0, 0]) if axis == "x" else np.array([1.0, 0, 0])
    C = np.array([x, y, zc])
    # pattes
    for t in (-0.32, 0.32):
        p = C + ax * L * t
        b.box("plate2", (p[0], p[1], z0 + (r + 0.08) / 2), (0.16 if axis == "x" else r * 1.7, r * 1.7 if axis == "x"
                                                             else 0.16, r + 0.08), bev=0.012)
    b.cyl("body", C, r, L * 0.78, axis=ax, n=32, bev=0.012)
    # bobines (tores cuivre) sur le tiers central, carter ajouré au-dessus
    nk = int(L * 0.5 / 0.065)
    for k in range(nk):
        b.torus("copper", C + ax * (-L * 0.25 + k * L * 0.5 / max(1, nk - 1)), r + 0.012, 0.026, axis=ax, n=32, m=6)
    for t in (-0.3, 0.3):
        b.cyl("steel", C + ax * L * t, r + 0.04, 0.06, axis=ax, n=32, bev=0.008)
    for s in (-1, 1):
        e = C + ax * s * L * 0.42
        b.cyl("plate", e, r * 0.92, L * 0.08, axis=ax, n=32, bev=0.014)
        F = G.frame_from_axis(ax * s)
        for i in range(10):
            a = TAU * i / 10
            b.bolt("bolt", e + ax * s * L * 0.04 + (F[:, 0] * math.cos(a) + F[:, 1] * math.sin(a)) * r * 0.78, r=0.018,
                   h=0.012, axis=ax * s)
    # volant d'inertie (côté +), moyeu
    e = C + ax * L * 0.5
    b.cyl("steel", e + ax * 0.03, r * 1.08, 0.08, axis=ax, n=40, bev=0.01)
    b.cyl("dark", e + ax * 0.075, r * 0.3, 0.03, axis=ax, n=16, bev=0)
    for i in range(6):
        a = TAU * i / 6
        F = G.frame_from_axis(ax)
        b.box("plate2", e + ax * 0.08 + (F[:, 0] * math.cos(a) + F[:, 1] * math.sin(a)) * r * 0.6,
              (0.05, 0.05, 0.05), bev=0)
    # boîte à bornes et câbles
    tb = C + np.array([0, 0, r + 0.08]) - ax * L * 0.12
    b.box("olive", tb, (0.3, 0.26, 0.16) if axis == "x" else (0.26, 0.3, 0.16), bev=0.012)
    b.bolts_rect("bolt", tb[0] - 0.12, tb[0] + 0.12, tb[1] - 0.1, tb[1] + 0.1, tb[2] + 0.08, r=0.015, inset=0.03)
    if glow:
        for k in range(3):
            q = C - perp * (r + 0.004) + ax * (-0.18 + k * 0.18)
            b.box("dark", q, (0.12, 0.02, 0.07) if axis == "x" else (0.02, 0.12, 0.07), bev=0)
            b.box("glow", q - perp * 0.008, (0.08, 0.012, 0.035) if axis == "x" else (0.012, 0.08, 0.035), bev=0)
    return tb


def ammo_magazine(b, c, size, belt_to=None):
    """MAGASIN DE MUNITIONS : caisson blindé à tôles olive, portes boulonnées à charnières, bande de danger,
    trappe de chargement sur le dessus, rangée de caisses et goulotte vers l'affût."""
    x, y, z0 = c
    sx, sy, sz = size
    b.box("plate2", (x, y, z0 + sz / 2), (sx, sy, sz), bev=0.025)
    b.plates_face("olive", (x, y - sy / 2, z0 + sz * 0.5), (1, 0, 0), (0, 0, 1), max(1, int(sx / PLATE_W)),
                  max(1, int(sz / 0.36)), sx - 0.04, sz - 0.06, th=0.028, bolt_mat="bolt", tones=("olive", "olive",
                                                                                                    "plate"))
    b.plates_top("plate", x - sx / 2 + 0.03, x + sx / 2 - 0.03, y - sy / 2 + 0.03, y + sy / 2 - 0.03, z0 + sz,
                 max(1, int(sx / PLATE_W)), max(1, int(sy / PLATE_W)), th=0.03, gap=0.03, bolt_mat="bolt")
    b.hazard_band("haz_y", "haz_k", (x - sx / 2 + 0.05, y - sy / 2 - 0.03, z0 + sz * 0.12),
                  (x + sx / 2 - 0.05, y - sy / 2 - 0.03, z0 + sz * 0.12), width=0.1, th=0.012, normal="-y")
    for s in (-1, 1):
        b.box("body", (x + s * (sx / 2 + 0.01), y, z0 + sz / 2), (0.05, sy - 0.04, sz - 0.04), bev=0.008)
        for zz in (0.3, 0.7):
            b.cyl("steel", (x + s * (sx / 2 - 0.12), y - sy / 2 - 0.03, z0 + sz * zz), 0.025, 0.1, n=8, bev=0)
    b.lamp("amber", "plate2", (x + sx * 0.3, y - sy / 2 - 0.035, z0 + sz * 0.82), (0.07, 0.04), axis="-y")


def missile_rack(b, c, rot, n=(3, 2)):
    """PIÈCE DU NIVEAU 30 : lance-missiles blindé incliné (coin avant), ogives à lueur d'époque, socle à bande de
    danger. Posé hors du balayage de la tête (F46)."""
    x, y = c
    b.push(Rz(rot), (x, y, 0.0))
    b.box("plate2", (0, 0, 0.11), (0.95, 0.9, 0.22), bev=0.02)
    b.hazard_band("haz_y", "haz_k", (-0.43, -0.455, 0.11), (0.43, -0.455, 0.11), width=0.12, th=0.01, normal="-y")
    b.bolts_line("bolt", (-0.4, -0.46, 0.2), (0.4, -0.46, 0.2), 6, r=0.016, axis="-y", h=0.01)
    b.cyl("steel", (0, 0.05, 0.27), 0.34, 0.1, n=32, bev=0.01)
    b.push(Rx(0.38), (0, 0.05, 0.33))
    b.box("olive", (0, 0, 0.28), (0.78, 0.66, 0.5), bev=0.025)
    for s in (-1, 1):
        b.plates_face("plate", (s * 0.39, 0, 0.28), (0, s, 0), (0, 0, 1), 2, 1, 0.6, 0.44, th=0.02, bolt_mat="bolt")
    b.bolts_rect("bolt", -0.36, 0.36, -0.31, 0.31, 0.53, r=0.018, inset=0.05, n=(4, 4))
    b.box("plate", (0, 0.04, 0.545), (0.5, 0.36, 0.03), bev=0.008)
    nx, nz = n
    for i in range(nx):
        for j in range(nz):
            px, pz = -0.24 + i * 0.24, 0.16 + j * 0.22
            b.cyl("dark", (px, -0.332, pz), 0.085, 0.03, axis="y", n=16, bev=0)
            b.cyl("accent", (px, -0.33, pz), 0.095, 0.02, axis="y", n=16, bev=0.004)
            b.cyl("glow", (px, -0.345, pz), 0.042, 0.012, axis="y", n=12, bev=0)
    b.pop()
    b.pop()
    b.light((x, y - 0.5, 0.5), (1, 1, 1), 1.0)


def receiver(b, x, y0, y1, z, w, h, feed_side=1):
    """CULASSE : boîtier de mécanisme boulonné derrière le faisceau, couvercle à charnière, fenêtre d'éjection,
    cylindres de recul au-dessus, entrée de bande côté feed_side."""
    L = y1 - y0
    b.box("plate2", (x, (y0 + y1) / 2, z), (w, L, h), bev=0.022)
    b.box("plate", (x, (y0 + y1) / 2, z + h / 2 + 0.018), (w - 0.06, L - 0.08, 0.036), bev=0.01)
    b.bolts_rect("bolt", x - w / 2 + 0.03, x + w / 2 - 0.03, y0 + 0.04, y1 - 0.04, z + h / 2 + 0.036, r=0.017,
                 inset=0.04, n=(3, max(2, int(L / 0.2))))
    for s in (-1, 1):
        b.cyl("steel", (x + s * w * 0.28, (y0 + y1) / 2 + L * 0.1, z + h / 2 + 0.07), 0.04, L * 0.7, axis="y", n=12,
              bev=0.005)
    b.box("dark", (x + feed_side * (w / 2 + 0.005), y0 + L * 0.6, z + h * 0.1), (0.02, L * 0.3, h * 0.35), bev=0)
    for s in (-1, 1):
        b.plates_face("plate", (x + s * w / 2, (y0 + y1) / 2, z), (0, s, 0), (0, 0, 1), max(1, int(L / PLATE_W)), 1,
                      L - 0.06, h - 0.06, th=0.022, bolt_mat="bolt")


def gun(b, x, y0, z, P):
    """FAISCEAU ROTATIF : culasse, berceau à tourillons, faisceau de nb canons (bagues, moyeu, frein de bouche),
    chemise de refroidissement perforée à fentes de chaleur (petits foyers), cylindres de recul."""
    nb, ring_r, br, L = P["barrels"], P["ring_r"], P["br"], P["L"]
    rc = ring_r + br
    receiver(b, x, y0 - P["rec_L"], y0 + 0.05, z, P["rec_w"], P["rec_h"], feed_side=P.get("feed", 1))
    # berceau / bouclier de canon (masque) devant la culasse
    b.cyl("steel", (x, y0 + 0.04, z), rc + 0.1, 0.1, axis="y", n=28, bev=0.012)
    b.cyl("plate2", (x, y0 + 0.12, z), rc + 0.06, 0.08, axis="y", n=28, bev=0.01)
    nbo = 10
    for i in range(nbo):
        a = TAU * i / nbo
        b.bolt("bolt", (x + math.cos(a) * (rc + 0.06), y0 + 0.165, z + math.sin(a) * (rc + 0.06)), r=0.016, h=0.012,
               axis=(0, 1.0, 0))
    b.gatling("gun", "steel", "dark", (x, y0 + 0.12, z), nb, ring_r, br, L,
              rings=tuple(t for t in (0.08, 0.5, 0.72, 0.93)), muzzle_mat="plate")
    # chemise perforée sur le premier tiers, fentes de chaleur sur le dessus
    sL = L * P.get("shroud", 0.38)
    shroud(b, (x, y0 + 0.2, z), rc + 0.045, sL, holes_rows=max(3, int(sL / 0.13)), holes_per_row=max(8, int(rc * 50)))
    # perforations RONDES incandescentes sur le dessus de la chemise (canons chauds) : des trous, pas des fenêtres
    nsl = max(2, int(sL / 0.12))
    R_ = rc + 0.045
    for k in range(nsl):
        yy = y0 + 0.26 + (k + 0.5) * (sL - 0.12) / nsl
        for j, a in enumerate((math.pi / 2 - 0.42, math.pi / 2 + 0.42) if k % 2 == 0 else (math.pi / 2,)):
            n_ = np.array([math.cos(a), 0.0, math.sin(a)])
            p = np.array([x, yy, z]) + n_ * (R_ + 0.004)
            b.cyl("dark", p, 0.038, 0.012, axis=n_, n=12, bev=0)
            b.cyl("heat", p + n_ * 0.004, 0.026, 0.01, axis=n_, n=10, bev=0)
    # cylindres de recul sous le faisceau (visibles de côté)
    for s in (-1, 1):
        b.cyl("steel", (x + s * (rc + 0.03), y0 + 0.35, z - rc * 0.6), 0.035, 0.55, axis="y", n=10, bev=0.004)


def armor_skirt(b, R, z0, z1, a0, a1, n, standoff=0.08, mat="olive"):
    """Blindage espacé : plaques sur entretoises devant le fût (plaques multiples, ère V)."""
    for i in range(n):
        a = a0 + (a1 - a0) * (i + 0.5) / n
        ca, sa = math.cos(a), math.sin(a)
        Rm = Rz(a + math.pi / 2)
        w = (a1 - a0) / n * (R + standoff) - 0.05
        c = (ca * (R + standoff), sa * (R + standoff), (z0 + z1) / 2)
        b.box(mat, c, (w, 0.05, z1 - z0), R=Rm, bev=0.016)
        for zz in (z0 + 0.1, z1 - 0.1):
            for s in (-1, 1):
                u = np.array([-sa, ca, 0.0])
                p = np.array([ca * (R + standoff / 2), sa * (R + standoff / 2), zz]) + u * s * w * 0.3
                b.cyl("steel", p, 0.025, standoff, axis=(ca, sa, 0.0), n=8, bev=0)
                b.bolt("bolt", p + np.array([ca, sa, 0.0]) * (standoff / 2 + 0.03), r=0.02, h=0.014, axis=(ca, sa, 0.0))


def capacitor_cell(b, c, r, h, ports=2):
    """Cellule de condensateur verticale compacte (tête) : fût cerclé laiton, jauges rondes lumineuses, bornes."""
    x, y, z = c
    b.cyl("plate2", (x, y, z + h / 2), r, h, n=24, bev=0.01)
    for t in (0.15, 0.85):
        b.cyl("brass", (x, y, z + h * t), r + 0.015, 0.035, n=24, bev=0.005)
    for k in range(ports):
        a = -math.pi / 2 + (k - (ports - 1) / 2) * 0.9
        n_ = np.array([math.cos(a), math.sin(a), 0.0])
        p = np.array([x, y, z + h * 0.5]) + n_ * r
        b.cyl("dark", p, 0.045, 0.02, axis=n_, n=12, bev=0)
        b.cyl("glow", p + n_ * 0.008, 0.03, 0.012, axis=n_, n=12, bev=0)
    b.cyl("plate", (x, y, z + h + 0.02), r * 0.85, 0.04, n=24, bev=0.006)
    for s in (-1, 1):
        b.cyl("copper", (x + s * r * 0.4, y, z + h + 0.07), 0.03, 0.07, n=8, bev=0.004)


# ------------------------------------------------------------------------------------------------
# Tête paramétrée (repère local : canons vers +Y, z absolu)
# ------------------------------------------------------------------------------------------------
HEAD = {
    11: dict(z0=0.55, ring=1.1, hull=0.86, hull_h=0.3, cone_h=0.16, cone_k=0.8, guns=[-0.3, 0.3],
             gun=dict(barrels=4, ring_r=0.085, br=0.04, L=1.4, rec_L=0.8, rec_w=0.24, rec_h=0.24, shroud=0.42),
             mantlet=(0.6, 0.12, 0.4), drums=[1], drum=(0.26, 0.62), secondaries=[], sensor=None,
             bustle=(0.9, 0.3, 0.36), radiators=1, cells=0, skirt=False, hoses=0, insulators=True),
    21: dict(z0=0.85, ring=1.78, hull=1.4, hull_h=0.42, cone_h=0.24, cone_k=0.8, guns=[-0.52, 0.52],
             gun=dict(barrels=6, ring_r=0.16, br=0.06, L=2.35, rec_L=1.2, rec_w=0.4, rec_h=0.38, shroud=0.4),
             mantlet=(1.0, 0.16, 0.62), drums=[1, -1], drum=(0.38, 1.0), secondaries=[(-0.85, -0.55)],
             sensor=(0.0, 0.2), bustle=(1.5, 0.42, 0.56), radiators=2, cells=2, skirt=False, hoses=2,
             insulators=False),
    29: dict(z0=1.05, ring=2.22, hull=1.78, hull_h=0.5, cone_h=0.3, cone_k=0.8, guns=[-1.1, -0.38, 0.38, 1.1],
             gun=dict(barrels=8, ring_r=0.2, br=0.062, L=2.85, rec_L=1.45, rec_w=0.44, rec_h=0.44, shroud=0.4),
             mantlet=(1.5, 0.18, 0.78), drums=[1, -1], drum=(0.46, 1.3), secondaries="tambours",
             sensor="masque", bustle=(2.0, 0.5, 0.7), radiators=3, cells=4, skirt=True, hoses=2,
             insulators=False),
}
HEAD[30] = HEAD[29]


def head_dims(lv):
    P = HEAD[lv]
    zb = P["z0"] + 0.11
    zh = zb + P["hull_h"]
    zt = zh + P["cone_h"]
    rt = P["hull"] * P["cone_k"]
    gz = zt + P["gun"]["rec_h"] / 2 + 0.1
    y0 = rt * 0.85 + 0.12
    return zb, zh, zt, rt, gz, y0


def head(b, lv):
    """Tête de la tourelle : couronne tournante, coque ronde basse et large (fût + cône de glacis), culasses et
    faisceaux posés SUR le toit derrière un masque blindé, tambours-chargeurs et bandes de cartouches laiton,
    bustle arrière (radiateurs, grille), cellules, tourelles secondaires, viseur, gaines et câbles. Les dimensions
    viennent de HEAD[lv] ; les PIÈCES (tôles, boulons, grilles) gardent leur taille absolue."""
    P = HEAD[lv]
    z0, Rr, Rh = P["z0"], P["ring"], P["hull"]
    zb, zh, zt, rt, gz, y0 = head_dims(lv)
    G_ = P["gun"]
    # couronne tournante : plateau, chemin de roulement, boulons
    b.cyl("plate2", (0, 0, z0 + 0.05), Rr, 0.1, n=72, bev=0.012)
    b.cyl("steel", (0, 0, z0 + 0.105), Rr - 0.06, 0.02, n=72, bev=0.005)
    nb = int(TAU * Rr / 0.17)
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (math.cos(a) * (Rr - 0.06), math.sin(a) * (Rr - 0.06), z0 + 0.12), r=0.021)
    b.label("socle pivotant")
    # coque : fût et cône de glacis, tôles boulonnées tout autour
    b.cyl("body", (0, 0, (zb + zh) / 2), Rh, zh - zb, n=64, bev=0.02)
    b.cyl("body", (0, 0, (zh + zt) / 2), Rh, zt - zh, r2=rt, n=64, bev=0.02)
    ring_plates(b, Rh, zb + 0.02, zh, tone_seed=lv, mats=("olive", "olive", "plate_l", "olive", "plate"))
    ring_plates(b, Rh + 0.02, zh, zt, cone_r1=rt + 0.02, tone_seed=lv + 2, mats=("olive", "plate_l", "olive", "olive", "plate"))
    # bande de danger sur le bas de la coque (secteur avant)
    nh = int(TAU * Rh / 0.3)
    for i in range(nh):
        a = TAU * (i + 0.5) / nh
        if not (0.6 < a < 2.55):
            continue
        ca, sa = math.cos(a), math.sin(a)
        u = np.array([-sa, ca, 0.0])
        p = np.array((ca * (Rh + 0.045), sa * (Rh + 0.045), zb + 0.06))
        w = TAU * Rh / nh
        b.hazard_band("haz_y", "haz_k", p - u * w / 2, p + u * w / 2, width=0.08, th=0.01, normal=(ca, sa, 0.0), n=2)
    # voyants ronds d'état en ceinture (ère IV et V) : petits foyers, jamais une bande continue
    if lv >= 21:
        nl = int(TAU * Rh / 0.3)
        for i in range(nl):
            a = TAU * (i + 0.25) / nl
            if 0.6 < a < 2.55:
                continue
            ca, sa = math.cos(a), math.sin(a)
            n_ = np.array([ca, sa, 0.0])
            p = np.array([ca * (Rh + 0.04), sa * (Rh + 0.04), zb + (zh - zb) * 0.62])
            b.cyl("steel", p, 0.05, 0.04, axis=n_, n=14, bev=0.005)
            b.cyl("glow", p + n_ * 0.022, 0.032, 0.012, axis=n_, n=12, bev=0)
    b.label("tête à canons")
    # toit : tôles, boulons de rive
    b.cyl("plate", (0, 0, zt + 0.02), rt, 0.04, n=64, bev=0.01)
    k = max(2, int(2 * rt * 0.7 / PLATE_W + 0.5))
    sq = rt * 0.7
    b.plates_top("plate2", -sq, sq, -sq, sq, zt + 0.04, k, k, th=0.025, gap=0.03, bolt_mat="bolt")
    nb = int(TAU * rt / 0.15)
    for i in range(nb):
        a = TAU * i / nb
        b.bolt("bolt", (math.cos(a) * (rt - 0.05), math.sin(a) * (rt - 0.05), zt + 0.045), r=0.019)
    # berceaux sous les culasses
    for x in P["guns"]:
        for yy in (y0 - G_["rec_L"] * 0.75, y0 - G_["rec_L"] * 0.2):
            h = gz - G_["rec_h"] / 2 - zt
            b.box("plate2", (x, yy, zt + h / 2 + 0.02), (G_["rec_w"] * 0.8, 0.16, h + 0.04), bev=0.012)
            for s in (-1, 1):
                b.cyl("steel", (x + s * G_["rec_w"] * 0.42, yy, zt + h * 0.6), 0.05, 0.05, axis="x", n=12, bev=0.005)
    # masque frontal : bouclier épais incliné devant les culasses, embrasures, bande de danger
    mw, md, mh = P["mantlet"]
    b.box("plate2", (0, y0 - md / 2, gz), (mw * 2, md, mh), R=Rx(-0.12), bev=0.03)
    b.box("olive", (0, y0 + 0.012, gz + 0.02), (mw * 2 - 0.08, 0.04, mh - 0.1), R=Rx(-0.12), bev=0.012)
    b.bolts_line("bolt", (-mw + 0.07, y0 + 0.04, gz + mh / 2 - 0.08), (mw - 0.07, y0 + 0.07, gz + mh / 2 - 0.08),
                 max(4, int(mw * 2 / 0.14)), r=0.02, axis=(0, 0.99, 0.12), h=0.014)
    b.bolts_line("bolt", (-mw + 0.07, y0 + 0.0, gz - mh / 2 + 0.1), (mw - 0.07, y0 + 0.0, gz - mh / 2 + 0.1),
                 max(4, int(mw * 2 / 0.14)), r=0.02, axis=(0, 0.99, 0.12), h=0.014)
    b.box("steel", (0, y0 - md / 2, gz + mh / 2 + 0.02), (mw * 2 + 0.04, md + 0.06, 0.04), bev=0.01)
    b.hazard_band("haz_y", "haz_k", (-mw + 0.04, y0 - md / 2, gz + mh / 2 + 0.045),
                  (mw - 0.04, y0 - md / 2, gz + mh / 2 + 0.045), width=0.08, th=0.008, normal="z")
    b.label("blindage frontal")
    # faisceaux
    for x in P["guns"]:
        gun(b, x, y0, gz, dict(G_, feed=1 if x > 0 else -1))
    if len(P["guns"]) >= 2:
        b.label("canons jumelés")
    b.label("refroidissement des canons")
    # tambours-chargeurs et bandes de cartouches
    dr, dL = P["drum"]
    for s in P["drums"]:
        xd = s * (Rh + dr * 0.72)
        zd = zb + dr + 0.04
        b.box("plate2", (s * (Rh + 0.02), 0.0, zb + 0.12), (dr * 0.9, dL * 0.8, 0.24), bev=0.012)
        xg = P["guns"][0 if s < 0 else -1]
        drum_mag(b, (xd, 0.0, zd), dr, dL, (xg + s * G_["rec_w"] / 2, y0 - G_["rec_L"] * 0.45, gz))
        b.ammo_belt("case", "dark", [(xd - s * dr * 0.3, -dL * 0.2, zd + dr * 0.85), (s * (rt + 0.05), -0.15, zt + 0.1),
                                     (xg + s * G_["rec_w"] * 0.3, y0 - G_["rec_L"] * 0.7, gz + G_["rec_h"] / 2 + 0.02)],
                    w=0.1)
    b.label("alimentation en munitions")
    if lv >= 21:
        b.label("chargeur automatique")
    # bustle arrière : coffre, radiateurs à ailettes, grille
    bw, bd, bh = P["bustle"]
    yb = -Rh * 0.8 - bd / 2
    b.box("plate2", (0, yb, zb + bh / 2), (bw, bd, bh), bev=0.025)
    b.plates_face("plate", (0, yb - bd / 2, zb + bh / 2), (1, 0, 0), (0, 0, 1), max(1, int(bw / PLATE_W)),
                  max(1, int(bh / 0.34)), bw - 0.04, bh - 0.04, th=0.026, bolt_mat="bolt", tones=TONES)
    nr = P["radiators"]
    for k in range(nr):
        xr = -bw / 2 + (k + 0.5) * bw / nr
        b.fins("steel", (xr, yb, zb + bh), "x", bd - 0.08, 0.16, max(3, int(bw / nr / 0.07) - 1), pitch=0.065,
               th=0.03, base_mat="plate2")
    b.vent_face("body", "steel", "glow" if lv >= 21 else "dark", (0, yb - bd / 2 - 0.03, zb + bh * 0.45), (1, 0, 0),
                (0, 0, 1), min(0.5, bw * 0.3), bh * 0.5, max(3, int(bh * 0.5 / 0.075)))
    if nr >= 2:
        b.label("radiateurs")
    # cellules d'énergie en rang sur le toit arrière
    nc = P["cells"]
    for k in range(nc):
        xc = (k - (nc - 1) / 2) * 0.3
        capacitor_cell(b, (xc, -rt * 0.62, zt + 0.04), 0.11 if lv < 29 else 0.12, 0.3 if lv < 29 else 0.36)
    if nc:
        b.label("générateur ou condensateur")
    if nc >= 4:
        b.label("réserve d'énergie visible")
    # tourelles secondaires, viseur
    if P["secondaries"] == "tambours":
        # ère V : une tourelle secondaire sur chaque tambour-chargeur, bien visible sur les flancs
        for s in P["drums"]:
            xd = s * (Rh + P["drum"][0] * 0.72)
            ztop = zb + 2 * P["drum"][0] + 0.04
            b.box("plate2", (xd, -0.12, ztop + 0.02), (0.36, 0.5, 0.08), bev=0.01)
            secondary_turret(b, (xd, -0.12, ztop + 0.06), 1.15)
        secs = P["drums"]
    else:
        secs = P["secondaries"]
        for (sx, sy) in secs:
            secondary_turret(b, (sx, sy, zt + 0.04), 1.0)
    if len(secs) == 1:
        b.label("tourelle secondaire")
    elif len(secs) >= 2:
        b.label("tourelles secondaires")
    if P["sensor"] == "masque":
        sensor(b, (0.0, y0 - P["mantlet"][1] / 2, gz + P["mantlet"][2] / 2 + 0.04), 0.17)
        b.label("viseur")
    elif P["sensor"]:
        sensor(b, (P["sensor"][0], P["sensor"][1], zt + 0.04), 0.2)
        b.label("viseur")
    # isolateurs céramique et éclateur (époque 6 : électricité)
    if P["insulators"]:
        for s in (-1, 1):
            zz = zt + 0.04
            for kk in range(4):
                b.cyl("accent", (s * 0.26, -0.36, zz + 0.035), 0.06 if kk % 2 == 0 else 0.045, 0.07, n=14, bev=0.008)
                zz += 0.07
            b.cyl("copper", (s * 0.26, -0.36, zz + 0.05), 0.018, 0.1, n=8, bev=0)
            b.sphere("copper", (s * 0.2, -0.36, zz + 0.1), 0.03, n=10, m=6)
        b.box("glow", (0, -0.36, zt + 0.04 + 0.28 + 0.1), (0.24, 0.04, 0.05), bev=0)
        b.light((0, -0.36, zt + 0.5), (1, 1, 1), 1.0)
    # blindage espacé (plaques multiples) sur les flancs
    if P["skirt"]:
        armor_skirt(b, Rh, zb + 0.06, zh - 0.02, -0.75, 0.45, 3)
        armor_skirt(b, Rh, zb + 0.06, zh - 0.02, math.pi - 0.45, math.pi + 0.75, 3)
        armor_skirt(b, Rh, zb + 0.06, zh - 0.02, -math.pi / 2 - 0.55, -math.pi / 2 + 0.55, 3, mat="plate")
        b.label("blindage à plaques multiples")
    # gaines de refroidissement bustle -> chemises, câbles le long du toit
    for k in range(P["hoses"]):
        s = -1 if k == 0 else 1
        x = P["guns"][0 if s < 0 else -1]
        hose_arc(b, (s * bw * 0.36, yb + 0.05, zb + bh + 0.1), (x + s * (G_["ring_r"] + G_["br"] + 0.06), y0 + 0.4, gz),
                 0.4 if lv >= 29 else 0.32, 0.05 if lv >= 29 else 0.042, pitch=0.065)
    if lv >= 21:
        for s in (-1, 1):
            b.cable("rubber", (s * rt * 0.88, -rt * 0.35, zt + 0.07), (s * rt * 0.62, y0 - 0.25, zt + 0.07), sag=-0.03,
                    r=0.022)
            b.cable("cable_r", (s * rt * 0.8, -rt * 0.35, zt + 0.07), (s * rt * 0.55, y0 - 0.25, zt + 0.07), sag=-0.03,
                    r=0.02)
        b.label("câblage et conduits")
    # cœur d'énergie de la tête (ère IV et V) : puits rond grillagé sur le toit, lueur d'époque sous les barreaux
    if lv >= 21:
        rc = 0.22 if lv < 29 else 0.32
        cx, cy = 0.0, -rt * 0.18
        b.cyl("plate2", (cx, cy, zt + 0.07), rc + 0.08, 0.07, n=32, bev=0.01)
        b.cyl("steel", (cx, cy, zt + 0.11), rc + 0.03, 0.02, n=32, bev=0.004)
        b.cyl("glow", (cx, cy, zt + 0.1), rc, 0.012, n=28, bev=0)
        for k in range(5):
            xx = cx - rc + (k + 1) * 2 * rc / 6
            hw = math.sqrt(max(0.0, rc * rc - (xx - cx) ** 2))
            b.box("grille", (xx, cy, zt + 0.12), (0.03, 2 * hw, 0.025), bev=0)
        nbo = 12
        for i in range(nbo):
            a = TAU * i / nbo
            b.bolt("bolt", (cx + math.cos(a) * (rc + 0.055), cy + math.sin(a) * (rc + 0.055), zt + 0.105), r=0.016)
        b.light((cx, cy, zt + 0.4), (1, 1, 1), 1.0)
    # trappe ronde du chef de pièce, voyants
    hx_, hy_ = (-rt * 0.3, -rt * 0.15) if lv < 21 else (-rt * 0.42, rt * 0.05)
    b.cyl("plate", (hx_, hy_, zt + 0.07), 0.13, 0.05, n=22, bev=0.008)
    b.cyl("dark", (hx_, hy_, zt + 0.1), 0.02, 0.02, n=8, bev=0)
    b.box("steel", (hx_, hy_ + 0.08, zt + 0.11), (0.12, 0.025, 0.02), bev=0)
    b.lamp("amber", "plate2", (bw * 0.35, yb - bd / 2 - 0.01, zb + bh * 0.82), (0.07, 0.04), axis="-y")
    b.light((0, yb - bd / 2 - 0.2, zb + bh * 0.5), (1, 1, 1), 1.0)


# ------------------------------------------------------------------------------------------------
# Socles
# ------------------------------------------------------------------------------------------------
def crate_stack(b, c, size, tiers=2, rot=0.0):
    """Pile de caisses de munitions (tiers étages, la seconde légèrement décalée et tournée)."""
    x, y = c
    sx, sy, sz = size
    crate(b, (x, y, 0.0), (sx, sy, sz), rot=rot)
    if tiers >= 2:
        crate(b, (x + 0.03, y + 0.05, sz), (sx * 0.86, sy * 0.86, sz * 0.85), rot=rot + 0.12, hazard=False)


def feed_station(b, c, L, d, h):
    """Poste d'alimentation bas (avant) : caisson olive à trappes boulonnées, fente de bande, cartouches visibles,
    bande de danger, poignées. Bas : ne masque pas l'affût."""
    x, y = c
    b.box("plate2", (x, y, h / 2), (L, d, h), bev=0.02)
    n = max(2, int(L / PLATE_W))
    w = L / n
    for i in range(n):
        cx = x - L / 2 + (i + 0.5) * w
        b.box("olive" if i % 3 else "plate", (cx, y, h + 0.015), (w - 0.04, d - 0.06, 0.03), bev=0.01)
        b.bolts_rect("bolt", cx - w / 2 + 0.02, cx + w / 2 - 0.02, y - d / 2 + 0.03, y + d / 2 - 0.03, h + 0.03,
                     r=0.017, inset=0.04)
        b.box("dark", (cx, y - d * 0.2, h + 0.035), (w * 0.35, 0.03, 0.02), bev=0)
    b.box("dark", (x, y + d * 0.1, h + 0.032), (L * 0.6, 0.08, 0.012), bev=0)
    for i in range(int(L * 0.6 / 0.045)):
        b.cyl("case", (x - L * 0.3 + (i + 0.5) * 0.045, y + d * 0.1, h + 0.04), 0.017, 0.07, axis="y", n=6, bev=0)
    b.hazard_band("haz_y", "haz_k", (x - L / 2 + 0.05, y - d / 2 - 0.004, h * 0.5), (x + L / 2 - 0.05, y - d / 2 - 0.004,
                  h * 0.5), width=h * 0.4, th=0.01, normal="-y")
    b.bolts_line("bolt", (x - L / 2 + 0.06, y - d / 2 - 0.006, h * 0.15), (x + L / 2 - 0.06, y - d / 2 - 0.006, h * 0.15),
                 max(3, int(L / 0.15)), r=0.017, axis="-y", h=0.012)


def junction_box(b, c, size):
    """Armoire électrique : caisson, porte boulonnée, ailettes, voyant ambre, presse-étoupes et câbles au sol."""
    x, y = c
    sx, sy, sz = size
    b.box("plate2", (x, y, sz / 2), (sx, sy, sz), bev=0.02)
    b.box("olive", (x, y - sy / 2 - 0.012, sz * 0.52), (sx - 0.08, 0.025, sz * 0.8), bev=0.01)
    b.bolts_rect("bolt", x - sx / 2 + 0.04, x + sx / 2 - 0.04, y - sy / 2, y - sy / 2, sz * 0.52, r=0.016, inset=0.0)
    for zz in (0.25, 0.75):
        b.cyl("steel", (x + sx / 2 - 0.06, y - sy / 2 - 0.03, sz * zz), 0.02, 0.07, n=8, bev=0)
    b.lamp("amber", "plate2", (x - sx * 0.25, y - sy / 2 - 0.03, sz * 0.85), (0.05, 0.035), axis="-y")
    b.fins("steel", (x, y, sz), "x", sy - 0.06, 0.08, max(3, int(sx / 0.07) - 1), pitch=0.065, th=0.028)


def socle_11(b):
    """Époque 6 (Électricité), 3×3 : affût à 2 gradins sur bordure ; à l'arrière, transformateur à isolateurs
    céramique et éclateur (arc cyan), cellule, radiateur ; flanc est, caisses de munitions ; flanc ouest, pompe et
    conduite ; avant bas, poste d'alimentation et piles de caisses ; gaine annelée."""
    side, hx, hy = 3, 1.5, 1.5 * TD
    apron(b, side, cf=0.6, cb=0.4, inset=0.1)
    curb(b, 1.22, w=0.1, h=0.06)
    mount(b, 1.22, 0.5, [(1.22, 0.26), (1.13, 0.24)], 14, vents=3, glow_vents=1, lamps=4)
    hoist(b, -1.9, 1.22, 0.5, w=0.3, depth=0.26)
    b.label("socle pivotant")
    # arrière gauche : transformateur (caisson à ailettes, tôles olive, isolateurs)
    x, y = -0.9, 1.62
    b.box("plate2", (x, y, 0.33), (0.68, 0.62, 0.62), bev=0.02)
    b.plates_face("olive", (x, y - 0.31, 0.33), (1, 0, 0), (0, 0, 1), 2, 2, 0.64, 0.58, th=0.022, bolt_mat="bolt",
                  tones=("olive", "olive", "plate"))
    b.fins("steel", (x - 0.36, y, 0.05), "y", 0.1, 0.5, 8, pitch=0.07, th=0.03)
    for k in range(2):
        xx = x - 0.18 + k * 0.36
        zz = 0.64
        for kk in range(4):
            b.cyl("accent", (xx, y + 0.05, zz + 0.035), 0.06 if kk % 2 == 0 else 0.045, 0.07, n=14, bev=0.008)
            zz += 0.07
        b.cyl("copper", (xx, y + 0.05, zz + 0.05), 0.018, 0.1, n=8, bev=0)
    b.box("glow", (x, y + 0.05, 0.98), (0.2, 0.04, 0.05), bev=0)
    b.light((x, y - 0.1, 1.0), (1, 1, 1), 1.0)
    b.label("générateur ou condensateur")
    # arrière droit : cellule et radiateur
    capacitor(b, (0.98, 1.72, 0.0), 0.24, 0.62, glow_slits=2)
    b.light((0.98, 1.4, 0.4), (1, 1, 1), 1.0)
    radiator_block(b, (0.15, 1.6, 0.0), (0.62, 0.5, 0.5), along="x")
    pipe_run(b, (-0.4, 1.98), (0.6, 1.98), 0.035, 0.14, flanges=2, valve=False, supports=2)
    # flanc est : caisses de munitions
    crate_stack(b, (1.26, 0.35), (0.4, 0.62, 0.3), tiers=2)
    crate(b, (1.28, -0.55, 0.0), (0.36, 0.5, 0.26))
    # flanc ouest : pompe, conduite
    pump(b, (-1.28, 0.1, 0.0), 0.14, 0.26)
    junction_box(b, (-1.28, -0.75), (0.34, 0.36, 0.34))
    crate(b, (1.3, -1.2, 0.0), (0.3, 0.36, 0.22), rot=0.08)
    pipe_run(b, (-1.42, -1.3), (-1.42, 1.15), 0.04, 0.2, flanges=3, valve=False, supports=2)
    # avant : poste d'alimentation, piles de caisses
    feed_station(b, (0.0, -1.68), 0.9, 0.46, 0.22)
    crate_stack(b, (-1.08, -1.72), (0.44, 0.38, 0.24), tiers=1)
    crate_stack(b, (1.08, -1.72), (0.44, 0.38, 0.24), tiers=1)
    lamp_post(b, (-0.6, -1.45, 0.0), 0.16)
    lamp_post(b, (0.6, -1.45, 0.0), 0.16)
    pump(b, (1.0, 1.15, 0.0), 0.12, 0.2)
    big_hose(b, [(-0.6, 1.35, 0.4), (-1.35, 1.0, 0.3), (-1.55, 0.6, 0.22)], 0.06)
    return {}


def socle_21(b):
    """Époque 11, 5×5 : affût à 3 gradins sur bordure ; à l'arrière, générateur bobiné, deux cellules (réserve),
    radiateur ; flanc ouest, deux réservoirs verticaux, pompe, armoire ; flanc est, magasin de munitions et
    goulotte ; avant bas, poste d'alimentation, réservoirs couchés, piles de caisses ; gaines qui débordent."""
    side, hx, hy = 5, 2.5, 2.5 * TD
    apron(b, side, cf=1.0, cb=0.6, inset=0.12)
    curb(b, 1.95, w=0.14, h=0.07)
    mount(b, 1.95, 0.8, [(1.95, 0.3), (1.86, 0.28), (1.78, 0.22)], 22, vents=5, glow_vents=3, lamps=10)
    for a in (-2.16, -0.99):
        hoist(b, a, 1.95, 0.8, w=0.36)
    b.label("socle pivotant")
    # arrière gauche : générateur bobiné (axe x)
    tb = generator(b, (-1.35, 2.85, 0.0), 1.55, 0.36, axis="x")
    b.label("générateur")
    junction_box(b, (-2.15, 3.25), (0.4, 0.45, 0.5))
    # arrière droit : 2 cellules
    for xx in (1.05, 1.75):
        capacitor(b, (xx, 2.95, 0.0), 0.27, 0.95, glow_slits=2)
        b.light((xx, 2.6, 0.6), (1, 1, 1), 1.0)
    b.label("réserve d'énergie")
    # arrière centre : radiateur
    radiator_block(b, (-0.05, 2.78, 0.0), (0.95, 0.8, 0.85), along="x", glow=True)
    pipe_run(b, (-0.7, 3.38), (0.7, 3.38), 0.045, 0.2, flanges=3, valve=True, supports=2)
    pump(b, (1.4, 2.2, 0.0), 0.15, 0.3)
    pump(b, (-1.6, 1.85, 0.0), 0.15, 0.3)
    b.label("radiateurs")
    # flanc ouest : réservoirs verticaux, pompe, armoire
    for yy in (1.6, 0.6):
        tank_v(b, (-2.2, yy, 0.0), 0.29, 0.82)
    pump(b, (-2.2, -0.45, 0.0), 0.17, 0.32)
    junction_box(b, (-2.12, -1.35), (0.4, 0.42, 0.42))
    crate(b, (2.16, -1.38, 0.0), (0.44, 0.5, 0.3), rot=0.06)
    pipe_run(b, (-2.48, -1.6), (-2.48, 2.1), 0.05, 0.28, flanges=4, valve=True, supports=3)
    # flanc est : magasin de munitions et goulotte
    ammo_magazine(b, (2.12, 0.9, 0.0), (0.62, 1.25, 0.72))
    conveyor(b, (1.9, 0.2, 0.55), (1.72, -0.3, 0.75), 0.2)
    crate_stack(b, (2.12, -0.45), (0.5, 0.55, 0.3), tiers=2)
    b.label("alimentation en munitions")
    # avant : réservoirs couchés aux coins, piles de caisses, poste d'alimentation, collecteur, bornes
    for s in (-1, 1):
        tank_h(b, (s * 1.75, -2.15, 0.0), 0.2, 1.0)
        crate_stack(b, (s * 1.9, -3.0), (0.55, 0.42, 0.28), tiers=2, rot=s * 0.08)
        crate(b, (s * 1.12, -2.95, 0.0), (0.48, 0.5, 0.26), rot=-s * 0.05)
    feed_station(b, (0.0, -2.75), 1.3, 0.5, 0.26)
    b.push(None, (0, 0, 0.05))
    floor_conduit(b, -1.3, 1.3, -2.38, glow=True, w=0.16)
    b.pop()
    pipe_run(b, (-0.85, -3.38), (0.85, -3.38), 0.045, 0.16, flanges=4, valve=True, supports=3)
    for xx in (-0.85, 0.85):
        lamp_post(b, (xx * 1.05, -2.3, 0.0), 0.2, glow="glow")
    # gaines annelées (cœur -> affût), qui débordent du contour
    big_hose(b, [(-0.6, 2.75, 0.55), (-1.4, 2.3, 0.4), (-2.5, 2.15, 0.3), (-2.68, 1.2, 0.24), (-2.66, -0.2, 0.22),
                 (-2.4, -1.25, 0.2)], 0.085)
    big_hose(b, [(0.75, 2.75, 0.5), (1.6, 2.2, 0.3), (2.6, 1.9, 0.22), (2.66, 0.0, 0.2), (2.55, -1.1, 0.18)], 0.075)
    cable_bundle(b, (tb[0], tb[1], tb[2] + 0.05), (-0.6, 1.95, 0.85), sag=0.12, n=3)
    b.label("câblage et conduits")
    return {}


def tank_v(b, c, r, h):
    """Réservoir vertical de fluide de refroidissement : virole peinte olive, cerclages, dôme, échelle, manomètre."""
    x, y, z0 = c
    b.cyl("plate2", (x, y, z0 + 0.05), r + 0.06, 0.1, n=28, bev=0.01)
    b.cyl("olive", (x, y, z0 + 0.1 + h / 2), r, h, n=32, bev=0.012)
    for t in (0.1, 0.4, 0.7, 0.95):
        b.cyl("steel" if t != 0.4 else "brass", (x, y, z0 + 0.1 + h * t), r + 0.014, 0.035, n=32, bev=0.005)
    b.sphere("plate", (x, y, z0 + 0.1 + h), r, n=24, m=10, scale=(1, 1, 0.4))
    b.cyl("steel", (x, y, z0 + 0.1 + h + r * 0.4), 0.06, 0.06, n=12, bev=0.005)
    for s in (-1, 1):
        b.box("body", (x + s * 0.06, y - r - 0.05, z0 + 0.1 + h / 2), (0.025, 0.025, h), bev=0)
    for k in range(int(h / 0.12)):
        b.box("body", (x, y - r - 0.05, z0 + 0.18 + k * 0.12), (0.14, 0.022, 0.022), bev=0)
    b.cyl("brass", (x + r * 0.7, y - r * 0.7, z0 + 0.1 + h * 0.6), 0.05, 0.02, axis=(0.7, -0.7, 0), n=14, bev=0)
    b.hazard_band("haz_y", "haz_k", (x - r * 0.6, y - r - 0.004, z0 + 0.2), (x + r * 0.6, y - r - 0.004, z0 + 0.2),
                  width=0.08, th=0.008, normal="-y")


def socle_29(b, piece=False):
    """Époque 15 (Légende), 6×6 : affût à 4 gradins sur bordure ; à l'arrière, CUVE-CŒUR sphérique (hublots),
    batterie de radiateurs, générateur et 2 cellules, armoires ; flanc ouest, réservoirs, pompes, armoire ; flanc
    est, grand magasin de munitions, goulotte et caisses ; avant bas, réservoirs couchés, piles de caisses, poste
    d'alimentation, collecteur, bornes ; grosses gaines de cuivre en boucle hors du contour. piece=True : niveau 30,
    deux lance-missiles aux coins avant (à la place des piles de caisses d'angle)."""
    side, hx, hy = 6, 3.0, 3.0 * TD
    apron(b, side, cf=1.2, cb=0.7, inset=0.14)
    curb(b, 2.42, w=0.16, h=0.08)
    mount(b, 2.42, 1.0, [(2.42, 0.3), (2.33, 0.28), (2.25, 0.24), (2.18, 0.18)], 28, vents=7, glow_vents=4, lamps=13)
    for a in (-2.27, -1.71, -1.43, -0.87):
        hoist(b, a, 2.42, 1.0)
    b.label("socle pivotant")
    # arrière gauche : cuve-cœur
    core_vessel(b, (-1.95, 3.25, 0.88), 0.78, glow_ports=7)
    b.label("réserve d'énergie visible")
    for yy in (3.55, 2.85):
        capacitor(b, (-0.85, yy + 0.2, 0.0), 0.2, 0.75, glow_slits=1)
    b.light((-0.85, 2.7, 0.5), (1, 1, 1), 1.0)
    # arrière centre : batterie de radiateurs
    radiator_block(b, (0.15, 3.2, 0.0), (1.15, 0.95, 1.0), along="x", glow=True)
    pipe_run(b, (-0.5, 3.95), (0.75, 3.95), 0.05, 0.22, flanges=3, valve=True, supports=2)
    pump(b, (1.75, 2.1, 0.0), 0.17, 0.34)
    pump(b, (-1.75, 2.05, 0.0), 0.17, 0.34)
    junction_box(b, (-2.15, 1.35), (0.34, 0.4, 0.45))
    b.label("radiateurs")
    # arrière droit : générateur + 2 cellules derrière, armoire
    for xx in (1.6, 2.35):
        capacitor(b, (xx, 3.85, 0.0), 0.27, 1.1, glow_slits=2)
        b.light((xx, 3.5, 0.6), (1, 1, 1), 1.0)
    tb = generator(b, (2.0, 2.95, 0.0), 1.55, 0.36, axis="x")
    b.label("générateur")
    junction_box(b, (1.0, 3.7), (0.3, 0.5, 0.6))
    # flanc ouest : réservoirs, pompes, armoire
    for yy in (1.8, 0.85):
        tank_v(b, (-2.66, yy, 0.0), 0.3, 1.0)
    for yy in (-0.2, -1.1):
        pump(b, (-2.66, yy, 0.0), 0.17, 0.32)
    junction_box(b, (-2.62, -1.95), (0.42, 0.4, 0.45))
    pipe_run(b, (-2.94, -2.5), (-2.94, 2.4), 0.055, 0.3, flanges=5, valve=True, supports=4)
    # flanc est : grand magasin de munitions, goulotte, caisses
    ammo_magazine(b, (2.62, 1.0, 0.0), (0.66, 1.5, 0.85))
    conveyor(b, (2.4, 0.15, 0.65), (2.2, -0.35, 0.95), 0.22)
    crate_stack(b, (2.62, -0.8), (0.6, 0.55, 0.36), tiers=2)
    crate(b, (2.62, -1.7, 0.0), (0.55, 0.5, 0.32))
    b.label("alimentation en munitions")
    # avant : réservoirs couchés, piles de caisses (coins), poste d'alimentation, collecteur, bornes
    for s in (-1, 1):
        tank_h(b, (s * 2.05, -2.62, 0.0), 0.22, 1.35)
        if not piece:
            crate_stack(b, (s * 2.3, -3.6), (0.62, 0.48, 0.32), tiers=2, rot=s * 0.06)
        crate_stack(b, (s * 1.38, -3.4), (0.55, 0.62, 0.28), tiers=1, rot=-s * 0.05)
    feed_station(b, (0.0, -3.25), 1.7, 0.56, 0.3)
    b.push(None, (0, 0, 0.05))
    floor_conduit(b, -1.32, 1.32, -2.86, glow=True, w=0.18)
    b.pop()
    pipe_run(b, (-1.0, -3.82), (1.0, -3.82), 0.05, 0.17, flanges=5, valve=True, supports=3)
    for xx in (-1.05, 1.05):
        lamp_post(b, (xx, -2.7, 0.0), 0.22, glow="glow")
    # gaines annelées
    big_hose(b, [(-1.3, 3.0, 0.75), (-2.3, 2.45, 0.5), (-3.15, 2.1, 0.32), (-3.18, 0.2, 0.26), (-3.05, -1.6, 0.22),
                 (-2.6, -2.3, 0.2)], 0.1)
    big_hose(b, [(-1.2, 3.55, 0.95), (-0.55, 2.9, 1.1), (-0.25, 2.55, 0.95)], 0.09)
    big_hose(b, [(1.2, 2.6, 0.5), (2.1, 2.2, 0.32), (3.12, 2.0, 0.24), (3.18, 0.1, 0.22), (3.05, -1.7, 0.2),
                 (2.6, -2.35, 0.18)], 0.09)
    cable_bundle(b, (tb[0], tb[1], tb[2] + 0.05), (0.9, 2.35, 1.0), sag=0.15, n=4)
    b.label("câblage et conduits")
    if piece:
        for s in (-1, 1):
            missile_rack(b, (s * 2.3, -3.5), s * 0.3)
    return {}


SOCLES = {11: socle_11, 21: socle_21, 29: socle_29, 30: lambda b: socle_29(b, piece=True)}


def build(variant):
    """Construit la géométrie d'une variante ; renvoie (constructeur, angle de rotation de la tête)."""
    v = VARIANTS[variant]
    lv = v["level"]
    b = G.B(seed=lv)
    if v["part"] == "socle":
        SOCLES[lv](b)
        return b, 0.0
    head(b, 29 if lv == 30 else lv)
    return b, DIR_ANGLE[v["dir"]]


def systems(level):
    """Inventaire des systèmes fonctionnels (socle + tête) du niveau (labels distincts, comptés une fois)."""
    lv = 29 if level == 30 else level
    b1 = G.B()
    SOCLES[level if level in SOCLES else lv](b1)
    head(b1, lv)
    s = list(b1.systems)
    if level == 30:
        s.append("lance-missiles (pièce du niveau 30)")
    return s
