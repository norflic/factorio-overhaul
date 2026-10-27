"""Lot A1, correcteur (23/10) : E66, TEMPS gagné par l'ombre de la tête à 32 échantillons au lieu de 128. Python 3.9.

    py -3.9 tools/render/pieces/levels/gun_e/e66_temps.py --dest DOSSIER [--ages 2,9,15] [--poses N,E] [--reps 3]
        [--ref 2-12=DOSSIER --ref 13-15=DOSSIER] [--rose DOSSIER]

Pourquoi : la première mesure d'E66 comparait deux séries prises sous des charges différentes (rendu d'identité à 128
pendant un banc, rose à 32 avec d'autres lots qui rendaient) : rapports de temps 128/32 de 4,8 à 7,1, impossibles sans
échantillonnage adaptatif ni débruitage (fo_scene.setup_render). Ici, tout est mesuré DOS À DOS, dans UNE session
Blender, sous la même charge :
1. Le script tient les DEUX places du verrou de rendu (interdit n° 6) : une « garde » (ce script en mode --garde, lancé
   par with_render_lock.py) prend une place et attend ; Blender est lancé par with_render_lock.py et prend l'autre.
   Aucun autre rendu Blender des lots ne peut donc tourner pendant la mesure. La garde est rendue à la fin.
2. e66_temps_blender.py : chauffe, puis --reps répétitions en ordre alterné de shadow 32, shadow 128, main 128,
   glow 128 et shadow 1 (coût fixe), chacune rendue seule (c'est le rendu par passe de D-7, chronométré pour de vrai).
3. Surveillance de la charge toutes les 2 s (psutil) : processeur total, part de Blender, autres processus gourmands,
   factorio.exe (banc fo-autotest / fo-visual ou autre), autres blender.exe, verrou fo-autotest.lock. Chaque rendu
   reçoit la charge « des autres » pendant son intervalle ; un rendu chevauché par un banc ou un autre Blender est
   marqué.
4. Preuve que les rendus chronométrés sont les vrais : les passes d'ombre de la répétition 1 sont post-traitées comme
   rendre.post (fo_post.shadow_layer, trim_box, write_png) et leurs sha256 comparés à ceux des sprites validés
   (128 : --ref, poses tete-N et tete-E) et de la rose du lot A1 (32 : --rose, poses d00 et d16). Les répétitions
   suivantes doivent redonner les mêmes pixels (sha256 des pixels identique : rendu déterministe).
Sortie (--dest) : e66-temps.txt (tableau), e66-temps.json, charge.jsonl, blender.log.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import statistics as st
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, RENDER)
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
SCRIPT = os.path.join(HERE, "e66_temps_blender.py")
LOCK_DIR = os.environ.get("FO_RENDER_LOCK_DIR", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91")
POSE_DIR = {"N": "d00", "E": "d16"}


def garde(stop):
    """Mode --garde : tient une place du verrou (lancé par with_render_lock.py) jusqu'au fichier stop (6 h au plus)."""
    t0 = time.time()
    while not os.path.exists(stop) and time.time() - t0 < 6 * 3600:
        time.sleep(1)
    return 0


def places_tenues(marque):
    res = []
    for k in (1, 2):
        p = os.path.join(LOCK_DIR, "fo-render.lock.%d" % k, "owner.txt")
        try:
            with open(p, encoding="utf-8") as f:
                if marque in f.read():
                    res.append(k)
        except OSError:
            pass
    return res


