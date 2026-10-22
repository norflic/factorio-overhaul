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
    1: {"chimney": [(0.70, -1.20, None), (0.29, -0.78, 0.826)],
        "smoke": (0.29, -0.78, 0.976),          # haut du chapeau chinois (z 0,826 + 0,15)
        "emit": []},
    2: {"chimney": [(0.66, -0.50, 1.37)],      # +0,05 : O de n3 au-dessus de celui de n2 (0,61)
        "emit": [(-0.19, 0.95, 0.24, "#FF6A20")]},
    3: {"chimney": [(0.55, -0.50, 1.40)],
        "emit": [(-0.25, 0.95, 0.17, "#FFB050"), (-0.25, 0.44, 0.62, "#FFC060")]},
    4: {"chimney": [(0.55, -0.55, 1.50)],      # +0,06 : O 0,66 -> 0,70 (pas d'O non nul, mineur 5)
        "emit": [(-0.30, 0.90, 0.66, "#FF8C1A"), (0.62, 0.95, 0.40, "#FF8C1A")]},
    5: {"chimney": [(0.48, -0.52, 1.60)],      # +0,07 : O 0,72 -> 0,76 (pas ≥ 0,03 sur l'époque 4)
        "emit": [(-0.08, 0.95, 0.20, "#FF4A10"), (-0.08, 0.55, 0.60, "#FF4A10")]},
    6: {"chimney": [(0.62, -0.55, 1.64)],      # +0,09 : O 0,72 -> 0,78
        "emit": [(-0.15, 0.98, 0.30, "#FF8A1E"), (-0.15, 0.20, 1.20, "#60D0FF")]},
    7: {"chimney": [(0.60, -0.55, 1.66)],
        "emit": [(-0.10, 0.95, 0.15, "#B070FF"), (-0.10, 0.15, 1.00, "#B070FF")]},
    8: {"chimney": [(0.62, -0.55, 1.95)],
        "emit": [(-0.15, 0.95, 0.12, "#A8FF3A"), (-0.15, 0.15, 0.70, "#A8FF3A")]},
    9: {"chimney": [(0.60, -0.50, 1.88)],
        "emit": [(-0.15, 0.95, 0.20, "#5CFF4A"), (-0.15, 0.40, 0.85, "#5CFF4A")]},
    10: {"chimney": [(0.72, -0.62, 2.02)],
         "emit": [(-0.14, 0.42, 0.74, "#FFB060"), (-0.14, 0.30, 1.30, "#3AA8FF")]},
    11: {"chimney": [(0.80, -0.55, 2.36)],     # évent déplacé et relevé : O 1,20 -> 1,22
         "emit": [(-0.14, 0.33, 0.80, "#FFB060"), (-0.14, 0.18, 1.15, "#BFE6FF")]},
    12: {"chimney": [(0.62, -0.62, 2.35)],     # colonne relevée : O 1,25 -> 1,32
         "emit": [(-0.12, 0.40, 1.05, "#FFD080"), (-0.12, 0.12, 0.55, "#4AF0FF")]},
    13: {"chimney": [(0.62, -0.62, 2.45)],
         "emit": [(-0.12, 0.45, 1.45, "#FF9A3A"), (-0.12, 0.08, 1.45, "#FF4FD8")]},
    14: {"chimney": [(0.55, -0.66, 2.58)],     # mât-balise déplacé (x 0,66 -> 0,55) pour séparer les sommets
         "emit": [(-0.10, 0.50, 0.12, "#FFC060"), (-0.10, 0.12, 1.78, "#FFE6A0"), (0.68, -0.66, 2.53, "#FF2A2A")]},
    15: {"chimney": [(0.36, -0.24, 3.24)],
         "emit": [(-0.10, 0.45, 1.11, "#FFF2C0"), (-0.10, 0.10, 1.38, "#FFC060"), (-0.10, 0.10, 0.10, "#FFF2C0")]},
}


# Couleur du feu de la bouche par époque (« feu de l'ère », correction V3, majeur 1) : aux époques 2 à 5, la
# couleur émissive de la bible §1.5 (forge #FF6A20, ambre, orange #FF8C1A, braise #FF4A10) ; ensuite, la
# bouche garde un feu chaud et la couleur d'époque vit dans les lueurs de décor (KEY[e]["emit"]).
MOUTH = {2: "#FF6A20", 3: "#FFB050", 4: "#FF8C1A", 5: "#FF4A10", 6: "#FF8A1E", 7: "#B070FF", 8: "#A8FF3A", 9: "#5CFF4A",
         10: "#FFB060", 11: "#FFB060", 12: "#FFD080", 13: "#FF9A3A", 14: "#FFC060", 15: "#FFC060"}

# Couleurs émissives déclarées par époque (matériaux de k.emit) : cibles de la mesure de couleur composée
# (measure_d1.py : chaque pixel lumineux est rapporté à la cible de teinte la plus proche).
EMIT_TARGETS = {2: ["#FF6A20"], 3: ["#FFB050", "#FFC060"], 4: ["#FF8C1A", "#FFB040"], 5: ["#FF4A10"],
                6: ["#FF8A1E", "#60D0FF"], 7: ["#B070FF", "#8A50E0"], 8: ["#A8FF3A"], 9: ["#5CFF4A"],
                10: ["#FFB060", "#3AA8FF"], 11: ["#FFB060", "#BFE6FF"], 12: ["#FFD080", "#4AF0FF"],
                13: ["#FF9A3A", "#FF4FD8"], 14: ["#FFC060", "#FFE6A0", "#FF2A2A"], 15: ["#FFC060", "#FFF2C0"]}

# Clés des matériaux émissifs du FEU DE MARCHE (couche glow : working_visualisations, fadeout, flicker) ;
# toutes les autres sont des lueurs de DÉCOR (couche glowdeco : always_draw, sans flicker).
FEU_KEYS = {"bouche", "ambre", "lave", "flamme", "arc", "bain", "uranium", "coeur", "creuset"}


def _variants():
    v = {}
    for n in PRM.RENDERED:
        e = PRM.epoch_of(n)
        wins = [(x, y, z if z is not None else 0.0, 0.45, 1.0) for (x, y, z, _c) in KEY[e]["emit"]]
        d = {"dest": "levels/furnace/n%02d" % n, "anchor_tiles": (0.0, 0.0), "level": n, "epoch": e,
             "halo": PRM.halo_windows(n, wins), "margin_px": int(64 * (0.15 + PRM.halo_layer(n)["r1"])) + 8}
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
        self.k_alb = PRM.ALBEDO_K.get(self.e, 1.0)

    def metal(self, key, hexc=None, gain=2.2, rough=0.42, metallic=0.55, grain=0.22, rust=None, rust_amount=0.0,
              dirt=0.5, seed=0.0, grain_scale=55.0):
        name = "%s_%d" % (key, self.e)
        if name not in self._m:
            col = PRM.hex_lin(hexc or self.pal[key], gain * self.k_alb)
            rc = PRM.hex_lin(rust, self.k_alb) if isinstance(rust, str) else rust
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
            self._m[name] = self.S.mat_metal(name, PRM.hex_lin(hexc or self.pal[key], gain * self.k_alb), rough=rough,
                                             metallic=metallic, grain=0.06, grain_scale=20.0, dirt=0.3, seed=self.e)
        return self._m[name]

    def emit(self, key, hexc, strength=1.4, cls=None, tex=True, scale=14.0, crust=None):
        """Matériau émissif (correction V3, problème majeur 1). cls : « feu » (feu de MARCHE : couche glow,
        working_visualisations, fadeout, flicker) ou « decor » (couche glowdeco, always_draw) ; par défaut
        selon la clé (FEU_KEYS). La force est plafonnée pour que le 2e canal reste ≤ 0,6 en linéaire : la
        couleur composée garde sa teinte (le premier aperçu saturait deux canaux : jaune citron). Le matériau
        froid (fo_cold) remplace l'émetteur dans la couche principale : braise éteinte sombre pour le feu,
        verre ou métal teinté sombre pour le décor."""
        name = "emit_%s_%d" % (key, self.e)
        if name not in self._m:
            col = PRM.hex_lin(hexc)
            c2 = sorted(col, reverse=True)[1]
            # plafond : 2e canal ≤ 0,6 en linéaire (sRGB ≤ 204) ; les couleurs pâles (#FFF2C0, #BFE6FF, #4AF0FF)
            # passent SOUS 1 : sinon deux canaux saturent à 255 une fois la couche principale ajoutée
            s = min(strength, 1.6, 0.6 / max(c2, 1e-3))
            cls = cls or ("feu" if key in FEU_KEYS else "decor")
            if tex:
                cru = crust if crust is not None else (0.30 if cls == "feu" else 0.62)
                m = self.g.mat_emit_tex(name, col, s, scale=scale, crust=cru, core=0.28 if cls == "feu" else 0.18,
                                        seed=float(self.e) + len(self._m))
            else:
                m = self.S.mat_emissive(name, col, strength=s)
            m["fo_emit_class"] = cls
            if cls == "feu":
                m["fo_cold"] = list(PRM.hex_lin("#241812"))
                m["fo_cold_rough"], m["fo_cold_metal"] = 0.8, 0.05
            else:
                m["fo_cold"] = [0.010 + 0.06 * c for c in col]
                m["fo_cold_rough"], m["fo_cold_metal"] = 0.3, 0.3
            self._m[name] = m
        return self._m[name]

    def cache(self, key, fn):
        if key not in self._m:
            self._m[key] = fn()
        return self._m[key]

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
# Époque 1 · Pionnier : pièce du niveau 2 (hotte et conduit de fumée en tôle rivetée, arrière droit)
# -------------------------------------------------------------------------------------------------
# Le haut du sprite vanilla est plat (-1,09 à -1,28 tuile, mesuré) : la pièce n'est visible que si elle
# DÉPASSE (F42). Masque au pixel par l'alpha du sprite vanilla (comme la variante « four » de V0) : la pièce
# est DERRIÈRE le four. Elle se place donc là où « derrière » est naturel : un conduit de tôle rivetée qui
# monte de l'arrière du toit, juste à gauche de la cheminée vanilla (x 0,18 à 0,42, où le toit vanilla est
# le plus bas : -1,00 à -1,03), coiffé d'une hotte évasée et d'un chapeau chinois. Premier essai (hotte
# posée sur la bouche de la cheminée vanilla) rejeté sur aperçu : le rebord vanilla passait devant, la
# pièce se lisait comme une tache derrière la cheminée.
E1_STACK = {"x": 0.29, "y": -0.78, "r": 0.13}


def e1_piece(k):
    g, S = k.g, k.S
    # tôle réchauffée (correction V3, mineur 3 : le chapeau gris mauve froid, saturation 0,21, détonnait sur le
    # four vanilla chaud, 0,36) : fer rouillé brun chaud, rouille plus étendue
    tole = k.metal("fer", "#64503C", gain=1.9, rough=0.40, metallic=0.5, rust="#6A3A1E", rust_amount=0.6, dirt=0.55,
                   grain=0.28)
    band = k.metal("bande", "#3A3430", gain=2.2, rough=0.32, metallic=0.8, dirt=0.35)
    riv = k.metal("rivet", "#8A7A62", gain=2.6, rough=0.25, metallic=0.9, grain=0.1, dirt=0.15)
    st = E1_STACK
    xc, yc, r = st["x"], st["y"], st["r"]
    zt = KEY[1]["chimney"][1][2]            # haut du conduit (sortie de fumée sous le chapeau)
    # conduit en deux viroles rivetées, cerclages
    g.cyl(xc, yc, 0.0, r, 0.50, "virole_basse", tole, verts=40)
    g.cyl(xc, yc, 0.50, r - 0.008, zt - 0.16 - 0.50, "virole_haute", tole, verts=40)
    for i, z in enumerate((0.36, 0.50, 0.60)):
        g.cyl(xc, yc, z - 0.012, r + 0.012, 0.024, "cerclage_%d" % i, band, verts=40, bevel_w=0.004)
        g.rivet_ring_at(xc, yc, r + 0.010, z + 0.03, 14, 0.011, riv, "rivets_%d" % i, phase=0.2 * i)
    # hotte évasée (tronc de cône riveté) au sommet, lèvre, puis chapeau chinois sur 3 pattes
    g.cyl(xc, yc, zt - 0.18, r, 0.18, "hotte", tole, verts=40, r2=r + 0.10, caps=False, bevel_w=0)
    S.torus(r + 0.10, 0.02, g.G(xc, yc, zt), band, "levre_hotte")
    g.rivet_ring_at(xc, yc, r + 0.06, zt - 0.09, 18, 0.011, riv, "rivets_hotte")
    smoke_mouth(k, xc, yc, zt - 0.005, r + 0.085)
    legs = []
    p0 = g.G(xc, yc, 0)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        rr = r + 0.08
        legs.append(g.cyl_between((p0[0] + rr * math.cos(a), p0[1] + rr * math.sin(a), zt - 0.01),
                                  (p0[0] + rr * math.cos(a), p0[1] + rr * math.sin(a), zt + 0.07), 0.011,
                                  "patte_%d" % i, band, verts=8))
    g.join(legs, "pattes_chapeau")
    g.cyl(xc, yc, zt + 0.065, r + 0.15, 0.085, "chapeau", tole, verts=40, r2=0.03, bevel_w=0.004)
    # chapeau riveté : ourlet et couronne de rivets
    S.torus(r + 0.15, 0.012, g.G(xc, yc, zt + 0.068), band, "ourlet_chapeau")
    g.rivet_ring_at(xc, yc, r + 0.10, zt + 0.098, 12, 0.012, riv, "rivets_chapeau")
    # hauban de fer plat vers la cheminée vanilla (repère de liaison ; masqué là où il passe derrière)
    g.cyl_between(g.G(xc + r, yc, zt - 0.22), g.G(0.60, -0.62, 0.70), 0.010, "hauban", band, verts=6)


