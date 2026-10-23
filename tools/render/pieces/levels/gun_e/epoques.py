"""REGISTRE DES ÉPOQUES et CONTRAT des modules epNN.py (lot V3-E, quatrième passe, 23/10 ; habillage complet et
points d'accroche : passe 5, deuxième temps du kit, 23/10). Python pur (importable
hors Blender par les outils). FICHIER GELÉ pour les constructeurs.

Un module d'époque epNN.py (N = 2 à 15) ne remplit QUE les emplacements d'époque du catalogue (§A.2) : arme (E1),
tuyaux et grands volumes annexes (E2), accents et matières d'accent (E3, E4), foyers (E5), signatures et pièce du
niveau pair (E6). Le corps de lignée (corps.py), les matières du corps et les règles de reflets (kit.py), les formes
communes (formes.py) et les outils sont communs et gelés. Contrat :

  EPOQUE = N ; NOM = "…"
  FOYER = dict(rgb=(r, g, b) linéaire, rgb2=… facultatif (2e couleur), nuit=False, doux=dict(force=0.7, base=…))
          la couleur doit tomber, MESURÉE sur la couche glow (mesures.py), dans la famille FAMILLES[N] ;
  CANON = dict(L=…, nb=…, rb=…, rr=…)      longueur et nombre de tubes, rayon d'un tube, rayon du faisceau ;
  HABILLAGE = dict(…)                      facultatif : clés de HABILLAGE_DEFAUT (voir « HABILLAGE » ci-dessous) ;
  PLATEFORME = dict(chanfrein=…)           facultatif : chanfrein avant de la plateforme (remplissage, §A.5) ;
  def matieres(metal, M)                   facultatif : matières propres (metal(clé, couleur, …) de kit.materials) ;
  def socle(g, c)        après plateforme, colonne et trémie : grands volumes, liaisons, accents, foyers, halos ;
  def piece(g, c)        pièce du niveau pair, en paire aux coins avant (couche ajoutée au socle) ;
  def arme(g, c, x, sx)  posée sur le bras de tourillon de la lignée (x : axe du canon, sx : côté) ; RÈGLE D'OR 1 :
                         elle AJOUTE son organe à la rosette du kit (corps.rosette, corps.bouche, corps.canon_lignee),
                         elle ne la recouvre jamais ;
  def tete(g, c)         après le noyau et les deux armes : plaques, liaisons, viseurs, signature de coupole… ;
  def masque(g, c)       facultatif : remplace le masque avant de la lignée (corps.masque_lignee) ;
  def nacelle(g, c)      facultatif : organe dorsal sur la nacelle (défaut : 2 échappements, corps.echappements).
c (corps.Ctx) porte : g, M, e, ep, side, B (colonne), H (tête + CANON), T (cotes de la taille), rt, hab, et pour la
tête Pf, Nf (coupole), nac (bx, yb0, yb1, ztop, yc), tour (cx, cy, z du dessus du tourelleau).
Époque 1 (Pionnier) : le niveau 1 est la mitrailleuse vanilla ; ep01 ne fournit que piece() (niveau 2).
Époque 0 (ep00) : la LIGNÉE SEULE (témoin du kit, variantes kS-…), sans organe d'époque.
VARIANTE DE CORPS (passe 5) : corps_choix.py, UN fichier d'UNE ligne, CORPS = "A" (corps de la passe 4, défaut) ou
"B" (valeurs groupées : grandes masses plus claires, micro-contrastes resserrés ; kit.corps_b). C'est le SEUL fichier
commun que les constructeurs ont le droit de modifier ; rendre.py --corps A|B l'emporte sur lui pour un rendu (essais
du kit), et la variante utilisée est écrite dans render.json et spec.json de chaque sprite.
HABILLAGE (passe 5, consigne du Directeur Créatif du 23/10 : d'un âge à l'autre, la différence doit être aussi franche
qu'entre deux évolutions d'une défense de Clash of Clans). Une époque change la MATIÈRE et le MOTIF de TOUT le corps de
lignée depuis son seul fichier, SANS toucher à la géométrie commune (mêmes pièces, mêmes sommets, même précision ;
seule la clé « plateforme » redessine le MOTIF du pont, à la même précision) :
HABILLAGE = dict(clé=valeur, …) dans epNN.py, et ses matières propres dans def matieres(metal, M). Toute clé absente ou
None laisse la lignée telle quelle (contrôle de construction : construction.py, empreinte identique). Une valeur
nomme une matière de kit.materials (lignée, bibliothèque d'accents) ou de ep.matieres ; une matière inconnue est une
erreur au chargement (KeyError). Les cibles se lisent dans la palette d'ORIGINE : jamais de remplacement en chaîne.
Où s'applique l'habillage : aux pièces de la LIGNÉE (plateforme, dalle, colonne, couronne dentée, trémie et goulotte,
collier, jupe, coupole, masque de lignée, nacelle, échappements, tourelleau, trappe, bras de tourillon) ; corps.habille
met g.M sur la palette habillée (c.Mh) le temps de les dessiner. NE s'applique PAS : au canon (canon_lignee, rosette,
bouche, moteur ; l'époque passe recv_mats, masque_mats, alim_mats, bague_mat à canon_lignee si elle veut sa matière)
ni à ce que l'époque dessine (socle, piece, arme, tete, masque et nacelle d'époque) : pour poser un organe dans la
matière de son corps, l'époque lit corps.mat(c, "steel_dk"), corps.capot(c, "olive"), etc.
Clés de MATIÈRE (valeur simple : tout le groupe ; couple : (premier groupe, second groupe)) :
  capots     "clé" | ("clé1", "clé2") : clé1 remplace l'OLIVE (coupole, bandes olive de la jupe, fût de la colonne,
             coque de la nacelle, bras de tourillon, masque, joues de la goulotte), clé2 l'OCRE (plaques ocre de la
             nacelle et du masque ; trémie et tourelleau quand « tremie » et « tourelleau » gardent leur défaut) ;
             valeur simple : les deux. Ex. capots=("nacre", "or_blanc").
  acier      "clé" | ("sombre", "clair") : sombre remplace l'acier SOMBRE de structure (steel_dk, armor2, armor :
             collier, nervures et bourrelet de la coupole, ceinture, semelle et goussets de la colonne, couronne dentée,
             berceaux, tourillons, périscopes, nervures et porte de la trémie, maillons de la goulotte, cornières du pont
             quand « plateforme » ne dit pas « bord ») ; clair remplace l'acier CLAIR (steel, steel_hi : dents de la
             couronne, échelle, boulons, poignées, lamelles de grille) ; valeur simple : le sombre seul.
             Ex. acier=("fer_brut", "fer_clair").
  rivets     "clé" : rivets et têtes bombées de la lignée (rivet). Ex. rivets="or_rivet".
  joints     "clé" : joints et âmes sombres entre les plaques (seam : âme de la jupe, caissons, fond de la couronne,
             fond d'échelle). Ex. joints="joint_gris". Les bouches, trous et creux (void) restent noirs.
  danger     "clé" | ("clair", "sombre") : bandes de danger de la couronne dentée et de la trémie (hazy, hazk) ;
             valeur simple : les deux (bande unie). Ex. danger=("corde", "poutre").
  peinture   "clé" : peinture rouge de la colonne (redpaint). Ex. peinture="magenta_sombre".
  tremie, tourelleau, chapeau, jupe_cerclage, grille_nacelle (clés de la passe 4) : matière de cette pièce ; se lisent
             dans la palette habillée (« ochre », défaut du tourelleau, suit donc « capots »).
Clé de MOTIF du pont :
  plateforme None (caillebotis de la lignée, code d'origine) | "motif" | dict(motif=…, mat=…, mat2=…, fond=…, bord=…,
             boulons=…, lisere=…, pas=…, joint=…, relief=…) :
     motif   "caillebotis" (lames sur chant au pas de 0,09) | "planches" (planches de 0,16 t le long de x, longueurs de
             0,5 à 1 t décalées, deux clous à chaque bout) | "dalles" (dalles carrées de 0,28 t à joints fins) |
             "toles" (tôles de 0,5 t, 6 rivets chacune) ;
     mat     matière des lames, planches, dalles ou tôles (défaut "grate") ; mat2 : seconde matière tirée au hasard
             (planches ou dalles dépareillées ; défaut aucune) ;
     fond    tablier continu sous le motif, visible dans les joints (défaut "tablier", noir) ;
     bord    cornières du pourtour (défaut "steel_dk", qui suit « acier ») ;
     boulons boulons des cornières, clous des planches, rivets des tôles (défaut "steel_hi" ; None : aucun) ;
     lisere  matière LUMINEUSE d'un liseré fin sur le dessus des cornières (défaut None ; ex. "emit_soft" : âges
             lumineux) ;
     pas     pas du motif en tuiles de jeu (défauts : planches 0,16, dalles 0,28, tôles 0,5) ; joint : largeur des joints
             (unités Blender ; défauts 0,014, 0,016, 0,02) ; relief : écart d'épaisseur des pièces (0 à 1, défaut 0).
     Le tablier reste continu et les cornières restent : aucun trou possible. corps.dalle (pièce du niveau pair) suit le
     même motif. Hasard LOCAL (graine fixe) : le tirage du reste du bâtiment ne change pas.
     Ex. plateforme=dict(motif="planches", mat="planche", mat2="planche2", bord="poutre", boulons="clou", relief=0.4).
EXEMPLES COMPLETS (essais du kit sur le témoin) : habillages.py (pionnier, fusion, legende) ; rendu avec
rendre.py --kit S --habillage NOM. Règle de reflets inchangée (kit.REFLETS) ; une grande masse claire doit rester peu
métallique (métallicité <= 0,5) : un métal pur sous ce soleil reste sombre (fait mesuré en pose N, passe 5).
SUPERSTRUCTURES (passe 5) : points d'accroche et places libres par taille dans accroches.py (coins du pont, côtés de la
trémie, sommet de la coupole, couronne de la jupe) ; dans Blender, corps.accroche(c, nom) rend la place libre pour le
canon de l'époque.
POSE N (passe 5, règle d'or 7) : les tubes par défaut sont en acier nu clair (M["gun"]) ; corps.rosette éclaire la
pointe de chaque tube (pointes=…) ; corps.couronne_bouche remplace le frein en bloc de la passe 4 ; un frein d'époque
ne doit pas faire de chapeau plat plus large que le faisceau.
FORMES (passe 5, troisième temps du kit, 23/10 ; décision de l'orchestrateur après la ronde 2 : les paires qui ne sautent
pas se lisent « même forme, même socle, même plan » ; Clash of Clans change aussi la FORME de la base). Une époque
choisit, depuis son seul fichier, la FORME de quatre grandes pièces de la lignée, par quatre clés d'HABILLAGE ; la
disposition (coupole au centre, canons vers l'avant, trémie au sud), les points d'accroche et la précision restent.
Valeur : None (forme de la lignée : code d'origine, empreinte de construction IDENTIQUE, construction.py) | "nom" |
dict(forme="nom", option=…). Une forme ou une option inconnue est une erreur au chargement. Les matières des options
nomment une clé de kit.materials ou de ep.matieres, lue dans la palette HABILLÉE (elles suivent capots, acier, etc.).
Contours et hauteurs : silhouettes.py (Python pur) ; dessin : corps.py ; exemples complets : habillages.py (f_forge,
f_vapeur, f_electricite, f_legende, f_petrole, f_marais, f_titane), rendus avec rendre.py --kit S --habillage NOM.
Chaque forme a été construite aux 5 tailles (construction.py --habillages …) et rendue en aperçu (trous, ilots).
  forme_plateforme  CONTOUR, HAUTEUR et BORDS du pont (le motif du dessus reste la clé « plateforme » ; sans elle, motif
             propre à la forme) :
     "octogone"  la lignée (= None) ;
     "carre"     carré à petits pans coupés, pont mince (0,045), cornières boulonnées, GARDE-CORPS (lisses « flanc »,
                 défaut jaune de danger ; poteaux et plinthe « flanc2 ») au sud, à l'est et à l'ouest, MURET plein au nord
                 (un garde-corps au nord enfermerait le vide du sprite) ;
     "rond"      disque (en tuiles : rond à l'écran) prolongé vers la trémie, PLINTHE surélevée (0,10 à 0,16) habillée de
                 tôles rivetées verticales (« flanc », défaut capot olive), collerette rivetée (« flanc2 ») ; dessus : tôles ;
     "hexagone"  hexagone à pans avant et arrière plats, plinthe (0,07 à 0,11) à panneaux lisses, BISEAU sur le pourtour ;
                 dessus : dalles ; « lisere » : filet lumineux sur le biseau ;
     "pierre"    socle de PIERRE surélevé (0,13 à 0,23) : assises de pierre sur les faces sud (« flanc », « flanc2 »,
                 défaut stone2, stone), chaperon, CRÉNEAUX (crenaux=False : muret seul) ; dessus : dalles de pierre ;
     "gradins"   2 gradins (2×2, 3×3) ou 3 (4×4 à 6×6 ; « niveaux » pour forcer), chacun rentré de 0,14 à 0,26 et haut
                 de 0,05 à 0,10 ; flancs à panneaux (assises=True : blocs, basalte) ; arête de chaque gradin (« bord » du
                 motif) ; « lisere » : filet lumineux sur chaque arête ; crenaux=True : FLEURONS sur le dernier gradin
                 (base couronnée) ; dessus : dalles ;
     "bastions"  pont carré mince et deux TOURS D'ANGLE blindées et crénelées aux coins arrière (hauteur 0,16 à 0,30) :
                 les places coin_NO et coin_NE sont sur leur toit (z_sol) ;
     "pilotis"   plancher surélevé (0,20 à 0,36) sur PIEUX (« flanc ») à semelles, poutres de rive (« flanc2 ») ; le vide
                 sous le plancher s'ouvre vers le bas (aucun trou enfermé : JAMAIS de lisse ni d'entretoise entre les
                 pieux) ; garde_corps=True : garde-corps et muret nord ; dessus : planches.
     Options : hauteur (dessus du pont), flanc, flanc2, dessus (matière du motif), lisere (matière lumineuse), crenaux,
     garde_corps, niveaux, assises. Bords, créneaux et garde-corps s'interrompent devant la trémie et sur les carrés de la
     pièce paire (couche posée PAR-DESSUS le socle).
     CE QUI BOUGE POUR L'ÉPOQUE : sur un pont surélevé, la colonne et la trémie montent de c.dz (le haut de la colonne et
     la tête ne bougent pas ; gradins : la trémie reste au sol et sort des gradins) ; corps.collecteur monte aussi ;
     un organe d'époque posé au sol doit monter de corps.z_pont(c, x, yn) (accroches : « z_sol » de chaque place).
  forme_coupole  la coupole (repère de la tête, centrée en (0, 0, zs), dans le rayon de la jupe) :
     "dome"      la lignée (= None) ;
     "dome_bas"  dôme bas (0,7 rz) à côtes serrées, trois rangs de rivets, bouton sommital ;
     "tour"      TOUR cylindrique (0,88 R, 0,8 rz) : assises sur âme sombre, mâchicoulis, meurtrières, parapet et
                 CRÉNEAUX, toit plat (le tourelleau et la trappe s'y posent) ;
     "pyramide"  pyramide à pans plats (« pans », défaut 8 ; 1,25 rz) : tôles rivetées par pan, arêtiers, plateau, flèche ;
     "bulbe"     bulbe en oignon (1,6 rz) à côtes rivetées, bandeau, flèche à pommeau (« epi ») ;
     "cloche"    cloche de VERRE (« verre », défaut glass ; 1,35 rz) à meneaux et cerces (« mat2 »), socle riveté,
                 couronne d'isolateurs ; « lisere » : bouton lumineux ;
     "anneau"    noyau bas (0,6 R, 0,85 rz) ceint de DEUX ANNEAUX horizontaux (« mat2 », défaut acier clair) à doublure
                 lumineuse (« lisere », défaut emit_soft), brides et bras ;
     "coque"     coque lisse en super-ellipse (1,08 rz), lignes de panneaux affleurantes, VISIÈRE sombre à l'avant, AILERON
                 dorsal ; « lisere » : filet lumineux sous la visière.
     Options : hauteur (facteur de la hauteur), mat (défaut capot olive habillé), mat2 (défaut acier sombre habillé),
     pans, lisere, epi (défaut matière du « chapeau »), verre.
     CE QUI BOUGE POUR L'ÉPOQUE : c.Pf(th, ph, k) et c.Nf(th, ph) gardent leur signature (P2.applique se pose sur toute
     forme) ; une hauteur sur la coque se lit avec corps.z_coque(c, x, y) (JAMAIS la formule de l'ellipsoïde : ep08 l'a
     fait, elle ne vaut que pour "dome") ; le tourelleau descend jusqu'au point le plus bas de son pied ; la trappe suit
     la pente ; accroches : place « coupole » recalculée (aucune place au sommet d'un bulbe : la flèche y est).
  forme_jupe  la jupe sous la coupole (même hauteur, rayon extérieur <= celui de la lignée) :
     "blindee"   la lignée (= None) ; "conique" : tronc de cône à pans rivetés (col à 0,8 R) ; "colonnade" : colonnes à
     base et chapiteau devant une âme sombre (« mat », défaut capot ocre), stylobate, entablement ; "ecailles" :
     écailles rivetées en rangs décalés. Options : mat, mat2, n (nombre de pans, colonnes ou écailles par rang).
  forme_tremie  la trémie, dans la MÊME boîte (c.tremie_box ; débord de 0,03 à 0,07 au plus), sortie de bande rendue :
     "caisson"   la lignée (= None) ; "tambour" : tambour-chargeur couché vers la colonne, FACE RONDE à rayons vers la
     caméra, cercles boulonnés, berceaux, fenêtre de chargement ; "silo" : silo debout (1,3 h) à viroles, toit conique,
     échelle, caisson d'alimentation ; "entonnoir" : caisson bas à bande de danger et ENTONNOIR évasé ouvert sur les
     cartouches. Options : mat (défaut peinture de la trémie), mat2 (défaut acier sombre habillé).
CANON EFFILÉ (passe 5, troisième temps ; proposition de lignée pour la pose N) : corps.canon_lignee(…, effile=True |
dict(conv=…, frein=(début, fin) | None, guidon=…)) ou corps.canon_effile(g, x, y0, z, L, nb, rb, rr, …) : faisceau
qui CONVERGE (pointe vers la bouche), jaquette CONIQUE perforée (0,35 L au plus) à une seule bague, MANCHON À FENTES
reculé (0,64 à 0,8 L) au ras du faisceau, qui fait le collier, DERNIER CINQUIÈME des tubes nu et convergent, pointes
éclairées, GUIDON dressé. Mode d'emploi pour un canon d'époque : docstring de corps.canon_effile.
"""
import importlib
import os
import sys

