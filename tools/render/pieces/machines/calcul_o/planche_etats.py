"""PLANCHE DES ÉTATS CLÉS (lot DA-CALCUL, 4/11) : une rangée par machine ; à gauche le visuel ACTUEL (rendu du 1/11, celui de la
branche design-machines-calcul) et le sprite vanilla HR de même emprise, puis les états proposés. Même sol, même échelle,
ombre et lueur (au travail) composées comme en jeu (commun/compo.py). Python 3.9, hors Blender.

    py -3.9 tools/render/pieces/machines/calcul_o/planche_etats.py --actuel DIR --etats DIR --dest planche.png [--zoom 1|2] [--nuit]
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import planche as PL  # noqa: E402

K = PL.K

# rangée : (titre, [(nom, source : "actuel" | "etats" | None (vanilla), titre de la case)])
RANGEES = [
    ("Salle blanche fo-cleanroom (5×5) : À REFAIRE", [
        ("salle", "actuel", "ACTUEL 1/11 : le « visage »"), ("van:raffinerie", None, None),
        ("salle_a", "etats", "a : hall à plafond filtrant"), ("salle_b", "etats", "b : fab en trois niveaux"),
        ("salle_c", "etats", "c : tour d'air et peigne de gaines")]),
    ("Unité cryogénique fo-cryogenic-unit (5×5) : tuyaux dessinés retirés", [
        ("cryo", "actuel", "ACTUEL 1/11"), ("van:reacteur", None, None), ("cryo", "etats", "corrigé")]),
    ("Grand centre fo-data-center-2 (6×6) : tuyaux dessinés retirés", [
        ("grand_centre", "actuel", "ACTUEL 1/11"), ("van:raffinerie", None, "Vanilla : raffinerie (5×5 ; aucun 6×6)"),
        ("grand_centre", "etats", "corrigé")]),
    ("Centre de calcul fo-data-center (4×4) : tuyaux dessinés retirés", [
        ("centre", "actuel", "ACTUEL 1/11"), ("van:roboport", None, None), ("centre", "etats", "corrigé (CDU au nord-est)")]),
    ("Groupe froid fo-chiller (4×4) : lueur de travail, tuyaux du bord retirés", [
        ("froid", "actuel", "ACTUEL 1/11"), ("van:roboport", None, None), ("froid", "etats", "corrigé")]),
    ("Scie à fil fo-wire-saw (3×3) : lueur de travail", [
        ("scie", "actuel", "ACTUEL 1/11"), ("van:assembleur3", None, None), ("scie", "etats", "corrigé")]),
]


def rangee(cases, src, ppt, nuit, haut, oy):
    imgs = []
    for nom, ou, titre in cases:
        cle = nom if ou is None else "%s|%s" % (nom, src[ou])
        e = PL.emprise(cle)
        Wt = e[0] + 4
        day, night, _ = K.compose([{"pos": (Wt / 2.0, oy), "layers": PL.couches(src["actuel"], cle)}], Wt, haut)
        img = night if nuit else day
        if ppt == 32:
            img = K.down2(img)
        imgs.append((K.to_im(img), titre or PL.titre(nom), e))
    return imgs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--actuel", required=True)
    ap.add_argument("--etats", required=True)
    ap.add_argument("--dest", required=True)
    ap.add_argument("--zoom", type=int, default=2, choices=(1, 2))
    ap.add_argument("--nuit", action="store_true")
    ap.add_argument("--seulement", default="", help="numéros de rangées (0 = salle), séparés par des virgules")
    a = ap.parse_args()
    ppt = 64 if a.zoom == 2 else 32
    src = {"actuel": a.actuel, "etats": a.etats}
    haut, oy = 10.0, 6.6
    gap, hd, lab, tit = 6, 40, 26, 30
    rangs = RANGEES if not a.seulement else [RANGEES[int(i)] for i in a.seulement.split(",")]
    blocs = [(t, rangee(c, src, ppt, a.nuit, haut, oy)) for t, c in rangs]
    W = max(sum(im.size[0] for im, _, _ in r) + (len(r) + 1) * gap for _, r in blocs)
    H = hd + sum(tit + r[0][0].size[1] + lab + gap for _, r in blocs)
    sheet = Image.new("RGB", (W, H), (22, 22, 26))
    dr = ImageDraw.Draw(sheet)
    f1, f2, f3 = K.font(22 if a.zoom == 2 else 16), K.font(18 if a.zoom == 2 else 13), K.font(16 if a.zoom == 2 else 11, False)
    dr.text((10, 8), "DA-CALCUL, états clés (16 échantillons) · zoom %d · %s · lueur de travail allumée" % (a.zoom, "nuit" if a.nuit else "jour"),
            fill=(255, 205, 120), font=f1)
    y = hd
    for t, r in blocs:
        dr.text((10, y + 4), t, fill=(140, 200, 255), font=f2)
        y += tit
        x = gap
        for im, titre, e in r:
            sheet.paste(im, (x, y))
            dr.text((x + 6, y + im.size[1] + 3), "%s · %d×%d" % (titre, e[0], e[1]), fill=(235, 235, 235), font=f3)
            x += im.size[0] + gap
        y += r[0][0].size[1] + lab + gap
    os.makedirs(os.path.dirname(os.path.abspath(a.dest)), exist_ok=True)
    sheet.save(a.dest, optimize=True)
    print(a.dest, sheet.size, "%.2f Mo" % (os.path.getsize(a.dest) / 1e6))


if __name__ == "__main__":
    main()
