"""Four en acier, niveaux 2 à 30 (lot V3, famille « furnace », phase 1) : modélisation paramétrique.

Fichier de pièce au format du pipeline V0 (tools/render/README.md) : PIECE (métadonnées, lisibles sans
bpy) et build(S, C, variant). Une variante par niveau : « n02 » à « n30 ».
- n02 : la pièce d'époque 1 seule, posée DERRIÈRE le sprite vanilla du four (masque au pixel par son
  alpha, comme la variante « four » de la cheminée V0) ;
- niveau impair 2e-1 : silhouette complète de l'époque e ;
- niveau pair 2e : la même silhouette + la pièce de l'époque (rendu complet en phase 1 ; en phase 2, la
  pièce deviendra une couche séparée, voir besoins du pipeline).
Règles : docs/DESIGN_EPOQUES.md (§1.4 enveloppes, §1.5 palette, §1.6 lumière, §2.7, §4, §5) ; cibles
chiffrées et choix de la famille : params.py. Identité invariante du four : foyer compact, BOUCHE
LUMINEUSE au sud, CHEMINÉE à l'arrière droit d'où sort la fumée.

Repère : positions en tuiles de JEU (x est, y SUD) converties par geo.G ; z et rayons en unités Blender.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import params as PRM  # noqa: E402

VANILLA_MASK = {
    "hr": {"file": "steel-furnace/hr-steel-furnace.png", "shift": (-0.0390625, 0.0625)},
    "lr": {"file": "steel-furnace/steel-furnace.png", "shift": (-0.046875, 0.046875)},
}

# --- points clés par époque (Python pur : relus par le pilote, les mesures et le manifeste) ---------
# chimney : (x, y_sol, z_haut) du centre du haut de la cheminée -> sortie de fumée
# emit    : zones émissives [(x, y_sol, z, couleur)] -> sources du halo et fenêtres de la couche halo
KEY = {
    1: {"chimney": [(0.70, -1.20, None), (0.27, -0.60, 0.86)],
        "emit": []},
    2: {"chimney": [(0.44, -0.50, 1.03)],
        "emit": [(-0.14, 0.95, 0.30, PRM.FIRE)]},
    3: {"chimney": [(0.55, -0.50, 1.16)],
        "emit": [(-0.25, 0.95, 0.17, PRM.FIRE), (-0.25, 0.44, 0.62, "#FFC060")]},
    4: {"chimney": [(0.55, -0.55, 1.27)],
        "emit": [(-0.30, 0.90, 0.66, PRM.FIRE), (0.62, 0.95, 0.40, "#FF8C1A")]},
    5: {"chimney": [(0.48, -0.52, 1.44)],
        "emit": [(-0.14, 0.95, 0.20, "#FF4A10"), (-0.14, 0.55, 0.60, "#FF4A10")]},
    6: {"chimney": [(0.62, -0.55, 1.55)],
        "emit": [(-0.15, 0.95, 0.30, PRM.FIRE), (-0.15, 0.10, 1.00, "#60D0FF")]},
    7: {"chimney": [(0.60, -0.55, 1.66)],
        "emit": [(-0.10, 0.95, 0.15, "#B070FF"), (-0.10, 0.15, 1.00, "#B070FF")]},
    8: {"chimney": [(0.62, -0.55, 1.95)],
        "emit": [(-0.15, 0.95, 0.12, "#A8FF3A"), (-0.15, 0.15, 0.70, "#A8FF3A")]},
    9: {"chimney": [(0.60, -0.50, 1.88)],
        "emit": [(-0.15, 0.95, 0.20, "#5CFF4A"), (-0.15, 0.40, 0.85, "#5CFF4A")]},
    10: {"chimney": [(0.66, -0.62, 2.02)],
         "emit": [(-0.12, 0.45, 0.80, PRM.FIRE), (-0.12, 0.30, 1.30, "#3AA8FF")]},
    11: {"chimney": [(0.62, -0.62, 2.16)],
         "emit": [(-0.12, 0.35, 0.80, PRM.FIRE), (-0.12, 0.20, 1.40, "#BFE6FF")]},
    12: {"chimney": [(0.62, -0.62, 2.25)],
         "emit": [(-0.12, 0.40, 1.05, PRM.FIRE), (-0.12, 0.12, 0.55, "#4AF0FF")]},
    13: {"chimney": [(0.62, -0.62, 2.42)],
         "emit": [(-0.12, 0.45, 1.45, "#FF9A3A"), (-0.12, 0.08, 1.45, "#FF4FD8")]},
    14: {"chimney": [(0.66, -0.62, 2.53)],
         "emit": [(-0.12, 0.10, 1.40, "#FFF2C0"), (0.66, -0.62, 2.62, "#FF2A2A")]},
    15: {"chimney": [(0.45, -0.45, 2.82)],
         "emit": [(-0.12, 0.10, 1.15, "#FFF2C0"), (-0.12, 0.10, 0.20, "#FFF2C0")]},
}


def _variants():
    v = {}
    for n in PRM.RENDERED:
        e = PRM.epoch_of(n)
        wins = [(x, y, z if z is not None else 0.0, 0.45, 1.0) for (x, y, z, _c) in KEY[e]["emit"]]
        d = {"dest": "levels/furnace/n%02d" % n, "anchor_tiles": (0.0, 0.0), "level": n, "epoch": e,
             "halo": PRM.halo_windows(n, wins), "margin_px": int(max(96, 64 * (1.55 + 0.05 * n - 0.4)))}
        if n == 2:
            d["mask"] = VANILLA_MASK
            d["halo"] = []
        v["n%02d" % n] = d
    return v


PIECE = {"name": "furnace", "variants": _variants(), "margin_px": 96,
         "halo": [{"at": (0.0, 0.85, 0.0), "r": (1.0, 2.0)}]}


# =================================================================================================
# Côté Blender
# =================================================================================================
class Kit:
    """Matériaux d'époque et raccourcis de modélisation."""

    def __init__(self, S, C, geo, n):
        self.S, self.C, self.g, self.n = S, C, geo, n
        self.e = PRM.epoch_of(n)
        self.pal = PRM.PALETTE[self.e]
        self._m = {}
        self.halo_scale = 0.4 + 0.6 * n / 30.0

    def metal(self, key, hexc=None, gain=2.2, rough=0.42, metallic=0.55, grain=0.22, rust=None, rust_amount=0.0,
              dirt=0.5, seed=0.0, grain_scale=55.0):
        name = "%s_%d" % (key, self.e)
        if name not in self._m:
            col = PRM.hex_lin(hexc or self.pal[key], gain)
            rc = PRM.hex_lin(rust, 1.0) if isinstance(rust, str) else rust
            self._m[name] = self.S.mat_metal(name, col, rough=rough, metallic=metallic, grain=grain,
                                             grain_scale=grain_scale, rust=rc, rust_amount=rust_amount, dirt=dirt,
                                             seed=seed + self.e)
        return self._m[name]

    def stone(self, key, hexc=None, gain=1.25, rough=0.85, grain=0.30, dirt=0.6, seed=0.0, rust=None, rust_amount=0.0):
        return self.metal(key, hexc, gain=gain, rough=rough, metallic=0.0, grain=grain, dirt=dirt, seed=seed,
                          grain_scale=35.0, rust=rust, rust_amount=rust_amount)

    def glossy(self, key, hexc=None, gain=1.0, rough=0.15, metallic=0.0):
        name = "%s_%d" % (key, self.e)
        if name not in self._m:
            self._m[name] = self.S.mat_metal(name, PRM.hex_lin(hexc or self.pal[key], gain), rough=rough,
                                             metallic=metallic, grain=0.06, grain_scale=20.0, dirt=0.3, seed=self.e)
        return self._m[name]

    def emit(self, key, hexc, strength=1.4):
        name = "emit_%s_%d" % (key, self.e)
        if name not in self._m:
            self._m[name] = self.S.mat_emissive(name, PRM.hex_lin(hexc), strength=strength)
        return self._m[name]

    def soot(self):
        if "soot" not in self._m:
            self._m["soot"] = self.S.mat_flat("suie_%d" % self.e, (0.012, 0.010, 0.009), rough=0.95)
        return self._m["soot"]

    def halo(self, x, y, z, hexc, w=6.0, name="halo"):
        col = PRM.hex_lin(hexc)
        m = max(col)
        col = tuple(c / m for c in col)
        self.g.halo(x, y, z, col, w * self.halo_scale, "%s_%d" % (name, len(self._m)))


def fire_mouth(k, x, y_face, z0, w, h, frame_mat, fire_hex=PRM.FIRE, depth=0.10, strength=1.6, arch=False):
    """Bouche lumineuse : cadre + foyer incandescent légèrement en retrait dans la face sud y_face."""
    g = k.g
    fire = k.emit("bouche", fire_hex, strength)
    yb = -y_face * g.K
    # foyer : plaque émissive juste devant la face (le cadre en saillie la fait paraître en retrait)
    k.S.box((w, 0.012, h), (x, yb - 0.008, z0 + h / 2), fire, "bouche_feu", bevel_w=0)
    t = 0.05
    yc = yb - depth / 2 + 0.02
    parts = [k.S.box((w + 2 * t, depth, t), (x, yc, z0 - t / 2), frame_mat, "cadre_b", bevel_w=0.008),
             k.S.box((t, depth, h), (x - w / 2 - t / 2, yc, z0 + h / 2), frame_mat, "cadre_g", bevel_w=0.008),
             k.S.box((t, depth, h), (x + w / 2 + t / 2, yc, z0 + h / 2), frame_mat, "cadre_d", bevel_w=0.008)]
    if arch:
        # arc : disque de cadre au ras de la face, disque de feu devant lui
        parts.append(k.S.cylinder(w / 2 + t, 0.02, (x, yb, z0 + h), frame_mat, "cadre_arc", verts=32,
                                  rot=(math.pi / 2, 0, 0), bevel_w=0.004))
        k.S.cylinder(w / 2, 0.012, (x, yb - 0.02, z0 + h), fire, "bouche_feu_arc", verts=32, rot=(math.pi / 2, 0, 0),
                     bevel_w=0)
    else:
        parts.append(k.S.box((w + 2 * t, depth, t), (x, yc, z0 + h + t / 2), frame_mat, "cadre_h", bevel_w=0.008))
    k.g.join(parts, "cadre_bouche")


def smoke_mouth(k, x, y, z, r, name="gueule"):
    """Intérieur sombre (suie) en haut d'une cheminée ronde ouverte."""
    k.g.cyl(x, y, z - 0.10, r, 0.10, name, k.soot(), verts=40, bevel_w=0, caps=True)


