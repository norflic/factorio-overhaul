"""PALETTES du kit machines par âge (lot DESIGN-CALCUL CALC-MACHINES-AMONT). Couleurs LINÉAIRES (Base Color de
Blender) reprises des matières de la lignée validée par le DC (levels/commun/ages.py, mitrailleuse du 23/10) pour que
les machines d'un âge soient de la même famille que les bâtiments à niveaux du même âge ; recette de surface usée de
mat.py (kit vaisseau_o, lot CENTRE-OPUS). Écart dit franchement : la bible (DESIGN_EPOQUES §5) écrit « tôle jaune
délavée #8C7A3A » pour l'âge 4 ; la lignée validée a pris un jaune de signalisation et du noir (ronde 5) : on suit la
lignée.

Clés communes à tous les âges (organes.py les emploie) : rivet, boulon, trim, acier, noir, rampe, caillebotis, grille,
armoire, moteur, ailette, cable, socle, rouge, danger_j, danger_n ; lumières : feu (voyant de l'âge), feu2.
"""
import mat as MT


def _commun(S, M, acier=(0.2, 0.2, 0.2), trim=(0.32, 0.31, 0.29), feu=(1.0, 0.42, 0.1)):
    su = MT.surface
    M["acier"] = su("m_acier", acier, rough=0.5, met=0.55, usure=0.6, coulures=0.3)
    M["trim"] = su("m_trim", trim, rough=0.45, met=0.6, usure=0.8, crasse=0.4)
    M["rivet"] = su("m_rivet", tuple(min(1.0, c * 1.25) for c in trim), rough=0.42, met=0.6, usure=0.0, crasse=0.25)
    M["boulon"] = su("m_boulon", (0.13, 0.11, 0.09), rough=0.45, met=0.6, usure=0.9, crasse=0.3)
    M["noir"] = su("m_noir", (0.012, 0.012, 0.013), rough=0.7, met=0.0, usure=0.0, crasse=0.0)
    M["rampe"] = su("m_rampe", (0.2, 0.17, 0.12), rough=0.45, met=0.5, usure=0.5, crasse=0.3)
    M["caillebotis"] = su("m_caill", (0.11, 0.095, 0.08), rough=0.55, met=0.5, usure=0.9, crasse=0.6)
    M["grille"] = su("m_grille", (0.09, 0.09, 0.09), rough=0.6, met=0.4, usure=0.6, crasse=0.5)
    M["cable"] = su("m_cable", (0.02, 0.02, 0.022), rough=0.6, met=0.0, usure=0.0, crasse=0.2)
    M["socle"] = su("m_socle", (0.13, 0.125, 0.115), rough=0.85, met=0.0, tole=(0.5, 0.5), joint=0.55, usure=0.4,
                    crasse=0.7, coulures=0.0)
    M["rouge"] = su("m_rouge", (0.42, 0.035, 0.02), rough=0.55, met=0.1, usure=0.8)
    M["danger_j"] = su("m_dj", (0.62, 0.46, 0.02), rough=0.7, met=0.0, usure=0.9, crasse=0.6)
    M["danger_n"] = su("m_dn", (0.03, 0.03, 0.03), rough=0.7, met=0.0, usure=0.9, crasse=0.4)
    M["feu"] = MT.lumiere(S, "m_feu", feu, 6.0, 0.3)


def age04(S):
    """Pétrole : jaune de signalisation délavé (capots), noir (structure), acier galvanisé, volants rouges ; feu orange."""
    su = MT.surface
    M = {}
    _commun(S, M, acier=(0.16, 0.162, 0.165), trim=(0.3, 0.31, 0.31), feu=(1.0, 0.42, 0.1))
    M["capot"] = su("m4_capot", (0.6, 0.48, 0.03), rough=0.72, met=0.0, tole=(0.62, 0.42), joint=0.45, usure=0.9,
                    coulures=0.55, rouille=(0.24, 0.085, 0.03), crasse=0.7)
    M["capot2"] = su("m4_capot2", (0.5, 0.4, 0.025), rough=0.72, met=0.0, tole=(0.4, 0.3), joint=0.45, usure=0.9,
                     coulures=0.5, rouille=(0.24, 0.085, 0.03), crasse=0.7)
    M["structure"] = su("m4_noir", (0.045, 0.044, 0.042), rough=0.45, met=0.15, tole=(0.5, 0.5), joint=0.5, usure=1.0,
                        coulures=0.3, crasse=0.5)
    M["galva"] = su("m4_galva", (0.3, 0.31, 0.31), rough=0.42, met=0.45, tole=(0.45, 0.3), joint=0.6, usure=0.6,
                    coulures=0.35, crasse=0.55)
    M["armoire"] = M["galva"]
    M["moteur"] = su("m4_moteur", (0.05, 0.08, 0.05), rough=0.5, met=0.3, usure=0.9, crasse=0.5)
    M["ailette"] = M["galva"]
    M["verre"] = MT.verre("m4_verre")
    M["carte"] = su("m4_carte", (0.03, 0.16, 0.05), rough=0.4, met=0.1, usure=0.0, crasse=0.1, tole=(0.08, 0.05),
                    joint=0.5, joint_l=0.008)
    M["cuivre"] = su("m4_cuivre", (0.5, 0.2, 0.07), rough=0.35, met=0.8, usure=0.6, crasse=0.4)
    M["feu2"] = MT.lumiere(S, "m4_feu2", (1.0, 0.75, 0.3), 5.0, 0.3)
    M["tuyau"] = su("m4_tuyau", (0.05, 0.043, 0.036), rough=0.42, met=0.2, usure=1.2, nu=(0.3, 0.24, 0.17),
                    coulures=0.6, rouille=(0.24, 0.085, 0.03), crasse=0.6, crasse_col=(0.06, 0.035, 0.015))
    M["socle"] = su("m4_socle", (0.07, 0.055, 0.04), rough=0.85, met=0.05, tole=(0.5, 0.5), joint=0.5, usure=0.5,
                    crasse=0.8, crasse_col=(0.06, 0.035, 0.015), coulures=0.4, rouille=(0.24, 0.085, 0.03))
    M["chrome"] = su("m4_chrome", (0.38, 0.37, 0.35), rough=0.3, met=0.85, usure=0.3, crasse=0.5)
    return M


