r"""Le tir de la mitrailleuse est-il JOUÉ en jeu, avec le son de son ère ? (lot S0-suite, scénario greffé s0-tir)

    py -3.9 tools/sound/tirs_joues.py <audio-disk.raw> <factorio.log de la session avec images> [--mod RACINE]
                                      [--data <racine>\data] [--seuil 0.5] [--tol-ms 60] [--wav sortie.wav]

Entrées :
  - audio-disk.raw : sortie mixée du jeu écrite par le pilote SDL « disk » (session FO_AUDIO=1, tools/autotest/README.md
    §1.3 ; rien n'atteint la sortie du PC) ; format lu dans la ligne « [Audio] … Depth … Channels … Frequency » du
    journal ;
  - le journal de la MÊME session (fo-shots\factorio.log) : lignes « [FO-S0-TIR] TIR<TAB>site=..<TAB>niveau=..<TAB>
    ere=..<TAB>tick=.. » écrites par le scénario au tick de chaque tir (ère 0 = mitrailleuse vanilla).
Gabarits : les 20 tirs du mod (sound/levels/gun/tir-ere<N>-<i>.ogg) et les 4 tirs vanilla
(<data>\base\sound\fight\gun-turret-gunshot-0<i>.ogg), décodés par PyAV (FFmpeg ; Blender n'est PAS utilisé), en mono.

Méthode :
  1. filtre adapté : corrélation normalisée (par FFT) de la sortie mono avec chaque gabarit ;
  2. détections : maxima de max(gabarits) au-dessus du seuil, séparés de 0,3 s au moins ; chaque détection reçoit le
     gabarit le plus corrélé (ère et variation) et l'écart au meilleur gabarit d'une AUTRE ère ;
  3. instants : droite temps = a + b × tick ajustée sur les tirs (b libre : l'horloge du pilote disk n'est pas celle du
     jeu) ; recherche de (a, b) qui apparie le plus de tirs à une détection à ± tol, puis moindres carrés et
     réappariement ; résidu de chaque tir en ms ;
  4. verdict, tir par tir : reconnu (détection appariée), ère juste (gabarit de l'ère attendue), instant juste (résidu
     dans la tolérance) ; détections non appariées comptées et listées.
Code de sortie : 0 si chaque tir est reconnu, de la bonne ère, au bon instant, et si aucune détection de gabarit ne reste
sans tir ; 1 sinon ; 2 entrée illisible.
"""
import argparse
import json
import os
import re
import sys

import numpy as np
from scipy.signal import fftconvolve

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
GAME = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
AUDIO_LINE = re.compile(r"^\s*([\d.]+)\s.*\[Audio\][^\n]*?Depth:\s*(\d+)[^\n]*?Channels:\s*(\d+)[^\n]*?Frequency:\s*(\d+)",
                        re.M)
TIR_LINE = re.compile(r"^\s*([\d.]+)\s.*\[FO-S0-TIR\] TIR\t(.*)$", re.M)


def decode(path):
    """Fichier son -> (mono float64, fréquence) par PyAV."""
    import av
    c = av.open(path)
    s = c.streams.audio[0]
    rate = s.rate
    parts = []
    for fr in c.decode(s):
        a = fr.to_ndarray()
        if a.dtype.kind == "i":
            a = a.astype(np.float64) / float(np.iinfo(a.dtype).max)
        a = a.astype(np.float64)
        if not fr.format.is_planar:
            a = a.reshape(-1, len(fr.layout.channels)).T
        parts.append(a)
    c.close()
    x = np.concatenate(parts, axis=1)
    return x.mean(axis=0), rate


def templates(mod, data):
    out = []
    for i in range(1, 5):
        out.append(("vanilla-%d" % i, 0, i, os.path.join(data, "base", "sound", "fight", "gun-turret-gunshot-0%d.ogg" % i)))
    for e in range(1, 6):
        for i in range(1, 5):
            out.append(("ere%d-%d" % (e, i), e, i, os.path.join(mod, "sound", "levels", "gun", "tir-ere%d-%d.ogg" % (e, i))))
    return out


