"""MATIÈRES DES TITANS (lot TITANS, 9/11 ; RECALIBRÉES sur les sept concepts du DC, 10/11) : l'identité visuelle commune au
Juggernaut, à la Sentinelle et au Léviathan (alliés) et au Kaiju (ennemi).

Lu sur les concepts (C:\\Users\\evan2\\Pictures\\Gemini_Generated_Image_*.jfif, 2752×1536) :
- le BLINDAGE est ARGENT PÂLE IRIDESCENT (environ #9FA8B8 en sRGB), reflets bleu → violet → rose aux rasances, PAS noir : les plaques
  sombres des rendus du 9/11 étaient une erreur ; le sombre, ce sont les CREUX (joints entre plaques, mécanique interne, articulations) ;
- les CONDUITS cyan (#19E6FF) sont des tracés FINS (circuits gravés) qui brillent même de jour ;
- les CŒURS / VORTEX sont cyan incandescent, centre presque blanc, avec un HALO diffus ;
- les CRISTAUX sont bleu glacier TRANSLUCIDES, arêtes vives, bord plus lumineux que le centre ;
- les ANNEAUX de lévitation sont des tores cyan SEMI-TRANSPARENTS lumineux ;
- accents MAGENTA / ROSE discrets : articulations, et la chair du Kaiju biomécanique.

Tout repose sur le kit des géants (tools/render/pieces/experimentaux/mat.py : tôles, grain, arêtes, crasse). Les émissifs passent par
S.mat_emissive (couche lueur du pipeline ; `main_scale` : part d'émission gardée dans la couche principale, règle V0b).
Lisibilité de JOUR à 32 px/tuile : le blindage argent froid (bleu-gris) se détache du sol de Factorio (brun/vert chaud) ; si l'argent se
noyait, on assombrit les CREUX (joint, crasse, struct), jamais le blindage (consigne du DC).

S'exécute DANS Blender (bpy). Importé par juggernaut.py, kaiju.py, sentinelle.py, leviathan.py via batch_titans.py.
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
XP = os.path.normpath(os.path.join(HERE, "..", "experimentaux"))
if XP not in sys.path:
    sys.path.insert(0, XP)
import mat as MT  # noqa: E402

# ------------------------------------------------------------------------------------------------ palette (linéaire)
# ART-16DIR (11/11, charte du mandat de 10 h : « blindage sombre iridescent, anneaux de lévitation, cœurs et conduits à vortex cyan »,
# plus de contraste) : l'argent passe au gris acier bleuté (environ #5D6476, deux crans plus sombre, jamais noir : il doit se détacher du sol
# brun de Factorio), l'iridescence monte, conduits et anneaux brillent plus ; le cœur garde sa force (au-delà la couche additive blanchit).
ARGENT = (0.110, 0.130, 0.180)      # #5D6476 : blindage principal, gris acier bleuté sombre (avant : #9FA8B8)
ARGENT2 = (0.084, 0.100, 0.140)     # plaques secondaires, un ton plus bas (#515867 ; avant : #8B96AA)
CREUX = (0.038, 0.042, 0.058)        # joints, mécanique interne, articulations : le SOMBRE des concepts
ARETE = (0.78, 0.82, 0.90)           # métal nu des arêtes : vif, presque blanc
ARETE_SOMBRE = (0.42, 0.46, 0.54)    # ART-16DIR : arêtes du blindage sombre (usure 0,55 -> 0,30 : le métal nu blanchissait les plaques)
CYAN = (0.098, 0.902, 1.000)         # #19E6FF : conduits
TURQUOISE = (0.12, 0.86, 0.82)
COEUR = (0.14, 0.86, 1.00)           # vortex : cyan vif ; rouge bas : à force 3 la couche additive (RGB coupé à 1) reste CYAN, pas blanche
SINGULARITE = (0.06, 0.72, 1.00)     # singularité de la Sentinelle (FINITIONS 10/11) : cyan profond, jamais blanc de jour
CRISTAL = (0.16, 0.46, 1.00)         # émission des cristaux (bleu glacier saturé : la lueur additive ne doit pas blanchir)
GLACE = (0.26, 0.50, 0.88)           # corps des cristaux (bleu glacier profond : la lueur pâle des hautes ères ne le blanchit pas, FINITIONS)
MAGENTA = (0.95, 0.22, 0.70)
CHAIR = (0.40, 0.14, 0.25)           # chair du Kaiju biomécanique
PEAU = (0.25, 0.15, 0.21)            # peau mauve du Kaiju, entre les plaques
# Iridescence : bleu à faible incidence, violet au milieu, rose en rasant.
IRIS = ((0.40, 0.55, 1.00), (0.62, 0.42, 0.95), (1.00, 0.50, 0.80))
# Éclairage : les métaux reflètent le ciel ; le ciel du calibrage (0,08) est trop sombre pour un argent iridescent : les seuls rayons
# spéculaires voient un ciel SKY_GLOSSY fois plus fort (fo_scene.setup_world, SKY_GLOSSY_FACTOR ; sans effet sur le diffus ni l'ombre).
SKY_GLOSSY = 2.5                       # ART-16DIR : 6 -> 2,5 (le ciel blanchissait tout le blindage)


def _facing(N, L, blend=0.4):
    lw = N.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = blend
    return lw.outputs["Facing"]


def iridescence(m, part=0.45, blend=0.4):
    """Teinte le matériau `m` (sorti de MT.surface) selon l'angle de vue : rampe bleu -> violet -> rose (IRIS) pilotée par Layer Weight
    (Facing), MÉLANGÉE à la couleur de base avec un poids Facing × `part` (de face : la base ; en rasant : la teinte à `part`)."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    link = p.inputs["Base Color"].links[0]
    base = link.from_socket
    L.remove(link)
    f = _facing(N, L, blend)
    ramp = N.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = (IRIS[0][0], IRIS[0][1], IRIS[0][2], 1.0)
    cr.elements[1].position = 1.0
    cr.elements[1].color = (IRIS[2][0], IRIS[2][1], IRIS[2][2], 1.0)
    e = cr.elements.new(0.5)
    e.color = (IRIS[1][0], IRIS[1][1], IRIS[1][2], 1.0)
    L.new(f, ramp.inputs["Fac"])
    k = N.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = part
    L.new(f, k.inputs[0])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MIX"
    L.new(k.outputs[0], mix.inputs["Factor"])
    L.new(base, mix.inputs[6])
    L.new(ramp.outputs["Color"], mix.inputs[7])
    L.new(mix.outputs[2], p.inputs["Base Color"])
    if "Coat Weight" in p.inputs:
        p.inputs["Coat Weight"].default_value = 0.6
        p.inputs["Coat Roughness"].default_value = 0.08
        if "Coat Tint" in p.inputs:
            p.inputs["Coat Tint"].default_value = (0.85, 0.90, 1.0, 1.0)
    return m


