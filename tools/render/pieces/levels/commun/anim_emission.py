"""ANIMATION DES SURFACES ÉMISSIVES (kit commun, lot A4, 24/10/2026) : socle émissif animé, passes lueur et halo
seulement. Python pur à l'import (table, formule) ; installer() ne s'appelle que dans Blender. Partagé par toutes les
familles (un même âge anime ses foyers de la même façon, quelle que soit la famille).

Principe : chaque matière émissive (fo_scene.mat_emissive, « fo_kind » = « emissive ») voit sa force d'émission
multipliée par un FACTEUR m(x, y, t) >= 0, où (x, y) est la position au SOL en tuiles (x vers l'est, y vers le sud ;
origine = centre de l'entité) et t la phase du cycle (0 <= t < 1, une image sur N : t = k / N). Les sources ponctuelles
du halo (fo_scene.HALO_LIGHTS) reçoivent le même facteur, pris à leur position. MOYENNE de m sur un cycle = 1
EXACTEMENT pour chaque motif ci-dessous (sinus d'un nombre entier de tours) : la moyenne des images animées est l'image
fixe validée (contrôlé par anime_socle.py, à l'erreur d'échantillonnage près).

Motifs (phase p, m = 1 + A·sin(2π·p)) :
  souffle  p = c·t                               (tout le foyer respire ensemble, c tours par cycle)
  tourne   p = lobes·θ/2π − c·t                  (θ = angle autour du centre : la lumière tourne, sens horaire)
  onde     p = k·r − c·t                         (r = distance au centre, k ondes par tuile : la lumière s'éloigne)
  houle    p = k·(x·cos φ + y·sin φ) − c·t       (onde plane dans la direction φ)
La forme et l'amplitude sont choisies par âge d'après sa lumière (ages.PALETTE[e]["lumiere"]) ; PROPOSITION de l'agent,
SANS verdict du Directeur Créatif : à juger sur la planche animée et en jeu.
Les 11 âges 5 à 15 (plan de la suite, étape 5 : « socle émissif animé : 11 âges × 16 images ») ; les âges 2 à 4
(braise, ambre, torchère) gardent leur socle fixe.
"""
import math

IMAGES = 16          # images par cycle (plan : 16)
CYCLE_TICKS = 96     # durée du cycle en jeu (1,6 s) : animation_speed = IMAGES / CYCLE_TICKS

ANIM = {
    5: dict(motif="onde", A=0.35, k=0.8, c=1, note="lave orange : la chaleur s'écoule du centre vers les bords"),
    6: dict(motif="tourne", A=0.45, lobes=3, c=1, note="arcs bleu électrique : le courant tourne (3 lobes)"),
    7: dict(motif="tourne", A=0.30, lobes=6, c=1, note="violet des cristaux : scintillement tournant (6 facettes)"),
    8: dict(motif="onde", A=0.30, k=-0.6, c=1, note="jaune toxique : bouillonnement qui revient vers le centre"),
    9: dict(motif="souffle", A=0.30, c=1, note="vert uranium : pulsation du cœur"),
    10: dict(motif="tourne", A=0.40, lobes=8, c=1, note="voyants bleus : chenillard (8)"),
    11: dict(motif="houle", A=0.25, k=0.5, phi=0.0, c=1, note="bleu-blanc : balayage d'ouest en est"),
    12: dict(motif="tourne", A=0.35, lobes=2, c=1, note="cyan supraconducteur : courant à deux lobes"),
    13: dict(motif="onde", A=0.40, k=1.2, c=2, note="annihilation : ondes rapides du centre vers les bords"),
    14: dict(motif="souffle", A=0.30, c=2, note="blanc d'étoile : scintillement (2 battements par cycle)"),
    15: dict(motif="onde", A=0.35, k=0.5, c=1, note="incandescence blanc-or : respiration lente vers l'extérieur"),
}


def phase(age, x, y, t):
    a = ANIM[age]
    m = a["motif"]
    if m == "souffle":
        return a["c"] * t
    if m == "tourne":
        th = math.atan2(y, x)                    # x vers l'est, y vers le sud : angle croissant = sens horaire à l'écran
        return a["lobes"] * th / (2 * math.pi) - a["c"] * t
    if m == "onde":
        return a["k"] * math.hypot(x, y) - a["c"] * t
    if m == "houle":
        return a["k"] * (x * math.cos(a["phi"]) + y * math.sin(a["phi"])) - a["c"] * t
    raise ValueError("motif inconnu : %s" % m)


