"""KIT COMMUN de la mitrailleuse, lot V3-E, quatrième passe (23/10) : matières, teintes, règles de reflets et
accumulateur de géométrie. S'exécute DANS Blender. FICHIER GELÉ pour les constructeurs d'époque : un changement
commun se DÉCRIT dans le retour du constructeur, l'intégrateur du kit le fait.

=====================================================================================================================
RÈGLE D'OR (elle prime sur tout le reste ; consigne du Directeur Créatif confirmée le 22/10 à 17 h 20 : « Même style
et même précision, mais chaque époque a sa propre direction artistique, qui se voit d'un coup d'œil. Surtout par les
canons et les tuyaux, pas par une simple couleur. »)

  1. L'ORGANE D'ÉPOQUE S'AJOUTE AU CANON, IL NE LE RECOUVRE JAMAIS. Le faisceau de tubes (corps.rosette : tubes
     séparés, âme pleine, colliers de maintien) et sa BOUCHE (rosace sombre cerclée, pourtour éclairé) restent
     visibles de dessus, en pose E comme en pose N. Une jaquette, un carénage, une nacelle, un caisson, des bobines
     ou des anneaux d'époque se posent AUTOUR ou À CÔTÉ du faisceau : ils n'en couvrent jamais plus de la moitié
     arrière (corps.JAQUETTE_MAX = 0,5 de la longueur des tubes) et jamais la bouche. Un faisceau caché sous une
     nacelle fermée (passe 3, époque 10) ou sous des cylindres pleins (époque 6) est REFUSÉ.
  2. CE QUI PORTE L'ÂGE fait au moins UNE DEMI-TUILE au zoom 1 (0,5 t dans sa plus petite dimension vue de dessus,
     ou un groupe compact de pièces qui forme un volume de cette taille). Un détail plus petit ne compte pas comme
     identité ; il reste permis comme accent.
  3. UNE IDENTITÉ NE REPOSE JAMAIS SUR LA SEULE COULEUR. La couleur des foyers d'une époque appartient à SA famille
     (epoques.FAMILLES : teinte et saturation mesurées sur la couche glow) ; deux époques voisines n'ont jamais la
     même famille (contrôle au chargement : epoques.verifier_familles). Et la silhouette change : test gris
     (gris.py, UNE définition de FORME) au moins 25 % entre voisines de même taille.
  4. La précision ne baisse JAMAIS : taille des petites pièces constante (rivets 0,013 à 0,02 ; tôles 0,22 à 0,30 ;
     pas de rivetage 0,11 à 0,13) ; une grande époque porte PLUS de pièces, jamais de plus grosses.
  5. UNE seule règle de reflets (REFLETS ci-dessous) pour les 15 époques, et UNE seule palette de LIGNÉE (les matières
     ci-dessous ne changent jamais par époque : fin de SHINE, MET_K et EPOCH_TONE de la plage basse, qui cassaient la
     grammaire entre les époques 9 et 10). PASSE 5 (consigne du 23/10, « les designs changent vraiment beaucoup d'une
     évolution à une autre ») : une époque change la MATIÈRE de TOUT son corps, et le motif de son pont, UNIQUEMENT par
     ses CLÉS D'HABILLAGE (contrat dans epoques.py, corps.habille) et ses matières propres (ep.matieres), qui suivent
     la même règle de reflets ; jamais en modifiant les matières de la lignée.
  6. Aucune pièce qui flotte, aucun trou enfermé hors sol voulu : ilots.py est BLOQUANT (code de sortie 1).
  7. Pose N : un canon dressé ne se lit jamais comme une cheminée (passe 5, juges de la passe 4 : le frein en bloc
     « T » plat de la passe 4 se lisait encore comme un CHAPEAU de cheminée) : fût en ACIER NU CLAIR (M["gun"],
     diffusion claire : un métal pur dirigé vers le nord reste noir à la caméra), rosette de tubes séparés dont les
     POINTES sont éclairées (corps.rosette), bouche sans chapeau plat plus large que le faisceau (corps.couronne_bouche),
     culasse et caisses au pied qui débordent sur les côtés, aucune bague claire horizontale (bagues sombres).
     Troisième temps (passe 5) : en pose N, un tube dirigé vers le nord se projette EXACTEMENT comme un tube vertical
     (y et z valent 0,707 à l'écran) et sa bouche ne se voit jamais ; ce qui le sépare d'une cheminée se lit donc de
     dos : faisceau qui CONVERGE en pointe, jaquette conique, une seule bague, frein à fentes au ras du faisceau, tubes
     qui le dépassent pointes éclairées, guidon dressé (corps.canon_effile, canon_lignee(effile=True)).
=====================================================================================================================

Conventions (tools/render/README.md, CALIBRATION.md §2) : 1 unité = largeur d'une tuile ; +X est, +Y nord, +Z haut ;
origine = position de l'entité au sol ; une tuile de jeu vers le sud = 1,414 unité en Y (gy()). La tête est modélisée
canons vers +Y, dans SON repère ; ses objets reçoivent la rotation de la pose comme rotation d'objet.
N'utilise que l'API publique de tools/render/blender/fo_scene.py (S) et de tools/render/fo_calib.py (C).
"""
import math
import random

import bpy
import bmesh
from mathutils import Matrix, Vector

TAU = 2.0 * math.pi
SQ2 = math.sqrt(2.0)


def gy(t):
    """y de jeu (tuiles, vers le sud) -> Y Blender."""
    return -t * SQ2


def basis(axis):
    a = Vector(axis).normalized()
    ref = Vector((0.0, 0.0, 1.0)) if abs(a.z) < 0.9 else Vector((1.0, 0.0, 0.0))
    u = a.cross(ref).normalized()
    w = a.cross(u).normalized()
    return a, u, w


AX = {"x": (1, 0, 0), "-x": (-1, 0, 0), "y": (0, 1, 0), "-y": (0, -1, 0), "z": (0, 0, 1), "-z": (0, 0, -1)}


def axv(axis):
    return Vector(AX[axis]) if isinstance(axis, str) else Vector(axis)