class Charge(threading.Thread):
    def __init__(self, path, blender_pid_fn):
        super().__init__(daemon=True)
        import psutil
        self.ps = psutil
        self.path = path
        self.pid_fn = blender_pid_fn
        self.stop = threading.Event()
        self.samples = []
        self.ncpu = psutil.cpu_count()

    def run(self):
        ps = self.ps
        ps.cpu_percent(None)
        procs = {}
        with open(self.path, "w", encoding="utf-8") as f:
            while not self.stop.is_set():
                time.sleep(2)
                t = time.time()
                total = ps.cpu_percent(None)
                mine = self.pid_fn()
                cur = {}
                for p in ps.process_iter(["pid", "name"]):
                    cur[p.info["pid"]] = p
                per = []
                for pid, p in cur.items():
                    if pid == 0:
                        continue
                    q = procs.get(pid) or p
                    try:
                        c = q.cpu_percent(None) / self.ncpu
                    except (ps.NoSuchProcess, ps.AccessDenied):
                        continue
                    procs[pid] = q
                    per.append((c, pid, p.info["name"]))
                procs = {pid: procs[pid] for pid in cur if pid in procs}
                blender = sum(c for c, pid, _ in per if pid in mine)
                autres = sorted([x for x in per if x[1] not in mine], reverse=True)
                fact, autres_blender = [], []
                for c, pid, name in per:
                    n = (name or "").lower()
                    if n == "factorio.exe":
                        try:
                            cl = " ".join(cur[pid].cmdline())
                        except (ps.NoSuchProcess, ps.AccessDenied):
                            cl = ""
                        kind = "fo-autotest" if "fo-autotest" in cl else ("fo-visual" if "fo-visual" in cl else "autre")
                        fact.append({"pid": pid, "kind": kind, "cpu": round(c, 1)})
                    elif n == "blender.exe" and pid not in mine:
                        autres_blender.append({"pid": pid, "cpu": round(c, 1)})
                s = {"t": round(t, 2), "total": total, "blender": round(blender, 1),
                     "autres": round(max(0.0, total - blender), 1),
                     "top": [[name, round(c, 1)] for c, _, name in autres[:5]],
                     "factorio": fact, "autres_blender": autres_blender,
                     "fo_autotest_lock": os.path.isdir(os.path.join(LOCK_DIR, "fo-autotest.lock"))}
                self.samples.append(s)
                f.write(json.dumps(s, ensure_ascii=False) + "\n")
                f.flush()


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def sources(specs):
    res = {}
    for s in specs:
        plage, d = s.split("=", 1)
        a, b = plage.split("-") if "-" in plage else (plage, plage)
        for e in range(int(a), int(b) + 1):
            res[e] = d
    return res


