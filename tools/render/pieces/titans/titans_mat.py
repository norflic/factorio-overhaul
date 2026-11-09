"""MATIÈRES DES TITANS (lot TITANS, 9/11) : l'identité visuelle commune au Juggernaut (allié) et au Kaiju (ennemi).

Directive du DC : « blindage angulaire sombre/iridescent, anneaux magnétiques flottants, conduits lumineux et cœurs à vortex
cyan/turquoise, pointes de cristal énergétique résonant ». Les images de concept n'ont pas été retrouvées : choix PROVISOIRES,
consignés dans fo-logs/2026-11-09_TITANS/JOURNAL.md, à trancher sur les planches.

Tout repose sur le kit des géants (tools/render/pieces/experimentaux/mat.py : tôles usées, grain, arêtes, crasse) ; on y ajoute une
IRIDESCENCE : une teinte qui tourne de l'indigo au turquoise puis au magenta selon l'angle de vue (Layer Weight « Facing » -> rampe de
couleurs), mêlée au blindage sombre, vernis (Coat) sur les plaques. Les émissifs (conduits, cœur, cristal) passent par S.mat_emissive :
couche lueur du pipeline, éteints à 30 % dans la couche principale (règle V0b : la lueur additive seule donne la couleur la nuit).

S'exécute DANS Blender (bpy). Importé par juggernaut.py et kaiju.py via batch_titans.py.
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
if XP not in sys.path:
    sys.path.insert(0, XP)
import mat as MT  # noqa: E402

# Palette provisoire (linéaire). Cyan/turquoise de l'identité ; cristal plus bleu ; cœur presque blanc-cyan.
CYAN = (0.10, 0.92, 1.00)
TURQUOISE = (0.12, 0.85, 0.80)
CRISTAL = (0.30, 0.62, 1.00)
COEUR = (0.55, 1.00, 1.00)
# Iridescence : indigo de face, turquoise à 45°, magenta en rasant (les trois teintes de l'identité « sombre/iridescent »).
IRIS = ((0.06, 0.05, 0.16), (0.05, 0.42, 0.46), (0.52, 0.10, 0.44))


def iridescence(m, part=0.55, blend=0.4):
    """Ajoute au matériau `m` (sorti de MT.surface) une teinte qui change avec l'angle de vue : mélange de la couleur de base
    avec une rampe indigo -> turquoise -> magenta pilotée par Layer Weight (Facing). `part` : poids maximal de la rampe."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    link = p.inputs["Base Color"].links[0]
    base = link.from_socket
    L.remove(link)
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = blend
    ramp = N.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = (IRIS[0][0], IRIS[0][1], IRIS[0][2], 1.0)
    cr.elements[1].position = 1.0
    cr.elements[1].color = (IRIS[2][0], IRIS[2][1], IRIS[2][2], 1.0)
    e = cr.elements.new(0.55)
    e.color = (IRIS[1][0], IRIS[1][1], IRIS[1][2], 1.0)
    L.new(lw.outputs["Facing"], ramp.inputs["Fac"])
    k = N.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = part
    L.new(lw.outputs["Facing"], k.inputs[0])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "ADD"
    L.new(k.outputs[0], mix.inputs["Factor"])
    L.new(base, mix.inputs[6])
    L.new(ramp.outputs["Color"], mix.inputs[7])
    L.new(mix.outputs[2], p.inputs["Base Color"])
    if "Coat Weight" in p.inputs:
        p.inputs["Coat Weight"].default_value = 0.45
        p.inputs["Coat Roughness"].default_value = 0.12
    return m


