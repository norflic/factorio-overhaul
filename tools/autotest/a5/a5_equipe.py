"""Lot A5-ESSAI (25/10) : masque d'équipe de la mitrailleuse sur de PETITES pièces, ESSAI sur 3 âges. Python 3.9.

    py -3.9 tools/autotest/a5/a5_equipe.py rendre --ages 3,9,15 --groupes G.json --out DIR [--samples 32]
        [--dirs 0-63] [--socle]
        Couverture visible de chaque groupe de pièces (a5_equipe_blender.py), UNE session Blender par âge, l'une
        après l'autre, par le verrou de rendu (interdit n° 6 : une place, priorité basse). Journal : DIR/blender-eNN.log.
    py -3.9 tools/autotest/a5/a5_equipe.py diag --rendu DIR --out PNG [--dirs 0,8,16,24]
        Planche de diagnostic : chaque groupe en magenta sur la tête de PRODUCTION assombrie (où sont les pièces ?).

Les poses de PRODUCTION (images de base, inchangées) : d00 = tete-N et d16 = tete-E (sources validées V3-E), d32 et d48
(lot A2), les 60 autres (lot A3) ; même table que feuilles.py.
"""
import argparse
import json
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
RENDER = os.path.join(MOD, "tools", "render")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
SCRIPT = os.path.join(HERE, "a5_equipe_blender.py")
LOGS = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
VALIDES = {range(1, 10): os.path.join(LOGS, "2026-10-23_V3E-p5", "bas", "sprites"),
           range(10, 13): os.path.join(LOGS, "2026-10-23_V3E-p5", "haut", "sprites"),
           range(13, 16): os.path.join(LOGS, "2026-10-23_V3E-ereV", "sprites")}
SO = os.path.join(LOGS, "2026-10-24_A2", "sprites")
A3 = os.path.join(LOGS, "2026-10-24_A3", "sprites")


def plage(spec):
    res = []
    for x in [x for x in str(spec).split(",") if x]:
        a, b = x.split("-") if "-" in x else (x, x)
        res += list(range(int(a), int(b) + 1))
    return res


def source_pose(e, K):
    """(dossier de la pose, nom) de la pose de PRODUCTION K (0 à 63) de l'âge e, ou du socle (K = None)."""
    dv = [d for r, d in VALIDES.items() if e in r][0]
    if K is None:
        return os.path.join(dv, "e%02d-socle" % e), "e%02d-socle" % e
    if K == 0:
        return os.path.join(dv, "e%02d-tete-N" % e), "e%02d-tete-N" % e
    if K == 16:
        return os.path.join(dv, "e%02d-tete-E" % e), "e%02d-tete-E" % e
    if K in (32, 48):
        return os.path.join(SO, "e%02d-tete-d%02d" % (e, K)), "e%02d-tete-d%02d" % (e, K)
    return os.path.join(A3, "e%02d-tete-d%02d" % (e, K)), "e%02d-tete-d%02d" % (e, K)


def couche_prod(e, K, lay="main"):
    """Couche hr de production : (image RGBA uint8, gauche, haut) en px hr relatifs à l'origine."""
    d, nom = source_pose(e, K)
    s = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
    L = s["layers"][lay]
    im = np.asarray(Image.open(os.path.join(d, L["file"])).convert("RGBA"))
    gx = int(round(L["shift"][0] * 64 - L["width"] / 2.0))
    gy = int(round(L["shift"][1] * 64 - L["height"] / 2.0))
    return im, gx, gy, s


def recadre(npz, cle, gx, gy, w, h):
    """Recadre la passe de couverture (canevas Blender) sur la boîte de la couche de production."""
    ox, oy = [int(v) for v in npz["origin"]]
    a = npz[cle]
    x0, y0 = ox + gx, oy + gy
    out = np.zeros((h, w), a.dtype)
    ys0, xs0 = max(0, -y0), max(0, -x0)
    ys1, xs1 = min(h, a.shape[0] - y0), min(w, a.shape[1] - x0)
    if ys1 > ys0 and xs1 > xs0:
        out[ys0:ys1, xs0:xs1] = a[y0 + ys0:y0 + ys1, x0 + xs0:x0 + xs1]
    return out


def rendre(a):
    os.makedirs(a.out, exist_ok=True)
    for e in plage(a.ages):
        cmd = [sys.executable, LOCK, "--slots", "2", "--priority", "below", "--disque", a.out, "--", BLENDER, "-b",
               "--factory-startup", "-noaudio", "--python-exit-code", "1", "-P", SCRIPT, "--", "--ages", str(e),
               "--out", a.out, "--groupes", os.path.abspath(a.groupes), "--samples", str(a.samples), "--dirs", a.dirs]
        if a.socle:
            cmd.append("--socle")
        t0 = time.time()
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           env=dict(os.environ, PYTHONIOENCODING="utf-8"))
        txt = p.stdout.decode("utf-8", "replace")
        with open(os.path.join(a.out, "blender-e%02d%s.log" % (e, "-socle" if a.socle else "")), "w",
                  encoding="utf-8") as f:
            f.write(txt)
        for ln in txt.splitlines():
            if ln.startswith("[FO-A5]") or "Traceback" in ln or "Error" in ln or ln.startswith("[fo-render]"):
                print(ln, flush=True)
        print("[A5] âge %d : code %d en %.0f s" % (e, p.returncode, time.time() - t0), flush=True)
        if p.returncode:
            return p.returncode
    return 0


