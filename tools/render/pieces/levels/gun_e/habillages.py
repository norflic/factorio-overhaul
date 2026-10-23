"""HABILLAGES D'ESSAI du kit (passe 5, deuxième temps, 23/10) : trois habillages EXTRÊMES posés sur le TÉMOIN (ep00,
variantes kS-…) pour montrer ce que les clés d'habillage changent à elles seules, sans un seul organe d'époque. Python
pur à l'import (corps n'est importé que dans arme(), dans Blender). FICHIER DU KIT.

    py -3.9 tools/render/pieces/levels/gun_e/rendre.py --kit 3 --habillage legende --apercu --samples 32 --out DIR

Ce sont des EXEMPLES COMPLETS d'habillage, pas des décisions de direction artistique : chaque constructeur écrit le
sien dans son epNN.py (HABILLAGE = dict(…) et def matieres(metal, M)), en partant de ces exemples s'il le veut.
  pionnier  bois brut et fer brut : pont de PLANCHES clouées, capots de bois et de toile, acier en fer brut rouillé ;
  fusion    céramique blanche : pont de DALLES de céramique à joints gris, capots blancs et gris, acier clair, bandes
            magenta ;
  legende   or blanc et nacre : pont de dalles de nacre à joints d'or, capots d'or blanc et de nacre, acier d'or, bord
            du pont à liseré lumineux.
"""
import types

# matières propres (couleurs LINÉAIRES ; albédos de départ, seule compte la mesure sur le rendu, F36 et F38).
# Règle de reflets inchangée (kit.REFLETS) : métallicité <= 0,5 pour les grandes masses claires (un métal pur sous ce
# soleil reste sombre, fait mesuré en pose N, passe 5).


def _pionnier(metal, M):
    metal("planche", (0.38, 0.2, 0.08), rough=0.8, met=0.0, grain=0.45, gscale=18.0, dirt=0.85, stain=0.7, sscale=6.0,
          wear=1.0, streak=0.4)
    metal("planche2", (0.29, 0.15, 0.06), rough=0.82, met=0.0, grain=0.45, gscale=18.0, dirt=0.85, stain=0.7,
          sscale=6.0, wear=1.0, streak=0.4)
    metal("poutre", (0.14, 0.08, 0.04), rough=0.85, met=0.0, grain=0.4, gscale=18.0, dirt=0.9, stain=0.6, wear=1.4)
    metal("toile", (0.34, 0.27, 0.16), rough=0.92, met=0.0, grain=0.35, gscale=40.0, dirt=0.85, stain=0.8,
          sscale=5.0, wear=0.6)
    metal("fer_brut", (0.11, 0.085, 0.066), rough=0.55, met=0.5, grain=0.35, rust=(0.24, 0.085, 0.03), ra=0.55,
          dirt=0.85, stain=0.7, sscale=5.0, wear=2.0, streak=0.4)
    metal("fer_clair", (0.24, 0.2, 0.16), rough=0.55, met=0.45, grain=0.3, rust=(0.24, 0.085, 0.03), ra=0.35,
          dirt=0.7, stain=0.4, wear=1.0, reflet="fin")
    metal("clou", (0.2, 0.17, 0.13), rough=0.55, met=0.45, grain=0.1, dirt=0.3, stain=0.0, reflet="fin")
    metal("corde", (0.38, 0.29, 0.16), rough=0.92, met=0.0, grain=0.5, gscale=60.0, dirt=0.6, stain=0.3)


def _fusion(metal, M):
    metal("ceram_bl", (0.62, 0.6, 0.56), rough=0.32, met=0.0, grain=0.08, gscale=30.0, dirt=0.35, stain=0.15,
          sscale=5.0, wear=0.3, mottle=0.12)
    metal("ceram_gr", (0.3, 0.3, 0.31), rough=0.34, met=0.1, grain=0.08, gscale=30.0, dirt=0.4, stain=0.15,
          sscale=5.0, wear=0.4)
    metal("ceram_dalle", (0.56, 0.55, 0.53), rough=0.3, met=0.0, grain=0.06, dirt=0.3, stain=0.12, sscale=5.0,
          wear=0.3)
    metal("ceram_dalle2", (0.5, 0.5, 0.49), rough=0.3, met=0.0, grain=0.06, dirt=0.3, stain=0.12, sscale=5.0,
          wear=0.3)
    metal("acier_clair", (0.36, 0.36, 0.37), rough=0.38, met=0.45, grain=0.1, dirt=0.35, stain=0.15, wear=0.5)
    metal("acier_poli", (0.52, 0.52, 0.54), rough=0.4, met=0.45, grain=0.08, dirt=0.25, stain=0.0, reflet="fin")
    metal("joint_gris", (0.12, 0.12, 0.13), rough=0.6, met=0.1, grain=0.1, dirt=0.3, stain=0.0)
    metal("magenta_sombre", (0.32, 0.05, 0.22), rough=0.38, met=0.1, grain=0.08, dirt=0.4, stain=0.15, wear=0.4)


