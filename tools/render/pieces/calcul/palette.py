"""PALETTE COMMUNE des icônes de la chaîne du calcul (lot CALC-ICONES-A, 30/10). Propriétaire : CALC-ICONES-A.

CALC-ICONES-B (barrette, carte mère, carte graphique, baies, processeur quantique, technologies) RELIT ce fichier SANS le
modifier : les puces y réapparaissent (DRAM sur la barrette, puce logique et mémoire sur la carte graphique, puce à qubits
sur le processeur quantique). Une couleur changée ici change toutes les icônes des deux lots : passer par le DC.

Chaque matière : couleur sRGB (hexadécimal, comme les fiches de docs/DESIGN_EPOQUES.md), rugosité (0 miroir, 1 mat),
métallicité (0 à 1). `lin(nom)` rend la couleur en lumière LINÉAIRE (rendu), `mat(nom)` le dictionnaire complet.

Règle de lecture (même règle que les icônes des modules validées, tools/render/pieces/modules/icones.py) : chaque objet se
lit à 32 px par sa SILHOUETTE, puis par sa COULEUR DOMINANTE. Les trois puces ont chacune une couleur de fonction
(« die shot » : les blocs fonctionnels d'une puce photographiée prennent des couleurs d'interférence) :
  - puce LOGIQUE : ambre / or (FONCTION["logique"]) ;
  - puce DRAM    : vert d'eau (FONCTION["dram"]) ;
  - puce SRAM    : violet (FONCTION["sram"]).
Ces trois couleurs reprennent les teintes provisoires du lot CALCUL (1.00/0.85/0.45, 0.55/1.00/0.80, 0.85/0.60/1.00),
assombries pour tenir sur le silicium : le joueur qui connaît déjà les puces ne les perd pas.
"""

# Couleurs d'âge (docs/DESIGN_EPOQUES.md §5 ; tools/render/pieces/levels/commun/ages.py, catalogue des teintes)
AGE = {
    7: dict(lumiere="#B070FF"),                       # Cristal : violet de cristal
    10: dict(carenage="#A8ADB3", noir="#222428", lumiere="#3AA8FF"),   # Haute technologie : voyants bleus
    11: dict(alliage="#C9C6BE", titane="#8E9AA6", lumiere="#BFE6FF"),
    13: dict(ceramique="#D9D6CF", cuivre="#B0703A", plasma="#FF4FD8", coeur="#FF9A3A", lumiere="#8F4BFF"),
}

# Couleurs de FONCTION des puces : claire (blocs éclairés), moyenne, sombre (creux, canaux)
FONCTION = {
    "logique": dict(clair="#FFC65A", moyen="#D88A22", sombre="#5A3008"),
    "dram": dict(clair="#6EF0C4", moyen="#1FA982", sombre="#0A4436"),
    "sram": dict(clair="#C9A2FF", moyen="#8A55E8", sombre="#33186E"),
}

MATIERES = {
    # silicium poli (dos et bords des puces, tranche) : bleu nuit presque noir, très lisse
    "silicium": ("#141A2A", 0.12, 0.00),
    "silicium_clair": ("#2C3A5C", 0.16, 0.00),
    "silicium_bord": ("#20283A", 0.30, 0.20),
    "silicium_reflet": ("#9DB4E8", 0.0, 0.0),    # teinte du reflet du silicium poli (bleu acier)
    # anneau de scellement et plots de connexion
    "anneau": ("#8C96A8", 0.25, 0.90),
    "or": ("#E6B94C", 0.22, 1.00),
    "or_sombre": ("#7A5518", 0.35, 1.00),
    # métaux
    "cuivre": ("#D2774B", 0.28, 1.00),          # proche de icons/copper-plate.png (moyenne des pixels opaques)
    "cuivre_sombre": ("#6B3220", 0.40, 1.00),
    "aluminium": ("#C7CDD6", 0.32, 1.00),
    "aluminium_sombre": ("#5E6670", 0.40, 1.00),
    "chrome": ("#9AA3AD", 0.10, 1.00),           # chrome de l'âge 12, reflets du laser
    "tungstene": ("#3E3D42", 0.30, 0.90),        # absorbeur du photomasque (shared/content/x3.lua : « absorbeur en tungstène »)
    # verre de quartz du photomasque
    "quartz": ("#A9D6E6", 0.06, 0.00),
    "quartz_bord": ("#7CCFC4", 0.10, 0.00),
    # laser à cristal (âge 10 : carénage, noir mat ; cristal taillé de l'âge 7)
    "carenage": (AGE[10]["carenage"], 0.40, 0.20),
    "noir_mat": (AGE[10]["noir"], 0.60, 0.20),
    "cristal": ("#7FDCFF", 0.05, 0.00),
    "cristal_coeur": ("#E6FFFF", 0.05, 0.00),
    "faisceau": (AGE[10]["lumiere"], 0.0, 0.0),
    "voyant": (AGE[10]["lumiere"], 0.0, 0.0),
    # ilménite dégazée (âge 13) : boulettes frittées graphite, reflets métalliques bronze
    "ilmenite_deg": ("#5A5450", 0.45, 0.40),
    "ilmenite_reflet": ("#C2A57A", 0.25, 0.90),
    "ilmenite_pore": ("#151416", 0.80, 0.10),
    # fluides
    "resine": ("#E7901E", 0.08, 0.00),           # résine photosensible : ambre (provisoire 0.90/0.55/0.20)
    "resine_sombre": ("#6E2C06", 0.10, 0.00),
    "helium3_proton": ("#FFD98A", 0.15, 0.10),   # hélium-3 : 2 protons, or pâle (provisoire 0.95/0.95/0.60)
    "helium3_neutron": (AGE[13]["ceramique"], 0.18, 0.10),
    "plasma": (AGE[13]["plasma"], 0.0, 0.0),
}


def srgb_hex_vers_lin(h):
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def lin(nom):
    """Couleur LINÉAIRE d'une matière, d'une couleur de fonction (« logique.clair ») ou d'âge (« 10.lumiere »)."""
    if nom in MATIERES:
        return srgb_hex_vers_lin(MATIERES[nom][0])
    a, b = nom.split(".")
    if a in FONCTION:
        return srgb_hex_vers_lin(FONCTION[a][b])
    return srgb_hex_vers_lin(AGE[int(a)][b])


def mat(nom, **kw):
    h, rough, met = MATIERES[nom]
    d = dict(rgb=srgb_hex_vers_lin(h), rough=rough, met=met)
    d.update(kw)
    return d


def table():
    """Toute la palette (pour la page de contrôle et pour CALC-ICONES-B) : {nom: hex}."""
    t = {k: v[0] for k, v in MATIERES.items()}
    for f, d in FONCTION.items():
        for k, v in d.items():
            t["%s.%s" % (f, k)] = v
    for e, d in AGE.items():
        for k, v in d.items():
            t["%d.%s" % (e, k)] = v
    return t
