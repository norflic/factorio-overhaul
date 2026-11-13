"""CHARTE V3 des titans du joueur (lot s43-3d-juggernaut-sentinel, 13/11) : Juggernaut et Sentinelle refondus.

Le DC (13/11) : modèles « laids et sans retour visuel ». Charte : blindage SOMBRE IRIDESCENT, anneaux de lévitation MAGNÉTIQUE,
cœurs et conduits à vortex cyan étincelant ; silhouette lisible au zoom normal, détails mécaniques NETS, contraste FORT.

Ce qui change par rapport à titans_mat.matieres (gardé tel quel pour le Kaiju, le Léviathan et le Ravageur, d'autres lots les rendent) :
- blindage : acier de nuit (#30343F environ) très métallique et peu rugueux, IRIDESCENCE PHYSIQUE (film mince du Principled de Blender 4.2+ :
  reflets vert-or / magenta selon l'épaisseur, deux épaisseurs pour les deux tons de plaques) au lieu d'un dégradé violet plat ; arêtes
  usées en acier VIF (presque blanc) : chaque plaque se découpe par un liseré clair, c'est le « détail mécanique net » ;
- anneaux : plus de tores cyan translucides (ils noyaient le corps dans une brume cyan) : anneaux de métal poli OPAQUES dont seuls les
  flancs rasants s'allument (lueur de bord, cyan intense) ; les gorges `turq` restent les traits lumineux ;
- halos : presque invisibles de jour (7 %), la lueur de nuit vient de la couche additive ;
- conduits : un cran plus forts (ils sont le seul cyan franc sur le sombre).
Le ciel vu par les seuls rayons spéculaires est poussé (SKY_GLOSSY du module, lu par batch_titans) : un métal sombre ne vit que de ses reflets.
S'exécute DANS Blender (bpy).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
if XP not in sys.path:
    sys.path.insert(0, XP)
import mat as MT  # noqa: E402
import titans_mat as TM  # noqa: E402

NUIT = (0.075, 0.085, 0.105)          # blindage principal : acier de nuit bleuté
NUIT2 = (0.150, 0.165, 0.200)         # plaques secondaires : acier canon CLAIR (deux tons : chaque plaque se lit sur le blindage de nuit)
VIF = (0.72, 0.78, 0.88)              # arêtes usées : acier vif
CREUX = (0.010, 0.011, 0.015)
SKY_GLOSSY = 4.0
# Iridescence « huile sur acier » : sarcelle de face, bleu roi à mi-angle, violet en rasant (le film mince physique de Blender virait
# à l'olive ou au mauve uniforme sur les essais du 13/11 : rampe pilotée par l'angle, maîtrisée)
IRIS_NUIT = ((0.05, 0.42, 0.55), (0.16, 0.24, 0.85), (0.50, 0.20, 0.80))


def film(m, nm, ior=1.5):
    """Iridescence physique (film mince) sur le Principled du matériau, si la version de Blender l'a (4.2+)."""
    p = m.node_tree.nodes["Principled BSDF"]
    if "Thin Film Thickness" in p.inputs:
        p.inputs["Thin Film Thickness"].default_value = float(nm)
        p.inputs["Thin Film IOR"].default_value = float(ior)
    return m


def anneau_mag(S, name):
    """Anneau de lévitation magnétique : métal poli sombre OPAQUE, flancs rasants allumés en cyan (lueur de bord)."""
    m = S.mat_emissive(name, TM.CYAN, strength=2.4, base=(0.020, 0.030, 0.040), main_scale=0.45)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Metallic"].default_value = 0.9
    p.inputs["Roughness"].default_value = 0.16
    film(m, 300)
    TM.rim(m, 2.4, creux=0.02, blend=0.22)
    m["fo_glow_part"] = 0.8
    return m


def halo_discret(S, name):
    m = S.mat_emissive(name, TM.CYAN, strength=1.0, base=(0.02, 0.2, 0.24), main_scale=0.15)
    TM.rim(m, 1.0, creux=1.0, blend=0.5)
    return TM.translucide(m, 0.07)


def charte(S, M, prefix, gris=False):
    """Remplace dans le jeu de matières `M` (titans_mat.matieres) le blindage, le canon, la structure, les anneaux et les halos."""
    if gris:
        return M
    M["blind"] = MT.surface(prefix + "v3_blind", NUIT, rough=0.20, met=0.92, tole=(1.6, 0.9), joint=0.05, joint_l=0.022, var=0.10,
                            usure=0.62, nu=VIF, crasse=0.08, crasse_col=CREUX, relief=0.45, grain=0.0, biseau=0.04, graine=21)
    M["blind2"] = MT.surface(prefix + "v3_blind2", NUIT2, rough=0.24, met=0.90, tole=(0.8, 0.5), joint=0.05, joint_l=0.026, var=0.12,
                             usure=0.62, nu=VIF, crasse=0.08, crasse_col=CREUX, relief=0.4, grain=0.0, biseau=0.04, graine=22)
    iris, TM.IRIS = TM.IRIS, IRIS_NUIT       # rampe d'iridescence de la charte V3 (rendue après usage : Kaiju & co gardent la leur)
    try:
        TM.iridescence(M["blind"], part=0.55, blend=0.32)
        TM.iridescence(M["blind2"], part=0.65, blend=0.32)
    finally:
        TM.IRIS = iris
    M["canon"] = MT.surface(prefix + "v3_canon", (0.11, 0.12, 0.14), rough=0.22, met=0.95, tole=(0.5, 0.25), joint=0.08, joint_l=0.03,
                            var=0.08, usure=0.6, nu=VIF, crasse=0.1, crasse_col=CREUX, relief=0.7, grain=0.0, biseau=0.03, graine=25)
    M["struct"] = MT.surface(prefix + "v3_struct", (0.016, 0.017, 0.022), rough=0.38, met=0.8, usure=0.5, nu=(0.40, 0.44, 0.52),
                             crasse=0.15, crasse_col=(0.004, 0.004, 0.006), grain=0.0, biseau=0.03, graine=23)
    M["anneau"] = anneau_mag(S, prefix + "anneau_v3")
    M["halo"] = halo_discret(S, prefix + "halo_v3")
    M["conduit"] = S.mat_emissive(prefix + "conduit_v3", TM.CYAN, strength=3.8, base=(0.02, 0.30, 0.36), main_scale=0.55)
    return M
