"""ICÔNES DU MINERAI DE CASSITÉRITE, faites sur la forme C14 (lot MINERAIS, 01/11).

DC (30/10, ~10 h 40) : « je viens de revoir les minerais, changez les icones mais si non c est pas mal ». La forme C14
(gisement) est acceptée ; son icône (cellule d'icône de feuille.py : UN bloc et ses pépites soudés en une masse brune) ne
l'était pas : à 32 px, une seule silhouette en gourde, sans jour entre les pièces, quand les icônes vanilla
(icons/iron-ore.png, coal.png : 64 px + 3 mipmaps) montrent 3 à 5 morceaux SÉPARÉS par un jour sombre qui remplissent
le cadre. Même démarche que les icônes de l'ilménite (icone_ilmenite.py) : pièces du gisement, mais POSÉES à la main.

Pièces du gisement C14 : blocs trapus de gisement.roche (6 coupes, cassure 0,45 à 0,80, aplat 0,95, lissé 25°) et
pépites bipyramidales de gisement.bipyramide (habitus de la cassitérite) ; matières C : brun, roux, cuir, ambre ; ciel
spéculaire × 5 (CALIB C9 à C14). Ajouts propres à l'icône, assumés : pièces posées (jour entre elles), relief de surface
(grain des icônes vanilla), faces au soleil plus claires que le gisement (cuir, roux) pour que l'icône ne se lise pas en
tache sombre à 32 px.

Rendu : 4 cellules (icône, puis les 3 images au sol) en UN appel de Blender, PAR LE VERROU, à 256 px par tuile, passe
main seule ; réduction en lumière linéaire prémultipliée (fo_post.icon_strip) en 64 + 32 + 16 + 8 = 120 x 64 px.

    python tools/render/with_render_lock.py -- py -3.9 tools/render/pieces/ressources/icone_cassiterite.py         --samples 128 --travail <dossier> --sortie <dossier des icônes>
    # post-traitement seul : --post-seul ; installation dans graphics/ressources/cassiterite : --installer
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

PIECE = {"name": "icone-cassiterite", "variants": {"C14": {}}, "margin_px": 32}
PAS_IC = 6.0          # écart entre deux cellules, en tuiles
PX = 256.0            # pixels par tuile du rendu des icônes
GRAINE = 7414
GROS = 1.0           # morceaux grossis (comme l'ilménite : à 32 px, le jour entre les pièces mange le cadre)
RUGOSITE = 0.16       # éclat adamantin : reflets nets sur les arêtes
RELIEF = 0.32
ECART = 1.08          # écarte les positions (jour entre les pièces)
FICHIERS = ("icone.png", "icone-1.png", "icone-2.png", "icone-3.png")
# Matières de l'icône : couleurs de directions.MAT, faces au soleil éclaircies pour la lecture à 32 px
MAT_BLOC = ("cassiterite_brun", "cassiterite_noir", "cassiterite_roux")
MAT_PEP = ("cassiterite_ambre", "cassiterite_roux", "cassiterite_cuir")
# Compositions (tuiles de jeu, y vers le sud, relatives au centre de la cellule).
#   blocs : (x, y, taille, matière, bosse) ; bosse : None ou (angle en degrés, taille relative) d'une bosse soudée ;
#   pepites : (x, y, longueur, largeur, inclinaison en degrés, azimut en degrés, matière).
COMPOS = [
    # icône : 3 blocs en quinconce, 3 pépites bipyramidales plantées entre eux
    dict(blocs=[(0.17, 0.17, 0.30, 0, (40, 0.55)), (-0.25, -0.20, 0.26, 1, (220, 0.5)), (-0.27, 0.25, 0.21, 2, None)],
         pepites=[(0.27, -0.25, 0.30, 0.24, 24, 20, 1), (-0.02, -0.04, 0.27, 0.22, 30, 200, 0),
                  (0.04, 0.34, 0.22, 0.18, 34, 100, 1)]),
    dict(blocs=[(-0.15, 0.10, 0.28, 1, (160, 0.55)), (0.26, 0.18, 0.22, 0, None), (-0.27, -0.22, 0.18, 2, None)],
         pepites=[(0.08, -0.24, 0.28, 0.22, 26, 60, 0), (0.30, -0.10, 0.20, 0.17, 30, 250, 2)]),
    dict(blocs=[(-0.12, 0.10, 0.27, 0, (150, 0.5)), (0.25, 0.14, 0.22, 2, None), (-0.30, -0.19, 0.17, 1, None)],
         pepites=[(0.06, -0.25, 0.27, 0.21, 28, 300, 1), (0.34, -0.20, 0.19, 0.16, 36, 120, 0),
                  (-0.02, 0.32, 0.20, 0.17, 32, 20, 2)]),
    dict(blocs=[(-0.22, -0.18, 0.26, 2, (120, 0.55)), (0.26, -0.10, 0.21, 0, None)],
         pepites=[(-0.08, 0.27, 0.27, 0.22, 25, 180, 0), (0.22, 0.26, 0.21, 0.17, 33, 330, 1),
                  (0.03, -0.06, 0.22, 0.18, 30, 90, 2)]),
]


def centre(c):
    return (PAS_IC * (c - 1.5), 0.0)


# ------------------------------------------------------------------------------------------------
# Blender (pièce lue par tools/render/blender/render_piece.py)
# ------------------------------------------------------------------------------------------------
def _matiere(S, D, nom):
    """Matière du gisement (directions.MAT) + relief de surface par bosselage (grain des icônes vanilla)."""
    m = D.MAT[nom]
    mat = S.mat_metal("cas_ic_" + nom, m["color"], rough=min(m["rough"], RUGOSITE), metallic=m["met"], grain=m["grain"],
                      grain_scale=m["gscale"], dirt=m["dirt"], dirt_distance=0.08)
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    nr = N.new("ShaderNodeTexNoise")
    nr.inputs["Scale"].default_value = 44.0
    nr.inputs["Detail"].default_value = 8.0
    nr.inputs["Roughness"].default_value = 0.7
    L.new(tc.outputs["Object"], nr.inputs["Vector"])
    vo = N.new("ShaderNodeTexVoronoi")
    vo.feature = "DISTANCE_TO_EDGE"
    vo.inputs["Scale"].default_value = 22.0
    L.new(tc.outputs["Object"], vo.inputs["Vector"])
    vm = N.new("ShaderNodeMapRange")
    vm.inputs["From Min"].default_value = 0.0
    vm.inputs["From Max"].default_value = 0.08
    L.new(vo.outputs["Distance"], vm.inputs["Value"])
    ad = N.new("ShaderNodeMath")
    ad.operation = "MULTIPLY_ADD"
    L.new(vm.outputs["Result"], ad.inputs[0])
    ad.inputs[1].default_value = 0.6
    L.new(nr.outputs["Fac"], ad.inputs[2])
    bu = N.new("ShaderNodeBump")
    bu.inputs["Strength"].default_value = RELIEF
    bu.inputs["Distance"].default_value = 0.012
    L.new(ad.outputs["Value"], bu.inputs["Height"])
    L.new(bu.outputs["Normal"], p.inputs["Normal"])
    return mat


def build(S, C, variant):
    import gisement as G   # noqa: E402  (importe bpy : seulement dans Blender)
    import directions as D  # noqa: E402
    cle = "C14"
    coupes, lisse = D.ROCHE_COUPES[cle], D.ROCHE_LISSE[cle]
    aplat, cassure = D.ROCHE_APLAT[cle], D.ROCHE_CASSURE[cle]
    mats = {nom: _matiere(S, D, nom) for nom in sorted(set(MAT_BLOC + MAT_PEP))}
    for c, compo in enumerate(COMPOS):
        rng = random.Random(GRAINE * 10 + c)
        cx, cy = centre(c)
        for i, (gx, gy, t, mi, b) in enumerate(compo["blocs"]):
            t = t * GROS
            gx, gy = gx * ECART, gy * ECART
            parts = [(gx, gy, t)]
            if b is not None:
                a = math.radians(b[0])
                parts.append((gx + 0.55 * t * math.cos(a), gy + 0.55 * t * math.sin(a) * 0.85, t * b[1]))
            for j, (px, py, tt) in enumerate(parts):
                v, f = G.roche(rng, tt, aplat=aplat, n_coupes=coupes, cassure=cassure)
                incl = math.radians(rng.uniform(0, 14))
                bx, by, _ = C.tile_to_blender(cx + px, cy + py)
                vv = G._transforme(v, incl, rng.uniform(0, 2 * math.pi), bx, by, -0.25 * tt * math.sin(incl))
                G._objet("cas_ic%d_b%d_%d" % (c, i, j), vv, f, mats[MAT_BLOC[mi]], S, lisse)
        for k, (gx, gy, L, larg, incl, az, mi) in enumerate(compo["pepites"]):
            gx, gy = gx * ECART, gy * ECART
            v, f = G.bipyramide(rng, L * GROS, larg * GROS)
            bx, by, _ = C.tile_to_blender(cx + gx, cy + gy)
            vv = G._transforme(v, math.radians(incl), math.radians(az), bx, by, -0.02)
            o = G._objet("cas_ic%d_p%d" % (c, k), vv, f, mats[MAT_PEP[mi]], S)
            S.bevel(o, 0.008, 1)


# ------------------------------------------------------------------------------------------------
# Python système : rendu par Blender (appelé sous le verrou) et post-traitement
# ------------------------------------------------------------------------------------------------
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")


def rendre(travail, samples):
    os.makedirs(travail, exist_ok=True)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", os.path.join(RENDER, "blender", "render_piece.py"), "--",
           "--piece", os.path.abspath(__file__), "--out", travail, "--variant", "C14", "--samples", str(samples),
           "--layers", "main", "--margin", "32",
           "--set", "PX_PER_UNIT_HR=%r" % PX, "--set", "SKY_GLOSSY_FACTOR=5.0"]
    t0 = time.time()
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    with open(os.path.join(travail, "blender.log"), "w", encoding="utf-8") as f:
        f.write(" ".join(cmd) + "\n" + p.stdout + "\n" + p.stderr)
    if p.returncode != 0 or "[FO-RENDER]" not in p.stdout:
        raise SystemExit("[FO-ICONE-CAS] ECHEC du rendu Blender, journal : %s" % travail)
    print("[FO-ICONE-CAS] rendu : %.1f s (%d échantillons)" % (time.time() - t0, samples))


def post(travail, sortie, fill):
    import numpy as np
    import fo_post as P
    pre = os.path.join(travail, "%s-C14" % PIECE["name"])
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
    print("[FO-ICONE-CAS] 4 icônes (120 x 64) dans %s" % sortie)
    return info, sums


def installer(travail, sortie):
    """Copie les 4 icônes dans graphics/ressources/cassiterite et met à jour les sommes et la rubrique « icones » du
    MANIFEST.json de la feuille (check_gisement.py les relit)."""
    import shutil
    dest = os.path.join(MOD, "graphics", "ressources", "cassiterite")
    mp = os.path.join(dest, "MANIFEST.json")
    with open(mp, encoding="utf-8") as f:
        man = json.load(f)
    with open(os.path.join(travail, "%s-C14-render.json" % PIECE["name"]), encoding="utf-8") as f:
        info = json.load(f)
    for fn in FICHIERS:
        shutil.copyfile(os.path.join(sortie, fn), os.path.join(dest, fn))
        with open(os.path.join(dest, fn), "rb") as f:
            man["sha256"][fn] = hashlib.sha256(f.read()).hexdigest()
    man["sha256"] = dict(sorted(man["sha256"].items()))
    man["icones"] = {"rendu": "tools/render/pieces/ressources/icone_cassiterite.py (forme C14, pièces posées, relief)",
                     "echantillons": info.get("samples"), "secondes_blender": info.get("seconds"),
                     "px_par_tuile": PX}
    with open(mp, "w", encoding="utf-8", newline=chr(10)) as f:
        json.dump(man, f, indent=1, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    print("[FO-ICONE-CAS] installées dans %s (MANIFEST.json mis à jour)" % dest)


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
