"""LOT F1-C (4/11) : PRODUCTION des sprites de la tourelle laser (designs validés par le DC, QCM-4/11-LASER-F1C). Python 3.9.
Lancé depuis la racine du mod (ou du worktree). Modèle : gun_e/produire_a3.py, en plus simple (une session à la fois : F145,
deux rendus Blender en parallèle ne vont pas plus vite sur ce PC).

    py -3.9 tools/render/pieces/levels/laser_e/produire.py [--dry-run] [--directions 2-15=64] [--ages 2-15]
        [--minutes 15] [--sortie DIR] [--journal FICHIER] [--stop FICHIER] [--max-paquets N]

Cibles : e01-piece ; pour chaque âge 2 à 15, eNN-socle, eNN-piece et les têtes eNN-tete-dKK de ses directions (64 :
d00 à d63 ; 32 : d00, d02, … d62 ; --directions, même syntaxe que feuilles.py). Ordre : âge par âge (pièce e01 d'abord),
socle et pièce puis têtes, pour que les feuilles d'un âge puissent être faites et regardées dès qu'il est fini.
Qualité de PRODUCTION : 128 échantillons, jamais --quick ni --apercu ; têtes à l'ombre de 32 échantillons (D-7).
Paquets HOMOGÈNES (têtes, ou socles et pièces), d'au plus --minutes de rendu ESTIMÉ (temps mesurés du lot, puis temps
réels des variantes déjà faites du même âge et de la même partie), une session Blender par paquet par le verrou de rendu
(rendre.py --only … --sessions 1 : interdit n° 6, priorité basse, garde de disque) ; une session ne dépasse pas 20 min.
REPRENABLE : une variante est FAITE quand son spec.json est de production et que chaque PNG a le sha256 du spec.json ;
une variante faite n'est jamais refaite. TROUS : une variante au plus grand trou enfermé > 8 px est gardée et inscrite
« HORS REGLE » au journal et dans hors_regle.txt (à regarder, puis feuilles.py --hors-regle-ok) ; code de sortie 3.
ARRÊT PROPRE : fichier --stop présent -> aucun nouveau paquet (le paquet en cours finit) ; relancer reprend.
Codes : 0 tout fait ; 1 erreur (rendu en échec, variante non faite à la fin) ; 2 STOP ; 3 hors règle ; 4 garde de disque.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import feuilles as FE  # noqa: E402

BASE = os.path.join(FE.LOGS, "2026-11-04_LASER-F1C", "production")
SORTIE = os.path.join(BASE, "sprites")
JOURNAL = os.path.join(BASE, "production.log")
STOP = os.path.join(BASE, "STOP")
RENDRE = os.path.join(HERE, "rendre.py")
SAMPLES = 128
PASSES_TETE = "shadow=32"


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def partie(nom):
    return "tete" if "-tete-" in nom else nom.split("-", 1)[1]


def cibles(ndirs, ages):
    res = ["e01-piece"] if 1 in ages else []
    for e in sorted(a for a in ages if a >= 2):
        res += ["e%02d-socle" % e, "e%02d-piece" % e]
        n = ndirs[e]
        res += ["e%02d-tete-d%02d" % (e, k * FE.NDIR_MAX // n) for k in range(n)]
    return res


def etat(sortie, nom):
    """(fait, motif, spec) ; ne lève jamais d'exception."""
    try:
        p = os.path.join(sortie, nom, "spec.json")
        if not os.path.exists(p):
            return False, "absente", None
        with open(p, encoding="utf-8") as f:
            s = json.load(f)
        if s.get("variant") != nom or s.get("kit") != "laser_e":
            return False, "spec.json d'une autre variante", s
        if s.get("samples") != SAMPLES or s.get("quick") or s.get("apercu"):
            return False, "pas de production (échantillons %s)" % s.get("samples"), s
        attendu = {"shadow": 32} if partie(nom) == "tete" else None
        if (s.get("samples_passes") or None) != attendu:
            return False, "samples_passes %s, attendu %s" % (s.get("samples_passes"), attendu), s
        if "main" not in s.get("layers", {}):
            return False, "sans couche principale", s
        for lay, L in s["layers"].items():
            for LL in (L, L["lr"]):
                f = os.path.join(sortie, nom, LL["file"])
                if not os.path.exists(f) or sha(f) != LL["sha256"]:
                    return False, "PNG absent ou sha256 différent (%s)" % LL["file"], s
        return True, "", s
    except Exception as ex:  # noqa: BLE001 (lecture : jamais d'exception, la variante est à refaire)
        return False, "lecture impossible : %r" % ex, None


