"""PAGE LOCALE d'un état du QG (refonte du 30/10) : planches (état | vanilla | ancienne v6), tableau des mesures du brief,
historique des essais, défauts restants. Écrit <dossier>/index.html (images relatives, aucun service extérieur).

    py -3.9 tools/render/pieces/levels/vaisseau_o/page_qg.py --dossier <fo-logs/2026-10-30_QG/age08> --donnees page.json
"""
import argparse
import html
import json
import os

CSS = """:root{--bg:#16171a;--fg:#e8e4da;--mut:#a39d90;--card:#202227;--line:#33363d;--acc:#f0b429;--ok:#5fb36b;--bad:#e05252}
@media (prefers-color-scheme: light){:root{--bg:#f4f1ea;--fg:#1e1d1a;--mut:#5f5a50;--card:#fff;--line:#d9d3c6;--acc:#9a6a00;--ok:#2f7d3b;--bad:#b02a2a}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,Segoe UI,sans-serif}
main{max-width:1600px;margin:0 auto;padding:16px}
h1{font-size:1.6rem;margin:.2em 0}h2{margin-top:1.8em;border-bottom:1px solid var(--line);padding-bottom:.3em}
img{max-width:100%;height:auto;display:block;border-radius:4px;background:#000}
.box{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:12px;margin:12px 0}
.mut{color:var(--mut);font-size:.9rem}.ok{color:var(--ok)}.bad{color:var(--bad)}
table{border-collapse:collapse;width:100%;font-size:.9rem}td,th{border-bottom:1px solid var(--line);padding:4px 6px;text-align:right}
td:first-child,th:first-child{text-align:left}.scroll{overflow-x:auto}a{color:var(--acc)}
.nez{font-weight:600;color:var(--ok)}"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dossier", required=True)
    ap.add_argument("--donnees", required=True)
    a = ap.parse_args()
    d = json.load(open(a.donnees, encoding="utf-8"))
    e = html.escape
    out = ["<!doctype html><html lang='fr'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
           "<title>QG âge 8 Marais</title><style>%s</style></head><body><main>" % CSS]
    out.append("<h1>%s</h1><p class='mut'>%s</p>" % (e(d["titre"]), e(d["sous_titre"])))
    out.append("<p class='nez'>%s</p>" % e(d["nez"]))
    out.append("<div class='box'>%s</div>" % d["resume_html"])
    for (t, img, leg) in d["images"]:
        out.append("<h2>%s</h2><a href='%s'><img src='%s' alt='%s'></a><p class='mut'>%s</p>" % (e(t), e(img), e(img), e(t), e(leg)))
    out.append("<h2>Mesures du brief</h2><div class='scroll'><table><tr>%s</tr>" % "".join("<th>%s</th>" % e(h) for h in d["mesures"]["entetes"]))
    for row in d["mesures"]["lignes"]:
        cls = "bad" if "ÉCHEC" in row[-1] else ("ok" if "OK" in row[-1] else "")
        out.append("<tr>%s</tr>" % "".join("<td class='%s'>%s</td>" % (cls if i == len(row) - 1 else "", e(str(c))) for i, c in enumerate(row)))
    out.append("</table></div><p class='mut'>%s</p>" % e(d["mesures"]["note"]))
    out.append("<h2>Essais</h2><div class='box'>%s</div>" % d["essais_html"])
    out.append("<h2>Défauts restants (sans complaisance)</h2><div class='box'>%s</div>" % d["defauts_html"])
    out.append("<p class='mut'>%s</p></main></body></html>" % e(d["pied"]))
    open(os.path.join(a.dossier, "index.html"), "w", encoding="utf-8").write("\n".join(out))
    print(os.path.join(a.dossier, "index.html"))


if __name__ == "__main__":
    main()