def identite(dest, name, age, pose, refs, rose):
    """Ombres de la répétition 1, post-traitées comme rendre.post, contre les sprites de référence (sha256 hr)."""
    import numpy as np
    import fo_post as P
    d = os.path.join(dest, "rendus", name)
    cadre = json.load(open(os.path.join(d, "cadre.json"), encoding="utf-8"))
    origin = tuple(cadre["origin_px"])
    res = {}
    for s, ref_dir, ref_name in ((128, refs.get(age), name),
                                 (32, rose, "e%02d-tete-%s" % (age, POSE_DIR[pose]))):
        npy = os.path.join(d, "shadow-%d.npy" % s)
        if not os.path.exists(npy) or not ref_dir:
            res[s] = {"ok": None, "raison": "absent"}
            continue
        img = P.shadow_layer(np.load(npy).astype(np.float64))
        x0, y0, x1, y1 = P.trim_box(img, origin)
        h = P.write_png(img[y0:y1, x0:x1], os.path.join(d, "hr-shadow-%d.png" % s))
        spec = json.load(open(os.path.join(ref_dir, ref_name, "spec.json"), encoding="utf-8"))
        attendu = spec["layers"]["shadow"]["sha256"]
        res[s] = {"ok": h == attendu, "sha256": h, "attendu": attendu, "ref": os.path.join(ref_dir, ref_name)}
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--garde", default="")
    ap.add_argument("--dest", default="")
    ap.add_argument("--ages", default="2,9,15")
    ap.add_argument("--poses", default="N,E")
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--ref", action="append", default=[])
    ap.add_argument("--rose", default="")
    a = ap.parse_args()
    if a.garde:
        return garde(a.garde)
    if not a.dest:
        raise SystemExit("--dest requis")
    os.makedirs(a.dest, exist_ok=True)
    ages = [int(x) for x in a.ages.split(",") if x]
    poses = [x for x in a.poses.split(",") if x]
    names = ["e%02d-tete-%s" % (e, p) for e in ages for p in poses]
    marque = "e66-garde-%d" % os.getpid()
    stop = os.path.join(a.dest, "garde.stop")
    if os.path.exists(stop):
        os.remove(stop)
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    g = subprocess.Popen([sys.executable, LOCK, "--", sys.executable, os.path.abspath(__file__), "--garde", stop,
                          "--dest", marque], env=env)
    t_att = time.time()
    while not places_tenues(marque):
        if g.poll() is not None:
            raise SystemExit("la garde s'est arrêtée (code %s)" % g.returncode)
        time.sleep(2)
    print("[E66] garde en place (%.0f s d'attente) ; lancement de Blender par le verrou" % (time.time() - t_att),
          flush=True)
    cmd = [sys.executable, LOCK, "--", BLENDER, "-b", "--factory-startup", "-noaudio", "--python-exit-code", "1",
           "-P", SCRIPT, "--", "--names", ",".join(names), "--out", os.path.join(a.dest, "rendus"),
           "--reps", str(a.reps)]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    import psutil
    lanceur = psutil.Process(p.pid)

    def pids_blender():
        try:
            return {c.pid for c in lanceur.children(recursive=True) if (c.name() or "").lower() == "blender.exe"}
        except psutil.Error:
            return set()

    charge = Charge(os.path.join(a.dest, "charge.jsonl"), pids_blender)
    charge.start()
    rendus, log = [], []
    t_debut = None
    try:
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace").rstrip()
            log.append(line)
            now = time.time()
            if "[E66-" in line or "Error" in line or "Traceback" in line or "[fo-render]" in line:
                print(line, flush=True)
            if t_debut is None and ("Blender" in line or "[E66-" in line):
                t_debut = now
            m = re.match(r"\[E66-T\] (\S+) (\d+) (\S+) (\d+) ([\d.]+) (\S+)", line)
            if m:
                dt = float(m.group(5))
                rendus.append({"name": m.group(1), "rep": int(m.group(2)), "layer": m.group(3),
                               "samples": int(m.group(4)), "s": dt, "png_sha": m.group(6),
                               "t0": now - dt, "t1": now})
        rc = p.wait()
    finally:
        open(stop, "w").close()
        try:
            g.wait(timeout=60)
        except subprocess.TimeoutExpired:
            g.terminate()
        charge.stop.set()
        charge.join(10)
        with open(os.path.join(a.dest, "blender.log"), "w", encoding="utf-8") as f:
            f.write("\n".join(log) + "\n")
    # charge pendant chaque rendu
    for r in rendus:
        ech = [s for s in charge.samples if r["t0"] - 1 <= s["t"] <= r["t1"] + 1]
        r["n_ech"] = len(ech)
        r["autres_moy"] = round(st.mean([s["autres"] for s in ech]), 1) if ech else None
        r["blender_moy"] = round(st.mean([s["blender"] for s in ech]), 1) if ech else None
        r["banc"] = any(f["kind"] != "autre" for s in ech for f in s["factorio"]) or any(
            s["fo_autotest_lock"] for s in ech)
        r["factorio_autre"] = any(f["kind"] == "autre" for s in ech for f in s["factorio"])
        r["autre_blender"] = any(s["autres_blender"] for s in ech)
    refs = sources(a.ref)
    ident = {}
    for e in ages:
        for po in poses:
            n = "e%02d-tete-%s" % (e, po)
            ident[n] = identite(a.dest, n, e, po, refs, a.rose)
    bilan(a, names, rendus, ident, rc, charge.samples)
    for n in names:  # purge des .npy (disque H:)
        d = os.path.join(a.dest, "rendus", n)
        for f in os.listdir(d) if os.path.isdir(d) else []:
            if f.endswith(".npy"):
                os.remove(os.path.join(d, f))
        for sub in os.listdir(d) if os.path.isdir(d) else []:
            if os.path.isdir(os.path.join(d, sub)):
                shutil.rmtree(os.path.join(d, sub), ignore_errors=True)
    return rc


