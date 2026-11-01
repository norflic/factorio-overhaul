"""ICÔNES DU MINERAI D'ILMÉNITE, refaites sur la forme J7 (lot ICONE-ILMENITE, 30/10).

DC (30/10, ~10 h 40) : « je viens de revoir les minerais, changez les icones mais si non c est pas mal ». La forme J7
(gisement) est acceptée ; ses icônes (gros plan de feuille.py --icones-seules) ne le sont pas : à 32 px elles se lisent
en UN pâté gris aux bords lisses (morceaux soudés, aucun grain, reflets blancs ponctuels), quand les icônes vanilla
(icons/iron-ore.png, coal.png : 64 px + 3 mipmaps) montrent 3 à 5 morceaux SÉPARÉS par un jour sombre, qui remplissent
le cadre, à surface grenue et arêtes claires.

Même modèle que la forme J7 : morceaux de gisement.roche aux réglages J7 (6 coupes, cassure 0,45 à 0,80, bosses ±16 %,
aplat 0,90, lissé 30°), tête et bosse soudées comme les amas J7, tablette hexagonale d'accent (gisement.lame, habitus
tabulaire de l'ilménite) ; matières J7 (ilmenite_k brun-noir, ilmenite_bronze) ; ciel spéculaire × 5 (CALIB J7).
Ajouts propres à l'icône, assumés : (1) les morceaux sont POSÉS (positions fixes, jour entre eux) au lieu d'être tirés
dans un disque ; (2) un relief de surface (bosselage par bruit, en coordonnées du monde) qui donne le grain des icônes
vanilla ; à l'échelle du gisement (32 px par tuile) il n'apporterait rien ; (3) les plages bronze sont un mélange par
bruit des deux matières J7 sur chaque morceau, au lieu d'une matière par morceau.

Rendu : 4 cellules (icône, puis les 3 images au sol `pictures`) en UN appel de Blender, PAR LE VERROU, à 256 px par
tuile (--set PX_PER_UNIT_HR=256 : même géométrie que le gisement, 4 fois la résolution), passe main seule ; réduction
en lumière linéaire prémultipliée (fo_post.icon_strip) en 64 + 32 + 16 + 8 = 120 × 64 px, comme les icônes vanilla.

    # rendu (Blender par le verrou) puis post-traitement, vers un dossier de sortie :
    python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/ressources/icone_ilmenite.py \
        --samples 128 --travail <dossier> --sortie <dossier des icônes>
    # post-traitement seul : ... --post-seul ; installation dans graphics/ressources/ilmenite (sommes du MANIFEST) :
    py -3.9 tools/render/pieces/ressources/icone_ilmenite.py --travail <dossier> --installer
"""
import argparse
import hashlib
import json
import math
import os
import random
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.abspath(os.path.join(HERE, "..", ".."))
MOD = os.path.abspath(os.path.join(RENDER, "..", ".."))
for _p in (HERE, RENDER):
    if _p not in sys.path:
        sys.path.insert(0, _p)

PIECE = {"name": "icone-ilmenite", "variants": {"J7": {}}, "margin_px": 32}
PAS_IC = 6.0          # écart entre deux cellules, en tuiles
PX = 256.0            # pixels par tuile du rendu des icônes
GRAINE = 7307
GROS = 1.15       # (1,10 avant la ronde 7) morceaux grossis (ronde 6 : à 32 px, le jour entre les morceaux mangeait le cadre)
RUGOSITE = 0.22   # reflets plus nets que J7 (0,26) : arêtes claires des icônes vanilla
FICHIERS = ("icone.png", "icone-1.png", "icone-2.png", "icone-3.png")

# Matières : couleurs J7 (directions.MAT["ilmenite_k"], ["ilmenite_bronze"], valeurs linéaires)
BRUN = (0.15, 0.11, 0.085)    # brun J7 exact (ronde 7, critique : le brun plus sombre noyait l'icône à 32 px)
BRONZE = (0.33, 0.22, 0.14)
BRONZE_MAX = 0.30   # part de bronze au plus dans une plage (ronde 7 : à 1,0, les plages beiges en aplat se lisaient
                    # « granit » ou « biscuit », absentes de J7 ; le bronze de J7 est dans les REFLETS, pas en taches)
