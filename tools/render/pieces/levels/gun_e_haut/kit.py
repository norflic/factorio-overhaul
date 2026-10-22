"""Kit de modélisation « industriel lourd » (lot V3-S, exploration de style, mitrailleuse).

S'exécute DANS Blender (importé par ind.py). N'utilise que l'API publique de tools/render/blender/fo_scene.py
(S) et de tools/render/fo_calib.py (C), plus bpy/bmesh pour des maillages GROUPÉS : toutes les pièces d'un même
matériau et d'un même style sont accumulées dans UN maillage (des milliers de rivets, boulons, lamelles et
cartouches sans le coût d'un objet Blender chacun). Rien du pipeline partagé n'est modifié.

Conventions (tools/render/README.md, CALIBRATION.md §2) : 1 unité = largeur d'une tuile ; +X est, +Y nord,
+Z haut ; origine = position de l'entité au sol ; une tuile de jeu vers le sud = 1,414 unité en Y (gy()).
La tête est modélisée canons vers +Y, dans SON repère : ses objets reçoivent la rotation de la pose comme
rotation d'objet (les textures en coordonnées « Object » tournent avec elle : aucune rouille qui glisse d'une
direction à l'autre sur les 64 directions du jeu).

Repris de V3 phase 1 (tools/render/pieces/levels/gun, branche worktree-wf_1f9884be-7b6-2) : tête et socle
rendus séparément, tête à plusieurs canons, zone sûre F46, ombres plein est (F47, soleil du pipeline).
"""
import math
import random

import bpy
import bmesh
from mathutils import Matrix, Vector

TAU = 2.0 * math.pi
SQ2 = math.sqrt(2.0)


def gy(t):
    """y de jeu (tuiles, vers le sud) -> Y Blender."""
    return -t * SQ2


