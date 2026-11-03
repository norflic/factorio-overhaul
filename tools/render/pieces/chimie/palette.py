"""MATIÈRES du kit chimie (lot DA-CHIMIE, 3/11) : recette de mat.py (copie du kit calcul_o, même usure, même patine),
UNE palette pour la famille (pas d'âge). Clés neutres partagées avec le calcul (noir, acier, acier_clair, riv, cuivre,
chevron, verre, isolant…) et clés propres aux 4 machines. lueur() : lumière en dégradé (hauteur et bruit), jamais un aplat.
"""
import bpy

import mat as MT


def lueur(S, name, col, force=4.0, main=0.45, grad=None, part=0.55, echelle=9.0, graine=3.0):
    """Lumière en dégradé. grad = (z0, z1, k0, k1) : la force passe de k0 (à z0) à k1 (à z1), position du monde."""
    force *= 0.55
    m = S.mat_emissive(name, col, strength=force, base=tuple(c * 0.08 for c in col), main_scale=main,
                       crust=(echelle, part, graine))
    if grad:
        N, L = m.node_tree.nodes, m.node_tree.links
        k = next(n for n in N if n.name == "fo_emit_strength")
        src = k.inputs[0].links[0].from_socket
        geo = N.new("ShaderNodeNewGeometry")
        sz = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Position"], sz.inputs["Vector"])
        r = MT._range(N, L, sz.outputs["Z"], grad[0], grad[1], grad[2], grad[3], True)
        L.new(MT._math(N, L, "MULTIPLY", src, r), k.inputs[0])
    return m


