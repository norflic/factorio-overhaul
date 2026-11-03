"""MATIÈRES du kit vaisseau_o (lot CENTRE-OPUS) : une seule recette de surface usée, réglée par matière.

Couches (dans cet ordre) : tôles (texture « brique » sur les UV en unités : panneaux, joints sombres en creux, valeur
de chaque tôle ±var) ou couleur unie ; grain fin ; bandes (chevrons) ; coulures verticales de rouille sur les faces
verticales ; usure des arêtes saillantes (nœud Bevel contre la normale vraie : métal nu plus clair) ; crasse des creux
(occlusion) et des pieds (hauteur) ; arêtes adoucies à l'ombrage (normale du nœud Bevel, sans géométrie de biseau) ;
joints en relief (Bump). Les graines de bruit sont données par un DÉCALAGE des coordonnées (F136 : l'entrée « W »
d'un bruit 3D est inerte).
"""
import bpy

# PATINE (refonte QG, 31/10) : couche commune à toutes les surfaces d'un état, réglée par l'état avant matieres() ;
# ec : part d'écailles de peinture (bords francs, couleur ec_col) ; ta : marbrure en taches de 3 à 6 px (± ta) ;
# ra : rayures fines ; nu_k : éclaircit le métal nu des arêtes. Casse les aplats (mesures « damier », D3, D5) sans
# ajouter de géométrie ; sans : matières (morceaux de nom) qui n'écaillent pas. Vide : recette d'avant, inchangée.
PATINE = {}


def _n(N, kind, **inputs):
    node = N.new(kind)
    for k, v in inputs.items():
        node.inputs[k].default_value = v
    return node


def _rgb(c):
    return (c[0], c[1], c[2], 1.0)


def _scale(N, L, col_sock, k_sock):
    m = N.new("ShaderNodeVectorMath")
    m.operation = "SCALE"
    L.new(col_sock, m.inputs[0])
    if isinstance(k_sock, float):
        m.inputs["Scale"].default_value = k_sock
    else:
        L.new(k_sock, m.inputs["Scale"])
    return m.outputs["Vector"]


def _mix(N, L, fac, a, b):
    m = N.new("ShaderNodeMix")
    m.data_type = "RGBA"
    if isinstance(fac, float):
        m.inputs["Factor"].default_value = fac
    else:
        L.new(fac, m.inputs["Factor"])
    for idx, s in ((6, a), (7, b)):
        if isinstance(s, tuple):
            m.inputs[idx].default_value = _rgb(s)
        else:
            L.new(s, m.inputs[idx])
    return m.outputs[2]


def _mixf(N, L, fac, a, b):
    m = N.new("ShaderNodeMix")
    m.data_type = "FLOAT"
    L.new(fac, m.inputs["Factor"])
    for idx, s in ((2, a), (3, b)):
        if isinstance(s, float):
            m.inputs[idx].default_value = s
        else:
            L.new(s, m.inputs[idx])
    return m.outputs[0]


def _range(N, L, sock, f0, f1, t0=0.0, t1=1.0, smooth=False):
    r = N.new("ShaderNodeMapRange")
    if smooth:
        r.interpolation_type = "SMOOTHSTEP"
    r.clamp = True
    r.inputs["From Min"].default_value = f0
    r.inputs["From Max"].default_value = f1
    r.inputs["To Min"].default_value = t0
    r.inputs["To Max"].default_value = t1
    L.new(sock, r.inputs["Value"])
    return r.outputs["Result"]


def _math(N, L, op, a, b):
    m = N.new("ShaderNodeMath")
    m.operation = op
    for i, s in enumerate((a, b)):
        if isinstance(s, float):
            m.inputs[i].default_value = s
        else:
            L.new(s, m.inputs[i])
    return m.outputs[0]


def _bruit(N, L, vec, scale, detail=4.0, rough=0.55, decal=(0.0, 0.0, 0.0), etire=(1.0, 1.0, 1.0)):
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = decal
    mp.inputs["Scale"].default_value = etire
    L.new(vec, mp.inputs["Vector"])
    nz = _n(N, "ShaderNodeTexNoise", Scale=scale, Detail=detail, Roughness=rough)
    L.new(mp.outputs["Vector"], nz.inputs["Vector"])
    return nz.outputs["Fac"]


