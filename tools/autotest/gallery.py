#!/usr/bin/env python3
r"""
Index et planche-contact d'une session de captures (lot P1).

    python tools/autotest/gallery.py <dossier fo-shots> [--titre "texte"]

Lit index.tsv et plan.txt écrits par le mod de test (shots.lua), vérifie chaque capture (décodage PNG
complet) et écrit dans le même dossier :
  - index.txt          : une ligne par capture (numéro, fichier, scène, zoom, heure du jour, tick, taille, état) ;
  - planche-NN.png     : vignettes légendées, 48 par planche, dans l'ordre des numéros.
Code de sortie : 0 si toutes les captures prévues sont présentes et lisibles, 4 sinon.
Dépendance : Pillow (python -m pip install --user pillow).
"""
import argparse
import os
import sys

COLUMNS = ["num", "fichier", "scene", "x", "y", "zoom", "daytime", "tick", "resolution", "alt_mode", "anti_alias"]

THUMB_W, THUMB_H = 384, 216
COLS, PER_PAGE = 6, 48
PAD, LABEL_H = 8, 34


def heure(daytime):
    """Libellé de l'heure du jour (surface.daytime : 0 = midi, 0,5 = minuit)."""
    d = float(daytime) % 1.0
    if 0.25 < d < 0.75:
        return "nuit" if abs(d - 0.5) < 0.2 else "crepuscule"
    return "jour"


def read_plan(shots):
    p = os.path.join(shots, "plan.txt")
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8", errors="replace") as f:
        txt = f.read().strip()
    try:
        return int(txt.split()[0])
    except (ValueError, IndexError):
        return None


def read_index(shots):
    p = os.path.join(shots, "index.tsv")
    rows = []
    if not os.path.exists(p):
        return rows
    with open(p, encoding="utf-8", errors="replace") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if not parts or parts[0] in ("", "num"):
                continue
            row = dict(zip(COLUMNS, parts))
            rows.append(row)
    rows.sort(key=lambda r: r["num"])
    return rows


def validate(shots):
    """Vérifie chaque capture listée : présente et décodable en entier. Renvoie (lignes, problèmes)."""
    from PIL import Image
    rows = read_index(shots)
    problems = []
    for r in rows:
        path = os.path.join(shots, r["fichier"])
        r["ok"] = False
        if not os.path.exists(path):
            r["etat"] = "absente"
            problems.append(r["fichier"] + " : absente")
            continue
        try:
            with Image.open(path) as im:
                im.load()
                r["w"], r["h"] = im.size
            r["octets"] = os.path.getsize(path)
            r["ok"] = True
            r["etat"] = "OK"
        except Exception as exc:  # fichier en cours d'écriture ou tronqué
            r["etat"] = "illisible"
            problems.append(r["fichier"] + " : illisible (" + type(exc).__name__ + ")")
    plan = read_plan(shots)
    if plan is None:
        problems.append("plan.txt absent : nombre de captures prevues inconnu")
    elif plan != len(rows):
        problems.append("%d captures prevues, %d demandees" % (plan, len(rows)))
    return rows, problems


def write_index(shots, rows, problems, titre):
    plan = read_plan(shots)
    ok = sum(1 for r in rows if r.get("ok"))
    lines = [
        "Index des captures : " + titre,
        "Prevues : %s ; demandees : %d ; presentes et lisibles : %d" % (plan if plan is not None else "?", len(rows), ok),
        "",
        "%-4s %-58s %-7s %-10s %-7s %-11s %-12s %s" % ("num", "fichier", "zoom", "heure", "tick", "resolution", "octets", "etat"),
    ]
    for r in rows:
        lines.append("%-4s %-58s %-7s %-10s %-7s %-11s %-12s %s" % (
            r["num"], r["fichier"], "%.2f" % float(r["zoom"]), heure(r["daytime"]), r["tick"],
            r.get("resolution", ""), r.get("octets", "-"), r.get("etat", "?")))
    if problems:
        lines += ["", "PROBLEMES :"] + ["  - " + p for p in problems]
    path = os.path.join(shots, "index.txt")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return path


def contact_sheets(shots, rows, titre):
    from PIL import Image, ImageDraw, ImageFont
    try:
        font = ImageFont.load_default(size=13)
        font_t = ImageFont.load_default(size=18)
    except TypeError:  # Pillow < 10.1
        font = font_t = ImageFont.load_default()
    for name in os.listdir(shots):
        if name.startswith("planche-") and name.endswith(".png"):
            os.remove(os.path.join(shots, name))
    pages = [rows[i:i + PER_PAGE] for i in range(0, len(rows), PER_PAGE)] or [[]]
    out = []
    head = 36
    for n, page in enumerate(pages, 1):
        nrows = max(1, (len(page) + COLS - 1) // COLS)
        W = PAD + COLS * (THUMB_W + PAD)
        H = head + PAD + nrows * (THUMB_H + LABEL_H + PAD)
        sheet = Image.new("RGB", (W, H), (32, 32, 34))
        d = ImageDraw.Draw(sheet)
        d.text((PAD, 8), "%s  -  planche %d/%d  -  %d captures" % (titre, n, len(pages), len(rows)), fill=(235, 235, 235), font=font_t)
        for k, r in enumerate(page):
            cx = PAD + (k % COLS) * (THUMB_W + PAD)
            cy = head + PAD + (k // COLS) * (THUMB_H + LABEL_H + PAD)
            d.rectangle([cx, cy, cx + THUMB_W - 1, cy + THUMB_H - 1], fill=(16, 16, 16))
            if r.get("ok"):
                with Image.open(os.path.join(shots, r["fichier"])) as im:
                    im = im.convert("RGB")
                    im.thumbnail((THUMB_W, THUMB_H), Image.LANCZOS)
                    sheet.paste(im, (cx + (THUMB_W - im.width) // 2, cy + (THUMB_H - im.height) // 2))
            else:
                d.text((cx + 10, cy + THUMB_H // 2 - 8), "CAPTURE " + r.get("etat", "?").upper(), fill=(255, 90, 90), font=font_t)
            label1 = (r["num"] + " " + r["scene"])[:52]
            label2 = "zoom %.2f  %s  tick %s" % (float(r["zoom"]), heure(r["daytime"]), r["tick"])
            d.text((cx, cy + THUMB_H + 2), label1, fill=(230, 230, 230), font=font)
            d.text((cx, cy + THUMB_H + 17), label2, fill=(160, 160, 160), font=font)
        path = os.path.join(shots, "planche-%02d.png" % n)
        sheet.save(path, optimize=True)
        out.append(path)
    return out


def build(shots, titre="captures"):
    """Valide, écrit l'index et les planches. Renvoie (lignes, problèmes, chemin de l'index, planches)."""
    rows, problems = validate(shots)
    idx = write_index(shots, rows, problems, titre)
    sheets = contact_sheets(shots, rows, titre)
    return rows, problems, idx, sheets


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("shots", help="dossier fo-shots (script-output/fo-shots)")
    ap.add_argument("--titre", default=None)
    a = ap.parse_args()
    titre = a.titre or os.path.basename(os.path.abspath(a.shots))
    rows, problems, idx, sheets = build(a.shots, titre)
    ok = sum(1 for r in rows if r.get("ok"))
    print("index : " + idx)
    for s in sheets:
        print("planche : " + s)
    print("captures prevues %s, lisibles %d" % (read_plan(a.shots), ok))
    for p in problems:
        print("PROBLEME : " + p)
    return 0 if not problems and ok == len(rows) and rows else 4


if __name__ == "__main__":
    sys.exit(main())
