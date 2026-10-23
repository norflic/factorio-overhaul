"""OUTIL COMMUN DE RENDU de la mitrailleuse V3-E (kit gun_e) : rendu par paquets + post-traitement. FICHIER GELÉ.

    py -3.9 tools/render/pieces/levels/gun_e/rendre.py --out DIR [--cache DIR] [--samples 128] [--quick]
        [--only e02-socle,…] | [--epochs 2,3 --parts socle,piece,tete-E,tete-N] | [--kit 2,5]
        [--per 4] [--post-only] [--keep-npy] [--corps A|B] [--apercu] [--sessions 1|2] [--habillage NOM]
        [--dirs rose|N,NE,…|d00,…]     (dégel D-9, lot A1 : têtes tournées eNN-tete-dKK, d00 = nord, sens horaire)
        [--samples-passes shadow=32]   (décision D-7, lot A3 : échantillons propres à une passe ; spec.json le dit)
    py -3.9 tools/render/pieces/levels/gun_e/rendre.py --ronde 2,5,9 --out DIR [--corps A|B] [--sessions 2]

RONDE DE LECTURE (passe 5) : --ronde EPOQUES rend, en APERÇU (32 échantillons, --apercu), exactement ce qu'il faut
pour les vignettes E et N du niveau impair (vignettes.py) : eNN-socle, eNN-tete-E, eNN-tete-N (époque 1 : e01-piece,
le niveau 1 est vanilla), 9 variantes par session Blender, 2 sessions en parallèle (--sessions 2 : chacune prend sa
place au verrou de rendu ; c'est le maximum permis sur le PC). --apercu : toutes les passes de jour (ombre, liseré de
contact, lueur), sans le halo de nuit. --corps A|B : variante de corps de ce rendu (sinon corps_choix.py).
--habillage pionnier|fusion|legende (passe 5, deuxième temps du kit) : habillage d'essai du TÉMOIN (habillages.py),
avec --kit seulement ; écrit dans render.json, spec.json et temps.json.

1. Les variantes sont rendues par PAQUETS de --per variantes, une session Blender par paquet (batch_blender.py),
   chacune lancée par le verrou de rendu prescrit (interdit n° 6) : « python tools/render/with_render_lock.py --
   <blender …> » (2 rendus au plus sur le PC, priorité inférieure à la normale). Une session ne prend qu'UNE place ;
   le verrou est rendu entre deux paquets (l'autre constructeur rend aussi).
2. Post-traitement avec tools/render/fo_post.py (inchangé) : liseré de contact sous la couche principale du socle et
   de la pièce paire, ombre, lueur additive, halo V0b borné et normalisé au sol (pic 0,45). Foyers de NUIT (époque 1,
   epoques.FAMILLES) : la lueur passe dans la couche halo (draw_as_light), il n'y a pas de couche lueur.
3. Sorties hr (64 px/tuile) ET normales (32 px/tuile : réduction 2×2 en linéaire, additive pour lueur et halo),
   spec.json (largeur, hauteur, shift, sha256, contrôles : trous enfermés, plus grand trou, éléments fins). Les passes
   brutes (.npy, float32) sont PURGÉES dès que le spec.json est écrit (disque H: presque plein), sauf --keep-npy.
Essais rapides : --quick --samples 16 (passes main, glow et shadow ; pas de liseré de contact ni de halo).
Rendus de production : --samples 128, jamais --quick (les juges refusent un essai rapide).
"""
import argparse
import json
import os
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
MOD = os.path.dirname(os.path.dirname(RENDER))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_checks as FC  # noqa: E402
import fo_post as P  # noqa: E402
import piece  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
BATCH = os.path.join(HERE, "batch_blender.py")
HALO_PEAK = 0.45
_VERROU_JOURNAL = threading.Lock()


def largest_hole(alpha):
    n, _, holes = FC.enclosed_transparent(alpha)
    if not n:
        return 0, 0, 0
    sys.path.insert(0, os.path.join(MOD, "tools", "da"))
    import da_lib as D
    sizes, _ = D.components(holes, conn8=False)
    return n, len(sizes), max(sizes.values())


def merge_additive(a, b):
    """Somme de deux couches additives (RGB normalisé, A = intensité) -> même format."""
    pm = a[..., :3] * a[..., 3:4] + b[..., :3] * b[..., 3:4]
    m = np.clip(pm.max(-1, keepdims=True), 0, 1)
    rgb = np.where(m > 1e-6, pm / np.maximum(pm.max(-1, keepdims=True), 1e-6), 0)
    return np.concatenate([rgb, m], -1)


