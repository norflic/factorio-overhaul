"""Lot IA1-b : « une équipe de 30 livre-t-elle plus qu'une équipe de 10 ? » (protocole ia1b-scale30 / ia1b-scale10).

Usage : python -B tools/autotest/ia1b_livre.py <archive 30> <archive 10> [<archive 30 avant> <archive 10 avant>]
Chaque archive est une copie de fo-autotest\\ (benchmark.log, et benchmark-stdout.txt ou .zip). Lit, par équipe, la
production de la force sur la partie (MU : plaques de fer et de cuivre, charbon, pierre ; statistiques du moteur),
l'inactivité réelle (à la pensée), l'effectif final ; et les morts d'agents causées par les ennemis (sortie du banc).
Imprime un tableau et le rapport 30 / 10 par équipe et au total. Code 0 si les journaux sont lisibles, 1 sinon.
"""
import io
import os
import re
import sys
import zipfile

RE_TEAM = re.compile(r"\] (\w+) : sur toute la partie, inactivite reelle ([\d.]+) % ; .*?production (-?\d+) MU")
RE_MIN = re.compile(r"\] minute (\d+) \| (\w+) n=(\d+)/(\d+)")
RE_DEATH = re.compile(r"Morts d'agents \(cause/force:degats\) : (.*)$", re.M)


def read_stdout(d):
    p = os.path.join(d, "benchmark-stdout.txt")
    if os.path.exists(p):
        with open(p, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    z = p + ".zip"
    if os.path.exists(z):
        with zipfile.ZipFile(z) as zf:
            name = zf.namelist()[0]
            return io.TextIOWrapper(zf.open(name), encoding="utf-8", errors="replace").read()
    return ""


def load(d):
    with open(os.path.join(d, "benchmark.log"), encoding="utf-8", errors="replace") as fh:
        log = fh.read()
    teams, last_n = {}, {}
    for m in RE_TEAM.finditer(log):
        teams[m.group(1)] = {"idle": float(m.group(2)), "mu": int(m.group(3))}
    for m in RE_MIN.finditer(log):
        last_n[m.group(2)] = int(m.group(3))
    for k, v in teams.items():
        v["n_fin"] = last_n.get(k, 0)
    enemy = 0
    deaths = RE_DEATH.findall(read_stdout(d))
    if deaths:
        for part in deaths[-1].split(","):
            part = part.strip()
            if "/enemy:" in part:
                enemy += int(part.rsplit("=", 1)[1])
    return teams, enemy


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    labels = ["30 (lot)", "10 (lot)", "30 (avant)", "10 (avant)"][: len(argv)]
    data = []
    for d in argv:
        try:
            data.append(load(d))
        except OSError as e:
            print("illisible :", d, e)
            return 1
    keys = []
    for teams, _ in data:
        for k in teams:
            if k not in keys:
                keys.append(k)
    print("equipe".ljust(10) + "".join(lab.rjust(36) for lab in labels))
    for k in keys:
        row = k.ljust(10)
        for teams, _ in data:
            t = teams.get(k)
            row += (f"{t['mu']} MU, inact. {t['idle']:.0f} %, fin {t['n_fin']}" if t else "absente").rjust(36)
        print(row)
    totals = [sum(t["mu"] for t in teams.values()) for teams, _ in data]
    print("TOTAL".ljust(10) + "".join(f"{x} MU".rjust(36) for x in totals))
    print("morts (ennemis)".ljust(10) + "".join(f"{e}".rjust(36) for _, e in data))
    for i in range(0, len(data) - 1, 2):
        a, b = data[i][0], data[i + 1][0]
        parts = []
        for k in keys:
            if k in a and k in b and b[k]["mu"] > 0:
                parts.append(f"{k} {a[k]['mu'] / b[k]['mu']:.2f}")
        ratio = totals[i] / totals[i + 1] if totals[i + 1] else float("nan")
        print(f"30 / 10 {labels[i].split()[1]} : total {ratio:.2f} ; " + ", ".join(parts))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