# -------------------------------------------------------------------------------------------------
# Époque 2 · Forge : four en briques réfractaires cerclé d'acier, créneaux d'acier, HAUTE cheminée carrée
# en briques à l'arrière droit, porte à volets ; pièce (niveau 4) : soufflet de forge sur le flanc gauche
# -------------------------------------------------------------------------------------------------
E2_CHIM = {"x": 0.66, "y": -0.50, "side": 0.40}


def e2(k, even):
    g, S = k.g, k.S
    bcol = PRM.hex_lin(PRM.PALETTE[2]["brique"], 1.7 * k.k_alb)
    brick = k.cache("brique", lambda: g.mat_brick("brique_2", bcol, (0.085, 0.075, 0.065), soot=0.45, seed=2.0))
    steel = k.metal("acier", gain=2.1, rough=0.34, metallic=0.7, rust="#5A3A26", rust_amount=0.25)
    strap = k.metal("cerclage", gain=2.6, rough=0.32, metallic=0.8, dirt=0.3)
    brass = k.metal("laiton", gain=2.2, rough=0.25, metallic=0.9, grain=0.1, dirt=0.2)
    x0, x1, y0, y1, h = -0.86, 0.48, -0.40, 0.90, 0.60
    cxb, cyb = (x0 + x1) / 2, (y0 + y1) / 2
    g.prism(g.rect(cxb, cyb, x1 - x0, y1 - y0), 0.0, h, "corps_briques", brick, bevel_w=0.015)
    # cerclages horizontaux (bandes d'acier qui ceinturent le bloc) et cornières aux arêtes verticales
    for z in (0.08, 0.44):
        g.prism(g.rect(cxb, cyb, x1 - x0 + 0.03, y1 - y0 + 0.02), z, z + 0.055, "cerclage_%d" % int(z * 100), strap,
                bevel_w=0.008)
    for cx, cy in ((x0, y1), (x1, y1), (x0, y0), (x1, y0)):
        g.box(cx, cy, 0.0, 0.07, 0.07, h + 0.03, "corniere", steel, bevel_w=0.006)
    # rebord d'acier (cornière) autour du toit en briques, créneaux d'acier sur l'avant et les côtés
    rim = []
    for (cx, cy, w, d) in ((cxb, y1, x1 - x0 + 0.06, 0.06), (cxb, y0, x1 - x0 + 0.06, 0.06),
                           (x0, cyb, 0.06, (y1 - y0) * g.K), (x1, cyb, 0.06, (y1 - y0) * g.K)):
        rim.append(g.box(cx, cy, h, w, d, 0.05, "rebord", steel, bevel_w=0.006))
    g.join(rim, "rebord_toit")
    merl = []
    for i in range(6):
        mx = x0 + 0.08 + i * (x1 - x0 - 0.16) / 5
        merl.append(g.box(mx, y1 - 0.01, h + 0.05, 0.14, 0.07, 0.15, "merlon_av_%d" % i, steel, bevel_w=0.008))
    for side, xs in (("g", x0 + 0.01), ("d", x1 - 0.01)):
        for j in range(3):
            my = y1 - 0.34 - j * 0.38
            merl.append(g.box(xs, my, h + 0.05, 0.07, 0.20, 0.15, "merlon_%s_%d" % (side, j), steel, bevel_w=0.008))
    g.join(merl, "creneaux")
    g.rivets([g.G(x0 + 0.08 + i * (x1 - x0 - 0.16) / 5, y1 + 0.03, h + 0.15) for i in range(6)], 0.016, brass, "rivets_merlons")
    # chambre de chauffe arrière : cube d'acier boulonné et cerclé posé sur le toit (casse le toit plat ;
    # signature d'époque « cubes cerclés »), reliée à la cheminée par le carneau
    ry0, ry1 = y0 + 0.02, 0.14
    rcx, rw = cxb + 0.02, x1 - x0 - 0.20
    g.prism(g.rect(rcx, (ry0 + ry1) / 2, rw, ry1 - ry0), h, h + 0.32, "chambre", steel, bevel_w=0.012)
    # chapeau de la chambre (correction V3, mineur 1 : « dalle noire plate et sans détail ») : TROIS tôles
    # rivetées séparées par des joints creux, chacune biseautée (le biseau accroche le soleil), une bouche de
    # chargement à couvercle et une lumière d'échappement. La médiane du corps est tenue par la rugosité et le
    # cerclage sombre, pas par l'albédo (un grand dessus clair portait la médiane de 49 à 75)
    g.prism(g.rect(rcx, (ry0 + ry1) / 2, rw + 0.05, ry1 - ry0 + 0.035), h + 0.32, h + 0.345, "chambre_chapeau", strap,
            bevel_w=0.004)
    plate = k.metal("tole_chambre", "#4A4C50", gain=0.9, rough=0.75, metallic=0.25, rust="#4A2E1E", rust_amount=0.35,
                    dirt=0.6, grain=0.30)
    pw = (rw + 0.02) / 3.0
    for i in range(3):
        px0 = rcx - (rw + 0.02) / 2 + pw * (i + 0.5)
        g.prism(g.rect(px0, (ry0 + ry1) / 2, pw - 0.035, ry1 - ry0 - 0.02), h + 0.345, h + 0.375 + 0.008 * (i % 2),
                "tole_chapeau_%d" % i, plate, bevel_w=0.012)
        g.rivets([g.G(px0 + dx, (ry0 + ry1) / 2 + dy, h + 0.38 + 0.008 * (i % 2)) for dx in (-pw / 2 + 0.05, pw / 2 - 0.05)
                  for dy in (-0.14, 0.0, 0.14)], 0.013, brass, "rivets_tole_%d" % i)
    # bouche de chargement (couvercle bombé à charnière) sur la tôle gauche, lumière d'échappement à droite
    hx = rcx - (rw + 0.02) / 2 + pw * 0.5
    g.cyl(hx, (ry0 + ry1) / 2 + 0.02, h + 0.37, 0.11, 0.05, "col_chargement", strap, verts=24, bevel_w=0.006)
    g.cyl(hx, (ry0 + ry1) / 2 + 0.02, h + 0.42, 0.125, 0.04, "couvercle_chargement", steel, verts=24, r2=0.07,
          bevel_w=0.006)
    S.torus(0.04, 0.010, g.G(hx, (ry0 + ry1) / 2 + 0.02, h + 0.475), brass, "anneau_couvercle")
    ex = rcx + (rw + 0.02) / 2 - pw * 0.5
    g.box(ex, (ry0 + ry1) / 2 + 0.03, h + 0.37, 0.16, 0.10, 0.06, "event_chambre", strap, bevel_w=0.008)
    S.box((0.11, 0.012, 0.025), g.G(ex, (ry0 + ry1) / 2 + 0.03 + 0.05 / g.K + 0.004, h + 0.40),
          k.emit("bouche", MOUTH[2], 1.6), "lumiere_echappement", bevel_w=0)
    for z in (h + 0.06, h + 0.22):
        g.prism(g.rect(rcx, (ry0 + ry1) / 2, rw + 0.025, ry1 - ry0 + 0.02), z, z + 0.04, "chambre_cercle_%d" % int(z * 100),
                strap, bevel_w=0.005)
    g.rivets([g.G(rcx - rw / 2 + 0.08 + i * (rw - 0.16) / 7, ry1 + 0.012, h + 0.155) for i in range(8)], 0.016, brass,
             "boulons_chambre")
    # trappe de chargement boulonnée sur le toit avant, anneau de levage
    g.box(cxb - 0.08, 0.50, h, 0.42, 0.34, 0.035, "trappe", steel, bevel_w=0.006)
    g.rivets([g.G(cxb - 0.08 + dx, 0.50 + dy, h + 0.04) for dx in (-0.17, 0.17) for dy in (-0.09, 0.09)], 0.014, brass,
             "boulons_trappe")
    S.torus(0.055, 0.014, g.G(cxb - 0.08, 0.54, h + 0.05), brass, "anneau_trappe")
    # boucliers plats boulonnés de part et d'autre de la porte
    yf = -y1 * g.K
    for sx in (-1, 1):
        px = -0.19 + sx * 0.46
        S.box((0.24, 0.03, 0.40), (px, yf - 0.016, 0.30), steel, "bouclier_%d" % (sx + 1), bevel_w=0.008)
        g.rivets([(px + dx, yf - 0.036, z) for dx in (-0.085, 0.085) for z in (0.14, 0.46)], 0.017, brass,
                 "boulons_%d" % (sx + 1))
    # porte à volets ouverts et bouche de feu
    fire_mouth(k, -0.19, y1, 0.10, 0.36, 0.28, steel, MOUTH[2], strength=1.6)
    for sx in (-1, 1):
        hinge = -0.19 + sx * 0.23
        v = S.box((0.20, 0.025, 0.30), (0, 0, 0), steel, "volet_%d" % (sx + 1), bevel_w=0.006)
        a = sx * math.radians(60)
        v.location = (hinge + sx * 0.10 * math.cos(a), yf - 0.05 - 0.10 * abs(math.sin(a)), 0.25)
        v.rotation_euler = (0, 0, -a)
    # HAUTE cheminée carrée en briques à l'arrière droit, cerclée, couronnement d'acier en encorbellement
    c = E2_CHIM
    cx, cy, cw = c["x"], c["y"], c["side"]
    zc = KEY[2]["chimney"][0][2]
    g.box(cx, cy, 0.0, cw, cw, zc - 0.09, "cheminee", brick, bevel_w=0.01)
    g.box(cx, cy, zc - 0.09, cw + 0.07, cw + 0.07, 0.09, "couronnement", steel, bevel_w=0.01)
    S.box((cw - 0.10, cw - 0.10, 0.01), g.G(cx, cy, zc + 0.002), k.soot(), "gueule", bevel_w=0)
    for z in (0.40, 0.78, zc - 0.30):
        g.box(cx, cy, z, cw + 0.03, cw + 0.03, 0.045, "cercle_chem_%d" % int(z * 100), strap, bevel_w=0.005)
    # carneau : liaison acier entre le toit et la cheminée
    g.box(x1 + 0.02, cy + 0.08, h + 0.06, 0.14, 0.24, 0.22, "carneau", steel, bevel_w=0.01)
    # volant d'inertie à manivelle sur le flanc droit (kit d'époque)
    S.cylinder(0.16, 0.04, g.G(x1 + 0.04, 0.50, 0.28), steel, "volant", verts=32, rot=(0, math.pi / 2, 0), bevel_w=0.006)
    S.cylinder(0.05, 0.06, g.G(x1 + 0.05, 0.50, 0.28), brass, "moyeu", verts=16, rot=(0, math.pi / 2, 0), bevel_w=0.004)
    k.halo(-0.19, 0.95, 0.24, MOUTH[2], 7.0, "halo_bouche")
    if even:
        # soufflet de forge (correction V3, mineur 3 : l'ancien se lisait comme « une planche ou un poteau surmonté
        # d'un carré ») : GRAND soufflet couché à cheval sur l'arête gauche du four, posé sur un chevalet au-dessus
        # des créneaux (z 0,80 à 1,02, arrière relevé) : plateaux de bois en POIRE (gros bout au sud, face à la
        # caméra, 0,40 de large), poche de cuir PLISSÉE en accordéon, buse de laiton qui plonge dans la chambre,
        # levier à poignée. Premier essai de la correction (soufflet debout contre le flanc, 0,21 de large) rejeté
        # sur aperçu : vu par la tranche, il se lisait encore comme une planche. Bord ouest -1,06 (mineur 5).
        wood = k.stone("bois", "#6B4F35", gain=1.5, rough=0.7, grain=0.4)
        leather = k.stone("cuir", "#8A5A3A", gain=1.4, rough=0.5, grain=0.25)
        xc_b, xw = -0.86, 0.20                 # centre et demi-largeur maximale (x de jeu)
        yn, ys = -0.32, 0.62                    # bout étroit (nord, buse) et gros bout (sud)
        tilt = 0.14                             # l'arrière (nord) est relevé de 0,14

        def pear(sc, z):
            pts = []
            for i in range(24):
                t = 2 * math.pi * i / 24
                u = -math.cos(t)                # -1 au nord, +1 au sud
                st = math.sin(t)
                sgn = 0.0 if abs(st) < 1e-9 else math.copysign(1.0, st)
                wdt = xw * sc * (0.35 + 0.65 * ((u + 1) / 2) ** 0.6) * sgn * abs(st) ** 0.7
                y = yn + (ys - yn) * (u + 1) / 2
                pts.append(g.G(xc_b + wdt, y, z + tilt * (ys - y) / (ys - yn)))
            return pts
        # chevalet : deux montants au sol à gauche, traverses posées sur les créneaux
        for i, yy in enumerate((yn + 0.18, ys - 0.16)):
            g.box(-1.02, yy, 0.0, 0.05, 0.05, 0.80 + tilt * (ys - yy) / (ys - yn), "montant_%d" % i, wood, bevel_w=0.004)
            g.cyl_between(g.G(-1.03, yy, 0.78 + tilt * (ys - yy) / (ys - yn)), g.G(-0.62, yy, 0.78 + tilt * (ys - yy) / (ys - yn)),
                          0.022, "traverse_%d" % i, wood, verts=8)
        z_b, z_t = 0.78, 1.06
        g.loft([pear(1.0, z_b), pear(1.0, z_b + 0.035)], "plateau_bas", wood, True, True, None, 0.006)
        rings = []
        for j in range(7):
            f = j / 6.0
            sc = 1.08 if j % 2 == 1 else 0.86          # accordéon : plis SAILLANTS (dépassent les plateaux) et rentrants
            rings.append(pear(sc, z_b + 0.035 + f * (z_t - z_b - 0.035)))
        g.loft(rings, "poche_cuir", leather, False, False, None, 0.0)
        g.loft([pear(1.0, z_t), pear(1.0, z_t + 0.035)], "plateau_haut", wood, True, True, None, 0.006)
        g.rivets_line(g.G(xc_b, yn + 0.14, z_t + 0.05 + tilt * 0.85), g.G(xc_b, ys - 0.08, z_t + 0.05 + tilt * 0.05), 4, 0.014,
                      brass, "clous_plateau")
        # buse de laiton au bout étroit, qui plonge dans la chambre de chauffe
        g.pipe([g.G(xc_b, yn + 0.02, z_b + 0.10 + tilt), g.G(xc_b, yn - 0.05, z_b + 0.06 + tilt),
                g.G(xc_b + 0.18, yn - 0.02, 0.70)], 0.032, "buse", brass)
        # levier à poignée sur le gros bout, vers le sud-ouest
        g.cyl_between(g.G(xc_b - 0.04, ys - 0.12, z_t + 0.05), g.G(xc_b - 0.10, ys + 0.10, z_t + 0.30), 0.022, "levier", wood,
                      verts=10)
        g.cyl_between(g.G(xc_b - 0.17, ys + 0.10, z_t + 0.30), g.G(xc_b - 0.03, ys + 0.10, z_t + 0.30), 0.024, "poignee", wood,
                      verts=10)


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
    fire_mouth(k, -0.25, 0.92, 0.06, 0.34, 0.14, laiton, MOUTH[3], strength=1.6, arch=True)
    # tour en fonte (profil de haut-fourneau : ventre puis cuve conique)
    tx, ty = -0.25, -0.05
    prof = [(0.60, 0.0), (0.66, 0.30), (0.71, 0.55), (0.66, 0.80), (0.54, 1.02), (0.44, 1.14), (0.40, 1.20)]
    # gueulard OUVERT (cap_top=False) : le premier aperçu fermait le haut par un disque de fonte à la même
    # cote que la lueur ambrée (z 1,20) : chevauchement de faces, triangle sombre sur le feu (vu le 22/10)
    g.lathe(prof, (tx, ty), "haut_fourneau", fonte, segs=48, cap_top=False)
    for z, r in ((0.30, 0.675), (0.55, 0.72), (0.80, 0.67)):
        S.torus(r, 0.022, g.G(tx, ty, z), laiton, "cercle_%d" % int(z * 100))
        g.rivet_ring_at(tx, ty, r + 0.01, z + 0.05, 24, 0.012, laiton, "rivets_%d" % int(z * 100))
    # gueulard : couronne et lueur ambrée au sommet
    S.torus(0.40, 0.035, g.G(tx, ty, 1.20), laiton, "gueulard")
    k_amb = k.emit("ambre", "#FFC060", 1.3)
    # gueulard FERMÉ par la cloche de chargement en fonte (correction V3, mineur 2 : le disque crème de 0,37 de
    # rayon couvrait 13 % du corps et se lisait comme une lampe) : seul un ANNEAU ambré luit entre la cloche et
    # la couronne (bible : environ 1 % de part émissive à l'époque 3)
    g.lathe([(0.30, 1.13), (0.37, 1.13), (0.37, 1.15), (0.30, 1.15)], (tx, ty), "gueulard_anneau", k_amb, segs=48,
            smooth_deg=None)
    g.lathe([(0.31, 1.10), (0.31, 1.16), (0.20, 1.24), (0.06, 1.29), (0.001, 1.30)], (tx, ty), "cloche", fonte, segs=48,
            smooth_deg=50)
    g.cyl(tx, ty, 1.29, 0.035, 0.12, "tige_cloche", laiton, verts=12, bevel_w=0)
    # hublot ambré sur la face avant de la tour
    hy = ty + 0.70 / g.K
    S.cylinder(0.085, 0.03, g.G(tx, hy + 0.005, 0.62), k_amb, "hublot", verts=32, rot=(math.pi / 2, 0, 0), bevel_w=0)
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
    k.halo(-0.25, 0.97, 0.15, MOUTH[3], 8.0, "halo_bouche")
    k.halo(-0.25, 0.55, 0.62, "#FFC060", 3.0, "halo_hublot")
    if even:
        # chaudière de récupération : cylindre horizontal riveté (axe nord-sud) sur le flanc gauche
        bx, by, bz, br = -0.86, 0.05, 0.36, 0.22          # bord ouest -1,10 avec les cerclages (était -1,20 ; mineur 5)
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
    fire = k.emit("bouche", MOUTH[4], 1.7)
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
    k.halo(fx, 0.95, fz, MOUTH[4], 9.0, "halo_bouche")
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
E5_X = -0.08          # axe du four-forge (était -0,13 : bord ouest ramené à -1,08)


