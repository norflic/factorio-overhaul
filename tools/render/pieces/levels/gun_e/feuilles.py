"""FEUILLES DE JEU de la mitrailleuse V3-E (lot A2, 24/10) : des sprites de production aux fichiers du mod. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/feuilles.py [--dest graphics/levels/gun] [--valide 1-9=DIR …]
        [--so DIR] [--data <racine>/data] [--sans-images]

Ce que l'outil écrit dans --dest (dossier du mod ; les PNG y sont HORS de git, décision D-6 de l'orchestrateur) :
  - socle et pièce de chaque âge : COPIES octet à octet des sprites validés (mêmes noms : hr-gune-eNN-socle-main.png…) ;
  - tête de chaque âge (2 à 15), par couche (main, shadow, glow) et par résolution : UNE feuille en COLONNE de 4 images
    dans l'ordre des directions d'une RotatedAnimation à 4 directions de Factorio (N, E, S, O : doc 1.1.91,
    « 4 : North (1), East (2), South (3), West (4) ») ; cadre commun = union des 4 poses, bords PAIRS relatifs à
    l'origine (la version normale tombe au pixel) ; chaque pose collée à sa place exacte : les pixels des poses
    validées (N = tete-N, E = tete-E) sont recopiés SANS changement (contrôle : check_gun_sheets.py --sources) ;
  - icône de chaque âge 2 à 15 (64 px + mipmaps, bande 120 × 64) : socle + tête E composés hors Blender, réduits par
    fo_post.icon_strip (même code que l'icône de render.py) ;
  - sprites.lua (définitions lues par prototypes/levels/gun.lua) et sprites.json (mêmes données, pour les outils) ;
  - MANIFEST.json : chaque fichier (taille, sha256, dimensions), les sources (spec.json et sha256 de chaque PNG
    source) et la commande exacte qui régénère le dossier. sprites.lua, sprites.json et MANIFEST.json sont COMMITÉS.

Bouche du canon (E68, mesurée ici sur les sprites) : pour chaque pose de tête, le point opaque (alpha ≥ 0,5) le plus
loin dans la direction du tir (E : colonne la plus à droite ; N : ligne la plus haute ; S : la plus basse ; O : la
plus à gauche), et sa coordonnée transverse (médiane des pixels opaques des 6 dernières colonnes ou lignes), en
tuiles depuis le centre de l'entité. Étalonnage sur la VANILLA (mêmes mesures sur hr-gun-turret-shooting-*.png,
images 0, 16, 32, 48) : décalage s = bouche dessinée en E − point du moteur en E (projectile_center +
projectile_creation_distance). Pour chaque âge : distance = bouche_E.x − s.x, centre.y = bouche_E.y − s.y (centre.x =
0). Modèle des écarts : bouche prévue = centre + (0, s.y) + (distance + s.x) × direction du tir (s.x le long du tir,
s.y vers le haut de l'écran). Les écarts aux poses N, S et O sont écrits dans sprites.json (« ecarts_bouche ») : NON
corrigés (un seul centre et une seule distance pour toutes les directions, règle du moteur). La « bouche » est le
point opaque le plus avancé : sur certaines poses, ce n'est pas le canon (organe d'époque plus avancé) : mesure
grossière, à confronter aux captures du tir en moteur (scénario gun-rose).

Sources par défaut (designs VALIDÉS par le Directeur Créatif ; production à 128 échantillons) :
  âges 1 à 9    fo-logs/2026-10-23_V3E-p5/bas/sprites
  âges 10 à 12  fo-logs/2026-10-23_V3E-p5/haut/sprites   (e13 à e15 de ce dossier : REFUSÉS, REFUSES.txt)
  âges 13 à 15  fo-logs/2026-10-23_V3E-ereV/sprites
  poses S et O  fo-logs/2026-10-24_A2/sprites (eNN-tete-d32, eNN-tete-d48 ; lot A2)
"""
import argparse
import hashlib
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
GAME = os.path.dirname(os.path.dirname(MOD)) if os.path.basename(os.path.dirname(MOD)) == "mods" else None
sys.path.insert(0, RENDER)
import fo_post as P  # noqa: E402

