r"""Les couches de son du lot TIRS sont-elles JOUÉES en jeu, à leur VITESSE, et la RAFALE suit-elle la prévision ?
(lot TIRS, ronde 4 ; scénario greffé tirs-son, session FO_AUDIO=1, pilote SDL disk : rien n'atteint la sortie du PC)

    py -3.9 -B tools/sound/tirs_couches.py <audio-disk.raw> <factorio.log de la session> [--mod RACINE] [--json SORTIE]

Méthode (mêmes décodage et corrélation que tools/sound/tirs_joues.py, lot S0-suite) :
  1. instants : droite temps = a + b × tick ajustée sur les tirs isolés (journal « [FO-TIRS-SON] TIR ») par filtre adapté
     contre les tirs S0 et vanilla ;
  2. tir isolé d'un âge à couches : le tir S0 de l'ère (meilleure des 4 variations, ± 40 ms) est retiré par moindres
     carrés ; sur le RÉSIDU, pour chaque couche ajoutée, corrélation normalisée maximale (± 30 ms, meilleure variation)
     avec le fichier de la couche lu (H_v) à la vitesse de la table (milieu de [min, max]) et (H_1) à la vitesse 1 ;
     verdict « vitesse appliquée » si ρ(H_v) dépasse ρ(H_1) de 0,05 au moins en moyenne sur les couches à vitesse
     éloignée de 1 (|v − 1| >= 0,1) ; défaut de la ronde 3 : la vitesse posée sur la couche était ignorée (F360 voisin) ;
  3. rafale (journal « RAFALE debut / fin ») : sonie momentanée maximale (BS.1770, 400 ms) de la fenêtre, rapportée à la
     rafale du site vanilla ; comparée à tools/sound/tirs_sonie.py pour la même cadence, sous deux hypothèses
     d'`aggregation` : H_agg (une couche ne démarre un son que si moins de max_count jouent) et H_libre (aucune limite).
     La plus proche (écart > 0,5 dB entre les deux prévisions) départage F360.
Code 0 si la vitesse est appliquée sur chaque site à couches et si la rafale mesurée croît avec l'âge, 1 sinon, 2 si
l'entrée est illisible.
"""
import argparse
import json
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import rafales  # noqa: E402
import tirs_joues as TJ  # noqa: E402
import tirs_sonie as TS  # noqa: E402

AUDIO_LINE = TJ.AUDIO_LINE
TIR = re.compile(r"\[FO-TIRS-SON\] TIR\t(.*)$", re.M)
RAF = re.compile(r"\[FO-TIRS-SON\] RAFALE\t(.*)$", re.M)
L_SEG = 1.6   # s : segment d'un tir isolé (tirs séparés de 1 s ; la queue du précédent est faible)


def champs(txt):
    return {k: (int(v) if v.lstrip("-").isdigit() else v) for k, v in (kv.split("=", 1) for kv in txt.strip().split("\t")
                                                                        if "=" in kv)}