RELIEF = 0.15       # force du bosselage (ronde 7 : 0,35 émiettait les grands reflets bronze de J7 en grain)
# Compositions (tuiles de jeu, y vers le sud, relatives au centre de la cellule) : (x, y, taille, bosse, part de bronze)
#   bosse : None ou (angle en degrés, taille relative) d'une bosse soudée (amas J7 : tête et 1 bosse) ;
#   tablettes : (x, y, longueur, largeur, inclinaison en degrés, azimut en degrés).
COMPOS = [
    # icône : 4 morceaux en quinconce serrée (comme iron-ore.png), une tablette bronze qui sort du gros morceau
    dict(morceaux=[(0.17, 0.17, 0.32, (40, 0.6), 0.35), (-0.24, -0.19, 0.27, (220, 0.55), 0.25),
                   (0.27, -0.25, 0.23, None, 0.45), (-0.26, 0.24, 0.24, (140, 0.55), 0.25)],
         tablettes=[(0.03, -0.30, 0.24, 0.26, 22, 170)]),
    # images au sol : trois autres tas (la vanilla en a 4 en tout, dont l'icône)
    dict(morceaux=[(-0.15, 0.10, 0.30, (160, 0.6), 0.3), (0.25, 0.17, 0.24, (30, 0.55), 0.4),
                   (0.10, -0.24, 0.23, None, 0.3), (-0.27, -0.22, 0.17, None, 0.45)],
         tablettes=[]),
    dict(morceaux=[(-0.12, 0.10, 0.28, (150, 0.5), 0.35), (0.24, 0.13, 0.24, None, 0.3),
                   (0.05, -0.25, 0.22, (270, 0.5), 0.45), (-0.30, -0.19, 0.16, None, 0.3),
                   (0.33, -0.21, 0.15, None, 0.4)],
         tablettes=[]),
    dict(morceaux=[(-0.22, -0.20, 0.26, (120, 0.6), 0.3), (0.25, -0.11, 0.23, None, 0.35),
                   (-0.09, 0.28, 0.23, (10, 0.55), 0.4)],
         tablettes=[(0.19, 0.25, 0.20, 0.24, 45, 200)]),
]


def centre(c):
    return (PAS_IC * (c - 1.5), 0.0)


# ------------------------------------------------------------------------------------------------
# Blender (pièce lue par tools/render/blender/render_piece.py)
# ------------------------------------------------------------------------------------------------
def _matiere(S, nom, part_bronze):
    """Brun-noir J7 et plages bronze mêlées par bruit ; relief de surface par bosselage (grain des icônes vanilla)."""
    import bpy
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    # plages bronze (bruit large)
    nb = N.new("ShaderNodeTexNoise")
    nb.inputs["Scale"].default_value = 9.0
    nb.inputs["Detail"].default_value = 3.0
    L.new(tc.outputs["Object"], nb.inputs["Vector"])
    mb = N.new("ShaderNodeMapRange")
    mb.inputs["From Min"].default_value = 0.64 - 0.22 * part_bronze
    mb.inputs["From Max"].default_value = 0.72 - 0.22 * part_bronze
    mb.inputs["To Max"].default_value = BRONZE_MAX
    L.new(nb.outputs["Fac"], mb.inputs["Value"])
    # grain fin de la couleur (comme mat_metal : ±22 %)
    ng = N.new("ShaderNodeTexNoise")
    ng.inputs["Scale"].default_value = 60.0
    ng.inputs["Detail"].default_value = 6.0
    ng.inputs["Roughness"].default_value = 0.6
    L.new(tc.outputs["Object"], ng.inputs["Vector"])
    mg = N.new("ShaderNodeMapRange")
    mg.inputs["From Min"].default_value = 0.3
    mg.inputs["From Max"].default_value = 0.7
    mg.inputs["To Min"].default_value = 0.78
    mg.inputs["To Max"].default_value = 1.22
    L.new(ng.outputs["Fac"], mg.inputs["Value"])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs[6].default_value = (BRUN[0], BRUN[1], BRUN[2], 1)
    mix.inputs[7].default_value = (BRONZE[0], BRONZE[1], BRONZE[2], 1)
    L.new(mb.outputs["Result"], mix.inputs["Factor"])
    sc = N.new("ShaderNodeVectorMath")
    sc.operation = "SCALE"
    L.new(mix.outputs[2], sc.inputs[0])
    L.new(mg.outputs["Result"], sc.inputs["Scale"])
    # creux assombris (dirt 0,45 de J7)
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.06
    ao.samples = 8
    dm = N.new("ShaderNodeMapRange")
    dm.inputs["To Min"].default_value = 0.55
    dm.inputs["To Max"].default_value = 1.0
    L.new(ao.outputs["AO"], dm.inputs["Value"])
    sd = N.new("ShaderNodeVectorMath")
    sd.operation = "SCALE"
    L.new(sc.outputs["Vector"], sd.inputs[0])
    L.new(dm.outputs["Result"], sd.inputs["Scale"])
    L.new(sd.outputs["Vector"], p.inputs["Base Color"])
    # rugosité et métal : J7 (0,26 ; 0,62) sur le brun, bronze (0,32 ; 0,65)
    rr = N.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = RUGOSITE
    rr.inputs["To Max"].default_value = RUGOSITE + 0.06 * BRONZE_MAX
    L.new(mb.outputs["Result"], rr.inputs["Value"])
    L.new(rr.outputs["Result"], p.inputs["Roughness"])
    p.inputs["Metallic"].default_value = 0.72
    # relief : bruit grenu + cassures (Voronoï, distance au bord)
    nr = N.new("ShaderNodeTexNoise")
    nr.inputs["Scale"].default_value = 38.0
    nr.inputs["Detail"].default_value = 8.0
    nr.inputs["Roughness"].default_value = 0.65
    L.new(tc.outputs["Object"], nr.inputs["Vector"])
    vo = N.new("ShaderNodeTexVoronoi")
    vo.feature = "DISTANCE_TO_EDGE"
    vo.inputs["Scale"].default_value = 16.0
    L.new(tc.outputs["Object"], vo.inputs["Vector"])
    vm = N.new("ShaderNodeMapRange")
    vm.inputs["From Min"].default_value = 0.0
    vm.inputs["From Max"].default_value = 0.08
    L.new(vo.outputs["Distance"], vm.inputs["Value"])
    ad = N.new("ShaderNodeMath")
    ad.operation = "MULTIPLY_ADD"
    L.new(vm.outputs["Result"], ad.inputs[0])
    ad.inputs[1].default_value = 0.5
    L.new(nr.outputs["Fac"], ad.inputs[2])
    bu = N.new("ShaderNodeBump")
    bu.inputs["Strength"].default_value = RELIEF
    bu.inputs["Distance"].default_value = 0.012
    L.new(ad.outputs["Value"], bu.inputs["Height"])
    L.new(bu.outputs["Normal"], p.inputs["Normal"])
    m["fo_kind"] = "surface"
    return m


