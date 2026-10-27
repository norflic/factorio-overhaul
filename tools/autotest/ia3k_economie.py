"""Lot IA3-k : économie d'une faction à une minute donnée, lue dans le journal d'un banc (lignes « ===== minute N »,
en-tête de la faction, puis « equipe : … livre fer X cuivre Y charbon Z … »). Mêmes compteurs pour le lot et son témoin.

    py -3.9 -B tools/autotest/ia3k_economie.py <archive ou benchmark.log[.gz]> [minute=70] [faction=Scarlet]
"""
import gzip
import os
import re
import sys


def lignes(chemin):
    if os.path.isdir(chemin):
        chemin = os.path.join(chemin, "benchmark.log.gz") if os.path.exists(
            os.path.join(chemin, "benchmark.log.gz")) else os.path.join(chemin, "benchmark.log")
    ouvrir = gzip.open if chemin.endswith(".gz") else open
    with ouvrir(chemin, "rt", encoding="utf-8", errors="replace") as f:
        return f.read().splitlines()


def economie(chemin, minute=70, faction="Scarlet"):
    tout = lignes(chemin)
    debut = None
    for i, l in enumerate(tout):
        if f"===== minute {minute} (tick" in l:
            debut = i
            break
    if debut is None:
        return None
    dans = False
    entete = None
    for l in tout[debut:debut + 400]:
        if f"===== minute {minute + 1} (tick" in l:
            break
        if "remote.lua:60:" not in l:
            continue
        corps = l.split("remote.lua:60:", 1)[1]
        net = corps.lstrip()
        retrait = len(corps) - len(net)
        if retrait <= 3:
            dans = net.startswith(faction)
            if dans:
                entete = net
        elif dans and net.startswith("equipe :"):
            m = re.search(r"livre fer (\d+) cuivre (\d+) charbon (\d+)", corps)
            pm = re.search(r"avant-postes (\d+)", entete or "")
            so = re.search(r"soldats (\d+)", entete or "")
            if m:
                return {"fer": int(m.group(1)), "cuivre": int(m.group(2)), "charbon": int(m.group(3)),
                        "avant_postes": int(pm.group(1)) if pm else None, "soldats": int(so.group(1)) if so else None}
    return None


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    mn = int(sys.argv[2]) if len(sys.argv) > 2 else 70
    fa = sys.argv[3] if len(sys.argv) > 3 else "Scarlet"
    e = economie(sys.argv[1], mn, fa)
    if e is None:
        print(f"[IA3K-ECO] {sys.argv[1]} : minute {mn} ou faction {fa} introuvable")
        sys.exit(2)
    print(f"[IA3K-ECO] {sys.argv[1]} : {fa} a la minute {mn} : livre fer {e['fer']}, cuivre {e['cuivre']}, charbon "
          f"{e['charbon']} ; avant-postes {e['avant_postes']} ; soldats {e['soldats']}")