def ncc_max(x, y, lag):
    """Corrélation normalisée maximale de x (résidu) avec y (gabarit), décalage de 0 à lag échantillons."""
    if len(y) > len(x) - lag:
        y = y[:len(x) - lag]
    r = TJ.ncc(x[:len(y) + lag], y)
    return float(r.max()) if len(r) else 0.0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw")
    ap.add_argument("log")
    ap.add_argument("--mod", default=REPO)
    ap.add_argument("--json")
    a = ap.parse_args()
    try:
        log = open(a.log, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print("[FO-TIRS-COUCHES] ECHEC journal illisible : %s" % exc)
        return 2
    m = AUDIO_LINE.search(log)
    if not m:
        print("[FO-TIRS-COUCHES] ECHEC pas de ligne [Audio] : session sans son ?")
        return 2
    depth, ch, fs = int(m.group(2)), int(m.group(3)), int(m.group(4))
    if depth != 16 or fs != TS.RATE:
        print("[FO-TIRS-COUCHES] ECHEC format %d bits %d Hz non lu" % (depth, fs))
        return 2
    tirs = [champs(t) for t in TIR.findall(log)]
    raf = [champs(t) for t in RAF.findall(log)]
    if not tirs:
        print("[FO-TIRS-COUCHES] ECHEC aucun tir au journal")
        return 2
    raw = np.fromfile(a.raw, dtype="<i2").astype(np.float64) / 32768.0
    st = raw[:len(raw) // ch * ch].reshape(-1, ch)
    x = st.mean(axis=1)
    print("[FO-TIRS-COUCHES] sortie %.1f s, %d voies ; %d tirs isoles, %d rafales au journal" % (len(x) / fs, ch, len(tirs),
                                                                                              len(raf)))
    ages = {g["age"]: g for g in TS.lire_ages(a.mod)}
    s0_ere = {}
    for g in ages.values():
        s0_ere[g["ere"]] = g["s0"]
    # 1. instants
    tpl = []
    for name, era, var, path in TJ.templates(a.mod, os.path.join(TS.GAME, "data")):
        y, rate = TJ.decode(path)
        tpl.append({"name": name, "era": era, "var": var, "y": y, "rho": TJ.ncc(x, y)})
    n = min(len(t["rho"]) for t in tpl)
    best = np.vstack([t["rho"][:n] for t in tpl]).max(axis=0)
    dets = [{"t": j / float(fs)} for j in TJ.peaks(best, fs, 0.4, 0.3)]
    fit = TJ.fit_times(tirs, dets, 0.06)
    if fit is None:
        print("[FO-TIRS-COUCHES] ECHEC aucun tir entendu")
        return 1
    fa, fb = fit
    print("[FO-TIRS-COUCHES] droite temps = %.4f + %.7f x tick (%d detections)" % (fa, fb, len(dets)))
    # 2. couches à leur vitesse
    res, ok_v = {}, True
    for age in sorted({t["age"] for t in tirs if t["ere"] > 0}):
        g = ages.get(age)
        if not g or not g["couches"]:
            continue
        s0 = [TJ.decode(TS.chemin(a.mod, f))[0] for f in g["s0"]]
        rho = {"v": [], "1": []}
        pour_couche = []
        for t in [t for t in tirs if t["age"] == age]:
            i0 = int(round((fa + fb * t["tick"]) * fs))
            seg = x[max(0, i0 - int(0.04 * fs)):i0 + int(L_SEG * fs)]
            # S0 : meilleure variation et décalage
            bk, bi, br = 0, 0, -1
            for k, y in enumerate(s0):
                r = TJ.ncc(seg[:len(y) + int(0.08 * fs)], y)
                if len(r) and r.max() > br:
                    bk, bi, br = k, int(r.argmax()), float(r.max())
            y = s0[bk]
            w = seg[bi:bi + len(y)]
            gain = float(np.dot(w, y[:len(w)]) / np.dot(y[:len(w)], y[:len(w)]))
            resid = seg[bi:].copy()
            L = min(len(resid), len(y))
            resid[:L] -= gain * y[:L]
            for c in g["couches"]:
                vm = 0.5 * (c["vmin"] + c["vmax"])
                pv, p1 = 0.0, 0.0
                for f in c["fichiers"]:
                    z = TJ.decode(TS.chemin(a.mod, f))[0]
                    pv = max(pv, ncc_max(resid, TS.vitesse(z, vm), int(0.03 * fs)))
                    p1 = max(p1, ncc_max(resid, z, int(0.03 * fs)))
                pour_couche.append((os.path.basename(c["fichiers"][0]).rsplit("-", 1)[0], vm, pv, p1))
                if abs(vm - 1) >= 0.1:
                    rho["v"].append(pv)
                    rho["1"].append(p1)
        mv, m1 = float(np.mean(rho["v"])) if rho["v"] else 0, float(np.mean(rho["1"])) if rho["1"] else 0
        verdict = mv - m1 >= 0.05
        ok_v = ok_v and verdict
        par = {}
        for nom, vm, pv, p1 in pour_couche:
            par.setdefault((nom, vm), []).append((pv, p1))
        det = " ; ".join("%s a %.2f : rho(H_v) %.2f, rho(H_1) %.2f" % (nom, vm, np.mean([u for u, _ in l]),
                                                                       np.mean([w for _, w in l]))
                         for (nom, vm), l in par.items())
        print("[FO-TIRS-COUCHES] age %2d : %s -> moyenne rho(H_v) %.3f contre rho(H_1) %.3f : %s" % (
            age, det, mv, m1, "VITESSE APPLIQUEE" if verdict else "VITESSE NON DEMONTREE"))
        res[age] = {"rho_v": mv, "rho_1": m1, "vitesse_appliquee": verdict}
    # 3. rafales
    ref = None
    mes = {}
    for r in raf:
        t0 = fa + fb * r["debut"]
        t1 = fa + fb * r["fin"] + 1.0
        w = st[int(t0 * fs):int(t1 * fs)]
        if ch == 1:
            w = np.repeat(w[:, None], 2, axis=1)
        mm = rafales.mesures(w[:, :2])
        cad = (r["fin"] - r["debut"]) / 60.0 / max(1, r["cartouches"])
        mes[r["age"] if r["ere"] > 0 else 0] = {"momentanee": mm["momentanee"], "crete": mm["crete"], "cadence": cad,
                                                "n": r["cartouches"]}
    if 0 not in mes:
        print("[FO-TIRS-COUCHES] rafale vanilla absente : rafales non comparees")
    else:
        v = mes[0]
        raf_v = rafales.mesures(TS.rafale(None, a.mod, n_tirs=v["n"], cadence=v["cadence"]))["momentanee"]
        prev, croit = None, True
        for age in sorted(k for k in mes if k > 0):
            mm = mes[age]
            d = mm["momentanee"] - v["momentanee"]
            g = dict(ages[age]) if age in ages else None
            if g is None:
                g = {"s0": s0_ere.get(1), "vol_s0": ages[1]["vol_s0"], "couches": []}
            p_agg = rafales.mesures(TS.rafale(g, a.mod, n_tirs=mm["n"], cadence=mm["cadence"]))["momentanee"] - raf_v
            libre = dict(g)
            libre["couches"] = [dict(c, max=10 ** 6) for c in g["couches"]]
            p_lib = rafales.mesures(TS.rafale(libre, a.mod, n_tirs=mm["n"], cadence=mm["cadence"]))["momentanee"] - raf_v
            proche = ("H_agg" if abs(d - p_agg) < abs(d - p_lib) else "H_libre") if abs(p_agg - p_lib) > 0.5 else "indistinct"
            if prev is not None and d <= prev:
                croit = False
            prev = d
            res.setdefault(age, {}).update({"rafale_mesuree": d, "prevu_agg": p_agg, "prevu_libre": p_lib,
                                             "plus_proche": proche, "cadence_s": mm["cadence"]})
            print("[FO-TIRS-COUCHES] rafale age %2d (%d cartouches, %.0f ms entre deux tirs) : %+.2f dB sur la vanilla "
                  "(prevu H_agg %+.2f, H_libre %+.2f : %s) ; crete %.1f dBFS" % (
                      age, mm["n"], 1000 * mm["cadence"], d, p_agg, p_lib, proche, mm["crete"]))
        print("[FO-TIRS-COUCHES] rafale croissante avec l'age : %s" % ("OUI" if croit else "NON"))
        ok_v = ok_v and croit
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({str(k): v for k, v in res.items()}, f, indent=1)
    print("[FO-TIRS-COUCHES] BILAN : %s" % ("OK" if ok_v else "ECHEC"))
    return 0 if ok_v else 1


if __name__ == "__main__":
    sys.exit(main())