def bilan(a, names, rendus, ident, rc, samples):
    L = []
    out = {"date": time.strftime("%Y-%m-%d %H:%M:%S"), "code_blender": rc, "reps": a.reps, "rendus": rendus,
           "identite": ident, "poses": {}}

    def t(n, layer, s, rep=None):
        v = [r["s"] for r in rendus if r["name"] == n and r["layer"] == layer and r["samples"] == s
             and (rep is None or r["rep"] == rep)]
        return v

    L.append("E66, temps dos à dos (une session Blender, deux places du verrou tenues, ordre alterné), %s"
             % out["date"])
    L.append("Secondes par rendu d'UNE passe (médiane [min-max] sur %d répétitions)." % a.reps)
    L.append("pose          ombre 1   ombre 32            ombre 128             128/32 par rep       "
             "main 128  lueur 128 | tête 128 -> tête ombre 32 : gain par rep (médiane)")
    tot128 = {rep: 0.0 for rep in range(1, a.reps + 1)}
    tot32 = {rep: 0.0 for rep in range(1, a.reps + 1)}
    for n in names:
        s1, s32, s128 = t(n, "shadow", 1), t(n, "shadow", 32), t(n, "shadow", 128)
        mn, gl = t(n, "main", 128), t(n, "glow", 128)
        ratios, gains = [], []
        for rep in range(1, a.reps + 1):
            a32, a128 = t(n, "shadow", 32, rep), t(n, "shadow", 128, rep)
            m_, g_ = t(n, "main", 128, rep), t(n, "glow", 128, rep)
            if a32 and a128:
                ratios.append(a128[0] / a32[0])
            if a32 and a128 and m_:
                T128 = m_[0] + a128[0] + (g_[0] if g_ else 0.0)
                T32 = m_[0] + a32[0] + (g_[0] if g_ else 0.0)
                gains.append(1 - T32 / T128)
                tot128[rep] += T128
                tot32[rep] += T32

        def f(v):
            return "%6.1f [%5.1f-%5.1f]" % (st.median(v), min(v), max(v)) if v else "      -"
        L.append("%-12s %7.2f  %s  %s  %-20s %8.1f  %8.1f | %s (%.1f %%)" % (
            n, st.median(s1) if s1 else float("nan"), f(s32), f(s128), " ".join("%.2f" % x for x in ratios),
            st.median(mn) if mn else float("nan"), st.median(gl) if gl else 0.0,
            " ".join("%.1f %%" % (100 * x) for x in gains), 100 * st.median(gains) if gains else float("nan")))
        # coût fixe et coût par échantillon de la passe d'ombre (moindres carrés sur 1, 32, 128)
        xs = [1] * len(s1) + [32] * len(s32) + [128] * len(s128)
        ys = s1 + s32 + s128
        if len(set(xs)) >= 2:
            mx, my = st.mean(xs), st.mean(ys)
            b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs)
            a0 = my - b * mx
        else:
            a0 = b = float("nan")
        out["poses"][n] = {"ombre1": s1, "ombre32": s32, "ombre128": s128, "main128": mn, "lueur128": gl,
                           "rapports_128_32": ratios, "gains": gains, "fixe_s": a0, "par_echantillon_s": b,
                           "borne_rapport": (a0 + 128 * b) / (a0 + 32 * b) if b == b else None}
    L.append("")
    L.append("Passe d'ombre, modèle t = fixe + k × échantillons (moindres carrés sur 1, 32 et 128) :")
    for n in names:
        q = out["poses"][n]
        L.append("  %-12s fixe %.2f s, %.4f s par échantillon -> rapport 128/32 attendu %.2f (mesuré : %s)" % (
            n, q["fixe_s"], q["par_echantillon_s"], q["borne_rapport"] or float("nan"),
            " ".join("%.2f" % x for x in q["rapports_128_32"])))
    L.append("")
    gains_tot = [1 - tot32[r] / tot128[r] for r in tot128 if tot128[r] > 0]
    L.append("TOTAL des %d poses, tête entière (main 128 + lueur 128 + ombre) : " % len(names) + " ; ".join(
        "rep %d : %.0f s -> %.0f s, gain %.1f %%" % (r, tot128[r], tot32[r], 100 * (1 - tot32[r] / tot128[r]))
        for r in tot128 if tot128[r] > 0))
    if gains_tot:
        L.append("GAIN tête entière, %d pose(s) : médiane %.1f %%, de %.1f à %.1f %%" % (
            len(names), 100 * st.median(gains_tot), 100 * min(gains_tot), 100 * max(gains_tot)))
    out["totaux"] = {"tete128": tot128, "tete32": tot32, "gains": gains_tot}
    L.append("")
    L.append("Charge pendant les rendus (processeur total moins Blender, en %% de la machine ; %d échantillons de "
             "2 s) :" % len(samples))
    au = [r["autres_moy"] for r in rendus if r["autres_moy"] is not None]
    if au:
        L.append("  autres processus : médiane %.1f %%, max %.1f %% (par rendu)" % (st.median(au), max(au)))
    L.append("  rendus chevauchés par un banc fo-autotest/fo-visual ou le verrou fo-autotest.lock : %d sur %d" % (
        sum(r["banc"] for r in rendus), len(rendus)))
    L.append("  rendus chevauchés par un factorio.exe hors banc (partie du DC ?) : %d ; par un autre blender.exe : %d"
             % (sum(r["factorio_autre"] for r in rendus), sum(r["autre_blender"] for r in rendus)))
    tops = {}
    pendant = [s for s in samples if any(r["t0"] - 1 <= s["t"] <= r["t1"] + 1 for r in rendus)]
    for s in pendant:
        for name, c in s["top"]:
            if c >= 2.0:
                tops[name] = max(tops.get(name, 0), c)
    L.append("  processus autres que ce Blender à 2 %% ou plus de la machine pendant un rendu : %s" % (
        ", ".join("%s %.0f %%" % kv for kv in sorted(tops.items(), key=lambda kv: -kv[1])) or "aucun"))
    L.append("")
    L.append("Identité (passes d'ombre de la répétition 1, post-traitées comme rendre.post, sha256 hr) :")
    n_ok = n_tot = 0
    for n in names:
        for s in (128, 32):
            r = ident[n][s]
            n_tot += 1
            n_ok += bool(r.get("ok"))
            L.append("  %-12s ombre %3d : %s%s" % (n, s, {True: "IDENTIQUE", False: "DIFFERENT", None: "non vérifié"}[
                r.get("ok")], "" if r.get("ok") else "  (%s)" % r.get("raison", r.get("ref"))))
    det = {}
    for r in rendus:
        det.setdefault((r["name"], r["layer"], r["samples"]), set()).add(r["png_sha"])
    n_det = sum(1 for v in det.values() if len(v) == 1)
    L.append("IDENTITE : %d sur %d ; pixels identiques d'une répétition à l'autre : %d rendus sur %d" % (
        n_ok, n_tot, n_det, len(det)))
    L.append("Code de sortie de Blender : %s" % rc)
    txt = "\n".join(L) + "\n"
    print(txt)
    with open(os.path.join(a.dest, "e66-temps.txt"), "w", encoding="utf-8") as f:
        f.write(txt)
    with open(os.path.join(a.dest, "e66-temps.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1, ensure_ascii=False, default=list)


if __name__ == "__main__":
    sys.exit(main())