def e5(k, even):
    """Correction V3 : flancs franchement inclinés (base 2,00, sommet 0,72 : trapèze en vignette, mineur 6),
    gradins qui débordent, contreforts inclinés aux coins avant (kit), 2 pointes de basalte à l'arrière de la
    dalle (événements de silhouette : ère II, 2 à 3), lave texturée (croûte, veines), O 0,72 -> 0,76."""
    g, S = k.g, k.S
    tung = k.metal("tungstene", gain=2.0, rough=0.45, metallic=0.6, rust="#5A3A2A", rust_amount=0.35, dirt=0.6)
    rouille = k.metal("rouille", gain=1.6, rough=0.7, metallic=0.3, dirt=0.5)
    riv = k.metal("rivet", "#6A6670", gain=2.2, rough=0.3, metallic=0.85, grain=0.08)
    lava = k.emit("lave", "#FF4A10", 1.8, scale=26.0, crust=0.15)
    X = E5_X
    # tronc de pyramide en trois gradins ; chaque gradin DÉBORDE de 0,02 sur le haut du précédent (lèvre)
    tiers = [((X, 0.17, 2.00, 1.50), 0.0, (X, 0.13, 1.70, 1.26), 0.32),
             ((X, 0.13, 1.74, 1.28), 0.28, (X, 0.08, 1.32, 1.00), 0.62),
             ((X, 0.08, 1.36, 1.02), 0.58, (X, 0.03, 0.90, 0.68), 0.92)]
    for i, ((ax, ay, aw, ad), z0, (bx, by, bw, bd), z1) in enumerate(tiers):
        g.frustum(g.rect(ax, ay, aw, ad), z0, g.rect(bx, by, bw, bd), z1, "gradin_%d" % i, tung, bevel_w=0.02)
        g.rivets_line(g.G(ax - aw / 2 + 0.1, ay + ad / 2 + 0.01, z0 + 0.04), g.G(ax + aw / 2 - 0.1, ay + ad / 2 + 0.01, z0 + 0.04),
                      7 - i, 0.024, riv, "rivets_g%d" % i)
    g.frustum(g.rect(X, 0.03, 0.90, 0.68), 0.92, g.rect(X, 0.03, 0.74, 0.54), 0.98, "dalle", rouille, bevel_w=0.01)
    cracks = {1: X - 0.42, 2: X + 0.33}
    scales = []
    for ti, ((ax, ay, aw, ad), z0, (bx_, by_, bw, bd), z1) in enumerate(tiers):
        ya, yb_ = ay + ad / 2, by_ + bd / 2
        th = -math.atan(((ya - yb_) * g.K) / (z1 - z0))
        for row, t in enumerate((0.30, 0.68)):
            z = z0 + (z1 - z0) * t
            yf = ya + (yb_ - ya) * t + 0.012
            wf = aw + (bw - aw) * t - 0.10
            npl = max(4, int(wf / 0.19))
            for j in range(npl):
                x = ax - wf / 2 + (j + 0.25 + 0.5 * (row % 2)) * wf / npl
                if ti in cracks and abs(x - cracks[ti]) < 0.11:
                    continue
                o = S.box((0.17, 0.022, 0.15), g.G(x, yf, z), tung, "ecaille_%d_%d_%d" % (ti, row, j), bevel_w=0.006)
                o.rotation_euler = (th - 0.22, 0, 0)
                scales.append(o)
        if ti >= 1:
            g.box(ax, ya - 0.004, z0 + 0.02, aw - 0.16, 0.03, 0.035, "joint_braise_%d" % ti, lava, bevel_w=0)
    g.join(scales, "ecailles")
    for ti, xc0 in sorted(cracks.items()):
        (ax, ay, aw, ad), z0, (bx_, by_, bw, bd), z1 = tiers[ti]
        ya, yb_ = ay + ad / 2, by_ + bd / 2
        pts = [g.G(xc0 + dx, ya + (yb_ - ya) * t + 0.016, z0 + (z1 - z0) * t)
               for dx, t in ((0.0, 0.08), (0.06, 0.36), (-0.04, 0.62), (0.05, 0.92))]
        g.pipe(pts, 0.03, "fissure_%d" % ti, lava, segs=8)
    # contreforts inclinés aux deux coins avant (kit d'époque) : le pied déborde, le haut s'appuie sur le gradin
    for sx in (-1, 1):
        xb = X + sx * 0.90
        g.frustum(g.rect(xb, 0.80, 0.20, 0.22), 0.0, g.rect(xb - sx * 0.10, 0.70, 0.10, 0.10), 0.52,
                  "contrefort_%d" % (sx + 1), tung, bevel_w=0.012)
    fire_mouth(k, X, 0.89, 0.04, 0.42, 0.16, rouille, MOUTH[5], strength=1.9, arch=True)
    # deux pointes de basalte (colonnes hexagonales à pointe) à l'ARRIÈRE de la dalle : elles sortent du profil
    for i, (x, y, top) in enumerate(((X - 0.40, -0.17, 1.46), (X + 0.16, -0.19, 1.40))):
        g.cyl(x, y, 0.90, 0.10, top - 0.90, "pointe_%d" % i, tung, verts=6, bevel_w=0.004)
        g.cyl(x, y, top, 0.10, 0.13, "pointe_tete_%d" % i, tung, verts=6, r2=0.0, bevel_w=0)
    cx, cy = 0.48, -0.52
    zt = KEY[5]["chimney"][0][2]
    g.frustum(g.rect(cx, cy, 0.44, 0.44 / g.K), 0.0, g.rect(cx, cy, 0.26, 0.26 / g.K), zt, "cheminee", tung, bevel_w=0.012)
    g.frustum(g.rect(cx, cy, 0.32, 0.32 / g.K), zt - 0.10, g.rect(cx, cy, 0.30, 0.30 / g.K), zt + 0.02, "couronne", rouille,
              bevel_w=0.008)
    S.box((0.20, 0.20, 0.01), g.G(cx, cy, zt + 0.025), k.soot(), "gueule", bevel_w=0)
    o = S.box((0.12, 0.03, 0.16), g.G(cx, cy + 0.145 / g.K, zt - 0.32), lava, "fente_chem", bevel_w=0)
    o.rotation_euler = (-math.atan(0.09 / zt), 0, 0)
    k.halo(X, 0.98, 0.15, MOUTH[5], 9.0, "halo_bouche")
    k.halo(X, 0.75, 0.62, "#FF4A10", 3.0, "halo_fentes")
    if even:
        # rigole de coulée (correction V3, mineur 2 : « tracé vectoriel », ne se lisait pas comme un canal) : lit en
        # U creusé entre deux RIVES de pierre à blocs irréguliers, lave en retrait sous une croûte (texture), bec
        # de coulée, lingotière à droite
        st = k.stone("pierre", "#3A3634", gain=1.4, rough=0.9)
        y0, y1 = 0.80, 1.18
        g.box(X, (y0 + y1) / 2, 0.0, 0.54, (y1 - y0) * g.K, 0.08, "rigole_fond", st, bevel_w=0.015)
        rocks = []
        for sx in (-1, 1):
            for j in range(4):
                yy = y0 + 0.05 + j * (y1 - y0 - 0.10) / 3
                hh = 0.16 + 0.03 * ((j + (sx > 0)) % 2)
                rocks.append(g.box(X + sx * 0.22, yy, 0.0, 0.10, 0.13, hh, "rive_%d_%d" % (sx + 1, j), st, bevel_w=0.025))
        g.join(rocks, "rives")
        lav2 = k.emit("lave", "#FF4A10", 1.8)
        g.box(X, (y0 + y1) / 2 + 0.01, 0.08, 0.32, (y1 - y0) * g.K - 0.04, 0.02, "rigole_lave", lav2, bevel_w=0)
        S.box((0.30, 0.10, 0.03), g.G(X, y0 - 0.005, 0.10), st, "bec_coulee", bevel_w=0.01)
        g.box(0.33, 1.10, 0.0, 0.36, 0.30, 0.16, "lingotiere", tung, bevel_w=0.015)
        g.box(0.33, 1.10, 0.16, 0.26, 0.20, 0.012, "lingot", lav2, bevel_w=0)
        k.halo(X, 1.12, 0.15, "#FF4A10", 4.0, "halo_rigole")


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
    # cuve avancée de 0,10 vers le sud (correction V3, majeur 2 : bas du masque à +0,70 seulement), électrodes,
    # mât et isolateurs relevés de 0,20 pour garder le sommet
    vx, vy = -0.15, 0.22
    # cuve ronde et couvercle bombé
    g.lathe([(0.74, 0.0), (0.78, 0.08), (0.78, 0.55), (0.80, 0.62)], (vx, vy), "cuve", acier, segs=48)
    g.lathe([(0.80, 0.62), (0.74, 0.70), (0.55, 0.80), (0.30, 0.86), (0.0, 0.88)], (vx, vy), "couvercle",
            k.metal("refractaire", "#8A8478", gain=1.3, rough=0.7, metallic=0.1), segs=48)
    for z in (0.18, 0.45):
        S.torus(0.785, 0.025, g.G(vx, vy, z), cuivre, "barre_%d" % int(z * 100))
    # trou de coulée (bouche) : bec avant avec métal en fusion
    fire = k.emit("bouche", MOUTH[6], 1.8)
    g.box(vx, vy + 0.62, 0.24, 0.24, 0.40, 0.12, "bec", acier, bevel_w=0.02)
    g.box(vx, vy + 0.66, 0.36, 0.14, 0.30, 0.01, "coulee", fire, bevel_w=0)
    S.box((0.30, 0.03, 0.12), g.G(vx, vy + 0.555, 0.30), fire, "trou_coulee", bevel_w=0)
    # 3 électrodes verticales (graphite), colliers lumineux cyan au passage du couvercle
    tops = (1.60, 1.72, 1.82)
    for i, a in enumerate((math.radians(250), math.radians(10), math.radians(130))):
        ex = vx + 0.30 * math.cos(a)
        ey = vy - 0.30 * math.sin(a) / g.K
        g.cyl(ex, ey, 0.70, 0.085, tops[i] - 0.70, "electrode_%d" % i, graph, verts=24)
        S.torus(0.115, 0.035, g.G(ex, ey, 0.84), cyan, "collier_arc_%d" % i)
        # pince en cuivre et bras sur pile d'isolateurs vers le mât arrière gauche
        g.cyl(ex, ey, tops[i] - 0.22, 0.11, 0.12, "pince_%d" % i, cuivre, verts=20)
        g.cyl_between(g.G(ex, ey, tops[i] - 0.16), g.G(-0.80, -0.30, tops[i] - 0.16), 0.035, "bras_%d" % i, cuivre, verts=10)
    # mât gauche et piles d'isolateurs
    g.box(-0.80, -0.30, 0.0, 0.14, 0.14, 1.80, "mat", acier, bevel_w=0.01)
    insulator_stack(k, -0.80, -0.30, 1.80, 2, "isol_mat")
    for i, z in enumerate((1.15, 1.32)):
        insulator_stack(k, -0.62, -0.18, z, 2, "isol_bras_%d" % i, r=0.06)
    # arcs (zigzags émissifs) entre les sommets des électrodes
    pts = [g.G(vx + 0.30 * math.cos(math.radians(250)), vy - 0.30 * math.sin(math.radians(250)) / g.K, 0.95),
           g.G(vx - 0.02, vy + 0.02, 1.08), g.G(vx + 0.05, vy - 0.06, 1.00),
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
    k.halo(vx, 0.98, 0.30, MOUTH[6], 8.0, "halo_bouche")
    k.halo(vx, vy, 1.05, "#60D0FF", 4.0, "halo_arcs")
    if even:
        # transformateur à ailettes et traversées en céramique, flanc gauche
        tx, ty = -0.84, -0.25                               # ailettes à -1,10 (était -1,14 ; mineur 5)
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
    # bain violet en retrait sous une croûte sombre (le premier essai, bain plein de 0,52, faisait une table rose)
    g.cyl(px, py, 0.80, 0.50, 0.05, "croute", k.soot(), verts=48, bevel_w=0)
    # bain réduit (rayon 0,36 -> 0,24 ; correction V3, mineur 2 : part émissive de l'époque 7 à 18-22 % pour 5 %
    # proposés par la bible) : la croûte sombre occupe le reste du creuset
    g.cyl(px, py, 0.84, 0.24, 0.03, "bain", k.emit("bain", "#8A50E0", 1.1), verts=48, bevel_w=0)
    # 4 griffes de cristal pointées vers le haut (hauteurs asymétriques), avec éclats lumineux au pied
    # griffes replacées (correction V3, majeur 3 : 2 événements de silhouette pour 3 à 4 en ère III) : la griffe
    # arrière droite s'écarte de la cheminée (x 0,40 -> 0,20), un CRISTAL CENTRAL perce la croûte du bain ; le
    # profil a ainsi 4 sommets séparés (griffe gauche, cristal central, griffe droite, cheminée)
    claws = [(-0.80, 0.55, 1.05, (0.10, 0.05)), (0.50, 0.62, 0.95, (-0.10, 0.06)),
             (-0.72, -0.30, 1.62, (0.10, -0.04)), (0.20, -0.34, 1.42, (-0.06, -0.03))]
    crystal(k, -0.30, -0.06, 0.78, 0.11, 1.02, (0.03, 0.0), "cristal_central", cris, rot=0.2)
    crystal(k, -0.16, 0.02, 0.80, 0.07, 0.55, (0.06, -0.02), "cristal_central_b", cris, rot=0.7)
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
        zc = 1.60
        cxp, cyp, _ = g.G(px, py, 0)
        top = (cxp, cyp, zc + 0.42)
        bot = (cxp, cyp, zc - 0.30)
        mid = g.ring_pts(cxp, cyp, 0.26, zc + 0.02, 4, math.pi / 4)
        verts = mid + [top, bot]
        faces = [(i, (i + 1) % 4, 4) for i in range(4)] + [((i + 1) % 4, i, 5) for i in range(4)]
        g.mesh("prisme", verts, faces, cglow, bevel_w=0.003)
        S.torus(0.31, 0.03, (cxp, cyp, zc + 0.02), bronze, "anneau_prisme")
        for sx in (-1, 1):
            g.pipe([(cxp + sx * 0.31, cyp, zc + 0.02), (cxp + sx * 0.52, cyp + 0.10, zc - 0.15),
                    (cxp + sx * 0.62, cyp + 0.25, zc - 0.62)], 0.035, "bras_prisme_%d" % (sx + 1), bronze)
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
    # correction V3 (majeur 3 : 1 seul événement de silhouette pour 3 à 4 en ère III) : TÊTE d'alambic (petite
    # sphère de verre) coiffée d'un évent vertical, col de cygne ABAISSÉ qui part de la tête et ne domine plus le
    # profil, COLONNE de condensation à bulbe à l'arrière gauche ; sommets : colonne, évent, cheminée
    cx0, cy0, _ = g.G(bx, by, 0)
    chx, chy = 0.62, -0.55
    zt = KEY[8]["chimney"][0][2]
    p_ch = g.G(chx, chy, 0)
    zh = zc + r + 0.17
    g.cyl(bx, by, zc + r - 0.06, 0.07, 0.14, "col_tete", vdg, verts=20)
    S.sphere(0.15, (cx0, cy0, zh), verre, "tete_alambic", seg=32, rings=16)
    S.torus(0.155, 0.02, (cx0, cy0, zh), vdg, "ceinture_tete")
    g.cyl(bx, by, zh + 0.12, 0.05, 2.28 - zh - 0.12, "event_tete", vdg, verts=16)
    g.cyl(bx, by, 2.24, 0.075, 0.05, "chapeau_event", caout, verts=16, bevel_w=0.004)
    neck = [(cx0 + 0.13, cy0, zh), (cx0 + 0.30, cy0 + 0.12, zh + 0.10), (cx0 + 0.52, cy0 + 0.36, zh + 0.10),
            (p_ch[0] - 0.12, p_ch[1] - 0.06, zh - 0.02), (p_ch[0], p_ch[1], zt - 0.45)]
    g.pipe(neck, 0.075, "col_de_cygne", vdg)
    S.torus(0.09, 0.022, (cx0 + 0.13, cy0, zh), caout, "joint_col")
    # colonne de condensation à bulbe, arrière gauche
    qx, qy = -0.52, -0.42
    g.cyl(qx, qy, 0.0, 0.10, 0.12, "pied_colonne", vdg, verts=20)
    g.cyl(qx, qy, 0.12, 0.055, 1.42, "tube_colonne", verre, verts=20)
    for z in (0.40, 0.80, 1.20):
        S.torus(0.06, 0.016, g.G(qx, qy, z), vdg, "bague_colonne")
    S.sphere(0.14, g.G(qx, qy, 1.62), verre, "bulbe_colonne", seg=32, rings=16)
    S.torus(0.145, 0.018, g.G(qx, qy, 1.62), vdg, "ceinture_bulbe_colonne")
    g.cyl(qx, qy, 1.74, 0.04, 0.10, "event_colonne", vdg, verts=12)
    g.pipe([g.G(qx, qy, 1.10), g.G(qx + 0.12, qy + 0.10, 1.05), g.G(bx - 0.30, by - 0.20, zc + 0.30)], 0.03, "tube_condenseur", caout)
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
        sx, sy, sz, sr = -0.76, -0.25, 0.80, 0.30           # bord ouest -1,10 avec la ceinture (était -1,22 ; mineur 5)
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
    # correction V3 (majeur 3 : 2 événements pour 3 à 4 en ère III) : cheminée de ventilation octogonale au
    # sommet du dôme (bande jaune), mât-balise de radiation à gauche
    g.lathe([(0.14, 1.00), (0.14, 1.62), (0.16, 1.66), (0.16, 1.74), (0.12, 1.76)], (bx, by - 0.16), "ventilation", plomb,
            segs=8, phase=ph, smooth_deg=None, bevel_w=0.006, cap_top=False)
    g.lathe([(0.145, 1.42), (0.145, 1.52)], (bx, by - 0.16), "ventilation_bande", jaune, segs=8, phase=ph, smooth_deg=None,
            cap_top=False, cap_bottom=False)
    g.cyl(bx, by - 0.16, 1.66, 0.10, 0.06, "ventilation_fond", k.soot(), verts=8, bevel_w=0)
    g.cyl(-0.64, 0.02, 0.80, 0.055, 0.78, "mat_balise", jaune, verts=10, bevel_w=0.004)
    S.sphere(0.095, g.G(-0.64, 0.02, 1.66), k.emit("balise", "#5CFF4A", 1.4), "balise", seg=16, rings=8)
    S.torus(0.10, 0.02, g.G(-0.64, 0.02, 1.60), plomb, "collier_balise")
    k.halo(bx, 0.98, 0.20, "#5CFF4A", 7.0, "halo_bouche")
    k.halo(bx, 0.55, 0.62, "#5CFF4A", 4.0, "halo_hublots")
    if even:
        # conduit annelé sur le flanc droit, de la base jusqu'à la tour
        pts = [g.G(0.62, 0.55, 0.20), g.G(0.92, 0.45, 0.30), g.G(0.95, 0.10, 0.65), g.G(0.92, -0.20, 1.10),
               g.G(cx + 0.22, cy + 0.05, 1.30)]
        # contraste au gris (correction V3, mineur 3) : conduit galvanisé clair, anneaux jaunes et noirs alternés
        galv = k.metal("galva_conduit", "#9EA4AA", gain=1.6, rough=0.32, metallic=0.75, dirt=0.35, grain=0.08)
        noirc = k.metal("noir_conduit", "#1E1E20", gain=1.4, rough=0.5, metallic=0.4)
        g.pipe(pts, 0.085, "conduit_annele", galv)
        # anneaux le long du conduit
        from mathutils import Vector
        rings = []
        for a, b in zip(pts[:-1], pts[1:]):
            va, vb = Vector(a), Vector(b)
            d = vb - va
            for i in range(1, 4):
                p = va + d * (i / 4)
                o = S.torus(0.10, 0.026, tuple(p), jaune if i % 2 else noirc, "anneau", minor_seg=8)
                o.rotation_mode = "QUATERNION"
                o.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
                rings.append(o)
        g.join(rings, "anneaux_conduit")
        S.cylinder(0.08, 0.02, g.G(0.97, 0.10, 0.65), vert, "voyant_conduit", verts=20, rot=(0, math.pi / 2, 0), bevel_w=0)


# -------------------------------------------------------------------------------------------------
# Ères IV et V : ancrage au sol (correction V3, problème majeur 2)
# -------------------------------------------------------------------------------------------------
# Le vérificateur a mesuré le bas des masques des niveaux 19 à 30 à y = +0,31..+0,62 (vanilla : +1,02) : le
# bâtiment n'occupait plus le tiers sud de son emprise et paraissait décalé vers le nord. Deux remèdes, tous
# deux demandés au choix et cumulés ici :
# (a) des PIEDS ou plots aux coins de l'emprise ; les pieds avant arrivent à y ≈ +0,76 (+0,84 avec la
#     semelle) ; ils font partie du masque D1 ;
# (b) une PLAQUE AU SOL par époque, de la taille de l'emprise 2×2 (couche « patch » : integration_patch du
#     prototype, couche lower-object, bible §1.8.8), rendue à part (passes.py) et exclue du masque D1 (Q13).
# Pas de matériau émissif dans les plaques : les couches de lueur restent les seules sources de couleur vive.
FRONT_Y, BACK_Y = 0.76, -0.62


def ground_pad(k, top, rim, inlay=None, name="plaque", inset=0.04, square=0.74):
    """Plaque au sol (patch) : dalle de l'emprise moins un retrait, cadre en saillie, liseré peint en carré."""
    g = k.g
    w = 2.0 - 2 * inset
    objs = [g.box(0.0, 0.0, 0.0, w, w * g.K, 0.020, name + "_dalle", top, bevel_w=0.006)]
    b = 0.07
    for i, (cx, cy, ww, dd) in enumerate(((0.0, w / 2 - b / 2, w, b), (0.0, -w / 2 + b / 2, w, b),
                                          (-w / 2 + b / 2, 0.0, b, w - 2 * b), (w / 2 - b / 2, 0.0, b, w - 2 * b))):
        objs.append(g.box(cx, cy, 0.0, ww, dd * g.K, 0.030, "%s_cadre_%d" % (name, i), rim, bevel_w=0.008))
    for i, (cx, cy, ww, dd) in enumerate(((0.0, 0.0, w - 0.1, 0.03), (0.0, 0.0, 0.03, w - 0.1))):
        objs.append(g.box(cx, cy, 0.0, ww, dd * g.K, 0.022, "%s_joint_%d" % (name, i), rim, bevel_w=0.002))
    if inlay is not None:
        q, t = square, 0.035
        for i, (cx, cy, ww, dd) in enumerate(((0.0, q, 2 * q, t), (0.0, -q, 2 * q, t), (-q, 0.0, t, 2 * q), (q, 0.0, t, 2 * q))):
            objs.append(g.box(cx, cy, 0.0, ww, dd * g.K, 0.024, "%s_liseret_%d" % (name, i), inlay, bevel_w=0.002))
        for i, (sx, sy) in enumerate(((-1, 1), (1, 1), (-1, -1), (1, -1))):
            objs.append(g.box(sx * q, sy * q, 0.0, 0.14, 0.14 * g.K, 0.026, "%s_coin_%d" % (name, i), rim, bevel_w=0.01))
    return g.mark_patch(objs)


def foot(k, x, y, mat, r=0.085, h=0.06, name="pied"):
    """Semelle au sol ; renvoie le point d'attache (Blender) au-dessus."""
    k.g.cyl(x, y, 0.0, r, h, name + "_semelle", mat, verts=16, bevel_w=0.01)
    return k.g.G(x, y, h)


def leg(k, foot_pt, att, knee_z, mat, r, name, joint_mat=None):
    """Jambe en deux segments (pied -> genou relevé -> attache), genou sphérique."""
    g, S = k.g, k.S
    kx = foot_pt[0] + 0.45 * (att[0] - foot_pt[0])
    ky = foot_pt[1] + 0.45 * (att[1] - foot_pt[1])
    knee = (kx, ky, knee_z)
    g.cyl_between(foot_pt, knee, r, name + "_bas", mat, verts=12)
    g.cyl_between(knee, att, r * 0.9, name + "_haut", mat, verts=12)
    S.sphere(r * 1.35, knee, joint_mat or mat, name + "_genou", seg=16, rings=8)


# -------------------------------------------------------------------------------------------------
# Époque 10 · Haute technologie : capsule d'induction sur 4 pieds aux coins ; pièce : écran et antenne
# -------------------------------------------------------------------------------------------------
# Correction V3 : pieds aux 4 coins de l'emprise, plaque au sol ; capsule affinée (rayon 0,56 -> 0,46) pour
# libérer le profil ; 4 sommets séparés (ère IV : 4 à 5 événements) : parabole sur mât à gauche, pointe-voyant
# au sommet de la capsule, mât-capteur à droite, mât d'évacuation (cheminée) déplacé à x 0,72.
E10 = {"cx": -0.14, "cy": 0.02}


def e10(k, even):
    g, S = k.g, k.S
    car = k.metal("carenage", gain=1.25, rough=0.30, metallic=0.25, grain=0.06, dirt=0.35)
    noir = k.metal("noir", gain=1.6, rough=0.55, metallic=0.3, grain=0.05, dirt=0.2)
    bleu = k.emit("bleu", "#3AA8FF", 1.8)
    fire = k.emit("bouche", MOUTH[10], 1.6)
    cx, cy = E10["cx"], E10["cy"]
    ground_pad(k, k.metal("dalle", "#5C6066", gain=1.3 / k.k_alb, rough=0.62, metallic=0.3, grain=0.18, dirt=0.5), noir,
               inlay=k.metal("peinture_bleue", "#2F6FA8", gain=1.0, rough=0.45, metallic=0.1))
    # anneau de base noir (vide dessous) et voyants
    g.lathe([(0.34, 0.30), (0.56, 0.32), (0.58, 0.40), (0.34, 0.44)], (cx, cy), "anneau_base", noir, segs=48)
    led = []
    for i in range(7):
        a = math.radians(200 + i * 20)
        led.append(S.sphere(0.024, g.G(cx + 0.58 * math.cos(a), cy - 0.58 * math.sin(a) / g.K, 0.36), bleu, "led_%d" % i,
                            seg=8, rings=4))
    g.join(led, "leds_base")
    # 4 pieds aux coins de l'emprise, genoux relevés (silhouette d'atterrisseur)
    cxb, cyb, _ = g.G(cx, cy, 0)
    for i, (fx, fy) in enumerate(((cx - 0.62, FRONT_Y), (cx + 0.62, FRONT_Y), (cx - 0.62, BACK_Y), (cx + 0.56, BACK_Y))):
        fp = foot(k, fx, fy, noir, name="pied_%d" % i)
        a = math.atan2(fp[1] - cyb, fp[0] - cxb)
        leg(k, fp, (cxb + 0.50 * math.cos(a), cyb + 0.50 * math.sin(a), 0.36), 0.62, noir, 0.040, "jambe_%d" % i, car)
    # capsule lisse verticale
    r, z0, z1 = 0.46, 0.40, 2.25
    prof = [(0.001, z0), (0.26, z0 + 0.02)] + [(r * math.sin(math.pi / 2 * i / 6), z0 + 0.22 - 0.22 * math.cos(math.pi / 2 * i / 6))
                                              for i in range(2, 7)]
    prof += [(r, z1 - r)] + [(r * math.cos(math.pi / 2 * i / 8), z1 - r + r * math.sin(math.pi / 2 * i / 8)) for i in range(1, 8)]
    prof += [(0.001, z1)]
    g.lathe(prof, (cx, cy), "capsule", car, segs=56, smooth_deg=60)
    for z in (1.05, 1.55):
        g.lathe([(r + 0.012, z + 0.035), (r + 0.012, z + 0.145)], (cx, cy), "induction_%d" % int(z * 100), bleu, segs=56,
                cap_top=False, cap_bottom=False)
        g.lathe([(r + 0.02, z - 0.03), (r + 0.02, z)], (cx, cy), "joint_%d" % int(z * 100), noir, segs=56)
    # pointe-voyant au sommet
    g.cyl(cx, cy, z1 - 0.04, 0.10, 0.06, "embase_pointe", noir, verts=24)
    g.cyl(cx, cy, z1 + 0.02, 0.05, 0.40, "pointe", noir, verts=12, r2=0.035)
    S.sphere(0.06, g.G(cx, cy, z1 + 0.46), bleu, "pointe_led", seg=16, rings=8)
    # fenêtre de coulée (bouche)
    S.box((0.28, 0.05, 0.28), g.G(cx, cy + r / g.K + 0.005, 0.74), fire, "fenetre_bouche", bevel_w=0.01)
    S.box((0.38, 0.06, 0.05), g.G(cx, cy + r / g.K + 0.012, 0.905), noir, "cadre_bouche_h", bevel_w=0.005)
    S.box((0.38, 0.06, 0.05), g.G(cx, cy + r / g.K + 0.012, 0.575), noir, "cadre_bouche_b", bevel_w=0.005)
    # parabole sur mât, arrière gauche
    px, py = -0.86, -0.30
    g.cyl(px, py, 0.0, 0.06, 0.08, "pied_parabole", noir, verts=16)
    g.cyl(px, py, 0.08, 0.032, 1.22, "mat_parabole", noir, verts=10)
    S.cylinder(0.05, 0.10, g.G(px, py, 1.36), car, "parabole", verts=32, radius2=0.17, rot=(math.radians(-25), 0, 0),
               bevel_w=0.004)
    g.cyl_between(g.G(px, py, 1.40), g.G(px, py + 0.10, 1.62), 0.012, "source_parabole", noir, verts=6)
    S.sphere(0.03, g.G(px, py + 0.10, 1.63), bleu, "source_led", seg=10, rings=5)
    # mât-capteur à droite, sur l'anneau de base, tenu à la capsule
    qx, qy = 0.40, 0.06
    g.cyl(qx, qy, 0.40, 0.04, 1.92, "capteur_mat", noir, verts=10)
    g.cyl(qx, qy, 2.30, 0.07, 0.12, "capteur_tete", car, verts=20, bevel_w=0.01)
    S.sphere(0.035, g.G(qx, qy, 2.46), bleu, "capteur_led", seg=10, rings=5)
    g.cyl_between(g.G(qx, qy, 1.80), g.G(cx + r * 0.95, cy, 1.80), 0.02, "bras_capteur", noir, verts=8)
    # mât d'évacuation caréné, arrière droit (la cheminée)
    mx, my = 0.72, -0.62
    zt = KEY[10]["chimney"][0][2]
    g.box(mx, my, 0.0, 0.24, 0.24, zt - 0.08, "mat", car, bevel_w=0.06)
    g.box(mx, my, zt - 0.08, 0.20, 0.20, 0.08, "event", noir, bevel_w=0.03)
    S.box((0.08, 0.02, 0.60), g.G(mx, my + 0.12 / g.K + 0.01, 1.10), bleu, "bandeau_mat", bevel_w=0)
    g.cyl_between(g.G(mx - 0.12, my + 0.05, 0.80), g.G(cx + 0.35, cy - 0.20, 0.95), 0.05, "liaison", noir, verts=16)
    S.box((0.14, 0.14, 0.01), g.G(mx, my, zt + 0.002), k.soot(), "gueule", bevel_w=0)
    k.halo(cx, 0.60, 0.74, MOUTH[10], 7.0, "halo_bouche")
    k.halo(cx, cy + 0.45, 1.30, "#3AA8FF", 4.0, "halo_anneaux")
    if even:
        # écran latéral sur bras articulé et antenne fouet (flanc gauche, devant ; bord ouest ≤ -1,10)
        ex, ey, ez = -0.82, 0.36, 1.00
        g.cyl_between(g.G(cx - 0.42, cy + 0.10, 1.12), g.G(ex + 0.18, ey, ez - 0.02), 0.035, "bras_ecran", noir, verts=12)
        scr = S.box((0.48, 0.04, 0.42), g.G(ex, ey, ez), noir, "ecran", bevel_w=0.015)
        scr.rotation_euler = (math.radians(-12), 0, math.radians(-18))
        face = S.box((0.42, 0.01, 0.36), g.G(ex + 0.006, ey + 0.016, ez), bleu, "ecran_face", bevel_w=0)
        face.rotation_euler = (math.radians(-12), 0, math.radians(-18))
        g.cyl(ex - 0.10, ey - 0.05, ez + 0.18, 0.012, 1.00, "antenne_fouet", noir, verts=6, bevel_w=0)
        S.sphere(0.03, g.G(ex - 0.10, ey - 0.05, ez + 1.19), bleu, "pointe_antenne", seg=10, rings=5)
        k.halo(ex, ey + 0.2, ez, "#3AA8FF", 3.0, "halo_ecran")


# -------------------------------------------------------------------------------------------------
# Époque 11 · Titane : four vertical élancé, ailerons relevés en flèche, 4 pieds aux coins ; pièce : aileron dorsal
# -------------------------------------------------------------------------------------------------
def fin(k, x, y, ang, r_in, z_lo, z_hi, r_out, z_out, name, mat, thick=0.035):
    """Aileron triangulaire dans le plan vertical radial d'angle ang (Blender) autour de (x, y) de jeu."""
    g = k.g
    cx, cy, _ = g.G(x, y, 0)
    u = (math.cos(ang), math.sin(ang), 0.0)
    pts = [(r_in, z_lo), (r_out, z_out), (r_in * 0.9, z_hi)]
    return g.slab(pts, (cx, cy, 0.0), u, (0, 0, 1), thick, name, mat)


# Correction V3 : ailerons RELEVÉS (pointe extérieure la plus haute, silhouette en flèche) aux angles 125°, 55°,
# 235°, 305° ; évent (cheminée) déplacé à x 0,80 et relevé (O 1,22) ; 4 pieds en V aux coins ; plaque au sol.
# Sommets : aileron arrière gauche, tour, aileron arrière droit, évent (ère IV : 4 à 5 événements).
E11 = {"cx": -0.14, "cy": -0.02}


def e11(k, even):
    g, S = k.g, k.S
    alli = k.metal("alliage", gain=1.0, rough=0.35, metallic=0.25, rust="#8A8478", rust_amount=0.35, dirt=0.45, grain=0.1)
    tit = k.metal("titane", gain=1.6, rough=0.3, metallic=0.75, dirt=0.3, grain=0.08)
    ligne = k.emit("ligne", "#BFE6FF", 1.7)
    fire = k.emit("bouche", MOUTH[11], 1.6)
    cx, cy = E11["cx"], E11["cy"]
    ground_pad(k, k.metal("dalle", "#8E8C88", gain=0.75 / k.k_alb, rough=0.6, metallic=0.2, grain=0.12, dirt=0.5), tit,
               inlay=k.metal("peinture", "#6E8AA0", gain=1.0, rough=0.4, metallic=0.2))
    # 4 pieds en V aux coins de l'emprise (vides au sol)
    cxb, cyb, _ = g.G(cx, cy, 0)
    for i, (fx, fy) in enumerate(((cx - 0.62, FRONT_Y), (cx + 0.62, FRONT_Y), (cx - 0.62, BACK_Y), (cx + 0.56, BACK_Y))):
        fp = foot(k, fx, fy, tit, r=0.07, name="pied_%d" % i)
        a = math.atan2(fp[1] - cyb, fp[0] - cxb)
        for da in (-0.25, 0.25):
            g.cyl_between(fp, (cxb + 0.30 * math.cos(a + da), cyb + 0.30 * math.sin(a + da), 0.62), 0.030,
                          "pied_%d_%d" % (i, int(da > 0)), tit, verts=10)
    prof = [(0.001, 0.50), (0.30, 0.52), (0.42, 0.64), (0.42, 1.30), (0.36, 1.85), (0.24, 2.30), (0.12, 2.55), (0.001, 2.66)]
    g.lathe(prof, (cx, cy), "tour", alli, segs=48, smooth_deg=50)
    g.lathe([(0.425, 1.05), (0.42, 1.22)], (cx, cy), "bague_lumineuse", ligne, segs=48, cap_top=False, cap_bottom=False)
    S.box((0.16, 0.05, 0.30), g.G(cx, cy + 0.42 / g.K - 0.01, 0.82), fire, "bouche_fente", bevel_w=0.01)
    bx, by, _ = g.G(cx, cy, 0)
    for i, a_deg in enumerate((125, 55, 235, 305)):
        a = math.radians(a_deg)
        fin(k, cx, cy, a, 0.40, 0.78, 1.55, 0.86, 2.05, "aileron_%d" % i, alli)
        g.cyl_between((bx + 0.86 * math.cos(a), by + 0.86 * math.sin(a), 2.02),
                      (bx + 0.42 * math.cos(a), by + 0.42 * math.sin(a), 0.82), 0.022, "ligne_%d" % i, ligne, verts=8)
    mx, my = 0.80, -0.55
    zt = KEY[11]["chimney"][0][2]
    g.lathe([(0.15, 0.0), (0.14, 0.6), (0.12, zt - 0.30), (0.09, zt - 0.05), (0.10, zt)], (mx, my), "event", alli, segs=32,
            cap_top=False)
    g.cyl(mx, my, zt - 0.10, 0.09, 0.09, "fond_event", k.soot(), verts=24, bevel_w=0)
    fin(k, mx, my, math.radians(0), 0.13, 0.30, 1.20, 0.26, 0.25, "aileron_event", tit, thick=0.03)
    g.lathe([(0.145, 0.95), (0.14, 1.12)], (mx, my), "ligne_event", ligne, segs=32, cap_top=False, cap_bottom=False)
    g.cyl_between(g.G(mx - 0.12, my + 0.04, 0.95), g.G(cx + 0.38, cy - 0.10, 1.00), 0.04, "liaison", tit, verts=12)
    k.halo(cx, 0.55, 0.80, MOUTH[11], 7.0, "halo_bouche")
    k.halo(cx, cy + 0.4, 1.15, "#BFE6FF", 4.0, "halo_bague")
    if even:
        bx2, by2, _ = g.G(cx, cy - 0.28, 0)
        pts = [(-0.66, 1.18), (0.66, 1.18), (0.12, 2.62), (-0.05, 2.62)]
        g.slab(pts, (bx2, by2, 0.0), (1, 0, 0), (0, 0, 1), 0.05, "aileron_dorsal", tit)
        g.slab([(-0.58, 1.24), (0.58, 1.24), (0.08, 2.45), (-0.03, 2.45)], (bx2, by2 - 0.035, 0.0), (1, 0, 0), (0, 0, 1), 0.02,
               "aileron_dorsal_ame", alli)
        for sx in (-1, 1):
            g.cyl_between((bx2 + sx * 0.64, by2 - 0.03, 1.20), (bx2 + sx * 0.10, by2 - 0.03, 2.58), 0.022,
                          "ligne_dorsale_%d" % (sx + 1), ligne, verts=8)


# -------------------------------------------------------------------------------------------------
# Époque 12 · Supraconducteurs : creuset en lévitation entre 2 anneaux ; pièce : pylône cryogénique
# -------------------------------------------------------------------------------------------------
# Correction V3 : 3 PÔLES magnétiques chromés dressés sur l'anneau supérieur (angles 165°, 100°, 50°) ; colonne
# d'évacuation relevée ; 3 plots d'ancrage aux coins (le 4e coin est la colonne) ; plaque au sol. Sommets : 3 pôles
# et la colonne (ère IV : 4 à 5).
def e12(k, even):
    g, S = k.g, k.S
    noir = k.metal("noir", gain=1.6, rough=0.35, metallic=0.5, grain=0.05, dirt=0.25)
    chrome = k.metal("chrome", gain=1.4, rough=0.15, metallic=0.95, grain=0.05, rust="#DDEEFF", rust_amount=0.35, dirt=0.15)
    cyan = k.emit("cyan", "#4AF0FF", 1.8)
    fire = k.emit("bouche", MOUTH[12], 1.7)
    cx, cy = -0.12, 0.12
    ground_pad(k, k.metal("dalle", "#2C2E34", gain=1.6 / k.k_alb, rough=0.5, metallic=0.4, grain=0.12, dirt=0.4), chrome,
               inlay=k.metal("peinture_cyan", "#2A8A96", gain=1.0, rough=0.4, metallic=0.2))
    g.frustum(g.regular(cx, cy, 0.50, 6, 0.0), 0.0, g.regular(cx, cy, 0.44, 6, 0.0), 0.16, "socle", noir, bevel_w=0.012)
    g.lathe([(0.47, 0.06), (0.47, 0.10)], (cx, cy), "fente_socle", cyan, segs=6, cap_top=False, cap_bottom=False, smooth_deg=None)
    # plots d'ancrage aux coins (avant gauche, avant droit, arrière gauche) reliés au socle par des poutres basses
    for i, (fx, fy) in enumerate(((cx - 0.64, FRONT_Y), (cx + 0.64, FRONT_Y), (cx - 0.64, BACK_Y))):
        g.frustum(g.regular(fx, fy, 0.10, 6, 0.0), 0.0, g.regular(fx, fy, 0.07, 6, 0.0), 0.34, "plot_%d" % i, noir,
                  bevel_w=0.008)
        g.cyl(fx, fy, 0.34, 0.075, 0.05, "plot_tete_%d" % i, chrome, verts=6, bevel_w=0.006)
        S.sphere(0.045, g.G(fx, fy, 0.42), cyan, "plot_pole_%d" % i, seg=12, rings=6)
        g.cyl_between(g.G(fx, fy, 0.10), g.G(cx + (fx - cx) * 0.35, cy + (fy - cy) * 0.35, 0.10), 0.035, "poutre_%d" % i,
                      chrome, verts=10)
    for z, R in ((0.50, 0.66), (1.62, 0.58)):
        S.torus(R, 0.075, g.G(cx, cy, z), chrome, "anneau_%d" % int(z * 100), minor_seg=16)
        g.lathe([(R - 0.07, z - 0.05), (R - 0.07, z + 0.05)], (cx, cy), "bande_%d" % int(z * 100), cyan, segs=48,
                cap_top=False, cap_bottom=False)
    # pôles magnétiques sur l'anneau supérieur
    bx, by, _ = g.G(cx, cy, 0)
    for i, (a_deg, top) in enumerate(((165, 2.20), (100, 2.42), (50, 2.22))):
        a = math.radians(a_deg)
        px_, py_ = bx + 0.58 * math.cos(a), by + 0.58 * math.sin(a)
        S.cylinder(0.075, 0.10, (px_, py_, 1.70), noir, "pole_pied_%d" % i, verts=16, bevel_w=0.006)
        S.cylinder(0.055, top - 1.75, (px_, py_, 1.75 + (top - 1.75) / 2), chrome, "pole_%d" % i, verts=16, radius2=0.04,
                   bevel_w=0.004)
        S.torus(0.06, 0.018, (px_, py_, top - 0.22), cyan, "pole_bague_%d" % i)
        S.sphere(0.05, (px_, py_, top + 0.02), chrome, "pole_tete_%d" % i, seg=16, rings=8)
    g.lathe([(0.001, 0.80), (0.24, 0.82), (0.36, 0.95), (0.40, 1.12), (0.38, 1.28), (0.30, 1.36)], (cx, cy), "creuset", noir,
            segs=48, cap_top=False)
    S.torus(0.30, 0.03, g.G(cx, cy, 1.36), chrome, "levre")
    g.cyl(cx, cy, 1.30, 0.29, 0.04, "bain", fire, verts=40, bevel_w=0)
    S.box((0.26, 0.04, 0.14), g.G(cx, cy + 0.40 / g.K - 0.01, 1.08), fire, "fenetre_bain", bevel_w=0.008)
    mx, my = 0.62, -0.62
    zt = KEY[12]["chimney"][0][2]
    blocks = [(0.0, 0.42, 0.17), (0.50, 0.94, 0.155), (1.02, 1.44, 0.14), (1.52, 1.92, 0.13), (2.00, zt, 0.12)]
    for i, (z0, z1, r) in enumerate(blocks):
        g.frustum(g.regular(mx, my, r, 8, math.pi / 8), z0, g.regular(mx, my, r * 0.92, 8, math.pi / 8), z1, "bloc_%d" % i,
                  chrome if i % 2 else noir, bevel_w=0.01)
        if i:
            g.cyl(mx, my, z0 - 0.06, r * 0.5, 0.05, "lueur_%d" % i, cyan, verts=16, bevel_w=0)
    g.cyl(mx, my, zt - 0.06, 0.07, 0.07, "gueule", k.soot(), verts=16, bevel_w=0)
    k.halo(cx, 0.60, 1.05, MOUTH[12], 6.0, "halo_bouche")
    k.halo(cx, cy + 0.3, 0.50, "#4AF0FF", 4.0, "halo_anneaux")
    if even:
        px, py = -0.88, -0.25                                # bord ouest ≤ -1,10 (était -1,12 ; mineur 5)
        givre = k.metal("givre", gain=0.9, rough=0.6, metallic=0.1, grain=0.2, dirt=0.2)
        g.frustum(g.regular(px, py, 0.13, 6, 0.0), 0.0, g.regular(px, py, 0.09, 6, 0.0), 1.55, "pylone", noir, bevel_w=0.01)
        for z in (0.30, 0.70, 1.10):
            g.cyl(px, py, z, 0.13, 0.10, "givre_%d" % int(z * 100), givre, verts=20, bevel_w=0.02)
        for i in range(4):
            S.torus(0.15, 0.035, g.G(px, py, 1.58 + i * 0.07), cyan if i % 2 == 0 else chrome, "bobine_%d" % i)
        S.sphere(0.08, g.G(px, py, 1.90), chrome, "tete", seg=16, rings=8)
        g.pipe([g.G(px + 0.10, py, 0.25), g.G(px + 0.35, py + 0.15, 0.12), g.G(cx - 0.40, cy, 0.10)], 0.035, "tuyau_cryo", chrome)
        k.halo(px, py, 1.65, "#4AF0FF", 3.0, "halo_pylone")


# -------------------------------------------------------------------------------------------------
# Époque 13 · Fusion : sphère sur trépied aux coins, tore de plasma, injecteurs dressés ; pièce : second tore
# -------------------------------------------------------------------------------------------------
# Correction V3 : le trépied pose ses pieds aux coins de l'emprise (avant gauche, avant droit, arrière) ; plaque
# au sol ; 3 INJECTEURS dressés sur le tore (165°, 115°, 65°) et une antenne-électrode au sommet de la sphère.
# Sommets : injecteurs, antenne, flèche d'évacuation (ère V : 5 à 6 événements).
def e13(k, even):
    g, S = k.g, k.S
    cer = k.metal("ceramique", gain=1.0, rough=0.4, metallic=0.05, grain=0.08, dirt=0.45, rust="#9A9284", rust_amount=0.3)
    cuivre = k.metal("cuivre", gain=1.5, rough=0.3, metallic=0.85, dirt=0.3)
    plasma = k.emit("plasma", "#FF4FD8", 1.3)
    coeur = k.emit("coeur", MOUTH[13], 1.8)
    cx, cy, zc, R = -0.12, 0.08, 1.45, 0.55
    ground_pad(k, k.metal("dalle", "#9A968E", gain=0.62 / k.k_alb, rough=0.6, metallic=0.05, grain=0.12, dirt=0.5), cuivre,
               inlay=k.metal("cuivre_incruste", "#8A5A30", gain=1.4, rough=0.35, metallic=0.8))
    cxb, cyb, _ = g.G(cx, cy, 0)
    for i, (fx, fy) in enumerate(((cx - 0.66, FRONT_Y), (cx + 0.66, FRONT_Y), (cx, BACK_Y - 0.04))):
        fp = foot(k, fx, fy, cuivre, r=0.10, h=0.06, name="pied_%d" % i)
        a = math.atan2(fp[1] - cyb, fp[0] - cxb)
        att = (cxb + 0.28 * math.cos(a), cyb + 0.28 * math.sin(a), zc - 0.45)
        g.cyl_between(fp, att, 0.05, "jambe_%d" % i, cuivre, verts=12)
        mid = tuple(fp[j] + 0.35 * (att[j] - fp[j]) for j in range(3))
        S.torus(0.065, 0.02, mid, cer, "bague_jambe_%d" % i)
    S.sphere(R, g.G(cx, cy, zc), cer, "sphere", seg=48, rings=24)
    S.torus(R + 0.005, 0.03, g.G(cx, cy, zc), cuivre, "equateur")
    S.torus(0.30, 0.05, g.G(cx, cy, zc - R + 0.08), cuivre, "collier_bas")
    S.cylinder(0.16, 0.06, g.G(cx, cy + R / g.K - 0.03, zc - 0.10), coeur, "coeur", verts=32, rot=(math.radians(60), 0, 0), bevel_w=0)
    S.torus(0.17, 0.03, g.G(cx, cy + R / g.K - 0.015, zc - 0.10), cuivre, "cadre_coeur", rot=(math.radians(60), 0, 0))
    # tore de plasma affiné et gainé de 8 brides de cuivre (correction V3, mineur 2 : part émissive de l'époque 13 à
    # 33-41 % pour 10 % proposés par la bible)
    S.torus(0.88, 0.055, g.G(cx, cy, zc), plasma, "tore", major_seg=72, minor_seg=16)
    for i in range(8):
        a = 2 * math.pi * (i + 0.5) / 8
        o = S.torus(0.075, 0.03, (cxb + 0.88 * math.cos(a), cyb + 0.88 * math.sin(a), zc), cuivre, "bride_tore_%d" % i,
                    rot=(0, math.pi / 2, a + math.pi / 2), major_seg=24, minor_seg=8)
    bx, by = cxb, cyb
    for i in range(3):
        a = math.radians(60 + 120 * i)
        g.cyl_between((bx + (R - 0.02) * math.cos(a), by + (R - 0.02) * math.sin(a), zc),
                      (bx + 0.80 * math.cos(a), by + 0.80 * math.sin(a), zc), 0.035, "injecteur_%d" % i, cuivre, verts=12)
    # injecteurs dressés sur le tore et antenne-électrode
    for i, (a_deg, top) in enumerate(((165, 2.20), (115, 2.42), (65, 2.32))):
        a = math.radians(a_deg)
        px_, py_ = bx + 0.88 * math.cos(a), by + 0.88 * math.sin(a)
        S.cylinder(0.085, 0.10, (px_, py_, zc + 0.09), cuivre, "inj_collier_%d" % i, verts=16, bevel_w=0.006)
        S.cylinder(0.05, top - zc - 0.14, (px_, py_, (zc + 0.14 + top) / 2), cuivre, "inj_tige_%d" % i, verts=12,
                   radius2=0.035, bevel_w=0.004)
        S.sphere(0.06, (px_, py_, top + 0.03), plasma, "inj_pointe_%d" % i, seg=16, rings=8)
    g.cyl(cx, cy, zc + R - 0.04, 0.09, 0.08, "embase_antenne", cuivre, verts=20)
    g.cyl(cx, cy, zc + R + 0.04, 0.045, 0.82, "antenne", cuivre, verts=12, r2=0.03)
    S.sphere(0.06, g.G(cx, cy, zc + R + 0.90), plasma, "antenne_pointe", seg=16, rings=8)
    mx, my = 0.62, -0.62
    zt = KEY[13]["chimney"][0][2]
    g.lathe([(0.14, 0.0), (0.12, 0.30), (0.11, zt - 0.20), (0.13, zt)], (mx, my), "fleche", cer, segs=32, cap_top=False)
    for z in (0.6, 1.2, 1.8):
        S.torus(0.12, 0.025, g.G(mx, my, z), cuivre, "bague_%d" % int(z * 10))
    g.cyl(mx, my, zt - 0.10, 0.11, 0.09, "fond", k.soot(), verts=24, bevel_w=0)
    S.torus(0.115, 0.02, g.G(mx, my, zt - 0.03), plasma, "lueur_fleche")
    k.halo(cx, 0.55, zc - 0.1, MOUTH[13], 6.0, "halo_coeur")
    k.halo(cx, cy + 0.5, zc, "#FF4FD8", 6.0, "halo_tore")
    if even:
        o = S.torus(0.76, 0.055, g.G(cx, cy, zc + 0.05), plasma, "tore_incline", major_seg=72, minor_seg=16)
        o.rotation_euler = (math.radians(55), math.radians(20), 0)
        for sgn in (-1, 1):
            p = (bx + sgn * 0.72, by, zc + 0.05)
            S.sphere(0.07, p, cuivre, "noeud_%d" % (sgn + 1), seg=16, rings=8)


# -------------------------------------------------------------------------------------------------
# Époque 14 · Orbite : four solaire, pétales-miroirs dorés ; pièce : pétale arrière supplémentaire
# -------------------------------------------------------------------------------------------------
def mirror_petal(k, cx, cy, ang, r0, z0, r1, z1, w0, w1, name, gold, cells, thick=0.03, rim=None):
    """Pétale-miroir : face intérieure (vers le foyer) en feuille d'or, dos en cellules bleu nuit, légèrement
    creusé (les bords se relèvent). Coordonnées Blender ; ang : direction radiale. rim : matériau d'un
    liseré sombre le long des bords (contraste au test du gris, correction V3)."""
    g = k.g
    from mathutils import Vector
    u = Vector((math.cos(ang), math.sin(ang), 0.0))
    t = Vector((-math.sin(ang), math.cos(ang), 0.0))
    p0 = Vector((cx, cy, z0)) + u * r0
    p1 = Vector((cx, cy, z1)) + u * r1
    axis = (p1 - p0).normalized()
    nrm = axis.cross(t).normalized()           # vers le haut et vers le foyer
    lift = 0.06                                # creux : les bords se relèvent
    rows = []
    for s, (p, w) in enumerate(((p0, w0), (p1, w1))):
        rows.append([p - t * w + nrm * lift * (s * 0.6 + 0.4), p - t * w * 0.5 + nrm * lift * 0.25, p,
                     p + t * w * 0.5 + nrm * lift * 0.25, p + t * w + nrm * lift * (s * 0.6 + 0.4)])
    verts, faces = [], []
    for off in (thick / 2, -thick / 2):             # 0-9 : dessus (rangée p0 puis p1) ; 10-19 : dessous
        for r in rows:
            verts += [tuple(q + nrm * off) for q in r]
    n = 5
    T0, T1, B0, B1 = 0, n, 2 * n, 3 * n
    for i in range(n - 1):
        faces.append((T0 + i, T0 + i + 1, T1 + i + 1, T1 + i))      # face d'or
        faces.append((B0 + i + 1, B0 + i, B1 + i, B1 + i + 1))      # dos en cellules
        faces.append((B0 + i, B0 + i + 1, T0 + i + 1, T0 + i))      # chant intérieur
        faces.append((T1 + i, T1 + i + 1, B1 + i + 1, B1 + i))      # chant extérieur
    faces.append((T0, T1, B1, B0))                                  # chants latéraux
    faces.append((T0 + n - 1, B0 + n - 1, B1 + n - 1, T1 + n - 1))
    o = g.mesh(name, verts, faces, None, smooth_deg=None, bevel_w=0.003)
    o.data.materials.append(gold)
    o.data.materials.append(cells)
    nv = Vector(nrm)
    for poly in o.data.polygons:
        poly.material_index = 0 if Vector(poly.normal).dot(nv) > -0.2 else 1
    if rim is not None:
        top = rows[1]
        bot = rows[0]
        for j, (a_, b_) in enumerate(((bot[0], top[0]), (top[0], top[4]), (top[4], bot[4]))):
            g.cyl_between(tuple(a_ + nrm * (thick / 2 + 0.006)), tuple(b_ + nrm * (thick / 2 + 0.006)), 0.016,
                          "%s_lisere_%d" % (name, j), rim, verts=6)
    return o


# Correction V3 : pétales POINTUS de deux longueurs (longs : pointe à z 1,90 ; courts : 1,55), liseré sombre sur
# les bords (contraste au test du gris : la corolle se fondait dans la terre), mât-balise déplacé à x 0,55 et
# relevé, tour-récepteur au-dessus du creuset (foyer). Sommets : pétales courts gauche et droit, pétales longs
# arrière gauche et droit, récepteur, mât (ère V : 5 à 6). Bord ouest ≤ -1,10 (rayon des pétales 1,04 -> 0,98).
# 3 ancres aux coins (le 4e coin est le mât), plaque au sol.
E14_PETALS = [(22.5, 1.55, 0.10), (67.5, 1.90, 0.07), (112.5, 1.90, 0.07), (157.5, 1.55, 0.10), (202.5, 1.75, 0.08),
              (247.5, 1.50, 0.10), (292.5, 1.50, 0.10), (337.5, 1.75, 0.08)]


def e14(k, even):
    g, S = k.g, k.S
    blanc = k.metal("blanc", gain=0.75, rough=0.35, metallic=0.15, grain=0.08, dirt=0.5, rust="#8A8478", rust_amount=0.35)
    orf = k.metal("or", "#BFA45E", gain=1.15, rough=0.46, metallic=0.85, grain=0.55, grain_scale=18.0, dirt=0.4,
                  rust="#6A5A30", rust_amount=0.35)
    cell = k.glossy("cellules", gain=2.2, rough=0.2, metallic=0.4)
    sombre = k.metal("cadre_sombre", "#2A2C32", gain=1.4, rough=0.4, metallic=0.6, grain=0.05)
    eclat = k.emit("creuset", "#FFE6A0", 1.6)
    bouche = MOUTH[14]
    rouge = k.emit("balise", "#FF2A2A", 2.0)
    cx, cy = -0.10, 0.12
    ground_pad(k, k.metal("dalle", "#A09A8A", gain=0.62 / k.k_alb, rough=0.55, metallic=0.1, grain=0.12, dirt=0.5), orf,
               inlay=sombre)
    g.frustum(g.regular(cx, cy, 0.54, 6, 0.0), 0.0, g.regular(cx, cy, 0.48, 6, 0.0), 0.36, "base", blanc, bevel_w=0.012)
    g.frustum(g.regular(cx, cy, 0.55, 6, 0.0), 0.24, g.regular(cx, cy, 0.53, 6, 0.0), 0.29, "base_bandeau", orf, bevel_w=0.004)
    fire_mouth(k, cx, cy + 0.54 * math.cos(math.pi / 6) / g.K - 0.01, 0.05, 0.30, 0.15, orf, bouche, strength=1.6, arch=True)
    # 3 ancres aux coins, haubans rigides vers le tambour
    cxb, cyb, _ = g.G(cx, cy, 0)
    for i, (fx, fy) in enumerate(((cx - 0.64, FRONT_Y), (cx + 0.64, FRONT_Y), (cx - 0.64, BACK_Y))):
        g.frustum(g.rect(fx, fy, 0.18, 0.14), 0.0, g.rect(fx, fy, 0.12, 0.09), 0.16, "ancre_%d" % i, blanc, bevel_w=0.01)
        g.cyl(fx, fy, 0.16, 0.05, 0.04, "ancre_tete_%d" % i, orf, verts=16, bevel_w=0.004)
        fb = g.G(fx, fy, 0.18)
        a = math.atan2(fb[1] - cyb, fb[0] - cxb)
        g.cyl_between(fb, (cxb + 0.50 * math.cos(a), cyb + 0.50 * math.sin(a), 0.30), 0.022, "hauban_%d" % i, sombre, verts=8)
    g.cyl(cx, cy, 0.36, 0.16, 0.70, "colonne", blanc, verts=32)
    for z in (0.55, 0.85):
        S.torus(0.165, 0.028, g.G(cx, cy, z), orf, "bague_colonne_%d" % int(z * 100))
    g.lathe([(0.16, 1.00), (0.30, 1.04), (0.34, 1.10), (0.20, 1.16)], (cx, cy), "moyeu", blanc, segs=40)
    bx, by = cxb, cyb
    for i, (a_deg, z1, w1) in enumerate(E14_PETALS):
        mirror_petal(k, bx, by, math.radians(a_deg), 0.26, 1.06, 0.98, z1, 0.10, w1, "petale_%d" % i, orf, cell, rim=sombre)
    zf = 1.78
    g.lathe([(0.06, zf - 0.12), (0.17, zf - 0.08), (0.21, zf + 0.02), (0.19, zf + 0.06)], (cx, cy), "creuset", blanc, segs=32,
            cap_top=False)
    g.cyl(cx, cy, zf - 0.02, 0.17, 0.03, "foyer", eclat, verts=32, bevel_w=0)
    S.sphere(0.085, g.G(cx, cy, zf + 0.06), eclat, "eclat", seg=24, rings=12)
    for i in range(3):
        a = math.radians(90 + 120 * i)
        g.cyl_between((bx + 0.30 * math.cos(a), by + 0.30 * math.sin(a), 1.12), (bx + 0.17 * math.cos(a), by + 0.17 * math.sin(a), zf - 0.08),
                      0.022, "bras_%d" % i, blanc, verts=8)
    # tour-récepteur : trépied fin au-dessus de l'éclat, tête de réception éclatante
    for i in range(3):
        a = math.radians(30 + 120 * i)
        g.cyl_between((bx + 0.19 * math.cos(a), by + 0.19 * math.sin(a), zf + 0.05), (bx, by, zf + 0.50), 0.016,
                      "recepteur_pied_%d" % i, blanc, verts=6)
    g.cyl(cx, cy, zf + 0.48, 0.065, 0.12, "recepteur", blanc, verts=20, bevel_w=0.008)
    S.sphere(0.06, g.G(cx, cy, zf + 0.64), eclat, "recepteur_eclat", seg=16, rings=8)
    mx, my = 0.55, -0.66
    zt = KEY[14]["chimney"][0][2]
    g.cyl(mx, my, 0.0, 0.13, 0.20, "pied_mat", blanc, verts=24)
    g.cyl(mx, my, 0.20, 0.10, zt - 0.30, "mat", blanc, verts=24)
    for z in (0.7, 1.5, 2.1):
        S.torus(0.105, 0.025, g.G(mx, my, z), orf, "bague_mat_%d" % int(z * 10))
    g.cyl(mx, my, zt - 0.10, 0.11, 0.10, "chapeau", orf, verts=24, r2=0.08)
    g.cyl(mx, my, zt - 0.02, 0.07, 0.02, "gueule", k.soot(), verts=16, bevel_w=0)
    S.sphere(0.06, g.G(mx + 0.13, my, zt - 0.05), rouge, "balise", seg=16, rings=8)
    g.cyl_between(g.G(mx + 0.02, my, zt - 0.05), g.G(mx + 0.13, my, zt - 0.05), 0.015, "bras_balise", blanc, verts=8)
    k.halo(cx, cy + 0.2, zf, "#FFE6A0", 7.0, "halo_creuset")
    k.halo(cx, 0.60, 0.12, bouche, 6.0, "halo_bouche")
    k.halo(mx + 0.13, my, zt - 0.05, "#FF2A2A", 2.0, "halo_balise")
    if even:
        # pétale supplémentaire à l'arrière, plus grand et plus redressé : panneau de CELLULES sombres cadré d'or
        # (correction V3, mineur 3 : faible contraste au gris ; le panneau sombre se détache de l'or et du sol)
        mirror_petal(k, bx, by + 0.10, math.radians(90), 0.30, 1.10, 1.02, 2.30, 0.12, 0.30, "petale_arriere", cell, orf,
                     thick=0.035, rim=orf)
        g.cyl_between((bx, by + 0.30, 1.05), (bx, by + 0.80, 2.00), 0.03, "hauban_arriere", blanc, verts=8)


# -------------------------------------------------------------------------------------------------
# Époque 15 · Légende : creuset en couronne flottant, halo ; pièce : seconde couronne
# -------------------------------------------------------------------------------------------------
def crown(k, x, y, z0, r, h_band, spikes, mat, gem, name, gem_k=0.45, verts=8):
    """Bandeau de couronne (rayon r, de z0 à z0 + h_band) et flèches facettées posées dessus ; une petite gemme
    lumineuse au pied de chaque flèche. spikes = [(angle Blender en degrés, hauteur, rayon du pied)] ; 90° =
    nord (arrière), 270° = sud (avant, face à la caméra)."""
    g, S = k.g, k.S
    g.lathe([(r * 0.94, z0), (r, z0 + 0.03), (r, z0 + h_band - 0.03), (r * 1.06, z0 + h_band)], (x, y), name + "_bandeau",
            mat, segs=48, cap_top=False, cap_bottom=False)
    g.lathe([(r * 0.86, z0), (r * 0.86, z0 + h_band)], (x, y), name + "_interieur", mat, segs=48, cap_top=False,
            cap_bottom=False)
    g.lathe([(r * 0.86, z0 + h_band), (r * 1.06, z0 + h_band)], (x, y), name + "_dessus", mat, segs=48, cap_top=False,
            cap_bottom=False)
    bx, by, _ = g.G(x, y, 0)
    for i, (a_deg, hh, rr) in enumerate(spikes):
        a = math.radians(a_deg)
        px, py = bx + r * math.cos(a), by + r * math.sin(a)
        S.cylinder(rr, hh * 0.55, (px, py, z0 + h_band + hh * 0.275 - 0.01), mat, "%s_fut_%d" % (name, i), verts=verts,
                   radius2=rr * 0.78, bevel_w=0.004)
        S.cylinder(rr * 0.78, hh * 0.47, (px, py, z0 + h_band + hh * 0.55 + hh * 0.235 - 0.02), mat,
                   "%s_pointe_%d" % (name, i), verts=verts, radius2=0.0, bevel_w=0)
        if gem is not None and gem_k > 0:
            S.sphere(rr * gem_k, (px + 0.0, py, z0 + h_band * 0.5), gem, "%s_gemme_%d" % (name, i), seg=12, rings=6)


# Époque 15 · Légende. Correction V3 :
# - couronne de 6 flèches HAUTES et ESPACÉES (165°, 125°, 90°, 15° derrière ; 195°, 345° basses devant) :
#   avec la flèche-cheminée, 5 sommets séparés de plus de 0,10 tuile (ère V : 5 à 6 ; le profil n'en avait que 2,
#   l'anneau-halo comblait les creux entre les flèches) ;
# - anneau-halo ABAISSÉ sous le bandeau de la couronne (z 1,05, rayon 0,96 : bord ouest -1,06) ; 6 perles
#   GROSSIES (rayon 0,06, environ 8 px HR) ; les 16 particules isolées (« bruit de rendu ») sont retirées : elles
#   relèvent de la couche de particules animée de la phase 2 ;
# - lévitation lisible : liseré lumineux SOUS le creuset et tache d'ombre sur le socle ;
# - plaque au sol et 4 obélisques-émetteurs aux coins (ancrage, majeur 2) ; le plot reste au centre.
E15 = {"cx": -0.10, "cy": 0.10, "disc": (0.46, 0.58, 0.96), "bowl_z": (0.86, 1.38), "rim_r": 0.72,
       "chim": (0.36, -0.24)}
E15_SPIKES = [(165, 1.00, 0.10), (125, 1.25, 0.11), (90, 0.95, 0.11), (10, 1.45, 0.10), (195, 0.55, 0.085),
              (345, 0.55, 0.085)]


def e15(k, even):
    g, S = k.g, k.S
    orb = k.metal("orblanc", gain=0.72, rough=0.24, metallic=0.65, grain=0.12, dirt=0.5, rust="#8A7A58", rust_amount=0.4)
    nacre = k.metal("nacre", gain=0.58, rough=0.32, metallic=0.15, grain=0.10, dirt=0.5, rust="#8A8478", rust_amount=0.35)
    lum = k.emit("lumiere", "#FFF2C0", 0.9)
    bain = k.emit("bain", MOUTH[15], 1.0)
    bouche = k.emit("bouche", MOUTH[15], 1.2)
    p = E15
    cx, cy = p["cx"], p["cy"]
    ground_pad(k, k.metal("dalle", "#A8A296", gain=0.55 / k.k_alb, rough=0.5, metallic=0.15, grain=0.10, dirt=0.5), orb,
               inlay=k.metal("or_incruste", "#B89A5A", gain=1.0, rough=0.3, metallic=0.85))
    # obélisques-émetteurs aux 4 coins (nacre, pointe d'or, gemme)
    for i, (fx, fy) in enumerate(((-0.78, FRONT_Y), (0.70, FRONT_Y), (-0.78, BACK_Y - 0.04), (0.74, BACK_Y - 0.04))):
        g.frustum(g.regular(fx, fy, 0.085, 4, math.pi / 4), 0.0, g.regular(fx, fy, 0.055, 4, math.pi / 4), 0.34,
                  "obelisque_%d" % i, nacre, bevel_w=0.006)
        g.cyl(fx, fy, 0.34, 0.055, 0.10, "obelisque_pointe_%d" % i, orb, verts=4, r2=0.0, bevel_w=0)
        S.sphere(0.035, g.G(fx, fy + 0.04, 0.24), lum, "obelisque_gemme_%d" % i, seg=10, rings=5)
    g.frustum(g.regular(cx, cy, 0.24, 6, 0.0), 0.0, g.regular(cx, cy, 0.19, 6, 0.0), 0.09, "plot", nacre, bevel_w=0.01)
    S.torus(0.16, 0.02, g.G(cx, cy, 0.095), orb, "plot_bague")
    g.cyl(cx, cy, 0.09, 0.05, p["disc"][0] - 0.09, "colonne_lumiere", lum, verts=16, bevel_w=0)
    z0, z1, R = p["disc"]
    g.frustum(g.regular(cx, cy, R - 0.10, 6, 0.0), z0, g.regular(cx, cy, R, 6, 0.0), z0 + 0.07, "socle_dessous", nacre,
              bevel_w=0.01)
    g.frustum(g.regular(cx, cy, R, 6, 0.0), z0 + 0.07, g.regular(cx, cy, R, 6, 0.0), z1 - 0.03, "socle_chant", orb,
              bevel_w=0.006)
    g.frustum(g.regular(cx, cy, R, 6, 0.0), z1 - 0.03, g.regular(cx, cy, R - 0.07, 6, 0.0), z1, "socle_dessus", nacre,
              bevel_w=0.008)
    g.lathe([(R * 0.868 + 0.004, z0 + 0.085), (R * 0.868 + 0.004, z0 + 0.105)], (cx, cy), "socle_lisere", lum, segs=6,
            cap_top=False, cap_bottom=False, smooth_deg=None)
    # tache d'ombre douce sur le socle, sous le creuset (le creuset flotte : il ne touche pas le socle)
    g.cyl(cx, cy + 0.04, z1 + 0.002, 0.42, 0.004, "ombre_creuset", k.metal("ombre", "#3A342C", gain=1.0, rough=0.8,
                                                                            metallic=0.0, grain=0.05, dirt=0.0),
          verts=40, bevel_w=0)
    zb0, zb1 = p["bowl_z"]
    rr = p["rim_r"]
    g.lathe([(0.10, zb0), (0.28, zb0 + 0.03), (0.46, zb0 + 0.12), (0.60, zb0 + 0.27), (rr - 0.02, zb1 - 0.08), (rr, zb1)],
            (cx, cy), "creuset", orb, segs=56, cap_top=False, smooth_deg=50)
    g.lathe([(0.001, zb0 - 0.01), (0.10, zb0 - 0.01), (0.10, zb0)], (cx, cy), "creuset_fond", nacre, segs=24)
    # liseré lumineux SOUS le creuset (lévitation)
    S.torus(0.22, 0.03, g.G(cx, cy, zb0 + 0.01), lum, "lisere_dessous")
    g.cyl(cx, cy, zb1 - 0.14, rr - 0.05, 0.04, "croute", k.metal("croute", "#5A4A30", gain=1.2, rough=0.6, metallic=0.4,
                                                                       grain=0.4, dirt=0.6), verts=56, bevel_w=0)
    g.cyl(cx, cy, zb1 - 0.105, 0.30, 0.012, "bain", bain, verts=40, bevel_w=0)
    S.torus(0.30, 0.03, g.G(cx, cy, zb0 + 0.05), orb, "creuset_bague")
    by_ = cy + 0.50 / g.K
    S.cylinder(0.13, 0.05, g.G(cx, by_, zb0 + 0.25), bouche, "bouche", verts=32, rot=(math.radians(62), 0, 0), bevel_w=0)
    S.torus(0.145, 0.028, g.G(cx, by_ + 0.012, zb0 + 0.25), orb, "bouche_cadre", rot=(math.radians(62), 0, 0))
    crown(k, cx, cy, zb1 - 0.02, rr, 0.16, E15_SPIKES, orb, lum, "couronne", gem_k=0.42)
    # anneau-halo abaissé, perles grossies
    zh = 1.05
    o = S.torus(0.96, 0.03, g.G(cx, cy, zh), orb, "anneau_halo", major_seg=96, minor_seg=10)
    o.rotation_euler = (math.radians(7), 0, 0)
    bx, by, _ = g.G(cx, cy, 0)
    beads = []
    for i in range(6):
        a = 2 * math.pi * (i + 0.5) / 6
        zz = zh + 0.96 * math.sin(a) * math.sin(math.radians(7))
        beads.append(S.sphere(0.06, (bx + 0.96 * math.cos(a), by + 0.96 * math.sin(a) * math.cos(math.radians(7)), zz), lum,
                              "perle_%d" % i, seg=16, rings=8))
    g.join(beads, "perles_halo")
    mx, my = p["chim"]
    zt = KEY[15]["chimney"][0][2]
    g.lathe([(0.17, z1), (0.15, z1 + 0.25), (0.125, zt - 0.55), (0.105, zt - 0.14), (0.13, zt - 0.06), (0.12, zt)], (mx, my),
            "fleche_cheminee", orb, segs=8, cap_top=False, smooth_deg=None, bevel_w=0.004)
    g.cyl(mx, my, zt - 0.12, 0.10, 0.11, "fond", k.soot(), verts=16, bevel_w=0)
    for z in (z1 + 0.55, zt - 0.85):
        g.cyl(mx, my, z, 0.16, 0.05, "bague_fleche_%d" % int(z * 100), nacre, verts=8, bevel_w=0.004)
    g.lathe([(0.112, zt - 0.36), (0.112, zt - 0.24)], (mx, my), "lueur_fleche", lum, segs=8, cap_top=False, cap_bottom=False,
            smooth_deg=None)
    g.cyl_between(g.G(mx, my, zb1 - 0.20), g.G(cx + 0.45, cy - 0.32, zb1 - 0.25), 0.035, "liaison", orb, verts=12)
    k.halo(cx, cy + 0.45, zb0 + 0.25, MOUTH[15], 8.0, "halo_bouche")
    k.halo(cx, cy, zb1, "#FFD98A", 5.0, "halo_bain")
    k.halo(cx, cy, 0.12, "#FFF2C0", 3.0, "halo_plot")
    if even:
        # seconde couronne : MÊME or blanc et mêmes flèches facettées que la première (correction V3, mineur 3 :
        # le « godet gris terne » de nacre est retiré), dessous en or, trait de lumière depuis le bain
        zc2 = zb1 + 1.05
        spikes2 = [(90, 0.72, 0.085), (30, 0.58, 0.08), (150, 0.58, 0.08), (330, 0.42, 0.075), (210, 0.42, 0.075)]
        crown(k, cx, cy - 0.04, zc2, 0.40, 0.12, spikes2, orb, lum, "couronne2", gem_k=0.40)
        g.cyl(cx, cy - 0.04, zc2 - 0.08, 0.26, 0.08, "couronne2_dessous", orb, verts=32, r2=0.38, bevel_w=0.004)
        S.torus(0.20, 0.025, g.G(cx, cy - 0.04, zc2 - 0.09), lum, "couronne2_lisere")
        g.cyl(cx, cy - 0.02, zb1 - 0.10, 0.025, zc2 - zb1 - 0.02, "trait_lumiere", lum, verts=12, bevel_w=0)
        k.halo(cx, cy - 0.04, zc2 + 0.1, "#FFF2C0", 3.0, "halo_couronne2")


BUILDERS = {2: e2, 3: e3, 4: e4, 5: e5, 6: e6, 7: e7, 8: e8, 9: e9, 10: e10, 11: e11, 12: e12, 13: e13, 14: e14, 15: e15}


def build(S, C, variant):
    import geo
    import passes
    geo.S = S
    passes.install(S)
    n = int(variant[1:])
    k = Kit(S, C, geo, n)
    if n == 2:
        e1_piece(k)
        return
    e = PRM.epoch_of(n)
    BUILDERS[e](k, PRM.is_even(n))
