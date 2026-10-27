"""Lot A3 (24/10), décision D-7 : gain de temps de l'ombre à 32 échantillons, mesuré DOS À DOS par le vrai chemin de
production (rendre.py), sur des têtes entières. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/d7_temps.py --dest DIR [--noms e02-tete-d04,e09-tete-d04,e15-tete-d04]
        [--ordre ABBA]

1. Le script tient les DEUX places du verrou de rendu (interdit n° 6) : une garde (ce script en mode --garde, lancée par
   with_render_lock.py) prend une place ; chaque rendu de rendre.py prend l'autre. Aucun autre rendu des lots ne tourne
   pendant la mesure.
2. Séries dans l'ordre --ordre (A = tout à 128 ; B = --samples-passes shadow=32), une session Blender par série, les
   mêmes têtes : temps d'horloge de la série (temps.json de rendre.py, démarrage de Blender et construction compris) et
   secondes par tête (spec.json : « seconds » = construction + rendu dans Blender). Le post-traitement (hors Blender) est
   chronométré à part.
3. Charge surveillée toutes les 2 s (psutil) : autres blender.exe, factorio.exe, verrou fo-autotest.lock, part du
   processeur prise par les autres processus.
4. Contrôle : les séries A entre elles et B entre elles donnent les mêmes PNG (sha256 des spec.json) ; les couches main
   et glow de B égalent celles de A (D-7 ne change que l'ombre).
Sortie : DIR/d7-temps.txt, DIR/d7-temps.json, DIR/charge.jsonl, DIR/<série>/ (sprites).
"""
import argparse
import json
import os
import shutil
import statistics as st
import subprocess
import sys
import threading
import time

