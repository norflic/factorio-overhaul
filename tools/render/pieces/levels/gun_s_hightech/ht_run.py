"""Chaîne de rendu de l'explorateur « haute technologie » : UNE session Blender par appel, sous le verrou de rendu
partagé (tools/render/with_render_lock.py, appelé tel quel, priorité inférieure à la normale, 2 places au plus),
puis post-traitement (ht_post.py). Mesure et consigne les temps (attente du verrou, session, passes).

    python ht_run.py --names n29-socle,n29-tete-E [--samples 128] [--tag essai]

Le verrou n'a pas de file d'attente (README du pipeline) : on essaie « --wait 0 » toutes les 2 s, la même règle
que les lots V3 (qui essaient toutes les 0,5 à 1 s).
"""
import argparse
import json
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import ht_post  # noqa: E402

BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
LOCK = os.path.join(RENDER, "with_render_lock.py")
SCRIPT = os.path.join(HERE, "ht_blender.py")
MARK = "aucune place libre"


def locked(cmd, log):
    t0, n = time.time(), 0
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    while True:
        n += 1
        p = subprocess.Popen([sys.executable, LOCK, "--wait", "0", "--"] + cmd, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, env=env)
        busy, t_start, lines = False, None, []
        for raw in p.stdout:
            line = raw.decode("utf-8", "replace")
            if MARK in line:
                busy = True
                continue
            if t_start is None:
                t_start = time.time()
            lines.append(line)
            if line.startswith("[FO-RENDER]") or "Error" in line or "Traceback" in line:
                print(line.rstrip(), flush=True)
        rc = p.wait()
        if rc == 2 and busy:
            if n % 150 == 1:
                print("[ht_run] pas de place (%d essais, %.0f s)" % (n, time.time() - t0), flush=True)
            time.sleep(2.0)
            continue
        with open(log, "a", encoding="utf-8") as f:
            f.write(" ".join(cmd) + "\n" + "".join(lines[-400:]) + "\n")
        return rc, n, time.time() - t0, lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--samples", type=int, default=128)
    ap.add_argument("--tag", default="run")
    ap.add_argument("--cache", default=ht_post.CACHE)
    ap.add_argument("--outdir", default=ht_post.OUT)
    a = ap.parse_args()
    os.makedirs(a.cache, exist_ok=True)
    log = os.path.join(a.cache, "ht_run-%s.log" % a.tag)
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "-P", SCRIPT, "--", "--names", a.names, "--out",
           a.cache, "--samples", str(a.samples)]
    t0 = time.time()
    rc, tries, dt, lines = locked(cmd, log)
    done = [l.split()[1] for l in lines if l.startswith("[FO-RENDER]")]
    rec = {"tag": a.tag, "names": a.names.split(","), "samples": a.samples, "rc": rc, "lock_tries": tries,
           "wall_s_total": round(dt, 1), "done": done, "started": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(t0))}
    secs = {}
    for n in done:
        with open(os.path.join(a.cache, n, "render.json"), encoding="utf-8") as f:
            secs[n] = json.load(f)
        ht_post.post(n, a.cache, a.outdir)
        print("[FO-POST] %s" % n, flush=True)
    rec["render"] = {n: {"seconds": s["seconds"], "pass": s["seconds_pass"], "canvas": s["canvas"], "faces": s["faces"]}
                     for n, s in secs.items()}
    rec["render_s_sum"] = round(sum(s["seconds"] for s in secs.values()), 1)
    with open(os.path.join(a.cache, "temps-%s.json" % a.tag), "w", encoding="utf-8") as f:
        json.dump(rec, f, indent=1, ensure_ascii=False)
    print("[ht_run] %s : code %d, %d/%d variantes, %.0f s en tout (dont rendu %.0f s), %d essai(s) du verrou"
          % (a.tag, rc, len(done), len(rec["names"]), dt, rec["render_s_sum"], tries), flush=True)
    sys.exit(rc)


if __name__ == "__main__":
    main()