def build(S, C, variant):
    import gisement as G   # noqa: E402  (importe bpy : seulement dans Blender)
    import directions as D  # noqa: E402
    cle = "J7"
    d = D.DIRECTIONS[cle]
    coupes, lisse = D.ROCHE_COUPES[cle], D.ROCHE_LISSE[cle]
    aplat, cassure, bosse = D.ROCHE_APLAT[cle], D.ROCHE_CASSURE[cle], D.ROCHE_BOSSE[cle]
    mats = {}
    for c, compo in enumerate(COMPOS):
        rng = random.Random(GRAINE * 10 + c)
        cx, cy = centre(c)
        for i, (gx, gy, t, b, pb) in enumerate(compo["morceaux"]):
            t = t * GROS
            cle_m = round(pb, 2)
            if cle_m not in mats:
                mats[cle_m] = _matiere(S, "ilm_icone_%03d" % int(cle_m * 100), cle_m)
            parts = [(gx, gy, t, 0.0)]
            if b is not None:
                a = math.radians(b[0])
                # bosse soudée : décalée de 0,55 × t, à demi enfoncée (comme la tête et ses bosses dans un amas J7)
                parts.append((gx + 0.55 * t * math.cos(a), gy + 0.55 * t * math.sin(a) * 0.85, t * b[1], 0.0))
            for j, (px, py, tt, _) in enumerate(parts):
                v, f = G.roche(rng, tt, aplat=aplat, n_coupes=coupes, cassure=cassure, bosse=bosse)
                incl = math.radians(rng.uniform(0, 18))
                bx, by, _ = C.tile_to_blender(cx + px, cy + py)
                vv = G._transforme(v, incl, rng.uniform(0, 2 * math.pi), bx, by, -0.25 * tt * math.sin(incl))
                G._objet("ilm_ic%d_m%d_%d" % (c, i, j), vv, f, mats[cle_m], S, lisse)
        for k, (gx, gy, L, larg, incl, az) in enumerate(compo["tablettes"]):
            v, f = G.lame(rng, L, larg, larg * 0.42)
            bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
            vv = G._transforme(v, math.radians(incl), math.radians(az), bx, by, -0.02)
            if "tab" not in mats:
                mats["tab"] = _matiere(S, "ilm_icone_tab", 0.9)
            o = G._objet("ilm_ic%d_tab%d" % (c, k), vv, f, mats["tab"], S)
            S.bevel(o, 0.008, 1)