def matieres(S):
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.16, ra=0.28, ec=0.55, nu_k=1.45, ec_col=(0.028, 0.018, 0.008),
                     sans=("verre", "cuivre", "chrome", "noir", "isolant", "blanc"))
    sf = MT.surface
    cr = (0.008, 0.0065, 0.004)
    M = {}
    # ---- neutres (mêmes réglages que calcul_o)
    M["noir"] = sf("h_noir", (0.012, 0.0125, 0.014), rough=0.62, met=0.2, usure=0.45, nu=(0.16, 0.16, 0.16), crasse=0.6,
                   crasse_col=(0.003, 0.003, 0.003), grain=0.1, graine=15)
    M["acier"] = sf("h_acier", (0.1, 0.082, 0.065), rough=0.48, met=0.75, usure=0.85, nu=(0.68, 0.65, 0.58), crasse=0.8,
                    crasse_col=cr, coulures=0.5, rouille=(0.18, 0.08, 0.03), graine=17)
    M["acier_clair"] = sf("h_acier_clair", (0.24, 0.235, 0.225), rough=0.36, met=0.85, usure=0.4, crasse=0.65, crasse_col=cr,
                          graine=18)
    M["chrome"] = sf("h_chrome", (0.5, 0.53, 0.57), rough=0.16, met=1.0, usure=0.2, nu=(0.85, 0.87, 0.9), crasse=0.55,
                     crasse_col=(0.015, 0.016, 0.02), grain=0.03, graine=19)
    M["riv"] = sf("h_riv", (0.09, 0.075, 0.05), rough=0.55, met=0.4, usure=0.3, crasse=0.5, graine=20)
    M["caoutchouc"] = sf("h_cao", (0.02, 0.02, 0.019), rough=0.72, met=0.0, usure=0.3, nu=(0.07, 0.07, 0.065), crasse=0.5,
                         crasse_col=cr, graine=21)
    M["cuivre"] = sf("h_cuivre", (0.5, 0.2, 0.07), rough=0.3, met=0.95, coulures=0.5, rouille=(0.05, 0.17, 0.11), usure=0.55,
                     nu=(0.85, 0.5, 0.26), crasse=0.6, crasse_col=cr, graine=22)
    M["chevron"] = sf("h_chevron", (0.42, 0.26, 0.015), rough=0.5, met=0.2, bandes=(0.14, (0.012, 0.011, 0.01), 0.5), usure=0.8,
                      nu=(0.4, 0.38, 0.35), crasse=0.7, crasse_col=cr, coulures=0.5, graine=24)
    M["jaune"] = sf("h_jaune", (0.42, 0.24, 0.015), rough=0.48, met=0.2, coulures=0.7, rouille=(0.16, 0.06, 0.02), usure=0.8,
                    nu=(0.62, 0.6, 0.56), crasse=0.85, crasse_col=cr, grain=0.1, graine=25)
    M["rouge"] = sf("h_rouge", (0.3, 0.018, 0.012), rough=0.5, met=0.1, usure=0.45, nu=(0.45, 0.25, 0.18), crasse=0.5,
                    crasse_col=cr, graine=26)
    M["bleu"] = sf("h_bleu", (0.02, 0.095, 0.26), rough=0.45, met=0.35, coulures=0.5, rouille=(0.2, 0.26, 0.3), usure=0.65,
                   nu=(0.5, 0.5, 0.5), crasse=0.8, crasse_col=cr, grain=0.1, graine=27)
    M["isolant"] = sf("h_isolant", (0.38, 0.385, 0.38), rough=0.55, met=0.6, tole=(0.3, 0.22), joint=0.55, var=0.08,
                      coulures=0.55, rouille=(0.12, 0.1, 0.08), usure=0.3, crasse=0.75, crasse_col=cr, grain=0.14, graine=30)
    M["beton"] = sf("h_beton", (0.24, 0.225, 0.2), rough=0.9, met=0.0, tole=(1.3, 0.55), joint=0.6, var=0.07, coulures=0.85,
                    rouille=(0.07, 0.06, 0.045), usure=0.5, nu=(0.34, 0.32, 0.29), crasse=0.8, crasse_col=cr,
                    pied=(0.0, 1.0, 0.55), relief=0.3, grain=0.16, graine=32)
    M["verre"] = MT.verre("h_verre", col=(0.01, 0.02, 0.03), reflet=(0.16, 0.26, 0.34))
    # ---- carénages de la famille
    M["car"] = sf("h_car", (0.11, 0.105, 0.1), rough=0.42, met=0.3, tole=(0.62, 0.41), joint=0.45, var=0.09, coulures=0.8,
                  rouille=(0.2, 0.08, 0.025), usure=0.75, nu=(0.6, 0.58, 0.54), crasse=0.9, crasse_col=cr,
                  pied=(0.0, 0.8, 0.5), grain=0.1, graine=11)
    M["car2"] = sf("h_car2", (0.2, 0.19, 0.17), rough=0.5, met=0.35, tole=(0.33, 0.27), joint=0.5, var=0.1, coulures=0.7,
                   rouille=(0.2, 0.08, 0.025), usure=0.8, nu=(0.5, 0.48, 0.45), crasse=0.9, crasse_col=cr,
                   pied=(0.0, 0.7, 0.55), grain=0.11, graine=13)
    # craquage : caisson de four peint rouge oxyde, réfractaire, cheminée
    M["oxyde"] = sf("h_oxyde", (0.26, 0.065, 0.03), rough=0.55, met=0.25, tole=(0.45, 0.36), joint=0.5, var=0.1, coulures=0.85,
                    rouille=(0.1, 0.035, 0.015), usure=0.7, nu=(0.5, 0.36, 0.28), crasse=0.9, crasse_col=cr,
                    pied=(0.0, 0.9, 0.6), grain=0.12, graine=41)
    M["brique"] = sf("h_brique", (0.3, 0.12, 0.06), rough=0.85, met=0.0, tole=(0.16, 0.08), joint=0.35, joint_l=0.02, var=0.18,
                     usure=0.3, nu=(0.4, 0.25, 0.15), crasse=0.85, crasse_col=(0.02, 0.008, 0.004), grain=0.2, relief=0.7,
                     graine=42)
    M["blanc"] = sf("h_blanc", (0.47, 0.475, 0.47), rough=0.45, met=0.15, coulures=0.6, rouille=(0.2, 0.12, 0.06), usure=0.6,
                    nu=(0.62, 0.62, 0.6), crasse=0.85, crasse_col=cr, pied=(0.0, 0.6, 0.45), grain=0.08, graine=43)
    M["gris_proc"] = sf("h_gris_proc", (0.17, 0.175, 0.18), rough=0.45, met=0.4, tole=(0.5, 0.35), joint=0.5, var=0.08,
                        coulures=0.6, rouille=(0.18, 0.08, 0.03), usure=0.7, nu=(0.55, 0.55, 0.55), crasse=0.85, crasse_col=cr,
                        pied=(0.0, 0.7, 0.5), grain=0.1, graine=44)
    # électrolyse : plaques de la pile, joints rouges, flasques
    M["plaque_pile"] = sf("h_plaque_pile", (0.035, 0.055, 0.085), rough=0.4, met=0.6, usure=0.6, nu=(0.4, 0.45, 0.5), crasse=0.6,
                          crasse_col=cr, grain=0.06, graine=45)
    M["joint_pile"] = sf("h_joint_pile", (0.32, 0.03, 0.02), rough=0.65, met=0.0, usure=0.2, crasse=0.5, crasse_col=cr,
                         graine=46)
    M["titane"] = sf("h_titane", (0.28, 0.28, 0.295), rough=0.3, met=0.9, usure=0.4, nu=(0.6, 0.62, 0.66), crasse=0.7,
                     crasse_col=cr, coulures=0.35, rouille=(0.12, 0.1, 0.12), grain=0.06, graine=47)
    M["sel_lilas"] = sf("h_sel_lilas", (0.42, 0.22, 0.5), rough=0.75, met=0.0, usure=0.0, crasse=0.6,
                        crasse_col=(0.08, 0.04, 0.1), grain=0.3, graine=48)
    # ---- lueurs (couche lueur ; dégradés)
    M["feu"] = lueur(S, "h_feu", (1.0, 0.2, 0.02), 4.2, 0.3, part=0.65, echelle=16.0)
    M["tube_rouge"] = lueur(S, "h_tube_rouge", (1.0, 0.42, 0.1), 5.5, 0.55, part=0.45, echelle=22.0, graine=5.0)
    M["cyan"] = lueur(S, "h_cyan", (0.18, 0.82, 1.0), 5.0, 0.5, part=0.5, echelle=26.0, graine=7.0)
    M["ambre"] = lueur(S, "h_ambre", (1.0, 0.55, 0.1), 5.0, 0.55, part=0.45, echelle=18.0, graine=9.0)
    M["lilas"] = lueur(S, "h_lilas", (0.72, 0.3, 1.0), 5.5, 0.55, part=0.45, echelle=18.0, graine=11.0)
    M["voyant"] = lueur(S, "h_voyant", (1.0, 0.45, 0.06), 5.0, 0.5, part=0.3, echelle=30.0)
    M["voyant_b"] = lueur(S, "h_voyant_b", (0.08, 0.5, 1.0), 5.0, 0.5, part=0.3, echelle=30.0)
    M["voyant_v"] = lueur(S, "h_voyant_v", (0.12, 1.0, 0.25), 3.6, 0.5, part=0.3, echelle=30.0)
    M["voyant_r"] = lueur(S, "h_voyant_r", (1.0, 0.1, 0.04), 4.0, 0.5, part=0.3, echelle=30.0)
    return M