# LOT K0 (23/10) : le kit commun (kit.py, parts*.py, formes.py, silhouettes.py, repere.py, habillage.py, pont.py,
# places.py, ages.py et les outils) vit dans ../commun ; ce module, importé le premier par piece.py, le met dans
# sys.path. Le dossier gun_e garde ce qui est propre à la mitrailleuse (corps.py, cotes.py, accroches.py, epNN.py,
# piece.py, rendre.py, batch_blender.py, habillages.py, profil.py, corps_choix.py).
_ICI = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.join(os.path.dirname(_ICI), "commun")
for _d in (COMMUN, _ICI):
    if _d not in sys.path:
        sys.path.insert(0, _d)
import ages  # noqa: E402
import habillage as _H  # noqa: E402

COTE = {0: None, 1: 2, 2: 2, 3: 2, 4: 3, 5: 3, 6: 3, 7: 4, 8: 4, 9: 4, 10: 5, 11: 5, 12: 5, 13: 6, 14: 6, 15: 6}
# noms, ères et familles de couleur des âges : communs à toutes les familles (commun/ages.py, lot K0 ; ère V cosmique :
# 13 Antimatière, 14 La Porte, 15 Néant)
ERE = ages.ERE
NOMS = ages.NOMS
# plage de chaque constructeur (fichiers epNN.py qu'il possède)
PLAGE_BASSE = tuple(range(1, 10))
PLAGE_HAUTE = tuple(range(10, 16))

