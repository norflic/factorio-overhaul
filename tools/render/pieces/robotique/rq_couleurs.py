"""Matières des icônes de la robotique (lot DA-ICONES), Python pur. Elles s'AJOUTENT à celles du calcul
(tools/render/pieces/calcul/couleurs_calcul.py : même format, mêmes clés), pour rester dans la même palette.

Couleurs de FAMILLE des kits et des technologies des robots : la lumière de l'usine qui les fabrique
(prototypes/robots.lua, USINE_LUMIERE) : Atelier ambre, Hall violet, Dock bleu, Portique magenta.
"""
from couleurs_calcul import LUM, MAT, lin  # noqa: F401  (réexportées pour les scènes)

FAMILLES = ("ambre", "violet", "bleu", "magenta")

MAT.update({
    # familles : peinture des cornières, sangles et plateaux
    "peint_ambre": dict(rgb=lin("#E3901E"), rough=0.30, met=0.45, grain=0.07, creux=0.6, arete=0.8, bosse=0.06),
    "peint_violet": dict(rgb=lin("#913CE6"), rough=0.30, met=0.45, grain=0.07, creux=0.6, arete=0.8, bosse=0.06),
    "peint_bleu": dict(rgb=lin("#1F7BDC"), rough=0.30, met=0.45, grain=0.07, creux=0.6, arete=0.8, bosse=0.06),
    "peint_magenta": dict(rgb=lin("#EE3F86"), rough=0.30, met=0.45, grain=0.07, creux=0.6, arete=0.8, bosse=0.06),
    # caisse de transport
    "bois_caisse": dict(rgb=lin("#5C4128"), rough=0.62, met=0.0, grain=0.22, gs=18.0, creux=0.7, arete=0.6, bosse=0.12),
    "acier_caisse": dict(rgb=lin("#3A3D44"), rough=0.32, met=0.8, grain=0.08, creux=0.6, arete=1.0, bosse=0.06),
    # robots
    "laiton": dict(rgb=lin("#C99A4A"), rough=0.22, met=1.0, grain=0.08, creux=0.6, arete=0.6, bosse=0.10),
    "laiton_sombre": dict(rgb=lin("#6E4A1E"), rough=0.30, met=1.0, grain=0.08, creux=0.5, arete=0.8, bosse=0.08),
    "fonte": dict(rgb=lin("#2E2B2A"), rough=0.42, met=0.7, grain=0.12, creux=0.6, arete=1.0, bosse=0.10),
    "ecaille": dict(rgb=lin("#4C4E55"), rough=0.30, met=0.85, grain=0.10, creux=0.7, arete=1.2, bosse=0.10),
    "ecaille_rouille": dict(rgb=lin("#6A4030"), rough=0.36, met=0.7, grain=0.12, creux=0.7, arete=1.0, bosse=0.10),
    "chrome": dict(rgb=(0.72, 0.74, 0.77), rough=0.14, met=1.0, grain=0.04, creux=0.5, arete=0.4, bosse=0.04),
    "violet_aiguille": dict(rgb=lin("#6A34D6"), rough=0.18, met=0.7, grain=0.05, creux=0.5, arete=0.6, bosse=0.04),
    "canon": dict(rgb=lin("#6A707A"), rough=0.30, met=0.85, grain=0.10, creux=0.7, arete=1.0, bosse=0.10),
    "jaune_danger": dict(rgb=lin("#E8B020"), rough=0.35, met=0.2, grain=0.05, creux=0.5, arete=0.5, bosse=0.03),
    "panneau_solaire": dict(rgb=(0.010, 0.025, 0.16), rough=0.10, met=0.5, grain=0.03, creux=0.3, arete=0.8, bosse=0.02),
    "noir_brillant": dict(rgb=(0.012, 0.013, 0.016), rough=0.14, met=0.6, grain=0.04, creux=0.4, arete=1.4, bosse=0.03),
    # pièces
    "aimant_rouge": dict(rgb=lin("#C42020"), rough=0.26, met=0.3, grain=0.05, creux=0.5, arete=0.6, bosse=0.03),
    "aimant_bleu": dict(rgb=lin("#2040C8"), rough=0.26, met=0.3, grain=0.05, creux=0.5, arete=0.6, bosse=0.03),
    "laque_cuivre": dict(rgb=lin("#B0401C"), rough=0.12, met=0.75, grain=0.04, creux=0.5, arete=0.5, bosse=0.04),
    "tole": dict(rgb=lin("#7C828C"), rough=0.30, met=0.85, grain=0.10, gs=90.0, creux=0.8, arete=0.8, bosse=0.06),
    "etain": dict(rgb=(0.70, 0.71, 0.73), rough=0.16, met=1.0, grain=0.05, creux=0.4, arete=0.4, bosse=0.03),
    "silicium_met": dict(rgb=(0.20, 0.23, 0.31), rough=0.18, met=0.95, grain=0.24, gs=26.0, creux=0.7, arete=1.3, bosse=0.20),
    "polysilicium": dict(rgb=(0.50, 0.53, 0.60), rough=0.26, met=0.9, grain=0.20, gs=32.0, creux=0.8, arete=0.6, bosse=0.20),
    "ruban_ybco": dict(rgb=(0.40, 0.41, 0.44), rough=0.18, met=1.0, grain=0.05, gs=150.0, creux=0.6, arete=0.6, bosse=0.03),
    "tranche": dict(rgb=(0.20, 0.25, 0.36), rough=0.08, met=0.75, grain=0.02, creux=0.2, arete=0.3, bosse=0.04),
    "silicium_casse": dict(rgb=(0.62, 0.65, 0.72), rough=0.30, met=0.6, grain=0.30, gs=40.0, creux=0.4, arete=0.6, bosse=0.25),
    "miroir": dict(rgb=(0.92, 0.93, 0.95), rough=0.30, met=1.0, grain=0.01, creux=0.2, arete=0.2, bosse=0.0),
    "ruban_sombre": dict(rgb=(0.10, 0.10, 0.12), rough=0.30, met=0.6, grain=0.04, creux=0.4, arete=0.6, bosse=0.02),
    "or_mur": dict(rgb=lin("#E2A83A"), rough=0.32, met=0.55, grain=0.06, creux=0.6, arete=0.6, bosse=0.06),
    "argent_hc49": dict(rgb=(0.90, 0.91, 0.93), rough=0.34, met=0.9, grain=0.10, gs=140.0, creux=0.5, arete=0.4, bosse=0.03),
    "moyeu_bleu": dict(rgb=lin("#1E5FB8"), rough=0.28, met=0.5, grain=0.05, creux=0.5, arete=0.6, bosse=0.03),
})