# -------------------------------------------------------------------------------------------------
# Époque 1 · Pionnier : pièce du niveau 2 (hotte et conduit en tôle rivetée, derrière le corps vanilla)
# -------------------------------------------------------------------------------------------------
def e1_piece(k):
    g, S = k.g, k.S
    tole = k.metal("fer", gain=2.6, rough=0.5, metallic=0.5, rust="#6B3A20", rust_amount=0.6, dirt=0.6, grain=0.28)
    band = k.metal("bande", "#3A3430", gain=2.0, rough=0.4, metallic=0.7, dirt=0.4)
    riv = k.metal("rivet", "#8A7A62", gain=2.4, rough=0.3, metallic=0.85, grain=0.1, dirt=0.2)
    # hotte : tronc de pyramide de tôle derrière la boucle de tuyaux vanilla ; seul ce qui DÉPASSE du
    # sprite vanilla reste visible (masque au pixel). Haut de la hotte : écran -1,19 ; chapeau : O 0,36.
    base = g.rect(-0.06, -0.60, 1.12, 0.50)
    top = g.rect(0.12, -0.60, 0.48, 0.20)
    g.frustum(base, 0.36, top, 0.70, "hotte", tole, bevel_w=0.012)
    for sx in (-1, 1):
        x0 = -0.06 + sx * 0.56
        x1 = 0.12 + sx * 0.24
        g.rivets_line(g.G(x0, -0.85, 0.38), g.G(x1, -0.70, 0.69), 6, 0.016, riv, "rivets_hotte_%d" % (sx + 1))
    g.rivets_line(g.G(-0.12, -0.70, 0.705), g.G(0.36, -0.70, 0.705), 7, 0.015, riv, "rivets_faite")
    g.box(0.12, -0.60, 0.68, 0.52, 0.30, 0.04, "bord_hotte", band, bevel_w=0.008)
    # conduit de fumée court en tôle rivetée, cerclage, chapeau chinois sur 3 pattes
    xc, yc, r = 0.27, -0.60, 0.115
    zt = KEY[1]["chimney"][1][2]
    g.cyl(xc, yc, 0.66, r, zt - 0.66, "conduit", tole, verts=40)
    g.cyl(xc, yc, 0.76, r + 0.012, 0.035, "cerclage", band, verts=40, bevel_w=0.004)
    g.rivet_ring_at(xc, yc, r + 0.004, zt - 0.03, 12, 0.012, riv, "rivets_conduit")
    smoke_mouth(k, xc, yc, zt, r - 0.015)
    legs = []
    p0 = g.G(xc, yc, 0)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.4
        legs.append(g.cyl_between((p0[0] + r * math.cos(a), p0[1] + r * math.sin(a), zt - 0.01),
                                  (p0[0] + (r + 0.02) * math.cos(a), p0[1] + (r + 0.02) * math.sin(a), zt + 0.06), 0.012,
                                  "patte_%d" % i, band, verts=8))
    g.join(legs, "pattes_chapeau")
    g.cyl(xc, yc, zt + 0.05, 0.17, 0.07, "chapeau", tole, verts=40, r2=0.02, bevel_w=0.004)


