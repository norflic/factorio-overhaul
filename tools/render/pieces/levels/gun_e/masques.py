"""Lot A3 (24/10) : masques rapides des têtes de la mitrailleuse (64 directions × âges 2 à 15), trous enfermés et
bouchon arrière (décision D-10). Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/masques.py rendre  --out DIR [--ages 2-15] [--samples 16] [--sessions 2]
    py -3.9 tools/render/pieces/levels/gun_e/masques.py valider --masques DIR [--valide 1-9=DIR …] [--so DIR]
    py -3.9 tools/render/pieces/levels/gun_e/masques.py trous   --masques DIR [--secteur 20-44] [--dest DIR]
    py -3.9 tools/render/pieces/levels/gun_e/masques.py bouchon --masques DIR [--dest DIR]

rendre  : masques_blender.py par le verrou de rendu (interdit n° 6), --sessions sessions en parallèle (2 au plus),
          un âge par paquet ; sorties <out>/eNN/eNN-dKK.npz (voir masques_blender.py).
valider : compare l'alpha des masques à l'alpha de PRODUCTION des poses déjà rendues (d00 = tete-N et d16 = tete-E
          validées, d32 et d48 du lot A2 ; bouchon posé en d32 aux âges 4 à 7, comme en production) : pixels dont
          l'alpha franchit 0,5 de la même façon (taux sur l'union des silhouettes), écart d'alpha 8 bits, plus grand trou
          enfermé du masque contre celui de la production (spec.json « checks », calculé sur la passe brute) et contre
          celui recalculé sur le PNG de production.
trous   : plus grand trou enfermé (règle des rendus : alpha < 0,5 non relié au bord en 4-connexité, plus grande
          composante, ≤ 8 px hr) pour chaque âge et direction, avec la règle du bouchon de piece.py (secteur donné par
          --secteur, défaut celui de piece.BOUCHON_SECTEUR) ; table et liste des échecs.
bouchon : âges 4 à 7, 64 directions : trou SANS bouchon, pixels VISIBLES du bouchon (couverture ≥ 0,5 au premier plan),
          trou AVEC bouchon ; secteur = directions où le trou sans bouchon dépasse 8 px (règle d'A1) ; saut aux bords.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import piece  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
SCRIPT = os.path.join(HERE, "masques_blender.py")
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
VALIDES = ["1-9=" + os.path.join(LOGS, "2026-10-23_V3E-p5", "bas", "sprites"),
           "10-12=" + os.path.join(LOGS, "2026-10-23_V3E-p5", "haut", "sprites"),
           "13-15=" + os.path.join(LOGS, "2026-10-23_V3E-ereV", "sprites")]
SO = os.path.join(LOGS, "2026-10-24_A2", "sprites")
SEUIL_TROU = 8
QUATRE = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)


def plage(spec):
    res = []
    for x in [x for x in str(spec).split(",") if x]:
        a, b = x.split("-") if "-" in x else (x, x)
        res += list(range(int(a), int(b) + 1))
    return res


def plages(specs):
    res = {}
    for s in specs:
        p, d = s.split("=", 1)
        for e in plage(p):
            res[e] = d
    return res


def plus_grand_trou(alpha01, thr=0.5):
    """Même règle que rendre.largest_hole (fo_checks.enclosed_transparent + da_lib.components en 4-connexité) :
    pixels d'alpha < thr non reliés au bord en 4-connexité ; renvoie (pixels enfermés, groupes, plus grand)."""
    free = np.asarray(alpha01) < thr
    lab, n = ndimage.label(free, structure=QUATRE)
    if not n:
        return 0, 0, 0
    bord = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    tailles = np.bincount(lab.ravel())
    trous = [k for k in range(1, n + 1) if k not in bord]
    if not trous:
        return 0, 0, 0
    t = tailles[trous]
    return int(t.sum()), len(trous), int(t.max())


AUTRES = {}   # âge -> dossier de masques prioritaire (option --age-masques 4-7=DIR)


def charge(masques, e, d):
    base = AUTRES.get(e, masques)
    z = np.load(os.path.join(base, "e%02d" % e, "e%02d-%s.npz" % (e, d)))
    return {k: z[k] for k in z.files}