# ------------------------------------------------------------------------------------------------
# Textures de surface (nœuds insérés dans les matériaux de fo_scene.mat_metal)
# ------------------------------------------------------------------------------------------------
def _insert_stain(mat, amount, scale, seed, contraste=1.0):
    """Taches basse fréquence (P2 de la charte : coulures, plaques) : la couleur de base est multipliée par
    1 ± amount selon un bruit d'échelle `scale` (coordonnées Object). contraste (variante de corps B) : resserre la
    plage du bruit lue (0,3 à 0,7 divisée par contraste autour de 0,5) : taches plus franches, même dessin."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    inp = p.inputs["Base Color"]
    if not inp.links:
        return
    src = inp.links[0].from_socket
    tc = N.new("ShaderNodeTexCoord")
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 3.0
    nz.inputs["Roughness"].default_value = 0.55
    if "W" in nz.inputs:
        nz.noise_dimensions = "4D"
        nz.inputs["W"].default_value = seed + 3.1
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.5 - 0.2 / contraste
    mr.inputs["From Max"].default_value = 0.5 + 0.2 / contraste
    mr.inputs["To Min"].default_value = 1.0 - amount * 0.85
    mr.inputs["To Max"].default_value = 1.0 + amount * 0.45
    L.new(nz.outputs["Fac"], mr.inputs["Value"])
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(src, mul.inputs[0])
    L.new(mr.outputs["Result"], mul.inputs["Scale"])
    L.new(mul.outputs["Vector"], inp)


def _insert_streaks(mat, amount, scale, seed):
    """Coulures et crasse verticales : bruit étiré en Z (coordonnées Object), multiplie la couleur par
    1 - amount au plus. Donne la variance basse fréquence (P2) des tôles vanilla sans motif de camouflage."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    inp = p.inputs["Base Color"]
    if not inp.links:
        return
    src = inp.links[0].from_socket
    tc = N.new("ShaderNodeTexCoord")
    sc = N.new("ShaderNodeVectorMath")
    sc.operation = "MULTIPLY"
    sc.inputs[1].default_value = (scale, scale, scale * 0.18)
    L.new(tc.outputs["Object"], sc.inputs[0])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.0
    nz.inputs["Detail"].default_value = 4.0
    nz.inputs["Roughness"].default_value = 0.6
    if "W" in nz.inputs:
        nz.noise_dimensions = "4D"
        nz.inputs["W"].default_value = seed + 5.7
    L.new(sc.outputs["Vector"], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.45
    mr.inputs["From Max"].default_value = 0.7
    mr.inputs["To Min"].default_value = 1.0
    mr.inputs["To Max"].default_value = 1.0 - amount
    mr.clamp = True
    L.new(nz.outputs["Fac"], mr.inputs["Value"])
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(src, mul.inputs[0])
    L.new(mr.outputs["Result"], mul.inputs["Scale"])
    L.new(mul.outputs["Vector"], inp)


def _insert_edgewear(mat, amount, dist=0.014):
    """Arêtes usées plus claires (vocabulaire vanilla : « arêtes claires », charte §4.6) : occlusion ambiante
    calculée vers l'INTÉRIEUR de l'objet (nœud AO, inside, objet seul) ; près d'une arête convexe, les rayons
    ressortent vite : 1 - AO marque l'arête sur environ `dist` unités. La couleur y est multipliée par
    1 + amount. Les plaques font au moins 0,016 d'épaisseur : leur intérieur n'est pas marqué."""
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    inp = p.inputs["Base Color"]
    if not inp.links:
        return
    src = inp.links[0].from_socket
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.inside = True
    ao.only_local = True
    ao.samples = 16
    ao.inputs["Distance"].default_value = dist
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 1.0
    mr.inputs["From Max"].default_value = 0.55
    mr.inputs["To Min"].default_value = 1.0
    mr.inputs["To Max"].default_value = 1.0 + amount
    mr.clamp = True
    L.new(ao.outputs["AO"], mr.inputs["Value"])
    mul = N.new("ShaderNodeVectorMath")
    mul.operation = "SCALE"
    L.new(src, mul.inputs[0])
    L.new(mr.outputs["Result"], mul.inputs["Scale"])
    L.new(mul.outputs["Vector"], inp)


# ------------------------------------------------------------------------------------------------
# RÈGLES DE REFLETS (une seule règle, toutes époques, corps comme accents)
# ------------------------------------------------------------------------------------------------
# CAUSE des points blancs de la passe 3 (17 à 44 par t² dans la plage basse, 4 à 30 dans la plage haute, contre
# 13,2 au vanilla, définition des juges : pixel opaque de luminance >= 200 qui dépasse la médiane 3×3 de plus de 70) :
# des REFLETS SPÉCULAIRES SATURÉS, pas du bruit d'échantillonnage. Le soleil du pipeline est ponctuel
# (fo_calib.SUN_ANGLE_DEG = 0) et la sortie est écrêtée à 1 (transformation « Standard », aucune compression des
# hautes lumières) ; sur un métal peu rugueux (0,14 à 0,22 : « reflets francs » de la passe 3, et SHINE × 0,8 à l'ère
# I), le pic de reflet d'un rivet de 1 à 2 px hr ou de l'arête haute d'un tube dépasse 1 et devient un point ou un
# pointillé blanc. Preuve (fo-logs/2026-10-23_V3E-p4/kit/exp_lucioles, mêmes têtes, 128 échantillons, rendu
# déterministe : la variante témoin redonne exactement le sprite livré) :
#   tête 2 E  : 43,6 -> 0,7 point/t² ; tête 6 E : 23,2 -> 8,0 ; tête 11 E : 29,6 -> 3,6 ; tête 15 E : 29,1 -> 2,7 ;
#   reflet p95 (C2) : 124 -> 128, 132 -> 131, 166 -> 158, 184 -> 168 (cible 165 à 200 : les reflets francs viennent
#   des surfaces larges, pas des pointes).
# Seuls les rivets plus rugueux ne suffisaient pas (tête 2 : 36,6 ; l'arête haute du fût d'acier restait un pointillé
# blanc) : la règle porte sur TOUS les métaux. Elle ne se contourne pas par époque (pas de « chrome miroir » : un
# chrome franc se fait par des facettes plus larges, pas par une rugosité plus basse).
#   tout métal (métallicité >= 0,5) : rugosité >= REFLETS["metal"] ;
#   « fin » (rivets, têtes de boulon, acier clair des arêtes et poignées) : rugosité >= REFLETS["fin"].
REFLETS = {"fin": 0.45, "metal": 0.38, "plat": 0.0}
# grain adouci des matières d'accent reprises de la plage basse (lot V3-E, catalogue §A.6 : P1 visé 4,7 à 5,0)
GRAIN_ACCENT = 0.62
# taches moyennes des matières d'accent reprises de la plage basse (P2 : plancher 16)
TACHES_ACCENT = 0.32


def corps_choisi():
    """Variante de corps : variable d'environnement FO_CORPS (« A » ou « B », posée par rendre.py --corps pour les
    comparaisons du kit), sinon corps_choix.CORPS (le fichier d'une ligne que les constructeurs ont le droit de
    modifier). Toute autre valeur est une erreur."""
    import os
    import importlib.util
    v = os.environ.get("FO_CORPS", "").strip().upper()
    if not v:
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "corps_choix.py")
        spec = importlib.util.spec_from_file_location("corps_choix", p)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        v = str(mod.CORPS).strip().upper()
    if v not in ("A", "B"):
        raise ValueError("variante de corps inconnue : %r (A ou B)" % v)
    return v


