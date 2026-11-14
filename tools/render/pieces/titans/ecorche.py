"""ÉCORCHÉS, mordeurs MUTANTS : la lignée que pond l'Écorcheur (ecorcheur.py) et que les nids proposent tard dans l'évolution.
Refonte ORGANIQUE (s43 3d-ecorches, 13/11) : les Écorchés d'avant étaient des quadrupèdes à blocs et à cristaux, peu lisibles ; ce sont
désormais des bêtes à la PEAU ARRACHÉE : muscle strié humide (fibres le long des membres, matière `muscle` ci-dessous), tendons ivoire
tendus des hanches aux pieds et des épaules au crâne, côtes et vertèbres à nu, crâne d'os, lambeaux de peau morte. TROIS variantes (le
« stade » du rendu = la variante, shared/robots/titans.lua T.ECORCHE.variants), distinctes d'un coup d'œil :
  1 RÔDEUR : BAS et ALLONGÉ (dos à 0,7 tuile, 4,5 tuiles du museau à la queue-fouet), pattes en araignée aux genoux hauts, chair
    PÂLE (os et muscle rose délavé) : la plus claire ;
  2 PORTEUR : MASSIF, dos en bosse, pattes en colonnes, porte sa CHARGE : un amas de poches de ponte sombres sanglées de tendons, piquées
    de pustules lumineuses ; chair presque noire : la plus sombre ;
  3 HURLEUR : avant DRESSÉ, cou levé, GUEULE GRANDE OUVERTE sur une gorge lumineuse, collerette d'épines et de membranes ; chair ROUGE
    à vif : luminance médiane.
Lueur rendue BLANCHE (GLOW_BLANC) : le prototype la teint de la couleur de la variante (T.ECORCHE.variants[i].lueur) mêlée à l'ère.
Modèle paramétrique ANIMÉ : `build_anime(S, lot, variante, u, attaque)` (course 8 images, attaque 4 : batch_titans.py). Repère LOCAL :
+x = avant, +y = gauche, +z = haut ; origine = sous le centre du corps, au sol.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
if XP not in sys.path:
    sys.path.insert(0, XP)
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import geo as G  # noqa: E402
import greb as R  # noqa: E402
import titans_mat as TM  # noqa: E402
from juggernaut import pointe, plaque  # noqa: E402
from kaiju import pas, ik2, ellipse  # noqa: E402

PREFIX = "em_"
GRIS = os.environ.get("FO_GRIS", "") == "1"
SERIE = {"course": 8, "attaque": 4, "densite": 64.0, "R": 3.3, "zmax": 3.6, "sol": 40.0}
AO = 0.3
GLOW_BLANC = True
AMP = 0.42
# s43 tranche 2 : TAILLE d'avant rendue (environ 4 tuiles du museau à la queue) : chaque variante est modelée puis agrandie de
# TAILLE[variante] (lot.xf) ; l'amplitude du pas est divisée d'autant dans le repère du modèle, la foulée au sol reste FOULEE.
TAILLE = {1: 1.15, 2: 1.45, 3: 1.3}
AMP_MODELE = [AMP]
# tranche 3 : éclaircissement des crêtes de fibres par variante (contraste p90-p10 >= 0,35 en gardant l'ordre de luminance)
CONTRASTE_CRETE = {1: 1.0, 2: 1.0, 3: 1.0}
# exposition par variante (facteur sur toutes les couleurs de surface) : charte lum. médiane <= 0,38 et ordre rôdeur > hurleur > porteur
ECLAT = {1: 0.72, 2: 0.92, 3: 1.15}
FOULEE = 2 * 0.42

# Variante : couleurs LINÉAIRES du muscle (creux, fond, crêtes), de l'os, du tendon et de la peau morte ; le reste (silhouette) est dans
# les fonctions de pose propres à chaque variante (POSES).
COULEURS = {
    # s43 tranche 2 (QA : charte lum. médiane <= 0,38, pas de blanc brûlé) : rôdeur gris-rose délavé (et non plus blanc-beige), os
    # jauni sombre ; l'ordre de luminance rôdeur > hurleur > porteur reste (tests/titans_test.lua §8)
    # QA tour 3 : rôdeur ROUGE SANG (écarlate, le plus clair des trois), moins d'os blanc ; porteur : chair rouge sombre nettement plus
    # claire que sa charge presque noire (valeurs séparées, nervures claires) ; hurleur cramoisi sombre, crâne d'os jauni sombre
    # tranche 4 : séparées aussi par la TEINTE : rôdeur chair rosée (saumon), hurleur rouge sang sombre à collerette noire, porteur
    # brun-bordeaux sous sa charge noire veinée de nervures claires
    1: {"creux": (0.12, 0.03, 0.03), "fond": (0.33, 0.115, 0.10), "crete": (0.85, 0.48, 0.40), "os": (0.30, 0.24, 0.14),
        "tendon": (0.55, 0.45, 0.32), "peau": (0.20, 0.13, 0.12), "gorge": (0.20, 0.025, 0.03)},
    2: {"creux": (0.010, 0.005, 0.004), "fond": (0.06, 0.025, 0.02), "crete": (0.40, 0.20, 0.12), "os": (0.15, 0.10, 0.04),
        "tendon": (0.70, 0.56, 0.34), "peau": (0.025, 0.018, 0.022), "gorge": (0.10, 0.01, 0.015), "sac": (0.008, 0.005, 0.007)},
    3: {"creux": (0.03, 0.002, 0.003), "fond": (0.24, 0.012, 0.014), "crete": (0.66, 0.08, 0.055), "os": (0.18, 0.12, 0.05),
        "tendon": (0.40, 0.30, 0.20), "peau": (0.012, 0.008, 0.009), "gorge": (0.20, 0.008, 0.025)},
}


# ------------------------------------------------------------------------------------------------ matières
def muscle(nom, creux, fond, crete, rough=0.36, echelle=14.0, bosse=0.9, graine=0.0, contraste=1.0):
    """Muscle ÉCORCHÉ : fibres (vagues en bandes le long de u : la longueur des tubes et des lofts), marbrure, relief des fibres, vernis
    humide (couche de vernis). Couleurs linéaires : creux des fibres, fond, crêtes."""
    import bpy
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    wv = N.new("ShaderNodeTexWave")
    wv.wave_type = "BANDS"
    wv.bands_direction = "Y"
    wv.inputs["Scale"].default_value = echelle
    # tranche 4 : fibres FINES et serrées le long du muscle (peu de distorsion) : des sillons, pas des bandes de tigre
    wv.inputs["Distortion"].default_value = 1.2
    wv.inputs["Detail"].default_value = 1.0
    wv.inputs["Detail Scale"].default_value = 1.2
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (graine * 0.31, graine * 0.17, 0.0)
    L.new(tc.outputs["UV"], mp.inputs["Vector"])
    L.new(mp.outputs["Vector"], wv.inputs["Vector"])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 4.0
    nz.inputs["Detail"].default_value = 5.0
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    a = N.new("ShaderNodeMath")
    a.operation = "MULTIPLY"
    a.inputs[1].default_value = 0.4      # tranche 4 : la fibre module peu la couleur ; le relief (bosse) la dessine
    L.new(wv.outputs["Fac"], a.inputs[0])
    b = N.new("ShaderNodeMath")
    b.operation = "MULTIPLY_ADD"
    L.new(nz.outputs["Fac"], b.inputs[0])
    b.inputs[1].default_value = 0.8      # tranche 4 : marbrure des groupes musculaires (clairs sur les lobes, sombres aux creux)
    L.new(a.outputs["Value"], b.inputs[2])
    rp = N.new("ShaderNodeValToRGB")
    e = rp.color_ramp.elements
    # tranche 3 (QA A3) : creux deux fois plus noirs, crêtes plus claires (CONTRASTE_CRETE de la variante), rampe plus raide
    e[0].position, e[0].color = 0.22, tuple(c * 0.5 for c in creux) + (1.0,)
    e[1].position, e[1].color = 0.85, tuple(min(1.0, c * contraste) for c in crete) + (1.0,)
    mid = e.new(0.5)
    mid.color = tuple(fond) + (1.0,)
    L.new(b.outputs["Value"], rp.inputs["Fac"])
    # tranche 4 : ombres de creux entre les groupes musculaires, sous les côtes et les tendons (occlusion locale dans la couleur) :
    # le contraste vient du volume, pas de bandes sombres
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.18
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.08
    L.new(ao.outputs["AO"], mr.inputs["Value"])
    mx = N.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = "MULTIPLY"
    mx.inputs[0].default_value = 1.0
    ins = [x for x in mx.inputs if x.type == "RGBA"]
    L.new(rp.outputs["Color"], ins[0])
    L.new(mr.outputs["Result"], ins[1])
    L.new([x for x in mx.outputs if x.type == "RGBA"][0], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = 0.0
    # tranche 3 (QA A4) : vernis humide atténué et plus diffus : le reflet du soleil le long du dos (vue de dos) brûlait en blanc
    for k, v in (("Specular IOR Level", 0.45), ("Coat Weight", 0.3), ("Coat Roughness", 0.25)):
        if k in p.inputs:
            p.inputs[k].default_value = v
    bp = N.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = bosse
    bp.inputs["Distance"].default_value = 0.008
    L.new(wv.outputs["Fac"], bp.inputs["Height"])
    L.new(bp.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def lisse(nom, col, rough=0.3, coat=0.25, cavites=True):
    """Os, tendon, poche : surface lisse à légère marbrure (bruit), vernis léger."""
    import bpy
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 6.0
    nz.inputs["Detail"].default_value = 4.0
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    rp = N.new("ShaderNodeValToRGB")
    e = rp.color_ramp.elements
    e[0].position, e[0].color = 0.3, tuple(c * 0.62 for c in col) + (1.0,)
    e[1].position, e[1].color = 0.75, tuple(min(1.0, c * 1.12) for c in col) + (1.0,)
    L.new(nz.outputs["Fac"], rp.inputs["Fac"])
    col_out = rp.outputs["Color"]
    if cavites:
        # s43 tranche 2 : ombres de cavités (occlusion locale) multipliées dans la couleur : sutures, orbites, creux entre os
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.12
        mp2 = N.new("ShaderNodeMapRange")
        mp2.inputs["To Min"].default_value = 0.18
        L.new(ao.outputs["AO"], mp2.inputs["Value"])
        mx = N.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        mx.blend_type = "MULTIPLY"
        mx.inputs[0].default_value = 1.0
        ins = [x for x in mx.inputs if x.type == "RGBA"]
        L.new(col_out, ins[0])
        L.new(mp2.outputs["Result"], ins[1])
        col_out = [x for x in mx.outputs if x.type == "RGBA"][0]
    L.new(col_out, p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = 0.0
    for k, v in (("Coat Weight", coat), ("Coat Roughness", 0.2)):
        if k in p.inputs:
            p.inputs[k].default_value = v
    bp = N.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.25
    bp.inputs["Distance"].default_value = 0.01
    L.new(nz.outputs["Fac"], bp.inputs["Height"])
    L.new(bp.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def matieres(S, stage):
    M = TM.matieres(S, PREFIX, GRIS)
    if GRIS:
        for k in ("muscle", "tendon", "sac", "gorge"):
            M[k] = M["chair"]
        M["peau_morte"] = M["cavite"] = M["peau"]
        M["gorge_lum"], M["oeil"], M["pustule"] = M["coeur"], M["conduit"], M["conduit"]
        return M
    c = {k: tuple(x * ECLAT[stage] for x in v) for k, v in COULEURS[stage].items()}
    M["muscle"] = muscle(PREFIX + "muscle", c["creux"], c["fond"], c["crete"], graine=stage, contraste=CONTRASTE_CRETE[stage])
    M["gorge"] = muscle(PREFIX + "gorge", tuple(x * 0.4 for x in c["gorge"]), c["gorge"], tuple(min(1.0, x * 2.2) for x in c["gorge"]),
                        rough=0.25, echelle=2.5, bosse=0.3)
    M["os"] = lisse(PREFIX + "os", c["os"], rough=0.42, coat=0.1)
    M["tendon"] = lisse(PREFIX + "tendon", c["tendon"], rough=0.22, coat=0.45)
    M["peau_morte"] = lisse(PREFIX + "peau_morte", c["peau"], rough=0.7, coat=0.0)
    M["cavite"] = lisse(PREFIX + "cavite", tuple(x * 0.12 for x in c["os"]), rough=0.8, coat=0.0, cavites=False)
    M["sac"] = lisse(PREFIX + "sac", c.get("sac", c["peau"]), rough=0.15, coat=0.5)
    # émissifs (couche lueur, rendus blancs, teints en jeu) : yeux, gorge, pustules
    M["oeil"] = S.mat_emissive(PREFIX + "conduit_oeil", (1.0, 0.95, 0.85), strength=3.0, base=(0.3, 0.2, 0.1), main_scale=0.1)
    # tranche 3 (QA A4 : blanc brûlé du hurleur) : la gorge brûle dans la couche LUEUR seule ; dans la couche principale, chair sombre
    M["gorge_lum"] = S.mat_emissive(PREFIX + "conduit_gorge", (1.0, 0.92, 0.85), strength=3.0, base=(0.12, 0.015, 0.02), main_scale=0.04)
    M["pustule"] = S.mat_emissive(PREFIX + "conduit_pustule", (1.0, 0.75, 0.45), strength=2.4, base=(0.5, 0.25, 0.1), main_scale=0.55)
    return M


# ------------------------------------------------------------------------------------------------ primitives
def ellipsoide(c, rx, ry, rz, seg=12, rings=7):
    v, f, u = G.sphere((0.0, 0.0, 0.0), 1.0, seg, rings)
    return [(c[0] + p[0] * rx, c[1] + p[1] * ry, c[2] + p[2] * rz) for p in v], f, u


def renfle(a, b, r0, r1, bombe=0.35, n=7, segs=10):
    """Muscle fusiforme de a à b : rayon r0 -> r1, ventre renflé de `bombe` au milieu."""
    pts = [G.lerp(a, b, i / float(n)) for i in range(n + 1)]
    L = G.length(G.sub(b, a)) or 1e-6
    def rf(s, i):
        t = i / float(n)
        return (r0 + (r1 - r0) * t) * (1.0 + bombe * math.sin(math.pi * t))
    return G.tube(pts, r0, segs, rfun=rf)


def cable(lot, M, pts, r, cle="tendon"):
    lot.put(M[cle], G.tube(G.catmull(pts, 4) if len(pts) > 2 else pts, r, 6))


# ------------------------------------------------------------------------------------------------ corps
def torse(lot, M, ctrl, rayon, cotes, vertebres=True, peau=()):
    """Corps : loft le long de la colonne `ctrl` (queue -> nuque), rayons `rayon(t) -> (rw, rh)` ; côtes à nu (`cotes` : (t0, t1, n)),
    vertèbres, lambeaux de peau morte aux t de `peau`. Rend (pts, prof)."""
    pts = G.catmull(ctrl, 6)
    n = len(pts)
    rings, prof = [], []
    for i, p in enumerate(pts):
        t = i / float(n - 1)
        rw, rh = rayon(t)
        rings.append(ellipse(p, rw, rh, 12))
        prof.append((p, rw, rh, t))
    lot.put(M["muscle"], G.loft(rings, True, True))
    t0, t1, nc = cotes
    for k in range(nc):
        t = t0 + (t1 - t0) * k / max(1, nc - 1)
        i = int(t * (n - 1))
        p, rw, rh, _ = prof[i]
        for s in (-1, 1):
            arc = []
            for q in range(9):
                a = math.radians(80 - 125 * q / 8.0)
                arc.append((p[0] - 0.05 * q / 8.0, p[1] + s * rw * 1.04 * math.cos(a), p[2] + rh * 1.04 * math.sin(a)))
            lot.put(M["os"], G.tube(arc, 0.026 + 0.012 * rw, 6))
    if vertebres:
        for i in range(1, n - 1):
            p, rw, rh, t = prof[i]
            if t < 0.05:
                continue
            d = G.norm(G.sub(pts[i + 1], pts[i - 1]))
            top = (p[0], p[1], p[2] + rh * 0.95)
            lot.put(M["os"], ellipsoide(top, 0.05 + 0.04 * rh, 0.04 + 0.03 * rh, 0.035 + 0.03 * rh, 8, 4))
            if i % 2 == 0 and t > 0.3:
                lot.put(M["os"], pointe(top, G.norm((-0.5 * d[0], 0.0, 1.0)), 0.10 + 0.22 * rh, 0.03 + 0.02 * rh, 5))
    for tp, s in peau:
        i = int(tp * (n - 1))
        p, rw, rh, _ = prof[i]
        d = G.norm(G.sub(pts[min(n - 1, i + 1)], pts[max(0, i - 1)]))
        lot.put(M["peau_morte"], plaque((p[0], p[1] + s * rw * 0.9, p[2] + rh * 0.25), G.norm((0.0, s * 1.0, 0.35)), rw * 1.1, rh * 1.2,
                                        0.03, up=d, coins=0.45, bis=0.9))
    # tendons du flanc : de la hanche à l'épaule, tendus sur les côtes
    for s in (-1, 1):
        line = [(pts[i][0], pts[i][1] + s * prof[i][1] * 1.02, pts[i][2] - prof[i][2] * 0.35) for i in range(int(n * 0.35), n - 1, 3)]
        if len(line) > 2:
            lot.put(M["tendon"], G.tube(line, 0.022, 6))
    return pts, prof


def patte(lot, M, hanche, pied0, u, l1, l2, r, pole, levee=0.22, griffe=0.24, appui=0.55):
    """Patte : cuisse musclée renflée, tibia sec (os + tendon d'Achille), pied à trois griffes ; `pole` : côté du genou."""
    dx, dz = pas(u, AMP_MODELE[0], levee, appui)
    pied = (pied0[0] + dx, pied0[1], pied0[2] + dz)
    genou = ik2(hanche, pied, l1, l2, pole)
    lot.put(M["muscle"], ellipsoide(hanche, r * 1.35, r * 1.2, r * 1.3, 10, 5))
    lot.put(M["muscle"], renfle(hanche, genou, r * 1.1, r * 0.6, 0.7))
    # tranche 4 : groupes musculaires lisibles par le volume : lobe externe de la cuisse ou de l'épaule, et lobe arrière
    cu = G.sub(genou, hanche)
    ext = G.cross(cu, (0.0, 0.0, 1.0))
    ext = G.norm(ext) if G.length(ext) > 1e-4 else (0.0, 1.0, 0.0)
    if G.dot(ext, (0.0, 1.0 if hanche[1] >= 0 else -1.0, 0.0)) < 0:
        ext = G.mul(ext, -1.0)
    lot.put(M["muscle"], renfle(G.add(hanche, G.mul(ext, r * 0.55)), G.add(G.lerp(hanche, genou, 0.7), G.mul(ext, r * 0.35)), r * 0.7, r * 0.4, 0.8, 6, 9))
    lot.put(M["muscle"], renfle(G.add(hanche, (0.0, 0.0, r * 0.5)), G.add(G.lerp(hanche, genou, 0.6), (0.0, 0.0, r * 0.4)), r * 0.6, r * 0.35, 0.8, 6, 9))
    lot.put(M["os"], ellipsoide(genou, r * 0.62, r * 0.62, r * 0.62, 8, 4))
    cheville = G.lerp(genou, pied, 0.86)
    lot.put(M["muscle"], renfle(genou, G.lerp(genou, pied, 0.5), r * 0.62, r * 0.32, 0.5, 5, 8))
    lot.put(M["os"], G.tube([genou, cheville, pied], r * 0.3, 6))
    # tendons : de la hanche au genou (devant), du mollet au talon (derrière)
    tib = G.sub(pied, genou)
    lat = G.cross(tib, (0.0, 0.0, 1.0))
    off = G.mul(G.norm(lat) if G.length(lat) > 1e-4 else (0.0, 1.0, 0.0), r * 0.7)
    cable(lot, M, [G.add(hanche, (0.0, 0.0, r * 0.6)), G.add(G.lerp(hanche, genou, 0.5), (0.0, 0.0, r * 0.95)), G.add(genou, (0.0, 0.0, r * 0.5))],
          r * 0.16)
    cable(lot, M, [G.add(G.lerp(genou, pied, 0.15), off), G.add(G.lerp(genou, pied, 0.6), G.mul(off, 0.6)), cheville], r * 0.13)
    cable(lot, M, [G.add(G.lerp(genou, pied, 0.15), G.mul(off, -1.0)), G.add(G.lerp(genou, pied, 0.6), G.mul(off, -0.6)), cheville], r * 0.13)
    d = G.norm((pied[0] - genou[0], pied[1] - genou[1], 0.0)) if abs(pied[0] - genou[0]) + abs(pied[1] - genou[1]) > 1e-3 else (1.0, 0.0, 0.0)
    fw = G.norm((1.0, 0.25 * d[1], 0.0))
    for ay in (-0.45, 0.0, 0.45):
        dd = G.norm((fw[0], fw[1] + ay, -0.35))
        lot.put(M["os"], pointe((pied[0], pied[1] + ay * r, pied[2] + 0.04), dd, griffe * (1.0 if ay == 0 else 0.8), r * 0.22, 5))
    lot.put(M["muscle"], ellipsoide((pied[0], pied[1], pied[2] + r * 0.25), r * 0.55, r * 0.5, r * 0.3, 8, 4))
    return genou, pied


def tete(lot, M, base, k, tangage, ouverture, crane, dents=3, yeux=2, gorge=1.0):
    """Tête posée en `base`, échelle k, tangage (rad, > 0 : museau levé) : crâne d'os (loft), muscles des joues, mâchoire ouverte de
    `ouverture` (rad), dents, gorge lumineuse, yeux. `crane` : (longueur, largeur, hauteur) relatifs."""
    lx, ly, lz = crane
    ct, st = math.cos(tangage), math.sin(tangage)
    bx, by, bz = base

    def P(x, y, z):
        x, y, z = x * k * lx, y * k * ly, z * k * lz
        return (bx + x * ct - z * st, by + y, bz + x * st + z * ct)

    def sect(x, w, h, zc):
        return [P(x, -w, zc - h * 0.3), P(x, -w * 0.85, zc + h * 0.55), P(x, -w * 0.4, zc + h), P(x, 0.0, zc + h * 1.05), P(x, w * 0.4, zc + h),
                P(x, w * 0.85, zc + h * 0.55), P(x, w, zc - h * 0.3), P(x, w * 0.5, zc - h * 0.5), P(x, -w * 0.5, zc - h * 0.5)]
    lot.put(M["os"], G.loft([sect(-0.15, 0.24, 0.22, 0.05), sect(0.15, 0.30, 0.26, 0.08), sect(0.45, 0.24, 0.18, 0.06),
                             sect(0.8, 0.15, 0.12, 0.02), sect(1.0, 0.08, 0.07, 0.0)], True, True))
    # arcades et orbites : bourrelets d'os, yeux lumineux enfoncés
    for s in (-1, 1):
        lot.put(M["os"], ellipsoide(P(0.32, s * 0.24, 0.24), 0.09 * k * lx, 0.07 * k, 0.05 * k, 8, 4))
        # s43 tranche 2 : orbites et fosses (ombres de cavités) : creux sombres autour des yeux, narines, fosse temporale
        lot.put(M["cavite"], ellipsoide(P(0.33, s * 0.245, 0.13), 0.1 * k * lx, 0.06 * k, 0.07 * k, 8, 4))
        lot.put(M["cavite"], ellipsoide(P(0.9, s * 0.07, 0.07), 0.05 * k * lx, 0.03 * k, 0.03 * k, 6, 3))
        lot.put(M["cavite"], ellipsoide(P(0.0, s * 0.27, 0.12), 0.08 * k * lx, 0.05 * k, 0.07 * k, 8, 4))
        for q in range(yeux):
            lot.put(M["oeil"], ellipsoide(P(0.38 - 0.12 * q, s * 0.27, 0.15 - 0.03 * q), 0.035 * k, 0.03 * k, 0.03 * k, 8, 4))
    # mâchoire : tourne autour de la charnière (x = -0.05, z = -0.1) de `ouverture`
    co, so = math.cos(ouverture), math.sin(ouverture)

    def J(x, y, z):
        xx, zz = x + 0.05, z + 0.1
        return P(-0.05 + xx * co + zz * so, y, -0.1 - xx * so + zz * co)
    jaw = [[J(x, -w, -0.04), J(x, w, -0.04), J(x, w * 0.7, -0.04 - hh), J(x, 0.0, -0.06 - hh * 1.1), J(x, -w * 0.7, -0.04 - hh)]
           for x, w, hh in ((-0.05, 0.22, 0.14), (0.35, 0.19, 0.12), (0.7, 0.12, 0.09), (0.95, 0.06, 0.05))]
    lot.put(M["os"], G.loft(jaw, True, True))
    # joues : muscles masséters du crâne à la mâchoire (fibres visibles)
    for s in (-1, 1):
        lot.put(M["muscle"], renfle(P(0.05, s * 0.24, 0.12), J(0.3, s * 0.19, -0.1), 0.06 * k, 0.05 * k, 0.6, 5, 8))
        cable(lot, M, [P(-0.1, s * 0.22, 0.2), P(0.15, s * 0.26, 0.05), J(0.45, s * 0.17, -0.08)], 0.015 * k)
    # dents : rangées haute et basse, crocs devant
    nd = 4 + 2 * dents
    for q in range(nd):
        x = 0.2 + 0.75 * q / float(nd - 1)
        L = (0.10 + (0.08 if q >= nd - 2 else 0.0)) * (1.0 + 0.15 * dents)
        for s in (-1, 1):
            wq = 0.22 - 0.15 * q / float(nd - 1)
            lot.put(M["os"], pointe(P(x, s * wq, -0.02), G.norm(G.sub(P(x, s * wq * 0.9, -1.0), P(x, s * wq, 0.0))), L * k, 0.022 * k, 4))
            lot.put(M["os"], pointe(J(x * 0.95, s * wq * 0.85, -0.04), G.norm(G.sub(J(x, s * wq * 0.8, 1.0), J(x, s * wq * 0.85, 0.0))),
                                    L * 0.8 * k, 0.02 * k, 4))
    # gorge : intérieur de chair sombre et cœur lumineux au fond, qui grossit avec l'ouverture
    gc = G.lerp(P(0.2, 0.0, -0.04), J(0.2, 0.0, -0.04), 0.5)
    lot.put(M["gorge"], ellipsoide(gc, 0.3 * k * lx, 0.16 * k, 0.08 * k + 0.12 * k * min(1.0, ouverture), 10, 5))
    rv = (0.05 + 0.06 * min(1.2, ouverture)) * k * gorge
    o = min(1.0, ouverture)
    lot.put(M["gorge_lum"], ellipsoide(J(0.12 + 0.2 * o, 0.0, -0.02 + 0.03 * o), rv * 1.3, min(rv, 0.15 * k), min(rv * 0.8, 0.1 * k), 10, 5))
    return P, J


def cou(lot, M, a, b, r0, r1):
    """Cou : muscle renflé de la nuque `a` à la base du crâne `b`, deux tendons dorsaux, une vertèbre en saillie."""
    lot.put(M["muscle"], renfle(a, b, r0, r1, 0.15, 6, 12))
    for s in (-1, 1):
        cable(lot, M, [G.add(a, (0.0, s * r0 * 0.6, r0 * 0.8)), G.add(G.lerp(a, b, 0.5), (0.0, s * (r0 + r1) * 0.35, (r0 + r1) * 0.5)),
                       G.add(b, (0.0, s * r1 * 0.5, r1 * 0.7))], 0.02)
    for q in range(1, 4):
        p = G.lerp(a, b, q / 4.0)
        lot.put(M["os"], ellipsoide(G.add(p, (0.0, 0.0, (r0 + r1) * 0.48)), 0.05, 0.04, 0.04, 8, 4))


# ------------------------------------------------------------------------------------------------ poses des variantes
def queue(lot, M, pts, rmax, sway):
    """Queue-fouet : tube effilé suivant `pts` (base -> pointe), osselets en saillie, pointe d'os."""
    pp = [(p[0], p[1] + sway * (i / float(len(pts) - 1)) ** 1.6, p[2]) for i, p in enumerate(pts)]
    pp = G.catmull(pp, 4)
    n = len(pp)
    lot.put(M["muscle"], G.tube(pp, rmax, 8, rfun=lambda s, i: rmax * (1.0 - 0.85 * i / float(n - 1))))
    for i in range(1, n - 1, 2):
        lot.put(M["os"], ellipsoide(G.add(pp[i], (0.0, 0.0, rmax * (1.0 - 0.85 * i / float(n - 1)) * 0.9)), 0.03, 0.025, 0.025, 6, 3))
    d = G.norm(G.sub(pp[-1], pp[-2]))
    lot.put(M["os"], pointe(pp[-1], d, 0.3, 0.035, 5))


def rodeur(lot, M, u, a, bob, lunge, ouv):
    """RÔDEUR : bas et allongé, genoux d'araignée au-dessus du dos, tête longue au ras du sol, queue-fouet."""
    sw = 0.12 * math.sin(G.TAU * u)
    x0 = lunge
    ctrl = [(-1.15 + x0, 0.0, 0.62 + bob * 0.5), (-0.5 + x0, 0.0, 0.70 + bob), (0.25 + x0, 0.0, 0.74 + bob), (0.85 + x0, 0.0, 0.70 + bob),
            (1.15 + x0, 0.0, 0.64 + bob)]
    def ray(t):
        rw = 0.28 + 0.12 * math.sin(math.pi * min(1.0, t * 1.1)) - 0.05 * math.exp(-((t - 0.45) / 0.12) ** 2)
        rh = 0.24 + 0.09 * math.sin(math.pi * min(1.0, t * 1.05))
        return rw, rh
    pts, prof = torse(lot, M, ctrl, ray, (0.42, 0.85, 6), peau=((0.2, 1), (0.75, -1)))
    queue(lot, M, [(-1.1 + x0, 0.0, 0.6 + bob * 0.5), (-1.6 + x0, 0.0, 0.48), (-2.1 + x0, 0.0, 0.32), (-2.35 + x0, 0.0, 0.24)], 0.17, -sw * 2.2)
    ph = {"AG": 0.0, "PD": 0.0, "AD": 0.5, "PG": 0.5}
    for k, (hx, fx) in (("AG", (0.75, 1.1)), ("AD", (0.75, 1.1)), ("PG", (-0.7, -0.95)), ("PD", (-0.7, -0.95))):
        s = 1 if k[1] == "G" else -1
        hz = 0.66 + bob
        patte(lot, M, (hx + x0, s * 0.2, hz), (fx + (x0 if a is None else 0.0), s * 0.95, 0.0), u + ph[k], 0.72, 0.82, 0.11,
              G.norm((0.15 if k[0] == "A" else -0.15, s * 0.45, 1.0)), levee=0.2, griffe=0.22)
    nuque = pts[-1]
    b = (nuque[0] + 0.28, 0.0, nuque[2] - 0.06)
    cou(lot, M, nuque, b, 0.15, 0.1)
    tete(lot, M, b, 0.62, -0.18 - 0.15 * ouv, 0.18 + ouv, (1.25, 0.85, 0.75), dents=2, yeux=2, gorge=0.7)


def porteur(lot, M, u, a, bob, lunge, ouv):
    """PORTEUR : massif, dos en bosse, pattes en colonnes, sa CHARGE (poches de ponte sanglées) sur le dos, tête basse et lourde."""
    x0 = lunge * 0.6
    ctrl = [(-1.05 + x0, 0.0, 0.70 + bob * 0.5), (-0.55 + x0, 0.0, 0.98 + bob), (0.1 + x0, 0.0, 1.08 + bob), (0.65 + x0, 0.0, 1.0 + bob),
            (0.98 + x0, 0.0, 0.86 + bob)]
    def ray(t):
        return 0.30 + 0.30 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7, 0.26 + 0.24 * math.sin(math.pi * min(1.0, t * 1.1)) ** 0.7
    pts, prof = torse(lot, M, ctrl, ray, (0.4, 0.8, 5), vertebres=False, peau=((0.25, 1), (0.3, -1), (0.8, 1), (0.85, -1)))
    queue(lot, M, [(-1.0 + x0, 0.0, 0.7 + bob * 0.5), (-1.35 + x0, 0.0, 0.5), (-1.65 + x0, 0.0, 0.3)], 0.14, -0.1 * math.sin(G.TAU * u))
    # CHARGE : amas de poches de ponte sur le dos, sanglé de tendons qui ceinturent le ventre, pustules lumineuses
    cz = 1.08 + bob
    sacs = ((0.0, 0.0, 0.62, 0.50, 0.46, 0.42), (-0.42, 0.18, 0.52, 0.34, 0.30, 0.30), (-0.36, -0.22, 0.48, 0.32, 0.28, 0.28),
            (0.38, 0.12, 0.50, 0.30, 0.28, 0.27), (0.25, -0.25, 0.44, 0.26, 0.24, 0.24), (-0.05, 0.05, 1.02, 0.30, 0.27, 0.26),
            (-0.6, 0.0, 0.32, 0.22, 0.30, 0.2))
    for (sx, sy, sz, rx, ry, rz) in sacs:
        lot.put(M["sac"], ellipsoide((sx + x0, sy, cz + sz * 0.9), rx, ry, rz, 14, 7))
        # s43 tranche 2 (QA : « boules noires brillantes peu lisibles ») : chaque poche est veinée de deux nervures claires
        for ph0 in (0.35, 1.9):
            arc = []
            for q in range(9):
                t = -1.25 + 2.5 * q / 8.0
                arc.append((sx + x0 + 1.02 * rx * math.sin(t) * math.cos(ph0), sy + 1.02 * ry * math.sin(t) * math.sin(ph0),
                            cz + sz * 0.9 + 1.02 * rz * math.cos(t)))
            lot.put(M["tendon"], G.tube(arc, 0.022, 5))
    for q, (sx, sy, sz) in enumerate(((0.12, 0.3, 0.75), (-0.3, 0.35, 0.6), (0.3, -0.33, 0.62), (-0.48, -0.3, 0.5), (0.0, -0.1, 1.25),
                                      (-0.1, 0.36, 1.05), (0.45, 0.25, 0.75))):
        lot.put(M["pustule"], ellipsoide((sx + x0, sy, cz + sz * 0.9), 0.06, 0.06, 0.05, 8, 4))
    for sx in (-0.3, 0.25):
        ring = []
        for q in range(15):
            ang = math.radians(-20 + 220 * q / 14.0)
            rw, rh = 0.62, 0.55
            ring.append((sx + x0, rw * math.cos(ang) * 1.05, cz - 0.05 + 0.75 * math.sin(ang) * (1.0 if math.sin(ang) > 0 else 0.7)))
        lot.put(M["tendon"], G.tube(ring, 0.035, 6, cap0=True, cap1=True))
        ring2 = [(p[0], -p[1], p[2]) for p in ring]
        lot.put(M["tendon"], G.tube(ring2, 0.035, 6))
    # crochets d'os qui tiennent la charge
    for s in (-1, 1):
        for sx in (-0.5, 0.0, 0.45):
            lot.put(M["os"], pointe((sx + x0, s * 0.42, cz + 0.1), G.norm((0.0, s * 0.6, 1.0)), 0.35, 0.05, 5))
    ph = {"AG": 0.0, "PD": 0.0, "AD": 0.5, "PG": 0.5}
    for k, (hx, fx) in (("AG", (0.55, 0.62)), ("AD", (0.55, 0.62)), ("PG", (-0.55, -0.62)), ("PD", (-0.55, -0.62))):
        s = 1 if k[1] == "G" else -1
        patte(lot, M, (hx + x0, s * 0.5, 0.9 + bob), (fx + (x0 if a is None else 0.0), s * 0.72, 0.0), u + ph[k], 0.5, 0.55, 0.15,
              G.norm((0.6 if k[0] == "A" else -0.6, s * 0.3, 0.0)), levee=0.16, griffe=0.2, appui=0.6)
    nuque = pts[-1]
    b = (nuque[0] + 0.2, 0.0, nuque[2] - 0.12)
    cou(lot, M, nuque, b, 0.3, 0.2)
    tete(lot, M, b, 0.72, -0.35 + 0.1 * ouv, 0.12 + 0.6 * ouv, (1.05, 1.2, 1.0), dents=2, yeux=3, gorge=0.6)


def hurleur(lot, M, u, a, bob, lunge, ouv, cri):
    """HURLEUR : avant dressé, cou levé, gueule grande ouverte (toujours), collerette d'épines et de membranes, chair rouge à vif."""
    x0 = lunge * 0.5
    ctrl = [(-0.9 + x0, 0.0, 0.62 + bob * 0.5), (-0.4 + x0, 0.0, 0.78 + bob), (0.15 + x0, 0.0, 1.0 + bob), (0.55 + x0, 0.0, 1.22 + bob),
            (0.78 + x0, 0.0, 1.42 + bob)]
    def ray(t):
        return 0.22 + 0.16 * math.sin(math.pi * min(1.0, t * 1.0)) ** 0.8, 0.2 + 0.16 * math.sin(math.pi * min(1.0, t)) ** 0.8
    pts, prof = torse(lot, M, ctrl, ray, (0.4, 0.88, 6), peau=((0.3, 1), (0.35, -1)))
    queue(lot, M, [(-0.85 + x0, 0.0, 0.62 + bob * 0.5), (-1.35 + x0, 0.0, 0.42), (-1.85 + x0, 0.0, 0.25)], 0.12, -0.15 * math.sin(G.TAU * u))
    ph = {"AG": 0.0, "PD": 0.0, "AD": 0.5, "PG": 0.5}
    for k, hx, hz, fx, l1, l2 in (("AG", 0.55, 1.15, 0.85, 0.62, 0.7), ("AD", 0.55, 1.15, 0.85, 0.62, 0.7),
                                  ("PG", -0.55, 0.72, -0.75, 0.45, 0.52), ("PD", -0.55, 0.72, -0.75, 0.45, 0.52)):
        s = 1 if k[1] == "G" else -1
        patte(lot, M, (hx + x0, s * 0.32, hz + bob), (fx + (x0 if a is None else 0.0), s * 0.62, 0.0), u + ph[k], l1, l2, 0.1,
              G.norm((0.5 if k[0] == "A" else -0.8, s * 0.4, 0.2)), levee=0.2, griffe=0.24)
    nuque = pts[-1]
    b = (nuque[0] + 0.25, 0.0, nuque[2] + 0.42 - 0.1 * cri)
    cou(lot, M, nuque, b, 0.22, 0.16)
    # collerette : membranes de peau sombre tendues entre des épines d'os, en éventail autour du cou ; s'évase pendant le cri
    c = G.lerp(nuque, b, 0.45)
    nep = 9
    ev = 1.0 + 0.35 * cri
    tips = []
    for q in range(nep):
        ang = -math.pi * 0.9 + 1.8 * math.pi * q / (nep - 1)
        d = G.norm((-0.55, math.cos(ang) * ev, (math.sin(ang) * 0.7 + 0.45) * ev))
        L = (0.5 + 0.18 * math.cos(ang * 0.5)) * ev
        root = G.add(c, (0.0, math.cos(ang) * 0.2, math.sin(ang) * 0.17 + 0.05))
        lot.put(M["os"], pointe(root, d, L, 0.04, 5))
        tips.append((root, G.add(root, G.mul(d, L * 0.8))))
    for q in range(nep - 1):
        (r0, t0), (r1, t1) = tips[q], tips[q + 1]
        mid = G.mul(G.add(t0, t1), 0.5)
        mid = G.add(mid, G.mul(G.sub(G.mul(G.add(r0, r1), 0.5), mid), 0.25))   # membrane échancrée entre deux épines
        v = [r0, t0, mid, t1, r1]
        lot.put(M["peau_morte"], (v, [(0, 1, 2), (0, 2, 4), (4, 2, 3)], [(0.0, 0.0)] * 5))
        lot.put(M["peau_morte"], (v, [(2, 1, 0), (4, 2, 0), (3, 2, 4)], [(0.0, 0.0)] * 5))
    tete(lot, M, b, 0.85, 0.4 + 0.12 * cri, 0.95 + 0.35 * ouv, (1.05, 1.05, 1.0), dents=4, yeux=2, gorge=1.1)


def build_anime(S, lot, stage, u, attaque):
    """Pose d'un Écorché de la variante `stage` (1 à 3) : u = phase de course ; attaque = phase d'attaque (0 à 1) ou None."""
    st = int(stage) if stage else 1
    M = matieres(S, st)
    R.raz()
    K = TAILLE[st]
    lot.xf = lambda v: (v[0] * K, v[1] * K, v[2] * K)
    AMP_MODELE[0] = AMP / K
    if attaque is not None:
        a = attaque
        k = math.sin(math.pi * min(1.0, a * 1.4))        # élan : monte puis retombe sur la dernière image
        lunge, ouv, cri = 0.05 * k, k, k      # QA A8 : élan court (gigue du centre de masse <= 3 %) : la gueule et la tête font l'attaque
        bob, uu = 0.0, 0.0
    else:
        a = None
        lunge, ouv, cri = 0.0, 0.0, 0.0
        bob = 0.015 * math.sin(G.TAU * 2.0 * u)
        uu = u
    if st == 1:
        rodeur(lot, M, uu, a, bob, lunge, ouv)
    elif st == 2:
        porteur(lot, M, uu, a, bob, lunge, ouv)
    else:
        hurleur(lot, M, uu, a, bob, lunge, ouv, cri)
    return {"variante": stage, "pieces": lot.n, "u": u, "attaque": attaque}