def alpha_prod(z, e, d, secteur=None):
    """Alpha (0..1) de la pose telle que la production la rendrait : bouchon posé selon la règle de piece.py."""
    a = z["alpha"]
    if "alpha_sans" in z and not pose_bouchon(e, d, secteur):
        a = z["alpha_sans"]
    return a.astype(np.float64) / 255.0


def pose_bouchon(e, d, secteur=None):
    """Le bouchon est-il posé dans la pose d ? Règle de production (piece.bouchon, sans FO_BOUCHON), ou secteur
    imposé (--secteur, essais)."""
    if e not in piece.BOUCHON_AGES:
        return False
    if secteur is not None:
        return int(d[1:]) in secteur
    ancien = os.environ.pop("FO_BOUCHON", None)
    try:
        return piece.bouchon(e, d)
    finally:
        if ancien is not None:
            os.environ["FO_BOUCHON"] = ancien


# ------------------------------------------------------------------------------------------------ rendre
def rendre(a):
    ages = plage(a.ages)
    os.makedirs(a.out, exist_ok=True)

    def un(e):
        cmd = [sys.executable, LOCK, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
               "-P", SCRIPT, "--", "--ages", str(e), "--out", a.out, "--samples", str(a.samples), "--dirs", a.dirs]
        t0 = time.time()
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=dict(os.environ,
                                                                                         PYTHONIOENCODING="utf-8"))
        txt = p.stdout.decode("utf-8", "replace")
        with open(os.path.join(a.out, "blender-e%02d.log" % e), "w", encoding="utf-8") as f:
            f.write(txt)
        for ln in txt.splitlines():
            if ln.startswith("[FO-MASQUES]") or "Traceback" in ln or "Error" in ln:
                print(ln, flush=True)
        return e, p.returncode, time.time() - t0

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=max(1, min(2, a.sessions))) as ex:
        res = list(ex.map(un, sorted(ages, key=lambda e: -e)))
    bad = [r for r in res if r[1]]
    print("[FO-MASQUES] %d âges en %.0f s d'horloge (%d session(s)) ; échecs : %s" % (
        len(ages), time.time() - t0, a.sessions, bad or "aucun"), flush=True)
    return 1 if bad else 0


# ------------------------------------------------------------------------------------------------ valider
def prod_alpha_canvas(d_sprite, nom, canvas, origin):
    s = json.load(open(os.path.join(d_sprite, nom, "spec.json"), encoding="utf-8"))
    L = s["layers"]["main"]
    im = np.asarray(Image.open(os.path.join(d_sprite, nom, L["file"])).convert("RGBA"))
    W, H = int(canvas[0]), int(canvas[1])
    ox, oy = int(origin[0]), int(origin[1])
    x0 = int(round(ox + L["shift"][0] * 64 - L["width"] / 2))
    y0 = int(round(oy + L["shift"][1] * 64 - L["height"] / 2))
    out = np.zeros((H, W), np.uint8)
    h, w = im.shape[:2]
    xa, ya = max(0, x0), max(0, y0)
    xb, yb = min(W, x0 + w), min(H, y0 + h)
    perdu = int((im[..., 3] > 0).sum())
    out[ya:yb, xa:xb] = im[ya - y0:yb - y0, xa - x0:xb - x0, 3]
    perdu -= int((out > 0).sum())
    return out, s, perdu