# habillage du corps permis à une époque (accents, catalogue §A.1 « seulement l'habillage ») : nom de matière
# Lot K0 : les clés de MATIÈRE et de MOTIF de tout le corps sont COMMUNES (commun/habillage.HABILLAGE_LIGNEE) ; celles
# de la mitrailleuse (cerclages, trémie, munitions, nacelle, tourelleau, chapeau) et ses FORMES restent ici. Même
# ordre et mêmes valeurs qu'avant K0.
HABILLAGE_DEFAUT = dict(
    jupe_cerclage="brass",     # deux cerclages de la jupe
    tremie=None,               # peinture de la trémie (None : ocre de la lignée, qui suit « capots »)
    pochoirs=True,             # marquages au pochoir sur la face sud de la trémie
    munitions=None,            # (étui, balle) des bandes visibles dans la trémie (None : laiton et cuivre)
    grille_nacelle="steel",    # lamelles de la grille arrière de la nacelle (2×2 à 4×4)
    tourelleau="ochre",        # caisson du tourelleau
    chapeau="brass",           # chapeau boulonné du tourillon
    # --- MATIÈRE et MOTIF de TOUT le corps (passe 5 ; contrat « HABILLAGE » ci-dessus) : None = lignée inchangée ;
    # capots, plateforme, acier, rivets, joints, danger, peinture (commun/habillage.py ; valeurs d'un âge :
    # commun/ages.CORPS)
    **_H.HABILLAGE_LIGNEE,
    # --- FORME des grandes pièces (passe 5, troisième temps ; contrat « FORMES » ci-dessus) : None = forme de la lignée
    forme_plateforme=None,     # contour, hauteur et bords du pont
    forme_coupole=None,        # coupole
    forme_jupe=None,           # jupe sous la coupole
    forme_tremie=None,         # trémie à munitions
)