def facteur(age, x, y, t):
    """Facteur d'émission de l'âge au point (x, y) du sol (tuiles) à la phase t ; 1 si l'âge n'est pas animé."""
    if age not in ANIM:
        return 1.0
    return 1.0 + ANIM[age]["A"] * math.sin(2 * math.pi * phase(age, x, y, t))


def installer(bpy, age, cos_t):
    """Dans Blender, après la construction de la pièce : insère m(x, y, t) dans la force d'émission de CHAQUE matière
    émissive (nœud « fo_emit_strength » gardé : fo_scene._set_emit_strength y écrit toujours la force de base, les
    copies des passes lueur et halo héritent du montage). Position au sol depuis la position MONDE du point rendu
    (x = X ; y = −Y·cos θ, comme fo_calib.tile_to_blender). Rend la fonction pose_t(t) qui écrit t dans toutes les
    matières (copies comprises) ; nombre de matières montées."""
    n = 0
    for mat in list(bpy.data.materials):
        if mat.get("fo_kind") != "emissive" or mat.get("fo_anim"):
            continue
        nt = mat.node_tree
        N, L = nt.nodes, nt.links
        p = N["Principled BSDF"]
        entree = p.inputs["Emission Strength"]
        k = N.get("fo_emit_strength")
        if k is None:
            k = N.new("ShaderNodeMath")
            k.operation = "MULTIPLY"
            k.name = "fo_emit_strength"
            k.inputs[0].default_value = 1.0
            k.inputs[1].default_value = entree.default_value
        for lk in list(entree.links):
            L.remove(lk)
        geo = N.new("ShaderNodeNewGeometry")
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Position"], sep.inputs[0])
        y_sol = N.new("ShaderNodeMath")
        y_sol.operation = "MULTIPLY"
        y_sol.inputs[1].default_value = -cos_t
        L.new(sep.outputs["Y"], y_sol.inputs[0])
        x_out, y_out = sep.outputs["X"], y_sol.outputs[0]
        tval = N.new("ShaderNodeValue")
        tval.name = "fo_anim_t"
        tval.outputs[0].default_value = 0.0
        a = ANIM[age]

        def math_node(op, i0, i1=None, v1=None):
            m = N.new("ShaderNodeMath")
            m.operation = op
            if hasattr(i0, "is_linked") or hasattr(i0, "links"):
                L.new(i0, m.inputs[0])
            else:
                m.inputs[0].default_value = i0
            if i1 is not None:
                L.new(i1, m.inputs[1])
            elif v1 is not None:
                m.inputs[1].default_value = v1
            return m.outputs[0]

        ct = math_node("MULTIPLY", tval.outputs[0], v1=float(a["c"]))
        if a["motif"] == "souffle":
            ph = ct
        else:
            if a["motif"] == "tourne":
                th = math_node("ARCTAN2", y_out, x_out)
                base = math_node("MULTIPLY", th, v1=a["lobes"] / (2 * math.pi))
            elif a["motif"] == "onde":
                x2 = math_node("MULTIPLY", x_out, x_out)
                y2 = math_node("MULTIPLY", y_out, y_out)
                r = math_node("SQRT", math_node("ADD", x2, y2))
                base = math_node("MULTIPLY", r, v1=float(a["k"]))
            else:
                ux = math_node("MULTIPLY", x_out, v1=math.cos(a["phi"]))
                uy = math_node("MULTIPLY", y_out, v1=math.sin(a["phi"]))
                base = math_node("MULTIPLY", math_node("ADD", ux, uy), v1=float(a["k"]))
            ph = math_node("SUBTRACT", base, ct)
        s = math_node("SINE", math_node("MULTIPLY", ph, v1=2 * math.pi))
        m = math_node("ADD", math_node("MULTIPLY", s, v1=float(a["A"])), v1=1.0)
        fin = N.new("ShaderNodeMath")
        fin.operation = "MULTIPLY"
        fin.name = "fo_anim"
        L.new(k.outputs[0], fin.inputs[0])
        L.new(m, fin.inputs[1])
        L.new(fin.outputs[0], entree)
        mat["fo_anim"] = age
        n += 1

    def pose_t(t):
        for mat in bpy.data.materials:
            if mat.node_tree is None:
                continue
            v = mat.node_tree.nodes.get("fo_anim_t")
            if v is not None:
                v.outputs[0].default_value = float(t)
    return pose_t, n
