"""Matières des icônes des MÉTAUX (lot ICONES-DISTINCTES, 11/11), Python pur. Elles s'AJOUTENT à celles du calcul
(tools/render/pieces/calcul/couleurs_calcul.py : même format, mêmes clés), pour rester dans la même palette.

Demande du DC (mandat du 10/11, 22 h 20) : tôle magnétique feuilletée à liserés d'induction cyan ; billettes de fer et de
cuivre en lingots moulés, gris acier franc contre cuivre orangé vif ; billette de tungstène en barreau dense, sombre,
texturé ; plaques de titane hexagonales biseautées, lisses, à reflets argentés.
"""
from couleurs_calcul import LUM, MAT, lin  # noqa: F401  (réexportées pour les scènes)

MAT.update({
    "mx_tole": dict(rgb=lin("#4C5566"), rough=0.22, met=0.92, grain=0.05, gs=120.0, creux=0.55, arete=1.1, bosse=0.03),
    "mx_isolant": dict(rgb=lin("#1C2230"), rough=0.40, met=0.2, grain=0.04, creux=0.4, arete=0.4, bosse=0.0),
    "mx_vis": dict(rgb=lin("#A7ADB6"), rough=0.20, met=1.0, grain=0.05, creux=0.5, arete=0.6, bosse=0.03),
    "mx_fer": dict(rgb=lin("#B6BCC6"), rough=0.30, met=1.0, grain=0.10, gs=60.0, creux=0.65, arete=0.9, bosse=0.10),
    "mx_fer_marque": dict(rgb=lin("#5C616A"), rough=0.40, met=0.9, grain=0.10, creux=0.6, arete=0.6, bosse=0.06),
    "mx_cuivre": dict(rgb=lin("#E8793A"), rough=0.22, met=1.0, grain=0.08, gs=60.0, creux=0.6, arete=0.7, bosse=0.10),
    "mx_cuivre_marque": dict(rgb=lin("#8E3A14"), rough=0.34, met=0.9, grain=0.08, creux=0.6, arete=0.5, bosse=0.06),
    "mx_tungstene": dict(rgb=lin("#3A3C43"), rough=0.48, met=0.85, grain=0.24, gs=28.0, creux=0.85, arete=1.4, bosse=0.24),
    "mx_tungstene_frette": dict(rgb=lin("#202125"), rough=0.36, met=0.9, grain=0.10, creux=0.6, arete=1.0, bosse=0.08),
    "mx_titane": dict(rgb=(0.80, 0.83, 0.88), rough=0.07, met=1.0, grain=0.02, gs=160.0, creux=0.35, arete=0.5, bosse=0.01),
    "mx_titane_bord": dict(rgb=lin("#C2CDDD"), rough=0.10, met=1.0, grain=0.02, gs=160.0, creux=0.35, arete=0.7, bosse=0.01),
})

LUM.update({
    "mx_induction": (lin("#D2FBFF"), lin("#12B6E6"), 1.45),
})
