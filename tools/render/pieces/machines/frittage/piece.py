"""FOUR DE FRITTAGE (fo-sintering-furnace, âge 5 Volcan, 3 × 3, 600 kW) : pièce du kit machines, lot DESIGN-CALCUL
CALC-MACHINES-AMONT. Dégaze le régolithe (hélium-3) et fait l'ilménite dégazée (chaînes du titane et des
supraconducteurs). Raccords : boîtes de fluide de prototypes/superconductors.lua (fluid_box) : 1 ENTRÉE au nord en
(0, −2), 1 SORTIE au sud en (0, 2) (y de jeu vers le sud) ; tuyau et cache dessinés par le moteur (pipe_picture de
l'assembleur 2) : le corps montre une bride au droit de chacun.

Essais de silhouette (3, avant tout verdict du DC) :
  a : four tubulaire rotatif : virole inclinée sur bandages et galets, couronne dentée, hotte d'alimentation et
      cyclone à l'ouest, hotte de brûleur rougeoyante à l'est ;
  b : four à cloche : cornue verticale cerclée, couronne de brûleurs, cloche levée par un portique, condenseur
      à ailettes ;
  c : batterie de cornues : massif de briques tenu par des poutres, 2 portes rougeoyantes, barillet de gaz sur le
      dessus, cheminée de briques et petit gazomètre.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
for p in (HERE, COMMUN):
    if p not in sys.path:
        sys.path.insert(0, p)

TITRES = {"a": "A · four tubulaire rotatif", "b": "B · four à cloche", "c": "C · batterie de cornues"}
PIECE = {"name": "fritt", "margin_px": 32, "calib": {"LIGHT_HOLDOUT": True}, "light_scale": 1.0,
         "variants": {n: {"side": 3, "age": 5, "titre": TITRES[n]} for n in TITRES}}


def build(S, C, variant):
    import geo
    import palettes
    import organes
    mod = importlib.import_module("fritt_" + variant)
    lot = geo.Lot(S, "fritt_" + variant)
    M = palettes.matieres(5, S)
    k = organes.Kit(lot, M, seed=5)
    mod.build(S, k)
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n, "petites": k.petites}}