def corps_b(metal, M):
    """VARIANTE DE CORPS « B, valeurs groupées » (passe 5) : MÊME géométrie, même nombre de pièces, mêmes graines de
    bruit (grain, taches, coulures aux mêmes endroits : la précision au zoom 2 ne change pas) ; ce qui change :
      - grandes masses (olive, ocre, acier sombre, couronne, peinture rouge, blindages) plus CLAIRES (+20 à +50 %) ;
      - micro-contrastes RESSERRÉS vers la valeur de la masse qui les porte : rivets et têtes de boulon, acier clair
        des arêtes, bandes de danger, usure des arêtes (wear) moitié moins forte, grain des peintures plus doux
        (chaque petit éclat clair ou noir compte comme une « petite pièce » D3 de la charte) ;
      - caillebotis UNIFORME (lames sans grain ni taches) : ses lames deviennent des lignes continues ; joints et fond
        du caillebotis restent noirs (creux sombres P3, précision du dessin).
    But (témoin du kit) : D3 <= 45 et P2 >= 16, et laisser respirer canons et tuyaux d'époque (qui ne changent pas).
    Mesuré le 23/10 (passe 5) : D3 atteint, P2 NON (10 environ, comme A) : voir le rapport du kit."""
    rust = (0.24, 0.085, 0.03)
    G = 0.09
    SB = 5.0   # échelle des taches des grandes masses (comme A ; 3,5 et 2,6 essayés : P2 inchangé, D3 plus haut)
    KB = 1.0   # contraste des taches (comme A ; 1,5 à 2,5 essayés : P2 +1 au plus, D3 +4 à +8)
    metal("armor", (0.2, 0.168, 0.128), rough=0.36, met=0.7, grain=0.24, rust=rust, ra=0.12, dd=0.35, wear=0.8,
          mottle=0.5)
    metal("armor2", (0.11, 0.1, 0.086), rough=0.38, met=0.75, grain=0.24, rust=(0.18, 0.07, 0.03), ra=0.1, dirt=0.6,
          wear=1.0, mottle=0.45)
    metal("khaki", (0.22, 0.18, 0.105), rough=0.48, met=0.4, grain=0.24, rust=rust, ra=0.12, wear=0.7, mottle=0.5)
    metal("seam", (0.012, 0.011, 0.01), rough=0.8, met=0.2, grain=0.15, dirt=0.4, stain=0.0)
    metal("rivet", (0.28, 0.24, 0.18), rough=0.3, met=0.85, grain=0.08, dirt=0.25, stain=0.0, reflet="fin")
    metal("steel_hi", (0.34, 0.33, 0.3), rough=0.2, met=0.92, grain=0.16, gscale=44.0, rust=rust, ra=0.06,
          dirt=0.6, stain=0.25, sscale=16.0, wear=0.3, streak=0.25, reflet="fin")
    metal("hazy", (0.34, 0.225, 0.032), rough=0.5, met=0.1, grain=0.2, rust=rust, ra=0.22, dirt=0.7, stain=0.35,
          wear=0.3)
    metal("hazk", (0.085, 0.074, 0.062), rough=0.55, met=0.2, grain=0.2, dirt=0.3, stain=0.0, wear=1.2)
    metal("redpaint", (0.32, 0.09, 0.036), rough=0.4, met=0.35, grain=G, gscale=30.0, rust=(0.1, 0.05, 0.025),
          ra=0.2, dirt=0.75, stain=1.0, sscale=SB, skon=KB, wear=1.2, streak=0.6, mottle=0.6)
    masses = [
        ("ochre", (0.4, 0.245, 0.068), dict(rough=0.4, met=0.35, grain=G, gscale=30.0, rust=rust, ra=0.2, dirt=0.75,
                                            stain=1.0, sscale=SB, skon=KB, dd=0.3, wear=1.2, streak=0.7, mottle=0.6)),
        ("olive", (0.23, 0.192, 0.098), dict(rough=0.38, met=0.45, grain=G, gscale=30.0, rust=rust, ra=0.3, dirt=0.75,
                                             stain=1.0, sscale=SB, skon=KB, wear=1.4, streak=0.7, mottle=0.6)),
        ("steel_dk", (0.15, 0.142, 0.13), dict(rough=0.3, met=0.9, grain=G, gscale=36.0, rust=rust, ra=0.3, dirt=0.7,
                                               stain=0.9, sscale=SB, skon=KB, wear=1.3, streak=0.6, mottle=0.55)),
    ]
    for key, col, kw in masses:
        metal(key, col, **kw)
    # caillebotis : lames et fond UNIFORMES, sans grain, taches ni usure (même contraste lame/fond qu'en A) : chaque
    # lame reste UNE ligne continue (plus de 256 px) au lieu d'un pointillé de petites pièces (D3 : c'était la première
    # source de petites pièces du témoin, carte du 23/10)
    # Essais du 23/10 sur le témoin k3 (32 échantillons) : des taches sur le caillebotis (lames et fond, même graine)
    # montent P2 de 10 à 12 au plus, mais remontent D3 (48 à 52) et font un camouflage ; des plaques dépareillées en
    # 3 valeurs n'y changent rien (P2 10,4) ; des lames plus claires (0,2) remontent D3 (50). Retenu : caillebotis
    # uniforme, lames de la valeur de A.
    metal("grate", (0.13, 0.122, 0.11), rough=0.4, met=0.8, grain=0.05, gscale=40.0, dirt=0.35, stain=0.0)
    metal("tablier", (0.01, 0.009, 0.008), rough=0.9, met=0.0, grain=0.05, dirt=0.0, stain=0.0)


