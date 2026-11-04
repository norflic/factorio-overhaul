"""Matières des icônes de la chaîne du calcul, Python pur (lu dans Blender).

Couleurs d'âge de docs/DESIGN_EPOQUES.md §5 (hex sRGB convertis en linéaire) ; couleurs de fonction des puces reprises
du lot CALC-ICONES-A (logique ambre, DRAM vert d'eau, SRAM violet), NAND corail ajoutée pour la v2.

Clés d'une matière : rgb linéaire ; rough ; met ; grain, gs (échelle du grain) ; creux (occlusion), arete (usure claire
des arêtes), bosse (ondulation de surface) ; plat = sans grain ni occlusion ; emis = lumineuse (voir mat_lum).
"""


def lin(h):
    """'#RRGGBB' sRGB -> rgb linéaire."""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def _f(rgb, f):
    return tuple(v * f for v in rgb)


MAT = {
    # âge 10
    "carenage_clair": dict(rgb=lin("#B4B9C0"), rough=0.32, met=0.25, grain=0.07, creux=0.75, arete=0.7, bosse=0.10),
    "carenage_sombre": dict(rgb=lin("#6A6E76"), rough=0.34, met=0.35, grain=0.08, creux=0.7, arete=0.8, bosse=0.08),
    "noir_mat": dict(rgb=lin("#2A2C31"), rough=0.40, met=0.2, grain=0.10, creux=0.5, arete=1.0, bosse=0.06),
    # âge 11
    "alliage_blanc": dict(rgb=lin("#C9C6BE"), rough=0.30, met=0.2, grain=0.05, creux=0.75, arete=0.45, bosse=0.08),
    "titane": dict(rgb=lin("#8E9AA6"), rough=0.26, met=0.55, grain=0.09, creux=0.65, arete=0.8, bosse=0.12),
    "titane_sombre": dict(rgb=_f(lin("#8E9AA6"), 0.30), rough=0.32, met=0.5, grain=0.08, creux=0.5, arete=1.2, bosse=0.08),
    # âge 13
    "ceramique": dict(rgb=lin("#C4C1B8"), rough=0.24, met=0.0, grain=0.03, creux=0.8, arete=0.25, bosse=0.05),
    "cuivre": dict(rgb=lin("#C8764A"), rough=0.26, met=1.0, grain=0.09, creux=0.65, arete=0.7, bosse=0.12),
    "saphir": dict(rgb=(0.012, 0.03, 0.14), rough=0.08, met=0.3, grain=0.02, creux=0.3, arete=0.8, bosse=0.03),
    # électronique
    "pcb": dict(rgb=(0.006, 0.040, 0.24), rough=0.30, met=0.15, grain=0.12, creux=0.5, arete=0.8, bosse=0.03),
    "pcb_vert": dict(rgb=(0.006, 0.17, 0.035), rough=0.30, met=0.15, grain=0.12, creux=0.5, arete=0.8, bosse=0.03),
    "puce_noire": dict(rgb=(0.012, 0.012, 0.015), rough=0.28, met=0.3, grain=0.08, creux=0.3, arete=1.6, bosse=0.03),
    "silicium": dict(rgb=(0.016, 0.025, 0.06), rough=0.10, met=0.75, grain=0.03, creux=0.3, arete=1.2, bosse=0.03),
    "silicium_lingot": dict(rgb=(0.46, 0.49, 0.57), rough=0.24, met=0.8, grain=0.06, creux=0.3, arete=0.3, bosse=0.16),
    "silicium_poli": dict(rgb=(0.42, 0.50, 0.70), rough=0.10, met=0.45, grain=0.02, creux=0.2, arete=0.3, bosse=0.05),
    "marquage": dict(rgb=(0.34, 0.35, 0.36), rough=0.7, met=0.0, plat=True),
    "etiquette": dict(rgb=(0.55, 0.55, 0.50), rough=0.75, met=0.0, plat=True),
    "or": dict(rgb=(0.95, 0.56, 0.13), rough=0.20, met=1.0, grain=0.06, creux=0.45, arete=0.5, bosse=0.06),
    "or_sombre": dict(rgb=(0.56, 0.29, 0.06), rough=0.28, met=1.0, grain=0.07, creux=0.5, arete=0.8, bosse=0.06),
    "condensateur": dict(rgb=(0.02, 0.04, 0.09), rough=0.22, met=0.7, grain=0.04, creux=0.4, arete=1.0, bosse=0.03),
    "alu_brosse": dict(rgb=(0.60, 0.62, 0.66), rough=0.26, met=0.8, grain=0.12, gs=120.0, creux=0.85, arete=0.5, bosse=0.10),
    "alu_sombre": dict(rgb=(0.26, 0.28, 0.31), rough=0.30, met=0.7, grain=0.10, gs=120.0, creux=0.7, arete=0.8, bosse=0.08),
    "vis": dict(rgb=(0.62, 0.63, 0.66), rough=0.20, met=1.0, grain=0.04, creux=0.4, arete=0.4, bosse=0.03),
    "fond_noir": dict(rgb=(0.005, 0.005, 0.007), rough=0.7, met=0.0, plat=True),
    "pale_sombre": dict(rgb=(0.05, 0.055, 0.065), rough=0.28, met=0.6, grain=0.06, creux=0.3, arete=1.5, bosse=0.03),
    "cable_gris": dict(rgb=(0.05, 0.05, 0.055), rough=0.45, met=0.0, grain=0.05, creux=0.3, arete=0.3, bosse=0.0),
    "cable_jaune": dict(rgb=(0.85, 0.52, 0.05), rough=0.35, met=0.0, grain=0.03, creux=0.4, arete=0.2, bosse=0.0),
    "cable_bleu": dict(rgb=(0.03, 0.30, 0.85), rough=0.35, met=0.0, grain=0.03, creux=0.4, arete=0.2, bosse=0.0),
    "cable_rouge": dict(rgb=(0.72, 0.06, 0.04), rough=0.35, met=0.0, grain=0.03, creux=0.4, arete=0.2, bosse=0.0),
    # couleurs de fonction des puces
    "logique_clair": dict(rgb=lin("#FFC65A"), rough=0.22, met=0.85, grain=0.08, creux=0.5, arete=0.4, bosse=0.05),
    "logique": dict(rgb=lin("#D88A22"), rough=0.24, met=0.85, grain=0.08, creux=0.5, arete=0.6, bosse=0.05),
    "logique_sombre": dict(rgb=lin("#5A3008"), rough=0.30, met=0.6, grain=0.05, creux=0.3, arete=0.3, bosse=0.0),
    "dram_clair": dict(rgb=lin("#6EF0C4"), rough=0.22, met=0.75, grain=0.08, creux=0.5, arete=0.4, bosse=0.05),
    "dram": dict(rgb=lin("#1FA982"), rough=0.24, met=0.75, grain=0.08, creux=0.5, arete=0.6, bosse=0.05),
    "dram_sombre": dict(rgb=lin("#0A4436"), rough=0.30, met=0.6, grain=0.05, creux=0.3, arete=0.3, bosse=0.0),
    "sram_clair": dict(rgb=lin("#C9A2FF"), rough=0.22, met=0.75, grain=0.08, creux=0.5, arete=0.4, bosse=0.05),
    "sram": dict(rgb=lin("#8A55E8"), rough=0.24, met=0.75, grain=0.08, creux=0.5, arete=0.6, bosse=0.05),
    "sram_sombre": dict(rgb=lin("#33186E"), rough=0.28, met=0.7, grain=0.05, creux=0.4, arete=0.9, bosse=0.03),
    "nand_clair": dict(rgb=lin("#FF9A6E"), rough=0.22, met=0.75, grain=0.08, creux=0.5, arete=0.4, bosse=0.05),
    "nand": dict(rgb=lin("#D8452A"), rough=0.24, met=0.75, grain=0.08, creux=0.5, arete=0.6, bosse=0.05),
    "nand_sombre": dict(rgb=lin("#8E2612"), rough=0.30, met=0.6, grain=0.05, creux=0.3, arete=0.5, bosse=0.0),
    # roches
    "ilmenite": dict(rgb=(0.085, 0.075, 0.095), rough=0.30, met=0.85, grain=0.28, gs=24.0, creux=0.7, arete=1.2, bosse=0.20),
    "ilmenite_clair": dict(rgb=(0.19, 0.15, 0.20), rough=0.26, met=0.9, grain=0.25, gs=24.0, creux=0.7, arete=1.0, bosse=0.20),
    "regolithe": dict(rgb=(0.20, 0.18, 0.16), rough=0.75, met=0.0, grain=0.30, gs=30.0, creux=0.8, arete=0.6, bosse=0.25),
    "acier_creuset": dict(rgb=(0.10, 0.10, 0.11), rough=0.34, met=0.9, grain=0.16, creux=0.7, arete=1.0, bosse=0.14),
    "givre": dict(rgb=(0.62, 0.84, 0.95), rough=0.16, met=0.15, grain=0.08, creux=0.6, arete=0.5, bosse=0.06),
    "dewar": dict(rgb=lin("#C8D0D8"), rough=0.20, met=0.85, grain=0.05, creux=0.7, arete=0.4, bosse=0.12),
    "tuyau_froid": dict(rgb=(0.06, 0.40, 0.90), rough=0.20, met=0.7, grain=0.05, creux=0.5, arete=0.5, bosse=0.05),
    "tuyau_chaud": dict(rgb=(0.85, 0.20, 0.05), rough=0.22, met=0.7, grain=0.05, creux=0.5, arete=0.5, bosse=0.05),
    # verres
    "verre_cyan": dict(rgb=(0.25, 0.72, 0.92), rough=0.05, met=0.4, grain=0.02, creux=0.2, arete=0.6, bosse=0.04),
    "chrome_masque": dict(rgb=(0.05, 0.06, 0.075), rough=0.12, met=1.0, grain=0.03, creux=0.3, arete=1.0, bosse=0.03),
    # film de résine de la tranche insolée
    "resine_film": dict(rgb=(0.72, 0.28, 0.025), rough=0.12, met=0.25, grain=0.03, creux=0.3, arete=0.5, bosse=0.05),
    "resine_expose": dict(rgb=(0.34, 0.09, 0.012), rough=0.16, met=0.25, grain=0.03, creux=0.3, arete=0.5, bosse=0.03),
}