def post(name, cache, out_root):
    d = os.path.join(cache, name)
    with open(os.path.join(d, "render.json"), encoding="utf-8") as f:
        info = json.load(f)
    meta = piece.PIECE["variants"][name]
    origin = tuple(info["origin_px"])

    def npy(layer):
        if layer not in info.get("layers", []):
            return None
        p = os.path.join(d, "%s-%s.npy" % (name, layer))
        return np.load(p).astype(np.float64) if os.path.exists(p) else None

    main_raw = npy("main")
    hr = {"main": P.compose_main(main_raw, npy("ao"), C)}
    sh = npy("shadow")
    if sh is not None:
        hr["shadow"] = P.shadow_layer(sh)
    g = npy("glow")
    if g is not None:
        hr["glow"] = P.additive_layer(g)
    li = npy("light")
    if li is not None:
        free = np.minimum(li[..., 3], 1.0 - np.clip(main_raw[..., 3], 0, 1))
        lay = P.light_layer(np.concatenate([li[..., :3], free[..., None]], -1), C.LIGHT_SCALE)
        side = meta["side"]
        lay = P.radial_window(lay, origin, (0.5 * side + 0.15) * 64, (0.5 * side + 1.25) * 64)
        ground = (free > 0.5) & (lay[..., 3] > 0)
        ref = np.percentile(lay[..., 3][ground], 99.5) if ground.any() else 0.0
        if ref > 1e-6:
            lay[..., 3] = np.minimum(1.0, lay[..., 3] * HALO_PEAK / ref)
        hr["light"] = P.floor_alpha(P.fade_edges(lay))
    if meta["nuit"] and "glow" in hr:
        gl = hr.pop("glow")
        hr["light"] = merge_additive(hr["light"], gl) if "light" in hr else gl
    out = os.path.join(out_root, name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    spec = {"variant": name, "level": meta["level"], "epoch": meta["epoch"], "part": meta["part"],
            "dir": meta.get("dir"), "side": meta["side"], "samples": info["samples"], "seconds": info["seconds"],
            "seconds_render": info.get("seconds_render"), "verts": info.get("verts"), "count": info.get("count"),
            "quick": info.get("quick"), "canvas": info["canvas"], "night_only": meta["nuit"],
            "sous_vanilla": meta["sous_vanilla"], "kit": "gun_e", "corps": info.get("corps"),
            "apercu": info.get("apercu"), "habillage": info.get("habillage"), "layers": {}}
    if info.get("samples_passes"):
        spec["samples_passes"] = info["samples_passes"]     # D-7 (lot A3) : échantillons propres à une passe
    for layer in ("main", "shadow", "glow", "light"):
        if layer not in hr:
            continue
        img = hr[layer]
        box = P.trim_box(img, origin)
        if box is None:
            continue
        x0, y0, x1, y1 = box
        crop = img[y0:y1, x0:x1]
        crop_lr = P.downsample2_additive(crop) if layer in ("glow", "light") else P.downsample2(crop)
        fn = "hr-gune-%s-%s.png" % (name, layer)
        fn_lr = "gune-%s-%s.png" % (name, layer)
        sha = P.write_png(crop, os.path.join(out, fn))
        sha_lr = P.write_png(crop_lr, os.path.join(out, fn_lr))
        sd = P.sprite_def(box, origin, 64)
        sd_lr = P.sprite_def(box, origin, 32)
        spec["layers"][layer] = {"file": fn, "width": sd["width"], "height": sd["height"], "shift": sd["shift"],
                                 "sha256": sha, "draw_as": {"shadow": "shadow", "glow": "glow",
                                                            "light": "light"}.get(layer, "main"),
                                 "lr": dict(sd_lr, file=fn_lr, sha256=sha_lr)}
    n, ng, big = largest_hole(main_raw[..., 3])
    thin, thin_part = FC.thin_pixels(hr["main"][..., 3])
    spec["checks"] = {"enclosed_transparent_px": int(n), "enclosed_groups": int(ng), "largest_hole_px": int(big),
                      "holes_ok": bool(big <= 8), "thin_px": int(thin), "thin_part": float(thin_part)}
    with open(os.path.join(out, "spec.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1, sort_keys=True)
    return spec


def session(names, a):
    # garde de disque du verrou (lot A3) : refus (code 4) s'il reste moins de 1 Go libre sur le disque du cache ou de la
    # sortie (FO_RENDER_MIN_LIBRE_GO pour un autre seuil)
    cmd = [sys.executable, LOCK, "--disque", a.cache, "--disque", a.out, "--", BLENDER, "-b", "--factory-startup",
           "-noaudio", "--python-exit-code", "1",
           "-P", BATCH, "--", "--names", ",".join(names), "--out", a.cache, "--samples", str(a.samples)]
    if a.quick:
        cmd.append("--quick")
    if a.samples_passes:
        cmd += ["--samples-passes", a.samples_passes]
    elif a.apercu:
        cmd.append("--apercu")
    t0 = time.time()
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    env.pop("FO_CORPS", None)
    if a.corps:
        env["FO_CORPS"] = a.corps
    env.pop("FO_HABILLAGE_ESSAI", None)
    if a.habillage:
        env["FO_HABILLAGE_ESSAI"] = a.habillage
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    log = []
    t_lock = None
    for raw in p.stdout:
        line = raw.decode("utf-8", "replace").rstrip()
        log.append(line)
        if t_lock is None and ("Blender" in line or "[FO-RENDER]" in line or "Read prefs" in line):
            t_lock = time.time() - t0
        if line.startswith("[FO-RENDER]") or line.startswith("[fo-render]") or "Error" in line or "Traceback" in line:
            print(line, flush=True)
    rc = p.wait()
    dt = time.time() - t0
    with _VERROU_JOURNAL:
        with open(os.path.join(a.cache, "rendre.log"), "a", encoding="utf-8") as f:
            f.write("\n".join(log[-400:]) + "\n")
        tj = os.path.join(a.cache, "temps.json")
        hist = json.load(open(tj, encoding="utf-8")) if os.path.exists(tj) else []
        hist.append({"date": time.strftime("%Y-%m-%d %H:%M:%S"), "names": names, "samples": a.samples,
                     "quick": a.quick, "apercu": a.apercu, "corps": a.corps or "corps_choix.py",
                     "samples_passes": a.samples_passes or None,
                     "habillage": a.habillage or None,
                     "total_s": round(dt, 1), "attente_verrou_et_demarrage_s": round(t_lock or 0, 1), "code": rc})
        with open(tj, "w", encoding="utf-8") as f:
            json.dump(hist, f, indent=1)
    print("[FO-BATCH] %d variantes, %.0f s en tout (dont %.0f s avant la 1re sortie de Blender), code %d"
          % (len(names), dt, t_lock or 0, rc), flush=True)
    if rc != 0:
        print("\n".join(log[-60:]))
    return rc


def dirs_parts(spec):
    """--dirs (dégel D-9, lot A1) : « rose » (8 directions), noms de boussole (N, NE, E, SE, S, SO, O, NO) ou dKK
    (K = 00 à 63) -> parties « tete-dKK » (d00 = nord, sens horaire)."""
    boussole = dict(piece.ROSE)
    res = []
    for x in [x.strip() for x in (spec or "").split(",") if x.strip()]:
        ds = [d for _, d in piece.ROSE] if x == "rose" else [boussole.get(x, x)]
        for d in ds:
            if d not in piece.DIRS or not d.startswith("d"):
                raise SystemExit("direction inconnue : %s (rose, N…NO, ou d00 à d63)" % x)
            if "tete-" + d not in res:
                res.append("tete-" + d)
    return res


def selection(a):
    V = piece.PIECE["variants"]
    if a.only:
        names = [n for n in a.only.split(",") if n]
    elif a.ronde:
        names = []
        import profil   # lot K0 : variantes d'une ronde de lecture, profil de la famille (gun_e/profil.py)
        for e in [int(x) for x in a.ronde.split(",") if x]:
            names += profil.ronde(e)
    else:
        names = []
        for e in [int(x) for x in a.epochs.split(",") if x]:
            for p in [x for x in a.parts.split(",") if x] + dirs_parts(a.dirs):
                n = "e01-piece" if e == 1 else piece.nom(e, p)
                if n not in names:
                    names.append(n)
        for s in [int(x) for x in a.kit.split(",") if x]:
            for p in ("socle", "tete-N", "tete-E"):
                names.append("k%d-%s" % (s, p))
    bad = [n for n in names if n not in V]
    if bad:
        raise SystemExit("variantes inconnues : %s" % ", ".join(bad))
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--epochs", default="")
    ap.add_argument("--parts", default="socle,piece,tete-E,tete-N")
    ap.add_argument("--dirs", default="", help="têtes tournées (dégel D-9) ajoutées aux --parts : rose, N,NE,…,NO ou "
                                               "d00…d63 (d00 = nord, sens horaire) ; ex. --parts \"\" --dirs rose")
    ap.add_argument("--kit", default="", help="tailles du témoin du kit (lignée seule), ex. 2,5")
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--samples-passes", default="",
                    help="décision D-7 (lot A3) : échantillons propres à une passe, ex. « shadow=32 » (E66) ; les autres "
                         "passes gardent --samples ; vide (défaut) : rendu inchangé")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--post-only", action="store_true")
    ap.add_argument("--keep-npy", action="store_true", help="garder les passes brutes .npy après le post-traitement")
    ap.add_argument("--per", type=int, default=4, help="variantes par session Blender")
    ap.add_argument("--out", required=True)
    ap.add_argument("--cache", default="")
    ap.add_argument("--corps", default="", choices=("", "A", "B"),
                    help="variante de corps de ce rendu (sinon corps_choix.py)")
    ap.add_argument("--apercu", action="store_true", help="passes de jour seulement (sans halo de nuit)")
    ap.add_argument("--ronde", default="", help="époques d'une ronde de lecture : aperçu 32 échantillons, "
                                                "variantes des vignettes E et N du niveau impair")
    ap.add_argument("--sessions", type=int, default=1, choices=(1, 2), help="sessions Blender en parallèle")
    ap.add_argument("--habillage", default="", help="habillage d'essai du TÉMOIN (habillages.py : pionnier, fusion, "
                                                    "legende) ; refusé pour une époque")
    a = ap.parse_args()
    if a.ronde:
        a.apercu = True
        if a.samples == 128:
            a.samples = 32
        if a.per == 4:
            a.per = 9
    a.cache = a.cache or os.path.join(os.path.dirname(os.path.abspath(a.out)), "cache_" + os.path.basename(a.out))
    names = selection(a)
    if a.habillage:
        import habillages
        if a.habillage not in habillages.PRESETS:
            raise SystemExit("habillage d'essai inconnu : %s (%s)" % (a.habillage, ", ".join(sorted(habillages.PRESETS))))
        if any(not n.startswith("k") for n in names):
            raise SystemExit("--habillage ne s'applique qu'au témoin du kit (--kit)")
    os.makedirs(a.cache, exist_ok=True)
    t_debut = time.time()
    chunks = [names[i:i + a.per] for i in range(0, len(names), max(1, a.per))]
    if a.sessions > 1 and len(chunks) > 1:
        # paquets équilibrés : une variante sur deux à chaque session (les grandes tailles en fin de liste)
        chunks = [names[k::a.sessions] for k in range(a.sessions)]
        chunks = [c[i:i + a.per] for c in chunks for i in range(0, len(c), max(1, a.per))]

    def un_paquet(i_chunk):
        i, chunk = i_chunk
        if not a.post_only:
            print("[FO-LOTS] paquet %d/%d : %s" % (i + 1, len(chunks), ",".join(chunk)), flush=True)
            rc = session(chunk, a)
            if rc:
                return rc
        post_paquet(chunk, a)
        return 0

    if a.sessions > 1 and not a.post_only:
        with ThreadPoolExecutor(max_workers=a.sessions) as ex:
            rcs = list(ex.map(un_paquet, enumerate(chunks)))
    else:
        rcs = [un_paquet(ic) for ic in enumerate(chunks)]
    rc_all = next((r for r in rcs if r), 0)
    print("[FO-RENDRE] %d variantes en %.0f s (%s, %d échantillons, corps %s, %d session(s))" % (
        len(names), time.time() - t_debut, "aperçu" if a.apercu else ("rapide" if a.quick else "complet"),
        a.samples, a.corps or "de corps_choix.py", a.sessions), flush=True)
    sys.exit(rc_all)


def post_paquet(chunk, a):
    """Post-traitement des variantes d'un paquet rendu (passes brutes purgées ensuite, sauf --keep-npy)."""
    for n in chunk:
        if not os.path.exists(os.path.join(a.cache, n, "render.json")):
            continue
        if not any(f.endswith(".npy") for f in os.listdir(os.path.join(a.cache, n))):
            print("[FO-POST] %s : passes déjà purgées, rien à refaire" % n, flush=True)
            continue
        s = post(n, a.cache, a.out)
        if not a.keep_npy:
            for f in os.listdir(os.path.join(a.cache, n)):
                if f.endswith(".npy"):
                    os.remove(os.path.join(a.cache, n, f))
        c = s["checks"]
        print("[FO-POST] %s %s %.0f s ; trous %d px en %d groupes, plus grand %d px %s ; corps %s" % (
            n, sorted(s["layers"]), s["seconds"], c["enclosed_transparent_px"], c["enclosed_groups"],
            c["largest_hole_px"], "OK" if c["holes_ok"] else "ECHEC", s.get("corps")), flush=True)


if __name__ == "__main__":
    main()