# -------------------------------------------------------------------------------------------------
# Époque 2 · Forge : four en briques cerclé d'acier, cheminée carrée, porte à volets ; pièce : soufflet
# -------------------------------------------------------------------------------------------------
def e2(k, even):
    g, S = k.g, k.S
    brick = k.stone("brique", gain=1.45, rough=0.85, grain=0.38, dirt=0.7, rust="#2A1A14", rust_amount=0.35)
    steel = k.metal("acier", gain=2.0, rough=0.38, metallic=0.65, rust="#5A3A26", rust_amount=0.25)
    strap = k.metal("cerclage", gain=2.6, rough=0.35, metallic=0.75, dirt=0.3)
    brass = k.metal("laiton", gain=2.0, rough=0.28, metallic=0.9, grain=0.1, dirt=0.2)
    x0, x1, y0, y1, h = -0.90, 0.62, -0.42, 0.90, 0.74
    g.prism(g.rect((x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0), 0.0, h, "corps_briques", brick, bevel_w=0.02)
    # cerclages horizontaux (bandes d'acier qui ceinturent le bloc)
    for z in (0.10, 0.58):
        g.prism(g.rect((x0 + x1) / 2, (y0 + y1) / 2, x1 - x0 + 0.04, y1 - y0 + 0.03), z, z + 0.06,
                "cerclage_%d" % int(z * 100), strap, bevel_w=0.008)
    # cornières aux 4 arêtes verticales
    for cx, cy in ((x0, y1), (x1, y1), (x0, y0), (x1, y0)):
        g.box(cx, cy, 0.0, 0.07, 0.07, h + 0.02, "corniere", steel, bevel_w=0.006)
    # chapeau d'acier et créneaux (merlons) sur l'avant et les côtés
    g.prism(g.rect((x0 + x1) / 2, (y0 + y1) / 2, x1 - x0 + 0.06, y1 - y0 + 0.05), h, h + 0.05, "chapeau", steel,
            bevel_w=0.01)
    merl = []
    for i in range(6):
        mx = x0 + 0.10 + i * (x1 - x0 - 0.20) / 5
        merl.append(g.box(mx, y1 - 0.02, h + 0.05, 0.13, 0.08, 0.12, "merlon_av_%d" % i, steel, bevel_w=0.006))
    for side, xs in (("g", x0 + 0.02), ("d", x1 - 0.02)):
        for j in range(4):
            my = y1 - 0.30 - j * 0.32
            merl.append(g.box(xs, my, h + 0.05, 0.08, 0.17, 0.12, "merlon_%s_%d" % (side, j), steel, bevel_w=0.006))
    g.join(merl, "creneaux")
    # boucliers plats boulonnés de part et d'autre de la porte
    for sx in (-1, 1):
        px = -0.14 + sx * 0.50
        S.box((0.26, 0.03, 0.46), (px, -y1 * g.K - 0.015, 0.36), steel, "bouclier_%d" % (sx + 1), bevel_w=0.008)
        g.rivets([(px + dx, -y1 * g.K - 0.035, z) for dx in (-0.09, 0.09) for z in (0.18, 0.54)], 0.018, brass,
                 "boulons_%d" % (sx + 1))
    # porte à volets ouverts et bouche de feu
    fire_mouth(k, -0.14, y1, 0.10, 0.40, 0.34, steel, PRM.FIRE, strength=1.5)
    for sx in (-1, 1):
        hinge = -0.14 + sx * 0.25
        v = S.box((0.22, 0.03, 0.36), (0, 0, 0), steel, "volet_%d" % (sx + 1), bevel_w=0.006)
        a = sx * math.radians(55)
        cxv = hinge + sx * 0.11 * math.cos(a)
        cyv = -y1 * g.K - 0.06 - 0.11 * abs(math.sin(a))
        v.location = (cxv, cyv, 0.28)
        v.rotation_euler = (0, 0, -a)
    # cheminée carrée en briques, cerclée, à l'arrière droit
    cx, cy, cw = 0.44, -0.50, 0.34
    zc = KEY[2]["chimney"][0][2]
    g.box(cx, cy, 0.0, cw, cw, zc - 0.10, "cheminee", brick, bevel_w=0.012)
    g.box(cx, cy, zc - 0.10, cw + 0.07, cw + 0.07, 0.10, "couronnement", steel, bevel_w=0.01)
    S.box((cw - 0.08, cw - 0.08, 0.01), g.G(cx, cy, zc + 0.003), k.soot(), "gueule", bevel_w=0)
    for z in (0.92, 0.66):
        g.box(cx, cy, z, cw + 0.03, cw + 0.03, 0.045, "cercle_chem_%d" % int(z * 100), strap, bevel_w=0.005)
    # volant d'inertie à manivelle sur le flanc droit (kit d'époque), bas
    S.cylinder(0.17, 0.04, g.G(x1 + 0.04, 0.45, 0.30), steel, "volant", verts=32, rot=(0, math.pi / 2, 0), bevel_w=0.006)
    k.halo(-0.14, 0.95, 0.27, PRM.FIRE, 7.0, "halo_bouche")
    if even:
        # soufflet de forge debout contre le flanc gauche, levier à contrepoids sur un poteau de bois
        wood = k.stone("bois", "#6B4F35", gain=1.3, rough=0.75, grain=0.4)
        leather = k.stone("cuir", "#4A3324", gain=1.2, rough=0.7, grain=0.25)
        # soufflet couché le long du flanc gauche (planches horizontales, vues de la caméra), sur tréteau ;
        # buse vers la paroi ; s'ouvre vers l'arrière
        xl, xr = -1.18, -0.94
        yb0, yb1 = -0.30, 0.55
        poly = [(xl + 0.03, yb1), (xr - 0.02, yb1), (xr, yb0 + 0.10), (xr - 0.04, yb0), (xl + 0.04, yb0), (xl, yb0 + 0.10)]
        for i, (lx, ly) in enumerate(((xl + 0.05, yb0 + 0.08), (xr - 0.05, yb0 + 0.08), (xl + 0.05, yb1 - 0.08),
                                      (xr - 0.05, yb1 - 0.08))):
            g.box(lx, ly, 0.0, 0.04, 0.04, 0.36, "treteau_%d" % i, wood, bevel_w=0.004)
        g.prism(poly, 0.36, 0.40, "planche_bas", wood, bevel_w=0.008)

        def lift(y):
            return 0.46 + 0.16 * (yb1 - y) / (yb1 - yb0)
        ring0 = [g.G(x, y, 0.40) for x, y in poly]
        ring1 = [g.G(x, y, lift(y) - 0.005) for x, y in poly]
        g.loft([ring0, ring1], "cuir", leather, True, True, None, 0.01)
        top0 = [g.G(x, y, lift(y)) for x, y in poly]
        top1 = [g.G(x, y, lift(y) + 0.04) for x, y in poly]
        g.loft([top0, top1], "planche_haut", wood, True, True, None, 0.008)
        for i, y in enumerate((0.05, 0.30)):
            g.rivets_line(g.G(xl + 0.06, y, lift(y) + 0.045), g.G(xr - 0.06, y, lift(y) + 0.045), 3, 0.016, brass,
                          "clous_%d" % i)
        g.pipe([g.G((xl + xr) / 2, yb1, 0.43), g.G((xl + xr) / 2, yb1 + 0.06, 0.40), g.G(x0 - 0.02, yb1 - 0.05, 0.30)],
               0.035, "buse", brass)
        # poteau, fléau et contrepoids de pierre (sous O 0,47)
        px = -1.06
        g.box(px, -0.48, 0.0, 0.07, 0.07, 0.80, "poteau_soufflet", wood, bevel_w=0.006)
        g.cyl_between(g.G(px, 0.15, lift(0.15) + 0.06), g.G(px, -0.62, 0.90), 0.03, "fleau", wood, verts=10)
        g.box(px, -0.64, 0.80, 0.18, 0.18, 0.16, "contrepoids", k.stone("pierre", "#5A5048", gain=1.3), bevel_w=0.03)


# -------------------------------------------------------------------------------------------------
# Époque 3 · Vapeur : haut-fourneau rond, cheminée ronde à collerette ; pièce : chaudière de récupération
# -------------------------------------------------------------------------------------------------
def e3(k, even):
    g, S = k.g, k.S
    fonte = k.metal("fonte", gain=2.4, rough=0.45, metallic=0.55, rust="#4A2A1A", rust_amount=0.3, dirt=0.6)
    cuivre = k.metal("cuivre", gain=1.9, rough=0.30, metallic=0.85, rust="#3E6A55", rust_amount=0.2, dirt=0.35)
    laiton = k.metal("laiton", gain=1.9, rough=0.28, metallic=0.9, grain=0.12, dirt=0.25)
    # creuset bas (foyer) devant, avec la bouche en arc
    g.prism(g.rect(-0.25, 0.48, 1.20, 0.88), 0.0, 0.34, "foyer", fonte, bevel_w=0.03)
    fire_mouth(k, -0.25, 0.92, 0.06, 0.34, 0.14, laiton, PRM.FIRE, strength=1.6, arch=True)
    # tour en fonte (profil de haut-fourneau : ventre puis cuve conique)
    tx, ty = -0.25, -0.05
    prof = [(0.60, 0.0), (0.66, 0.30), (0.71, 0.55), (0.66, 0.80), (0.54, 1.02), (0.44, 1.14), (0.40, 1.20)]
    g.lathe(prof, (tx, ty), "haut_fourneau", fonte, segs=48)
    for z, r in ((0.30, 0.675), (0.55, 0.72), (0.80, 0.67)):
        S.torus(r, 0.022, g.G(tx, ty, z), laiton, "cercle_%d" % int(z * 100))
        g.rivet_ring_at(tx, ty, r + 0.01, z + 0.05, 24, 0.012, laiton, "rivets_%d" % int(z * 100))
    # gueulard : couronne et lueur ambrée au sommet
    S.torus(0.40, 0.035, g.G(tx, ty, 1.20), laiton, "gueulard")
    k_amb = k.emit("ambre", "#FFC060", 1.3)
    g.cyl(tx, ty, 1.12, 0.36, 0.08, "gueulard_feu", k_amb, verts=40, bevel_w=0)
    # hublot ambré sur la face avant de la tour
    hy = ty + 0.70 / g.K
    S.cylinder(0.105, 0.03, g.G(tx, hy + 0.005, 0.62), k_amb, "hublot", verts=32, rot=(math.pi / 2, 0, 0), bevel_w=0)
    S.torus(0.115, 0.025, g.G(tx, hy + 0.012, 0.62), laiton, "hublot_cadre", rot=(math.pi / 2, 0, 0))
    # tuyère de cuivre : conduite d'air chaud depuis la base de la cheminée
    p = [g.G(0.55, -0.32, 0.30), g.G(0.50, -0.10, 0.48), g.G(0.30, 0.05, 0.52), g.G(0.08, 0.10, 0.50)]
    g.pipe(p, 0.055, "tuyere", cuivre)
    S.torus(0.70, 0.04, g.G(tx, ty, 0.45), cuivre, "couronne_vent")
    # manomètre sur sa colonne, avant droit
    g.cyl(0.55, 0.62, 0.0, 0.05, 0.55, "colonne_mano", cuivre, verts=16)
    S.cylinder(0.12, 0.05, g.G(0.55, 0.60, 0.66), laiton, "manometre", verts=32, rot=(math.pi / 2, 0, 0), bevel_w=0.006)
    S.cylinder(0.095, 0.02, g.G(0.55, 0.62, 0.66), k.metal("cadran", "#D8D0B8", gain=1.0, metallic=0.0, rough=0.6),
               "cadran", verts=32, rot=(math.pi / 2, 0, 0), bevel_w=0)
    # cheminée ronde haute à collerette, arrière droit
    cx, cy, cr = 0.55, -0.50, 0.16
    zt = KEY[3]["chimney"][0][2]
    g.cyl(cx, cy, 0.0, cr + 0.03, 0.30, "pied_cheminee", fonte, verts=40)
    g.cyl(cx, cy, 0.30, cr, zt - 0.40, "fut_cheminee", fonte, verts=40)
    g.cyl(cx, cy, zt - 0.12, cr, 0.12, "collerette", laiton, verts=40, r2=0.21, caps=False, bevel_w=0)
    S.torus(0.21, 0.02, g.G(cx, cy, zt), laiton, "levre")
    for z in (0.55, 0.85):
        S.torus(cr + 0.005, 0.018, g.G(cx, cy, z), laiton, "cercle_chem_%d" % int(z * 100))
    smoke_mouth(k, cx, cy, zt, 0.19)
    g.cyl(cx, cy, zt - 0.11, 0.19, 0.02, "fond_gueule", k.soot(), verts=40, bevel_w=0)
    k.halo(-0.25, 0.97, 0.15, PRM.FIRE, 8.0, "halo_bouche")
    k.halo(-0.25, 0.55, 0.62, "#FFC060", 3.0, "halo_hublot")
    if even:
        # chaudière de récupération : cylindre horizontal riveté (axe nord-sud) sur le flanc gauche
        bx, by, bz, br = -0.98, 0.05, 0.36, 0.22
        S.cylinder(br, 1.25, g.G(bx, by, bz), cuivre, "chaudiere", verts=40, rot=(math.pi / 2, 0, 0), bevel_w=0.01)
        for dy in (-0.38, 0.0, 0.38):
            S.torus(br + 0.004, 0.018, g.G(bx, by + dy, bz), laiton, "cercle_chaud", rot=(math.pi / 2, 0, 0))
        g.cyl(bx, by - 0.10, bz + br - 0.04, 0.10, 0.20, "dome_vapeur", cuivre, verts=24, r2=0.08)
        S.sphere(0.08, g.G(bx, by - 0.10, bz + br + 0.17), laiton, "soupape", seg=16, rings=8)
        for dy in (-0.32, 0.32):
            g.box(bx, by + dy / g.K, 0.0, 0.32, 0.10, bz - br + 0.06, "berceau", fonte, bevel_w=0.01)
        g.pipe([g.G(bx + 0.10, by - 0.10, bz + br + 0.05), g.G(bx + 0.30, by - 0.20, bz + 0.65),
                g.G(-0.65, -0.15, 0.85)], 0.04, "tuyau_chaud", cuivre)
        S.cylinder(0.09, 0.03, g.G(bx, by + 0.62 / g.K + 0.42, bz), k_amb, "hublot_chaud", verts=24,
                   rot=(math.pi / 2, 0, 0), bevel_w=0)


# -------------------------------------------------------------------------------------------------
# Époque 4 · Pétrole : foyer cylindrique horizontal, réservoir latéral, cheminée, garde-corps ; pièce : torchère
# -------------------------------------------------------------------------------------------------
def e4(k, even):
    g, S = k.g, k.S
    jaune = k.metal("jaune", gain=2.0, rough=0.5, metallic=0.35, rust="#5A4A2A", rust_amount=0.35, dirt=0.55)
    galva = k.metal("galva", gain=1.9, rough=0.35, metallic=0.75, dirt=0.4)
    noir = k.metal("noir", gain=1.5, rough=0.5, metallic=0.5, dirt=0.3)
    orange = k.emit("voyant", "#FF8C1A", 1.6)
    # foyer : cylindre horizontal (axe nord-sud), bouche ronde au sud
    fx, fy0, fy1, fz, fr = -0.30, -0.55, 0.80, 0.68, 0.56
    L = (fy1 - fy0) * g.K
    yc = (fy0 + fy1) / 2
    S.cylinder(fr, L, g.G(fx, yc, fz), jaune, "foyer", verts=48, rot=(math.pi / 2, 0, 0), bevel_w=0.015)
    for t in (0.06, 0.5, 0.94):
        S.torus(fr + 0.006, 0.03, g.G(fx, fy0 + t * (fy1 - fy0), fz), noir, "bande_%d" % int(t * 100),
                rot=(math.pi / 2, 0, 0))
    # fond bombé avant, bouche ronde du brûleur
    yb = -fy1 * g.K
    S.cylinder(fr - 0.03, 0.10, (fx, yb - 0.05, fz), galva, "fond", verts=48, rot=(math.pi / 2, 0, 0), radius2=fr - 0.12,
               bevel_w=0.01)
    fire = k.emit("bouche", PRM.FIRE, 1.7)
    S.cylinder(0.20, 0.03, (fx, yb - 0.105, fz), fire, "bouche_feu", verts=40, rot=(math.pi / 2, 0, 0), bevel_w=0)
    S.torus(0.215, 0.03, (fx, yb - 0.11, fz), noir, "bouche_cadre", rot=(math.pi / 2, 0, 0))
    # berceaux
    for t in (0.2, 0.8):
        g.box(fx, fy0 + t * (fy1 - fy0), 0.0, 0.86, 0.14, fz - fr + 0.12, "berceau_%d" % int(t * 10), noir, bevel_w=0.01)
    # passerelle et garde-corps sur le foyer
    pz = fz + fr + 0.01
    g.box(fx, yc, pz, 0.46, L - 0.1, 0.03, "passerelle", galva, bevel_w=0.004)
    rails = []
    for sx in (-1, 1):
        for i in range(5):
            py = fy0 + 0.05 + i * (fy1 - fy0 - 0.1) / 4
            rails.append(g.cyl(fx + sx * 0.22, py, pz, 0.012, 0.24, "poteau_%d_%d" % (sx + 1, i), galva, verts=8, bevel_w=0))
        rails.append(g.cyl_between(g.G(fx + sx * 0.22, fy0 + 0.05, pz + 0.24), g.G(fx + sx * 0.22, fy1 - 0.05, pz + 0.24),
                                   0.014, "lisse_%d" % (sx + 1), galva, verts=8))
        rails.append(g.cyl_between(g.G(fx + sx * 0.22, fy0 + 0.05, pz + 0.13), g.G(fx + sx * 0.22, fy1 - 0.05, pz + 0.13),
                                   0.010, "sous_lisse_%d" % (sx + 1), galva, verts=8))
    g.join(rails, "garde_corps")
    # échelle sur l'avant gauche
    g.box(fx - 0.45, fy1 - 0.05, 0.0, 0.03, 0.03, pz, "echelle_m1", galva, bevel_w=0)
    g.box(fx - 0.33, fy1 - 0.05, 0.0, 0.03, 0.03, pz, "echelle_m2", galva, bevel_w=0)
    # réservoir de fioul latéral (droite), bandes noires, vanne à volant, voyant
    tx, tz, tr = 0.60, 0.33, 0.27
    S.cylinder(tr, 0.80 * g.K, g.G(tx, 0.50, tz), galva, "reservoir", verts=40, rot=(math.pi / 2, 0, 0), bevel_w=0.012)
    for t in (0.18, 0.82):
        S.torus(tr + 0.005, 0.022, g.G(tx, 0.10 + t * 0.80, tz), noir, "bande_res", rot=(math.pi / 2, 0, 0))
    S.sphere(0.07, g.G(tx, 0.92, tz + 0.12), orange, "voyant_res", seg=16, rings=8)
    g.pipe([g.G(tx - 0.12, 0.85, tz), g.G(0.10, 0.92, 0.40), g.G(fx + 0.30, fy1 + 0.02, 0.45)], 0.035, "conduite_fioul", galva)
    S.torus(0.08, 0.015, g.G(0.12, 0.98, 0.52), noir, "volant_vanne", rot=(math.pi / 2, 0, 0))
    S.sphere(0.065, g.G(fx - 0.38, fy1 + 0.02, fz + 0.32), orange, "voyant_foyer", seg=16, rings=8)
    # cheminée galvanisée à bandes noires, arrière droit
    cx, cy, cr = 0.55, -0.55, 0.15
    zt = KEY[4]["chimney"][0][2]
    g.cyl(cx, cy, 0.0, cr, zt, "cheminee", galva, verts=40)
    for z in (0.35, 0.75, zt - 0.10):
        S.torus(cr + 0.004, 0.028, g.G(cx, cy, z), noir, "bande_chem")
    smoke_mouth(k, cx, cy, zt, cr - 0.02)
    g.pipe([g.G(fx + 0.30, -0.35, fz + 0.30), g.G(0.25, -0.45, fz + 0.45), g.G(cx - 0.10, cy, fz + 0.45)], 0.07,
           "carneau", galva)
    k.halo(fx, 0.95, fz, PRM.FIRE, 9.0, "halo_bouche")
    k.halo(tx, 0.98, tz + 0.12, "#FF8C1A", 2.0, "halo_voyant")
    if even:
        # torchère greffée sur la cheminée : tube, couronne de brûleur et flamme
        fxp, fyp = 0.86, -0.42
        top = 1.48
        g.cyl(fxp, fyp, 0.0, 0.06, top, "torchere", galva, verts=20)
        for z in (0.5, 0.95, 1.30):
            g.cyl_between(g.G(fxp, fyp, z), g.G(cx, cy, z), 0.02, "bride_%d" % int(z * 100), noir, verts=8)
            S.torus(0.065, 0.015, g.G(fxp, fyp, z), noir, "collier_%d" % int(z * 100))
        g.cyl(fxp, fyp, top, 0.10, 0.10, "bruleur", noir, verts=24, r2=0.12)
        flame = k.emit("flamme", "#FFB040", 2.2)
        g.cyl(fxp, fyp, top + 0.10, 0.09, 0.24, "flamme", flame, verts=24, r2=0.0, bevel_w=0)
        S.sphere(0.075, g.G(fxp, fyp, top + 0.16), flame, "flamme_coeur", seg=16, rings=8)
        k.halo(fxp, fyp, top + 0.2, "#FFB040", 5.0, "halo_torchere")


# -------------------------------------------------------------------------------------------------
# Époque 5 · Volcan : tronc de pyramide en écailles, bouche de lave, fissures ; pièce : rigole de coulée
# -------------------------------------------------------------------------------------------------
def e5(k, even):
    g, S = k.g, k.S
    tung = k.metal("tungstene", gain=2.0, rough=0.45, metallic=0.6, rust="#5A3A2A", rust_amount=0.35, dirt=0.6)
    rouille = k.metal("rouille", gain=1.6, rough=0.7, metallic=0.3, dirt=0.5)
    riv = k.metal("rivet", "#6A6670", gain=2.2, rough=0.3, metallic=0.85, grain=0.08)
    lava = k.emit("lave", "#FF4A10", 1.8)
    # pyramide tronquée en trois gradins d'écailles (chaque gradin déborde un peu sur le suivant)
    tiers = [((-0.13, 0.17, 1.84, 1.44), 0.0, (-0.13, 0.12, 1.58, 1.22), 0.34),
             ((-0.13, 0.12, 1.60, 1.24), 0.30, (-0.13, 0.07, 1.30, 0.98), 0.64),
             ((-0.13, 0.07, 1.32, 1.00), 0.60, (-0.13, 0.02, 0.92, 0.66), 0.94)]
    for i, ((ax, ay, aw, ad), z0, (bx, by, bw, bd), z1) in enumerate(tiers):
        g.frustum(g.rect(ax, ay, aw, ad), z0, g.rect(bx, by, bw, bd), z1, "gradin_%d" % i, tung, bevel_w=0.02)
        # rivets lourds le long du bord bas de chaque gradin (face avant)
        g.rivets_line(g.G(ax - aw / 2 + 0.1, ay + ad / 2 + 0.01, z0 + 0.04), g.G(ax + aw / 2 - 0.1, ay + ad / 2 + 0.01, z0 + 0.04),
                      7 - i, 0.024, riv, "rivets_g%d" % i)
    g.frustum(g.rect(-0.13, 0.02, 0.94, 0.68), 0.94, g.rect(-0.13, 0.02, 0.80, 0.56), 1.00, "dalle", rouille, bevel_w=0.01)
    # fentes de braise (fissures) sur la face avant : plaques émissives en retrait entre écailles
    for i, (x, z, ti) in enumerate(((-0.58, 0.47, 1), (0.32, 0.47, 1), (-0.42, 0.78, 2), (0.16, 0.78, 2))):
        (ax, ay, aw, ad), z0, (bx_, by_, bw, bd), z1 = tiers[ti]
        ya, yb_ = ay + ad / 2, by_ + bd / 2
        yf = ya + (yb_ - ya) * (z - z0) / (z1 - z0)
        th = -math.atan(((ya - yb_) * g.K) / (z1 - z0))
        o = S.box((0.14, 0.03, 0.17), g.G(x, yf, z), lava, "fente_%d" % i, bevel_w=0)
        o.rotation_euler = (th, 0, 0)
    # bouche de lave à l'avant (arc)
    fire_mouth(k, -0.13, 0.89, 0.04, 0.42, 0.16, rouille, "#FF4A10", strength=1.9, arch=True)
    # pointes de basalte sur la dalle
    for i, (x, y) in enumerate(((-0.48, 0.25), (0.20, 0.30))):
        g.cyl(x, y, 0.98, 0.07, 0.30, "pointe_%d" % i, tung, verts=6, r2=0.0, bevel_w=0)
    # cheminée blindée en tronc de pyramide, arrière droit, fente de braise près du sommet
    cx, cy = 0.48, -0.52
    zt = KEY[5]["chimney"][0][2]
    g.frustum(g.rect(cx, cy, 0.44, 0.44 / g.K), 0.0, g.rect(cx, cy, 0.26, 0.26 / g.K), zt, "cheminee", tung, bevel_w=0.012)
    g.frustum(g.rect(cx, cy, 0.32, 0.32 / g.K), zt - 0.10, g.rect(cx, cy, 0.30, 0.30 / g.K), zt + 0.02, "couronne", rouille,
              bevel_w=0.008)
    S.box((0.20, 0.20, 0.01), g.G(cx, cy, zt + 0.025), k.soot(), "gueule", bevel_w=0)
    o = S.box((0.12, 0.03, 0.16), g.G(cx, cy + 0.145 / g.K, zt - 0.32), lava, "fente_chem", bevel_w=0)
    o.rotation_euler = (-math.atan(0.09 / zt), 0, 0)
    k.halo(-0.13, 0.98, 0.15, "#FF4A10", 9.0, "halo_bouche")
    k.halo(-0.13, 0.75, 0.62, "#FF4A10", 3.0, "halo_fentes")
    if even:
        # rigole de coulée de lave qui déborde à l'avant (+0,20 au sud) et lingotière
        st = k.stone("pierre", "#3A3634", gain=1.4, rough=0.9)
        y0, y1 = 0.80, 1.18
        g.box(-0.13, (y0 + y1) / 2, 0.0, 0.50, (y1 - y0) * g.K, 0.10, "rigole_fond", st, bevel_w=0.015)
        for sx in (-1, 1):
            g.box(-0.13 + sx * 0.22, (y0 + y1) / 2, 0.08, 0.07, (y1 - y0) * g.K, 0.10, "rigole_bord_%d" % (sx + 1), st,
                  bevel_w=0.012)
        g.box(-0.13, (y0 + y1) / 2 + 0.02, 0.10, 0.36, (y1 - y0) * g.K - 0.06, 0.02, "rigole_lave", lava, bevel_w=0)
        # lingotière en bout de rigole (déborde à droite), lave figée lumineuse
        g.box(0.30, 1.10, 0.0, 0.40, 0.30, 0.16, "lingotiere", tung, bevel_w=0.015)
        g.box(0.30, 1.10, 0.16, 0.30, 0.20, 0.012, "lingot", lava, bevel_w=0)
        k.halo(-0.13, 1.12, 0.15, "#FF4A10", 4.0, "halo_rigole")


# -------------------------------------------------------------------------------------------------
# Époque 6 · Électricité : four à arc (cuve, 3 électrodes, isolateurs) ; pièce : transformateur à ailettes
# -------------------------------------------------------------------------------------------------
def insulator_stack(k, x, y, z0, n, name, r=0.075):
    cer = k.metal("ceramique", gain=1.0, rough=0.35, metallic=0.0, grain=0.1, dirt=0.4)
    parts = []
    for i in range(n):
        parts.append(k.g.cyl(x, y, z0 + i * 0.07, r, 0.035, "%s_d%d" % (name, i), cer, verts=24, bevel_w=0.008))
        parts.append(k.g.cyl(x, y, z0 + i * 0.07 + 0.035, r * 0.55, 0.035, "%s_t%d" % (name, i), cer, verts=16, bevel_w=0))
    return k.g.join(parts, name)


def e6(k, even):
    g, S = k.g, k.S
    acier = k.metal("acier", gain=2.1, rough=0.38, metallic=0.65, dirt=0.45, rust="#4A3A30", rust_amount=0.15)
    cuivre = k.metal("cuivre", gain=1.6, rough=0.3, metallic=0.85, dirt=0.3)
    graph = k.metal("graphite", "#2A2A2C", gain=1.6, rough=0.55, metallic=0.2, grain=0.15)
    cyan = k.emit("arc", "#60D0FF", 1.8)
    vx, vy = -0.15, 0.12
    # cuve ronde et couvercle bombé
    g.lathe([(0.74, 0.0), (0.78, 0.08), (0.78, 0.55), (0.80, 0.62)], (vx, vy), "cuve", acier, segs=48)
    g.lathe([(0.80, 0.62), (0.74, 0.70), (0.55, 0.80), (0.30, 0.86), (0.0, 0.88)], (vx, vy), "couvercle",
            k.metal("refractaire", "#8A8478", gain=1.3, rough=0.7, metallic=0.1), segs=48)
    for z in (0.18, 0.45):
        S.torus(0.785, 0.025, g.G(vx, vy, z), cuivre, "barre_%d" % int(z * 100))
    # trou de coulée (bouche) : bec avant avec métal en fusion
    fire = k.emit("bouche", PRM.FIRE, 1.8)
    g.box(vx, vy + 0.62, 0.24, 0.24, 0.40, 0.12, "bec", acier, bevel_w=0.02)
    g.box(vx, vy + 0.66, 0.36, 0.14, 0.30, 0.01, "coulee", fire, bevel_w=0)
    S.box((0.30, 0.03, 0.12), g.G(vx, vy + 0.555, 0.30), fire, "trou_coulee", bevel_w=0)
    # 3 électrodes verticales (graphite), colliers lumineux cyan au passage du couvercle
    tops = (1.40, 1.52, 1.62)
    for i, a in enumerate((math.radians(250), math.radians(10), math.radians(130))):
        ex = vx + 0.30 * math.cos(a)
        ey = vy - 0.30 * math.sin(a) / g.K
        g.cyl(ex, ey, 0.70, 0.085, tops[i] - 0.70, "electrode_%d" % i, graph, verts=24)
        S.torus(0.115, 0.035, g.G(ex, ey, 0.84), cyan, "collier_arc_%d" % i)
        # pince en cuivre et bras sur pile d'isolateurs vers le mât arrière gauche
        g.cyl(ex, ey, tops[i] - 0.22, 0.11, 0.12, "pince_%d" % i, cuivre, verts=20)
        g.cyl_between(g.G(ex, ey, tops[i] - 0.16), g.G(-0.80, -0.30, tops[i] - 0.16), 0.035, "bras_%d" % i, cuivre, verts=10)
    # mât gauche et piles d'isolateurs
    g.box(-0.80, -0.30, 0.0, 0.14, 0.14, 1.60, "mat", acier, bevel_w=0.01)
    insulator_stack(k, -0.80, -0.30, 1.60, 2, "isol_mat")
    for i, z in enumerate((0.95, 1.12)):
        insulator_stack(k, -0.62, -0.18, z, 2, "isol_bras_%d" % i, r=0.06)
    # arcs (zigzags émissifs) entre les sommets des électrodes
    pts = [g.G(vx + 0.30 * math.cos(math.radians(250)), vy - 0.30 * math.sin(math.radians(250)) / g.K, 0.95),
           g.G(vx - 0.02, vy + 0.02, 1.05), g.G(vx + 0.05, vy - 0.06, 0.98),
           g.G(vx + 0.30 * math.cos(math.radians(10)), vy - 0.30 * math.sin(math.radians(10)) / g.K, 1.02)]
    g.pipe(pts, 0.025, "arc_1", cyan, segs=8)
    # extraction des fumées : coude depuis le couvercle vers la gaine arrière droite (cheminée)
    cx, cy, cr = 0.62, -0.55, 0.14
    zt = KEY[6]["chimney"][0][2]
    g.cyl(cx, cy, 0.0, cr, zt, "gaine", acier, verts=32)
    for z in (0.40, 0.90, zt - 0.10):
        S.torus(cr + 0.004, 0.025, g.G(cx, cy, z), cuivre, "bague_gaine")
    insulator_stack(k, cx, cy, zt - 0.36, 3, "isol_gaine", r=0.165)
    smoke_mouth(k, cx, cy, zt, cr - 0.02)
    g.pipe([g.G(vx + 0.35, vy - 0.30, 0.82), g.G(0.35, -0.45, 1.05), g.G(cx - 0.05, cy, 1.10)], 0.08, "coude_fumees", acier)
    k.halo(vx, 0.98, 0.30, PRM.FIRE, 8.0, "halo_bouche")
    k.halo(vx, vy, 1.05, "#60D0FF", 4.0, "halo_arcs")
    if even:
        # transformateur à ailettes et traversées en céramique, flanc gauche
        tx, ty = -0.88, -0.25
        g.box(tx, ty, 0.0, 0.36, 0.70, 0.62, "transfo", acier, bevel_w=0.015)
        fins = []
        for i in range(7):
            fy = ty - 0.22 + i * 0.075
            fins.append(g.box(tx - 0.21, fy, 0.05, 0.10, 0.025, 0.52, "ailette_%d" % i, acier, bevel_w=0.003))
        g.join(fins, "ailettes")
        for i, dy in enumerate((-0.14, 0.0, 0.14)):
            insulator_stack(k, tx + 0.04, ty + dy, 0.62, 4, "traversee_%d" % i, r=0.055)
            g.cyl_between(g.G(tx + 0.04, ty + dy, 0.92), g.G(vx - 0.35, vy - 0.15, 0.80), 0.015, "cable_%d" % i, cuivre, verts=8)
        S.box((0.16, 0.02, 0.10), g.G(tx, ty + 0.70 / g.K / 2 + 0.01, 0.45), cyan, "voyant_transfo", bevel_w=0)


# -------------------------------------------------------------------------------------------------
# Époque 7 · Cristal : creuset tenu par 4 griffes de cristal ; pièce : prisme focalisateur
# -------------------------------------------------------------------------------------------------
def crystal(k, x, y, z0, r, h, lean, name, mat, tip=0.35, rot=0.0):
    """Cristal hexagonal pointu, incliné de lean=(dx, dy) en unités Blender au sommet."""
    g = k.g
    cx, cy, _ = g.G(x, y, 0)
    body_h = h * (1 - tip)
    rings = []
    for t, rr in ((0.0, r * 0.85), (body_h, r)):
        f = t / h
        rings.append(g.ring_pts(cx + lean[0] * f, cy + lean[1] * f, rr, z0 + t, 6, rot))
    apex = (cx + lean[0], cy + lean[1], z0 + h)
    verts = rings[0] + rings[1] + [apex]
    faces = []
    for i in range(6):
        j = (i + 1) % 6
        faces.append((i, j, 6 + j, 6 + i))
        faces.append((6 + i, 6 + j, 12))
    faces.append(tuple(reversed(range(6))))
    return g.mesh(name, verts, faces, mat, smooth_deg=None, bevel_w=0.004)


def e7(k, even):
    g, S = k.g, k.S
    pierre = k.stone("pierre", gain=1.5, rough=0.9, grain=0.35, dirt=0.7)
    bronze = k.metal("bronze", gain=2.1, rough=0.32, metallic=0.85, rust="#3E6A50", rust_amount=0.25, dirt=0.4)
    cris = k.glossy("cristal", gain=0.75, rough=0.12)
    cglow = k.emit("cristal", "#B070FF", 1.5)
    px, py = -0.10, 0.15
    # socle de pierre taillée octogonal, foyer violet à l'avant
    g.frustum(g.regular(px, py, 0.92, 8, math.pi / 8), 0.0, g.regular(px, py, 0.84, 8, math.pi / 8), 0.30, "socle",
              pierre, bevel_w=0.02)
    fire_mouth(k, px, py + 0.92 * math.cos(math.pi / 8) / g.K - 0.01, 0.05, 0.30, 0.14, bronze, "#B070FF", strength=1.6,
               arch=True)
    # fût et creuset de bronze, bain violet lumineux
    g.cyl(px, py, 0.30, 0.20, 0.22, "fut", bronze, verts=32)
    g.lathe([(0.22, 0.50), (0.42, 0.62), (0.54, 0.82), (0.56, 0.96)], (px, py), "creuset", bronze, segs=48, cap_top=False)
    S.torus(0.56, 0.035, g.G(px, py, 0.96), bronze, "levre_creuset")
    g.cyl(px, py, 0.88, 0.52, 0.04, "bain", cglow, verts=48, bevel_w=0)
    # 4 griffes de cristal pointées vers le haut (hauteurs asymétriques), avec éclats lumineux au pied
    claws = [(-0.78, 0.62, 0.95, (0.10, 0.05)), (0.52, 0.66, 1.15, (-0.10, 0.06)),
             (-0.80, -0.30, 1.55, (0.12, -0.04)), (0.40, -0.22, 1.30, (-0.10, -0.03))]
    for i, (x, y, h, ln) in enumerate(claws):
        crystal(k, x, y, 0.22, 0.13, h, ln, "griffe_%d" % i, cris, rot=0.3 * i)
        crystal(k, x + 0.10, y + 0.06, 0.25, 0.07, h * 0.45, (ln[0] * 0.6 + 0.08, ln[1]), "eclat_%d" % i, cglow, rot=0.5)
        g.cyl_between(g.G(x, y, 0.70), g.G(px + (x - px) * 0.45, py + (y - py) * 0.45, 0.88), 0.04, "bras_%d" % i, bronze, verts=10)
        S.torus(0.15, 0.03, g.G(x, y, 0.40), bronze, "sertissure_%d" % i)
    # cheminée de bronze à bague de cristal, arrière droit
    cx, cy, cr = 0.60, -0.55, 0.14
    zt = KEY[7]["chimney"][0][2]
    g.cyl(cx, cy, 0.0, cr, zt, "cheminee", bronze, verts=32)
    g.cyl(cx, cy, zt - 0.30, cr + 0.04, 0.14, "bague", bronze, verts=32)
    for i in range(6):
        a = 2 * math.pi * i / 6
        bx, by, _ = g.G(cx, cy, 0)
        crystal(k, (bx + 0.17 * math.cos(a)), -(by + 0.17 * math.sin(a)) / g.K, zt - 0.32, 0.045, 0.22,
                (0.05 * math.cos(a), 0.05 * math.sin(a)), "eclat_chem_%d" % i, cglow)
    S.torus(cr + 0.02, 0.025, g.G(cx, cy, zt), bronze, "levre")
    smoke_mouth(k, cx, cy, zt, cr - 0.02)
    k.halo(px, 0.98, 0.12, "#B070FF", 7.0, "halo_bouche")
    k.halo(px, py, 1.00, "#B070FF", 5.0, "halo_bain")
    if even:
        # prisme focalisateur flottant au-dessus du creuset, tenu par deux bras de bronze
        zc = 1.42
        cxp, cyp, _ = g.G(px, py, 0)
        top = (cxp, cyp, zc + 0.30)
        bot = (cxp, cyp, zc - 0.26)
        mid = g.ring_pts(cxp, cyp, 0.19, zc + 0.02, 4, math.pi / 4)
        verts = mid + [top, bot]
        faces = [(i, (i + 1) % 4, 4) for i in range(4)] + [((i + 1) % 4, i, 5) for i in range(4)]
        g.mesh("prisme", verts, faces, cglow, bevel_w=0.003)
        S.torus(0.24, 0.025, (cxp, cyp, zc + 0.02), bronze, "anneau_prisme")
        for sx in (-1, 1):
            g.pipe([(cxp + sx * 0.24, cyp, zc + 0.02), (cxp + sx * 0.48, cyp + 0.10, zc - 0.10),
                    (cxp + sx * 0.62, cyp + 0.25, zc - 0.40)], 0.03, "bras_prisme_%d" % (sx + 1), bronze)
        k.halo(px, py, zc, "#B070FF", 4.0, "halo_prisme")


# -------------------------------------------------------------------------------------------------
# Époque 8 · Marais : alambic sphérique, col de cygne ; pièce : second alambic
# -------------------------------------------------------------------------------------------------
def alembic(k, x, y, zc, r, name, glass, liquid, band):
    g, S = k.g, k.S
    cx, cy, _ = g.G(x, y, 0)
    # moitié basse : liquide luminescent vu à travers le verre ; moitié haute : verre sombre
    prof_low = [(0.001, zc - r)] + [(r * math.sin(math.pi * i / 16), zc - r * math.cos(math.pi * i / 16)) for i in range(1, 9)]
    prof_hi = [(r * math.sin(math.pi * i / 16), zc - r * math.cos(math.pi * i / 16)) for i in range(8, 16)] + [(0.001, zc + r)]
    g.lathe(prof_low, (x, y), name + "_liquide", liquid, segs=40, cap_top=False)
    g.lathe(prof_hi, (x, y), name + "_verre", glass, segs=40, cap_bottom=False)
    S.torus(r + 0.005, 0.03, (cx, cy, zc), band, name + "_ceinture")


def e8(k, even):
    g, S = k.g, k.S
    vdg = k.metal("vdg", gain=2.0, rough=0.5, metallic=0.5, rust="#2E4A3A", rust_amount=0.4, dirt=0.55)
    verre = k.glossy("verre", gain=0.55, rough=0.08)
    liq = k.emit("liquide", "#A8FF3A", 1.1)
    caout = k.stone("caoutchouc", gain=1.3, rough=0.7)
    bx, by = -0.15, 0.18
    g.lathe([(0.84, 0.0), (0.86, 0.10), (0.80, 0.22), (0.62, 0.30)], (bx, by), "base", vdg, segs=48)
    fire_mouth(k, bx, by + 0.86 / g.K - 0.02, 0.03, 0.28, 0.10, vdg, "#A8FF3A", strength=1.4, arch=True)
    # berceau et alambic
    S.torus(0.48, 0.05, g.G(bx, by, 0.40), vdg, "berceau")
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        cx, cy, _ = g.G(bx, by, 0)
        g.cyl_between((cx + 0.55 * math.cos(a), cy + 0.55 * math.sin(a), 0.25), (cx + 0.45 * math.cos(a), cy + 0.45 * math.sin(a), 0.42),
                      0.035, "pied_berceau_%d" % i, vdg, verts=10)
    zc, r = 0.95, 0.60
    alembic(k, bx, by, zc, r, "alambic", verre, liq, vdg)
    # col de cygne : monte, s'arrondit et redescend vers la cheminée arrière droite
    cx0, cy0, _ = g.G(bx, by, 0)
    chx, chy = 0.62, -0.55
    zt = KEY[8]["chimney"][0][2]
    p_ch = g.G(chx, chy, 0)
    neck = [(cx0, cy0, zc + r - 0.05), (cx0, cy0 + 0.05, zc + r + 0.25), (cx0 + 0.15, cy0 + 0.25, zc + r + 0.45),
            (cx0 + 0.40, cy0 + 0.55, zc + r + 0.62), (p_ch[0] - 0.10, p_ch[1] - 0.05, zc + r + 0.45),
            (p_ch[0], p_ch[1], zt - 0.25)]
    g.pipe(neck, 0.085, "col_de_cygne", vdg)
    S.torus(0.10, 0.025, (cx0, cy0, zc + r + 0.02), caout, "joint_col")
    # cheminée : colonne de verre et vert-de-gris, bulbe d'évent
    g.cyl(chx, chy, 0.0, 0.12, zt - 0.30, "colonne", vdg, verts=32)
    S.sphere(0.16, g.G(chx, chy, zt - 0.22), verre, "bulbe_event", seg=32, rings=16)
    g.cyl(chx, chy, zt - 0.10, 0.07, 0.10, "event_bulbe", vdg, verts=20)
    smoke_mouth(k, chx, chy, zt, 0.05)
    # petits bulbes et conduits sur la base (kit)
    for i, (x, y) in enumerate(((0.40, 0.70), (-0.70, 0.60))):
        alembic(k, x, y, 0.32, 0.11, "bulbe_%d" % i, verre, liq, vdg)
    g.pipe([g.G(0.40, 0.70, 0.43), g.G(0.25, 0.50, 0.60), g.G(0.15, 0.40, 0.75)], 0.03, "conduit_bulbe", caout)
    k.halo(bx, 0.98, 0.08, "#A8FF3A", 6.0, "halo_bouche")
    k.halo(bx, by + 0.3, 0.70, "#A8FF3A", 5.0, "halo_alambic")
    if even:
        sx, sy, sz, sr = -0.92, -0.25, 0.80, 0.30
        alembic(k, sx, sy, sz, sr, "alambic2", verre, liq, vdg)
        for i in range(3):
            a = 2 * math.pi * i / 3 + 0.2
            cx, cy, _ = g.G(sx, sy, 0)
            g.cyl_between((cx + 0.28 * math.cos(a), cy + 0.28 * math.sin(a), 0.0), (cx + 0.18 * math.cos(a), cy + 0.18 * math.sin(a), sz - sr + 0.05),
                          0.03, "trepied_%d" % i, vdg, verts=10)
        g.pipe([g.G(sx, sy, sz + sr - 0.03), g.G(sx + 0.05, sy, sz + sr + 0.25), g.G(sx + 0.35, sy + 0.15, sz + sr + 0.30),
                g.G(bx - 0.35, by - 0.15, zc + 0.30)], 0.045, "tube_alambic2", vdg)
        k.halo(sx, sy, sz, "#A8FF3A", 3.0, "halo_alambic2")


# -------------------------------------------------------------------------------------------------
# Époque 9 · Atome : base octogonale plombée, dôme chanfreiné, tour hyperboloïde ; pièce : conduit annelé
# -------------------------------------------------------------------------------------------------
def e9(k, even):
    g, S = k.g, k.S
    plomb = k.metal("plomb", gain=2.0, rough=0.5, metallic=0.55, dirt=0.55, rust="#3A3E44", rust_amount=0.2)
    jaune = k.metal("jaune", gain=1.4, rough=0.55, metallic=0.2, dirt=0.4)
    beton = k.stone("beton", gain=1.15, rough=0.9, grain=0.3, dirt=0.6)
    vert = k.emit("uranium", "#5CFF4A", 1.4)
    bx, by = -0.15, 0.18
    ph = math.pi / 8
    g.lathe([(0.88, 0.0), (0.90, 0.06), (0.90, 0.24), (0.86, 0.30)], (bx, by), "base", plomb, segs=8, phase=ph, smooth_deg=None,
            bevel_w=0.012)
    g.lathe([(0.91, 0.24), (0.91, 0.31)], (bx, by), "bande_jaune", jaune, segs=8, phase=ph, smooth_deg=None)
    g.lathe([(0.86, 0.30), (0.80, 0.40), (0.74, 0.44), (0.72, 0.78), (0.58, 1.02), (0.36, 1.16), (0.0, 1.20)], (bx, by), "dome",
            plomb, segs=8, phase=ph, smooth_deg=None, bevel_w=0.01)
    # hublots verts sur les pans avant du dôme, porte chanfreinée avec fenêtre verte (bouche)
    for i, a in enumerate((-math.pi / 4, 0.0, math.pi / 4)):
        rr = 0.73 * math.cos(math.pi / 8) + 0.012
        hx = bx + rr * math.sin(a)
        hy = by + rr * math.cos(a) / g.K
        S.cylinder(0.10, 0.03, g.G(hx, hy, 0.62), vert, "hublot_%d" % i, verts=24, rot=(math.pi / 2, 0, a), bevel_w=0)
        S.torus(0.115, 0.025, g.G(hx + 0.008 * math.sin(a), hy + 0.008 * math.cos(a) / g.K, 0.62), jaune,
                "cadre_hublot_%d" % i, rot=(math.pi / 2, 0, a))
    fire_mouth(k, bx, by + 0.90 * math.cos(math.pi / 8) / g.K, 0.05, 0.30, 0.16, jaune, "#5CFF4A", strength=1.5)
    # plaque au trèfle
    S.cylinder(0.09, 0.02, g.G(bx + 0.45, by + 0.80 / g.K, 0.16), jaune, "plaque_trefle", verts=24, rot=(math.pi / 2, 0, 0.6), bevel_w=0)
    # tour de refroidissement hyperboloïde à l'arrière droit (béton, bande jaune) : la cheminée
    cx, cy = 0.60, -0.50
    zt = KEY[9]["chimney"][0][2]
    g.lathe([(0.36, 0.0), (0.31, 0.45), (0.25, 1.05), (0.235, 1.35), (0.25, 1.65), (0.28, zt)], (cx, cy), "tour", beton, segs=40,
            cap_top=False)
    g.lathe([(0.255, 1.60), (0.27, 1.75)], (cx, cy), "bande_tour", jaune, segs=40, cap_top=False, cap_bottom=False)
    g.cyl(cx, cy, zt - 0.12, 0.26, 0.11, "fond_tour", k.soot(), verts=40, bevel_w=0)
    S.torus(0.24, 0.03, g.G(cx, cy, zt - 0.10), vert, "vapeur_verte")
    k.halo(bx, 0.98, 0.20, "#5CFF4A", 7.0, "halo_bouche")
    k.halo(bx, 0.55, 0.62, "#5CFF4A", 4.0, "halo_hublots")
    if even:
        # conduit annelé sur le flanc droit, de la base jusqu'à la tour
        pts = [g.G(0.62, 0.55, 0.20), g.G(0.92, 0.45, 0.30), g.G(0.95, 0.10, 0.65), g.G(0.92, -0.20, 1.10),
               g.G(cx + 0.22, cy + 0.05, 1.30)]
        g.pipe(pts, 0.085, "conduit_annele", plomb)
        # anneaux le long du conduit
        from mathutils import Vector
        rings = []
        for a, b in zip(pts[:-1], pts[1:]):
            va, vb = Vector(a), Vector(b)
            d = vb - va
            for i in range(1, 4):
                p = va + d * (i / 4)
                o = S.torus(0.10, 0.022, tuple(p), jaune if i == 2 else plomb, "anneau", minor_seg=8)
                o.rotation_mode = "QUATERNION"
                o.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
                rings.append(o)
        g.join(rings, "anneaux_conduit")
        S.cylinder(0.08, 0.02, g.G(0.97, 0.10, 0.65), vert, "voyant_conduit", verts=20, rot=(0, math.pi / 2, 0), bevel_w=0)


# -------------------------------------------------------------------------------------------------
# Époque 10 · Haute technologie : capsule d'induction sur pieds courts ; pièce : écran et antenne
# -------------------------------------------------------------------------------------------------
def e10(k, even):
    g, S = k.g, k.S
    car = k.metal("carenage", gain=1.25, rough=0.30, metallic=0.25, grain=0.06, dirt=0.35)
    noir = k.metal("noir", gain=1.6, rough=0.55, metallic=0.3, grain=0.05, dirt=0.2)
    bleu = k.emit("bleu", "#3AA8FF", 1.8)
    fire = k.emit("bouche", "#FFB060", 1.6)
    cx, cy = -0.12, -0.02
    # 4 pieds courts écartés, anneau de base noir (vide dessous)
    for i, a in enumerate((math.radians(45), math.radians(135), math.radians(225), math.radians(315))):
        fx, fy = cx + 0.62 * math.cos(a), cy - 0.62 * math.sin(a) / g.K
        g.cyl_between(g.G(fx, fy, 0.03), g.G(cx + 0.48 * math.cos(a), cy - 0.48 * math.sin(a) / g.K, 0.30), 0.045,
                      "pied_%d" % i, noir, verts=12)
        g.cyl(fx, fy, 0.0, 0.07, 0.04, "semelle_%d" % i, noir, verts=16)
    g.lathe([(0.40, 0.26), (0.66, 0.28), (0.68, 0.36), (0.40, 0.40)], (cx, cy), "anneau_base", noir, segs=48)
    led = []
    for i in range(7):
        a = math.radians(200 + i * 20)
        led.append(S.sphere(0.022, g.G(cx + 0.68 * math.cos(a), cy - 0.68 * math.sin(a) / g.K, 0.33), bleu, "led_%d" % i, seg=8, rings=4))
    g.join(led, "leds_base")
    # capsule lisse verticale
    r, z0, z1 = 0.56, 0.36, 2.30
    prof = [(0.001, z0), (0.30, z0 + 0.02)] + [(r * math.sin(math.pi / 2 * i / 6), z0 + 0.25 - 0.25 * math.cos(math.pi / 2 * i / 6))
                                              for i in range(2, 7)]
    prof += [(r, z1 - r)] + [(r * math.cos(math.pi / 2 * i / 8), z1 - r + r * math.sin(math.pi / 2 * i / 8)) for i in range(1, 8)]
    prof += [(0.001, z1)]
    g.lathe(prof, (cx, cy), "capsule", car, segs=56, smooth_deg=60)
    # anneaux d'induction bleus (bandes épaisses : zones lumineuses >= 8 px HR)
    for z in (1.05, 1.55):
        g.lathe([(r + 0.012, z), (r + 0.012, z + 0.18)], (cx, cy), "induction_%d" % int(z * 100), bleu, segs=56,
                cap_top=False, cap_bottom=False)
        g.lathe([(r + 0.02, z - 0.03), (r + 0.02, z)], (cx, cy), "joint_%d" % int(z * 100), noir, segs=56)
    # fenêtre de coulée à l'avant (bouche)
    S.box((0.30, 0.05, 0.30), g.G(cx, cy + r / g.K + 0.005, 0.72), fire, "fenetre_bouche", bevel_w=0.01)
    S.box((0.40, 0.06, 0.05), g.G(cx, cy + r / g.K + 0.012, 0.895), noir, "cadre_bouche_h", bevel_w=0.005)
    S.box((0.40, 0.06, 0.05), g.G(cx, cy + r / g.K + 0.012, 0.545), noir, "cadre_bouche_b", bevel_w=0.005)
    # mât d'évacuation caréné, arrière droit (la cheminée), bandeau bleu
    mx, my = 0.66, -0.62
    zt = KEY[10]["chimney"][0][2]
    g.box(mx, my, 0.0, 0.24, 0.24, zt - 0.08, "mat", car, bevel_w=0.06)
    g.box(mx, my, zt - 0.08, 0.20, 0.20, 0.08, "event", noir, bevel_w=0.03)
    S.box((0.08, 0.02, 0.60), g.G(mx, my + 0.12 / g.K + 0.01, 1.10), bleu, "bandeau_mat", bevel_w=0)
    g.cyl_between(g.G(mx - 0.12, my + 0.05, 0.80), g.G(cx + 0.45, cy - 0.20, 0.95), 0.05, "liaison", noir, verts=16)
    S.box((0.14, 0.14, 0.01), g.G(mx, my, zt + 0.002), k.soot(), "gueule", bevel_w=0)
    k.halo(cx, 0.60, 0.70, "#FFB060", 7.0, "halo_bouche")
    k.halo(cx, cy + 0.45, 1.30, "#3AA8FF", 4.0, "halo_anneaux")
    if even:
        # écran latéral sur bras articulé et antenne fouet (flanc gauche)
        ex, ey, ez = -0.98, 0.05, 1.25
        g.cyl_between(g.G(cx - 0.50, cy, 1.20), g.G(ex + 0.20, ey, ez - 0.05), 0.035, "bras_ecran", noir, verts=12)
        scr = S.box((0.44, 0.04, 0.40), g.G(ex, ey, ez), noir, "ecran", bevel_w=0.015)
        scr.rotation_euler = (math.radians(-12), 0, math.radians(-18))
        face = S.box((0.38, 0.01, 0.34), g.G(ex + 0.006, ey + 0.016, ez), bleu, "ecran_face", bevel_w=0)
        face.rotation_euler = (math.radians(-12), 0, math.radians(-18))
        g.cyl(ex - 0.12, ey - 0.05, ez + 0.20, 0.012, 1.10, "antenne_fouet", noir, verts=6, bevel_w=0)
        S.sphere(0.03, g.G(ex - 0.12, ey - 0.05, ez + 1.31), bleu, "pointe_antenne", seg=10, rings=5)
        k.halo(ex, ey + 0.2, ez, "#3AA8FF", 3.0, "halo_ecran")


# -------------------------------------------------------------------------------------------------
# Époque 11 · Titane : four vertical élancé à 4 ailerons, sur pieds ; pièce : aileron dorsal
# -------------------------------------------------------------------------------------------------
def fin(k, x, y, ang, r_in, z_lo, z_hi, r_out, z_out, name, mat, thick=0.035):
    """Aileron triangulaire dans le plan vertical radial d'angle ang (Blender) autour de (x, y) de jeu."""
    g = k.g
    cx, cy, _ = g.G(x, y, 0)
    u = (math.cos(ang), math.sin(ang), 0.0)
    pts = [(r_in, z_lo), (r_out, z_out), (r_in * 0.9, z_hi)]
    return g.slab(pts, (cx, cy, 0.0), u, (0, 0, 1), thick, name, mat)


def e11(k, even):
    g, S = k.g, k.S
    alli = k.metal("alliage", gain=1.0, rough=0.35, metallic=0.25, rust="#8A8478", rust_amount=0.35, dirt=0.45, grain=0.1)
    tit = k.metal("titane", gain=1.6, rough=0.3, metallic=0.75, dirt=0.3, grain=0.08)
    ligne = k.emit("ligne", "#BFE6FF", 1.7)
    fire = k.emit("bouche", "#FFB060", 1.6)
    cx, cy = -0.12, -0.05
    # 4 pieds en V (vides au sol)
    for i, a in enumerate((math.radians(45), math.radians(135), math.radians(225), math.radians(315))):
        fx, fy = cx + 0.78 * math.cos(a), cy - 0.78 * math.sin(a) / g.K
        for da in (-0.25, 0.25):
            g.cyl_between(g.G(fx, fy, 0.02), g.G(cx + 0.30 * math.cos(a + da), cy - 0.30 * math.sin(a + da) / g.K, 0.62), 0.032,
                          "pied_%d_%d" % (i, int(da > 0)), tit, verts=10)
        g.cyl(fx, fy, 0.0, 0.06, 0.04, "semelle_%d" % i, tit, verts=12)
    # tour élancée effilée
    prof = [(0.001, 0.50), (0.30, 0.52), (0.42, 0.64), (0.42, 1.30), (0.36, 1.85), (0.24, 2.30), (0.12, 2.55), (0.001, 2.66)]
    g.lathe(prof, (cx, cy), "tour", alli, segs=48, smooth_deg=50)
    g.lathe([(0.425, 1.05), (0.42, 1.22)], (cx, cy), "bague_lumineuse", ligne, segs=48, cap_top=False, cap_bottom=False)
    # bouche : fente verticale avant
    S.box((0.16, 0.05, 0.30), g.G(cx, cy + 0.42 / g.K - 0.01, 0.82), fire, "bouche_fente", bevel_w=0.01)
    # 4 ailerons de refroidissement (diagonales), lignes lumineuses sur le bord d'attaque
    for i, a in enumerate((math.radians(35), math.radians(145), math.radians(215), math.radians(325))):
        fin(k, cx, cy, a, 0.40, 0.58, 1.70, 0.98, 0.52, "aileron_%d" % i, alli)
        bx, by, _ = g.G(cx, cy, 0)
        g.cyl_between((bx + 0.98 * math.cos(a), by + 0.98 * math.sin(a), 0.54),
                      (bx + 0.40 * 0.9 * math.cos(a), by + 0.40 * 0.9 * math.sin(a), 1.68), 0.022, "ligne_%d" % i, ligne, verts=8)
    # évent effilé à l'arrière droit (la cheminée)
    mx, my = 0.62, -0.62
    zt = KEY[11]["chimney"][0][2]
    g.lathe([(0.15, 0.0), (0.14, 0.6), (0.12, zt - 0.30), (0.09, zt - 0.05), (0.10, zt)], (mx, my), "event", alli, segs=32,
            cap_top=False)
    g.cyl(mx, my, zt - 0.10, 0.09, 0.09, "fond_event", k.soot(), verts=24, bevel_w=0)
    fin(k, mx, my, math.radians(0), 0.13, 0.30, 1.20, 0.32, 0.25, "aileron_event", tit, thick=0.03)
    g.lathe([(0.145, 0.95), (0.14, 1.12)], (mx, my), "ligne_event", ligne, segs=32, cap_top=False, cap_bottom=False)
    k.halo(cx, 0.55, 0.80, "#FFB060", 7.0, "halo_bouche")
    k.halo(cx, cy + 0.4, 1.15, "#BFE6FF", 4.0, "halo_bague")
    if even:
        # aileron dorsal : grand aileron triangulaire au dos du sommet, face à la caméra (plan est-ouest)
        bx, by, _ = g.G(cx, cy - 0.28, 0)
        pts = [(-0.66, 1.18), (0.66, 1.18), (0.12, 2.62), (-0.05, 2.62)]
        g.slab(pts, (bx, by, 0.0), (1, 0, 0), (0, 0, 1), 0.05, "aileron_dorsal", tit)
        g.slab([(-0.58, 1.24), (0.58, 1.24), (0.08, 2.45), (-0.03, 2.45)], (bx, by - 0.035, 0.0), (1, 0, 0), (0, 0, 1), 0.02,
               "aileron_dorsal_ame", alli)
        for sx in (-1, 1):
            g.cyl_between((bx + sx * 0.64, by - 0.03, 1.20), (bx + sx * 0.10, by - 0.03, 2.58), 0.022,
                          "ligne_dorsale_%d" % (sx + 1), ligne, verts=8)


# -------------------------------------------------------------------------------------------------
# Époque 12 · Supraconducteurs : creuset en lévitation entre 2 anneaux ; pièce : pylône cryogénique
# -------------------------------------------------------------------------------------------------
def e12(k, even):
    g, S = k.g, k.S
    noir = k.metal("noir", gain=1.6, rough=0.35, metallic=0.5, grain=0.05, dirt=0.25)
    chrome = k.metal("chrome", gain=1.4, rough=0.15, metallic=0.95, grain=0.05, rust="#DDEEFF", rust_amount=0.35, dirt=0.15)
    cyan = k.emit("cyan", "#4AF0FF", 1.8)
    fire = k.emit("bouche", "#FFD080", 1.7)
    cx, cy = -0.12, 0.12
    # socle hexagonal noir bas, fente cyan
    g.frustum(g.regular(cx, cy, 0.50, 6, 0.0), 0.0, g.regular(cx, cy, 0.44, 6, 0.0), 0.16, "socle", noir, bevel_w=0.012)
    g.lathe([(0.47, 0.06), (0.47, 0.10)], (cx, cy), "fente_socle", cyan, segs=6, cap_top=False, cap_bottom=False, smooth_deg=None)
    # anneau inférieur flottant (chrome + bande cyan)
    for z, R in ((0.50, 0.66), (1.62, 0.58)):
        S.torus(R, 0.075, g.G(cx, cy, z), chrome, "anneau_%d" % int(z * 100), minor_seg=16)
        g.lathe([(R - 0.07, z - 0.05), (R - 0.07, z + 0.05)], (cx, cy), "bande_%d" % int(z * 100), cyan, segs=48,
                cap_top=False, cap_bottom=False)
    # creuset noir en lévitation entre les deux anneaux, fenêtre de bain (bouche)
    g.lathe([(0.001, 0.80), (0.24, 0.82), (0.36, 0.95), (0.40, 1.12), (0.38, 1.28), (0.30, 1.36)], (cx, cy), "creuset", noir,
            segs=48, cap_top=False)
    S.torus(0.30, 0.03, g.G(cx, cy, 1.36), chrome, "levre")
    g.cyl(cx, cy, 1.30, 0.29, 0.04, "bain", fire, verts=40, bevel_w=0)
    S.box((0.26, 0.04, 0.14), g.G(cx, cy + 0.40 / g.K - 0.01, 1.08), fire, "fenetre_bain", bevel_w=0.008)
    # colonne d'évacuation en blocs flottants (arrière droit)
    mx, my = 0.62, -0.62
    zt = KEY[12]["chimney"][0][2]
    blocks = [(0.0, 0.42, 0.17), (0.50, 0.92, 0.155), (1.00, 1.40, 0.14), (1.48, 1.84, 0.13), (1.92, zt, 0.12)]
    for i, (z0, z1, r) in enumerate(blocks):
        g.frustum(g.regular(mx, my, r, 8, math.pi / 8), z0, g.regular(mx, my, r * 0.92, 8, math.pi / 8), z1, "bloc_%d" % i,
                  chrome if i % 2 else noir, bevel_w=0.01)
        if i:
            g.cyl(mx, my, z0 - 0.06, r * 0.5, 0.05, "lueur_%d" % i, cyan, verts=16, bevel_w=0)
    g.cyl(mx, my, zt - 0.06, 0.07, 0.07, "gueule", k.soot(), verts=16, bevel_w=0)
    k.halo(cx, 0.60, 1.05, "#FFD080", 6.0, "halo_bouche")
    k.halo(cx, cy + 0.3, 0.50, "#4AF0FF", 4.0, "halo_anneaux")
    if even:
        # pylône cryogénique givré à gauche, bobine cyan au sommet, tuyau vers le socle
        px, py = -0.92, -0.25
        givre = k.metal("givre", gain=0.9, rough=0.6, metallic=0.1, grain=0.2, dirt=0.2)
        g.frustum(g.regular(px, py, 0.13, 6, 0.0), 0.0, g.regular(px, py, 0.09, 6, 0.0), 1.55, "pylone", noir, bevel_w=0.01)
        for z in (0.30, 0.70, 1.10):
            g.cyl(px, py, z, 0.13, 0.10, "givre_%d" % int(z * 100), givre, verts=20, bevel_w=0.02)
        for i in range(4):
            S.torus(0.16, 0.035, g.G(px, py, 1.58 + i * 0.07), cyan if i % 2 == 0 else chrome, "bobine_%d" % i)
        S.sphere(0.08, g.G(px, py, 1.90), chrome, "tete", seg=16, rings=8)
        g.pipe([g.G(px + 0.10, py, 0.25), g.G(px + 0.35, py + 0.15, 0.12), g.G(cx - 0.40, cy, 0.10)], 0.035, "tuyau_cryo", chrome)
        k.halo(px, py, 1.65, "#4AF0FF", 3.0, "halo_pylone")


# -------------------------------------------------------------------------------------------------
# Époque 13 · Fusion : sphère sur trépied, tore de plasma ; pièce : second tore incliné
# -------------------------------------------------------------------------------------------------
def e13(k, even):
    g, S = k.g, k.S
    cer = k.metal("ceramique", gain=1.0, rough=0.4, metallic=0.05, grain=0.08, dirt=0.45, rust="#9A9284", rust_amount=0.3)
    cuivre = k.metal("cuivre", gain=1.5, rough=0.3, metallic=0.85, dirt=0.3)
    plasma = k.emit("plasma", "#FF4FD8", 2.0)
    coeur = k.emit("coeur", "#FF9A3A", 1.8)
    cx, cy, zc, R = -0.12, 0.08, 1.45, 0.55
    # trépied de cuivre (grand vide sous la sphère)
    for i in range(3):
        a = math.radians(90 + 120 * i + 30)
        fx, fy = cx + 0.80 * math.cos(a), cy - 0.80 * math.sin(a) / g.K
        g.cyl_between(g.G(fx, fy, 0.02), g.G(cx + 0.28 * math.cos(a), cy - 0.28 * math.sin(a) / g.K, zc - 0.45), 0.05,
                      "pied_%d" % i, cuivre, verts=12)
        g.cyl(fx, fy, 0.0, 0.09, 0.05, "semelle_%d" % i, cuivre, verts=16)
    S.sphere(R, g.G(cx, cy, zc), cer, "sphere", seg=48, rings=24)
    S.torus(R + 0.005, 0.03, g.G(cx, cy, zc), cuivre, "equateur")
    S.torus(0.30, 0.05, g.G(cx, cy, zc - R + 0.08), cuivre, "collier_bas")
    # fenêtre du cœur (bouche) à l'avant
    S.cylinder(0.16, 0.06, g.G(cx, cy + R / g.K - 0.03, zc - 0.10), coeur, "coeur", verts=32, rot=(math.radians(60), 0, 0), bevel_w=0)
    S.torus(0.17, 0.03, g.G(cx, cy + R / g.K - 0.015, zc - 0.10), cuivre, "cadre_coeur", rot=(math.radians(60), 0, 0))
    # tore de plasma horizontal + 3 injecteurs
    S.torus(0.88, 0.075, g.G(cx, cy, zc), plasma, "tore", major_seg=72, minor_seg=16)
    bx, by, _ = g.G(cx, cy, 0)
    for i in range(3):
        a = math.radians(60 + 120 * i)
        g.cyl_between((bx + (R - 0.02) * math.cos(a), by + (R - 0.02) * math.sin(a), zc),
                      (bx + 0.80 * math.cos(a), by + 0.80 * math.sin(a), zc), 0.035, "injecteur_%d" % i, cuivre, verts=12)
    # flèche d'évacuation à l'arrière droit
    mx, my = 0.62, -0.62
    zt = KEY[13]["chimney"][0][2]
    g.lathe([(0.14, 0.0), (0.12, 0.30), (0.11, zt - 0.20), (0.13, zt)], (mx, my), "fleche", cer, segs=32, cap_top=False)
    for z in (0.6, 1.2, 1.8):
        S.torus(0.12, 0.025, g.G(mx, my, z), cuivre, "bague_%d" % int(z * 10))
    g.cyl(mx, my, zt - 0.10, 0.11, 0.09, "fond", k.soot(), verts=24, bevel_w=0)
    S.torus(0.115, 0.02, g.G(mx, my, zt - 0.03), plasma, "lueur_fleche")
    k.halo(cx, 0.55, zc - 0.1, "#FF9A3A", 6.0, "halo_coeur")
    k.halo(cx, cy + 0.5, zc, "#FF4FD8", 6.0, "halo_tore")
    if even:
        o = S.torus(0.78, 0.06, g.G(cx, cy, zc + 0.05), plasma, "tore_incline", major_seg=72, minor_seg=16)
        o.rotation_euler = (math.radians(55), math.radians(20), 0)
        for sgn in (-1, 1):
            p = (bx + sgn * 0.74, by, zc + 0.05)
            S.sphere(0.07, p, cuivre, "noeud_%d" % (sgn + 1), seg=16, rings=8)


# -------------------------------------------------------------------------------------------------
# Époque 14 · Orbite : four solaire, pétales-miroirs dorés ; pièce : pétale arrière supplémentaire
# -------------------------------------------------------------------------------------------------
def petal(k, cx, cy, ang, r0, z0, r1, z1, w0, w1, name, mat, back_mat, thick=0.03):
    """Pétale trapézoïdal de (r0, z0) à (r1, z1) dans la direction ang (Blender), autour de (cx, cy) Blender."""
    g = k.g
    from mathutils import Vector
    u = Vector((math.cos(ang), math.sin(ang), 0.0))
    t = Vector((-math.sin(ang), math.cos(ang), 0.0))
    p0 = Vector((cx, cy, z0)) + u * r0
    p1 = Vector((cx, cy, z1)) + u * r1
    axis = (p1 - p0).normalized()
    nrm = axis.cross(t).normalized()
    quad = [p0 - t * w0, p0 + t * w0, p1 + t * w1, p1 - t * w1]
    # léger creux : les bords se relèvent vers le foyer
    mid0, mid1 = (p0 + nrm * 0.0), (p1 + nrm * 0.0)
    front = [tuple(q + nrm * (thick / 2)) for q in quad]
    back = [tuple(q - nrm * (thick / 2)) for q in quad]
    o = g.loft([back, front], name, mat, True, True, None, 0.004)
    return o


def e14(k, even):
    g, S = k.g, k.S
    blanc = k.metal("blanc", gain=1.0, rough=0.4, metallic=0.1, grain=0.08, dirt=0.45)
    orf = k.metal("or", gain=1.25, rough=0.25, metallic=0.95, grain=0.35, grain_scale=25.0, dirt=0.3)
    cell = k.glossy("cellules", gain=1.0, rough=0.25, metallic=0.3)
    eclat = k.emit("creuset", "#FFF2C0", 2.2)
    rouge = k.emit("balise", "#FF2A2A", 2.0)
    cx, cy = -0.12, 0.10
    g.frustum(g.regular(cx, cy, 0.42, 6, 0.0), 0.0, g.regular(cx, cy, 0.36, 6, 0.0), 0.14, "base", blanc, bevel_w=0.01)
    g.cyl(cx, cy, 0.14, 0.12, 1.10, "colonne", blanc, verts=24)
    S.torus(0.13, 0.03, g.G(cx, cy, 0.62), orf, "bague_colonne")
    # creuset éclatant au foyer (bouche)
    g.lathe([(0.10, 1.24), (0.22, 1.30), (0.26, 1.42), (0.24, 1.48)], (cx, cy), "creuset", blanc, segs=32, cap_top=False)
    g.cyl(cx, cy, 1.40, 0.22, 0.05, "foyer", eclat, verts=32, bevel_w=0)
    S.sphere(0.12, g.G(cx, cy, 1.52), eclat, "eclat", seg=24, rings=12)
    # corolle de 6 pétales-miroirs dorés (dos en cellules bleu nuit)
    bx, by, _ = g.G(cx, cy, 0)
    for i in range(6):
        a = math.radians(30 + 60 * i)
        petal(k, bx, by, a, 0.22, 0.78, 1.03, 1.42, 0.07, 0.26, "petale_%d" % i, orf, cell)
        g.cyl_between((bx, by, 0.70), (bx + 0.55 * math.cos(a), by + 0.55 * math.sin(a), 1.07), 0.02, "hauban_%d" % i, blanc, verts=8)
    # mât-balise à l'arrière droit (cheminée), balise rouge
    mx, my = 0.66, -0.62
    zt = KEY[14]["chimney"][0][2]
    g.cyl(mx, my, 0.0, 0.10, zt - 0.10, "mat", blanc, verts=24)
    for z in (0.7, 1.5):
        S.torus(0.105, 0.025, g.G(mx, my, z), orf, "bague_mat_%d" % int(z * 10))
    g.cyl(mx, my, zt - 0.10, 0.10, 0.10, "chapeau", orf, verts=24, r2=0.07)
    S.sphere(0.075, g.G(mx, my, zt + 0.03), rouge, "balise", seg=16, rings=8)
    k.halo(cx, cy + 0.2, 1.45, "#FFF2C0", 8.0, "halo_creuset")
    k.halo(mx, my, zt + 0.03, "#FF2A2A", 2.0, "halo_balise")
    if even:
        petal(k, bx, by, math.radians(90), 0.25, 0.85, 0.98, 1.95, 0.08, 0.30, "petale_arriere", orf, cell, thick=0.035)
        g.cyl_between((bx, by + 0.15, 0.80), (bx, by + 0.70, 1.65), 0.025, "hauban_arriere", blanc, verts=8)


# -------------------------------------------------------------------------------------------------
# Époque 15 · Légende : creuset en couronne flottant, halo ; pièce : seconde couronne
# -------------------------------------------------------------------------------------------------
def crown(k, x, y, z0, r, h_band, spikes, mat, gem, name):
    g, S = k.g, k.S
    g.lathe([(r * 0.92, z0), (r, z0 + 0.04), (r, z0 + h_band - 0.04), (r * 1.04, z0 + h_band)], (x, y), name + "_bandeau", mat,
            segs=48, cap_top=False, cap_bottom=False)
    g.lathe([(r * 0.86, z0), (r * 0.86, z0 + h_band)], (x, y), name + "_interieur", mat, segs=48, cap_top=False, cap_bottom=False)
    bx, by, _ = g.G(x, y, 0)
    for i, (a_deg, hh, rr) in enumerate(spikes):
        a = math.radians(a_deg)
        px, py = bx + r * math.cos(a), by + r * math.sin(a)
        S.cylinder(rr, hh, (px, py, z0 + h_band + hh / 2 - 0.02), mat, "%s_fleche_%d" % (name, i), verts=12, radius2=0.0,
                   bevel_w=0)
        S.sphere(rr * 0.9, (px, py, z0 + h_band * 0.55), gem, "%s_gemme_%d" % (name, i), seg=12, rings=6)


def e15(k, even):
    g, S = k.g, k.S
    orb = k.metal("orblanc", gain=0.95, rough=0.28, metallic=0.85, grain=0.1, dirt=0.35, rust="#B8A880", rust_amount=0.3)
    nacre = k.metal("nacre", gain=0.95, rough=0.3, metallic=0.2, grain=0.08, dirt=0.35)
    lum = k.emit("lumiere", "#FFF2C0", 2.0)
    cx, cy = -0.12, 0.10
    # petit plot émetteur au sol (seul contact), disque flottant au-dessus (vide)
    g.cyl(cx, cy, 0.0, 0.16, 0.05, "plot", nacre, verts=24)
    g.cyl(cx, cy, 0.05, 0.10, 0.015, "plot_lueur", lum, verts=24, bevel_w=0)
    g.lathe([(0.001, 0.30), (0.58, 0.30), (0.66, 0.36), (0.62, 0.42), (0.001, 0.42)], (cx, cy), "disque", nacre, segs=6,
            smooth_deg=None, bevel_w=0.01)
    g.lathe([(0.665, 0.355), (0.665, 0.375)], (cx, cy), "liseré_disque", lum, segs=6, cap_top=False, cap_bottom=False,
            smooth_deg=None)
    # couronne flottante (vide sous la couronne), cœur lumineux
    spikes = [(0, 0.55, 0.075), (51, 0.75, 0.07), (103, 0.95, 0.08), (154, 0.70, 0.07), (206, 0.50, 0.065), (257, 0.45, 0.06),
              (309, 0.48, 0.065)]
    crown(k, cx, cy, 0.58, 0.48, 0.30, spikes, orb, lum, "couronne")
    S.sphere(0.24, g.G(cx, cy, 0.86), lum, "coeur", seg=32, rings=16)
    # anneau-halo
    S.torus(0.80, 0.045, g.G(cx, cy, 1.12), lum, "anneau_halo", major_seg=72, minor_seg=10)
    # flèche-cheminée arrière droite, creuse
    mx, my = 0.45, -0.45
    zt = KEY[15]["chimney"][0][2]
    g.lathe([(0.15, 0.62), (0.12, 0.80), (0.11, zt - 0.40), (0.13, zt - 0.08), (0.12, zt)], (mx, my), "fleche_cheminee", orb, segs=32,
            cap_top=False)
    g.cyl(mx, my, zt - 0.10, 0.10, 0.09, "fond", k.soot(), verts=24, bevel_w=0)
    S.torus(0.13, 0.02, g.G(mx, my, zt - 0.20), lum, "bague_fleche")
    g.cyl_between(g.G(mx, my, 0.80), g.G(cx + 0.25, cy - 0.10, 0.78), 0.035, "liaison", orb, verts=12)
    # particules (petites sphères lumineuses)
    import random
    rnd = random.Random(15)
    parts = []
    for i in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.55, 0.95)
        z = rnd.uniform(0.5, 1.9)
        px, py, _ = g.G(cx, cy, 0)
        parts.append(S.sphere(rnd.uniform(0.018, 0.03), (px + rr * math.cos(a), py + rr * math.sin(a), z), lum, "part_%d" % i,
                              seg=8, rings=4))
    g.join(parts, "particules")
    k.halo(cx, cy + 0.3, 0.9, "#FFF2C0", 8.0, "halo_coeur")
    k.halo(cx, cy, 0.15, "#FFF2C0", 4.0, "halo_plot")
    if even:
        spikes2 = [(30, 0.30, 0.06), (102, 0.36, 0.06), (174, 0.30, 0.055), (246, 0.26, 0.05), (318, 0.28, 0.055)]
        crown(k, cx, cy - 0.05, 1.62, 0.32, 0.16, spikes2, orb, lum, "couronne2")
        S.sphere(0.10, g.G(cx, cy - 0.05, 1.70), lum, "coeur2", seg=24, rings=12)


BUILDERS = {2: e2, 3: e3, 4: e4, 5: e5, 6: e6, 7: e7, 8: e8, 9: e9, 10: e10, 11: e11, 12: e12, 13: e13, 14: e14, 15: e15}


def build(S, C, variant):
    import geo
    geo.S = S
    n = int(variant[1:])
    k = Kit(S, C, geo, n)
    if n == 2:
        e1_piece(k)
        return
    e = PRM.epoch_of(n)
    BUILDERS[e](k, PRM.is_even(n))
