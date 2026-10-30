"""Page HTML LOCALE d'une planche du mur (MUR-OPUS) : images relatives, aucun lien externe.

    py -3.9 tools/render/pieces/levels/mur_o/page.py --dir <dossier de la planche> --titre "Mur v1" [--notes FICHIER.md]
"""
import argparse
import html
import os

IMAGES = (("planche-zoom1.png", "Zoom 1 (32 px/tuile) : vanilla, âges 2, 8 et 15, même tracé"),
          ("planche-zoom2.png", "Zoom 2 (64 px/tuile) : chaque âge à côté du mur vanilla"),
          ("planche-gros-plan.png", "Gros plan : bout, courtine, bout (zoom 2 agrandi ×2)"),
          ("planche-gris.png", "Test du gris (D1-1), zoom 1"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--titre", default="Mur")
    ap.add_argument("--notes", default="")
    a = ap.parse_args()
    notes = ""
    if a.notes and os.path.exists(a.notes):
        notes = "<pre>%s</pre>" % html.escape(open(a.notes, encoding="utf-8").read())
    figs = "\n".join('<figure><figcaption>%s</figcaption><a href="%s"><img src="%s" alt="%s"></a></figure>'
                     % (html.escape(t), f, f, html.escape(t)) for f, t in IMAGES
                     if os.path.exists(os.path.join(a.dir, f)))
    page = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>
:root { --fond: #16161a; --texte: #e6e6e6; --accent: #f0c878; }
body { background: var(--fond); color: var(--texte); font: 15px/1.5 system-ui, sans-serif; margin: 0 16px 40px; }
h1 { color: var(--accent); font-size: 22px; }
figure { margin: 24px 0; } figcaption { margin-bottom: 6px; color: var(--accent); }
img { max-width: 100%%; height: auto; image-rendering: pixelated; border: 1px solid #333; }
pre { white-space: pre-wrap; background: #1f1f25; padding: 12px; border-radius: 6px; }
</style></head><body>
<h1>%s</h1>
%s
%s
</body></html>
""" % (html.escape(a.titre), html.escape(a.titre), figs, notes)
    out = os.path.join(a.dir, "index.html")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("[FO-PAGE] %s" % out)


if __name__ == "__main__":
    main()