def translucide(m, alpha):
    """Mélange la sortie du matériau avec un Transparent BSDF : part opaque `alpha` (anneaux, halos)."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    out = N["Material Output"]
    link = out.inputs["Surface"].links[0]
    shader = link.from_socket
    L.remove(link)
    tr = N.new("ShaderNodeBsdfTransparent")
    mix = N.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = alpha
    L.new(tr.outputs[0], mix.inputs[1])
    L.new(shader, mix.inputs[2])
    L.new(mix.outputs[0], out.inputs["Surface"])
    m["fo_alpha"] = float(alpha)
    return m


def rim(m, strength, creux=0.35, blend=0.5):
    """Émission plus forte au bord qu'au centre (cristal translucide, cœur) : force = strength × (creux + (1 - creux) × Facing)."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    old = N.get("fo_emit_strength")
    if old is not None:               # croûte de mat_emissive : elle multipliait déjà par la force ; on la rend neutre
        old.name = "fo_crust"
        old.inputs[1].default_value = 1.0
    k = N.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.name = "fo_emit_strength"       # _set_emit_strength (passe principale × main_scale) règle inputs[1]
    k.inputs[1].default_value = strength
    r = N.new("ShaderNodeMapRange")
    r.inputs["From Min"].default_value = 0.0
    r.inputs["From Max"].default_value = 1.0
    r.inputs["To Min"].default_value = creux
    r.inputs["To Max"].default_value = 1.0
    L.new(_facing(N, L, blend), r.inputs["Value"])
    prev = p.inputs["Emission Strength"].links
    if prev:   # croûte déjà branchée : on la multiplie par le bord
        src = prev[0].from_socket
        L.remove(prev[0])
        m2 = N.new("ShaderNodeMath")
        m2.operation = "MULTIPLY"
        L.new(src, m2.inputs[0])
        L.new(r.outputs["Result"], m2.inputs[1])
        L.new(m2.outputs[0], k.inputs[0])
    else:
        L.new(r.outputs["Result"], k.inputs[0])
    L.new(k.outputs[0], p.inputs["Emission Strength"])
    return m