def basis(axis):
    a = Vector(axis).normalized()
    ref = Vector((0.0, 0.0, 1.0)) if abs(a.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = a.cross(ref).normalized()
    w = a.cross(u).normalized()
    return a, u, w


AX = {"x": (1, 0, 0), "-x": (-1, 0, 0), "y": (0, 1, 0), "-y": (0, -1, 0), "z": (0, 0, 1), "-z": (0, 0, -1)}


def axv(axis):
    return Vector(AX[axis]) if isinstance(axis, str) else Vector(axis)


# ------------------------------------------------------------------------------------------------
# Matériaux (couleurs LINÉAIRES). Ancre : cheminée V0 validée (tôle brune rouillée, laiton, crasse forte).
# ------------------------------------------------------------------------------------------------
def _insert_stain(mat, amount, scale, seed):
    """Taches basse fréquence (P2 de la charte : coulures, plaques) : la couleur de base est multipliée par
    1 ± amount selon un bruit d'échelle `scale` (coordonnées Object)."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    inp = p.inputs["Base Color"]
    if not inp.links:
        return
    src = inp.links[0].from_socket
    tc = N.new("ShaderNodeTexCoord")
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 3.0
    nz.inputs["Roughness"].default_value = 0.55
    if "W" in nz.inputs:
        nz.noise_dimensions = "4D"
        nz.inputs["W"].default_value = seed + 3.1
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.3
    mr.inputs["From Max"].default_value = 0.7
    mr.inputs["To Min"].default_value = 1.0 - amount * 0.85
    mr.inputs["To Max"].default_value = 1.0 + amount * 0.45
    L.new(nz.outputs["Fac"], mr.inputs["Value"])
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(src, mul.inputs[0])
    L.new(mr.outputs["Result"], mul.inputs["Scale"])
    L.new(mul.outputs["Vector"], inp)


def _insert_streaks(mat, amount, scale, seed):
    """Coulures et crasse verticales : bruit étiré en Z (coordonnées Object), multiplie la couleur par
    1 - amount au plus. Donne la variance basse fréquence (P2) des tôles vanilla sans motif de camouflage."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    inp = p.inputs["Base Color"]
    if not inp.links:
        return
    src = inp.links[0].from_socket
    tc = N.new("ShaderNodeTexCoord")
    sc = N.new("ShaderNodeVectorMath")
    sc.operation = "MULTIPLY"
    sc.inputs[1].default_value = (scale, scale, scale * 0.18)
    L.new(tc.outputs["Object"], sc.inputs[0])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.0
    nz.inputs["Detail"].default_value = 4.0
    nz.inputs["Roughness"].default_value = 0.6
    if "W" in nz.inputs:
        nz.noise_dimensions = "4D"
        nz.inputs["W"].default_value = seed + 5.7
    L.new(sc.outputs["Vector"], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.45
    mr.inputs["From Max"].default_value = 0.7
    mr.inputs["To Min"].default_value = 1.0
    mr.inputs["To Max"].default_value = 1.0 - amount
    mr.clamp = True
    L.new(nz.outputs["Fac"], mr.inputs["Value"])
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(src, mul.inputs[0])
    L.new(mr.outputs["Result"], mul.inputs["Scale"])
    L.new(mul.outputs["Vector"], inp)


def _insert_edgewear(mat, amount, dist=0.014):
    """Arêtes usées plus claires (vocabulaire vanilla : « arêtes claires », charte §4.6) : occlusion ambiante
    calculée vers l'INTÉRIEUR de l'objet (nœud AO, inside, objet seul) ; près d'une arête convexe, les rayons
    ressortent vite : 1 - AO marque l'arête sur environ `dist` unités. La couleur y est multipliée par
    1 + amount. Les plaques font au moins 0,016 d'épaisseur : leur intérieur n'est pas marqué."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    inp = p.inputs["Base Color"]
    if not inp.links:
        return
    src = inp.links[0].from_socket
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.inside = True
    ao.only_local = True
    ao.samples = 16
    ao.inputs["Distance"].default_value = dist
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 1.0
    mr.inputs["From Max"].default_value = 0.55
    mr.inputs["To Min"].default_value = 1.0
    mr.inputs["To Max"].default_value = 1.0 + amount
    mr.clamp = True
    L.new(ao.outputs["AO"], mr.inputs["Value"])
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(src, mul.inputs[0])
    L.new(mr.outputs["Result"], mul.inputs["Scale"])
    L.new(mul.outputs["Vector"], inp)


def materials(S, epoch, tone=1.0):
    """Palette commune à TOUTES les époques (charte §6.4 : le corps reste du métal sombre, chaud et usé) ;
    seuls changent les matières d'accent de l'époque (≤ 15 % du corps, patinées, catalogue V3-E §A.3) et la
    couleur des foyers lumineux.

    Lot V3-E (époques 10 à 15), corrections des juges de V3-S faites EN PASSANT (catalogue §A.6) :
      - grain de surface plus doux (P1 et D3 trop hauts : 0,18 -> 0,11 sur les peintures), rouille moins piquetée ;
      - taches basses fréquences plus larges (P2 sous le plancher : 2e couche de taches à grande échelle) ;
      - reflets francs sur l'acier nu, le laiton et les rivets (C2 trop terne : rugosité plus basse).
    Clés d'époque (mêmes noms à toutes les époques, matières différentes) : jacket (jaquette des canons), ring
    (bagues et colliers), trim (plaques rapportées, ailerons, sertissures), pipe et pipe2 (liaisons), cable_a et
    cable_b, spec (matière spéciale : cellules, givre, nacre…), emit et emit2 (deux couleurs de foyer)."""
    M = {}
    k = [0]

    def metal(key, col, rough=0.4, met=0.75, grain=0.38, gscale=24.0, rust=None, ra=0.0, dirt=0.85, stain=0.5,
              sscale=7.0, dd=0.3, soot=None, wear=0.0, streak=0.0, mottle=0.0):
        k[0] += 1
        c = tuple(min(0.9, x * tone) for x in col)
        m = S.mat_metal("gune_e%02d_%s" % (epoch, key), c, rough=rough, metallic=met, grain=grain, grain_scale=gscale,
                        rust=rust, rust_amount=ra, rust_scale=6.0, dirt=dirt, seed=float(11 * k[0] + epoch),
                        soot=soot, dirt_distance=dd)
        if stain:
            _insert_stain(m, stain, sscale, float(11 * k[0] + epoch))
        if mottle:
            _insert_stain(m, mottle, 1.6, float(17 * k[0] + epoch + 0.5))
        if streak:
            _insert_streaks(m, streak, 14.0, float(13 * k[0] + epoch))
        if wear:
            _insert_edgewear(m, wear)
        M[key] = m
        return m

    rust = (0.24, 0.085, 0.03)
    G = 0.11   # grain des peintures (V3-S : 0,18)
    # corps : tôle brune rouillée (cheminée V0) pour la tête, tôle sombre et kaki usé pour le socle
    metal("armor", (0.15, 0.125, 0.095), rough=0.36, met=0.7, grain=0.3, rust=rust, ra=0.13, dd=0.35, wear=1.6,
          mottle=0.35)
    metal("armor2", (0.075, 0.068, 0.058), rough=0.38, met=0.75, grain=0.3, rust=(0.18, 0.07, 0.03), ra=0.11, dirt=0.7,
          wear=2.2, mottle=0.3)
    metal("khaki", (0.17, 0.14, 0.08), rough=0.48, met=0.4, grain=0.3, rust=rust, ra=0.13, wear=1.4, mottle=0.35)
    metal("seam", (0.01, 0.009, 0.008), rough=0.8, met=0.2, grain=0.2, dirt=0.4, stain=0.0)
    metal("steel", (0.2, 0.19, 0.175), rough=0.22, met=0.92, grain=0.2, gscale=40.0, rust=rust, ra=0.07, dirt=0.6,
          stain=0.25, wear=1.2)
    metal("gun", (0.13, 0.125, 0.118), rough=0.22, met=0.92, grain=0.2, gscale=60.0, dirt=0.5, stain=0.15, wear=1.5)
    metal("brass", (0.8, 0.56, 0.22), rough=0.2, met=0.95, grain=0.16, gscale=50.0, rust=(0.3, 0.12, 0.05),
          ra=0.14, dirt=0.5, stain=0.15, wear=0.5)
    metal("copper", (0.62, 0.26, 0.1), rough=0.26, met=0.95, grain=0.16, rust=(0.12, 0.2, 0.12), ra=0.08, dirt=0.55,
          stain=0.2, wear=0.6)
    metal("rivet", (0.56, 0.48, 0.36), rough=0.2, met=0.92, grain=0.1, dirt=0.3, stain=0.0)
    metal("hazy", (0.6, 0.38, 0.025), rough=0.5, met=0.1, grain=0.25, rust=rust, ra=0.25, dirt=0.85, stain=0.35,
          wear=0.6)
    metal("hazk", (0.025, 0.022, 0.02), rough=0.55, met=0.2, grain=0.25, dirt=0.4, stain=0.0, wear=3.0)
    metal("rubber", (0.03, 0.028, 0.026), rough=0.7, met=0.0, grain=0.12, dirt=0.3, stain=0.0)
    metal("redcable", (0.26, 0.035, 0.022), rough=0.55, met=0.0, grain=0.12, dirt=0.4, stain=0.0)
    metal("void", (0.008, 0.007, 0.006), rough=0.9, met=0.0, grain=0.1, dirt=0.0, stain=0.0)
    metal("soot", (0.05, 0.042, 0.038), rough=0.8, met=0.2, grain=0.25, dirt=0.5)
    metal("ochre", (0.33, 0.19, 0.045), rough=0.4, met=0.35, grain=G, gscale=30.0, rust=rust, ra=0.22,
          dirt=0.9, stain=0.95, sscale=5.0, dd=0.3, wear=2.6, streak=0.6, mottle=0.45)
    metal("redpaint", (0.27, 0.065, 0.025), rough=0.4, met=0.35, grain=G, gscale=30.0, rust=(0.1, 0.05, 0.025),
          ra=0.22, dirt=0.9, stain=0.95, sscale=5.0, wear=2.6, streak=0.55, mottle=0.45)
    metal("cream", (0.42, 0.35, 0.2), rough=0.38, met=0.2, grain=G, gscale=26.0, rust=(0.2, 0.09, 0.04),
          ra=0.22, dirt=0.95, stain=0.75, sscale=5.0, dd=0.35, wear=0.8, streak=0.65, mottle=0.4)
    metal("olive", (0.15, 0.125, 0.06), rough=0.38, met=0.45, grain=G, gscale=30.0, rust=rust, ra=0.36,
          dirt=0.9, stain=0.95, sscale=5.0, wear=3.0, streak=0.6, mottle=0.45)
    metal("steel_dk", (0.1, 0.094, 0.086), rough=0.3, met=0.9, grain=G, gscale=36.0, rust=rust, ra=0.36,
          dirt=0.8, stain=0.75, sscale=5.0, wear=2.8, streak=0.55, mottle=0.4)
    metal("steel_hi", (0.52, 0.5, 0.46), rough=0.15, met=0.95, grain=0.22, gscale=44.0, rust=rust, ra=0.08,
          dirt=0.75, stain=0.25, sscale=16.0, wear=0.6, streak=0.3)
    metal("grate", (0.11, 0.1, 0.09), rough=0.4, met=0.8, grain=0.22, gscale=40.0, rust=rust, ra=0.25, dirt=0.6,
          stain=0.5, wear=1.5)
    metal("dial", (0.4, 0.37, 0.3), rough=0.4, met=0.0, grain=0.15, dirt=0.4, stain=0.2)
    metal("matte", (0.022, 0.021, 0.022), rough=0.62, met=0.1, grain=0.12, dirt=0.4, stain=0.2, wear=2.0)
    # --- matières d'accent d'époque (catalogue §A.3) ; albédos de départ, à mesurer sur le rendu (F36, F38)
    ep = epoch
    if ep == 10:      # haute technologie : carénage gris clair patiné, noir mat, câbles rouges et bleus
        metal("jacket", (0.4, 0.4, 0.39), rough=0.42, met=0.3, grain=0.1, gscale=30.0, rust=rust, ra=0.08,
              dirt=0.9, stain=0.7, sscale=6.0, wear=1.2, streak=0.5, mottle=0.3)
        M["ring"] = M["matte"]
        M["trim"] = M["jacket"]
        metal("pipe", (0.11, 0.108, 0.104), rough=0.5, met=0.2, grain=0.1, dirt=0.6, stain=0.4, wear=1.0)
        M["pipe2"] = M["steel_hi"]
        M["cable_a"] = M["redcable"]
        metal("cable_b", (0.02, 0.06, 0.2), rough=0.5, met=0.0, grain=0.12, dirt=0.4, stain=0.0)
        metal("spec", (0.012, 0.03, 0.05), rough=0.15, met=0.3, grain=0.05, dirt=0.2, stain=0.0)       # écrans
        emit, emit2 = (0.227, 0.659, 1.0), (0.227, 0.659, 1.0)
    elif ep == 11:    # titane : titane patiné, alliage blanc patiné (ailerons, colliers)
        metal("jacket", (0.31, 0.315, 0.32), rough=0.3, met=0.88, grain=0.14, gscale=40.0, rust=rust, ra=0.06,
              dirt=0.8, stain=0.45, sscale=6.0, wear=1.0, streak=0.4)
        metal("ring", (0.42, 0.4, 0.36), rough=0.3, met=0.7, grain=0.14, gscale=30.0, rust=(0.2, 0.1, 0.05),
              ra=0.1, dirt=0.9, stain=0.6, sscale=5.0, wear=0.8, streak=0.5)
        M["trim"] = M["ring"]
        M["pipe"] = M["jacket"]
        M["pipe2"] = M["ring"]
        M["cable_a"], M["cable_b"] = M["redcable"], M["rubber"]
        M["spec"] = M["ring"]
        emit, emit2 = (0.749, 0.902, 1.0), (0.749, 0.902, 1.0)
    elif ep == 12:    # supraconducteurs : noir profond, chrome à reflets francs, givre (≤ 3 %)
        metal("jacket", (0.034, 0.035, 0.038), rough=0.3, met=0.6, grain=0.1, gscale=40.0, dirt=0.5, stain=0.3,
              wear=1.5)
        metal("ring", (0.8, 0.81, 0.83), rough=0.16, met=1.0, grain=0.06, gscale=60.0, dirt=0.5, stain=0.12,
              wear=0.3)
        metal("trim", (0.55, 0.6, 0.64), rough=0.85, met=0.0, grain=0.3, gscale=80.0, dirt=0.3, stain=0.3)  # givre
        metal("pipe", (0.38, 0.37, 0.34), rough=0.9, met=0.0, grain=0.35, gscale=50.0, rust=(0.2, 0.18, 0.15),
              ra=0.15, dirt=0.8, stain=0.6, sscale=5.0, streak=0.5)                                   # mousse givrée
        M["pipe2"] = M["ring"]
        metal("cable_a", (0.018, 0.018, 0.02), rough=0.55, met=0.0, grain=0.1, dirt=0.3, stain=0.0)
        M["cable_b"] = M["cable_a"]
        M["spec"] = M["trim"]
        emit, emit2 = (0.29, 0.94, 1.0), (0.29, 0.94, 1.0)
    elif ep == 13:    # fusion : céramique blanche patinée (buses, chambres, injecteurs), cuivre
        metal("jacket", (0.48, 0.46, 0.41), rough=0.55, met=0.0, grain=0.14, gscale=34.0, rust=(0.22, 0.12, 0.06),
              ra=0.12, dirt=0.95, stain=0.7, sscale=5.0, wear=0.6, streak=0.55, mottle=0.25)
        # cuivre des gaines et cerclages : plus rugueux et plus sombre (reflets saturés comptés comme foyers sinon)
        metal("copper13", (0.46, 0.2, 0.085), rough=0.42, met=0.9, grain=0.2, rust=(0.12, 0.2, 0.12), ra=0.12,
              dirt=0.7, stain=0.35, wear=0.8)
        M["copper"] = M["copper13"]
        M["ring"] = M["copper"]
        M["trim"] = M["jacket"]
        M["pipe"] = M["copper"]
        M["pipe2"] = M["jacket"]
        M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
        M["spec"] = M["jacket"]
        emit, emit2 = (1.0, 0.31, 0.847), (1.0, 0.604, 0.227)
    elif ep == 14:    # orbite : feuille d'or froissée, blanc cassé patiné, cellules bleu nuit (≤ 5 %)
        metal("jacket", (0.6, 0.4, 0.08), rough=0.3, met=1.0, grain=0.45, gscale=22.0, rust=(0.25, 0.14, 0.04),
              ra=0.12, dirt=0.75, stain=0.5, sscale=7.0, wear=0.4)
        metal("ring", (0.44, 0.42, 0.37), rough=0.5, met=0.05, grain=0.14, gscale=30.0, rust=(0.2, 0.1, 0.05),
              ra=0.12, dirt=0.95, stain=0.7, sscale=5.0, wear=0.8, streak=0.6)
        M["trim"] = M["jacket"]
        M["pipe"] = M["jacket"]
        M["pipe2"] = M["ring"]
        M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
        metal("spec", (0.012, 0.02, 0.075), rough=0.14, met=0.6, grain=0.05, dirt=0.3, stain=0.0)      # cellules
        emit, emit2 = (1.0, 0.165, 0.165), (0.184, 0.42, 1.0)
    else:             # 15 légende : or blanc patiné, nacre
        metal("jacket", (0.6, 0.52, 0.32), rough=0.26, met=0.95, grain=0.14, gscale=40.0, rust=(0.25, 0.12, 0.05),
              ra=0.1, dirt=0.85, stain=0.35, sscale=6.0, wear=0.5)
        # bagues, flèches de couronne : or blanc PATINÉ, plus rugueux (aucun éclat blanc franc : « pas de bague blanche »)
        metal("ring", (0.46, 0.39, 0.22), rough=0.42, met=0.9, grain=0.18, gscale=36.0, rust=(0.25, 0.12, 0.05),
              ra=0.14, dirt=0.9, stain=0.5, sscale=6.0, wear=0.6)
        metal("trim", (0.5, 0.47, 0.42), rough=0.3, met=0.15, grain=0.12, gscale=30.0, dirt=0.9, stain=0.5,
              sscale=5.0, wear=0.6, streak=0.4)                                                        # nacre
        M["pipe"] = M["trim"]
        M["pipe2"] = M["jacket"]
        M["cable_a"], M["cable_b"] = M["rubber"], M["redcable"]
        M["spec"] = M["trim"]
        emit, emit2 = (1.0, 0.949, 0.753), (1.0, 0.949, 0.753)
    M["accent"] = M["trim"]
    # éléments lumineux : couleur d'époque (charte §6.4) ; surface éteinte dans la couche principale (V0b)
    M["emit"] = S.mat_emissive("gune_e%02d_emit" % epoch, emit, strength=1.0, base=(0.01, 0.01, 0.012),
                               main_scale=0.0, crust=(18.0, 0.25, 1.0 + epoch))
    M["emit_soft"] = S.mat_emissive("gune_e%02d_emit_s" % epoch, emit, strength=0.7, base=(0.01, 0.01, 0.012),
                                    main_scale=0.0, crust=(12.0, 0.35, 2.0 + epoch))
    M["emit2"] = S.mat_emissive("gune_e%02d_emit2" % epoch, emit2, strength=1.0, base=(0.01, 0.01, 0.012),
                                main_scale=0.0, crust=(14.0, 0.25, 3.0 + epoch))
    # voyants ambre (vocabulaire vanilla : lampes de travail), admis à toutes les époques
    M["amber"] = S.mat_emissive("gune_e%02d_amber" % epoch, (1.0, 0.45, 0.06), strength=1.0,
                                base=(0.01, 0.006, 0.003), main_scale=0.0)
    for key in ("emit", "emit_soft", "emit2", "amber"):
        p = M[key].node_tree.nodes["Principled BSDF"]
        p.inputs["Roughness"].default_value = 1.0
        if "Specular IOR Level" in p.inputs:
            p.inputs["Specular IOR Level"].default_value = 0.0
    M["_emit_rgb"] = emit
    M["_emit2_rgb"] = emit2
    return M


# ------------------------------------------------------------------------------------------------
# Accumulateur de géométrie
# ------------------------------------------------------------------------------------------------
RIVET_K = 1.8  # espacement des rivets des plaques (reprise 22/10 : D3 au-dessus de 45 sinon)

STYLES = {
    "hard": {"bevel": 0.016, "smooth": 30.0},
    "soft": {"bevel": 0.024, "smooth": 35.0},
    "smooth": {"bevel": 0.0, "smooth": 50.0},
    "flat": {"bevel": 0.0, "smooth": None},
}


class Geo:
    def __init__(self, S, C, M, tag, rotz=0.0, seed=1):
        self.S, self.C, self.M = S, C, M
        self.tag = tag
        self.rotz = rotz
        self.data = {}
        self.stack = [Matrix.Identity(4)]
        self.rng = random.Random(seed)
        self.halos = []
        self.count = {}

    # --- repères ----------------------------------------------------------------------------------
    def push(self, loc=(0, 0, 0), rz=0.0, rx=0.0, ry=0.0):
        m = (self.stack[-1] @ Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rz, 4, "Z")
             @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X"))
        self.stack.append(m)

    def pop(self):
        self.stack.pop()

    def push_frame(self, p, nrm, xdir=None):
        """Repère local d'origine p dont l'axe z suit la normale nrm (pièces posées sur une surface courbe)."""
        a = Vector(nrm).normalized()
        if xdir is None:
            _, x, _ = basis(a)
        else:
            x = Vector(xdir)
            x = (x - a * x.dot(a))
            if x.length < 1e-6:
                _, x, _ = basis(a)
            x.normalize()
        y = a.cross(x).normalized()
        m = Matrix(((x.x, y.x, a.x, p[0]), (x.y, y.y, a.y, p[1]), (x.z, y.z, a.z, p[2]), (0, 0, 0, 1)))
        self.stack.append(self.stack[-1] @ m)

    def W(self, p):
        """Point local -> repère de la pièce (avant la rotation de pose)."""
        return self.stack[-1] @ Vector(p)

    def _add(self, mat, style, verts, faces, what="part"):
        m = self.stack[-1]
        V, F = self.data.setdefault((mat, style), ([], []))
        o = len(V)
        V.extend(tuple(m @ Vector(v)) for v in verts)
        F.extend(tuple(i + o for i in f) for f in faces)
        self.count[what] = self.count.get(what, 0) + 1

    # --- primitives -------------------------------------------------------------------------------
    def box(self, c, size, mat, style="hard", R=None, what="box"):
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
        vs = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
              (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        if R is not None:
            vs = [tuple(R @ Vector(v)) for v in vs]
        vs = [(v[0] + c[0], v[1] + c[1], v[2] + c[2]) for v in vs]
        fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self._add(mat, style, vs, fs, what)

    def hexa(self, pts8, mat, style="hard", what="hexa"):
        """Hexaèdre quelconque : 4 points du bas puis 4 du haut (même ordre)."""
        fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self._add(mat, style, [tuple(p) for p in pts8], fs, what)

    def cyl(self, c, axis, r, h, mat, n=16, r2=None, caps=True, style="smooth", phase=0.0, what="cyl"):
        a, u, w = basis(axv(axis))
        c = Vector(c)
        r2 = r if r2 is None else r2
        vs, fs = [], []
        for t, rr in ((-h / 2.0, r), (h / 2.0, r2)):
            for i in range(n):
                ang = phase + TAU * i / n
                vs.append(tuple(c + a * t + (u * math.cos(ang) + w * math.sin(ang)) * rr))
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + j, n + i))
        if caps:
            fs.append(tuple(range(n))[::-1])
            fs.append(tuple(range(n, 2 * n)))
        self._add(mat, style, vs, fs, what)

    def tube_shell(self, c, axis, r_out, r_in, h, mat, n=24, style="smooth", what="tube"):
        """Tube épais (anneau extrudé) : bagues, colliers, couronnes."""
        a, u, w = basis(axv(axis))
        c = Vector(c)
        vs, fs = [], []
        for t in (-h / 2.0, h / 2.0):
            for rr in (r_out, r_in):
                for i in range(n):
                    ang = TAU * i / n
                    vs.append(tuple(c + a * t + (u * math.cos(ang) + w * math.sin(ang)) * rr))
        # indices : bas-ext 0..n-1, bas-int n..2n-1, haut-ext 2n.., haut-int 3n..
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, 2 * n + j, 2 * n + i))              # paroi extérieure
            fs.append((n + j, n + i, 3 * n + i, 3 * n + j))      # paroi intérieure
            fs.append((2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i))  # dessus
            fs.append((j, i, n + i, n + j))                      # dessous
        self._add(mat, style, vs, fs, what)

    def torus(self, c, axis, R, r, mat, n=28, m=8, style="smooth", what="torus"):
        a, u, w = basis(axv(axis))
        c = Vector(c)
        vs, fs = [], []
        for i in range(n):
            th = TAU * i / n
            d = u * math.cos(th) + w * math.sin(th)
            for j in range(m):
                ph = TAU * j / m
                vs.append(tuple(c + d * (R + r * math.cos(ph)) + a * (r * math.sin(ph))))
        for i in range(n):
            for j in range(m):
                i2, j2 = (i + 1) % n, (j + 1) % m
                fs.append((i * m + j, i2 * m + j, i2 * m + j2, i * m + j2))
        self._add(mat, style, vs, fs, what)

    def sphere(self, c, r, mat, n=24, m=12, scale=(1.0, 1.0, 1.0), style="smooth", what="sphere"):
        """Sphère (ou ellipsoïde) UV fermée."""
        c = Vector(c)
        vs, fs = [], []
        for i in range(1, m):
            ph = -math.pi / 2 + math.pi * i / m
            for j in range(n):
                th = TAU * j / n
                vs.append((c.x + r * scale[0] * math.cos(ph) * math.cos(th), c.y + r * scale[1] * math.cos(ph) * math.sin(th),
                           c.z + r * scale[2] * math.sin(ph)))
        vs.append((c.x, c.y, c.z - r * scale[2]))
        vs.append((c.x, c.y, c.z + r * scale[2]))
        bot, top = len(vs) - 2, len(vs) - 1
        for i in range(m - 2):
            for j in range(n):
                j2 = (j + 1) % n
                fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((bot, j2, j))
            fs.append(((m - 2) * n + j, (m - 2) * n + j2, top))
        self._add(mat, style, vs, fs, what)

    def crumple(self, c, axis, r, h, mat, n=18, k=6, amp=0.012, what="feuille"):
        """Manchon froissé (feuille d'or, couverture thermique) : cylindre à facettes dont les sommets sont
        décalés au hasard ; ombrage plat (style « flat ») pour que chaque facette accroche la lumière."""
        a, u, w = basis(axv(axis))
        c = Vector(c)
        vs, fs = [], []
        for i in range(k + 1):
            t = -h / 2.0 + h * i / k
            for j in range(n):
                ang = TAU * (j + 0.5 * (i % 2)) / n
                rr = r + amp * (self.rng.random() * 2 - 1) * (0.4 if i in (0, k) else 1.0)
                vs.append(tuple(c + a * (t + amp * 0.6 * (self.rng.random() * 2 - 1) * (0 if i in (0, k) else 1))
                                + (u * math.cos(ang) + w * math.sin(ang)) * rr))
        for i in range(k):
            for j in range(n):
                j2 = (j + 1) % n
                fs.append((i * n + j, i * n + j2, (i + 1) * n + j2))
                fs.append((i * n + j, (i + 1) * n + j2, (i + 1) * n + j))
        fs.append(tuple(range(n))[::-1])
        fs.append(tuple(range(k * n, (k + 1) * n)))
        self._add(mat, "flat", vs, fs, what)

    def dome(self, p, nrm, r, mat, n=6, h=None, style="smooth", what="rivet"):
        """Rivet / tête de boulon bombée, posée sur une surface de normale nrm."""
        a, u, w = basis(nrm)
        p = Vector(p)
        h = r * 0.75 if h is None else h
        vs = []
        for i in range(n):
            ang = TAU * i / n
            vs.append(tuple(p - a * (r * 0.4) + (u * math.cos(ang) + w * math.sin(ang)) * r))
        for i in range(n):
            ang = TAU * (i + 0.5) / n
            vs.append(tuple(p + a * (h * 0.55) + (u * math.cos(ang) + w * math.sin(ang)) * (r * 0.72)))
        vs.append(tuple(p + a * h))
        fs = [tuple(range(n))[::-1]]
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + i))
            fs.append((j, n + j, n + i))
            fs.append((n + i, n + j, 2 * n))
        self._add(mat, style, vs, fs, what)

    def bolt(self, p, nrm, r, mat, what="bolt"):
        """Boulon à tête hexagonale + rondelle."""
        a, _, _ = basis(nrm)
        p = Vector(p)
        self.cyl(p + a * 0.004, nrm, r * 1.35, 0.012, mat, n=10, style="flat", what="washer")
        self.cyl(p + a * (0.012 + r * 0.45), nrm, r, r * 0.9, mat, n=6, style="hard", what=what)

    def slab(self, q, nrm, t, mat, style="hard", what="plate"):
        """Plaque d'épaisseur t posée sur le quadrilatère q (4 points coplanaires), vers nrm."""
        n = Vector(nrm).normalized() * t
        q = [Vector(p) for p in q]
        self.hexa(q + [p + n for p in q], mat, style, what)

    # --- chemins ----------------------------------------------------------------------------------
    @staticmethod
    def spline(ctrl, k=8):
        """Catmull-Rom passant par les points de contrôle."""
        P = [Vector(p) for p in ctrl]
        if len(P) < 3:
            out = []
            for i in range(k + 1):
                out.append(P[0].lerp(P[-1], i / k))
            return out
        P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
        out = []
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            for j in range(k):
                t = j / k
                t2, t3 = t * t, t * t * t
                out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                                  + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
        out.append(P[-2])
        return out

    @staticmethod
    def resample(pts, step):
        P = [Vector(p) for p in pts]
        out = [P[0]]
        acc = 0.0
        for i in range(1, len(P)):
            a, b = P[i - 1], P[i]
            seg = (b - a).length
            if seg < 1e-9:
                continue
            d = step - acc
            while d <= seg:
                out.append(a.lerp(b, d / seg))
                d += step
            acc = seg - (d - step)
        if (out[-1] - P[-1]).length > step * 0.3:
            out.append(P[-1])
        return out

    def frames(self, P):
        T = []
        for i in range(len(P)):
            a = P[max(0, i - 1)]
            b = P[min(len(P) - 1, i + 1)]
            T.append((b - a).normalized())
        _, u, _ = basis(T[0])
        U = [u]
        for i in range(1, len(P)):
            q = T[i - 1].rotation_difference(T[i])
            u = (q @ U[-1]).normalized()
            U.append(u)
        return T, U

    def tube(self, pts, r, mat, n=10, style="smooth", radii=None, caps=True, what="tube"):
        P = [Vector(p) for p in pts]
        T, U = self.frames(P)
        vs, fs = [], []
        for i, p in enumerate(P):
            rr = radii[i] if radii else r
            w = T[i].cross(U[i]).normalized()
            for j in range(n):
                ang = TAU * j / n
                vs.append(tuple(p + (U[i] * math.cos(ang) + w * math.sin(ang)) * rr))
        for i in range(len(P) - 1):
            for j in range(n):
                j2 = (j + 1) % n
                fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
        if caps:
            fs.append(tuple(range(n))[::-1])
            last = (len(P) - 1) * n
            fs.append(tuple(range(last, last + n)))
        self._add(mat, style, vs, fs, what)
        return P, T

    def hose(self, ctrl, r, mat, step=0.03, n=10, what="hose"):
        """Gaine annelée (cuivre, caoutchouc) : rayon alterné tous les `step`."""
        P = self.resample(self.spline(ctrl, 10), step / 2.0)
        radii = [r if i % 2 == 0 else r * 0.8 for i in range(len(P))]
        self.tube(P, r, mat, n=n, radii=radii, what=what)
        return P

    def cable(self, p0, p1, sag, r, mat, n=8, what="cable"):
        p0, p1 = Vector(p0), Vector(p1)
        pts = []
        for i in range(13):
            t = i / 12.0
            p = p0.lerp(p1, t)
            p.z -= sag * 4 * t * (1 - t)
            pts.append(p)
        self.tube(pts, r, mat, n=n, what=what)

    def pipe(self, ctrl, r, mat, fl_mat=None, bolt_mat=None, flanges=True, what="pipe"):
        """Tuyau à coudes arrondis, brides boulonnées aux extrémités et au milieu."""
        P = self.spline(ctrl, 8)
        P, T = self.tube(P, r, mat, n=14, what=what)
        if flanges:
            fl = fl_mat or mat
            idx = [0, len(P) // 2, len(P) - 1]
            for i in idx:
                self.cyl(P[i], T[i], r * 1.45, r * 0.55, fl, n=16, style="hard", what="flange")
                if bolt_mat is not None:
                    a, u, w = basis(T[i])
                    for k in range(6):
                        ang = TAU * k / 6
                        q = P[i] + (u * math.cos(ang) + w * math.sin(ang)) * r * 1.22 + a * r * 0.3
                        self.dome(q, a, 0.016, bolt_mat, n=6)

    # --- motifs de surface ------------------------------------------------------------------------
    def panels(self, q, nu, nv, mat, t=0.03, gap=0.02, rivet_mat=None, rivet_r=0.02, rivet_step=0.16,
               rivet_inset=0.035, jitter=0.35, mats=None, what="panel"):
        """Habille un quadrilatère q = (p00, p10, p11, p01) (sens direct vu de l'extérieur) de nu × nv plaques
        rivetées séparées par des joints sombres. mats : liste de matériaux tirés au sort (plaques dépareillées)."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        gu, gv = gap / max(lu, 1e-6) / 2.0, gap / max(lv, 1e-6) / 2.0
        for i in range(nu):
            for j in range(nv):
                s0, s1 = i / nu + gu, (i + 1) / nu - gu
                t0, t1 = j / nv + gv, (j + 1) / nv - gv
                th = t * (1.0 + jitter * (self.rng.random() - 0.5) * 2)
                m = mats[self.rng.randrange(len(mats))] if mats else mat
                quad = [P(s0, t0), P(s1, t0), P(s1, t1), P(s0, t1)]
                self.slab(quad, nrm, th, m, "hard", what)
                if rivet_mat is not None:
                    iu, iv = rivet_inset / max(lu, 1e-6), rivet_inset / max(lv, 1e-6)
                    pw = (s1 - s0) * lu
                    ph = (t1 - t0) * lv
                    nu_r = max(2, int(pw / (rivet_step * RIVET_K)) + 1)
                    nv_r = max(2, int(ph / (rivet_step * RIVET_K)) + 1)
                    pts = set()
                    for kk in range(nu_r):
                        s = s0 + iu + (s1 - s0 - 2 * iu) * kk / (nu_r - 1)
                        pts.add((round(s, 5), round(t0 + iv, 5)))
                        pts.add((round(s, 5), round(t1 - iv, 5)))
                    for kk in range(nv_r):
                        tt = t0 + iv + (t1 - t0 - 2 * iv) * kk / (nv_r - 1)
                        pts.add((round(s0 + iu, 5), round(tt, 5)))
                        pts.add((round(s1 - iu, 5), round(tt, 5)))
                    for s, tt in sorted(pts):
                        self.dome(P(s, tt) + nrm * th, nrm, rivet_r, rivet_mat)

    def hazard(self, q, n, t=0.02, skew=0.5):
        """Bande de danger jaune et noire (rayures obliques) sur le quadrilatère q."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        sk = skew / n
        for i in range(-1, n + 1):
            s0, s1 = i / n, (i + 1) / n
            a0, a1 = max(0.0, min(1.0, s0)), max(0.0, min(1.0, s1))
            b0, b1 = max(0.0, min(1.0, s0 + sk)), max(0.0, min(1.0, s1 + sk))
            if a1 - a0 < 1e-4 and b1 - b0 < 1e-4:
                continue
            m = self.M["hazy"] if i % 2 == 0 else self.M["hazk"]
            self.slab([P(a0, 0), P(a1, 0), P(b1, 1), P(b0, 1)], nrm, t, m, "flat", "hazard")

    def grille(self, q, n, depth=0.03, slat_mat=None, frame=0.03):
        """Grille d'aération : cadre, fond noir, lamelles ; q dans le plan de la face (vers l'extérieur)."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
        sm = slat_mat or self.M["steel"]

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        self.slab(q, nrm, 0.006, self.M["void"], "flat", "grille_fond")
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        fu, fv = frame / lu, frame / lv
        for quad in ([P(0, 0), P(1, 0), P(1, fv), P(0, fv)], [P(0, 1 - fv), P(1, 1 - fv), P(1, 1), P(0, 1)],
                     [P(0, fv), P(fu, fv), P(fu, 1 - fv), P(0, 1 - fv)], [P(1 - fu, fv), P(1, fv), P(1, 1 - fv), P(1 - fu, 1 - fv)]):
            self.slab(quad, nrm, depth, sm, "hard", "grille_cadre")
        for i in range(n):
            t0 = fv + (1 - 2 * fv) * (i + 0.2) / n
            t1 = fv + (1 - 2 * fv) * (i + 0.62) / n
            self.slab([P(fu, t0), P(1 - fu, t0), P(1 - fu, t1), P(fu, t1)], nrm, depth * 0.7, sm, "hard", "lamelle")

    def perforated(self, q, nu, nv, mat, hole_r=0.018, t=0.012):
        """Tôle perforée : plaque + trous (disques noirs affleurants)."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        self.slab(q, nrm, t, mat, "hard", "tole_perforee")
        for i in range(nu):
            for j in range(nv):
                s = (i + 0.5) / nu
                tt = (j + 0.5) / nv + (0.5 / nv if i % 2 else 0.0) * 0.5
                if tt > 1 - 0.3 / nv:
                    continue
                self.cyl(P(s, tt) + nrm * (t + 0.001), nrm, hole_r, 0.004, self.M["void"], n=6, style="flat", what="trou")

    # --- source de halo (passe light du socle) ----------------------------------------------------
    def halo(self, loc, color, power):
        o = self.S.halo_light(tuple(self.W(loc)), color, power, radius=0.08, name="%s_halo_%d" % (self.tag, len(self.halos)))
        self.halos.append(o)
        return o

    # --- création des objets ----------------------------------------------------------------------
    def flush(self):
        coll = self.S.piece_collection()
        objs = []
        for idx, ((mat, style), (V, F)) in enumerate(sorted(self.data.items(), key=lambda kv: (kv[0][0].name, kv[0][1]))):
            if not F:
                continue
            me = bpy.data.meshes.new("%s_%s_%s" % (self.tag, mat.name, style))
            me.from_pydata(V, [], F)
            me.validate()
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(me)
            bm.free()
            me.update()
            o = bpy.data.objects.new(me.name, me)
            coll.objects.link(o)
            o.data.materials.append(mat)
            st = STYLES[style]
            if st["smooth"] is not None:
                self.S.smooth(o, st["smooth"])
            if st["bevel"]:
                self.S.bevel(o, st["bevel"])
            o.rotation_euler = (0.0, 0.0, self.rotz)
            objs.append(o)
        self.data = {}
        bpy.context.view_layer.update()
        return objs