# Matières lumineuses (mat_lum) : coeur, bord (rgb linéaires), force. Le dégradé est obligatoire : aucune surface
# lumineuse n'est un aplat (coeur au centre vu de face, bord saturé sur le pourtour).
LUM = {
    "voyant_bleu": (lin("#60B8FF"), lin("#1060D8"), 1.15),
    "voyant_vert": (lin("#78F078"), lin("#10A028"), 1.1),
    "voyant_ambre": (lin("#FFC050"), lin("#D86C08"), 1.1),
    "voyant_teal": (lin("#70F0C8"), lin("#0CA880"), 1.05),
    "voyant_corail": (lin("#FF9070"), lin("#D83018"), 1.1),
    "ligne_bleu_blanc": (lin("#DFF2FF"), lin("#5AB0F0"), 1.15),
    "plasma": (lin("#FF70D8"), lin("#B81088"), 1.05),
    "plasma_fort": (lin("#FF90E0"), lin("#C81898"), 1.15),
    "fibre": (lin("#90E4FF"), lin("#1490D8"), 1.05),
    "fibre_pointe": (lin("#C8F4FF"), lin("#30B0F0"), 1.2),
    "cristal": (lin("#B8FAFF"), lin("#0C6C98"), 0.95),
    "foyer": (lin("#FFB040"), lin("#C83006"), 1.05),
    "masque_clair": (lin("#7CDCF4"), lin("#2484C0"), 0.72),
    "lum_uv": (lin("#E0B8FF"), lin("#7030F0"), 1.2),
    "givre_lum": (lin("#DCF8FF"), lin("#50B8E8"), 0.8),
}
