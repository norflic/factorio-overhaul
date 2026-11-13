"""TITANS V3 (s43, 13/11, refonte du Léviathan et du Ravageur ; charte du DC : « blindage sombre iridescent, anneaux de lévitation
magnétique, cœurs et conduits à vortex cyan étincelant ; silhouette lisible, contraste fort »).

Ce que la V2 ratait (planches 0.6.96, regardées le 13/11) : blindage gris-bleu MAT presque de la valeur du sol (aucun reflet franc), et
des dizaines de conduits fins qui font un « néon filaire » : à 32 px/tuile tout se fond en un gris bruité rayé de cyan.
V3 : (1) blindage plus SOMBRE mais très SPÉCULAIRE (vernis plein, rugosité basse) et irisation plus SATURÉE (sarcelle -> violet ->
magenta) : la lumière dessine les volumes par reflets francs ; arêtes usées claires (les biseaux brillent : contraste de valeur) ;
(2) peu de lumière mais GROSSE : un ou deux cœurs à vortex par pièce, des anneaux de lévitation épais, plus de traces filaires.

Les matières communes (titans_mat.py) sont partagées par les autres titans : rien n'y est changé, on les règle ici le temps de l'appel.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
for _p in (XP, HERE):
    if _p not in sys.path:
        sys.path.insert(0, _p)
import geo as G  # noqa: E402
import titans_mat as TM  # noqa: E402

ARGENT_V3 = (0.050, 0.058, 0.082)      # #3E4351 : acier sombre bleuté (V2 : #5D6476)
ARGENT2_V3 = (0.036, 0.040, 0.058)     # #353844
ARETE_V3 = (0.62, 0.68, 0.80)          # arêtes usées : elles brillent
IRIS_V3 = ((0.10, 0.85, 0.95), (0.50, 0.30, 1.00), (1.00, 0.30, 0.85))   # sarcelle -> violet -> magenta


def matieres(S, prefix, gris=False):
    """TM.matieres avec la palette V3 (sans toucher titans_mat.py : constantes rendues après l'appel)."""
    sauve = (TM.ARGENT, TM.ARGENT2, TM.ARETE_SOMBRE, TM.IRIS, TM.iridescence, TM.SKY_GLOSSY)
    iri0 = TM.iridescence

    def iri(m, part=0.45, blend=0.4):
        return iri0(m, part=min(0.9, part * 1.35), blend=blend * 0.85)
    TM.ARGENT, TM.ARGENT2, TM.ARETE_SOMBRE, TM.IRIS, TM.iridescence = ARGENT_V3, ARGENT2_V3, ARETE_V3, IRIS_V3, iri
    try:
        M = TM.matieres(S, prefix, gris)
    finally:
        TM.ARGENT, TM.ARGENT2, TM.ARETE_SOMBRE, TM.IRIS, TM.iridescence, _ = sauve
    if not gris:
        for k, rough in (("blind", 0.16), ("blind2", 0.2), ("canon", 0.22)):
            p = M[k].node_tree.nodes["Principled BSDF"]
            p.inputs["Roughness"].default_value = rough
            p.inputs["Metallic"].default_value = 0.88
            if "Coat Weight" in p.inputs:
                p.inputs["Coat Weight"].default_value = 1.0
                p.inputs["Coat Roughness"].default_value = 0.04
    return M


def arc_section(x, r_out, ep, a0, a1, zc, n=10, y0=0.0, sy=1.0):
    """Section d'une plaque de CARAPACE en arc autour de l'axe x (angles mesurés depuis +z, de a0 à a1, rayon r_out, épaisseur ep) :
    polygone fermé (arc extérieur puis arc intérieur à rebours), biseau aux deux bords."""
    pts = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        rr = r_out if 0 < i < n else r_out - ep * 0.35
        pts.append((x, y0 + sy * rr * math.sin(a), zc + rr * math.cos(a)))
    for i in range(n, -1, -1):
        a = a0 + (a1 - a0) * i / n
        rr = r_out - ep
        pts.append((x, y0 + sy * rr * math.sin(a), zc + rr * math.cos(a)))
    return pts


def carapace(lot, mat, xa, xb, r, zc, ouv=1.75, ep=0.45, lip=1.12, n=10, sy=1.0):
    """Plaque dorsale de CARAPACE de xa (arrière) à xb (avant) : arc de ±ouv rad autour du dos, lèvre avant en saillie (lip) qui
    recouvre la plaque suivante : grande surface lisse vue du dessus, marche d'ombre nette à chaque plaque."""
    L = xb - xa
    secs = [arc_section(xa, r * 0.98, ep, -ouv, ouv, zc, n, sy=sy), arc_section(xa + 0.3 * L, r * (1 + (lip - 1) * 0.5), ep, -ouv, ouv, zc, n, sy=sy),
            arc_section(xb - 0.12 * L, r * lip, ep, -ouv * 1.02, ouv * 1.02, zc, n, sy=sy), arc_section(xb, r * (1 + (lip - 1) * 0.55), ep, -ouv, ouv, zc, n, sy=sy)]
    lot.put(mat, G.loft(secs, True, True))
