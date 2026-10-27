# Lot IA-V2 (27/10) : critère K11 (docs/IA3_CERVEAU.md §6.1, déterminisme) : deux passages de la MÊME carte (même
# graine, même source) doivent donner les mêmes décisions du mod. Empreinte = SHA-256 des lignes de décision du journal
# (benchmark.log.gz archivé par banc.py), horodatage du moteur et numéro de ligne retirés, jusqu'à une minute donnée :
# lignes « [FO-TEAM] », « [FO-IA3B] », « [FO-IA3C] », « [FO-IA3F] », « [FO-WAR] » et lignes minute du scénario.
# Usage : py -3.9 -B tools/autotest/iav2_empreinte.py <archive A> <archive B> [--minutes 30]
# Code 0 : empreintes égales ; 1 : différentes (la première ligne qui diffère est imprimée).
import gzip
import hashlib
import os
import re
import sys

TAGS = ("[FO-TEAM]", "[FO-IA3B]", "[FO-IA3C]", "[FO-IA3F]", "[FO-WAR]")
RE_PREFIX = re.compile(r"^\s*[0-9.]+ Script @__[^_]+__/[^:]+:\d+: ")
RE_MINUTE = re.compile(r"\] minute (\d+) \|")
RE_AT = re.compile(r" a ([0-9.]+) min")


def lines_of(archive, minutes):
    out = []
    with gzip.open(os.path.join(archive, "benchmark.log.gz"), "rt", encoding="utf-8", errors="replace") as f:
        for line in f:
            if not any(t in line for t in TAGS) and " minute " not in line:
                continue
            s = RE_PREFIX.sub("", line.rstrip("\n"))
            m = RE_MINUTE.search(s)
            if m and int(m.group(1)) > minutes:
                continue
            m = RE_AT.search(s)
            if m and float(m.group(1)) > minutes:
                continue
            out.append(s)
    return out


def main(argv):
    minutes = 30
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--minutes":
            minutes = int(argv[i + 1])
            i += 2
        else:
            args.append(argv[i])
            i += 1
    a, b = args[0], args[1]
    la, lb = lines_of(a, minutes), lines_of(b, minutes)
    ha = hashlib.sha256("\n".join(la).encode("utf-8")).hexdigest()
    hb = hashlib.sha256("\n".join(lb).encode("utf-8")).hexdigest()
    na, nb = os.path.basename(os.path.normpath(a)), os.path.basename(os.path.normpath(b))
    print(f"[FO-HASH] {na} : {len(la)} lignes jusqu'à {minutes} min, {ha[:16]}")
    print(f"[FO-HASH] {nb} : {len(lb)} lignes jusqu'à {minutes} min, {hb[:16]}")
    if ha == hb:
        print(f"K11 : empreintes ÉGALES ({len(la)} lignes de décision sur {minutes} min)")
        return 0
    for k in range(min(len(la), len(lb))):
        if la[k] != lb[k]:
            print(f"K11 : DIFFÉRENTES, première différence à la ligne {k + 1} :\n  A : {la[k]}\n  B : {lb[k]}")
            return 1
    print(f"K11 : DIFFÉRENTES, longueurs {len(la)} contre {len(lb)}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