def estime(nom, faits):
    """Secondes estimées (durée totale de la variante dans sa session, construction comprise) : moyenne des variantes faites de même âge et partie, sinon temps mesurés du lot
    (128 échantillons : tête de l'âge 2 9 s, de l'âge 15 30 s ; socle de l'âge 9 134 s)."""
    e, p = int(nom[1:3]), partie(nom)
    vus = [s for n, s in faits.items() if int(n[1:3]) == e and partie(n) == p and s]
    if vus:
        return sum(vus) / len(vus)
    # âge pas encore rendu : temps du lot × rapport (réel / estimé) des variantes faites de la même partie (1re production :
    # têtes de l'âge 7 à 23 s pour 17 s estimées ; sans ce rapport, les paquets des grands âges dépassaient 20 min)
    # rapport le plus FORT par âge déjà rendu (prudence : têtes de l'âge 9 à 1,8 fois l'estimation, paquet de 19 min 45)
    par_age = {}
    for n, s in faits.items():
        if partie(n) == p and s:
            par_age.setdefault(int(n[1:3]), []).append(s / defaut(n))
    k = max([1.0] + [sum(v) / len(v) for v in par_age.values()])
    return defaut(nom) * k


def defaut(nom):
    e, p = int(nom[1:3]), partie(nom)
    if p == "tete":
        return 9.0 + 1.6 * (e - 2)
    if p == "socle":
        return 40.0 + 12.0 * e
    return 20.0 + 5.0 * e


def paquets(reste, faits, minutes):
    res, cur, t, genre = [], [], 0.0, None
    for nom in reste:
        g = partie(nom) == "tete"
        d = estime(nom, faits)
        if cur and (g != genre or t + d > minutes * 60 or len(cur) >= 64):
            res.append(cur)
            cur, t = [], 0.0
        cur.append(nom)
        t += d
        genre = g
    if cur:
        res.append(cur)
    return res