def ncc(x, r):
    """Corrélation normalisée de x avec le gabarit r à chaque décalage (fenêtre de la longueur de r)."""
    L = len(r)
    if len(x) < L:
        return np.zeros(0)
    c = fftconvolve(x, r[::-1], mode="valid")
    cs = np.concatenate([[0.0], np.cumsum(x * x)])
    win = cs[L:] - cs[:-L]
    win = win[:len(c)]
    rho = c / np.sqrt(np.maximum(win, 1e-20) * float(np.sum(r * r)))
    rho[win < 1e-12] = 0.0
    return rho


def peaks(d, fs, thr, gap_s):
    """Maxima de d au-dessus de thr, séparés de gap_s au moins (le plus haut gagne)."""
    idx = np.where(d > thr)[0]
    found = []
    gap = int(gap_s * fs)
    for j in idx:
        if found and j - found[-1] <= gap:
            if d[j] > d[found[-1]]:
                found[-1] = j
        else:
            found.append(j)
    # fusion de deux maxima trop proches après remplacement
    out = []
    for j in found:
        if out and j - out[-1] <= gap:
            if d[j] > d[out[-1]]:
                out[-1] = j
        else:
            out.append(j)
    return out


def fit_times(shots, dets, tol):
    """(a, b) de temps = a + b × tick qui apparie le plus de tirs à une détection à ± tol ; puis moindres carrés."""
    ticks = np.array([s["tick"] for s in shots], dtype=float)
    times = np.array([d["t"] for d in dets], dtype=float)
    if len(ticks) == 0 or len(times) == 0:
        return None
    best = (-1, 0.0, 0.0)
    for ratio in np.arange(0.90, 1.1001, 0.001):
        b = ratio / 60.0
        for t0 in times:
            for k in ticks:
                a = t0 - b * k
                pred = a + b * ticks
                err = np.min(np.abs(pred[:, None] - times[None, :]), axis=1)
                n = int(np.sum(err <= tol))
                if n > best[0]:
                    best = (n, a, b)
    _, a, b = best
    for _ in range(4):
        pred = a + b * ticks
        j = np.argmin(np.abs(pred[:, None] - times[None, :]), axis=1)
        ok = np.abs(pred - times[j]) <= tol
        if ok.sum() < 2:
            break
        A = np.column_stack([np.ones(ok.sum()), ticks[ok]])
        sol, *_ = np.linalg.lstsq(A, times[j][ok], rcond=None)
        a, b = float(sol[0]), float(sol[1])
    return a, b


GAIN_S = 0.9  # s : gain mesuré avant le tir suivant (60 ticks = 0,98 s de sortie)
SEUIL_COUCHES = 0.25  # corrélation minimale au S0 d'un tir de site à couches TIRS (le reste du mélange la fait baisser)

LUA = os.path.join("C:" + os.sep, "Users", "evan2", "bin", "lua5.2.exe")
DUMP_COUCHES = (
    'package.path = "./?.lua;" .. package.path '
    'local ok, T = pcall(require, "shared.tirs.ages") '
    'if ok then for e = 1, 15 do local A = T.ages[e] '
    'if A and A.son and A.son.couches and #A.son.couches > 0 then io.write(e, " ") end end end')


def ages_a_couches(mod):
    """Âges dont le tir porte des couches AJOUTÉES par le lot TIRS (shared/tirs/ages.lua) ; vide sans le lot."""
    import subprocess
    try:
        r = subprocess.run([LUA, "-e", DUMP_COUCHES], cwd=mod, capture_output=True, text=True)
    except OSError:
        return set()
    return {int(v) for v in r.stdout.split()}


