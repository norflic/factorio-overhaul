"""MATIÈRES du kit chimie (lot DA-CHIMIE) : recette de mat.py (copie du kit calcul_o, même usure, même patine), UNE palette
pour la famille (pas d'âge). Clés neutres partagées avec le calcul (noir, acier, acier_clair, riv, cuivre, chevron, verre,
isolant…) et clés propres aux 4 machines.

Ronde 2 (critique du 3/11, CRITIQUE.md) : aciers RÉCHAUFFÉS (rouge − bleu ≥ 0,08, saturation vers la plage vanilla 0,47 à
0,49), arêtes usées plus claires et aciers moins rugueux (reflets : p95 ≥ 150), lueurs données par leur COULEUR CIBLE sRVB
(lueur2) : la couche principale montre la surface lumineuse à V ≈ 0,5, la lueur additive porte la couleur à alpha ≈ 0,4.
Avant, matière claire + lueur forte écrêtaient en blanc (33 à 60 % de presque blanc de jour).
"""
import mat as MT


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lueur2(S, name, srgb, a_glow=0.4, v_main=0.5, part=0.4, echelle=18.0, graine=3.0):
    """Surface lumineuse de couleur cible srgb (0..255). La passe lueur rend sRVB(s × couleur) : son canal le plus fort
    (alpha de la couche additive) vaut a_glow ; la passe principale rend la même couleur à V = v_main (main_scale)."""
    lin = [_lin(c / 255.0) for c in srgb]
    m = max(lin)
    col = tuple(c / m for c in lin)
    s = _lin(a_glow)
    ms = _lin(v_main) / s
    return S.mat_emissive(name, col, strength=s, base=tuple(c * 0.05 for c in col), main_scale=ms,
                          crust=(echelle, part, graine))


