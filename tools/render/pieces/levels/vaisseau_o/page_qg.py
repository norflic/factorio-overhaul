"""PAGE LOCALE de revue d'un état du QG (pas d'artefact : un .html posé à côté des images, ouvert par le DC).

    py -3.9 tools/render/pieces/levels/vaisseau_o/page_qg.py --dir <dossier de l'état> --titre "…" --notes notes.html
        --images planche.png,planche_z1.png,... --mesures mesures.md

Les chemins d'images sont relatifs au dossier ; le tableau de mesures (Markdown de mesure_qg.py) est converti tel quel.
"""
import argparse
import html
import os


def table(md):
    rows = [l.strip() for l in md.splitlines() if l.strip().startswith("|")]
    out = ["<table>"]
    for i, l in enumerate(rows):
        if i == 1 and set(l.replace("|", "").strip()) <= set("-: "):
            continue
        cells = [c.strip() for c in l.strip("|").split("|")]
        tag = "th" if i == 0 else "td"
        tr = []
        for c in cells:
            cls = ' class="ko"' if c == "ÉCHEC" else (' class="ok"' if c in ("OK", "cible") else "")
            tr.append("<%s%s>%s</%s>" % (tag, cls, html.escape(c), tag))
        out.append("<tr>" + "".join(tr) + "</tr>")
    out.append("</table>")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--titre", required=True)
    ap.add_argument("--notes", default="")
    ap.add_argument("--images", default="")
    ap.add_argument("--mesures", default="")
    a = ap.parse_args()
    notes = open(os.path.join(a.dir, a.notes), encoding="utf-8").read() if a.notes else ""
    mes = table(open(os.path.join(a.dir, a.mesures), encoding="utf-8").read()) if a.mesures else ""
    figs = []
    for item in [x for x in a.images.split(",") if x]:
        src, _, leg = item.partition("=")
        figs.append('<figure><a href="%s"><img src="%s" loading="lazy"></a><figcaption>%s</figcaption></figure>'
                    % (html.escape(src), html.escape(src), html.escape(leg or src)))
    page = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>QG âge 0</title>
<style>
:root{--bg:#16161a;--fg:#e8e6e1;--mut:#a9a59c;--acc:#ffcd78;--ok:#8fd18a;--ko:#ff7a6b;--line:#33333a}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,Segoe UI,sans-serif}
main{max-width:1500px;margin:0 auto;padding:16px}
h1{color:var(--acc);font-size:22px;margin:8px 0 4px} h2{font-size:17px;margin:22px 0 6px;color:var(--acc)}
p,li{color:var(--fg)} .mut{color:var(--mut)}
figure{margin:10px 0 18px} figure img{max-width:100%%;height:auto;border:1px solid var(--line);image-rendering:auto}
figcaption{color:var(--mut);font-size:13px}
table{border-collapse:collapse;font-size:13px;margin:6px 0;overflow-x:auto;display:block}
th,td{border:1px solid var(--line);padding:3px 7px;text-align:right;white-space:nowrap} th{background:#22222a}
td:first-child,th:first-child{text-align:left} .ok{color:var(--ok)} .ko{color:var(--ko);font-weight:600}
</style></head><body><main>
<h1>%s</h1>
%s
<h2>Images (cliquer pour la pleine résolution)</h2>
%s
<h2>Mesures du brief QG (même instrument que le diagnostic ; verdict sur la dernière colonne)</h2>
%s
</main></body></html>
""" % (html.escape(a.titre), notes, "\n".join(figs), mes)
    dest = os.path.join(a.dir, "index.html")
    open(dest, "w", encoding="utf-8", newline="\n").write(page)
    print(dest)


if __name__ == "__main__":
    main()
