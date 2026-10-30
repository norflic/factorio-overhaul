"""UNITÉ CRYOGÉNIQUE (fo-cryogenic-unit, âge 12 Supraconducteurs, 5 × 5, 4 MW) : pièce du kit machines, lot
DESIGN-CALCUL CALC-MACHINES-AMONT. Format de tools/render/README.md (PIECE + build(S, C, variant)).

Raccords de fluide = ceux de la raffinerie vanilla (gardés par prototypes/superconductors.lua, keep_fluid_boxes) :
direction nord : 2 ENTRÉES au sud en (−1, 3) et (1, 3), 3 SORTIES au nord en (−2, −3), (0, −3), (2, −3) (y de jeu
vers le sud). Le dessin pose une bride sur le bord de l'emprise au droit de chacun.

Essais de silhouette (3, avant tout verdict du DC) :
  a : boîte froide (tour de distillation isolée) + cryostat à dilution + compresseurs : l'usine réelle ;
  b : batterie de 3 dewars verticaux sur un collecteur, compresseur caréné devant ;
  c : grand cryostat central ouvert sur son étage à dilution (« lustre » doré) sous un écran thermique annulaire.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
for p in (HERE, COMMUN):
    if p not in sys.path:
        sys.path.insert(0, p)

TITRES = {"a": "A · boîte froide + cryostat", "b": "B · batterie de dewars", "c": "C · grand cryostat ouvert"}
PIECE = {"name": "cryo", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True}, "light_scale": 1.0,
         "variants": {n: {"side": 5, "age": 12, "titre": TITRES[n]} for n in TITRES}}


def build(S, C, variant):
    import geo
    import palettes
    import organes
    mod = importlib.import_module("cryo_" + variant)
    lot = geo.Lot(S, "cryo_" + variant)
    M = palettes.matieres(12, S)
    k = organes.Kit(lot, M, seed=12)
    mod.build(S, k)
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n, "petites": k.petites}}
