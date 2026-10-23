"""HABILLAGE DE MATIÈRE d'un corps de lignée (lot K0, 23/10) : palette HABILLÉE (mats_habilles), zone habillée
(habille, @_lignee) et lecture des matières habillées (mat, capot, capots_mats). Sorti de gun_e/corps.py SANS changer
une ligne (corps.py réimporte ces noms). Contrat des clés : commun/LISEZMOI.md et gun_e/epoques.py (« HABILLAGE »).
Python pur (aucun appel Blender ici). Clés COMMUNES à toutes les familles : HABILLAGE_LIGNEE ci-dessous ; une famille
ajoute ses clés propres (gun_e : jupe_cerclage, tremie, munitions…) et ses formes."""

# clés d'habillage COMMUNES (matière de TOUT le corps et motif du pont) ; None = lignée inchangée. Ordre et valeurs de
# gun_e/epoques.HABILLAGE_DEFAUT (passe 5), qui les reprend.
HABILLAGE_LIGNEE = dict(
    capots=None,               # grands capots : clé, ou (remplace l'olive, remplace l'ocre)
    plateforme=None,           # pont : motif (caillebotis, planches, dalles, toles), matières, liseré
    acier=None,                # acier de structure : clé, ou (sombre, clair)
    rivets=None,               # rivets et têtes bombées de la lignée
    joints=None,               # joints et âmes sombres entre les plaques
    danger=None,               # bandes de danger : clé, ou (clair, sombre)
    peinture=None,             # peinture rouge de la colonne
)


def habillage(ep, defaut):
    """Habillage complet de l'âge : `defaut` (table de la famille, qui contient HABILLAGE_LIGNEE) complété par
    ep.HABILLAGE ; une clé inconnue de la famille est une erreur (KeyError)."""
    h = dict(defaut)
    for k, v in getattr(ep, "HABILLAGE", {}).items():
        if k not in h:
            raise KeyError("habillage inconnu : %s (permis : %s)" % (k, ", ".join(sorted(h))))
        h[k] = v
    return h


# clé d'habillage -> matières de la LIGNÉE qu'elle remplace (contrat complet en tête de epoques.py). Une valeur simple
# remplace tout le groupe ; un couple remplace (premier, second) groupe.
REMPLACE = {
    "capots": (("olive",), ("ochre",)),                       # grands capots ; défaut du second : le premier
    "acier": (("steel_dk", "armor2", "armor"), ("steel", "steel_hi")),   # défaut du second : inchangé
    "rivets": (("rivet",),),
    "joints": (("seam",),),
    "danger": (("hazy",), ("hazk",)),                          # défaut du second : le premier
    "peinture": (("redpaint",),),
}
_SECOND_SUIT = ("capots", "danger")


def mats_habilles(M, hab):
    """Palette HABILLÉE de la lignée : une copie de M où les matières des groupes de REMPLACE sont remplacées par
    celles que l'époque donne (clés d'habillage). Aucune clé donnée : rend M lui-même (aucun changement possible).
    Les cibles se lisent dans M (palette d'origine) : jamais de remplacement en chaîne."""
    rep = {}
    for cle, groupes in REMPLACE.items():
        v = hab.get(cle)
        if not v:
            continue
        vals = (v,) if isinstance(v, str) else tuple(v)
        if len(vals) > len(groupes):
            raise ValueError("habillage %s : %d valeurs pour %d groupe(s)" % (cle, len(vals), len(groupes)))
        for i, grp in enumerate(groupes):
            if i < len(vals):
                cible = vals[i]
            elif cle in _SECOND_SUIT:
                cible = vals[0]
            else:
                continue
            if cible is None:
                continue
            for src in grp:
                rep[src] = cible
    if not rep:
        return M
    manque = sorted({t for t in rep.values() if t not in M})
    if manque:
        raise KeyError("habillage : matière(s) inconnue(s) %s (kit.materials ou ep.matieres)" % ", ".join(manque))
    Mh = dict(M)
    for src, cible in rep.items():
        Mh[src] = M[cible]
    return Mh


class habille:
    """Zone de la LIGNÉE : `with habille(g, c): …` met g.M sur la palette habillée (c.Mh) le temps de dessiner une
    pièce de la lignée (plateforme, dalle, colonne, trémie, collier, jupe, coupole, masque, nacelle, échappements,
    tourelleau, bras). Le canon (canon_lignee, rosette, bouche, moteur) et tout ce que l'époque dessine restent hors
    zone (palette d'origine) ; une époque qui veut la matière habillée la lit avec mat(c, clé). Réentrant."""

    def __init__(self, g, c=None):
        c = c if c is not None else getattr(g, "ctx", None)
        self.g, self.Mh = g, (c.Mh if c is not None else None)

    def __enter__(self):
        self.old = self.g.M
        if self.Mh is not None:
            self.g.M = self.Mh
        return self.g.M

    def __exit__(self, *exc):
        self.g.M = self.old


def _lignee(f):
    """Décorateur : la fonction de lignée f(g, c, …) dessine dans la zone habillée."""
    def w(g, c, *a, **k):
        with habille(g, c):
            return f(g, c, *a, **k)
    w.__name__, w.__doc__ = f.__name__, f.__doc__
    return w


def mat(c, cle):
    """Matière HABILLÉE de la lignée pour la clé `cle` (« steel_dk », « rivet », « olive »…) : pour une époque qui
    veut poser ses organes dans la matière de son corps."""
    return c.Mh[cle]


def capot(c, cle):
    """Matière d'un GRAND CAPOT du corps de lignée. cle : « olive » (capots principaux : coupole, bandes olive de la
    jupe, fût de la colonne, coque de la nacelle, bras de tourillon, masque) ou « ochre » (capots secondaires : plaques
    ocre de la nacelle et du masque). Habillage « capots » de l'époque (epoques.HABILLAGE_DEFAUT) : None = olive et
    ocre de la lignée ; « clé » = cette matière pour les deux ; (clé1, clé2) = clé1 pour l'olive, clé2 pour l'ocre.
    Seule la MATIÈRE change : géométrie, nombre de plaques et de rivets identiques."""
    return c.Mh[cle]


def capots_mats(c, keys):
    """Liste de matières HABILLÉES pour des noms de clés (« olive » et « ochre » suivent la clé capots)."""
    return [c.Mh[k] for k in keys]
