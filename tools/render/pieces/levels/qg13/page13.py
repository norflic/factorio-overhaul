"""PAGE LOCALE du QG âge 13 (pas d'artefact : un .html posé à côté des images, ouvert au DC par « start »).

    py -3.9 tools/render/pieces/levels/qg13/page13.py <dossier age13> <fichier json des textes>

Le json donne : titre, da (liste de lignes citées), images [(fichier, légende)], mesures (texte préformaté),
notes (liste de paragraphes), defauts (liste).
"""
import html
import json
import os
import sys


def main():
    d = sys.argv[1]
    t = json.load(open(sys.argv[2], encoding="utf-8"))
    e = html.escape
    out = ["<!doctype html><html lang='fr'><head><meta charset='utf-8'>",
           "<meta name='viewport' content='width=device-width, initial-scale=1'>",
           "<title>QG âge 13 Fusion</title><style>",
           ":root{--bg:#16161a;--fg:#e8e6e1;--mut:#a9a49a;--acc:#ffcd78;--card:#202026}",
           "body{background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif;margin:0;padding:16px}",
           "h1{color:var(--acc);font-size:22px;margin:0 0 8px}h2{font-size:17px;color:var(--acc);margin:22px 0 6px}",
           "blockquote{margin:6px 0;padding:6px 12px;border-left:3px solid var(--acc);background:var(--card);color:var(--fg)}",
           "figure{margin:10px 0;background:var(--card);padding:8px;border-radius:6px;overflow-x:auto}",
           "figure img{display:block;max-width:none;image-rendering:auto}figcaption{color:var(--mut);margin-top:4px}",
           "pre{background:var(--card);padding:10px;overflow-x:auto;font-size:13px}li{margin:3px 0}",
           "</style></head><body>",
           "<h1>%s</h1>" % e(t["titre"])]
    out.append("<h2>Âge et DA (citation de docs/DESIGN_EPOQUES.md)</h2>")
    for l in t["da"]:
        out.append("<blockquote>%s</blockquote>" % e(l))
    out.append("<h2>Images</h2>")
    for f, cap in t["images"]:
        out.append("<figure><a href='%s'><img src='%s' alt='%s'></a><figcaption>%s</figcaption></figure>"
                   % (e(f), e(f), e(cap), e(cap)))
    out.append("<h2>Mesures contre les cibles du BRIEF</h2><pre>%s</pre>" % e(t["mesures"]))
    out.append("<h2>Ce qui a été fait</h2><ul>%s</ul>" % "".join("<li>%s</li>" % e(p) for p in t["notes"]))
    out.append("<h2>Défauts restants (dits franchement)</h2><ul>%s</ul>" % "".join("<li>%s</li>" % e(p) for p in t["defauts"]))
    out.append("</body></html>")
    p = os.path.join(d, "index.html")
    open(p, "w", encoding="utf-8").write("\n".join(out))
    print(p)


if __name__ == "__main__":
    main()
