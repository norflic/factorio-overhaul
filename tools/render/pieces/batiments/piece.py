"""Pièce du pipeline : BÂTIMENTS GÉNÉRIQUES REFAITS (lot POLISSAGE-FX, 10/11, axe 3 du Mode Démon) dans la direction artistique des
titans (titans_mat : blindage argent iridescent #9FA8B8, creux sombres, conduits et cœurs cyan #19E6FF, accents magenta) : les trois
bâtiments du mod les plus visibles qui n'étaient encore que des copies vanilla teintées :
  coffre : fo-team-chest (container 1×1, le stock des compagnons : copie jaune du coffre d'acier) ;
  pylone : fo-ht-pylon (electric-pole 2×2, fil de 64 : grand poteau teinté) ; UNE direction (symétrie carrée : direction_count 1),
           points d'attache des fils calculés depuis le modèle (ANCRAGES) ;
  cuve   : fo-reduction-cell (assembling-machine 4×4, 6 MW : four électrique teinté et étiré).
Format de tools/render/README.md (PIECE + build(S, C, variant)), kit d'organes de da_energie (geo.py, organes.py recopiés), matières des
titans (tools/render/pieces/titans/titans_mat.py). Une vue, face sud vers la caméra. Images FIXES (lueurs fixes : couche glow).
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TITANS = os.path.normpath(os.path.join(HERE, "..", "titans"))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
for p in (HERE, TITANS, XP):
    if p not in sys.path:
        sys.path.insert(0, p)

# bâtiment : (prototype, type, côté en tuiles, module)
BATIMENTS = {
    "coffre": ("fo-team-chest", "container", 1, "m_coffre"),
    "pylone": ("fo-ht-pylon", "electric-pole", 2, "m_pylone"),
    "cuve": ("fo-reduction-cell", "assembling-machine", 4, "m_cuve"),
    # lot POLISSAGE-2 (10/11) : tourelles électriques encore copiées de vanilla et teintées, refaites en émetteurs à symétrie de
    # révolution (UNE direction, tête non tournante : glow pulsé) ; ANCRAGES « emetteur » = origine du faisceau ou de l'orbe
    "bastion2": ("fo-bastion-2", "electric-turret", 2, "m_bastion2"),
    "bastion3": ("fo-bastion-3", "electric-turret", 2, "m_bastion3"),
    "bastion4": ("fo-bastion-4", "electric-turret", 2, "m_bastion4"),
    "tesla": ("fo-tesla-turret", "electric-turret", 2, "m_tesla"),
    "laser_lourd": ("fo-heavy-laser-turret", "electric-turret", 3, "m_laser_lourd"),
}
MACHINES = {n: p for n, p in BATIMENTS.items()}
PIECE = {"name": "bat", "margin_px": 40,
         # éclairage : ciel spéculaire des titans (argent iridescent), soleil et appoint un peu plus forts (premier rendu : blindage
         # lu bleu nuit sur les faces sud ; les plaques verticales ne voient pas le soleil de l'ouest à 48°)
         "calib": {"LIGHT_HOLDOUT": True, "SKY_GLOSSY_FACTOR": 6.0, "SUN_STRENGTH": 2.5, "FILL_STRENGTH": 2.2, "SKY_STRENGTH": 0.14},
         "variants": {n: {"epoch": 10, "side": m[2], "dest": "batiments/" + n, "anchor_tiles": (0.0, 0.0)} for n, m in BATIMENTS.items()}}
STATIQUE = False
ANIMES = ()
# Points d'attache des fils du pylône (repère Blender), remplis par m_pylone.build ; lus par batch_blender (projection écran + ombre)
ANCRAGES = {}


def margin_px(name):
    return 40


def build(S, C, variant):
    import geo
    import organes as O
    import titans_mat as TM
    mod = importlib.import_module(BATIMENTS[variant][3])
    lot = geo.Lot(S, "bat_" + variant)
    M = TM.matieres(S, "bt_" + variant + "_")
    # alias des organes du kit (noir, acier, riv, grille) vers les matières des titans
    M.update(noir=M["struct"], acier=M["canon"], acier_clair=M["os"], riv=M["os"], grille=M["struct"])
    k = O.Kit(lot, M, seed=sum(ord(c) for c in variant))
    ANCRAGES.clear()
    anc = mod.build(S, k, M)
    if anc:
        ANCRAGES.update(anc)
    n = lot.n
    objs = lot.flush()
    TM.sans_ombre(objs)
    return {"count": {"pieces": n}, "halos": 0, "ancrages": dict(ANCRAGES)}
