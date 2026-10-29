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
    return 40 + int(64 * 1.5)


# couleur, métallicité, rouille, taches de la coque propre, par âge
COQUE = {0: ((0.5, 0.38, 0.05), 0.3, 0.2, 0.3), 1: ((0.58, 0.55, 0.42), 0.25, 0.06, 0.12),
         4: ((0.72, 0.6, 0.03), 0.2, 0.06, 0.12), 8: ((0.27, 0.46, 0.39), 0.2, 0.08, 0.12),
         15: ((0.82, 0.62, 0.3), 0.55, 0.0, 0.1),
         2: ((0.2, 0.17, 0.15), 0.5, 0.15, 0.15), 3: ((0.5, 0.33, 0.1), 0.6, 0.05, 0.12), 5: ((0.09, 0.075, 0.07), 0.3, 0.0, 0.12),
         6: ((0.5, 0.56, 0.64), 0.4, 0.0, 0.1), 7: ((0.3, 0.2, 0.4), 0.3, 0.0, 0.1), 9: ((0.27, 0.3, 0.25), 0.2, 0.04, 0.12),
         10: ((0.55, 0.58, 0.62), 0.4, 0.0, 0.08), 11: ((0.62, 0.66, 0.7), 0.6, 0.0, 0.08), 12: ((0.5, 0.7, 0.78), 0.3, 0.0, 0.08),
         13: ((0.11, 0.08, 0.17), 0.4, 0.0, 0.1), 14: ((0.66, 0.67, 0.74), 0.2, 0.0, 0.08)}


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
        # coque PROPRE (v3 propreté) : peinture unie de l'âge, patine légère et régulière, sans grandes taches
        if self.e in COQUE:
            col, met, ra, st = COQUE[self.e]
        else:
            p = ages.palette(self.e)
            dom = p.get("dominante")
            dom = dom[0] if isinstance(dom, tuple) else dom
            col = (0.4, 0.4, 0.4)
            if dom in M:
                n = M[dom].node_tree.nodes.get("Principled BSDF")
                if n is not None:
                    col = tuple(min(0.9, max(0.04, x)) for x in n.inputs["Base Color"].default_value[:3])
            met, ra, st = 0.3, 0.05, 0.12
        metal("peau_prop", col, rough=0.42, met=met, grain=0.1, gscale=40.0, rust=(0.2, 0.09, 0.04), ra=ra, dirt=0.45,
              stain=st, sscale=9.0, wear=0.7)
        # reflets moins vifs (v5) : or du Néant et acier clair du Marais
        for key in ("or_chauffe", "or_blanc_chaud", "or_vif", "steel_hi"):
            if key in M and (self.e == 15 or (self.e == 8 and key == "steel_hi")):
                pb = M[key].node_tree.nodes.get("Principled BSDF")
                if pb is not None:
                    pb.inputs["Roughness"].default_value = 0.55
                    pb.inputs["Metallic"].default_value = 0.3


def build(S, C, variant):
    import kit as K
    import vaisseau
    K.PREFIXE = PREFIXE
    v = PIECE["variants"][variant]
    e = v["epoch"]
    M = K.materials(S, e, _Ep(e))
    g = K.Geo(S, C, M, "F%02d" % e, 0.0, seed=300 + e)
    vaisseau.vaisseau(g, e)
    count = dict(g.count)
    g.flush()
    return {"count": count, "halos": len(g.halos)}