def surface(name, col, rough=0.55, met=0.5, tole=None, joint=0.5, joint_l=0.014, var=0.07, grain=0.07,
            bandes=None, coulures=0.0, rouille=(0.22, 0.1, 0.045), usure=0.5, nu=None, crasse=0.55,
            crasse_col=(0.035, 0.028, 0.02), pied=None, biseau=0.025, relief=0.5, graine=0.0):
    """Surface usée générique.

    tole    : (largeur, hauteur) des panneaux en unités, ou None (pas de joints) ;
    joint   : valeur relative des joints (0,5 = moitié plus sombre) ; joint_l : largeur du joint ;
    bandes  : (période, couleur 2, part) chevrons sur u + v ;
    coulures: 0 à 1 ; usure : 0 à 1 (arêtes) ; nu : couleur du métal nu (défaut : couleur éclaircie) ;
    crasse  : 0 à 1 (creux) ; pied : (z0, z1, part) crasse vers le bas ; biseau : rayon d'adoucissement des arêtes.
    """
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    geo = N.new("ShaderNodeNewGeometry")
    uv = tc.outputs["UV"]
    obj = tc.outputs["Object"]
    d = (graine * 3.1, graine * 7.7, graine * 1.3)
    joint_fac = None
    if tole:
        br = N.new("ShaderNodeTexBrick")
        br.offset = 0.5
        br.offset_frequency = 2
        br.inputs["Color1"].default_value = _rgb(tuple(c * (1 - var) for c in col))
        br.inputs["Color2"].default_value = _rgb(tuple(min(1.0, c * (1 + var)) for c in col))
        br.inputs["Mortar"].default_value = _rgb(tuple(c * joint for c in col))
        br.inputs["Scale"].default_value = 1.0
        br.inputs["Mortar Size"].default_value = joint_l
        br.inputs["Mortar Smooth"].default_value = 0.2
        br.inputs["Bias"].default_value = 0.0
        br.inputs["Brick Width"].default_value = tole[0]
        br.inputs["Row Height"].default_value = tole[1]
        mp = N.new("ShaderNodeMapping")
        mp.inputs["Location"].default_value = (graine * 0.37, graine * 0.21, 0.0)
        L.new(uv, mp.inputs["Vector"])
        L.new(mp.outputs["Vector"], br.inputs["Vector"])
        base = br.outputs["Color"]
        joint_fac = br.outputs["Fac"]
    else:
        rgb = N.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = _rgb(col)
        base = rgb.outputs[0]
    # grain fin (deux échelles)
    g = _range(N, L, _bruit(N, L, obj, 38.0, 5.0, 0.6, d), 0.3, 0.7, 1 - grain, 1 + grain)
    base = _scale(N, L, base, g)
    g2 = _range(N, L, _bruit(N, L, obj, 4.0, 3.0, 0.5, add3(d, 5.0)), 0.35, 0.65, 1 - grain, 1 + grain)
    base = _scale(N, L, base, g2)
    if PATINE:
        ta = PATINE.get("ta", 0.0)
        if ta > 0:
            t1 = _range(N, L, _bruit(N, L, obj, 11.0, 4.0, 0.6, add3(d, 31.0)), 0.36, 0.64, 1 - ta, 1 + ta)
            base = _scale(N, L, base, t1)
        # DA-CHIMIE ronde 2 : grandes taches (salissures, reprises de peinture) de 10 à 25 px HR ; la charte mesurait
        # une variance basse fréquence trop faible (P2 11 à 15 contre 16) et trop de surfaces planes (P4)
        tb = PATINE.get("tb", 0.0)
        if tb > 0:
            t3 = _range(N, L, _bruit(N, L, obj, 2.6, 3.0, 0.55, add3(d, 53.0)), 0.34, 0.66, 1 - tb, 1 + tb)
            base = _scale(N, L, base, t3)
        ra = PATINE.get("ra", 0.0)
        if ra > 0:
            r1 = _range(N, L, _bruit(N, L, obj, 7.0, 3.0, 0.5, add3(d, 37.0), (1.0, 14.0, 5.0)), 0.6, 0.66, 1.0, 1.0 - ra)
            base = _scale(N, L, base, r1)
        ec = PATINE.get("ec", 0.0)
        if ec > 0 and not any(x in name for x in PATINE.get("sans", ())):
            zone = _range(N, L, _bruit(N, L, obj, 2.6, 3.0, 0.5, add3(d, 41.0)), 0.38, 0.6)
            chip = _range(N, L, _bruit(N, L, obj, 15.0, 5.0, 0.68, add3(d, 43.0)), 0.63 - 0.13 * ec, 0.65 - 0.13 * ec)
            base = _mix(N, L, _math(N, L, "MULTIPLY", zone, chip), base, PATINE.get("ec_col", (0.03, 0.017, 0.008)))
    if bandes:
        per, col2, part = bandes
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(uv, sep.inputs["Vector"])
        s = _math(N, L, "ADD", sep.outputs["X"], sep.outputs["Y"])
        s = _math(N, L, "DIVIDE", s, float(per))
        fr = _math(N, L, "FRACT", s, 0.0)
        st = _math(N, L, "GREATER_THAN", fr, float(1.0 - part))
        base = _mix(N, L, st, base, tuple(c for c in col2))
    # coulures de rouille sur les faces verticales
    if coulures > 0:
        sepn = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Normal"], sepn.inputs["Vector"])
        vert = _range(N, L, _math(N, L, "ABSOLUTE", sepn.outputs["Z"], 0.0), 0.75, 0.3)
        st = _bruit(N, L, obj, 3.0, 6.0, 0.6, add3(d, 11.0), (9.0, 9.0, 0.45))
        k = _range(N, L, st, 0.62 - 0.12 * coulures, 0.72 - 0.12 * coulures, 0.0, 0.85, True)
        k = _math(N, L, "MULTIPLY", k, vert)
        base = _mix(N, L, k, base, rouille)
    # usure des arêtes saillantes
    bev = N.new("ShaderNodeBevel")
    bev.samples = 6
    bev.inputs["Radius"].default_value = biseau
    if usure > 0:
        bev2 = N.new("ShaderNodeBevel")
        bev2.samples = 6
        bev2.inputs["Radius"].default_value = 0.035
        dt = N.new("ShaderNodeVectorMath")
        dt.operation = "DOT_PRODUCT"
        L.new(bev2.outputs["Normal"], dt.inputs[0])
        L.new(geo.outputs["Normal"], dt.inputs[1])
        e = _range(N, L, dt.outputs["Value"], 0.985, 0.90, 0.0, 1.0)
        nz = _bruit(N, L, obj, 22.0, 4.0, 0.7, add3(d, 3.0))
        e = _math(N, L, "MULTIPLY", e, _range(N, L, nz, 0.62 - 0.3 * usure, 0.7 - 0.3 * usure))
        nuc = nu or tuple(min(1.0, c * 1.6 + 0.12) for c in col)
        if PATINE.get("nu_k"):
            nuc = tuple(min(1.0, c * PATINE["nu_k"]) for c in nuc)
        base = _mix(N, L, e, base, nuc)
        rough_s = _mixf(N, L, e, rough, max(0.25, rough - 0.2))
        L.new(rough_s, p.inputs["Roughness"])
    else:
        p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = met
    # crasse des creux et des pieds
    if crasse > 0:
        ao = N.new("ShaderNodeAmbientOcclusion")
        ao.samples = 8
        ao.inputs["Distance"].default_value = 0.22
        k = _range(N, L, ao.outputs["AO"], 1.0, 0.35, 0.0, crasse, True)
        base = _mix(N, L, k, base, crasse_col)
    if pied:
        z0, z1, part = pied
        sz = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Position"], sz.inputs["Vector"])
        k = _range(N, L, sz.outputs["Z"], z1, z0, 0.0, part, True)
        nz = _range(N, L, _bruit(N, L, obj, 6.0, 4.0, 0.6, add3(d, 17.0)), 0.3, 0.7, 0.6, 1.0)
        base = _mix(N, L, _math(N, L, "MULTIPLY", k, nz), base, crasse_col)
    L.new(base, p.inputs["Base Color"])
    # normale : arêtes adoucies + joints en relief
    nrm = bev.outputs["Normal"]
    if joint_fac is not None and relief > 0:
        bp = N.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = relief
        bp.inputs["Distance"].default_value = 0.01
        inv = _math(N, L, "SUBTRACT", 1.0, joint_fac)
        L.new(inv, bp.inputs["Height"])
        L.new(nrm, bp.inputs["Normal"])
        nrm = bp.outputs["Normal"]
    L.new(nrm, p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def add3(d, k):
    return (d[0] + k, d[1] + k * 0.7, d[2] + k * 0.3)


def verre(name, col=(0.02, 0.045, 0.05), reflet=(0.16, 0.24, 0.26)):
    """Verre sombre : plus clair en incidence rasante (reflet du ciel faible du rendu)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    p = N["Principled BSDF"]
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    c = _mix(N, L, lw.outputs["Facing"], col, reflet)
    L.new(c, p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.12
    p.inputs["Metallic"].default_value = 0.0
    bev = N.new("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.02
    L.new(bev.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def lumiere(S, name, col, force=6.0, main=0.35):
    """Surface lumineuse (couche lueur) : voyants, hublots, fentes de foyer."""
    return S.mat_emissive(name, col, strength=force, base=tuple(c * 0.08 for c in col), main_scale=main)