def materials(S, epoch, ep):
    """Palette de l'époque `epoch` : corps de lignée COMMUN (identique aux 15 époques), bibliothèque de matières
    d'accent (communes, chaque époque y puise), puis matières propres de l'époque (ep.matieres), et foyers
    (ep.FOYER). Couleurs LINÉAIRES ; albédos de départ, seule compte la mesure sur le rendu (F36, F38)."""
    M = {}
    k = [0]
    first = {}   # clé -> indice de sa première création (graine des bruits)

    def metal(key, col, rough=0.4, met=0.75, grain=0.38, gscale=24.0, rust=None, ra=0.0, dirt=0.85, stain=0.5,
              sscale=7.0, dd=0.3, soot=None, wear=0.0, streak=0.0, mottle=0.0, stain2=0.0, reflet="plat", tone=1.0,
              _seed_k=None, skon=1.0):
        """Crée la matière `key` (remplace une matière de même nom). reflet : « fin » pour les petites pièces
        convexes, sinon « plat » ; le plancher des métaux s'applique toujours (REFLETS) ; tone : facteur d'albédo
        (matières d'accent seulement) ; _seed_k : indice de graine imposé (variante de corps B : mêmes bruits) ; skon :
        contraste des taches (_insert_stain), 1 partout sauf dans la variante de corps B."""
        if _seed_k is None:
            k[0] += 1
            first.setdefault(key, k[0])
            kk = k[0]
        else:
            kk = _seed_k
        rough = max(rough, REFLETS[reflet])
        if met >= 0.5:
            rough = max(rough, REFLETS["metal"])
        c = tuple(min(0.9, x * tone) for x in col)
        m = S.mat_metal("gune_e%02d_%s" % (epoch, key), c, rough=rough, metallic=met, grain=grain, grain_scale=gscale,
                        rust=rust, rust_amount=ra, rust_scale=6.0, dirt=dirt, seed=float(11 * kk + epoch),
                        soot=soot, dirt_distance=dd)
        if stain:
            _insert_stain(m, stain, sscale, float(11 * kk + epoch), contraste=skon)
        if stain2:
            _insert_stain(m, stain2, 13.0, float(17 * kk + epoch + 0.5))
        if mottle:
            _insert_stain(m, mottle, 1.6, float(17 * kk + epoch + 0.5))
        if streak:
            _insert_streaks(m, streak, 14.0, float(13 * kk + epoch))
        if wear:
            _insert_edgewear(m, wear)
        m["fo_reflet"] = reflet
        M[key] = m
        return m

    def accent(key, col, grain=0.38, stain=0.5, **kw):
        """Matière d'accent de la bibliothèque (reprise de la plage basse) : grain adouci, 2e couche de taches."""
        return metal(key, col, grain=grain * GRAIN_ACCENT, stain=stain, stain2=TACHES_ACCENT if stain else 0.0, **kw)

    rust = (0.24, 0.085, 0.03)
    G = 0.11   # grain des peintures (V3-S : 0,18)
    # --- CORPS DE LIGNÉE (première passe V3-S industriel, corrections des juges : grain plus doux, taches larges)
    metal("armor", (0.15, 0.125, 0.095), rough=0.36, met=0.7, grain=0.3, rust=rust, ra=0.13, dd=0.35, wear=1.6,
          mottle=0.35)
    metal("armor2", (0.075, 0.068, 0.058), rough=0.38, met=0.75, grain=0.3, rust=(0.18, 0.07, 0.03), ra=0.11, dirt=0.7,
          wear=2.2, mottle=0.3)
    metal("khaki", (0.17, 0.14, 0.08), rough=0.48, met=0.4, grain=0.3, rust=rust, ra=0.13, wear=1.4, mottle=0.35)
    metal("seam", (0.01, 0.009, 0.008), rough=0.8, met=0.2, grain=0.2, dirt=0.4, stain=0.0)
    metal("steel", (0.2, 0.19, 0.175), rough=0.22, met=0.92, grain=0.2, gscale=40.0, rust=rust, ra=0.07, dirt=0.6,
          stain=0.25, wear=1.2)
    # PASSE 5, POSE N (règle d'or 7, deux variantes) : fût des tubes en ACIER NU CLAIR (un canon dressé sombre se
    # lisait comme une cheminée : juges de la passe 4 ; passe 4 : (0,13, 0,125, 0,118), métallicité 0,92). Métallicité
    # BASSE (0,35) : un tube dirigé vers le nord n'a aucun reflet du soleil (ouest) vers la caméra (sud) ; un métal pur
    # y reste noir, quelle que soit sa couleur (essai du 23/10, témoin k3) ; il faut une diffusion claire.
    metal("gun", (0.3, 0.29, 0.27), rough=0.42, met=0.35, grain=0.14, gscale=60.0, dirt=0.55, stain=0.18, wear=0.7)
    metal("brass", (0.8, 0.56, 0.22), rough=0.2, met=0.95, grain=0.16, gscale=50.0, rust=(0.3, 0.12, 0.05),
          ra=0.14, dirt=0.5, stain=0.15, wear=0.5)
    metal("copper", (0.62, 0.26, 0.1), rough=0.26, met=0.95, grain=0.16, rust=(0.12, 0.2, 0.12), ra=0.08, dirt=0.55,
          stain=0.2, wear=0.6)
    metal("rivet", (0.56, 0.48, 0.36), rough=0.2, met=0.92, grain=0.1, dirt=0.3, stain=0.0, reflet="fin")
    metal("hazy", (0.6, 0.38, 0.025), rough=0.5, met=0.1, grain=0.25, rust=rust, ra=0.25, dirt=0.85, stain=0.35,
          wear=0.6)
    metal("hazk", (0.025, 0.022, 0.02), rough=0.55, met=0.2, grain=0.25, dirt=0.4, stain=0.0, wear=3.0)
    metal("rubber", (0.03, 0.028, 0.026), rough=0.7, met=0.0, grain=0.12, dirt=0.3, stain=0.0)
    metal("redcable", (0.26, 0.035, 0.022), rough=0.55, met=0.0, grain=0.12, dirt=0.4, stain=0.0)
    metal("void", (0.008, 0.007, 0.006), rough=0.9, met=0.0, grain=0.1, dirt=0.0, stain=0.0)
    metal("soot", (0.05, 0.042, 0.038), rough=0.8, met=0.2, grain=0.25, dirt=0.5)
    metal("ochre", (0.33, 0.19, 0.045), rough=0.4, met=0.35, grain=G, gscale=30.0, rust=rust, ra=0.22,
          dirt=0.9, stain=0.95, sscale=5.0, dd=0.3, wear=2.6, streak=0.6, mottle=0.45)
    metal("redpaint", (0.27, 0.065, 0.025), rough=0.4, met=0.35, grain=G, gscale=30.0, rust=(0.1, 0.05, 0.025),
          ra=0.22, dirt=0.9, stain=0.95, sscale=5.0, wear=2.6, streak=0.55, mottle=0.45)
    metal("cream", (0.42, 0.35, 0.2), rough=0.38, met=0.2, grain=G, gscale=26.0, rust=(0.2, 0.09, 0.04),
          ra=0.22, dirt=0.95, stain=0.75, sscale=5.0, dd=0.35, wear=0.8, streak=0.65, mottle=0.4)
    metal("olive", (0.15, 0.125, 0.06), rough=0.38, met=0.45, grain=G, gscale=30.0, rust=rust, ra=0.36,
          dirt=0.9, stain=0.95, sscale=5.0, wear=3.0, streak=0.6, mottle=0.45)
    metal("steel_dk", (0.1, 0.094, 0.086), rough=0.3, met=0.9, grain=G, gscale=36.0, rust=rust, ra=0.36,
          dirt=0.8, stain=0.75, sscale=5.0, wear=2.8, streak=0.55, mottle=0.4)
    metal("steel_hi", (0.52, 0.5, 0.46), rough=0.15, met=0.95, grain=0.22, gscale=44.0, rust=rust, ra=0.08,
          dirt=0.75, stain=0.25, sscale=16.0, wear=0.6, streak=0.3, reflet="fin")
    metal("grate", (0.11, 0.1, 0.09), rough=0.4, met=0.8, grain=0.22, gscale=40.0, rust=rust, ra=0.25, dirt=0.6,
          stain=0.5, wear=1.5)
    metal("dial", (0.4, 0.37, 0.3), rough=0.4, met=0.0, grain=0.15, dirt=0.4, stain=0.2)
    metal("matte", (0.022, 0.021, 0.022), rough=0.62, met=0.1, grain=0.12, dirt=0.4, stain=0.2, wear=2.0)
    # tablier de la plateforme (fond sous les lames du caillebotis) : le noir « void » en variante A
    M["tablier"] = M["void"]
    if corps_choisi() == "B":
        # mêmes graines de bruit que la variante A (seules les valeurs changent)
        def metal_b(key, *a_, **kw):
            if kw.get("_seed_k") is None:
                kw["_seed_k"] = first.get(key, 900 + len(first))
            return metal(key, *a_, **kw)
        corps_b(metal_b, M)
    # --- BIBLIOTHÈQUE D'ACCENTS (≤ 15 % du corps, patinés, toujours posés sur du métal sombre ; reprise de la plage
    # basse, valeurs linéaires d'origine). Toute époque peut y puiser ; une époque qui veut une variante la crée dans
    # ep.matieres (même clé ou clé nouvelle), jamais en changeant celles-ci.
    accent("ceramique", (0.42, 0.39, 0.33), rough=0.35, met=0.0, grain=0.22, dirt=0.85, stain=0.3)
    accent("wood", (0.24, 0.13, 0.062), rough=0.75, met=0.0, grain=0.5, gscale=18.0, dirt=0.9, stain=0.8,
           sscale=6.0, wear=1.2, streak=0.5)
    accent("wood2", (0.15, 0.085, 0.04), rough=0.8, met=0.0, grain=0.5, gscale=18.0, dirt=0.9, stain=0.8,
           sscale=6.0, wear=1.2, streak=0.5)
    accent("canvas", (0.27, 0.18, 0.085), rough=0.92, met=0.0, grain=0.45, gscale=40.0, dirt=0.9, stain=0.9,
           sscale=5.0, wear=0.8)
    accent("canvas2", (0.21, 0.145, 0.07), rough=0.92, met=0.0, grain=0.45, gscale=40.0, dirt=0.9, stain=0.9,
           sscale=5.0, wear=0.8)
    accent("rawiron", (0.1, 0.08, 0.064), rough=0.5, met=0.6, grain=0.4, rust=rust, ra=0.6, dirt=0.85, stain=0.8,
           sscale=5.0, wear=2.4, streak=0.5)
    accent("blackiron", (0.056, 0.05, 0.044), rough=0.42, met=0.75, grain=0.3, rust=rust, ra=0.35, dirt=0.7,
           stain=0.6, sscale=5.0, wear=3.4, streak=0.4)
    accent("bolted", (0.13, 0.115, 0.095), rough=0.36, met=0.8, grain=0.22, rust=rust, ra=0.45, dirt=0.85, stain=0.85,
           sscale=5.0, wear=2.8, streak=0.55)
    accent("brick", (0.28, 0.095, 0.045), rough=0.88, met=0.0, grain=0.5, gscale=30.0, dirt=0.9, stain=0.85,
           sscale=5.0, wear=1.4, streak=0.5)
    accent("brick2", (0.2, 0.07, 0.036), rough=0.9, met=0.0, grain=0.5, gscale=30.0, dirt=0.9, stain=0.85,
           sscale=5.0, wear=1.4, streak=0.5)
    accent("leather", (0.085, 0.045, 0.024), rough=0.62, met=0.0, grain=0.35, gscale=40.0, dirt=0.8, stain=0.8,
           sscale=6.0, wear=2.4)
    accent("crystal", (0.15, 0.085, 0.24), rough=0.12, met=0.15, grain=0.12, gscale=20.0, dirt=0.45, stain=0.35,
           sscale=4.0, wear=1.5)
    accent("tread", (0.2, 0.19, 0.17), rough=0.45, met=0.3, grain=0.3, gscale=40.0, rust=(0.24, 0.085, 0.03), ra=0.25,
           dirt=0.85, stain=0.7, sscale=5.0, wear=1.4)
    accent("stone2", (0.16, 0.135, 0.115), rough=0.85, met=0.0, grain=0.5, gscale=26.0, dirt=0.9, stain=0.8,
           sscale=5.0, wear=2.2)
    accent("glass", (0.045, 0.075, 0.035), rough=0.06, met=0.1, grain=0.08, dirt=0.5, stain=0.4, sscale=4.0)
    accent("castiron", (0.066, 0.057, 0.05), rough=0.55, met=0.6, grain=0.35, rust=rust, ra=0.3, dirt=0.8, stain=0.6,
           sscale=5.0, wear=2.6)
    accent("copper_pol", (0.5, 0.2, 0.075), rough=0.26, met=0.95, grain=0.22, rust=(0.08, 0.13, 0.08), ra=0.18,
           dirt=0.75, stain=0.45, sscale=6.0, wear=1.8)
    accent("galva", (0.2, 0.205, 0.21), rough=0.3, met=0.85, grain=0.3, gscale=30.0, rust=rust, ra=0.2, dirt=0.8,
           stain=0.75, sscale=5.0, wear=1.6, streak=0.45)
    accent("yellowpaint", (0.3, 0.222, 0.052), rough=0.42, met=0.3, grain=0.2, gscale=30.0, rust=rust, ra=0.35,
           dirt=0.9, stain=0.95, sscale=5.0, wear=2.8, streak=0.65)
    accent("tungsten", (0.078, 0.074, 0.08), rough=0.32, met=0.9, grain=0.22, rust=(0.16, 0.06, 0.025), ra=0.3,
           dirt=0.75, stain=0.7, sscale=5.0, wear=3.6, streak=0.45)
    accent("burnrust", (0.13, 0.056, 0.03), rough=0.62, met=0.35, grain=0.3, rust=(0.05, 0.03, 0.02), ra=0.4,
           dirt=0.85, stain=0.85, sscale=5.0, wear=2.0, streak=0.5)
    accent("basalt", (0.035, 0.032, 0.03), rough=0.6, met=0.1, grain=0.45, dirt=0.6, stain=0.5, wear=3.0)
    accent("bronze", (0.26, 0.15, 0.058), rough=0.34, met=0.85, grain=0.26, gscale=36.0, rust=(0.06, 0.1, 0.065),
           ra=0.32, dirt=0.85, stain=0.6, sscale=5.0, wear=1.8, streak=0.4)
    accent("stone", (0.075, 0.056, 0.044), rough=0.85, met=0.0, grain=0.5, gscale=26.0, dirt=0.9, stain=0.8,
           sscale=5.0, wear=2.2)
    accent("verdigris", (0.085, 0.135, 0.1), rough=0.55, met=0.4, grain=0.3, rust=(0.1, 0.07, 0.04), ra=0.35,
           dirt=0.85, stain=0.8, sscale=5.0, wear=1.6, streak=0.5)
    accent("glass_dk", (0.02, 0.035, 0.02), rough=0.08, met=0.0, grain=0.1, dirt=0.4, stain=0.2)
    accent("wicker", (0.13, 0.085, 0.04), rough=0.85, met=0.0, grain=0.6, gscale=60.0, dirt=0.9, stain=0.6, wear=1.0)
    accent("lead", (0.17, 0.165, 0.155), rough=0.5, met=0.6, grain=0.28, rust=(0.12, 0.11, 0.095), ra=0.3,
           dirt=0.85, stain=0.7, sscale=5.0, wear=1.6, streak=0.5)
    accent("uranium", (0.09, 0.2, 0.04), rough=0.5, met=0.2, grain=0.2, dirt=0.5, stain=0.0)
    accent("concrete", (0.17, 0.155, 0.135), rough=0.92, met=0.0, grain=0.5, gscale=30.0, dirt=0.9, stain=0.85,
           sscale=5.0, wear=1.4, streak=0.6)
    M["accent"] = M["ceramique"]
    # --- FOYERS (couleur de la famille de l'époque, epoques.FAMILLES) : surface éteinte dans la couche principale
    # (V0b). Foyers de nuit (époque 1) : la surface garde une teinte chaude visible de jour et la lueur passe en couche
    # halo au post-traitement (rendre.py).
    F = ep.FOYER
    emit = tuple(F["rgb"])
    emit2 = tuple(F.get("rgb2") or emit)
    night = bool(F.get("nuit", False))
    base = tuple(0.42 * c for c in emit) if night else (0.01, 0.01, 0.012)
    doux = F.get("doux", {})
    M["emit"] = S.mat_emissive("gune_e%02d_emit" % epoch, emit, strength=1.0, base=base,
                               main_scale=0.0, crust=(18.0, 0.25, 1.0 + epoch))
    M["emit_soft"] = S.mat_emissive("gune_e%02d_emit_s" % epoch, emit, strength=doux.get("force", 0.7),
                                    base=tuple(doux.get("base", base)), main_scale=0.0, crust=(12.0, 0.35, 2.0 + epoch))
    M["emit2"] = S.mat_emissive("gune_e%02d_emit2" % epoch, emit2, strength=1.0, base=(0.01, 0.01, 0.012),
                                main_scale=0.0, crust=(14.0, 0.25, 3.0 + epoch))
    # voyants ambre (vocabulaire vanilla : lampes de travail), admis à toutes les époques
    M["amber"] = S.mat_emissive("gune_e%02d_amber" % epoch, (1.0, 0.45, 0.06), strength=1.0,
                                base=(0.01, 0.006, 0.003), main_scale=0.0)
    for key in ("emit", "emit_soft", "emit2", "amber"):
        p = M[key].node_tree.nodes["Principled BSDF"]
        p.inputs["Roughness"].default_value = 1.0
        if "Specular IOR Level" in p.inputs:
            p.inputs["Specular IOR Level"].default_value = 0.0
    if night:
        M["amber"] = M["emit"]
    M["_emit_rgb"] = emit
    M["_emit2_rgb"] = emit2
    # --- matières propres de l'époque (accents E4 : variantes, alias jacket/ring/trim/pipe…)
    if hasattr(ep, "matieres"):
        ep.matieres(metal, M)
    return M