LUM.update({
    "fam_ambre": (lin("#FFD884"), lin("#E07A10"), 1.15),
    "fam_violet": (lin("#DCC0FF"), lin("#8A34E8"), 1.15),
    "fam_bleu": (lin("#B4E2FF"), lin("#1A70E0"), 1.15),
    "fam_magenta": (lin("#FFB4D2"), lin("#F02A78"), 1.15),
    "joint_orange": (lin("#FFB060"), lin("#E04808"), 1.2),
    "vert_cloche": (lin("#C8FF9A"), lin("#20A030"), 1.0),
    "violet_cristal": (lin("#F0C8FF"), lin("#8028E0"), 1.0),
    "cyan_levite": (lin("#C8FAFF"), lin("#10A8D8"), 1.2),
    "rose_tore": (lin("#FFB0F0"), lin("#E020B0"), 1.2),
    "rouge_laser": (lin("#FFB090"), lin("#E01808"), 1.3),
    "faisceau": (lin("#FF2A18"), lin("#A00404"), 1.0),
    "quartz2": (lin("#7FE8FF"), lin("#1878B0"), 0.95),
    "lilas_yag": (lin("#F4C0FF"), lin("#5A1488"), 1.05),
    "quartz": (lin("#D8FAFF"), lin("#38A8D8"), 0.9),
    "vitrail": (lin("#E08A20"), lin("#5A1E02"), 0.6),
    "or_halo": (lin("#FFF0B0"), lin("#E0A020"), 1.0),
})


def peint(famille):
    return "peint_" + famille


def lum(famille):
    return "fam_" + famille
