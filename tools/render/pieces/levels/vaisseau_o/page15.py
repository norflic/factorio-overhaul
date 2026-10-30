"""PAGE LOCALE de l'âge 15 (lot QG) : planches état | vanilla | ancienne, mesures du brief avec verdict, essais.
Écrit index.html dans le dossier donné (images en chemins relatifs). Aucune publication : page locale ouverte au DC.

    py -3.9 tools/render/pieces/levels/vaisseau_o/page15.py --dir <fo-logs/2026-10-30_QG/age15> --mesures final/mesures.json
        --images "planche.png=…;planche_z2.png=…" --essais "essai1=…;essai2=…" --notes notes.txt
"""
import argparse
import html
import io
import json
import os

CSS = """
:root{--bg:#f4f1ea;--fg:#1d1b18;--mut:#6b655c;--card:#fffdf8;--line:#ddd5c6;--ok:#2f7d32;--pl:#9a6a00;--ko:#b3261e}
@media (prefers-color-scheme: dark){:root{--bg:#16150f;--fg:#ece7dc;--mut:#a39c8f;--card:#201e17;--line:#3a362c;--ok:#7bc47f;--pl:#e0b04a;--ko:#f08b84}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 system-ui,Segoe UI,sans-serif}
main{max-width:1600px;margin:0 auto;padding:16px}
h1{font-size:22px;margin:4px 0 2px}h2{font-size:18px;margin:26px 0 8px}
p,li{max-width:110ch}.mut{color:var(--mut)}
figure{margin:12px 0;background:var(--card);border:1px solid var(--line);border-radius:8px;padding:8px;overflow-x:auto}
figure img{display:block;max-width:none}figcaption{color:var(--mut);font-size:13px;margin-top:6px}
table{border-collapse:collapse;font-size:13px;background:var(--card)}td,th{border:1px solid var(--line);padding:3px 7px;text-align:right}
th:first-child,td:first-child{text-align:left}.ok{color:var(--ok);font-weight:600}.pl{color:var(--pl);font-weight:600}.ko{color:var(--ko);font-weight:700}
.wrap{overflow-x:auto}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--mesures", required=True)
    ap.add_argument("--images", default="")
    ap.add_argument("--essais", default="")
    ap.add_argument("--notes", default="")
    a = ap.parse_args()
    rows = json.load(open(os.path.join(a.dir, a.mesures), encoding="utf-8"))
    out = ["<!doctype html><html lang='fr'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
           "<title>QG âge 15 Légende</title><style>%s</style></head><body><main>" % CSS,
           "<h1>Centre de commandement, âge 15 · Légende (QG refait, nez à droite)</h1>",
           "<p class='mut'>Lot QG, 30/10. Rendu Blender 5.2.2 par le verrou de rendu ; même sol, même échelle que le vanilla ; "
           "rien en jeu. Seul votre verdict sur image valide le design.</p>"]
    if a.notes and os.path.exists(os.path.join(a.dir, a.notes)):
        out.append(io.open(os.path.join(a.dir, a.notes), encoding="utf-8").read())
    for item in [x for x in a.images.split(";") if x]:
        f, cap = item.split("=", 1)
        out.append("<figure><a href='%s'><img src='%s' alt='%s' loading='lazy'></a><figcaption>%s</figcaption></figure>"
                   % (html.escape(f), html.escape(f), html.escape(cap), html.escape(cap)))
    out.append("<h2>Mesures du brief QG (corps alpha ≥ 0,5, 64 px/tuile)</h2><div class='wrap'><table><tr><th>état</th>")
    keys = [("masse", "masse t²"), ("d3", "pièces/t²"), ("pieces", "pièces"), ("d5", "contours"), ("d4", "contraste"), ("noir", "noir<25"),
            ("p05", "p05"), ("p50", "p50"), ("p95", "p95"), ("sat", "satur."), ("sat_hors", "saturé hors lum."), ("m2", "remplissage"),
            ("decoupe", "découpe"), ("damier", "damier"), ("foyers_dom", "foyers dom."), ("zone_lum", "zone lum.")]
    out.append("".join("<th>%s</th>" % html.escape(l) for k, l in keys) + "</tr>")
    for r in rows:
        out.append("<tr><td>%s</td>%s</tr>" % (html.escape(r["nom"]), "".join(
            "<td>%s</td>" % (("%.2f" % r[k]) if isinstance(r[k], float) else r[k]) for k, l in keys)))
    out.append("</table></div>")
    for r in rows:
        if "verdict" not in r:
            continue
        out.append("<h2>Verdict des planchers : %s</h2><div class='wrap'><table><tr><th>critère</th><th>valeur</th><th>état</th></tr>"
                   % html.escape(r["nom"]))
        for lib, v, st in r["verdict"]:
            cls = {"OK": "ok", "plancher": "pl"}.get(st, "ko")
            out.append("<tr><td>%s</td><td>%.3f</td><td class='%s'>%s</td></tr>" % (html.escape(lib), v, cls,
                                                                                {"OK": "cible atteinte", "plancher": "plancher tenu"}.get(st, "échec")))
        out.append("</table></div>")
    if a.essais:
        out.append("<h2>Essais (10 échantillons, bruités : scores de détail flattés)</h2>")
        for item in [x for x in a.essais.split(";") if x]:
            f, cap = item.split("=", 1)
            out.append("<figure><a href='%s'><img src='%s' alt='%s' loading='lazy' style='max-width:100%%'></a><figcaption>%s</figcaption></figure>"
                       % (html.escape(f), html.escape(f), html.escape(cap), html.escape(cap)))
    out.append("</main></body></html>")
    io.open(os.path.join(a.dir, "index.html"), "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print(os.path.join(a.dir, "index.html"))


if __name__ == "__main__":
    main()