# ------------------------------------------------------------------------------------------------
# Python système : rendu par Blender (appelé sous le verrou) et post-traitement
# ------------------------------------------------------------------------------------------------
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")


def rendre(travail, samples):
    os.makedirs(travail, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", os.path.join(RENDER, "blender", "render_piece.py"), "--",
           "--piece", os.path.abspath(__file__), "--out", travail, "--variant", "J7", "--samples", str(samples),
           "--layers", "main", "--margin", "32",
           "--set", "PX_PER_UNIT_HR=%r" % PX, "--set", "SKY_GLOSSY_FACTOR=5.0"]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    with open(os.path.join(travail, "blender.log"), "w", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n" + p.stdout + "\n" + p.stderr)
    if p.returncode != 0 or "[FO-RENDER]" not in p.stdout:
        raise SystemExit("[FO-ICONE-ILM] ECHEC du rendu Blender, journal : %s" % travail)
    print("[FO-ICONE-ILM] rendu : %.1f s (%d échantillons)" % (time.time() - t0, samples))


def post(travail, sortie, fill):
    import numpy as np
    import fo_post as P
    pre = os.path.join(travail, "%s-J7" % PIECE["name"])
    with open(pre + "-render.json", encoding="utf-8") as f:
        info = json.load(f)
    main = np.load(pre + "-main.npy").astype(np.float64)
    ox, oy = info["origin_px"]
    s = int(PAS_IC * PX * 0.8)
    sums = {}
    os.makedirs(sortie, exist_ok=True)
    for c, fn in enumerate(FICHIERS):
        tx, ty = centre(c)
        x0, y0 = int(round(ox + tx * PX - s / 2)), int(round(oy + ty * PX - s / 2))
        cad = np.zeros((s, s, 4))
        H, W = main.shape[:2]
        xa, xb, ya, yb = max(0, x0), min(W, x0 + s), max(0, y0), min(H, y0 + s)
        cad[ya - y0:yb - y0, xa - x0:xb - x0] = main[ya:yb, xa:xb]
        sums[fn] = P.write_png(P.floor_alpha(P.icon_strip(cad, fill=fill)), os.path.join(sortie, fn))
    print("[FO-ICONE-ILM] 4 icônes (120 x 64) dans %s" % sortie)
    return info, sums


def installer(travail, sortie):
    """Copie les 4 icônes dans graphics/ressources/ilmenite et met à jour les sommes et la rubrique « icones » du
    MANIFEST.json de la feuille (check_gisement.py les relit)."""
    import shutil
    dest = os.path.join(MOD, "graphics", "ressources", "ilmenite")
    mp = os.path.join(dest, "MANIFEST.json")
    with open(mp, encoding="utf-8") as f:
        man = json.load(f)
    with open(os.path.join(travail, "%s-J7-render.json" % PIECE["name"]), encoding="utf-8") as f:
        info = json.load(f)
    for fn in FICHIERS:
        shutil.copyfile(os.path.join(sortie, fn), os.path.join(dest, fn))
        with open(os.path.join(dest, fn), "rb") as f:
            man["sha256"][fn] = hashlib.sha256(f.read()).hexdigest()
    man["sha256"] = dict(sorted(man["sha256"].items()))
    man["icones"] = {"rendu": "tools/render/pieces/ressources/icone_ilmenite.py (forme J7, morceaux posés, relief)",
                     "echantillons": info.get("samples"), "secondes_blender": info.get("seconds"),
                     "px_par_tuile": PX}
    with open(mp, "w", encoding="utf-8", newline=chr(10)) as f:
        json.dump(man, f, indent=1, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print("[FO-ICONE-ILM] installées dans %s (MANIFEST.json mis à jour)" % dest)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--travail", required=True)
    ap.add_argument("--sortie", default=None)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--fill", type=float, default=0.97)
    ap.add_argument("--post-seul", action="store_true")
    ap.add_argument("--installer", action="store_true")
    a = ap.parse_args()
    sortie = a.sortie or os.path.join(a.travail, "icones")
    if a.installer:
        installer(a.travail, sortie)
        return
    if not a.post_seul:
        rendre(a.travail, a.samples)
    post(a.travail, sortie, a.fill)


if __name__ == "__main__":
    main()