import psutil

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
LOCK = os.path.join(RENDER, "with_render_lock.py")
LOCK_DIR = os.environ.get("FO_RENDER_LOCK_DIR", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91")


def garde(stop):
    t0 = time.time()
    while not os.path.exists(stop) and time.time() - t0 < 6 * 3600:
        time.sleep(1)
    return 0


def places_tenues(marque):
    n = 0
    for k in (1, 2):
        try:
            with open(os.path.join(LOCK_DIR, "fo-render.lock.%d" % k, "owner.txt"), encoding="utf-8") as f:
                if marque in f.read():
                    n += 1
        except OSError:
            pass
    return n


class Charge(threading.Thread):
    def __init__(self, path):
        super().__init__(daemon=True)
        self.path, self.stop, self.marque = path, False, None

    def run(self):
        moi = os.getpid()
        with open(self.path, "a", encoding="utf-8") as f:
            while not self.stop:
                bl, fa, autres = 0, 0, 0.0
                for p in psutil.process_iter(["name", "pid", "ppid"]):
                    try:
                        nm = (p.info["name"] or "").lower()
                        if nm == "blender.exe":
                            bl += 1
                        elif nm == "factorio.exe":
                            fa += 1
                    except psutil.Error:
                        pass
                tot = psutil.cpu_percent(interval=1.0)
                f.write(json.dumps({"t": time.time(), "serie": self.marque, "blender": bl, "factorio": fa,
                                    "cpu_total": tot, "fo_autotest_lock": os.path.isdir(
                                        os.path.join(LOCK_DIR, "fo-autotest.lock"))}) + "\n")
                f.flush()
                time.sleep(1.0)


def serie(nom, mode, noms, dest, ch):
    out = os.path.join(dest, nom)
    cache = os.path.join(dest, "cache_" + nom)
    for d in (out, cache):
        shutil.rmtree(d, ignore_errors=True)
    cmd = [sys.executable, os.path.join(HERE, "rendre.py"), "--out", out, "--cache", cache, "--only", ",".join(noms),
           "--samples", "128", "--per", str(len(noms)), "--sessions", "1"]
    if mode == "B":
        cmd += ["--samples-passes", "shadow=32"]
    ch.marque = nom
    t0 = time.time()
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=dict(os.environ, PYTHONUTF8="1"))
    dt = time.time() - t0
    txt = p.stdout.decode("utf-8", "replace")
    open(os.path.join(dest, nom + ".log"), "w", encoding="utf-8").write(txt)
    tj = json.load(open(os.path.join(cache, "temps.json"), encoding="utf-8"))[-1]
    tetes = {}
    for n in noms:
        s = json.load(open(os.path.join(out, n, "spec.json"), encoding="utf-8"))
        tetes[n] = {"seconds": s["seconds"], "seconds_render": s.get("seconds_render"),
                    "sha": {k: v["sha256"] for k, v in s["layers"].items()},
                    "samples_passes": s.get("samples_passes")}
    return {"serie": nom, "mode": mode, "code": p.returncode, "horloge_s": round(dt, 1),
            "blender_session_s": tj["total_s"], "tetes": tetes, "debut": t0, "fin": t0 + dt}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest")
    ap.add_argument("--noms", default="e02-tete-d04,e09-tete-d04,e15-tete-d04")
    ap.add_argument("--ordre", default="ABBA")
    ap.add_argument("--garde", default="")
    a = ap.parse_args()
    if a.garde:
        return garde(a.garde)
    os.makedirs(a.dest, exist_ok=True)
    noms = [n for n in a.noms.split(",") if n]
    stop = os.path.join(a.dest, "STOP-GARDE")
    if os.path.exists(stop):
        os.remove(stop)
    marque = "d7_temps.py --garde"
    g = subprocess.Popen([sys.executable, LOCK, "--", sys.executable, os.path.abspath(__file__), "--garde", stop])
    t_att = time.time()
    while places_tenues(marque) < 1:
        if g.poll() is not None:
            print("garde terminée avant d'avoir une place")
            return 1
        time.sleep(2)
    print("[D7] garde en place après %.0f s" % (time.time() - t_att), flush=True)
    ch = Charge(os.path.join(a.dest, "charge.jsonl"))
    ch.start()
    res = []
    try:
        for i, m in enumerate(a.ordre):
            r = serie("%d%s" % (i + 1, m), m, noms, a.dest, ch)
            print("[D7] série %s (%s) : code %d, horloge %.1f s, session Blender %.1f s ; %s" % (
                r["serie"], m, r["code"], r["horloge_s"], r["blender_session_s"],
                ", ".join("%s %.1f s" % (n, t["seconds"]) for n, t in r["tetes"].items())), flush=True)
            res.append(r)
    finally:
        ch.stop = True
        open(stop, "w").close()
        g.wait(timeout=120)
    # charge pendant chaque série
    ech = [json.loads(x) for x in open(os.path.join(a.dest, "charge.jsonl"), encoding="utf-8")]
    L = ["D-7 : temps dos à dos (rendre.py, une session par série, les deux places du verrou tenues), têtes %s" % noms,
         "série  mode  horloge  session  " + "  ".join("%14s" % n for n in noms) + "   charge (blender max, factorio max, "
         "cpu total médian)"]
    for r in res:
        e = [x for x in ech if r["debut"] <= x["t"] <= r["fin"]]
        r["charge"] = {"blender_max": max((x["blender"] for x in e), default=0),
                       "factorio_max": max((x["factorio"] for x in e), default=0),
                       "cpu_median": st.median([x["cpu_total"] for x in e]) if e else None,
                       "fo_autotest_lock": any(x["fo_autotest_lock"] for x in e)}
        L.append("%-6s %-4s %7.1f  %7.1f  " % (r["serie"], r["mode"], r["horloge_s"], r["blender_session_s"]) +
                 "  ".join("%14.1f" % r["tetes"][n]["seconds"] for n in noms) +
                 "   %d, %d, %s%s" % (r["charge"]["blender_max"], r["charge"]["factorio_max"], r["charge"]["cpu_median"],
                                     ", verrou fo-autotest PRIS" if r["charge"]["fo_autotest_lock"] else ""))
    A = [r for r in res if r["mode"] == "A"]
    B = [r for r in res if r["mode"] == "B"]
    L.append("")
    for n in noms:
        ta = st.mean(r["tetes"][n]["seconds"] for r in A)
        tb = st.mean(r["tetes"][n]["seconds"] for r in B)
        L.append("%s : tout à 128 %.1f s ; ombre à 32 %.1f s ; gain %.1f %%" % (n, ta, tb, 100 * (1 - tb / ta)))
    sa = st.mean(sum(r["tetes"][n]["seconds"] for n in noms) for r in A)
    sb = st.mean(sum(r["tetes"][n]["seconds"] for n in noms) for r in B)
    ha = st.mean(r["blender_session_s"] for r in A)
    hb = st.mean(r["blender_session_s"] for r in B)
    L.append("TOTAL des têtes (Blender, construction + rendu) : %.1f -> %.1f s, gain %.1f %% ; session complète "
             "(démarrage de Blender, conversion .npy, post-traitement compris) : %.1f -> %.1f s, gain %.1f %%" % (
                 sa, sb, 100 * (1 - sb / sa), ha, hb, 100 * (1 - hb / ha)))
    # contrôles
    ok = True
    for grp, nm in ((A, "A"), (B, "B")):
        for n in noms:
            if len({json.dumps(r["tetes"][n]["sha"], sort_keys=True) for r in grp}) != 1:
                ok = False
                L.append("CONTROLE : série %s, %s : sha256 différents d'une répétition à l'autre" % (nm, n))
    for n in noms:
        for lay in ("main", "glow"):
            if A and B and A[0]["tetes"][n]["sha"].get(lay) != B[0]["tetes"][n]["sha"].get(lay):
                ok = False
                L.append("CONTROLE : %s %s : B différent de A" % (n, lay))
    L.append("CONTROLES : %s (répétitions identiques ; main et glow de B = A)" % ("OK" if ok else "ECHEC"))
    txt = "\n".join(L)
    print(txt)
    open(os.path.join(a.dest, "d7-temps.txt"), "w", encoding="utf-8").write(txt + "\n")
    json.dump(res, open(os.path.join(a.dest, "d7-temps.json"), "w", encoding="utf-8"), indent=1)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