def journal(path, msg):
    ligne = "%s %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg)
    print(ligne, flush=True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(ligne + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--directions", default=FE.DIRECTIONS_DEFAUT)
    ap.add_argument("--ages", default="1-15")
    ap.add_argument("--minutes", type=float, default=10.0, help="rendu estimé par paquet (une session ≤ 20 min)")
    ap.add_argument("--sortie", default=SORTIE)
    ap.add_argument("--journal", default=JOURNAL)
    ap.add_argument("--stop", default=STOP)
    ap.add_argument("--max-paquets", type=int, default=0)
    ap.add_argument("--rendre", default=RENDRE, help="(bancs de l'outil) rendre.py à appeler")
    a = ap.parse_args()
    ndirs = FE.plages(a.directions)
    if "-" in a.ages:
        lo, hi = a.ages.split("-")
        ages = list(range(int(lo), int(hi) + 1))
    else:
        ages = [int(x) for x in a.ages.split(",") if x]
    toutes = cibles(ndirs, ages)
    faits, reste, motifs = {}, [], {}
    for nom in toutes:
        ok, motif, s = etat(a.sortie, nom)
        if ok:
            faits[nom] = (s or {}).get("seconds") or (s or {}).get("seconds_render")
        else:
            reste.append(nom)
            motifs[nom] = motif
    pq = paquets(reste, faits, a.minutes)
    est = sum(estime(n, faits) for n in reste)
    print("[FO-PROD-LASER] %d variantes visées, %d faites, %d à faire en %d paquet(s) ; rendu estimé %.1f h ; "
          "directions %s" % (len(toutes), len(faits), len(reste), len(pq), est / 3600.0, a.directions))
    if a.dry_run:
        par = {}
        for n in reste:
            par.setdefault(n[:3], []).append(n)
        for k in sorted(par):
            print("  %s : %d à faire (%s)" % (k, len(par[k]), motifs[par[k][0]]))
        for i, p in enumerate(pq[:5]):
            print("  paquet %d : %d variantes, %s … %s, %.0f s estimées" % (i + 1, len(p), p[0], p[-1],
                                                                           sum(estime(n, faits) for n in p)))
        return 0
    cache = os.path.join(os.path.dirname(os.path.abspath(a.sortie)), "cache_sprites")
    journal(a.journal, "DEBUT : %d à faire, %d paquets, %.1f h estimées, directions %s" % (len(reste), len(pq),
                                                                                         est / 3600.0, a.directions))
    hors_regle, erreurs, code_disque = [], 0, False
    t0 = time.time()
    i = -1
    tentes = set()
    while True:
        # paquets RECALCULÉS après chaque paquet, aux temps réels déjà mesurés (4/11, 19 h 30 : une partie du DC en
        # cours ralentissait les têtes de l'âge 10 à 70-105 s, un paquet prévu à 10 min en durait 29)
        a_faire = [n for n in toutes if n not in faits and n not in tentes]
        if not a_faire:
            break
        pq = paquets(a_faire, faits, a.minutes)
        p = pq[0]
        i += 1
        if os.path.exists(a.stop):
            journal(a.journal, "STOP trouvé (%s) : arrêt avant le paquet %d (%d à faire)" % (a.stop, i + 1,
                                                                                           len(a_faire)))
            return 2
        if a.max_paquets and i >= a.max_paquets:
            break
        tentes.update(p)
        tete = partie(p[0]) == "tete"
        cmd = [sys.executable, "-B", a.rendre, "--only", ",".join(p), "--samples", str(SAMPLES), "--out", a.sortie,
               "--cache", cache, "--per", str(len(p)), "--sessions", "1"]
        if tete:
            cmd += ["--samples-passes", PASSES_TETE]
        journal(a.journal, "paquet %d (%d restants) : %d variantes (%s … %s), %.0f s estimées" % (
            i + 1, len(pq), len(p), p[0], p[-1], sum(estime(n, faits) for n in p)))
        tp = time.time()
        try:
            r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               env=dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1"))
            sortie = r.stdout.decode("utf-8", "replace")
            if r.returncode:
                erreurs += 1
                if "REFUS" in sortie and "disque" in sortie.lower():
                    code_disque = True
                journal(a.journal, "paquet %d : rendre.py code %d ; fin de sortie :\n%s" % (i + 1, r.returncode,
                                                                                         sortie[-2500:]))
                if code_disque:
                    return 4
        except Exception:  # noqa: BLE001
            erreurs += 1
            journal(a.journal, "paquet %d : exception\n%s" % (i + 1, traceback.format_exc()))
        for nom in p:
            ok, motif, s = etat(a.sortie, nom)
            if not ok:
                erreurs += 1
                journal(a.journal, "  %s : NON FAITE (%s)" % (nom, motif))
                continue
            faits[nom] = s.get("seconds") or s.get("seconds_render")
            c = s.get("checks", {})
            if not c.get("holes_ok", False):
                hors_regle.append("%s %s px" % (nom, c.get("largest_hole_px")))
                journal(a.journal, "  %s : HORS REGLE, trou enfermé de %s px" % (nom, c.get("largest_hole_px")))
        n_fait = sum(1 for n in toutes if n in faits)
        dt = time.time() - t0
        restant = sum(estime(n, faits) for n in toutes if n not in faits)
        journal(a.journal, "paquet %d fini en %.0f s ; %d / %d faites ; reste estimé %.0f min (fin vers %s)" % (
            i + 1, time.time() - tp, n_fait, len(toutes), restant / 60.0,
            time.strftime("%H:%M", time.localtime(time.time() + restant * 1.08))))
    if hors_regle:
        with open(os.path.join(os.path.dirname(os.path.abspath(a.journal)), "hors_regle.txt"), "a",
                  encoding="utf-8") as f:
            f.write("\n".join(hors_regle) + "\n")
    manquent = [n for n in toutes if not etat(a.sortie, n)[0]]
    journal(a.journal, "FIN : %d / %d faites, %d erreur(s), %d hors règle, %.0f min" % (
        len(toutes) - len(manquent), len(toutes), erreurs, len(hors_regle), (time.time() - t0) / 60.0))
    if manquent and not a.max_paquets:
        return 1
    if hors_regle:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
