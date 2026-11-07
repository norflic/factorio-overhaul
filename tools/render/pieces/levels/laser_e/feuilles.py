"""FEUILLES DE JEU de la tourelle laser (lot F1-C, 4/11) : des sprites de production aux fichiers du mod. Python 3.9.
Modèle : gun_e/feuilles.py (lots A2 et A3-jeu), sans éclat de tir ni réglage de bouche par l'image (le faisceau part du
point mesuré sur la géométrie : bouches.py -> bouches.json).

    py -3.9 tools/render/pieces/levels/laser_e/feuilles.py [--src DIR ...] [--dest graphics/levels/laser]
        [--directions 2-15=64] [--hors-regle-ok NOM,...] [--essai]

Écrit dans --dest (dossier du mod ; PNG HORS de git, décision D-6) :
  - socle et pièce de chaque âge (pièce e01 sous le laser vanilla ; socle et pièce paire des âges 2 à 15) : COPIES octet à
    octet des sprites de production (mêmes noms : hr-lase-eNN-socle-main.png…) ;
  - tête de chaque âge (2 à 15), par couche (main, shadow, glow) et résolution, UNE feuille de N images (N = 64 ou 32,
    --directions, âge par âge), rangée par rangée, 8 images par rangée (line_length 8), dans l'ordre d'une
    RotatedAnimation : image k = pose d(k × 64 / N), rotation uniforme depuis le nord, sens horaire (piece.DIRS) ;
    apply_projection laissé vrai (F121 : le moteur montre l'image k pour orientation_image(k)) ; cadre commun = union
    des poses, bords PAIRS (la version normale tombe au pixel) ; chaque pose collée à sa place exacte, pixels
    INCHANGÉS (contrôle : check_laser_sheets.py --sources) ; 8 192 px au plus par côté (F144, refus sinon) ;
  - icône de chaque âge (socle + tête E = d16, bande 120 × 64, fo_post.icon_strip, comme la mitrailleuse) ;
  - sprites.lua (lu par prototypes/levels/laser.lua), sprites.json (mêmes données + placement des poses, pour les
    outils), MANIFEST.json (chaque fichier : taille, sha256, dimensions ; sources : sha256 du spec.json et de chaque PNG ;
    commande). sprites.lua, sprites.json et MANIFEST.json sont COMMITÉS.
  - tir de chaque âge : bouches.json (source_offset {0, −L} tourné avec la tête, hauteur H du faisceau) recopié dans
    sprites.lua (« tir »).

Contrôles (refus, code non nul, rien d'écrit au-delà des PNG) : spec.json de la variante attendue ; production à 128
échantillons, ni rapide ni aperçu ; têtes à l'ombre de 32 échantillons (D-7, « samples_passes ») ; sha256 de chaque PNG égal
au spec.json ; trou enfermé ≤ 8 px (« holes_ok ») sauf variante inscrite dans --hors-regle-ok après regard ; pose manquante.
--essai (bancs du prototype AVANT la production) : échantillons quelconques, une pose manquante est remplacée par la
pose présente la plus proche en angle, et MANIFEST.json porte « essai » : vrai (le contrôle du harnais le REFUSE : un essai ne
part jamais en intégration).

Sources (--src, répétable : la dernière qui a la variante l'emporte) : par défaut la production du lot,
fo-logs/2026-11-04_LASER-F1C/production/sprites (à GARDER).
"""
import argparse
import hashlib
import json
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
import fo_post as P  # noqa: E402

MOD_NAME = "factorio-overhaul"
LOGS = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs"
SRC_DEFAUT = [os.path.join(LOGS, "2026-11-04_LASER-F1C", "production", "sprites")]
DEST_DEFAUT = os.path.join(MOD, "graphics", "levels", "laser")
BOUCHES = os.path.join(HERE, "bouches.json")
GRAPHICS_PREFIX = "__%s__/graphics/levels/laser/" % MOD_NAME
# Directions de la tête par âge (décision du lead sur le budget de l'atlas virtuel au plancher, 4/11) : « a-b=N,… »
DIRECTIONS_DEFAUT = "2-15=64"
TETE_COUCHES = ("main", "shadow", "glow")
FIXE_COUCHES = ("main", "shadow", "glow", "light")
LIGNE = 8
NDIR_MAX = 64
LIMITE_PX = 8192        # F144
SAMPLES_PASSES_TETE = {"shadow": 32}     # D-7 (lot A3)
# Variantes « HORS REGLE » (trou enfermé > 8 px) acceptées après regard. Production du 5/11 : e06-tete-d17 (15 px) et
# e06-tete-d47 (16 px), REGARDÉES (fo-logs/2026-11-04_LASER-F1C/trous_prod/e06_zoom.png, avec leurs voisines d16, d18,
# d46, d48 : 1 à 4 px) : jour mécanique entre le tore de porcelaine et le bout de la bobine de cuivre, vu de biais, environ
# 4 × 4 px en hr (2 × 2 en normale) ; aucun manque de matière. Verdict du DC NON rendu.
HORS_REGLE_OK_DEFAUT = ("e06-tete-d17", "e06-tete-d47")
COMMANDE = ("py -3.9 tools/render/pieces/levels/laser_e/feuilles.py   (depuis la racine du mod ; sources par défaut : "
            "en tête de feuilles.py)")