# ------------------------------------------------------------------------------------------------
# Accumulateur de géométrie
# ------------------------------------------------------------------------------------------------
RIVET_K = 1.8  # espacement des rivets des plaques (reprise 22/10 : D3 au-dessus de 45 sinon)

STYLES = {
    "hard": {"bevel": 0.016, "smooth": 30.0},
    "soft": {"bevel": 0.024, "smooth": 35.0},
    "smooth": {"bevel": 0.0, "smooth": 50.0},
    "flat": {"bevel": 0.0, "smooth": None},
}


class Geo:
    def __init__(self, S, C, M, tag, rotz=0.0, seed=1):
        self.S, self.C, self.M = S, C, M
        self.tag = tag
        self.rotz = rotz
        self.data = {}
        self.stack = [Matrix.Identity(4)]
        self.rng = random.Random(seed)
        self.halos = []
        self.count = {}

    # --- repères ----------------------------------------------------------------------------------
    def push(self, loc=(0, 0, 0), rz=0.0, rx=0.0, ry=0.0):
        m = (self.stack[-1] @ Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rz, 4, "Z")
             @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X"))
        self.stack.append(m)

    def pop(self):
        self.stack.pop()

    def push_frame(self, p, nrm, xdir=None):
        """Repère local d'origine p dont l'axe z suit la normale nrm (pièces posées sur une surface courbe)."""
        a = Vector(nrm).normalized()
        if xdir is None:
            _, x, _ = basis(a)
        else:
            x = Vector(xdir)
            x = (x - a * x.dot(a))
            if x.length < 1e-6:
                _, x, _ = basis(a)
            x.normalize()
        y = a.cross(x).normalized()
        m = Matrix(((x.x, y.x, a.x, p[0]), (x.y, y.y, a.y, p[1]), (x.z, y.z, a.z, p[2]), (0, 0, 0, 1)))
        self.stack.append(self.stack[-1] @ m)

    def W(self, p):
        """Point local -> repère de la pièce (avant la rotation de pose)."""
        return self.stack[-1] @ Vector(p)

    def _add(self, mat, style, verts, faces, what="part"):
        m = self.stack[-1]
        V, F = self.data.setdefault((mat, style), ([], []))
        o = len(V)
        V.extend(tuple(m @ Vector(v)) for v in verts)
        F.extend(tuple(i + o for i in f) for f in faces)
        self.count[what] = self.count.get(what, 0) + 1

    # --- primitives -------------------------------------------------------------------------------
    def box(self, c, size, mat, style="hard", R=None, what="box"):
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
        vs = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
              (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        if R is not None:
            vs = [tuple(R @ Vector(v)) for v in vs]
        vs = [(v[0] + c[0], v[1] + c[1], v[2] + c[2]) for v in vs]
        fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self._add(mat, style, vs, fs, what)

    def hexa(self, pts8, mat, style="hard", what="hexa"):
        """Hexaèdre quelconque : 4 points du bas puis 4 du haut (même ordre)."""
        fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self._add(mat, style, [tuple(p) for p in pts8], fs, what)

    def cyl(self, c, axis, r, h, mat, n=16, r2=None, caps=True, style="smooth", phase=0.0, what="cyl"):
        a, u, w = basis(axv(axis))
        c = Vector(c)
        r2 = r if r2 is None else r2
        vs, fs = [], []
        for t, rr in ((-h / 2.0, r), (h / 2.0, r2)):
            for i in range(n):
                ang = phase + TAU * i / n
                vs.append(tuple(c + a * t + (u * math.cos(ang) + w * math.sin(ang)) * rr))
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + j, n + i))
        if caps:
            fs.append(tuple(range(n))[::-1])
            fs.append(tuple(range(n, 2 * n)))
        self._add(mat, style, vs, fs, what)

    def tube_shell(self, c, axis, r_out, r_in, h, mat, n=24, style="smooth", what="tube"):
        """Tube épais (anneau extrudé) : bagues, colliers, couronnes."""
        a, u, w = basis(axv(axis))
        c = Vector(c)
        vs, fs = [], []
        for t in (-h / 2.0, h / 2.0):
            for rr in (r_out, r_in):
                for i in range(n):
                    ang = TAU * i / n
                    vs.append(tuple(c + a * t + (u * math.cos(ang) + w * math.sin(ang)) * rr))
        # indices : bas-ext 0..n-1, bas-int n..2n-1, haut-ext 2n.., haut-int 3n..
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, 2 * n + j, 2 * n + i))              # paroi extérieure
            fs.append((n + j, n + i, 3 * n + i, 3 * n + j))      # paroi intérieure
            fs.append((2 * n + i, 2 * n + j, 3 * n + j, 3 * n + i))  # dessus
            fs.append((j, i, n + i, n + j))                      # dessous
        self._add(mat, style, vs, fs, what)

    def torus(self, c, axis, R, r, mat, n=28, m=8, style="smooth", what="torus"):
        a, u, w = basis(axv(axis))
        c = Vector(c)
        vs, fs = [], []
        for i in range(n):
            th = TAU * i / n
            d = u * math.cos(th) + w * math.sin(th)
            for j in range(m):
                ph = TAU * j / m
                vs.append(tuple(c + d * (R + r * math.cos(ph)) + a * (r * math.sin(ph))))
        for i in range(n):
            for j in range(m):
                i2, j2 = (i + 1) % n, (j + 1) % m
                fs.append((i * m + j, i2 * m + j, i2 * m + j2, i * m + j2))
        self._add(mat, style, vs, fs, what)

    def sphere(self, c, r, mat, n=24, m=12, scale=(1.0, 1.0, 1.0), style="smooth", what="sphere"):
        """Sphère (ou ellipsoïde) UV fermée."""
        c = Vector(c)
        vs, fs = [], []
        for i in range(1, m):
            ph = -math.pi / 2 + math.pi * i / m
            for j in range(n):
                th = TAU * j / n
                vs.append((c.x + r * scale[0] * math.cos(ph) * math.cos(th), c.y + r * scale[1] * math.cos(ph) * math.sin(th),
                           c.z + r * scale[2] * math.sin(ph)))
        vs.append((c.x, c.y, c.z - r * scale[2]))
        vs.append((c.x, c.y, c.z + r * scale[2]))
        bot, top = len(vs) - 2, len(vs) - 1
        for i in range(m - 2):
            for j in range(n):
                j2 = (j + 1) % n
                fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
        for j in range(n):
            j2 = (j + 1) % n
            fs.append((bot, j2, j))
            fs.append(((m - 2) * n + j, (m - 2) * n + j2, top))
        self._add(mat, style, vs, fs, what)

    def crumple(self, c, axis, r, h, mat, n=18, k=6, amp=0.012, what="feuille"):
        """Manchon froissé (feuille d'or, couverture thermique) : cylindre à facettes dont les sommets sont
        décalés au hasard ; ombrage plat (style « flat ») pour que chaque facette accroche la lumière."""
        a, u, w = basis(axv(axis))
        c = Vector(c)
        vs, fs = [], []
        for i in range(k + 1):
            t = -h / 2.0 + h * i / k
            for j in range(n):
                ang = TAU * (j + 0.5 * (i % 2)) / n
                rr = r + amp * (self.rng.random() * 2 - 1) * (0.4 if i in (0, k) else 1.0)
                vs.append(tuple(c + a * (t + amp * 0.6 * (self.rng.random() * 2 - 1) * (0 if i in (0, k) else 1))
                                + (u * math.cos(ang) + w * math.sin(ang)) * rr))
        for i in range(k):
            for j in range(n):
                j2 = (j + 1) % n
                fs.append((i * n + j, i * n + j2, (i + 1) * n + j2))
                fs.append((i * n + j, (i + 1) * n + j2, (i + 1) * n + j))
        fs.append(tuple(range(n))[::-1])
        fs.append(tuple(range(k * n, (k + 1) * n)))
        self._add(mat, "flat", vs, fs, what)

    def dome(self, p, nrm, r, mat, n=6, h=None, style="smooth", what="rivet"):
        """Rivet / tête de boulon bombée, posée sur une surface de normale nrm."""
        a, u, w = basis(nrm)
        p = Vector(p)
        h = r * 0.75 if h is None else h
        vs = []
        for i in range(n):
            ang = TAU * i / n
            vs.append(tuple(p - a * (r * 0.4) + (u * math.cos(ang) + w * math.sin(ang)) * r))
        for i in range(n):
            ang = TAU * (i + 0.5) / n
            vs.append(tuple(p + a * (h * 0.55) + (u * math.cos(ang) + w * math.sin(ang)) * (r * 0.72)))
        vs.append(tuple(p + a * h))
        fs = [tuple(range(n))[::-1]]
        for i in range(n):
            j = (i + 1) % n
            fs.append((i, j, n + i))
            fs.append((j, n + j, n + i))
            fs.append((n + i, n + j, 2 * n))
        self._add(mat, style, vs, fs, what)

    def bolt(self, p, nrm, r, mat, what="bolt"):
        """Boulon à tête hexagonale + rondelle."""
        a, _, _ = basis(nrm)
        p = Vector(p)
        self.cyl(p + a * 0.004, nrm, r * 1.35, 0.012, mat, n=10, style="flat", what="washer")
        self.cyl(p + a * (0.012 + r * 0.45), nrm, r, r * 0.9, mat, n=6, style="hard", what=what)

    def slab(self, q, nrm, t, mat, style="hard", what="plate"):
        """Plaque d'épaisseur t posée sur le quadrilatère q (4 points coplanaires), vers nrm."""
        n = Vector(nrm).normalized() * t
        q = [Vector(p) for p in q]
        self.hexa(q + [p + n for p in q], mat, style, what)

    # --- chemins ----------------------------------------------------------------------------------
    @staticmethod
    def spline(ctrl, k=8):
        """Catmull-Rom passant par les points de contrôle."""
        P = [Vector(p) for p in ctrl]
        if len(P) < 3:
            out = []
            for i in range(k + 1):
                out.append(P[0].lerp(P[-1], i / k))
            return out
        P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
        out = []
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            for j in range(k):
                t = j / k
                t2, t3 = t * t, t * t * t
                out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                                  + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
        out.append(P[-2])
        return out

    @staticmethod
    def resample(pts, step):
        P = [Vector(p) for p in pts]
        out = [P[0]]
        acc = 0.0
        for i in range(1, len(P)):
            a, b = P[i - 1], P[i]
            seg = (b - a).length
            if seg < 1e-9:
                continue
            d = step - acc
            while d <= seg:
                out.append(a.lerp(b, d / seg))
                d += step
            acc = seg - (d - step)
        if (out[-1] - P[-1]).length > step * 0.3:
            out.append(P[-1])
        return out

    def frames(self, P):
        T = []
        for i in range(len(P)):
            a = P[max(0, i - 1)]
            b = P[min(len(P) - 1, i + 1)]
            T.append((b - a).normalized())
        _, u, _ = basis(T[0])
        U = [u]
        for i in range(1, len(P)):
            q = T[i - 1].rotation_difference(T[i])
            u = (q @ U[-1]).normalized()
            U.append(u)
        return T, U

    def tube(self, pts, r, mat, n=10, style="smooth", radii=None, caps=True, what="tube"):
        P = [Vector(p) for p in pts]
        T, U = self.frames(P)
        vs, fs = [], []
        for i, p in enumerate(P):
            rr = radii[i] if radii else r
            w = T[i].cross(U[i]).normalized()
            for j in range(n):
                ang = TAU * j / n
                vs.append(tuple(p + (U[i] * math.cos(ang) + w * math.sin(ang)) * rr))
        for i in range(len(P) - 1):
            for j in range(n):
                j2 = (j + 1) % n
                fs.append((i * n + j, i * n + j2, (i + 1) * n + j2, (i + 1) * n + j))
        if caps:
            fs.append(tuple(range(n))[::-1])
            last = (len(P) - 1) * n
            fs.append(tuple(range(last, last + n)))
        self._add(mat, style, vs, fs, what)
        return P, T

    def hose(self, ctrl, r, mat, step=0.03, n=10, what="hose"):
        """Gaine annelée (cuivre, caoutchouc) : rayon alterné tous les `step`."""
        P = self.resample(self.spline(ctrl, 10), step / 2.0)
        radii = [r if i % 2 == 0 else r * 0.8 for i in range(len(P))]
        self.tube(P, r, mat, n=n, radii=radii, what=what)
        return P

    def cable(self, p0, p1, sag, r, mat, n=8, what="cable"):
        p0, p1 = Vector(p0), Vector(p1)
        pts = []
        for i in range(13):
            t = i / 12.0
            p = p0.lerp(p1, t)
            p.z -= sag * 4 * t * (1 - t)
            pts.append(p)
        self.tube(pts, r, mat, n=n, what=what)

    def pipe(self, ctrl, r, mat, fl_mat=None, bolt_mat=None, flanges=True, what="pipe"):
        """Tuyau à coudes arrondis, brides boulonnées aux extrémités et au milieu."""
        P = self.spline(ctrl, 8)
        P, T = self.tube(P, r, mat, n=14, what=what)
        if flanges:
            fl = fl_mat or mat
            idx = [0, len(P) // 2, len(P) - 1]
            for i in idx:
                self.cyl(P[i], T[i], r * 1.45, r * 0.55, fl, n=16, style="hard", what="flange")
                if bolt_mat is not None:
                    a, u, w = basis(T[i])
                    for k in range(6):
                        ang = TAU * k / 6
                        q = P[i] + (u * math.cos(ang) + w * math.sin(ang)) * r * 1.22 + a * r * 0.3
                        self.dome(q, a, 0.016, bolt_mat, n=6)

    # --- motifs de surface ------------------------------------------------------------------------
    def panels(self, q, nu, nv, mat, t=0.03, gap=0.02, rivet_mat=None, rivet_r=0.02, rivet_step=0.16,
               rivet_inset=0.035, jitter=0.35, mats=None, what="panel"):
        """Habille un quadrilatère q = (p00, p10, p11, p01) (sens direct vu de l'extérieur) de nu × nv plaques
        rivetées séparées par des joints sombres. mats : liste de matériaux tirés au sort (plaques dépareillées)."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        gu, gv = gap / max(lu, 1e-6) / 2.0, gap / max(lv, 1e-6) / 2.0
        for i in range(nu):
            for j in range(nv):
                s0, s1 = i / nu + gu, (i + 1) / nu - gu
                t0, t1 = j / nv + gv, (j + 1) / nv - gv
                th = t * (1.0 + jitter * (self.rng.random() - 0.5) * 2)
                m = mats[self.rng.randrange(len(mats))] if mats else mat
                quad = [P(s0, t0), P(s1, t0), P(s1, t1), P(s0, t1)]
                self.slab(quad, nrm, th, m, "hard", what)
                if rivet_mat is not None:
                    iu, iv = rivet_inset / max(lu, 1e-6), rivet_inset / max(lv, 1e-6)
                    pw = (s1 - s0) * lu
                    ph = (t1 - t0) * lv
                    nu_r = max(2, int(pw / (rivet_step * RIVET_K)) + 1)
                    nv_r = max(2, int(ph / (rivet_step * RIVET_K)) + 1)
                    pts = set()
                    for kk in range(nu_r):
                        s = s0 + iu + (s1 - s0 - 2 * iu) * kk / (nu_r - 1)
                        pts.add((round(s, 5), round(t0 + iv, 5)))
                        pts.add((round(s, 5), round(t1 - iv, 5)))
                    for kk in range(nv_r):
                        tt = t0 + iv + (t1 - t0 - 2 * iv) * kk / (nv_r - 1)
                        pts.add((round(s0 + iu, 5), round(tt, 5)))
                        pts.add((round(s1 - iu, 5), round(tt, 5)))
                    for s, tt in sorted(pts):
                        self.dome(P(s, tt) + nrm * th, nrm, rivet_r, rivet_mat)

    def hazard(self, q, n, t=0.02, skew=0.5):
        """Bande de danger jaune et noire (rayures obliques) sur le quadrilatère q."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        sk = skew / n
        for i in range(-1, n + 1):
            s0, s1 = i / n, (i + 1) / n
            a0, a1 = max(0.0, min(1.0, s0)), max(0.0, min(1.0, s1))
            b0, b1 = max(0.0, min(1.0, s0 + sk)), max(0.0, min(1.0, s1 + sk))
            if a1 - a0 < 1e-4 and b1 - b0 < 1e-4:
                continue
            m = self.M["hazy"] if i % 2 == 0 else self.M["hazk"]
            self.slab([P(a0, 0), P(a1, 0), P(b1, 1), P(b0, 1)], nrm, t, m, "flat", "hazard")

    def grille(self, q, n, depth=0.03, slat_mat=None, frame=0.03):
        """Grille d'aération : cadre, fond noir, lamelles ; q dans le plan de la face (vers l'extérieur)."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
        sm = slat_mat or self.M["steel"]

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        self.slab(q, nrm, 0.006, self.M["void"], "flat", "grille_fond")
        lu = (q[1] - q[0]).length
        lv = (q[3] - q[0]).length
        fu, fv = frame / lu, frame / lv
        for quad in ([P(0, 0), P(1, 0), P(1, fv), P(0, fv)], [P(0, 1 - fv), P(1, 1 - fv), P(1, 1), P(0, 1)],
                     [P(0, fv), P(fu, fv), P(fu, 1 - fv), P(0, 1 - fv)], [P(1 - fu, fv), P(1, fv), P(1, 1 - fv), P(1 - fu, 1 - fv)]):
            self.slab(quad, nrm, depth, sm, "hard", "grille_cadre")
        for i in range(n):
            t0 = fv + (1 - 2 * fv) * (i + 0.2) / n
            t1 = fv + (1 - 2 * fv) * (i + 0.62) / n
            self.slab([P(fu, t0), P(1 - fu, t0), P(1 - fu, t1), P(fu, t1)], nrm, depth * 0.7, sm, "hard", "lamelle")

    def perforated(self, q, nu, nv, mat, hole_r=0.018, t=0.012):
        """Tôle perforée : plaque + trous (disques noirs affleurants)."""
        q = [Vector(p) for p in q]
        nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()

        def P(s, t_):
            a = q[0].lerp(q[1], s)
            b = q[3].lerp(q[2], s)
            return a.lerp(b, t_)
        self.slab(q, nrm, t, mat, "hard", "tole_perforee")
        for i in range(nu):
            for j in range(nv):
                s = (i + 0.5) / nu
                tt = (j + 0.5) / nv + (0.5 / nv if i % 2 else 0.0) * 0.5
                if tt > 1 - 0.3 / nv:
                    continue
                self.cyl(P(s, tt) + nrm * (t + 0.001), nrm, hole_r, 0.004, self.M["void"], n=6, style="flat", what="trou")

    # --- source de halo (passe light du socle) ----------------------------------------------------
    def halo(self, loc, color, power):
        o = self.S.halo_light(tuple(self.W(loc)), color, power, radius=0.08, name="%s_halo_%d" % (self.tag, len(self.halos)))
        self.halos.append(o)
        return o

    # --- création des objets ----------------------------------------------------------------------
    def flush(self):
        coll = self.S.piece_collection()
        objs = []
        for idx, ((mat, style), (V, F)) in enumerate(sorted(self.data.items(), key=lambda kv: (kv[0][0].name, kv[0][1]))):
            if not F:
                continue
            me = bpy.data.meshes.new("%s_%s_%s" % (self.tag, mat.name, style))
            me.from_pydata(V, [], F)
            me.validate()
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(me)
            bm.free()
            me.update()
            o = bpy.data.objects.new(me.name, me)
            coll.objects.link(o)
            o.data.materials.append(mat)
            st = STYLES[style]
            if st["smooth"] is not None:
                self.S.smooth(o, st["smooth"])
            if st["bevel"]:
                self.S.bevel(o, st["bevel"])
            o.rotation_euler = (0.0, 0.0, self.rotz)
            objs.append(o)
        self.data = {}
        bpy.context.view_layer.update()
        return objs