def volumes_attendus(mod):
    """Volume du prototype par ère lu dans sound/levels/gun/sons.lua (`volumes`, sinon `volume`) ; ère 0 (vanilla) : 0,4."""
    txt = open(os.path.join(mod, "sound", "levels", "gun", "sons.lua"), encoding="utf-8").read()
    m = re.search(r"^\s*volume\s*=\s*([\d.]+)", txt, re.M)
    base = float(m.group(1)) if m else 0.4
    vols = {e: base for e in range(1, 6)}
    mv = re.search(r"volumes\s*=\s*\{([^}]*)\}", txt)
    if mv:
        for k, v in re.findall(r"\[(\d)\]\s*=\s*([\d.]+)", mv.group(1)):
            vols[int(k)] = float(v)
    vols[0] = 0.4
    return vols


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw")
    ap.add_argument("log")
    ap.add_argument("--mod", default=REPO)
    ap.add_argument("--data", default=os.path.join(GAME, "data"))
    ap.add_argument("--seuil", type=float, default=0.5)
    ap.add_argument("--tol-ms", type=float, default=60.0)
    ap.add_argument("--wav", default=None)
    ap.add_argument("--tol-db", type=float, default=0.2)
    ap.add_argument("--json", default=None, help="écrit les gains relatifs par ère (pour --avant)")
    ap.add_argument("--avant", default=None, help="JSON d'une session précédente : contrôle différentiel des volumes")
    a = ap.parse_args()

    try:
        log = open(a.log, encoding="utf-8", errors="replace").read()
    except OSError as exc:
        print("[FO-TIRS-JOUES] ECHEC journal illisible : %s" % exc)
        return 2
    m = AUDIO_LINE.search(log)
    if not m:
        print("[FO-TIRS-JOUES] ECHEC pas de ligne [Audio] dans le journal : session sans son ?")
        return 2
    t_open, depth, ch, fs = float(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))
    if depth != 16:
        print("[FO-TIRS-JOUES] ECHEC format %d bits non lu" % depth)
        return 2
    shots = []
    for mm in TIR_LINE.finditer(log):
        f = dict(kv.split("=", 1) for kv in mm.group(2).strip().split("\t") if "=" in kv)
        shots.append({"log_t": float(mm.group(1)), "site": int(f["site"]), "niveau": int(f["niveau"]),
                      "ere": int(f["ere"]), "tick": int(f["tick"]), "hors": f.get("hors_fenetre") == "1"})
    if not shots:
        print("[FO-TIRS-JOUES] ECHEC aucune ligne « [FO-S0-TIR] TIR » dans le journal")
        return 2
    raw = np.fromfile(a.raw, dtype="<i2").astype(np.float64) / 32768.0
    st = raw[:len(raw) // ch * ch].reshape(-1, ch)
    x = st.mean(axis=1)
    print("[FO-TIRS-JOUES] sortie : %s, %.2f s, %d voies, %d Hz, crete %.4f (%.1f dBFS) ; audio ouvert a %.3f s du journal"
          % (os.path.basename(a.raw), len(x) / fs, ch, fs, np.abs(st).max(), 20 * np.log10(max(np.abs(st).max(), 1e-12)),
             t_open))
    print("[FO-TIRS-JOUES] journal : %d tir(s) (%s)" % (len(shots), ", ".join(
        "site %d niveau %d ere %d : %d" % (k, n, e, sum(1 for s in shots if s["site"] == k))
        for k, n, e in sorted({(s["site"], s["niveau"], s["ere"]) for s in shots}))))

    tpl = []
    for name, era, var, path in templates(a.mod, a.data):
        y, rate = decode(path)
        if rate != fs:
            print("[FO-TIRS-JOUES] ECHEC %s : %d Hz (sortie %d Hz)" % (path, rate, fs))
            return 2
        tpl.append({"name": name, "era": era, "var": var, "rho": ncc(x, y), "len": len(y), "y": y})
    n = min(len(t["rho"]) for t in tpl)
    R = np.vstack([t["rho"][:n] for t in tpl])
    best = R.max(axis=0)
    arg = R.argmax(axis=0)
    eras = np.array([t["era"] for t in tpl])
    print("[FO-TIRS-JOUES] gabarits : %d (4 vanilla, 20 du mod), decodes par PyAV ; correlation max sur toute la sortie %.3f"
          % (len(tpl), best.max()))

    dets = []
    for j in peaks(best, fs, a.seuil, 0.3):
        k = int(arg[j])
        other = R[eras != tpl[k]["era"], j].max()
        oarg = int(np.argmax(np.where(eras != tpl[k]["era"], R[:, j], -9)))
        dets.append({"i": j, "t": j / float(fs), "tpl": tpl[k]["name"], "era": tpl[k]["era"], "var": tpl[k]["var"],
                     "rho": float(R[k, j]), "autre": float(other), "autre_tpl": tpl[oarg]["name"], "k": k})
    print("[FO-TIRS-JOUES] detections (correlation > %.2f, separees de 0,3 s) : %d" % (a.seuil, len(dets)))

    tol = a.tol_ms / 1000.0
    # lot TIRS (27/10) : aux âges à couches ajoutées, le tir n'est plus le S0 seul (le mélange fait baisser la corrélation
    # et monter le gain) : la droite des instants est ajustée sur les AUTRES sites ; ces tirs sont reconnus au S0 de leur
    # ère à SEUIL_COUCHES près de l'instant prévu ; leur ère est écartée du différentiel de volume
    # (tools/sound/tirs_couches.py les mesure). Âge d'un niveau n >= 2 : (n + 1) // 2 (prototypes/levels).
    couches = ages_a_couches(a.mod)
    for s in shots:
        s["couches"] = s["niveau"] >= 2 and (s["niveau"] + 1) // 2 in couches
    eres_couches = {s["ere"] for s in shots if s["couches"]}
    if couches:
        print("[FO-TIRS-JOUES] ages a couches TIRS : %s ; sites a couches : %s" % (
            ",".join(str(e) for e in sorted(couches)),
            ", ".join(sorted({"niveau %d" % s["niveau"] for s in shots if s["couches"]})) or "aucun"))
    fit = fit_times([s for s in shots if not s["couches"]] or shots, dets, tol)
    if fit is None:
        print("[FO-TIRS-JOUES] ECHEC aucune detection : aucun tir entendu")
        return 1
    fa, fb = fit
    times = np.array([d["t"] for d in dets])
    used = set()
    rows, ok_rec, ok_era, ok_t, res = [], 0, 0, 0, []
    for s in shots:
        pred = fa + fb * s["tick"]
        j = int(np.argmin(np.abs(times - pred)))
        r = times[j] - pred
        d = dets[j]
        rec = abs(r) <= tol and j not in used
        if not rec and s["couches"]:
            # tir à couches : meilleure corrélation au S0 de son ère près de l'instant prévu
            i0, i1 = max(0, int((pred - tol) * fs)), min(n, int((pred + tol) * fs) + 1)
            if i1 > i0:
                ks = [k for k, t_ in enumerate(tpl) if t_["era"] == s["ere"]]
                sub = R[ks, i0:i1]
                kk, jj = np.unravel_index(int(np.argmax(sub)), sub.shape)
                if sub[kk, jj] >= SEUIL_COUCHES:
                    k = ks[kk]
                    oth = R[eras != s["ere"], i0 + jj].max()
                    oarg = int(np.argmax(np.where(eras != s["ere"], R[:, i0 + jj], -9)))
                    dets.append({"i": i0 + jj, "t": (i0 + jj) / float(fs), "tpl": tpl[k]["name"], "era": s["ere"],
                                 "var": tpl[k]["var"], "rho": float(R[k, i0 + jj]), "autre": float(oth),
                                 "autre_tpl": tpl[oarg]["name"], "k": k, "couches": True})
                    j = len(dets) - 1
                    d = dets[j]
                    r = d["t"] - pred
                    rec = True
        if rec:
            used.add(j)
            ok_rec += 1
            res.append(r)
            era_ok = d["era"] == s["ere"]
            ok_era += era_ok
            ok_t += 1
        else:
            era_ok = False
        rows.append("  tir site %d niveau %2d ere %d tick %5d : attendu a %7.3f s, %s" % (
            s["site"], s["niveau"], s["ere"], s["tick"], pred,
            ("detection a %7.3f s (residu %+5.1f ms), gabarit %-10s rho %.3f, meilleure autre ere %-10s %.3f (marge %.3f) : %s"
             % (d["t"], 1000 * r, d["tpl"], d["rho"], d["autre_tpl"], d["autre"], d["rho"] - d["autre"],
                "ERE JUSTE" if era_ok else "ERE FAUSSE")) if rec else "AUCUNE detection a +/- %.0f ms : NON RECONNU" % a.tol_ms))
    extra = [d for k, d in enumerate(dets) if k not in used]
    print("[FO-TIRS-JOUES] droite temps = %.4f + %.7f x tick : %.4f s par 60 ticks (horloge du pilote disk / horloge du jeu)"
          % (fa, fb, 60 * fb))
    # cohérence avec l'horodatage du journal (secondes depuis le lancement) : temps de la sortie ~ journal - ouverture
    lt = np.array([s["log_t"] for s in shots])
    pt = fa + fb * np.array([s["tick"] for s in shots])
    off = pt - (lt - t_open)
    print("[FO-TIRS-JOUES] contre l'horodatage du journal : temps de la sortie - (temps du journal - ouverture de l'audio) "
          "= %+.3f s au premier tir, %+.3f s au dernier (latence plus derive de l'horloge disk)" % (off[0], off[-1]))
    for r in rows:
        print(r)
    res = np.array(res) if res else np.zeros(0)
    if len(res):
        print("[FO-TIRS-JOUES] residus : max |r| %.1f ms, ecart-type %.1f ms (%d tirs apparies)" % (
            1000 * np.abs(res).max(), 1000 * res.std(), len(res)))
    vars_seen = {}
    for k in sorted(used):
        d = dets[k]
        vars_seen.setdefault(d["era"], set()).add(d["var"])
    print("[FO-TIRS-JOUES] variations entendues par ere : %s" % " ; ".join(
        "ere %d : %s" % (e, ",".join(str(v) for v in sorted(vs))) for e, vs in sorted(vars_seen.items())))
    margins = [dets[k]["rho"] - dets[k]["autre"] for k in sorted(used)]
    if margins:
        print("[FO-TIRS-JOUES] rho des tirs apparies : min %.3f, median %.3f ; marge sur la meilleure autre ere : min %.3f"
              % (min(dets[k]["rho"] for k in used), float(np.median([dets[k]["rho"] for k in used])), min(margins)))
    print("[FO-TIRS-JOUES] detections sans tir : %d%s" % (len(extra), "" if not extra else " (" + ", ".join(
        "%.2f s %s %.3f" % (d["t"], d["tpl"], d["rho"]) for d in extra[:12]) + ")"))
    # bruit de fond : corrélation max HORS des tirs appariés (± 0,6 s)
    mask = np.ones(n, dtype=bool)
    for k in used:
        i0 = dets[k]["i"]
        mask[max(0, i0 - int(0.6 * fs)):i0 + int(0.6 * fs)] = False
    if mask.any():
        print("[FO-TIRS-JOUES] correlation max hors des tirs apparies (+/- 0,6 s) : %.3f" % best[mask].max())
    if a.wav:
        import wave
        with wave.open(a.wav, "wb") as w:
            w.setnchannels(ch)
            w.setsampwidth(2)
            w.setframerate(fs)
            w.writeframes((st * 32768.0).round().clip(-32768, 32767).astype("<i2").tobytes())
        print("[FO-TIRS-JOUES] WAV ecrit : %s" % a.wav)
    # volume EN JEU : gain de chaque tir apparié (moindres carrés sur les GAIN_S premières secondes, avant le tir
    # suivant) rapporté au fichier ; médiane par ère, rapportée au site vanilla. Ce rapport porte aussi un biais PAR SITE
    # (même distance d'écoute au centre de la tourelle, mais 24/10 : de −0,6 à +0,2 dB à volumes égaux, tirs à ±0,05 dB
    # près ; cause non établie, hypothèse : le son part de la bouche, plus loin du centre sur les grands âges) : il n'est
    # donc PAS comparé à l'attendu tel quel. Contrôle : DIFFÉRENTIEL entre deux sessions sur les mêmes sites (--avant :
    # JSON écrit par --json d'une session précédente) : le décalage mesuré de chaque ère doit être celui des volumes du
    # prototype (sons.lua) à --tol-db près.
    vols = volumes_attendus(a.mod)
    gains = {}
    for k in sorted(used):
        d = dets[k]
        y = tpl[d["k"]]["y"]
        m = min(int(GAIN_S * fs), len(y), n - d["i"])
        seg, ref = x[d["i"]:d["i"] + m], y[:m]
        gains.setdefault(d["era"], []).append(float(np.dot(seg, ref) / np.dot(ref, ref)))
    rel = {}
    vol_ok = None
    if 0 in gains:
        g0 = float(np.median(gains[0]))
        parts = []
        for e in sorted(gains):
            if e == 0:
                continue
            rel[e] = 20 * np.log10(float(np.median(gains[e])) / g0)
            gd = 20 * np.log10(np.array(gains[e]) / g0)
            parts.append("ere %d %+.2f dB (tirs de %+.2f a %+.2f)%s" % (e, rel[e], gd.min(), gd.max(),
                         " [site a couches TIRS]" if e in eres_couches else ""))
        print("[FO-TIRS-JOUES] volume en jeu, gain median du tir rapporte au site vanilla (biais de site compris) ; volumes "
              "du prototype lus dans sons.lua : %s : %s" % (", ".join("%d=%.4f" % (e, vols[e]) for e in sorted(vols)),
                                                          " ; ".join(parts)))
        print("[FO-TIRS-JOUES] gain absolu du site vanilla (sortie / fichier) : %.4f (%.1f dB ; volume 0,4 = %.1f dB, le "
              "reste : distance d'ecoute et mixage du jeu)" % (g0, 20 * np.log10(g0), 20 * np.log10(0.4)))
    else:
        print("[FO-TIRS-JOUES] volume en jeu : aucun tir vanilla apparie, rapport non mesure")
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"rel_db": {str(e): v for e, v in rel.items()}, "volumes": {str(e): v for e, v in vols.items()}},
                      f, indent=1)
    if a.avant:
        av_ = json.load(open(a.avant, encoding="utf-8"))
        vol_ok = bool(rel)
        parts = []
        for e in sorted(rel):
            if e in eres_couches:
                parts.append("ere %d : site a couches TIRS, non controle (tools/sound/tirs_couches.py)" % e)
                continue
            if str(e) not in av_["rel_db"]:
                vol_ok = False
                continue
            dm = rel[e] - av_["rel_db"][str(e)]
            da = 20 * np.log10(vols[e] / av_["volumes"][str(e)])
            ok = abs(dm - da) <= a.tol_db
            vol_ok = vol_ok and ok
            parts.append("ere %d mesure %+.2f dB, attendu %+.2f dB : %s" % (e, dm, da, "OK" if ok else "ECART"))
        print("[FO-TIRS-JOUES] volume en jeu, DIFFERENTIEL contre %s (tolerance %.2f dB) : %s" % (
            os.path.basename(a.avant), a.tol_db, " ; ".join(parts)))
    good = ok_rec == len(shots) and ok_era == len(shots) and not extra and vol_ok is not False
    print("[FO-TIRS-JOUES] BILAN : %d tir(s) au journal ; reconnus %d, ere juste %d, instant juste (+/- %.0f ms) %d ; "
          "detections sans tir %d ; volumes (differentiel) %s : %s" % (
              len(shots), ok_rec, ok_era, a.tol_ms, ok_t, len(extra),
              {None: "non controles (sans --avant)", True: "justes", False: "FAUX"}[vol_ok], "OK" if good else "ECHEC"))
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
