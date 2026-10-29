"""Pièce du pipeline : LA FUSÉE DE DÉPART = CENTRE DE COMMANDEMENT (lot CENTRE-FUSEE, 29/10, premier jet de concept).

Format de tools/render/README.md (PIECE + build(S, C, variant)). Variantes : `epave` (âge 0, la fusée écrasée), puis
`ageNN` (NN = 01 à 15 : la même fusée, réparée puis améliorée). Emprise de l'âge : COTE (4, 5, 6, 7, 8 par ère, comme
shared/levels/config.lua, L.footprints.command). Aucun fichier du jeu n'est touché : kit de rendu seulement.
Matières : celles du kit commun (ages.py), par âge ; foyers : ages.FOYER. Préfixe des matières Blender : « fus ».
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(HERE), "commun")
for _d in (COMMUN, HERE):
    if _d not in sys.path:
        sys.path.insert(0, _d)

PREFIXE = "fus"
COTE = {0: 4, 1: 4, 2: 4, 3: 4, 4: 5, 5: 5, 6: 5, 7: 6, 8: 6, 9: 6, 10: 7, 11: 7, 12: 7, 13: 8, 14: 8, 15: 8}


def nom(e):
    return "epave" if e == 0 else "age%02d" % e


def _variants():
    v = {}
    for e in range(0, 16):
        v[nom(e)] = {"epoch": e, "side": COTE[e], "dest": "levels/fusee_e/" + nom(e), "anchor_tiles": (0.0, 0.0)}
    return v


PIECE = {"name": "fus", "variants": _variants(), "margin_px": 40, "calib": {"LIGHT_HOLDOUT": True}}


def margin_px(name):
    return 40 + int(64 * 1.2)


class _Ep:
    """Âge pour kit.materials : foyer et matières propres de l'âge (aucun module d'âge du centre n'est importé)."""

    def __init__(self, e):
        import ages
        self.e = e
        self.FOYER = ages.FOYER[e] if e else dict(rgb=(1.0, 0.6, 0.2))

    def matieres(self, metal, M):
        import ages
        if self.e:
            ages.matieres(self.e, metal, M)


def build(S, C, variant):
    import kit as K
    import fusee
    K.PREFIXE = PREFIXE
    v = PIECE["variants"][variant]
    e = v["epoch"]
    M = K.materials(S, e, _Ep(e))
    g = K.Geo(S, C, M, "F%02d" % e, 0.0, seed=300 + e)
    fusee.fusee(g, e, v["side"])
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