def facettes(m, cellules=2.6, stries=6.0, bosse=0.35, graine=0.0):
    """Facettes et stries d'un cristal (FINITIONS 10/11) : Voronoi (cellules = facettes, relief `bosse`) et bandes ondulées le long de
    l'axe z de l'objet (stries de croissance, relief faible) ; la couleur de base s'éclaircit sur les crêtes des stries (bleu glacier clair),
    pour que le cristal reste lisible à 32 px/tuile (des faces, pas un aplat)."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    vo = N.new("ShaderNodeTexVoronoi")
    vo.feature = "F1"
    vo.inputs["Scale"].default_value = cellules
    if "W" in vo.inputs:
        vo.voronoi_dimensions = "4D"
        vo.inputs["W"].default_value = graine
    L.new(tc.outputs["Object"], vo.inputs["Vector"])
    wv = N.new("ShaderNodeTexWave")
    wv.wave_type = "BANDS"
    wv.bands_direction = "Z"
    wv.inputs["Scale"].default_value = stries
    wv.inputs["Distortion"].default_value = 1.2
    wv.inputs["Detail"].default_value = 2.0
    L.new(tc.outputs["Object"], wv.inputs["Vector"])
    b1 = N.new("ShaderNodeBump")
    b1.inputs["Strength"].default_value = bosse * 0.3
    b1.inputs["Distance"].default_value = 0.05
    L.new(wv.outputs["Fac"], b1.inputs["Height"])
    b2 = N.new("ShaderNodeBump")
    b2.inputs["Strength"].default_value = bosse
    b2.inputs["Distance"].default_value = 0.2
    L.new(vo.outputs["Distance"], b2.inputs["Height"])
    L.new(b1.outputs["Normal"], b2.inputs["Normal"])
    L.new(b2.outputs["Normal"], p.inputs["Normal"])
    # couleur : base sur les creux des stries, bleu glacier clair sur leurs crêtes (45 % au plus)
    base = tuple(p.inputs["Base Color"].default_value)[:3]
    clair = tuple(min(1.0, c * 0.55 + 0.45) for c in base)
    k = N.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.inputs[1].default_value = 0.45
    L.new(wv.outputs["Fac"], k.inputs[0])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MIX"
    mix.inputs[6].default_value = (base[0], base[1], base[2], 1.0)
    mix.inputs[7].default_value = (clair[0], clair[1], clair[2], 1.0)
    L.new(k.outputs[0], mix.inputs["Factor"])
    L.new(mix.outputs[2], p.inputs["Base Color"])
    return m


def cristal(S, name):
    """Cristal bleu glacier TRANSLUCIDE (FINITIONS 10/11, le DC : « translucides et texturés ») : corps GLACE, transmission 0,55 (le sol et les
    pièces se devinent au travers), IOR du verre, vernis, facettes et stries (facettes()), bord lumineux CRISTAL (rim) ; 45 % de jour.
    `fo_glow_part` : part gardée dans la passe de LUEUR (0,3) : à l'ère V du Kaiju la lueur, teintée par la couleur pâle de l'ère et presque
    opaque (alpha 0,91), blanchissait les cristaux ; le corps translucide porte désormais la couleur, la lueur n'est qu'un liseré."""
    m = S.mat_emissive(name, CRISTAL, strength=0.9, base=GLACE, main_scale=0.45, crust=(2.4, 0.3, 5))
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.06
    p.inputs["Metallic"].default_value = 0.0
    if "Transmission Weight" in p.inputs:
        p.inputs["Transmission Weight"].default_value = 0.55
    if "IOR" in p.inputs:
        p.inputs["IOR"].default_value = 1.45
    if "Coat Weight" in p.inputs:
        p.inputs["Coat Weight"].default_value = 1.0
        p.inputs["Coat Roughness"].default_value = 0.03
    facettes(m, cellules=2.6, stries=6.0, bosse=0.35, graine=5.0)
    rim(m, 0.9, creux=0.3, blend=0.55)
    m["fo_glow_part"] = 0.3
    return m


def singularite(S, name):
    """Singularité de la Sentinelle (FINITIONS 10/11 : « presque blanche de jour » sur la planche du 10/11). Cyan PROFOND (rouge presque nul :
    même à force 2,4 la couche additive reste cyan), 30 % de jour seulement ; profil d'ACCRÉTION piloté par l'angle de vue (Facing) : bord à
    0,55, anneau brillant aux deux tiers, œil sombre au centre (0,2) ; croûte tourbillonnante plus serrée. La lueur de nuit garde toute la force
    (couche lueur séparée)."""
    m = S.mat_emissive(name, SINGULARITE, strength=2.4, base=(0.01, 0.10, 0.14), main_scale=0.3, crust=(2.0, 0.5, 7))
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    old = N.get("fo_emit_strength")
    old.name = "fo_crust"
    old.inputs[1].default_value = 1.0
    ramp = N.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = (0.55, 0.55, 0.55, 1.0)
    cr.elements[1].position = 1.0
    cr.elements[1].color = (0.2, 0.2, 0.2, 1.0)
    e = cr.elements.new(0.55)
    e.color = (1.0, 1.0, 1.0, 1.0)
    e = cr.elements.new(0.8)
    e.color = (0.6, 0.6, 0.6, 1.0)
    L.new(_facing(N, L, 0.5), ramp.inputs["Fac"])
    m2 = N.new("ShaderNodeMath")
    m2.operation = "MULTIPLY"
    L.new(old.outputs[0], m2.inputs[0])
    L.new(ramp.outputs["Color"], m2.inputs[1])
    k = N.new("ShaderNodeMath")
    k.operation = "MULTIPLY"
    k.name = "fo_emit_strength"
    k.inputs[1].default_value = 2.4
    L.new(m2.outputs[0], k.inputs[0])
    L.new(k.outputs[0], p.inputs["Emission Strength"])
    return m


def coeur(S, name, strength=3.0):
    """Cœur à vortex : cyan incandescent, croûte tourbillonnante (le blanc vient des crêtes de la croûte) ; garde 50 % de jour (il brûle en
    plein jour sur les concepts) sans écraser tout le disque en blanc (Sentinelle : singularité de 9 unités)."""
    m = S.mat_emissive(name, COEUR, strength=strength, base=(0.08, 0.50, 0.58), main_scale=0.5, crust=(1.4, 0.6, 3))
    return m


def halo(S, name):
    """Halo d'un cœur : sphère plus large, cyan faible, presque toute transparente ; couche lueur surtout (20 % de jour)."""
    m = S.mat_emissive(name, CYAN, strength=1.2, base=(0.02, 0.2, 0.24), main_scale=0.2)
    rim(m, 1.2, creux=1.0, blend=0.5)
    return translucide(m, 0.16)


