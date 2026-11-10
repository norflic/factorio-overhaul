"""MARQUES DES TOURELLES À MUNITIONS (lot VISUELS-DISTINCTS, 10/11, sprint final du DC) : la donnée qui les distingue vue de haut.

Constat (planche fo-logs/2026-11-10_POLISSAGE-3/planche-tourelles) : les quatre tourelles à munitions refaites par F478 partageaient le
socle octogonal argent à anneau cyan des tourelles électriques (F476) : de haut, à zoom 1, elles se confondaient. Chacune reçoit ici :
  forme  : la silhouette du socle (socle_tourelle.socle) ;
  lisere : la couleur de FONCTION (couche lueur) : liseré du gradin, bague de la sellette, bande sud, motif du toit de la tête ;
  toit   : le motif peint sur le toit de la tête tournante (tourelle_tete.toit).
Le Bastion I garde le cyan des Bastion II à IV (même lignée) et un socle carré à pans coupés, parent de l'octogone. Les tourelles
électriques ne lisent pas cette table : leur socle (forme « octo ») est inchangé.
Lue par piece.py et batch_tetes.py (matière « lisere »), feuilles.py (table « marques » de sprites.lua, mesures sur les feuilles) et
tests/batiments_test.lua (§7).
"""

MARQUES = {
    "bastion1": {"forme": "carre", "lisere": (0.098, 0.902, 1.000), "toit": "chevron", "fonction": "cinetique"},
    "lourde": {"forme": "hexa", "lisere": (1.000, 0.420, 0.030), "toit": "barres", "fonction": "rafale"},
    "canon": {"forme": "rond", "lisere": (1.000, 0.140, 0.700), "toit": "cible", "fonction": "perforant"},
    "mortier": {"forme": "etoile", "lisere": (0.600, 1.000, 0.100), "toit": "croix", "fonction": "indirect"},
    # lot MURS-ACIDE (10/11) : pulvérisateur d'acide, socle rectangulaire 2×3 à citerne (m_acide.py), vert acide entre le vert-jaune du
    # mortier (≈ 72°) et le cyan du Bastion I (≈ 182°)
    "acide": {"forme": "citerne", "lisere": (0.120, 1.000, 0.330), "toit": "vague", "fonction": "corrosif"},
    # lot MURS-2 (10/11) : murs, sans socle ni toit : seul le lisere de fonction compte (tools/render/pieces/batiments/murs.py)
    "mur_renforce": {"forme": "mur", "lisere": (0.098, 0.902, 1.000), "toit": "aucun", "fonction": "rempart"},
    "mur_blinde": {"forme": "mur", "lisere": (1.000, 0.140, 0.700), "toit": "aucun", "fonction": "rempart lourd"},
}
SUFFIXES = ("_n", "_e", "_s", "_w")      # variantes de direction d'un socle (acide_n…) : même marque que la tourelle


def marque(nom):
    """La marque d'une tourelle (None pour un bâtiment sans marque : socle octogonal d'avant)."""
    if nom in MARQUES:
        return MARQUES[nom]
    for s in SUFFIXES:
        if nom.endswith(s) and nom[:-len(s)] in MARQUES:
            return MARQUES[nom[:-len(s)]]
    return None


def matiere(S, M, prefix, nom):
    """Ajoute à M la matière émissive « lisere » de la tourelle `nom` (sa couleur de fonction) ; sans marque : rien."""
    m = marque(nom)
    if not m:
        return
    c = m["lisere"]
    M["lisere"] = S.mat_emissive(prefix + "lisere", c, strength=1.5, base=(c[0] * 0.35, c[1] * 0.35, c[2] * 0.35), main_scale=0.6)
