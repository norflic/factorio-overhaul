"""MATIÈRES COMMUNES des bâtiments d'atelier (lot DA-ATELIERS) : palette « atelier » de palettes.py (matières neutres du kit
calcul_o) + matières de fonction : roche, sable, brique réfractaire, peinture de balisage, fonte, eau, feu, cristal.
"""
import math

import mat as MT
import organes as O
import palettes as P

D = O.D


def Y(ty):
    """Tuiles vers unités Blender (axe nord)."""
    return ty * D


def matieres(S):
    M = P.matieres(S, "atelier")
    MT.PATINE["sans"] = tuple(MT.PATINE.get("sans", ())) + ("a_blanc", "a_rouge_vif", "a_fil", "a_bois")
    sf = MT.surface
    cr = (0.008, 0.0065, 0.004)
    M["fonte"] = sf("a_fonte", (0.055, 0.052, 0.05), rough=0.62, met=0.55, usure=0.7, nu=(0.42, 0.4, 0.37), crasse=0.85, crasse_col=cr,
                    coulures=0.6, rouille=(0.17, 0.07, 0.025), pied=(0.0, 0.5, 0.5), grain=0.14, graine=41)
    M["pierre"] = sf("a_pierre", (0.2, 0.185, 0.16), rough=0.92, met=0.0, usure=0.55, nu=(0.36, 0.34, 0.3), crasse=0.9, crasse_col=cr, grain=0.3, graine=42)
    M["pierre2"] = sf("a_pierre2", (0.13, 0.12, 0.11), rough=0.92, met=0.0, usure=0.5, nu=(0.3, 0.28, 0.25), crasse=0.9, crasse_col=cr, grain=0.3, graine=43)
    M["laitier"] = sf("a_laitier", (0.09, 0.085, 0.1), rough=0.85, met=0.1, usure=0.5, nu=(0.3, 0.29, 0.33), crasse=0.8, crasse_col=cr, grain=0.3, graine=44)
    M["sable"] = sf("a_sable", (0.42, 0.32, 0.18), rough=0.95, met=0.0, usure=0.0, crasse=0.5, crasse_col=(0.12, 0.08, 0.04), grain=0.22, graine=45)
    M["gravier"] = sf("a_gravier", (0.24, 0.225, 0.2), rough=0.95, met=0.0, usure=0.0, crasse=0.6, crasse_col=(0.05, 0.045, 0.04), grain=0.45, graine=46)
    M["brique"] = sf("a_brique", (0.23, 0.08, 0.04), rough=0.85, met=0.0, tole=(0.16, 0.07), joint=0.35, var=0.12, coulures=0.4,
                     rouille=(0.06, 0.04, 0.03), usure=0.5, nu=(0.4, 0.18, 0.1), crasse=0.85, crasse_col=cr, relief=0.6, grain=0.18, graine=47)
    M["blanc"] = sf("a_blanc", (0.8, 0.79, 0.75), rough=0.45, met=0.05, coulures=0.45, rouille=(0.2, 0.09, 0.035), usure=0.6, nu=(0.62, 0.6, 0.57),
                    crasse=0.8, crasse_col=cr, grain=0.08, graine=48)
    M["rouge_vif"] = sf("a_rouge_vif", (0.62, 0.05, 0.025), rough=0.45, met=0.05, coulures=0.4, rouille=(0.16, 0.05, 0.02), usure=0.55,
                        nu=(0.5, 0.3, 0.22), crasse=0.75, crasse_col=cr, grain=0.08, graine=49)
    M["suie"] = sf("a_suie", (0.012, 0.011, 0.011), rough=0.85, met=0.1, usure=0.25, nu=(0.12, 0.11, 0.1), crasse=0.6, crasse_col=(0.002, 0.002, 0.002),
                   grain=0.25, graine=50)
    M["eau"] = sf("a_eau", (0.22, 0.27, 0.27), rough=0.08, met=0.0, usure=0.0, crasse=0.3, crasse_col=(0.05, 0.07, 0.07), grain=0.12, graine=51)
    M["boue"] = sf("a_boue", (0.36, 0.38, 0.38), rough=0.3, met=0.0, usure=0.0, crasse=0.4, crasse_col=(0.1, 0.12, 0.12), grain=0.2, graine=52)
    M["meule"] = sf("a_meule", (0.2, 0.205, 0.21), rough=0.3, met=0.85, usure=0.2, crasse=0.4, crasse_col=cr, grain=0.18, graine=53,
                    bandes=(0.045, (0.06, 0.062, 0.066), 0.35))
    M["fil"] = sf("a_fil", (0.78, 0.36, 0.13), rough=0.3, met=0.75, usure=0.3, nu=(0.85, 0.48, 0.25), crasse=0.45, crasse_col=(0.05, 0.02, 0.01),
                  grain=0.05, graine=54, bandes=(0.022, (0.45, 0.17, 0.05), 0.4))
    M["jet"] = sf("a_jet", (0.55, 0.68, 0.72), rough=0.1, met=0.0, usure=0.0, crasse=0.0, grain=0.15, graine=58)
    M["givre"] = sf("a_givre", (0.5, 0.6, 0.68), rough=0.8, met=0.0, usure=0.0, crasse=0.5, crasse_col=(0.16, 0.22, 0.28), grain=0.25, graine=55)
    M["bois"] = sf("a_bois", (0.3, 0.165, 0.075), rough=0.8, met=0.0, tole=(0.9, 0.11), joint=0.4, var=0.14, coulures=0.5,
                   rouille=(0.05, 0.035, 0.02), usure=0.55, nu=(0.32, 0.2, 0.11), crasse=0.85, crasse_col=cr, relief=0.4, grain=0.2, graine=56)
    M["charbon"] = sf("a_charbon", (0.02, 0.02, 0.022), rough=0.45, met=0.3, usure=0.6, nu=(0.18, 0.18, 0.2), crasse=0.6,
                      crasse_col=(0.003, 0.003, 0.003), grain=0.4, graine=57)
    M["feu"] = P.lueur(S, "a_feu", (1.0, 0.42, 0.08), 6.0, 0.45, part=0.7, echelle=16.0)
    M["braise"] = P.lueur(S, "a_braise", (1.0, 0.26, 0.04), 3.2, 0.4, part=0.8, echelle=12.0)
    M["cuisson"] = P.lueur(S, "a_cuisson", (1.0, 0.5, 0.1), 4.5, 0.5, part=0.5, echelle=22.0)
    M["cristal"] = P.lueur(S, "a_cristal", (0.06, 0.78, 1.0), 2.6, 0.7, part=0.45, echelle=14.0)
    M["projecteur"] = P.lueur(S, "a_projecteur", (1.0, 0.86, 0.55), 6.0, 0.6, part=0.2, echelle=30.0)
    M["gyro"] = P.lueur(S, "a_gyro", (1.0, 0.5, 0.04), 6.0, 0.55, part=0.25, echelle=30.0)
    M["flamme"] = flamme(S)
    return M


