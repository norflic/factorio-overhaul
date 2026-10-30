"""Matières des icônes d'assemblages du calcul (lot CALC-ICONES-B), Python pur (lu dans Blender et hors Blender).

Couleurs d'âge de docs/DESIGN_EPOQUES.md §5 (hex sRGB convertis en linéaire) :
  âge 10 Haute technologie : carénage gris clair #A8ADB3, noir mat #222428, voyants bleus #3AA8FF ;
  âge 11 Titane            : alliage blanc #C9C6BE, titane #8E9AA6, lignes bleu-blanc #BFE6FF ;
  âge 13 Fusion            : céramique blanche #D9D6CF, cuivre #B0703A, plasma magenta #FF4FD8 (cœur #FF9A3A).

DÉPENDANCE NON TENUE : la tâche demande de reprendre tools/render/pieces/calcul/palette.py du lot CALC-ICONES-A. Au
30/10 (début de ce lot), ce fichier N'EXISTE PAS (worktree dcalc-CALC-ICONES-A sans aucun fichier nouveau). Les valeurs
ci-dessous sont donc prises directement dans la bible ; à remplacer par palette.py dès qu'il sera validé par le DC.
"""


def lin(h):
    """'#RRGGBB' sRGB -> rgb linéaire."""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


AGE = {
    10: dict(carenage="#A8ADB3", noir="#222428", lumiere="#3AA8FF"),
    11: dict(alliage="#C9C6BE", titane="#8E9AA6", lumiere="#BFE6FF"),
    13: dict(ceramique="#D9D6CF", cuivre="#B0703A", plasma="#FF4FD8", coeur="#FF9A3A"),
}

# rgb linéaire ; rough/met ; emis = force d'émission (matière lumineuse) ; plat = sans grain
MAT = {
    # âge 10
    "carenage_clair": dict(rgb=lin(AGE[10]["carenage"]), rough=0.38, met=0.55, grain=0.05, dirt=0.30),
    "noir_mat": dict(rgb=lin(AGE[10]["noir"]), rough=0.55, met=0.3, grain=0.08),
    "voyant_bleu": dict(rgb=lin(AGE[10]["lumiere"]), emis=6.0, base=(0.02, 0.10, 0.30)),
    "vitre_sombre": dict(rgb=(0.010, 0.014, 0.022), rough=0.12, met=0.0, plat=True),
    # âge 11
    "alliage_blanc": dict(rgb=lin(AGE[11]["alliage"]), rough=0.40, met=0.35, grain=0.05, dirt=0.40),
    "titane": dict(rgb=lin(AGE[11]["titane"]), rough=0.32, met=0.85, grain=0.07, dirt=0.35),
    "titane_sombre": dict(rgb=tuple(v * 0.38 for v in lin(AGE[11]["titane"])), rough=0.40, met=0.8, grain=0.06),
    "ligne_bleu_blanc": dict(rgb=lin(AGE[11]["lumiere"]), emis=5.0, base=(0.2, 0.3, 0.4)),
    # âge 13
    "ceramique": dict(rgb=lin(AGE[13]["ceramique"]), rough=0.30, met=0.0, grain=0.03, dirt=0.30),
    "cuivre": dict(rgb=lin(AGE[13]["cuivre"]), rough=0.30, met=0.95, grain=0.06),
    "plasma": dict(rgb=lin(AGE[13]["plasma"]), emis=7.0, base=(0.3, 0.02, 0.2)),
    "plasma_halo": dict(rgb=lin(AGE[13]["plasma"]), emis=1.4, base=(0.1, 0.0, 0.06)),
    "saphir": dict(rgb=(0.10, 0.12, 0.20), rough=0.08, met=0.0, plat=True),
    # électronique commune
    "pcb": dict(rgb=(0.012, 0.036, 0.120), rough=0.40, met=0.05, grain=0.10, dirt=0.2),   # bleu nuit (âge 10)
    "puce_noire": dict(rgb=(0.011, 0.011, 0.013), rough=0.42, met=0.05, grain=0.05),
    "marquage": dict(rgb=(0.30, 0.31, 0.32), rough=0.7, met=0.0, plat=True),
    "etiquette": dict(rgb=(0.62, 0.62, 0.58), rough=0.8, met=0.0, plat=True),
    "or": dict(rgb=(1.00, 0.78, 0.36), rough=0.22, met=1.0, grain=0.04),
    "or_sombre": dict(rgb=(0.80, 0.56, 0.20), rough=0.30, met=1.0, grain=0.04),
    "composant": dict(rgb=(0.05, 0.04, 0.035), rough=0.5, met=0.1, plat=True),
    "composant_clair": dict(rgb=(0.40, 0.33, 0.22), rough=0.5, met=0.2, plat=True),
    "condensateur": dict(rgb=(0.02, 0.03, 0.06), rough=0.35, met=0.3, grain=0.04),
    "alu_brosse": dict(rgb=(0.62, 0.64, 0.67), rough=0.30, met=1.0, grain=0.10, grain_scale=120.0, dirt=0.45),
    "vis": dict(rgb=(0.55, 0.56, 0.58), rough=0.25, met=1.0, grain=0.04),
    "loquet": dict(rgb=(0.45, 0.47, 0.50), rough=0.45, met=0.2, plat=True),
    "fond_noir": dict(rgb=(0.006, 0.006, 0.008), rough=0.8, met=0.0, plat=True),
    "pale_sombre": dict(rgb=(0.025, 0.027, 0.032), rough=0.40, met=0.2, plat=True),
    "cable_gris": dict(rgb=(0.10, 0.10, 0.11), rough=0.6, met=0.0, plat=True),
}
