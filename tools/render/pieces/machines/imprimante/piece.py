"""IMPRIMANTE DE CIRCUITS (fo-circuit-printer, âge 4 Pétrole, 3 × 3, 300 kW, 1 entrée de fluide) : pièce du kit
machines, lot DESIGN-CALCUL CALC-MACHINES-AMONT. Fabrique la carte imprimée (lot ÉTAIN) et la carte mère (lot CALCUL).
Raccord : boîte de fluide de prototypes/superconductors.lua (fluid_box « input », côté 3) au NORD en (0, −2) ; tuyau
et cache dessinés par le moteur (pipe_picture de l'assembleur 2) : le corps montre une tubulure au droit.

Essais de silhouette (3, avant tout verdict du DC) :
  a : ligne de gravure : bac d'attaque horizontal, convoyeur de cartes, portique d'impression ;
  b : presse de sérigraphie : portique hydraulique, cadre d'écran et raclette, cuve verticale d'encre ;
  c : four de refusion : tunnel caréné, hotte et cheminée, convoyeur d'entrée et de sortie.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
for p in (HERE, COMMUN):
    if p not in sys.path:
        sys.path.insert(0, p)

TITRES = {"a": "A · ligne de gravure", "b": "B · presse de sérigraphie", "c": "C · four de refusion"}
PIECE = {"name": "impr", "margin_px": 32, "calib": {"LIGHT_HOLDOUT": True}, "light_scale": 1.0,
         "variants": {n: {"side": 3, "age": 4, "titre": TITRES[n]} for n in TITRES}}


def build(S, C, variant):
    import geo
    import palettes
    import organes
    mod = importlib.import_module("impr_" + variant)
    lot = geo.Lot(S, "impr_" + variant)
    M = palettes.matieres(4, S)
    M.setdefault("tuyau", M["galva"])
    k = organes.Kit(lot, M, seed=4)
    mod.build(S, k)
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n, "petites": k.petites}}