def matieres(S, prefix, gris=False):
    """Le jeu de matières d'un titan. `prefix` : « ju_ » ou « ka_ » (les groupes de lueur de batch_titans lisent les noms)."""
    def surf(name, col, **kw):
        if gris:
            return MT.surface(prefix + "g_" + name, (0.2, 0.2, 0.2), rough=0.6, met=0.1, usure=0.3, crasse=0.6, graine=kw.get("graine", 0))
        return MT.surface(prefix + name, col, **kw)
    MT.ECH[0] = 2.2
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.10, ra=0.16, ec=0.12, nu_k=1.3, ec_col=(0.02, 0.03, 0.05), sans=("cristal", "conduit", "coeur", "os"))
    M = {}
    # blindage principal : plaques angulaires sombres, joints nets, usure des arêtes en métal bleu-gris
    M["blind"] = surf("blind", (0.030, 0.034, 0.050), rough=0.30, met=0.80, tole=(1.6, 0.9), joint=0.35, joint_l=0.016, var=0.10,
                      coulures=0.0, usure=0.45, nu=(0.30, 0.36, 0.46), crasse=0.55, crasse_col=(0.004, 0.005, 0.008), relief=0.6, graine=11)
    M["blind2"] = surf("blind2", (0.045, 0.040, 0.070), rough=0.34, met=0.75, tole=(0.8, 0.5), joint=0.4, joint_l=0.02, var=0.14,
                       usure=0.5, nu=(0.34, 0.32, 0.5), crasse=0.6, crasse_col=(0.004, 0.004, 0.007), relief=0.5, graine=12)
    # structure (articulations, pistons, vérins) : acier gris-bleu brossé
    M["struct"] = surf("struct", (0.11, 0.12, 0.14), rough=0.45, met=0.7, usure=0.6, nu=(0.4, 0.42, 0.46), crasse=0.7,
                       crasse_col=(0.005, 0.005, 0.006), graine=13)
    # anneaux magnétiques : métal noir brillant à liseré, rugosité >= 0,40 (tores : lucioles, README)
    M["anneau"] = surf("anneau", (0.02, 0.022, 0.03), rough=0.42, met=0.9, usure=0.3, nu=(0.25, 0.3, 0.4), crasse=0.3, graine=14)
    # canon : alliage plus clair, cannelé
    M["canon"] = surf("canon", (0.16, 0.17, 0.19), rough=0.38, met=0.8, tole=(0.5, 0.25), joint=0.45, joint_l=0.03, var=0.1, usure=0.5,
                      nu=(0.45, 0.47, 0.5), crasse=0.6, crasse_col=(0.006, 0.006, 0.007), relief=0.7, graine=15)
    # peau cyber-organique du Kaiju : écailles sombres, reflets violets ; os/griffes : ivoire gris
    M["peau"] = surf("peau", (0.040, 0.030, 0.055), rough=0.5, met=0.35, tole=(0.45, 0.28), joint=0.5, joint_l=0.03, var=0.2,
                     usure=0.35, nu=(0.28, 0.2, 0.36), crasse=0.7, crasse_col=(0.004, 0.003, 0.006), relief=0.8, graine=16)
    M["os"] = surf("os", (0.42, 0.40, 0.34), rough=0.55, met=0.05, usure=0.2, nu=(0.6, 0.58, 0.5), crasse=0.5, crasse_col=(0.05, 0.04, 0.03), graine=17)
    if not gris:
        for k in ("blind", "blind2", "peau"):
            iridescence(M[k], part=0.55 if k != "peau" else 0.4)
        iridescence(M["anneau"], part=0.3, blend=0.6)
    # émissifs (couche lueur) : conduits, cœur à vortex, pointes de cristal ; éteints à 30 % de jour (main_scale)
    M["conduit"] = S.mat_emissive(prefix + "conduit", CYAN, strength=2.2, base=(0.01, 0.08, 0.09), main_scale=0.35)
    M["coeur"] = S.mat_emissive(prefix + "coeur", COEUR, strength=3.0, base=(0.02, 0.10, 0.11), main_scale=0.4, crust=(1.6, 0.5, 3))
    M["cristal"] = S.mat_emissive(prefix + "cristal", CRISTAL, strength=1.8, base=(0.03, 0.06, 0.14), main_scale=0.3, crust=(2.4, 0.35, 5))
    M["turq"] = S.mat_emissive(prefix + "conduit_turq", TURQUOISE, strength=1.6, base=(0.01, 0.07, 0.07), main_scale=0.3)
    return M
