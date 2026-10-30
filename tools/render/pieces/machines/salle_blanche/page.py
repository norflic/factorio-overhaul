"""PAGE LOCALE du lot CALC-SALLE-BLANCHE (30/10) : assemble index.html à partir d'un fichier de contenu JSON
(sections : titre, texte HTML, images relatives au dossier de la page). Aucune page Artifact (consigne du DC, 29/10).

    py -3.9 tools/render/pieces/machines/salle_blanche/page.py --contenu contenu.json --out index.html
"""
import argparse
import html
import json
import os

CSS = """
:root{--bg:#1d1f22;--fg:#e8e6e1;--mut:#a9a6a0;--acc:#3aa8ff;--amb:#ffb347;--card:#26292d;--bd:#3a3e44}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,Segoe UI,Arial,sans-serif}
main{max-width:1500px;margin:0 auto;padding:16px}
h1{font-size:24px;margin:8px 0 4px}h2{font-size:19px;margin:28px 0 8px;border-bottom:1px solid var(--bd);padding-bottom:4px}
p,li{color:var(--fg)}.mut{color:var(--mut)}.ko{color:#ff7a6b}.ok{color:#7ddc7a}.amb{color:var(--amb)}
figure{margin:10px 0;background:var(--card);border:1px solid var(--bd);border-radius:6px;padding:8px;overflow-x:auto}
figure img{display:block;max-width:none;image-rendering:auto}
figure.fit img{max-width:100%;height:auto}
figcaption{color:var(--mut);font-size:13px;margin-top:6px}
.trio{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
@media (max-width:900px){.trio{grid-template-columns:1fr}}
table{border-collapse:collapse;margin:8px 0}td,th{border:1px solid var(--bd);padding:4px 8px;text-align:left}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--contenu", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    c = json.load(open(a.contenu, encoding="utf-8"))
    out = ["<!doctype html><html lang='fr'><head><meta charset='utf-8'>",
           "<meta name='viewport' content='width=device-width,initial-scale=1'>",
           "<title>%s</title><style>%s</style></head><body><main>" % (html.escape(c["titre"]), CSS),
           "<h1>%s</h1>" % html.escape(c["titre"]), c.get("intro", "")]
    for s in c["sections"]:
        out.append("<h2>%s</h2>" % html.escape(s["titre"]))
        out.append(s.get("texte", ""))
        if s.get("trio"):
            out.append("<div class='trio'>")
        for im in s.get("images", []):
            cls = " class='fit'" if im.get("fit", True) else ""
            out.append("<figure%s><a href='%s'><img src='%s' alt='%s' loading='lazy'></a><figcaption>%s</figcaption>"
                       "</figure>" % (cls, im["src"], im["src"], html.escape(im.get("legende", "")),
                                      html.escape(im.get("legende", ""))))
        if s.get("trio"):
            out.append("</div>")
        out.append(s.get("apres", ""))
    out.append("</main></body></html>")
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print("[FO-PAGE] %s" % a.out)


if __name__ == "__main__":
    main()