# FAMILLES DE COULEUR DES FOYERS (règle d'or 3) : COMMUNES à toutes les familles de bâtiments depuis le lot K0
# (commun/ages.py : table, mesures de la mitrailleuse validée, foyers 5 et 6 tranchés, ère V cosmique).
FAMILLES = ages.FAMILLES
_arc = ages._arc
_recouvre = ages._recouvre
compatibles = ages.compatibles
verifier_familles = ages.verifier_familles
dans_famille = ages.dans_famille


# trous enfermés VOULUS (sol visible à travers une arche, un anneau…), déclarés par l'intégrateur du kit à la demande
# d'un constructeur : {(époque, partie « socle » | « tete » | « compo »): [(x, y, rayon) en tuiles depuis le centre]}
TROUS_VOULUS = {}


def module(e):
    """Module de l'époque e (ep00 à ep15), contrôlé contre le contrat."""
    m = importlib.import_module("ep%02d" % e)
    besoin = ["NOM", "FOYER", "piece"] if e == 1 else ["NOM", "FOYER", "socle", "piece", "arme", "tete"]
    manque = [k for k in besoin if not hasattr(m, k)]
    if manque:
        raise AttributeError("ep%02d : il manque %s" % (e, ", ".join(manque)))
    return m


def habillage(ep):
    """Habillage complet de l'âge (HABILLAGE_DEFAUT complété par ep.HABILLAGE ; commun/habillage.habillage)."""
    return _H.habillage(ep, HABILLAGE_DEFAUT)


verifier_familles()