def valider(a):
    V = plages(a.valide or VALIDES)
    poses = []
    for e in range(2, 16):
        poses += [(e, "d00", V[e], "e%02d-tete-N" % e), (e, "d16", V[e], "e%02d-tete-E" % e),
                  (e, "d32", a.so, "e%02d-tete-d32" % e), (e, "d48", a.so, "e%02d-tete-d48" % e)]
    lignes = ["Masques rapides contre alpha de PRODUCTION (%s)" % a.masques,
              "pose            bouchon  union   identiques(>=0,5)  alpha8 egal  ecart max  trou masque / spec / png prod"]
    tot_u = tot_id = tot_px = tot_eq = 0
    trous_ok = 0
    pires = []
    for e, d, src, nom in poses:
        z = charge(a.masques, e, d)
        am = (alpha_prod(z, e, d) * 255).round().astype(np.uint8)
        ap, spec, perdu = prod_alpha_canvas(src, nom, z["canvas"], z["origin"])
        bm, bp = am >= 128, ap >= 128
        union = bm | bp
        nu = int(union.sum())
        nid = int((bm == bp)[union].sum())
        sil = (am > 0) | (ap > 0)
        eq = int((am == ap)[sil].sum())
        dif = int(np.abs(am.astype(int) - ap.astype(int)).max())
        tm = plus_grand_trou(am / 255.0)[2]
        tp = plus_grand_trou(ap / 255.0)[2]
        ts = spec["checks"]["largest_hole_px"]
        tot_u += nu
        tot_id += nid
        tot_px += int(sil.sum())
        tot_eq += eq
        same_rule = (tm <= SEUIL_TROU) == (ts <= SEUIL_TROU)
        trous_ok += same_rule
        pires.append((nu - nid, nom))
        lignes.append("%-15s %-7s %7d   %7d (%6.3f %%)  %6.2f %%   %4d       %4d / %4d / %4d %s%s" % (
            "e%02d-%s" % (e, d), "oui" if pose_bouchon(e, d) else "non", nu, nid, 100.0 * nid / max(1, nu),
            100.0 * eq / max(1, int(sil.sum())), dif, tm, ts, tp, "" if same_rule else "  REGLE DIFFERENTE",
            "  (%d px hors canevas)" % perdu if perdu else ""))
    lignes.append("")
    lignes.append("BILAN : %d poses ; pixels binaires (alpha >= 0,5) identiques : %d / %d = %.4f %% de l'union des "
                  "silhouettes ; alpha 8 bits identique : %.2f %% des pixels non nuls ; verdict de la règle des trous "
                  "(<= %d px) identique : %d / %d" % (len(poses), tot_id, tot_u, 100.0 * tot_id / max(1, tot_u),
                                                       100.0 * tot_eq / max(1, tot_px), SEUIL_TROU, trous_ok,
                                                       len(poses)))
    pires.sort(reverse=True)
    lignes.append("poses les moins fidèles (pixels binaires différents) : %s" % ", ".join(
        "%s %d" % (n, k) for k, n in pires[:6]))
    txt = "\n".join(lignes)
    print(txt)
    if a.dest:
        os.makedirs(a.dest, exist_ok=True)
        open(os.path.join(a.dest, "validation.txt"), "w", encoding="utf-8").write(txt + "\n")
    return 0


# ------------------------------------------------------------------------------------------------ trous
def trous(a):
    secteur = plage(a.secteur) if a.secteur else None
    lignes = ["Plus grand trou enfermé (px hr, couche principale, masques %s) ; * = ECHEC (> %d px) ; "
              "b = bouchon posé (secteurs %s) ; masques par âge : %s" % (
                  a.masques, SEUIL_TROU, a.secteur or "piece.BOUCHON_SECTEURS %s, rampe %s" % (
                      piece.BOUCHON_SECTEURS, piece.BOUCHON_RAMPE), AUTRES or "aucun")]
    lignes.append("age  " + " ".join("%4d" % k for k in range(64)))
    echecs = []
    table = {}
    for e in range(2, 16):
        cells = []
        for k in range(64):
            d = "d%02d" % k
            z = charge(a.masques, e, d)
            n, g, big = plus_grand_trou(alpha_prod(z, e, d, secteur))
            table["e%02d-%s" % (e, d)] = {"enfermes": n, "groupes": g, "plus_grand": big,
                                          "bouchon": pose_bouchon(e, d, secteur)}
            c = "%3d%s" % (big, "*" if big > SEUIL_TROU else ("b" if pose_bouchon(e, d, secteur) else " "))
            cells.append(c)
            if big > SEUIL_TROU:
                echecs.append(("e%02d-%s" % (e, d), big, n, g))
        lignes.append("%3d  " % e + " ".join("%4s" % c for c in cells))
    lignes.append("")
    lignes.append("ECHECS : %d sur %d" % (len(echecs), 14 * 64))
    for nom, big, n, g in echecs:
        lignes.append("  %s plus grand %d px (%d px enfermés en %d groupes)" % (nom, big, n, g))
    txt = "\n".join(lignes)
    print(txt)
    if a.dest:
        os.makedirs(a.dest, exist_ok=True)
        open(os.path.join(a.dest, a.nom + ".txt"), "w", encoding="utf-8").write(txt + "\n")
        json.dump(table, open(os.path.join(a.dest, a.nom + ".json"), "w", encoding="utf-8"), indent=0,
                  sort_keys=True)
    return 0