def sha_file(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def plages(spec):
    """« 2-9=64,10-15=32 » -> {âge: N}."""
    res = {}
    for x in [x for x in spec.split(",") if x.strip()]:
        plage, n = x.split("=")
        a, b = plage.split("-") if "-" in plage else (plage, plage)
        for e in range(int(a), int(b) + 1):
            res[e] = int(n)
    for e in range(2, 16):
        if res.get(e) not in (32, 64):
            raise SystemExit("--directions : âge %d à %s directions (32 ou 64 attendus)" % (e, res.get(e)))
    return res


def trouve(srcs, nom):
    for d in reversed(srcs):
        if os.path.exists(os.path.join(d, nom, "spec.json")):
            return d
    return None


def lire_spec(d, nom, essai):
    p = os.path.join(d, nom, "spec.json")
    if not os.path.exists(p):
        raise SystemExit("source absente : %s" % p)
    with open(p, encoding="utf-8") as f:
        s = json.load(f)
    if s.get("variant") != nom:
        raise SystemExit("%s : spec.json d'une autre variante (%s)" % (p, s.get("variant")))
    if s.get("kit") != "laser_e":
        raise SystemExit("%s : pas un rendu du kit laser_e (%s)" % (p, s.get("kit")))
    if not essai and (s.get("samples") != 128 or s.get("quick") or s.get("apercu")):
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


def couche_def(fichier_hr, fichier_lr, w, h, shift):
    return {"hr": {"filename": GRAPHICS_PREFIX + fichier_hr, "width": w, "height": h, "shift": [shift[0], shift[1]]},
            "lr": {"filename": GRAPHICS_PREFIX + fichier_lr, "width": w // 2, "height": h // 2,
                   "shift": [shift[0], shift[1]]}}


def noms_pose(e, kk):
    """Noms possibles de la pose dKK de l'âge e : eNN-tete-dKK, et les poses nommées des rondes (tete-N = d00, tete-E
    = d16, mêmes flottants : piece.DIRS)."""
    res = ["e%02d-tete-d%02d" % (e, kk)]
    if kk == 0:
        res.append("e%02d-tete-N" % e)
    if kk == 16:
        res.append("e%02d-tete-E" % e)
    return res


def poses_age(e, n, srcs, essai):
    """Liste de (dname, nom, dossier source, substitut) pour les N directions de l'âge e."""
    present = {}
    for kk in range(NDIR_MAX):
        for nom in noms_pose(e, kk):
            d = trouve(srcs, nom)
            if d:
                present[kk] = (nom, d)
                break
    res = []
    manquent = []
    for k in range(n):
        kk = k * NDIR_MAX // n
        dname = "d%02d" % kk
        if kk in present:
            res.append((dname, present[kk][0], present[kk][1], None))
            continue
        if not essai or not present:
            manquent.append(dname)
            continue
        proche = min(present, key=lambda p: (min((p - kk) % NDIR_MAX, (kk - p) % NDIR_MAX), p))
        res.append((dname, present[proche][0], present[proche][1], "d%02d" % proche))
    if manquent:
        raise SystemExit("[FO-FEUILLES-LASER] âge %d : %d pose(s) manquante(s) sur %d : %s" % (
            e, len(manquent), n, ",".join(manquent[:12]) + ("…" if len(manquent) > 12 else "")))
    return res


def controle_trous(nom, s, hors_regle_ok, essai, refus):
    c = s.get("checks", {})
    if not c.get("holes_ok", False) and nom not in hors_regle_ok:
        msg = "%s : trou enfermé de %s px (> 8, HORS REGLE ; regarder, puis --hors-regle-ok)" % (
            nom, c.get("largest_hole_px"))
        if essai:
            print("[FO-FEUILLES-LASER] (essai) " + msg)
        else:
            refus.append(msg)


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
    return ("-- FICHIER GÉNÉRÉ par tools/render/pieces/levels/laser_e/feuilles.py (lot F1-C) : ne pas modifier à la main.\n"
            "-- Tailles en pixels, shift en tuiles. hr = 64 px/tuile (scale 0,5), normale = 32 px/tuile.\n"
            "-- Têtes (RotatedAnimation) : direction_count 64 ou 32 selon l'âge, feuille rangée par rangée (line_length 8),\n"
            "-- image k = pose d(k × 64 / N), rotation uniforme depuis le nord, sens horaire, apply_projection vrai (F121).\n"
            "-- tir : source_offset (tourné avec la tête) et hauteur du faisceau, mesurés sur la géométrie (bouches.py).\n"
            "-- Images : MANIFEST.json (hors de git, D-6) ; régénérer : voir MANIFEST.json, « commande ».\n"
            "return ") + lua_value(donnees) + "\n"


def pour_lua(donnees):
    """Données du jeu : sans les sous-tables des outils (« poses » des couches de tête, « outils » de chaque âge)."""
    pl = json.loads(json.dumps(donnees))
    for e, A in pl["ages"].items():
        A.pop("outils", None)
        for lay, cd in A.get("tete", {}).items():
            cd.pop("poses", None)
    pl["ages"] = {int(k): v for k, v in pl["ages"].items()}
    return pl


def icone(dest, e, A, pose_e):
    """Socle + tête E (d16) composés hors Blender, réduits par fo_post.icon_strip (comme la mitrailleuse)."""
    sm = A["socle"]["main"]["hr"]
    socle = rgba(os.path.join(dest, os.path.basename(sm["filename"]))).astype(np.float64) / 255.0
    sb = boite_px({"width": sm["width"], "height": sm["height"], "shift": sm["shift"], "file": sm["filename"]})
    nom, s, d = pose_e
    L = s["layers"]["main"]
    tete = rgba(os.path.join(d, L["file"])).astype(np.float64) / 255.0
    tb = boite_px(L)
    L0, T0 = min(sb[0], tb[0]), min(sb[1], tb[1])
    R0, B0 = max(sb[2], tb[2]), max(sb[3], tb[3])
    can_s = np.zeros((B0 - T0, R0 - L0, 4))
    can_t = np.zeros_like(can_s)
    can_s[sb[1] - T0:sb[3] - T0, sb[0] - L0:sb[2] - L0] = socle
    can_t[tb[1] - T0:tb[3] - T0, tb[0] - L0:tb[2] - L0] = tete
    strip = P.icon_strip(P.over(can_t, can_s))
    f = "laser-e%02d-icone.png" % e
    ecrire_png(P.to_u8(strip), os.path.join(dest, f))
    return {"filename": GRAPHICS_PREFIX + f, "icon_size": 64, "icon_mipmaps": 4}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", action="append", default=None, help="dossier de sprites (répétable)")
    ap.add_argument("--dest", default=DEST_DEFAUT)
    ap.add_argument("--directions", default=DIRECTIONS_DEFAUT, help="directions de la tête par âge, ex. 2-9=64,10-15=32")
    ap.add_argument("--hors-regle-ok", default="", help="variantes HORS REGLE acceptées après regard (virgules)")
    ap.add_argument("--essai", action="store_true", help="banc du prototype avant production (refusé par le harnais)")
    ap.add_argument("--ages", default="", help="(essai seulement) âges à écrire, ex. 2,15 ; les autres sont omis")
    a = ap.parse_args()
    srcs = [os.path.abspath(x) for x in (a.src or SRC_DEFAUT)]
    ndirs = plages(a.directions)
    hors_regle_ok = tuple(sorted(set(HORS_REGLE_OK_DEFAUT) | set(x for x in a.hors_regle_ok.split(",") if x)))
    if a.ages and not a.essai:
        raise SystemExit("--ages n'est permis qu'avec --essai (une production écrit les 15 âges)")
    ages_voulus = [int(x) for x in a.ages.split(",") if x] if a.ages else list(range(2, 16))
    with open(BOUCHES, encoding="utf-8") as f:
        bouches = json.load(f)["ages"]
    dest = os.path.abspath(a.dest)
    os.makedirs(dest, exist_ok=True)
    for f in os.listdir(dest):
        if f.endswith(".png"):
            os.remove(os.path.join(dest, f))
    sources = {}
    ages = {}
    refus = []
    bilan = []

    def note_source(nom, s, d):
        sources[nom] = {"dossier": d, "spec_sha256": sha_file(os.path.join(d, "spec.json")),
                        "couches": {lay: {"hr": L["sha256"], "lr": L["lr"]["sha256"]} for lay, L in s["layers"].items()},
                        "echantillons": s["samples"], "trous_px": s.get("checks", {}).get("largest_hole_px")}
        if s.get("samples_passes"):
            sources[nom]["samples_passes"] = s["samples_passes"]

    def copie(d, L):
        for LL in (L, L["lr"]):
            shutil.copyfile(os.path.join(d, LL["file"]), os.path.join(dest, LL["file"]))
        return couche_def(L["file"], L["lr"]["file"], L["width"], L["height"], L["shift"])

    def fixe(nom):
        d0 = trouve(srcs, nom)
        if d0 is None:
            raise SystemExit("source absente : %s (dossiers %s)" % (nom, srcs))
        s, d = lire_spec(d0, nom, a.essai)
        controle_trous(nom, s, hors_regle_ok, a.essai, refus)
        note_source(nom, s, d)
        return {lay: copie(d, s["layers"][lay]) for lay in FIXE_COUCHES if lay in s["layers"]}

    ages[1] = {"piece": fixe("e01-piece")}
    for e in ages_voulus:
        A = {"socle": fixe("e%02d-socle" % e), "piece": fixe("e%02d-piece" % e)}
        n = ndirs[e]
        rows = n // LIGNE
        poses = []
        substituts = {}
        for dname, nom, d0, sub in poses_age(e, n, srcs, a.essai):
            s, d = lire_spec(d0, nom, a.essai)
            if not a.essai and s.get("samples_passes") != SAMPLES_PASSES_TETE:
                raise SystemExit("%s : samples_passes %s, attendu %s (D-7)" % (nom, s.get("samples_passes"),
                                                                                SAMPLES_PASSES_TETE))
            controle_trous(nom, s, hors_regle_ok, a.essai, refus)
            note_source(nom, s, d)
            poses.append((dname, nom, s, d))
            if sub:
                substituts[dname] = sub
        tete = {}
        vides = {}
        u = [1e9, 1e9, -1e9, -1e9]
        for lay in TETE_COUCHES:
            presentes = [p for p in poses if lay in p[2]["layers"]]
            if not presentes:
                continue
            # une pose sans cette couche (lueur cachée par le corps dans cette direction) laisse sa cellule vide
            if len(presentes) != len(poses):
                vides.setdefault(lay, []).extend(p[0] for p in poses if lay not in p[2]["layers"])
            boites = {p[0]: boite_px(p[2]["layers"][lay]) for p in presentes}
            L0 = min(b[0] for b in boites.values())
            T0 = min(b[1] for b in boites.values())
            R0 = max(b[2] for b in boites.values())
            B0 = max(b[3] for b in boites.values())
            W, H = R0 - L0, B0 - T0
            if LIGNE * W > LIMITE_PX or rows * H > LIMITE_PX:
                raise SystemExit("[FO-FEUILLES-LASER] âge %d tête %s : feuille %d × %d px, au-delà de %d (F144)" % (
                    e, lay, LIGNE * W, rows * H, LIMITE_PX))
            hr = np.zeros((rows * H, LIGNE * W, 4), np.uint8)
            lr = np.zeros((rows * H // 2, LIGNE * W // 2, 4), np.uint8)
            cellules = {}
            for k, (dname, nom, s, d) in enumerate(poses):
                if lay not in s["layers"]:
                    continue
                L = s["layers"][lay]
                gx, gy, rx, by = boites[dname]
                ih = rgba(os.path.join(d, L["file"]))
                il = rgba(os.path.join(d, L["lr"]["file"]))
                assert ih.shape[:2] == (L["height"], L["width"]), nom
                assert il.shape[:2] == (L["height"] // 2, L["width"] // 2), nom
                cx, cy = (k % LIGNE) * W, (k // LIGNE) * H
                y0, x0 = cy + gy - T0, cx + gx - L0
                hr[y0:y0 + ih.shape[0], x0:x0 + ih.shape[1]] = ih
                lr[y0 // 2:y0 // 2 + il.shape[0], x0 // 2:x0 // 2 + il.shape[1]] = il
                cellules[dname] = {"source": nom, "x": gx - L0, "y": gy - T0, "k": k}
                if lay in ("main", "glow"):
                    u[0], u[1] = min(u[0], gx / 64.0), min(u[1], gy / 64.0)
                    u[2], u[3] = max(u[2], rx / 64.0), max(u[3], by / 64.0)
            fh, fl = "hr-laser-e%02d-tete-%s.png" % (e, lay), "laser-e%02d-tete-%s.png" % (e, lay)
            ecrire_png(hr, os.path.join(dest, fh))
            ecrire_png(lr, os.path.join(dest, fl))
            cd = couche_def(fh, fl, W, H, ((L0 + R0) / 2.0 / 64.0, (T0 + B0) / 2.0 / 64.0))
            for r in ("hr", "lr"):
                cd[r]["direction_count"] = n
                cd[r]["line_length"] = LIGNE
            cd["poses"] = cellules
            tete[lay] = cd
        A["tete"] = tete
        for part in ("socle", "piece"):
            for lay in ("main", "glow"):
                if lay in A[part]:
                    h = A[part][lay]["hr"]
                    u[0] = min(u[0], h["shift"][0] - h["width"] / 128.0)
                    u[1] = min(u[1], h["shift"][1] - h["height"] / 128.0)
                    u[2] = max(u[2], h["shift"][0] + h["width"] / 128.0)
                    u[3] = max(u[3], h["shift"][1] + h["height"] / 128.0)
        A["boite"] = [[round(u[0], 5), round(u[1], 5)], [round(u[2], 5), round(u[3], 5)]]
        b = bouches[str(e)]["tir"]
        A["tir"] = {"source_offset": [b["source_offset"][0], b["source_offset"][1]], "hauteur": b["hauteur"]}
        pe = [p for p in poses if p[0] == "d16"]
        if not pe:
            raise SystemExit("âge %d : pas de pose d16 (E) pour l'icône" % e)
        A["icone"] = icone(dest, e, A, (pe[0][1], pe[0][2], pe[0][3]))
        A["outils"] = {"directions": n, "noms": [p[0] for p in poses], "substituts": substituts, "cellules_vides": vides}
        ages[e] = A
        bilan.append((e, n, len(substituts)))
    if refus:
        for r in refus:
            print("[FO-FEUILLES-LASER] REFUS " + r)
        raise SystemExit("[FO-FEUILLES-LASER] %d variante(s) HORS REGLE non regardée(s)" % len(refus))
    donnees = {"ages": ages, "essai": bool(a.essai)}
    with open(os.path.join(dest, "sprites.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(texte_lua(pour_lua(donnees)))
    with open(os.path.join(dest, "sprites.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(donnees, f, indent=1, sort_keys=True)
    fichiers = {}
    for f in sorted(os.listdir(dest)):
        if f.endswith(".png"):
            p = os.path.join(dest, f)
            with Image.open(p) as im:
                w, h = im.size
            fichiers[f] = {"taille": os.path.getsize(p), "sha256": sha_file(p), "largeur": w, "hauteur": h}
    manifeste = {"commande": COMMANDE, "outil": "tools/render/pieces/levels/laser_e/feuilles.py",
                 "arguments": sys.argv[1:], "essai": bool(a.essai), "hors_regle_ok": list(hors_regle_ok),
                 "controle": "py -3.9 tools/render/pieces/levels/laser_e/check_laser_sheets.py [--sources]",
                 "git": "PNG hors de git (.gitignore : graphics/levels/laser/*.png, décision D-6) ; ce manifeste, "
                        "sprites.lua et sprites.json sont commités",
                 "directions": {str(e): n for e, n, _ in bilan},
                 "bouches_sha256": sha_file(BOUCHES),
                 "sources": sources, "fichiers": fichiers,
                 "sprites_lua_sha256": sha_file(os.path.join(dest, "sprites.lua")),
                 "sprites_json_sha256": sha_file(os.path.join(dest, "sprites.json"))}
    with open(os.path.join(dest, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifeste, f, indent=1, sort_keys=True)
    tot = sum(v["taille"] for v in fichiers.values())
    print("[FO-FEUILLES-LASER] %d fichiers PNG, %.2f Mo, %d sources ; têtes : %s%s ; dest %s" % (
        len(fichiers), tot / 1e6, len(sources),
        ", ".join("âge %d %d" % (e, n) for e, n, _ in bilan),
        (" ; ESSAI, poses remplacées : %d" % sum(s for _, _, s in bilan)) if a.essai else "", dest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