def age12(S):
    """Supraconducteurs : noir et chrome (structure), givre (lignes froides et panneaux de la boîte froide, en
    ACCENT), cuivre et or des étages et des barres ; anneaux cyan lumineux. Ronde r2 (mesure de r1 : médiane du
    corps 0,32 à 0,37 contre 0,17 à 0,24 au vanilla, saturation 0,08 contre 0,3 à 0,5) : corps plus sombre, crasse
    et coulures CHAUDES (brun, rouille), givre assombri et réduit."""
    su = MT.surface
    M = {}
    brun = (0.06, 0.032, 0.014)
    rouille = (0.26, 0.085, 0.025)
    _commun(S, M, acier=(0.045, 0.042, 0.04), trim=(0.26, 0.25, 0.24), feu=(0.29, 0.94, 1.0))
    M["socle"] = su("m12_socle", (0.06, 0.042, 0.028), rough=0.85, met=0.1, tole=(0.6, 0.6), joint=0.45, usure=0.5,
                    crasse=0.8, crasse_col=brun, coulures=0.4, rouille=rouille)
    M["capot"] = su("m12_givre", (0.3, 0.38, 0.42), rough=0.8, met=0.05, tole=(0.62, 0.42), joint=0.45, usure=0.4,
                    coulures=0.7, rouille=(0.16, 0.1, 0.06), crasse=0.75, crasse_col=brun, var=0.12)
    M["capot2"] = su("m12_givre2", (0.2, 0.25, 0.28), rough=0.8, met=0.05, tole=(0.42, 0.32), joint=0.45, usure=0.4,
                     coulures=0.7, rouille=(0.16, 0.1, 0.06), crasse=0.75, crasse_col=brun, var=0.12)
    M["structure"] = su("m12_noir", (0.036, 0.027, 0.02), rough=0.35, met=0.5, tole=(0.55, 0.38), joint=0.4, usure=1.0,
                        nu=(0.24, 0.2, 0.16), coulures=0.6, rouille=rouille, crasse=0.6, crasse_col=brun, var=0.15)
    M["chrome"] = su("m12_chrome", (0.26, 0.24, 0.21), rough=0.36, met=0.75, usure=0.5, coulures=0.4, rouille=rouille,
                     crasse=0.6, crasse_col=brun)
    M["galva"] = M["chrome"]
    M["armoire"] = su("m12_armoire", (0.05, 0.04, 0.032), rough=0.4, met=0.45, tole=(0.3, 0.6), joint=0.45, usure=0.9,
                      nu=(0.26, 0.22, 0.18), coulures=0.5, rouille=rouille, crasse=0.6, crasse_col=brun)
    M["moteur"] = su("m12_moteur", (0.05, 0.048, 0.05), rough=0.4, met=0.6, usure=1.0, nu=(0.26, 0.22, 0.18),
                     crasse=0.6, crasse_col=brun)
    M["ailette"] = M["chrome"]
    M["or"] = su("m12_or", (0.5, 0.3, 0.08), rough=0.32, met=0.9, usure=0.3, crasse=0.45, crasse_col=brun)
    M["cuivre"] = su("m12_cuivre", (0.42, 0.13, 0.045), rough=0.38, met=0.8, usure=0.6, crasse=0.5, crasse_col=brun)
    M["mousse"] = su("m12_mousse", (0.34, 0.42, 0.46), rough=0.95, met=0.0, usure=0.0, crasse=0.7, crasse_col=brun,
                     coulures=0.8, rouille=(0.14, 0.09, 0.05), var=0.12)
    M["tuyau"] = su("m12_tuyau", (0.12, 0.075, 0.045), rough=0.45, met=0.55, usure=1.0, nu=(0.3, 0.24, 0.18),
                    coulures=0.7, rouille=rouille, crasse=0.7, crasse_col=brun)
    M["verre"] = MT.verre("m12_verre", (0.01, 0.03, 0.04), (0.1, 0.22, 0.26))
    M["feu2"] = MT.lumiere(S, "m12_feu2", (0.6, 0.98, 1.0), 4.0, 0.3)
    return M


AGES = {4: age04, 12: age12}


def matieres(age, S):
    return AGES[age](S)
