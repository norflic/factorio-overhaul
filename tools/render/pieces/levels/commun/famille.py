"""PROFIL DE FAMILLE des outils communs (lot K0, 23/10). Python pur (3.9).

Les outils de contrôle et de lecture (compo.py, ilots.py, gris.py, mesures.py, dominance.py, vignettes.py, apercu.py)
ne connaissent plus la mitrailleuse : tout ce qui est propre à une famille (noms des variantes, parties, poses,
composition d'un niveau, bâtiment vanilla de référence, cibles de la charte, emprise par âge, trous voulus, variantes
d'une ronde de lecture) est dans le fichier profil.py de la famille, tools/render/pieces/levels/<famille>/profil.py.
Exemple complet : gun_e/profil.py. Mode d'emploi : commun/LISEZMOI.md.

Choix de la famille : option --famille NOM des outils, sinon variable d'environnement FO_FAMILLE, sinon « gun_e »
(comportement d'avant le lot K0). NOM est un dossier frère de commun/ (ou un chemin absolu).

CONTRAT d'un profil.py (contrôlé au chargement : un champ manquant est une erreur) :
  NOM            nom court de la famille (« gun_e ») ;        TITRE : nom lisible (« mitrailleuse ») ;
  FAMILLE_PROG   nom de la famille pour tools/da/progression.py et mesures.py (« mitrailleuse ») ;
  AGES           âges couverts (tuple, 1 à 15) ;               COTE : {âge: côté de l'emprise en tuiles} ;
  POSES          poses contrôlées (« E », « N ») ;             FENETRE_GRIS : fenêtre du test en gris, en tuiles ;
  REF_VANILLA    dict(dump=…, mesure=…) : dump vanilla du niveau 1 (compo.vanilla) et nom dans
                 docs/da/mesures_vanilla.json (dominance.py) ;
  CIBLE          {âge: (masse t², petites pièces, O, (zone lumineuse min, max))} (mesures.py ; {} : pas de cible) ;
  LUCIOLES_MAX   points blancs par t² au-delà desquels un sprite échoue (repère vanilla de la famille) ;
  PIECE_MIN      masque nouveau minimal de la pièce du niveau pair (t²) ;
  TROUS_VOULUS   {(âge, partie): [(x, y, rayon)]} (ilots.py) ;
  prefixe(e)                               préfixe des variantes de l'âge e (« e05 », témoin « k5 ») ;
  level_layers(K, out, e, pose, even, kinds)  couches d'un niveau composé (K : le module compo) ;
  variantes_seules(e)                      [(variante, partie)] contrôlées seules par ilots.py ;
  compositions(e)                          [(pose, pair)] des niveaux composés contrôlés (ilots.py, mesures.py) ;
  sprites(e)                               variantes dont mesures.py compte les points blancs ;
  est_piece_paire(e, fichier)              vrai si ce fichier de couche est la pièce du niveau pair ;
  besoin_vignette(e, pose)                 variantes nécessaires à une vignette de l'âge e (vignettes.py) ;
  niveau_vignette(e)                       niveau montré par la vignette de l'âge e ;
  ronde(e)                                 variantes à rendre pour une ronde de lecture (rendre.py --ronde).
"""
import importlib.util
import os
import sys

COMMUN = os.path.dirname(os.path.abspath(__file__))
LEVELS = os.path.dirname(COMMUN)
DEFAUT = "gun_e"
CHAMPS = ("NOM", "TITRE", "FAMILLE_PROG", "AGES", "COTE", "POSES", "FENETRE_GRIS", "REF_VANILLA", "CIBLE",
          "LUCIOLES_MAX", "PIECE_MIN", "TROUS_VOULUS", "prefixe", "level_layers", "variantes_seules", "compositions",
          "sprites", "est_piece_paire", "besoin_vignette", "niveau_vignette", "ronde")
_CACHE = {}


def dossier(nom):
    return nom if os.path.isabs(nom) else os.path.join(LEVELS, nom)


def nom_choisi(nom=None):
    return nom or os.environ.get("FO_FAMILLE", "").strip() or DEFAUT


def _norm(p):
    return os.path.normcase(os.path.normpath(os.path.abspath(p)))


def _est_famille(d):
    """Vrai si le dossier d est un dossier de FAMILLE (il a un profil.py), autre que commun/."""
    return d != _norm(COMMUN) and os.path.isfile(os.path.join(d, "profil.py"))


def _oublier_autres_familles(garder):
    """Retire de sys.modules les modules chargés depuis le dossier d'une AUTRE famille (epoques, corps, piece…), et ces
    dossiers de sys.path. Correction du lot K0 (défaut 1 de la vérification, 23/10) : compo.py charge gun_e à l'import ;
    sans ce ménage, le profil.py d'une autre famille qui fait « import epoques » recevait EN SILENCE l'epoques de la
    mitrailleuse (emprise et trous voulus faux), alors que FO_FAMILLE donnait le bon. Rend les noms retirés."""
    retires = []
    for nom, mod in sorted(list(sys.modules.items()), key=lambda kv: kv[0]):
        f = getattr(mod, "__file__", None)
        if not f:
            continue
        d = os.path.dirname(_norm(f))
        if d != garder and _est_famille(d):
            del sys.modules[nom]
            retires.append(nom)
    sys.path[:] = [p for p in sys.path if not (p and _norm(p) != garder and _est_famille(_norm(p)))]
    return retires


def charger(nom=None):
    """Module profil.py de la famille `nom` (voir nom_choisi), contrôlé contre le CONTRAT. Le choix par argument
    (--famille) et par FO_FAMILLE donnent le MÊME résultat : les modules d'une autre famille déjà importés (gun_e, chargé
    par défaut à l'import de compo.py) sont oubliés avant de charger celle-ci (test : commun/tests/test_famille.py)."""
    nom = nom_choisi(nom)
    d = dossier(nom)
    cle = _norm(d)
    if cle in _CACHE:
        _oublier_autres_familles(cle)
        if d not in sys.path:
            sys.path.insert(0, d)
        return _CACHE[cle]
    p = os.path.join(d, "profil.py")
    if not os.path.isfile(p):
        raise SystemExit("famille %s : pas de profil.py dans %s (contrat : commun/famille.py)" % (nom, d))
    _oublier_autres_familles(cle)
    _CACHE.clear()   # un seul profil vivant : ses modules (epoques…) sont ceux de sys.modules
    if d in sys.path:
        sys.path.remove(d)
    sys.path.insert(0, d)
    if COMMUN not in sys.path:
        sys.path.insert(1, COMMUN)
    spec = importlib.util.spec_from_file_location("profil_%s" % os.path.basename(d), p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    manque = [c for c in CHAMPS if not hasattr(m, c)]
    if manque:
        raise SystemExit("famille %s : profil.py incomplet, il manque %s" % (nom, ", ".join(manque)))
    # garde-fou : aucun module d'une autre famille ne doit rester chargé après le profil
    for n, mod in sorted(list(sys.modules.items()), key=lambda kv: kv[0]):
        f = getattr(mod, "__file__", None)
        if f and os.path.dirname(_norm(f)) != cle and _est_famille(os.path.dirname(_norm(f))):
            raise SystemExit("famille %s : le module %s vient d'une autre famille (%s)" % (nom, n, f))
    _CACHE[cle] = m
    return m