MOD_NAME = "factorio-overhaul"
LOGS = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
VALIDES_DEFAUT = ["1-9=" + os.path.join(LOGS, "2026-10-23_V3E-p5", "bas", "sprites"),
                  "10-12=" + os.path.join(LOGS, "2026-10-23_V3E-p5", "haut", "sprites"),
                  "13-15=" + os.path.join(LOGS, "2026-10-23_V3E-ereV", "sprites")]
SO_DEFAUT = os.path.join(LOGS, "2026-10-24_A2", "sprites")
DATA_DEFAUT = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\data"
DEST_DEFAUT = os.path.join(MOD, "graphics", "levels", "gun")
GRAPHICS_PREFIX = "__%s__/graphics/levels/gun/" % MOD_NAME
DIRECTIONS = (("N", "tete-N"), ("E", "tete-E"), ("S", "tete-d32"), ("O", "tete-d48"))
TETE_COUCHES = ("main", "shadow", "glow")
FIXE_COUCHES = ("main", "shadow", "glow", "light")
# Vanilla (data/base/prototypes/entity/turrets.lua, mitrailleuse) : point du moteur et tête hr
VANILLE = {"projectile_creation_distance": 1.39375, "projectile_center": (0.0, -0.0875),
           "tete_hr": {"w": 132, "h": 130, "shift_px": (0.0, -27.5), "bandes": 4, "par_bande": 16, "images": 2}}
COMMANDE = ("py -3.9 tools/render/pieces/levels/gun_e/feuilles.py   (depuis la racine du mod ; sources par défaut : "
            "en tête de feuilles.py)")


