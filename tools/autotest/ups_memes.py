# Lot UPS (13/11) : la MÊME PARTIE ? Compare le journal des décisions de deux archives de banc (même scénario, même graine).
#
#   PYTHONUTF8=1 py -3.9 -B tools/autotest/ups_memes.py <archive A> <archive B>      (code 0 si 1 et 3 sont identiques)
#
#  1. lignes [FO-CHAMP-ETAT] et [FO-DEBIT-FER] (critere de la mission) ;
#  2. tout le journal [FO-*] du mod, hors lignes de mesure (profileur, etalon, recensement, ombre) et hors lignes du scenario de banc
#     ([FO-PARTIE-REELLE-120], [FO-UPS-*] : nom du scenario) ;
#  3. le meme, numeros de ligne des sites d'appel (« fichier.lua:123 », ecrits par les journaux de diagnostic) remplaces par N :
#     un numero de ligne suit le code source, pas la partie. Les ecarts de 2 qui disparaissent en 3 sont listes par fichier.
# Aucune écriture, aucun jeu.
import sys, gzip, os, re, hashlib, collections
RE_PREFIX = re.compile(r"^\s*[0-9.]+ (?:Script @__[^:]+:\d+: )?")
RE_LIGNE = re.compile(r"([A-Za-z0-9_/]+\.lua):(\d+)")
MESURE = ("[FO-CALIB]", "[FO-PERF3-T]", "[FO-TRACE]", "[FO-BENCH]", "Duration:", "Profiler (fenetre", "Profiler: desactive",
          "[FO-RECENSEMENT]", "[FO-PERF3-DUMP]", "[FO-REGISTRE-OMBRE]", "[FO-PARTIE-REELLE-", "[FO-UPS-")


def lignes(arch):
    p = os.path.join(arch, "benchmark.log.gz")
    f = gzip.open(p, "rt", encoding="utf-8", errors="replace") if os.path.exists(p) else open(os.path.join(arch, "benchmark.log"), encoding="utf-8", errors="replace")
    cibles, tout = [], []
    for l in f:
        if "[FO-" not in l:
            continue
        if any(m in l for m in MESURE):
            continue
        s = RE_PREFIX.sub("", l.rstrip("\n"))
        if not s.startswith("[FO-"):
            continue
        tout.append(s)
        if s.startswith("[FO-CHAMP-ETAT]") or s.startswith("[FO-DEBIT-FER]"):
            cibles.append(s)
    return cibles, tout


def h(x):
    return hashlib.sha1("\n".join(x).encode()).hexdigest()[:12]


def premier(ta, tb):
    for i, (x, y) in enumerate(zip(ta, tb)):
        if x != y:
            m = min(len(x), len(y))
            k = next((j for j in range(m) if x[j] != y[j]), m)
            return "ligne %d, colonne %d :\n  A: ...%s\n  B: ...%s" % (i, k, x[max(0, k - 90):k + 110], y[max(0, k - 90):k + 110])
    return "prefixe commun, longueurs differentes (%d / %d)" % (len(ta), len(tb))


ca, ta = lignes(sys.argv[1])
cb, tb = lignes(sys.argv[2])
print("A = %s\nB = %s" % (os.path.basename(sys.argv[1].rstrip("/")), os.path.basename(sys.argv[2].rstrip("/"))))
print("1. CHAMP-ETAT + DEBIT-FER : A %d lignes %s ; B %d lignes %s ; %s" % (len(ca), h(ca), len(cb), h(cb), "IDENTIQUES" if ca == cb else "DIFFERENTES"))
print("2. journal [FO-*] brut    : A %d lignes %s ; B %d lignes %s ; %s" % (len(ta), h(ta), len(tb), h(tb), "IDENTIQUE" if ta == tb else "DIFFERENT"))
na = [RE_LIGNE.sub(r"\1:N", s) for s in ta]
nb = [RE_LIGNE.sub(r"\1:N", s) for s in tb]
print("3. numeros de ligne -> N  : A %s ; B %s ; %s" % (h(na), h(nb), "IDENTIQUE" if na == nb else "DIFFERENT"))
if na != nb:
    print("premiere difference " + premier(na, nb))
elif ta != tb:
    dec = collections.Counter()
    nl = 0
    for x, y in zip(ta, tb):
        if x != y:
            nl += 1
            for (fa, la), (fb, lb) in zip(RE_LIGNE.findall(x), RE_LIGNE.findall(y)):
                if la != lb:
                    dec[(fa, int(lb) - int(la))] += 1
    print("   %d ligne(s) ne different que par un numero de ligne de site d'appel : %s" % (nl, ", ".join("%s %+d (x%d)" % (f, d, n) for (f, d), n in sorted(dec.items()))))
sys.exit(0 if (ca == cb and na == nb) else 1)