def anneau_lum(S, name):
    """Anneau de lévitation : tore cyan semi-transparent, lumineux (bord plus fort), 50 % de jour."""
    m = S.mat_emissive(name, CYAN, strength=1.6, base=(0.06, 0.40, 0.46), main_scale=0.45)   # ART-16DIR : 1,3 -> 1,6
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.2
    rim(m, 1.6, creux=0.5, blend=0.45)
    m["fo_glow_part"] = 0.7
    return translucide(m, 0.55)


def matieres(S, prefix, gris=False):
    """Le jeu de matières d'un titan. `prefix` : « ju_ », « ka_ », « se_ », « le_ » (les groupes de lueur de batch_titans lisent les noms).
    Clés : blind, blind2 (argent iridescent), struct (creux sombres), canon (acier clair), anneau (tore cyan translucide), os (griffes,
    acier pâle), peau, chair (Kaiju), conduit, turq, coeur, halo, cristal, accent (magenta), singularite (vortex de la Sentinelle, FINITIONS)."""
    def surf(name, col, **kw):
        if gris:
            return MT.surface(prefix + "g_" + name, (0.2, 0.2, 0.2), rough=0.6, met=0.1, usure=0.3, crasse=0.6, graine=kw.get("graine", 0))
        return MT.surface(prefix + name, col, **kw)
    MT.ECH[0] = 2.2
    MT.PATINE.clear()
    MT.PATINE.update(ta=0.07, ra=0.10, ec=0.0, nu_k=1.0, sans=("cristal", "conduit", "coeur", "os", "anneau", "halo"))
    M = {}
    # blindage principal : plaques argent pâle, joints sombres NETS (les creux), arêtes vives presque blanches, peu de crasse
    M["blind"] = surf("blind", ARGENT, rough=0.26, met=0.70, tole=(1.6, 0.9), joint=0.12, joint_l=0.02, var=0.06, coulures=0.0,
                      usure=0.30, nu=ARETE_SOMBRE, crasse=0.45, crasse_col=CREUX, relief=0.8, graine=11)
    M["blind2"] = surf("blind2", ARGENT2, rough=0.30, met=0.65, tole=(0.8, 0.5), joint=0.12, joint_l=0.024, var=0.08,
                       usure=0.30, nu=ARETE_SOMBRE, crasse=0.5, crasse_col=CREUX, relief=0.7, graine=12)
    # structure (articulations, pistons, mécanique interne) : les CREUX sombres des concepts
    M["struct"] = surf("struct", CREUX, rough=0.48, met=0.6, usure=0.45, nu=(0.30, 0.34, 0.42), crasse=0.6,
                       crasse_col=(0.012, 0.013, 0.018), graine=13)
    # canon : acier clair cannelé
    M["canon"] = surf("canon", (0.30, 0.33, 0.40), rough=0.34, met=0.75, tole=(0.5, 0.25), joint=0.15, joint_l=0.03, var=0.08, usure=0.5,
                      nu=ARETE, crasse=0.45, crasse_col=CREUX, relief=0.7, graine=15)
    # peau du Kaiju biomécanique : mauve sombre à reflets roses ; chair : rose-magenta mat (cou, articulations)
    M["peau"] = surf("peau", PEAU, rough=0.52, met=0.20, tole=(0.45, 0.28), joint=0.25, joint_l=0.03, var=0.18,
                     usure=0.3, nu=(0.55, 0.40, 0.52), crasse=0.55, crasse_col=(0.03, 0.012, 0.025), relief=0.8, graine=16)
    M["chair"] = surf("chair", CHAIR, rough=0.62, met=0.05, usure=0.15, nu=(0.62, 0.30, 0.45), crasse=0.5, crasse_col=(0.06, 0.015, 0.04), graine=18)
    # griffes, dents, pointes d'os : acier pâle
    M["os"] = surf("os", (0.52, 0.52, 0.55), rough=0.32, met=0.6, usure=0.3, nu=ARETE, crasse=0.35, crasse_col=CREUX, graine=17)
    if not gris:
        iridescence(M["blind"], part=0.6, blend=0.4)      # ART-16DIR : 0,45 -> 0,6
        iridescence(M["blind2"], part=0.65, blend=0.4)    # 0,5 -> 0,65
        iridescence(M["canon"], part=0.3, blend=0.45)
        iridescence(M["peau"], part=0.35, blend=0.5)
        iridescence(M["os"], part=0.2, blend=0.5)
    # émissifs (couche lueur) : conduits fins, cœur et halo, cristaux, anneaux, accents magenta
    M["conduit"] = S.mat_emissive(prefix + "conduit", CYAN, strength=3.1, base=(0.02, 0.30, 0.36), main_scale=0.5)   # ART-16DIR : 2,6 -> 3,1
    M["turq"] = S.mat_emissive(prefix + "conduit_turq", TURQUOISE, strength=2.0, base=(0.02, 0.26, 0.26), main_scale=0.4)
    M["coeur"] = coeur(S, prefix + "coeur")
    M["singularite"] = singularite(S, prefix + "singularite")
    M["halo"] = halo(S, prefix + "halo")
    M["cristal"] = cristal(S, prefix + "cristal")
    M["anneau"] = anneau_lum(S, prefix + "anneau")
    M["accent"] = S.mat_emissive(prefix + "accent", MAGENTA, strength=1.4, base=(0.30, 0.06, 0.20), main_scale=0.6)
    return M


def sans_ombre(objs):
    """Les halos (translucides) ne portent pas d'ombre et ne se reflètent pas : à appeler après lot.flush()."""
    for o in objs:
        if o.type == "MESH" and o.data.materials and any(m is not None and m.get("fo_alpha", 1.0) < 0.3 for m in o.data.materials):
            o.visible_shadow = False
            o.visible_diffuse = False
            o.visible_glossy = False