def sha_file(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def plages(specs):
    res = {}
    for s in specs:
        plage, d = s.split("=", 1)
        a, b = plage.split("-") if "-" in plage else (plage, plage)
        for e in range(int(a), int(b) + 1):
            res[e] = d
    return res


def lire_spec(d, nom):
    p = os.path.join(d, nom, "spec.json")
    if not os.path.exists(p):
        raise SystemExit("source absente : %s" % p)
    s = json.load(open(p, encoding="utf-8"))
    if s.get("variant") != nom:
        raise SystemExit("%s : spec.json d'une autre variante (%s)" % (p, s.get("variant")))
    if s.get("samples") != 128 or s.get("quick") or s.get("apercu"):
        raise SystemExit("%s : pas un rendu de production (échantillons %s, rapide %s, aperçu %s)"
                         % (p, s.get("samples"), s.get("quick"), s.get("apercu")))
    for lay, L in s["layers"].items():
        for res, LL in (("hr", L), ("lr", L["lr"])):
            f = os.path.join(d, nom, LL["file"])
            if sha_file(f) != LL["sha256"]:
                raise SystemExit("%s : sha256 du PNG différent du spec.json (%s %s)" % (f, lay, res))
    return s, os.path.join(d, nom)


def rgba(p):
    return np.asarray(Image.open(p).convert("RGBA"))


def ecrire_png(u8, p):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    u8 = u8.copy()
    u8[u8[..., 3] == 0, :3] = 0
    Image.fromarray(u8, "RGBA").save(p, optimize=True, compress_level=9)


def boite_px(L):
    """Boîte d'une couche hr relative à l'origine, en px hr (gauche, haut, droite, bas) ; entiers PAIRS exigés."""
    w, h = L["width"], L["height"]
    gx = L["shift"][0] * 64 - w / 2
    gy = L["shift"][1] * 64 - h / 2
    if abs(gx - round(gx)) > 1e-9 or abs(gy - round(gy)) > 1e-9:
        raise SystemExit("bord de pose non entier : %s" % L["file"])
    gx, gy = int(round(gx)), int(round(gy))
    if gx % 2 or gy % 2 or w % 2 or h % 2:
        raise SystemExit("bord de pose impair (la version normale ne tomberait pas au pixel) : %s" % L["file"])
    return gx, gy, gx + w, gy + h


def bouche(alpha, gauche, haut, d):
    """Bouche dessinée d'une pose (tuiles depuis l'origine) : point opaque le plus loin dans la direction d."""
    x, y = _bouche(alpha, gauche, haut, d)
    return float(x), float(y)


def _bouche(alpha, gauche, haut, d):
    op = alpha >= 128
    ys, xs = np.nonzero(op)
    if d == "E":
        x = xs.max()
        sel = op[:, max(0, x - 5):x + 1].any(1)
        return ((gauche + x + 1) / 64.0, (haut + float(np.median(np.nonzero(sel)[0])) + 0.5) / 64.0)
    if d == "O":
        x = xs.min()
        sel = op[:, x:x + 6].any(1)
        return ((gauche + x) / 64.0, (haut + float(np.median(np.nonzero(sel)[0])) + 0.5) / 64.0)
    if d == "N":
        y = ys.min()
        sel = op[y:y + 6, :].any(0)
        return ((gauche + float(np.median(np.nonzero(sel)[0])) + 0.5) / 64.0, (haut + y) / 64.0)
    y = ys.max()
    sel = op[max(0, y - 5):y + 1, :].any(0)
    return ((gauche + float(np.median(np.nonzero(sel)[0])) + 0.5) / 64.0, (haut + y + 1) / 64.0)


def bouches_vanille(data_dir):
    V = VANILLE["tete_hr"]
    res = {}
    for d, k in (("N", 0), ("E", 16), ("S", 32), ("O", 48)):
        bande, ligne = divmod(k, V["par_bande"])
        p = os.path.join(data_dir, "base", "graphics", "entity", "gun-turret", "hr-gun-turret-shooting-%d.png" % (bande + 1))
        im = rgba(p)
        cad = im[ligne * V["h"]:(ligne + 1) * V["h"], 0:V["w"]]
        # by_pixel(x, y) = x/32 tuile ; en px hr (64/tuile) : 2x. Shift hr vanilla = by_pixel(0, -27.5) -> -55 px hr.
        gauche = V["shift_px"][0] * 2 - V["w"] / 2
        haut = V["shift_px"][1] * 2 - V["h"] / 2
        res[d] = bouche(cad[..., 3], gauche, haut, d)
    return res


def lua_value(v, ind=""):
    if isinstance(v, dict):
        items = []
        for k in sorted(v, key=lambda x: (isinstance(x, str), x)):
            if isinstance(k, int):
                key = "[%d]" % k
            else:
                key = k if k.isidentifier() else '["%s"]' % k
            items.append("%s  %s = %s" % (ind, key, lua_value(v[k], ind + "  ")))
        return "{\n" + ",\n".join(items) + "\n" + ind + "}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x, ind) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(v) if not v.is_integer() else str(int(v))
    return '"%s"' % v


def texte_lua(donnees):
    return ("-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/gun_e/feuilles.py (lot A2) : ne pas modifier à la main.\n"
            "-- Tailles en pixels, shift en tuiles. hr = 64 px/tuile (scale 0,5), normale = 32 px/tuile.\n"
            "-- Têtes : feuille en COLONNE de 4 images, directions N, E, S, O (RotatedAnimation, direction_count 4,\n"
            "-- line_length 1). Images : MANIFEST.json (hors de git, D-6) ; régénérer : voir MANIFEST.json, « commande ».\n"
            "return ") + lua_value(donnees) + "\n"


def couche_def(fichier_hr, fichier_lr, w, h, shift):
    return {"hr": {"filename": GRAPHICS_PREFIX + fichier_hr, "width": w, "height": h, "shift": [shift[0], shift[1]]},
            "lr": {"filename": GRAPHICS_PREFIX + fichier_lr, "width": w // 2, "height": h // 2,
                   "shift": [shift[0], shift[1]]}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--valide", action="append", default=None)
    ap.add_argument("--so", default=SO_DEFAUT)
    ap.add_argument("--data", default=DATA_DEFAUT)
    a = ap.parse_args()
    valides = plages(a.valide or VALIDES_DEFAUT)
    dest = os.path.abspath(a.dest)
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(dest):
        if f.endswith(".png"):
            os.remove(os.path.join(dest, f))
    sources = {}
    ages = {}
    union = {}

    def copie(d, L):
        """Copie octet à octet d'un PNG validé (hr et normale) ; rend la définition."""
        for LL in (L, L["lr"]):
            shutil.copyfile(os.path.join(d, LL["file"]), os.path.join(dest, LL["file"]))
        return couche_def(L["file"], L["lr"]["file"], L["width"], L["height"], L["shift"])

    def note_source(nom, s, d):
        sources[nom] = {"dossier": d, "spec_sha256": sha_file(os.path.join(d, "spec.json")),
                        "couches": {lay: {"hr": L["sha256"], "lr": L["lr"]["sha256"]} for lay, L in s["layers"].items()},
                        "echantillons": s["samples"], "trous_px": s["checks"]["largest_hole_px"],
                        "bouchon_arriere": (s.get("count") or {}).get("bouchon_arriere", 0)}

    # âge 1 : pièce posée sous la mitrailleuse vanilla
    s, d = lire_spec(valides[1], "e01-piece")
    note_source("e01-piece", s, d)
    ages[1] = {"piece": {lay: copie(d, s["layers"][lay]) for lay in FIXE_COUCHES if lay in s["layers"]}}
    vb = bouches_vanille(a.data)
    sE = (vb["E"][0] - (VANILLE["projectile_center"][0] + VANILLE["projectile_creation_distance"]),
          vb["E"][1] - VANILLE["projectile_center"][1])
    ecarts_vanille = {}
    for dd, (vx, vy) in sorted(vb.items()):
        ux, uy = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "O": (-1, 0)}[dd]
        # modèle : bouche dessinée = centre + (0, s.y) + (distance + s.x) × direction du tir (s.x : la bouche est en
        # deçà du point du moteur, LE LONG du tir ; s.y : à l'écran, vers le haut, quelle que soit la direction)
        mx = VANILLE["projectile_center"][0] + ux * (VANILLE["projectile_creation_distance"] + sE[0])
        my = VANILLE["projectile_center"][1] + sE[1] + uy * (VANILLE["projectile_creation_distance"] + sE[0])
        ecarts_vanille[dd] = [round(vx - mx, 4), round(vy - my, 4)]

    for e in range(2, 16):
        dv = valides[e]
        A = {}
        for part in ("socle", "piece"):
            nom = "e%02d-%s" % (e, part)
            s, d = lire_spec(dv, nom)
            note_source(nom, s, d)
            A[part] = {lay: copie(d, s["layers"][lay]) for lay in FIXE_COUCHES if lay in s["layers"]}
        poses = []
        for dname, part in DIRECTIONS:
            nom = "e%02d-%s" % (e, part)
            dsrc = dv if part in ("tete-N", "tete-E") else a.so
            s, d = lire_spec(dsrc, nom)
            note_source(nom, s, d)
            poses.append((dname, nom, s, d))
        tete = {}
        bouches = {}
        for lay in TETE_COUCHES:
            presentes = [p for p in poses if lay in p[2]["layers"]]
            if not presentes:
                continue
            boites = {p[1]: boite_px(p[2]["layers"][lay]) for p in presentes}
            L0 = min(b[0] for b in boites.values())
            T0 = min(b[1] for b in boites.values())
            R0 = max(b[2] for b in boites.values())
            B0 = max(b[3] for b in boites.values())
            W, H = R0 - L0, B0 - T0
            hr = np.zeros((4 * H, W, 4), np.uint8)
            lr = np.zeros((4 * H // 2, W // 2, 4), np.uint8)
            for k, (dname, nom, s, d) in enumerate(poses):
                if lay not in s["layers"]:
                    continue
                L = s["layers"][lay]
                gx, gy, rx, by = boites[nom]
                ih = rgba(os.path.join(d, L["file"]))
                il = rgba(os.path.join(d, L["lr"]["file"]))
                assert ih.shape[:2] == (L["height"], L["width"]), nom
                assert il.shape[:2] == (L["height"] // 2, L["width"] // 2), nom
                y0, x0 = k * H + gy - T0, gx - L0
                hr[y0:y0 + ih.shape[0], x0:x0 + ih.shape[1]] = ih
                y0l, x0l = (k * H + gy - T0) // 2, (gx - L0) // 2
                lr[y0l:y0l + il.shape[0], x0l:x0l + il.shape[1]] = il
                if lay == "main":
                    bouches[dname] = bouche(ih[..., 3], gx, gy, dname)
                for kind in ("main", "glow"):
                    if lay == kind:
                        u = union.setdefault(e, [1e9, 1e9, -1e9, -1e9])
                        u[0], u[1] = min(u[0], gx / 64.0), min(u[1], gy / 64.0)
                        u[2], u[3] = max(u[2], rx / 64.0), max(u[3], by / 64.0)
            fh, fl = "hr-gun-e%02d-tete-%s.png" % (e, lay), "gun-e%02d-tete-%s.png" % (e, lay)
            ecrire_png(hr, os.path.join(dest, fh))
            ecrire_png(lr, os.path.join(dest, fl))
            shift = ((L0 + R0) / 2.0 / 64.0, (T0 + B0) / 2.0 / 64.0)
            cd = couche_def(fh, fl, W, H, shift)
            for r in ("hr", "lr"):
                cd[r]["direction_count"] = 4
                cd[r]["line_length"] = 1
            tete[lay] = cd
            # placement de chaque pose dans sa cellule (outil de contrôle : check_gun_sheets.py --sources)
            tete[lay]["poses"] = {dname: {"source": nom, "x": boites[nom][0] - L0, "y": boites[nom][1] - T0}
                                  for dname, nom, s, d in poses if nom in boites}
        A["tete"] = tete
        # boîte d'affichage : socle, pièce et 4 poses de tête (couches principale et lueur)
        u = union.setdefault(e, [1e9, 1e9, -1e9, -1e9])
        for part in ("socle", "piece"):
            for lay in ("main", "glow"):
                if lay in A[part]:
                    h = A[part][lay]["hr"]
                    u[0] = min(u[0], h["shift"][0] - h["width"] / 128.0)
                    u[1] = min(u[1], h["shift"][1] - h["height"] / 128.0)
                    u[2] = max(u[2], h["shift"][0] + h["width"] / 128.0)
                    u[3] = max(u[3], h["shift"][1] + h["height"] / 128.0)
        A["boite"] = [[u[0], u[1]], [u[2], u[3]]]
        # bouche (E68) : point du moteur déduit de la pose E et du décalage étalonné sur la vanilla
        bE = bouches["E"]
        dist = bE[0] - sE[0]
        cy = bE[1] - sE[1]
        ecarts = {}
        for dd, (vx, vy) in sorted(bouches.items()):
            ux, uy = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "O": (-1, 0)}[dd]
            ecarts[dd] = [round(vx - ux * (dist + sE[0]), 4), round(vy - (cy + sE[1] + uy * (dist + sE[0])), 4)]
        A["tir"] = {"projectile_creation_distance": round(dist, 5), "projectile_center": [0.0, round(cy, 5)]}
        A["bouches"] = {k: [round(v[0], 5), round(v[1], 5)] for k, v in sorted(bouches.items())}
        A["ecarts_bouche"] = ecarts
        # icône : socle + tête E (couches principales hr), composées en lumière linéaire, réduites
        A["icone"] = icone(dest, e, A, poses)
        ages[e] = A
    donnees = {"directions": ["N", "E", "S", "O"], "ages": ages,
               "vanille": {"bouches": {k: [round(v[0], 5), round(v[1], 5)] for k, v in sorted(vb.items())},
                           "decalage_eclat": [round(sE[0], 5), round(sE[1], 5)], "ecarts_bouche": ecarts_vanille,
                           "projectile_creation_distance": VANILLE["projectile_creation_distance"],
                           "projectile_center": list(VANILLE["projectile_center"])}}
    # les sous-tables « poses » restent dans sprites.json (outils), pas dans sprites.lua (jeu)
    pour_lua = json.loads(json.dumps(donnees))
    for e, A in pour_lua["ages"].items():
        for lay, cd in A.get("tete", {}).items():
            cd.pop("poses", None)
    pour_lua["ages"] = {int(k): v for k, v in pour_lua["ages"].items()}
    with open(os.path.join(dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(texte_lua(pour_lua))
    with open(os.path.join(dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(donnees, f, indent=1, sort_keys=True)
    fichiers = {}
    for f in sorted(os.listdir(dest)):
        if f.endswith(".png"):
            p = os.path.join(dest, f)
            with Image.open(p) as im:
                w, h = im.size
            fichiers[f] = {"taille": os.path.getsize(p), "sha256": sha_file(p), "largeur": w, "hauteur": h}
    manifeste = {"commande": COMMANDE, "outil": "tools/render/pieces/levels/gun_e/feuilles.py",
                 "controle": "py -3.9 tools/render/pieces/levels/gun_e/check_gun_sheets.py [--sources]",
                 "git": "PNG hors de git (.gitignore : graphics/levels/gun/*.png, décision D-6) ; ce manifeste, "
                        "sprites.lua et sprites.json sont commités",
                 "sources": sources, "fichiers": fichiers,
                 "sprites_lua_sha256": sha_file(os.path.join(dest, "sprites.lua")),
                 "sprites_json_sha256": sha_file(os.path.join(dest, "sprites.json"))}
    with open(os.path.join(dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifeste, f, indent=1, sort_keys=True)
    tot = sum(v["taille"] for v in fichiers.values())
    print("[FO-FEUILLES] %d fichiers PNG, %.2f Mo, %d sources ; dest %s" % (len(fichiers), tot / 1e6, len(sources), dest))
    print("[FO-FEUILLES] vanilla : bouches %s ; décalage éclat %s ; écarts %s" % (
        donnees["vanille"]["bouches"], donnees["vanille"]["decalage_eclat"], ecarts_vanille))
    for e in range(2, 16):
        A = ages[e]
        print("[FO-FEUILLES] âge %2d tir %s ; écarts N %s S %s O %s ; boîte %s" % (
            e, A["tir"], A["ecarts_bouche"]["N"], A["ecarts_bouche"]["S"], A["ecarts_bouche"]["O"],
            [[round(x, 3) for x in c] for c in A["boite"]]))
    return 0


def icone(dest, e, A, poses):
    def charge(d, L):
        return rgba(os.path.join(d, L["file"])).astype(np.float64) / 255.0, boite_px(L)
    # socle : depuis la copie dans dest (mêmes octets que la source)
    sm = A["socle"]["main"]["hr"]
    socle = rgba(os.path.join(dest, os.path.basename(sm["filename"]))).astype(np.float64) / 255.0
    sb = boite_px({"width": sm["width"], "height": sm["height"], "shift": sm["shift"], "file": sm["filename"]})
    dname, nom, s, d = poses[1]          # tête E
    tete, tb = charge(d, s["layers"]["main"])
    L0, T0 = min(sb[0], tb[0]), min(sb[1], tb[1])
    R0, B0 = max(sb[2], tb[2]), max(sb[3], tb[3])
    can_s = np.zeros((B0 - T0, R0 - L0, 4))
    can_t = np.zeros_like(can_s)
    can_s[sb[1] - T0:sb[3] - T0, sb[0] - L0:sb[2] - L0] = socle
    can_t[tb[1] - T0:tb[3] - T0, tb[0] - L0:tb[2] - L0] = tete
    comp = P.over(can_t, can_s)
    strip = P.icon_strip(comp)
    f = "gun-e%02d-icone.png" % e
    ecrire_png(P.to_u8(strip), os.path.join(dest, f))
    return {"filename": GRAPHICS_PREFIX + f, "icon_size": 64, "icon_mipmaps": 4}


if __name__ == "__main__":
    sys.exit(main())
