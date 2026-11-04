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


def matieres(S, v2=False):
    """v2 (corrections de la critique, 3/11) : neutres plus clairs et plus chauds, peintures par machine, gemmes facettées ;
    cible mesurée sur la couche main (alpha > 0,5) : luminance moyenne ≥ 0,24, p90 ≥ 0,50, saturation dans la plage vanilla."""
    M = P.matieres(S, "atelier")
    MT.PATINE["sans"] = tuple(MT.PATINE.get("sans", ())) + ("a_blanc", "a_rouge_vif", "a_fil", "a_bois")
    if v2:
        MT.PATINE["ec"] = 0.3
        MT.PATINE["sans"] = tuple(MT.PATINE["sans"]) + ("a_chene", "a_manganese", "a_gemme")
    sf = MT.surface
    cr = (0.008, 0.0065, 0.004)
    if v2:
        cr2 = (0.03, 0.022, 0.014)
        M["car"] = sf("v_car", (0.3, 0.25, 0.19), rough=0.42, met=0.3, tole=(0.62, 0.41), joint=0.55, var=0.09, coulures=0.6,
                      rouille=(0.26, 0.12, 0.05), usure=0.7, nu=(0.66, 0.62, 0.55), crasse=0.7, crasse_col=cr2, pied=(0.0, 0.6, 0.4), grain=0.1, graine=61)
        M["car2"] = sf("v_car2", (0.43, 0.37, 0.28), rough=0.5, met=0.3, tole=(0.33, 0.27), joint=0.55, var=0.1, coulures=0.6,
                       rouille=(0.26, 0.12, 0.05), usure=0.7, nu=(0.66, 0.62, 0.55), crasse=0.7, crasse_col=cr2, grain=0.1, graine=62)
        M["acier"] = sf("v_acier", (0.27, 0.22, 0.16), rough=0.45, met=0.65, usure=0.8, nu=(0.72, 0.68, 0.6), crasse=0.65, crasse_col=cr2,
                        coulures=0.4, rouille=(0.3, 0.13, 0.05), graine=63)
        M["acier_clair"] = sf("v_acier_clair", (0.52, 0.49, 0.43), rough=0.36, met=0.8, usure=0.4, crasse=0.5, crasse_col=cr2, graine=64)
        M["noir"] = sf("v_noir", (0.05, 0.045, 0.04), rough=0.6, met=0.2, usure=0.5, nu=(0.25, 0.24, 0.22), crasse=0.5, crasse_col=cr, grain=0.1, graine=65)
        M["riv"] = sf("v_riv", (0.3, 0.24, 0.16), rough=0.5, met=0.5, usure=0.4, crasse=0.4, graine=66)
        M["chene"] = sf("a_chene", (0.54, 0.34, 0.17), rough=0.78, met=0.0, tole=(0.9, 0.11), joint=0.5, var=0.16, coulures=0.4,
                        rouille=(0.12, 0.07, 0.03), usure=0.5, nu=(0.62, 0.45, 0.28), crasse=0.65, crasse_col=cr2, relief=0.4, grain=0.2, graine=67)
        M["rouge_oxyde"] = sf("a_rouge_oxyde", (0.42, 0.11, 0.05), rough=0.55, met=0.2, coulures=0.5, rouille=(0.2, 0.07, 0.02), usure=0.75,
                              nu=(0.5, 0.42, 0.36), crasse=0.65, crasse_col=cr2, pied=(0.0, 0.5, 0.4), grain=0.12, graine=68)
        M["jaune"] = sf("a_jaune_engin", (0.66, 0.44, 0.03), rough=0.45, met=0.15, coulures=0.55, rouille=(0.24, 0.1, 0.03), usure=0.75,
                        nu=(0.62, 0.6, 0.56), crasse=0.65, crasse_col=cr2, pied=(0.0, 0.6, 0.45), grain=0.1, graine=69)
        M["manganese"] = sf("a_manganese", (0.56, 0.54, 0.5), rough=0.32, met=0.85, usure=0.3, nu=(0.8, 0.78, 0.74), crasse=0.55, crasse_col=cr2,
                            grain=0.12, graine=70)
        M["vert_machine"] = sf("a_vert_machine", (0.19, 0.33, 0.26), rough=0.45, met=0.2, coulures=0.4, rouille=(0.22, 0.12, 0.05), usure=0.7,
                               nu=(0.62, 0.6, 0.55), crasse=0.6, crasse_col=cr2, grain=0.1, graine=71)
        M["bleu_machine"] = sf("a_bleu_machine", (0.13, 0.25, 0.4), rough=0.45, met=0.2, coulures=0.4, rouille=(0.22, 0.12, 0.05), usure=0.7,
                               nu=(0.6, 0.6, 0.58), crasse=0.6, crasse_col=cr2, grain=0.1, graine=72)
        M["email"] = sf("a_email", (0.5, 0.25, 0.03), rough=0.12, met=0.0, usure=0.0, crasse=0.3, crasse_col=(0.1, 0.05, 0.01), grain=0.08, graine=73)
        M["gemme"] = P.verre_col("a_gemme", (0.01, 0.2, 0.3), (0.6, 0.97, 1.0), rough=0.06)
        M["jet"] = sf("a_jet", (0.7, 0.82, 0.86), rough=0.1, met=0.0, usure=0.0, crasse=0.0, grain=0.15, graine=74)
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
    if v2:
        cr2 = (0.03, 0.022, 0.014)
        M["fonte"] = sf("v_fonte", (0.15, 0.13, 0.11), rough=0.6, met=0.55, usure=0.75, nu=(0.55, 0.52, 0.47), crasse=0.7, crasse_col=cr2,
                        coulures=0.5, rouille=(0.26, 0.11, 0.04), pied=(0.0, 0.5, 0.4), grain=0.14, graine=81)
        M["pierre"] = sf("v_pierre", (0.42, 0.38, 0.32), rough=0.92, met=0.0, usure=0.55, nu=(0.62, 0.58, 0.5), crasse=0.8, crasse_col=cr2, grain=0.3, graine=82)
        M["pierre2"] = sf("v_pierre2", (0.3, 0.27, 0.23), rough=0.92, met=0.0, usure=0.5, nu=(0.5, 0.47, 0.42), crasse=0.8, crasse_col=cr2, grain=0.3, graine=83)
        M["sable"] = sf("v_sable", (0.66, 0.52, 0.31), rough=0.95, met=0.0, usure=0.0, crasse=0.45, crasse_col=(0.2, 0.13, 0.06), grain=0.22, graine=84)
        M["gravier"] = sf("v_gravier", (0.45, 0.42, 0.37), rough=0.95, met=0.0, usure=0.0, crasse=0.55, crasse_col=(0.08, 0.07, 0.06), grain=0.45, graine=85)
        M["beton"] = sf("v_beton", (0.4, 0.37, 0.32), rough=0.9, met=0.0, tole=(1.3, 0.55), joint=0.6, var=0.07, coulures=0.6, rouille=(0.12, 0.1, 0.07),
                        usure=0.5, nu=(0.5, 0.47, 0.42), crasse=0.7, crasse_col=cr2, pied=(0.0, 1.0, 0.4), relief=0.3, grain=0.16, graine=86)
        M["boue"] = sf("v_boue", (0.8, 0.83, 0.8), rough=0.25, met=0.0, usure=0.0, crasse=0.35, crasse_col=(0.2, 0.22, 0.22), grain=0.2, graine=87)
        M["meule"] = sf("v_meule", (0.36, 0.36, 0.37), rough=0.35, met=0.85, usure=0.2, crasse=0.35, crasse_col=cr2, grain=0.18, graine=88,
                        bandes=(0.05, (0.16, 0.16, 0.17), 0.3))
        M["spire"] = sf("v_spire", (0.82, 0.42, 0.18), rough=0.3, met=0.85, usure=0.2, nu=(0.95, 0.62, 0.38), crasse=0.35,
                        crasse_col=(0.08, 0.03, 0.01), grain=0.06, graine=90)
        M["cuivre"] = sf("v_cuivre", (0.62, 0.27, 0.1), rough=0.35, met=0.8, coulures=0.4, rouille=(0.08, 0.22, 0.15), usure=0.5,
                         nu=(0.85, 0.5, 0.28), crasse=0.5, crasse_col=cr2, graine=91)
        M["cristal_f"] = cristal_facette(S, "v_cristal_f", (0.12, 0.85, 1.0), 2.8)
        M["cristal_f2"] = cristal_facette(S, "v_cristal_f2", (0.35, 0.95, 1.0), 2.2)
        M["diamant"] = sf("v_diamant", (0.72, 0.72, 0.7), rough=0.55, met=0.6, usure=0.0, crasse=0.2, crasse_col=cr2, grain=0.55, graine=89)
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