# ------------------------------------------------------------------------------------------------ bouchon
def bouchon(a):
    lignes = ["D-10 : bouchon arrière, âges 4 à 7, 64 directions (masques %s)" % a.masques,
              "colonnes : direction ; trou SANS bouchon (px) ; pixels VISIBLES du bouchon (couverture >= 0,5 au "
              "premier plan) ; trou AVEC bouchon ; secteur (trou sans bouchon > %d px)" % SEUIL_TROU]
    res = {}
    for e in piece.BOUCHON_AGES:
        lignes.append("")
        lignes.append("âge %d" % e)
        lignes.append("  dir  trou_sans  visible  trou_avec  secteur")
        rows = []
        for k in range(64):
            d = "d%02d" % k
            z = charge(a.masques, e, d)
            ts = plus_grand_trou(z["alpha_sans"] / 255.0)[2]
            ta = plus_grand_trou(z["alpha"] / 255.0)[2]
            vis = int((z["bouchon"] >= 128).sum())
            rows.append({"dir": d, "trou_sans": ts, "visible": vis, "trou_avec": ta, "secteur": ts > SEUIL_TROU})
            lignes.append("  %s  %9d  %7d  %9d  %s" % (d, ts, vis, ta, "OUI" if ts > SEUIL_TROU else ""))
        sect = [r["dir"] for r in rows if r["secteur"]]
        ks = [int(x[1:]) for x in sect]
        bords = []
        if ks:
            k0, k1 = min(ks), max(ks)
            contigu = ks == list(range(k0, k1 + 1))
            bords = [("entrée", k0, rows[k0]["visible"], rows[k0 - 1]["visible"]),
                     ("sortie", k1, rows[k1]["visible"], rows[(k1 + 1) % 64]["visible"])]
            lignes.append("  secteur mesuré : d%02d à d%02d (%d directions%s)" % (
                k0, k1, len(ks), "" if contigu else ", NON CONTIGU : " + ",".join(sect)))
            for nom, k, vis_in, vis_out in bords:
                lignes.append("  bord %s d%02d : %d px de bouchon visibles dans la direction (saut à l'apparition ou à "
                              "la disparition) ; voisine hors secteur : %d px s'il y était" % (nom, k, vis_in,
                                                                                               vis_out))
        res[e] = {"rows": rows, "secteur": sect}
    txt = "\n".join(lignes)
    print(txt)
    if a.dest:
        os.makedirs(a.dest, exist_ok=True)
        open(os.path.join(a.dest, a.nom + ".txt"), "w", encoding="utf-8").write(txt + "\n")
        json.dump(res, open(os.path.join(a.dest, a.nom + ".json"), "w", encoding="utf-8"), indent=0)
    return 0


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    r = sp.add_parser("rendre")
    r.add_argument("--out", required=True)
    r.add_argument("--ages", default="2-15")
    r.add_argument("--dirs", default="0-63")
    r.add_argument("--samples", type=int, default=16)
    r.add_argument("--sessions", type=int, default=2)
    v = sp.add_parser("valider")
    v.add_argument("--masques", required=True)
    v.add_argument("--valide", action="append")
    v.add_argument("--so", default=SO)
    v.add_argument("--dest", default="")
    t = sp.add_parser("trous")
    t.add_argument("--masques", required=True)
    t.add_argument("--secteur", default="")
    t.add_argument("--dest", default="")
    t.add_argument("--nom", default="trous")
    b = sp.add_parser("bouchon")
    b.add_argument("--masques", required=True)
    b.add_argument("--dest", default="")
    b.add_argument("--nom", default="bouchon")
    for p in (v, t, b):
        p.add_argument("--age-masques", action="append", default=[],
                       help="âges=DIR : masques prioritaires pour ces âges (ex. 4-7=DIR de la rampe du bouchon)")
    a = ap.parse_args()
    AUTRES.update(plages(getattr(a, "age_masques", []) or []))
    return {"rendre": rendre, "valider": valider, "trous": trous, "bouchon": bouchon}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
