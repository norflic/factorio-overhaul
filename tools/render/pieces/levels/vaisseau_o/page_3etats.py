"""PAGE LOCALE DES 3 ÉTATS CLÉS DU QG (refonte du 31/10) : âge 0, âge 8, âge 15, chacun au zoom 1 à côté de l'épave vanilla
et de la raffinerie, gros plan, scène à l'échelle du jeu, tableau des mesures. Écrit <dossier>/index.html et ses images
(chemins relatifs, aucun service extérieur). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/levels/vaisseau_o/page_3etats.py --dossier <fo-logs/2026-10-31_QG> --textes textes.json

Attend dans <dossier> : age00/final/qg00, age08/final/qg08, age15/final/age15 (sorties de rendre.py) et leur mesures.json.
"""
import argparse
import html
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche as PL  # noqa: E402

K = PL.K
ETATS = (("age00", "qg00", (8, 4), "Âge 0 · Épave"), ("age08", "qg08", (12, 6), "Âge 8 · Marais"), ("age15", "age15", (16, 8), "Âge 15 · Légende"))
CLES = (("masse", "masse (t²)", "%.1f", None), ("pieces", "pièces", "%d", None), ("D3", "pièces/t² (D3)", "%.1f", "≥ 24"),
        ("D5", "contours (D5)", "%.3f", "≥ 0,24"), ("D4", "contraste local (D4)", "%.1f", "≥ 18"), ("noir", "noir L < 25", "%.3f", "≥ 0,15"),
        ("p05", "L p05", "%.1f", "≤ 10"), ("p50", "L p50", "%.1f", "43 à 58"), ("p95", "L p95", "%.1f", "160 à 200"),
        ("sat", "saturation", "%.3f", "≥ 0,40"), ("sat_hors", "saturée hors lumineux", "%.3f", "≤ 0,04"), ("M2", "M2 (masse / emprise)", "%.2f", "≥ 0,75"),
        ("decoupe", "découpe", "%.2f", "≥ 1,6 (épave ≥ 2,0)"), ("damier", "damier", "%.3f", "≤ 0,45"), ("foyers", "foyers dominants", "%d", "3 à 8"),
        ("zone_lum", "zone lumineuse", "%.3f", "≤ 0,06"))


def couches(dossier, age, nom):
    return K.own(os.path.join(dossier, age, "final"), nom, ("shadow", "main", "glow"))


def van(nom):
    return PL.couches("", "van:" + nom)