def cristal_facette(S, name, col, force):
    """Cristal qui luit, FACETTES lisibles (critique : « pastilles rondes sans facettes ») : la force d'émission suit l'orientation
    de chaque face par rapport à la caméra (Layer Weight « Facing ») ; les faces de profil restent sombres, celles de face claires."""
    m = P.lueur(S, name, col, force, 0.55, part=0.25, echelle=24.0)
    N, L = m.node_tree.nodes, m.node_tree.links
    k = N.get("fo_emit_strength")
    src = k.inputs[0].links[0].from_socket
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    f = MT._range(N, L, lw.outputs["Facing"], 0.0, 1.0, 1.0, 0.18)
    L.new(MT._math(N, L, "MULTIPLY", src, f), k.inputs[0])
    return m


def halo(S, k, loc, rgb, watts, r=(0.5, 1.3)):
    """Lumière portée au sol la nuit (passe light seulement, source ponctuelle sans bruit) et sa fenêtre : centrée sous la source,
    en tuiles du JEU (x est, y SUD), pleine jusqu'à r[0], nulle à r[1] (rendre.py, comme render.py)."""
    S.halo_light(loc, rgb, watts, radius=0.08)
    k.halos.append({"at": (loc[0], -loc[1] / D, 0.0), "r": r})   # hauteurs du dégradé de la flamme (posées par la torchère avant matieres())