def _legende(metal, M):
    metal("or_blanc", (0.86, 0.64, 0.3), rough=0.38, met=0.45, grain=0.06, gscale=40.0, dirt=0.25, stain=0.12,
          sscale=5.0, wear=0.5, mottle=0.1)
    metal("or_blanc_sombre", (0.6, 0.43, 0.18), rough=0.38, met=0.45, grain=0.06, gscale=40.0, dirt=0.3,
          stain=0.12, sscale=5.0, wear=0.6)
    # rivets à la valeur de la masse d'or (premier essai à (0,9 ; 0,74 ; 0,42) : 14,1 points blancs par t² sur la
    # tête E, au-dessus du repère vanilla 13,2)
    metal("or_rivet", (0.74, 0.56, 0.26), rough=0.5, met=0.4, grain=0.05, dirt=0.2, stain=0.0, reflet="fin")
    metal("nacre", (0.78, 0.76, 0.72), rough=0.28, met=0.05, grain=0.05, gscale=30.0, dirt=0.2, stain=0.1,
          sscale=5.0, wear=0.3, mottle=0.18)
    metal("nacre2", (0.7, 0.69, 0.68), rough=0.28, met=0.05, grain=0.05, gscale=30.0, dirt=0.2, stain=0.1,
          sscale=5.0, wear=0.3, mottle=0.18)
    metal("joint_or", (0.3, 0.24, 0.13), rough=0.45, met=0.3, grain=0.06, dirt=0.3, stain=0.0)


PRESETS = {
    "pionnier": dict(
        HABILLAGE=dict(capots=("planche", "toile"), acier=("fer_brut", "fer_clair"), rivets="clou",
                       danger=("corde", "poutre"), peinture="toile", tremie="planche2", tourelleau="planche2",
                       chapeau="fer_clair", jupe_cerclage="fer_brut", grille_nacelle="poutre",
                       plateforme=dict(motif="planches", mat="planche", mat2="planche2", bord="poutre",
                                       boulons="clou", relief=0.4)),
        matieres=_pionnier, FOYER=None),
    "fusion": dict(
        HABILLAGE=dict(capots=("ceram_bl", "ceram_gr"), acier=("acier_clair", "acier_poli"), rivets="acier_poli",
                       joints="joint_gris", danger=("ceram_bl", "magenta_sombre"), peinture="magenta_sombre",
                       tremie="ceram_bl", tourelleau="ceram_gr", chapeau="acier_poli", jupe_cerclage="acier_poli",
                       grille_nacelle="acier_clair",
                       plateforme=dict(motif="dalles", pas=0.3, joint=0.01, mat="ceram_dalle", mat2="ceram_dalle2",
                                       fond="joint_gris", bord="ceram_gr", boulons=None)),
        matieres=_fusion, FOYER=dict(rgb=(1.0, 0.3, 0.85))),
    "legende": dict(
        HABILLAGE=dict(capots=("or_blanc", "nacre"), acier=("or_blanc_sombre", "or_blanc"), rivets="or_rivet",
                       joints="joint_or", danger=("or_blanc", "nacre2"), peinture="or_blanc", tremie="nacre",
                       tourelleau="nacre", chapeau="or_rivet", jupe_cerclage="nacre",
                       grille_nacelle="or_blanc",
                       plateforme=dict(motif="dalles", pas=0.28, joint=0.012, mat="nacre", mat2="nacre2",
                                       fond="joint_or", bord="or_blanc", boulons=None, lisere="emit_soft")),
        matieres=_legende, FOYER=dict(rgb=(1.0, 0.9, 0.62))),
}


def temoin(nom, ep00):
    """Le témoin ep00 habillé de l'essai `nom` (espace de noms : mêmes fonctions, HABILLAGE, matieres, FOYER, et une
    arme dont la culasse, le masque et la caisse d'alimentation prennent la matière des capots)."""
    if nom not in PRESETS:
        raise KeyError("habillage d'essai inconnu : %s (%s)" % (nom, ", ".join(sorted(PRESETS))))
    p = PRESETS[nom]
    ns = types.SimpleNamespace(**{k: getattr(ep00, k) for k in dir(ep00) if not k.startswith("__")})
    ns.HABILLAGE = p["HABILLAGE"]
    ns.matieres = p["matieres"]
    if p["FOYER"]:
        ns.FOYER = p["FOYER"]
    ns.NOM = "%s (habillage %s)" % (ep00.NOM, nom)
    cap = p["HABILLAGE"]["capots"]
    cap = (cap, cap) if isinstance(cap, str) else cap

    def arme(g, c, x, sx):
        import corps
        acier = p["HABILLAGE"].get("acier")
        bague = (acier if isinstance(acier, str) else acier[0]) if acier else "steel_dk"
        corps.canon_lignee(g, c, x, sx, recv_mats=(cap[1], cap[0]), masque_mats=(cap[1], cap[0]),
                           alim_mats=(cap[0], cap[1]), bague_mat=bague)
    ns.arme = arme
    return ns
