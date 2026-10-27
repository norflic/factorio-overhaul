"""Enchaîne, sous UNE seule place du verrou de rendu, l'export de géométrie des têtes, le réglage des hauteurs pose
par pose et le rendu d'aperçu des variantes de la famille gun (lot V3 phase 1, reprises 3 et 4).

    python tools/render/pieces/levels/gun/lock_retry.py -- <python.exe> tools/render/pieces/levels/gun/chain_gun.py \
        [--samples 32] [--names a,b,...] [--no-geo] [--no-tune] [--no-render]

GARDE (reprise 4, vérification adverse, mineur 7 ; interdit n° 6 de CLAUDE.md) : ce script lance blender.exe ; il
REFUSE de le faire (code 4) si son processus parent n'est pas le propriétaire d'une place du verrou de rendu
(<racine du jeu>\\fo-render.lock.<k>\\owner.txt, écrit par tools/render/with_render_lock.py, inchangé). Lancé seul,
il ne lance donc jamais Blender. Lecture seule des dossiers du verrou.

Étapes (reprise 4) :
  1. export de la géométrie (geo_export.py : têtes en pose N, socles, socles + pièces) ;
  2. silhouettes géométriques (geo.py, Python système) puis tune.py --apply : zg de chaque époque sur la cible O ;
  3. second export des têtes (zg réglé), silhouettes, tune.py --strict : max ≤ cible ET O non décroissant POSE PAR
     POSE ; en cas d'échec, ARRÊT avant le rendu (code 3 : la géométrie doit être reprise) ;
  4. rendu d'aperçu de toutes les variantes demandées (render_batch.py), dans la même session Blender.
Les processus héritent de la priorité « inférieure à la normale » posée par with_render_lock.py. Le
post-traitement (render_gun.py --post-only), le balayage 64 directions (geo.py --sweep) et les mesures se font
ENSUITE, hors du verrou.
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gun as G  # noqa: E402

MOD = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
BLENDER = os.environ.get("FO_BLENDER", r"C:\Users\evan2\tools\blender-5.2.2\blender.exe")
GEO = os.path.join(MOD, "tools", "render", "cache", "levels-gun", "geo")
CACHE = os.path.join(MOD, "tools", "render", "cache", "levels-gun", "cycles")
LOCK_DIR = os.environ.get("FO_RENDER_LOCK_DIR", r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91")


def lock_slot_of_parent():
    """Place du verrou dont le propriétaire est le processus parent (None sinon). Lecture seule."""
    ppid = os.getppid()
    for k in range(1, 17):
        d = os.path.join(LOCK_DIR, "fo-render.lock.%d" % k)
        try:
            with open(os.path.join(d, "owner.txt"), encoding="utf-8") as f:
                pid = int(f.read().split()[0])
        except (OSError, ValueError, IndexError):
            continue
        if pid == ppid:
            return d
    return None


def blender(script, args):
    if lock_slot_of_parent() is None:
        print("[chain] REFUS : le processus parent (PID %d) ne tient aucune place du verrou de rendu ; lancer par "
              "lock_retry.py ou tools/render/with_render_lock.py (interdit n° 6)" % os.getppid(), flush=True)
        return 4
    cmd = [BLENDER, "-b", "--factory-startup", "-noaudio", "-P", os.path.join(HERE, script), "--"] + args
    print("[chain] " + " ".join(cmd[-6:]), flush=True)
    return subprocess.call(cmd)


def py(script, args):
    cmd = [sys.executable, "-B", os.path.join(HERE, script)] + args
    print("[chain] python " + script + " " + " ".join(args), flush=True)
    return subprocess.call(cmd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", type=int, default=32)
    ap.add_argument("--names", default="")
    ap.add_argument("--no-geo", action="store_true")
    ap.add_argument("--no-tune", action="store_true")
    ap.add_argument("--no-render", action="store_true")
    ap.add_argument("--tune-epochs", default="", help="époques réglées par tune.py --apply (défaut : toutes)")
    a = ap.parse_args()
    slot = lock_slot_of_parent()
    if slot is None:
        print("[chain] REFUS : lancé hors du verrou de rendu (parent PID %d) ; aucune commande Blender ne part" %
              os.getppid(), flush=True)
        return 4
    print("[chain] place du verrou : %s" % slot, flush=True)
    heads = ",".join("e%02d-tete-N" % e for e in range(2, 16))
    if not a.no_geo:
        fixed = ",".join(sorted(n for n, v in G.PIECE["variants"].items() if v["part"] != "tete"))
        rc = blender("geo_export.py", ["--out", GEO, "--only", heads + "," + fixed])
        if rc:
            return rc
        rc = py("geo.py", [])
        if rc:
            return rc
    if not a.no_tune:
        rc = py("tune.py", ["--apply"] + (["--epochs", a.tune_epochs] if a.tune_epochs else []))
        if rc:
            return rc
        rc = blender("geo_export.py", ["--out", GEO, "--only", heads])
        if rc:
            return rc
        rc = py("geo.py", ["--only", ",".join("e%02d-tete" % e for e in range(2, 16))])
        if rc:
            return rc
        rc = py("tune.py", ["--strict"])
        if rc:
            print("[chain] contrôle pose par pose en ÉCHEC : rendu annulé", flush=True)
            return rc
    if a.no_render:
        return 0
    names = [n for n in a.names.split(",") if n] or sorted(G.PIECE["variants"])
    os.makedirs(CACHE, exist_ok=True)
    return blender("render_batch.py", ["--names", ",".join(names), "--out", CACHE, "--samples", str(a.samples)])


if __name__ == "__main__":
    sys.exit(main())