def flamme(S):
    """Flamme : émission jaune au cœur (bas), orange puis rouge vers le haut, bruitée (langues)."""
    m = S.mat_emissive("a_flamme", (1.0, 0.6, 0.16), strength=5.5, base=(0.02, 0.01, 0.0), main_scale=0.0, crust=(7.0, 0.55, 5.0))
    N, L = m.node_tree.nodes, m.node_tree.links
    p = N["Principled BSDF"]
    geo = N.new("ShaderNodeNewGeometry")
    sz = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sz.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (1.0, 0.72, 0.28, 1.0)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.8, 0.1, 0.01, 1.0)
    e = ramp.color_ramp.elements.new(0.35)
    e.color = (1.0, 0.4, 0.05, 1.0)
    z0, z1 = FLAMME_Z
    r = MT._range(N, L, sz.outputs["Z"], z0, z1, 0.0, 1.0)
    L.new(r, ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], p.inputs["Emission Color"])
    k = N.get("fo_emit_strength")
    src = k.inputs[0].links[0].from_socket
    fade = MT._range(N, L, sz.outputs["Z"], z0, z1, 1.0, 0.35)
    L.new(MT._math(N, L, "MULTIPLY", src, fade), k.inputs[0])
    return m


FLAMME_Z = (3.0, 4.6)


def halo(S, k, loc, rgb, watts, r=(0.5, 1.3)):
    """Lumière portée au sol la nuit (passe light seulement, source ponctuelle sans bruit) et sa fenêtre : centrée sous la source,
    en tuiles du JEU (x est, y SUD), pleine jusqu'à r[0], nulle à r[1] (rendre.py, comme render.py)."""
    S.halo_light(loc, rgb, watts, radius=0.08)
    k.halos.append({"at": (loc[0], -loc[1] / D, 0.0), "r": r})   # hauteurs du dégradé de la flamme (posées par la torchère avant matieres())