def accord_silhouette(al, im):
    """Part des pixels de l'union des silhouettes (alpha ≥ 0,5) où Blender et la production sont d'accord."""
    pb, pa = al > 127, im[..., 3] > 127
    u = (pa | pb).sum()
    return float((pa & pb).sum()) / max(1, float(u))


def diag(a):
    """Une planche par âge (<out>-eNN.png) : une case par groupe présent, les directions côte à côte."""
    dirs = plage(a.dirs)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    for de in sorted(os.listdir(a.rendu)):
        if not (de.startswith("e") and os.path.isdir(os.path.join(a.rendu, de))):
            continue
        e = int(de[1:])
        if a.ages and e not in plage(a.ages):
            continue
        j = json.load(open(os.path.join(a.rendu, de, "equipe.json"), encoding="utf-8"))
        groupes = [g for g in sorted(j["groupes"]) if not j["etiquettes_absentes"][g]
                   and (not a.seulement or g in a.seulement.split(","))]
        prod = {}
        for K in dirs:
            im, gx, gy, s = couche_prod(e, K)
            z = np.load(os.path.join(a.rendu, de, "e%02d-d%02d.npz" % (e, K)))
            h, w = im.shape[:2]
            al = recadre(z, "alpha", gx, gy, w, h)
            print("[A5-DIAG] e%02d d%02d : silhouettes Blender / production d'accord sur %.2f %% de l'union" % (
                e, K, 100 * accord_silhouette(al, im)))
            prod[K] = (im, gx, gy, z)
        cases = []
        for g in groupes:
            vues = []
            for K in dirs:
                im, gx, gy, z = prod[K]
                h, w = im.shape[:2]
                c = recadre(z, "g_" + g, gx, gy, w, h).astype(np.float64) / 255.0
                base = im[..., :3].astype(np.float64) * 0.5
                rgb = base * (1 - c[..., None]) + np.array([255.0, 0.0, 255.0]) * c[..., None]
                t = np.concatenate([rgb, im[..., 3:4].astype(np.float64)], -1).astype(np.uint8)
                vues.append((Image.fromarray(t, "RGBA"), int((c > 0.5).sum())))
            W = sum(v[0].size[0] for v in vues) + 4 * len(vues)
            H = max(v[0].size[1] for v in vues) + 14
            case = Image.new("RGBA", (W, H), (36, 40, 36, 255))
            x = 0
            for v, n in vues:
                case.alpha_composite(v, (x, 14))
                x += v.size[0] + 4
            ImageDraw.Draw(case).text((2, 1), "%s  %s px" % (g, "/".join(str(v[1]) for v in vues)),
                                      fill=(255, 255, 255, 255))
            k = min(a.echelle, float(a.case) / W)
            cases.append(case.resize((max(1, int(W * k)), max(1, int(H * k))), Image.LANCZOS) if k != 1 else case)
        ncol = a.colonnes
        cw = max(c.size[0] for c in cases)
        ch = max(c.size[1] for c in cases)
        nl = (len(cases) + ncol - 1) // ncol
        planche = Image.new("RGBA", (ncol * cw, nl * ch), (24, 24, 24, 255))
        for i, c in enumerate(cases):
            planche.alpha_composite(c, ((i % ncol) * cw, (i // ncol) * ch))
        out = "%s-e%02d.png" % (os.path.splitext(a.out)[0], e)
        planche.convert("RGB").save(out, optimize=True)
        print("[A5-DIAG] %s : %d × %d (%d groupes)" % (out, planche.size[0], planche.size[1], len(cases)))
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("rendre")
    r.add_argument("--ages", required=True)
    r.add_argument("--groupes", required=True)
    r.add_argument("--out", required=True)
    r.add_argument("--samples", type=int, default=32)
    r.add_argument("--dirs", default="0-63")
    r.add_argument("--socle", action="store_true")
    d = sub.add_parser("diag")
    d.add_argument("--rendu", required=True)
    d.add_argument("--out", required=True)
    d.add_argument("--dirs", default="8,24")
    d.add_argument("--case", type=int, default=520, help="largeur maximale d'une case (px)")
    d.add_argument("--colonnes", type=int, default=5)
    d.add_argument("--seulement", default="", help="groupes à montrer (liste séparée par des virgules)")
    d.add_argument("--ages", default="")
    d.add_argument("--echelle", type=float, default=1.0, help="agrandissement maximal d'une case")
    a = ap.parse_args()
    return {"rendre": rendre, "diag": diag}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
