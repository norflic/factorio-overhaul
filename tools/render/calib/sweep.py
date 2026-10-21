"""Balayage d'un paramètre d'étalonnage (essais rapides) : relance run_calib.py pour chaque valeur.

    python tools/render/calib/sweep.py "<racine>/data" --only chest --base SUN_STRENGTH=4 \
        --param SKY_STRENGTH --values 0.08,0.15,0.25
"""
import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data")
    ap.add_argument("--only", default="chest")
    ap.add_argument("--base", action="append", default=[])
    ap.add_argument("--param", required=True)
    ap.add_argument("--values", required=True)
    ap.add_argument("--samples", default="64")
    ap.add_argument("--keys", default="chest.render_top_front")
    a = ap.parse_args()
    for v in a.values.split(";") if ";" in a.values else a.values.split(","):
        tag = "sweep-%s-%s" % (a.param, v.replace("(", "").replace(")", "").replace(" ", ""))
        cmd = [sys.executable, "-P", os.path.join(HERE, "run_calib.py"), a.data, "--tag", tag, "--samples", a.samples,
               "--only", a.only, "--set", "%s=%s" % (a.param, v)]
        for b in a.base:
            cmd += ["--set", b]
        p = subprocess.run(cmd, capture_output=True, text=True)
        try:
            d = json.loads(p.stdout)
        except Exception:
            print(v, "ERREUR", p.stdout[-800:], p.stderr[-800:])
            continue
        vals = []
        for k in a.keys.split(","):
            x = d
            for part in k.split("."):
                x = x[part]
            vals.append(x)
        print(a.param, "=", v, "->", json.dumps(vals))


if __name__ == "__main__":
    main()