def matieres(S):
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.2, tb=0.34, ra=0.28, ec=0.55, nu_k=1.6, ec_col=(0.03, 0.017, 0.007),
                     sans=("verre", "cuivre", "chrome", "noir", "isolant", "blanc", "laiton"))
    sf = MT.surface
    cr = (0.012, 0.008, 0.004)
    rouille = (0.24, 0.085, 0.025)
    M = {}
    # ---- neutres (réchauffés)
    M["noir"] = sf("h_noir", (0.018, 0.015, 0.012), rough=0.55, met=0.3, usure=0.5, nu=(0.3, 0.27, 0.22), crasse=0.6,
                   crasse_col=(0.004, 0.003, 0.002), grain=0.1, graine=15)
    M["acier"] = sf("h_acier", (0.13, 0.093, 0.06), rough=0.38, met=0.8, usure=0.9, nu=(0.86, 0.78, 0.64), crasse=0.75,
                    crasse_col=cr, coulures=0.6, rouille=rouille, graine=17)
    M["acier_clair"] = sf("h_acier_clair", (0.4, 0.33, 0.22), rough=0.3, met=0.85, usure=0.5, nu=(0.9, 0.84, 0.72),
                          crasse=0.6, crasse_col=cr, coulures=0.4, rouille=rouille, graine=18)
    M["chrome"] = sf("h_chrome", (0.56, 0.55, 0.52), rough=0.14, met=1.0, usure=0.2, nu=(0.92, 0.9, 0.86), crasse=0.5,
                     crasse_col=(0.02, 0.018, 0.015), grain=0.03, graine=19)
    M["riv"] = sf("h_riv", (0.16, 0.11, 0.06), rough=0.45, met=0.6, usure=0.4, nu=(0.7, 0.6, 0.45), crasse=0.5, graine=20)
    M["caoutchouc"] = sf("h_cao", (0.025, 0.022, 0.018), rough=0.72, met=0.0, usure=0.3, nu=(0.09, 0.08, 0.07), crasse=0.5,
                         crasse_col=cr, graine=21)
    M["cuivre"] = sf("h_cuivre", (0.8, 0.33, 0.18), rough=0.26, met=0.6, coulures=0.12, rouille=(0.05, 0.17, 0.11), usure=0.75,
                     nu=(1.0, 0.74, 0.52), crasse=0.5, crasse_col=cr, grain=0.06, graine=22)
    M["laiton"] = sf("h_laiton", (0.55, 0.36, 0.1), rough=0.3, met=0.9, usure=0.5, nu=(0.9, 0.75, 0.4), crasse=0.55,
                     crasse_col=cr, coulures=0.3, rouille=(0.1, 0.12, 0.05), grain=0.06, graine=49)
    M["chevron"] = sf("h_chevron", (0.5, 0.28, 0.012), rough=0.45, met=0.2, bandes=(0.14, (0.012, 0.011, 0.01), 0.5), usure=0.8,
                      nu=(0.6, 0.55, 0.45), crasse=0.7, crasse_col=cr, coulures=0.5, graine=24)
    M["jaune"] = sf("h_jaune", (0.5, 0.27, 0.012), rough=0.42, met=0.2, coulures=0.8, rouille=rouille, usure=0.8,
                    nu=(0.75, 0.68, 0.55), crasse=0.85, crasse_col=cr, grain=0.12, graine=25)
    M["rouge"] = sf("h_rouge", (0.4, 0.025, 0.012), rough=0.45, met=0.1, usure=0.5, nu=(0.6, 0.35, 0.22), crasse=0.5,
                    crasse_col=cr, coulures=0.5, rouille=rouille, graine=26)
    M["bleu"] = sf("h_bleu", (0.02, 0.1, 0.3), rough=0.42, met=0.35, coulures=0.6, rouille=rouille, usure=0.65,
                   nu=(0.6, 0.58, 0.52), crasse=0.8, crasse_col=cr, grain=0.1, graine=27)
    M["isolant"] = sf("h_isolant", (0.52, 0.45, 0.33), rough=0.38, met=0.75, tole=(0.3, 0.22), joint=0.55, var=0.1,
                      coulures=0.7, rouille=(0.2, 0.12, 0.05), usure=0.35, nu=(0.85, 0.8, 0.7), crasse=0.75, crasse_col=cr,
                      grain=0.14, graine=30)
    M["beton"] = sf("h_beton", (0.27, 0.235, 0.19), rough=0.9, met=0.0, tole=(1.3, 0.55), joint=0.6, var=0.07, coulures=0.85,
                    rouille=(0.09, 0.07, 0.045), usure=0.5, nu=(0.4, 0.36, 0.3), crasse=0.8, crasse_col=cr,
                    pied=(0.0, 1.0, 0.55), relief=0.3, grain=0.16, graine=32)
    M["verre"] = MT.verre("h_verre", col=(0.01, 0.02, 0.03), reflet=(0.16, 0.26, 0.34))
    # ---- carénages de la famille (chauds)
    M["car"] = sf("h_car", (0.16, 0.12, 0.08), rough=0.38, met=0.35, tole=(0.62, 0.41), joint=0.45, var=0.12, coulures=0.9,
                  rouille=rouille, usure=0.8, nu=(0.78, 0.7, 0.58), crasse=0.9, crasse_col=cr, pied=(0.0, 0.8, 0.5),
                  grain=0.12, graine=11)
    M["car2"] = sf("h_car2", (0.3, 0.22, 0.13), rough=0.4, met=0.4, tole=(0.33, 0.27), joint=0.5, var=0.12, coulures=0.85,
                   rouille=rouille, usure=0.85, nu=(0.75, 0.68, 0.56), crasse=0.9, crasse_col=cr, pied=(0.0, 0.7, 0.55),
                   grain=0.12, graine=13)
    # craquage : caisson rouge oxyde, brique réfractaire à rangs de 7 px HR, suie, acier bruni par la chaleur
    M["oxyde"] = sf("h_oxyde", (0.4, 0.12, 0.05), rough=0.48, met=0.25, tole=(0.45, 0.36), joint=0.45, var=0.14, coulures=0.95,
                    rouille=(0.1, 0.035, 0.015), usure=0.75, nu=(0.62, 0.42, 0.3), crasse=0.9, crasse_col=cr,
                    pied=(0.0, 0.9, 0.6), grain=0.14, graine=41)
    M["brique"] = sf("h_brique", (0.45, 0.2, 0.1), rough=0.8, met=0.0, tole=(0.3, 0.17), joint=0.42, joint_l=0.012,
                     var=0.15, usure=0.35, nu=(0.55, 0.32, 0.18), crasse=0.85, crasse_col=(0.02, 0.008, 0.004), grain=0.22,
                     relief=0.9, coulures=0.6, rouille=(0.04, 0.03, 0.025), graine=42)
    M["suie"] = sf("h_suie", (0.03, 0.024, 0.02), rough=0.8, met=0.0, usure=0.2, crasse=0.4, grain=0.3, graine=50)
    M["chauffe"] = sf("h_chauffe", (0.22, 0.11, 0.07), rough=0.3, met=0.85, usure=0.4, nu=(0.55, 0.4, 0.5), crasse=0.6,
                      crasse_col=cr, grain=0.2, graine=51)
    M["bleui"] = sf("h_bleui", (0.08, 0.075, 0.15), rough=0.3, met=0.85, usure=0.3, nu=(0.4, 0.3, 0.45), crasse=0.6,
                    crasse_col=cr, grain=0.2, graine=52)
    # reformage : caisson gris chaud calorifugé, adsorbeurs blanc cassé usé
    M["gris_proc"] = sf("h_gris_proc", (0.31, 0.235, 0.15), rough=0.4, met=0.45, tole=(0.36, 0.26), joint=0.45, var=0.12,
                        coulures=0.95, rouille=rouille, usure=0.75, nu=(0.75, 0.7, 0.6), crasse=0.85, crasse_col=cr,
                        pied=(0.0, 0.8, 0.55), grain=0.13, graine=44)
    M["blanc"] = sf("h_blanc", (0.6, 0.53, 0.4), rough=0.4, met=0.15, coulures=0.7, rouille=(0.22, 0.12, 0.05), usure=0.6,
                    nu=(0.75, 0.72, 0.66), crasse=0.85, crasse_col=cr, pied=(0.0, 0.6, 0.45), grain=0.1, graine=43)
    # électrolyse : plaques de la pile, joints rouges
    M["plaque_pile"] = sf("h_plaque_pile", (0.075, 0.062, 0.055), rough=0.32, met=0.75, usure=0.7, nu=(0.6, 0.6, 0.62), crasse=0.6,
                          crasse_col=cr, grain=0.06, graine=45)
    M["joint_pile"] = sf("h_joint_pile", (0.45, 0.04, 0.02), rough=0.6, met=0.0, usure=0.2, crasse=0.5, crasse_col=cr,
                         graine=46)
    M["titane"] = sf("h_titane", (0.4, 0.33, 0.24), rough=0.38, met=0.9, tole=(0.5, 0.36), joint=0.6, var=0.1, usure=0.45, nu=(0.82, 0.78, 0.7), crasse=0.7,
                     crasse_col=cr, coulures=0.5, rouille=rouille, grain=0.06, graine=47)
    M["sel_lilas"] = sf("h_sel_lilas", (0.36, 0.13, 0.5), rough=0.75, met=0.0, usure=0.0, crasse=0.6,
                        crasse_col=(0.08, 0.04, 0.1), grain=0.3, graine=48)
    # ---- lueurs : couleur cible sRVB (critique), principale à V ≈ 0,5, lueur à alpha ≈ 0,4
    M["feu"] = lueur2(S, "h_feu", (255, 80, 15), 0.55, 0.55, part=0.55, echelle=16.0)
    M["tube_rouge"] = lueur2(S, "h_tube_rouge", (255, 120, 30), 0.4, 0.5, part=0.4, echelle=22.0, graine=5.0)
    M["cyan"] = lueur2(S, "h_cyan", (60, 200, 230), 0.42, 0.5, part=0.4, echelle=26.0, graine=7.0)
    M["ambre"] = lueur2(S, "h_ambre", (210, 120, 20), 0.4, 0.55, part=0.4, echelle=18.0, graine=9.0)
    M["lilas"] = lueur2(S, "h_lilas", (150, 70, 200), 0.42, 0.55, part=0.4, echelle=18.0, graine=11.0)
    M["voyant"] = lueur2(S, "h_voyant", (255, 120, 20), 0.6, 0.6, part=0.2, echelle=30.0)
    M["voyant_b"] = lueur2(S, "h_voyant_b", (30, 120, 255), 0.6, 0.6, part=0.2, echelle=30.0)
    M["voyant_v"] = lueur2(S, "h_voyant_v", (40, 230, 70), 0.55, 0.6, part=0.2, echelle=30.0)
    M["voyant_r"] = lueur2(S, "h_voyant_r", (255, 30, 15), 0.6, 0.6, part=0.2, echelle=30.0)
    return M
