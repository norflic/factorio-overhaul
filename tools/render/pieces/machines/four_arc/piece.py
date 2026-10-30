"""FOUR À ARC (fo-arc-furnace, âge 6 Électricité, 4 × 4, 4,4 MW) : pièce du kit machines, lot DESIGN-CALCUL
CALC-MACHINES-AMONT. Fond l'ilménite dégazée (chaîne du titane). Raccord : boîte de fluide de prototypes/titanium.lua
(fluid_box « input », côté 4, une entrée) au NORD en (−0,5, −2,5) (y de jeu vers le sud) ; tuyau et cache dessinés par
le moteur (pipe_picture de l'assembleur 2) : le corps montre une bride au droit.

Essais de silhouette (3, avant tout verdict du DC) :
  a : four à arc triphasé (Héroult) : cuve bleue, voûte réfractaire, 3 électrodes de graphite sur 3 mâts à bras,
      transformateur à traversées de porcelaine, gaine de fumées, bec de coulée et poche de laitier ;
  b : four à arc sous vide (refusion du titane) : creuset à chemise d'eau, chambre à vide, tige d'électrode sous
      un haut portique, redresseur à traversées, pompes à vide ;
  c : four basculant à électrode unique : cuve sur berceaux et rails, vérins, une électrode sur bras de potence,
      maison du transformateur, poche sur chariot.
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
for p in (HERE, COMMUN):
    if p not in sys.path:
        sys.path.insert(0, p)

TITRES = {"a": "A · four triphasé à 3 électrodes", "b": "B · four à arc sous vide", "c": "C · four basculant"}
PIECE = {"name": "arc", "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True}, "light_scale": 1.0,
         "variants": {n: {"side": 4, "age": 6, "titre": TITRES[n]} for n in TITRES}}


def build(S, C, variant):
    import geo
    import palettes
    import organes
    mod = importlib.import_module("arc_" + variant)
    lot = geo.Lot(S, "arc_" + variant)
    M = palettes.matieres(6, S)
    k = organes.Kit(lot, M, seed=6)
    mod.build(S, k)
    n = lot.n
    lot.flush()
    return {"count": {"pieces": n, "petites": k.petites}}