def z1_etat(dossier, age, nom, emp, titre, dest):
    """Zoom 1 : état | épave vanilla | raffinerie (mêmes pixels que le jeu, 32 par tuile)."""
    cas = [(couches(dossier, age, nom), emp, titre), (van("vaisseau"), (16, 8), "Vanilla : épave du vaisseau"), (van("raffinerie"), (5, 5), "Vanilla : raffinerie")]
    ppt, haut, oy, gap = 32, 12.0, 7.5, 6
    cw = [int((e[0] + 4) * ppt) for _, e, _ in cas]
    sheet = Image.new("RGB", (sum(cw) + gap * 4, int(haut * ppt) + 30), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    x = gap
    for (lay, e, t), w in zip(cas, cw):
        Wt = w / float(ppt)
        day, _, _ = K.compose([{"pos": (Wt / 2.0, oy), "layers": lay}], Wt, haut)
        sheet.paste(K.to_im(K.down2(day)), (x, 0))
        dr.text((x + 6, int(haut * ppt) + 6), "%s · %d×%d" % (t, e[0], e[1]), fill=(235, 235, 235), font=K.font(13))
        x += w + gap
    sheet.save(dest, optimize=True)


def gros_plan(dossier, age, nom, emp, dest):
    """Gros plan : zoom 2 (64 px par tuile), image entière recadrée sur le centre."""
    Wt, Ht = emp[0] + 2.0, emp[1] + 6.0
    day, _, _ = K.compose([{"pos": (Wt / 2.0, Ht - emp[1] / 2.0 - 1.0), "layers": couches(dossier, age, nom)}], Wt, Ht)
    im = K.to_im(day)
    w, h = im.size
    cw, ch = min(w, 1100), min(h, 760)
    x0, y0 = (w - cw) // 2, max(0, h - ch - 20)
    im.crop((x0, y0, x0 + cw, y0 + ch)).save(dest, optimize=True)


def scene(dossier, dest, dest_loin):
    """Échelle du jeu : les 3 états, l'épave vanilla, la raffinerie, des assembleurs 3×3 sur le même sol, au zoom 1 et dézoomé."""
    Wt, Ht = 46.0, 28.0
    ents = [{"pos": (7.0, 8.0), "layers": couches(dossier, "age00", "qg00")}, {"pos": (19.5, 8.5), "layers": couches(dossier, "age08", "qg08")},
            {"pos": (36.0, 9.0), "layers": couches(dossier, "age15", "age15")}, {"pos": (10.0, 21.0), "layers": van("vaisseau")},
            {"pos": (25.0, 21.0), "layers": van("raffinerie")}, {"pos": (31.5, 20.5), "layers": van("assembleur3")},
            {"pos": (35.5, 20.5), "layers": van("assembleur3")}, {"pos": (39.5, 20.5), "layers": van("assembleur3")}]
    day, _, _ = K.compose(ents, Wt, Ht)
    im = K.to_im(K.down2(day))
    im.save(dest, optimize=True)
    im.resize((im.size[0] // 2, im.size[1] // 2), Image.LANCZOS).save(dest_loin, optimize=True)


CSS = """:root{--bg:#16171a;--fg:#e8e4da;--mut:#a39d90;--card:#202227;--line:#33363d;--acc:#f0b429;--ok:#5fb36b;--bad:#e05252}
@media (prefers-color-scheme: light){:root:not([data-theme=dark]){--bg:#f4f1ea;--fg:#1e1d1a;--mut:#5f5a50;--card:#fff;--line:#d9d3c6;--acc:#9a6a00;--ok:#2f7d3b;--bad:#b02a2a}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 system-ui,Segoe UI,sans-serif}
main{max-width:1500px;margin:0 auto;padding:16px}h1{font-size:1.6rem;margin:.2em 0}
h2{margin-top:1.8em;border-bottom:1px solid var(--line);padding-bottom:.3em}
img{max-width:100%;height:auto;display:block;border-radius:4px;background:#000}
.box{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:12px 16px;margin:12px 0}
.mut{color:var(--mut);font-size:.9rem}.ok{color:var(--ok)}.bad{color:var(--bad)}.q{border-left:4px solid var(--acc)}
table{border-collapse:collapse;width:100%;font-size:.9rem}td,th{border-bottom:1px solid var(--line);padding:4px 8px;text-align:right;white-space:nowrap}
td:first-child,th:first-child{text-align:left}.scroll{overflow-x:auto}a{color:var(--acc)}"""


def verdict(cle, v):
    return {"D3": v >= 24, "D5": v >= 0.24, "D4": v >= 18, "noir": v >= 0.15, "p05": v <= 10, "p50": 43 <= v <= 58, "p95": 160 <= v <= 200, "sat": v >= 0.4,
            "sat_hors": v <= 0.04, "M2": v >= 0.75, "decoupe": v >= 1.6, "damier": v <= 0.45, "foyers": 3 <= v <= 8, "zone_lum": v <= 0.06}.get(cle)


def table(dossier):
    data = [json.load(open(os.path.join(dossier, a, "final", "mesures.json"), encoding="utf-8")) for a, _, _, _ in ETATS]
    vr = data[0]["rows"][:2]
    cols = [(r["nom"], r, False) for r in vr] + [(t, d["rows"][-1], True) for (_, _, _, t), d in zip(ETATS, data)]
    out = ["<div class='scroll'><table><tr><th>mesure</th><th>plancher</th>%s</tr>" % "".join("<th>%s</th>" % html.escape(c[0]) for c in cols)]
    for k, lib, f, pl in CLES:
        tds = []
        for (_, r, nous) in cols:
            v = r[k]
            cl = ""
            if nous and verdict(k, v) is not None:
                cl = "ok" if verdict(k, v) else "bad"
            tds.append("<td class='%s'>%s</td>" % (cl, f % v))
        out.append("<tr><td>%s</td><td>%s</td>%s</tr>" % (lib, pl or "", "".join(tds)))
    out.append("</table></div>")
    return "\n".join(out), data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dossier", required=True)
    ap.add_argument("--textes", required=True)
    a = ap.parse_args()
    d = a.dossier
    T = json.load(open(a.textes, encoding="utf-8"))
    os.makedirs(os.path.join(d, "images"), exist_ok=True)
    for age, nom, emp, titre in ETATS:
        z1_etat(d, age, nom, emp, titre, os.path.join(d, "images", age + "-z1.png"))
        gros_plan(d, age, nom, emp, os.path.join(d, "images", age + "-gros.png"))
    scene(d, os.path.join(d, "images", "scene-z1.png"), os.path.join(d, "images", "scene-loin.png"))
    tab, _ = table(d)
    h = ["<!doctype html><html lang='fr'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
         "<title>QG trois états</title><style>%s</style></head><body><main>" % CSS,
         "<h1>QG : 3 états clés, à juger avant toute série</h1><p class='mut'>%s</p>" % html.escape(T["sous_titre"]),
         "<div class='box q'>%s</div>" % T["question"]]
    for age, nom, emp, titre in ETATS:
        h.append("<h2>%s (%d×%d, nez à droite)</h2>" % (html.escape(titre), emp[0], emp[1]))
        h.append("<p>%s</p>" % T["etats"][age]["regard"])
        h.append("<p class='mut'>Zoom 1, pixels du jeu, à côté de l'épave vanilla et de la raffinerie.</p><a href='images/%s-z1.png'><img src='images/%s-z1.png' alt='%s au zoom 1'></a>" % (age, age, html.escape(titre)))
        h.append("<p class='mut'>Gros plan, zoom 2.</p><a href='images/%s-gros.png'><img src='images/%s-gros.png' alt='%s en gros plan'></a>" % (age, age, html.escape(titre)))
    h.append("<h2>À l'échelle du jeu</h2><p class='mut'>En haut : nos 3 états. En bas : épave vanilla, raffinerie, 3 assembleurs 3×3. Même sol, zoom 1, puis dézoomé de moitié.</p>")
    h.append("<a href='images/scene-z1.png'><img src='images/scene-z1.png' alt='scène au zoom 1'></a><br><a href='images/scene-loin.png'><img src='images/scene-loin.png' alt='scène dézoomée'></a>")
    h.append("<h2>Mesures contre le vanilla</h2>" + tab + "<p class='mut'>%s</p>" % html.escape(T["note_mesures"]))
    h.append("<h2>Défauts restants, sans complaisance</h2><div class='box'>%s</div>" % T["defauts"])
    h.append("<p class='mut'>%s</p></main></body></html>" % html.escape(T["pied"]))
    open(os.path.join(d, "index.html"), "w", encoding="utf-8").write("\n".join(h))
    print(os.path.join(d, "index.html"))


if __name__ == "__main__":
    main()
