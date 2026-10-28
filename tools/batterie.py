#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Batterie hors jeu du mod Factorio Overhaul : toutes les suites en un seul passage.

Lance en parallele les suites listees dans tools/batterie_attendus.json (Lua pur, harness, api_lint,
outils Python), compare chaque bilan a l'attendu, imprime UNE table et un verdict global, ecrit
tools/batterie_derniere.txt. Python 3.9, aucune dependance. Aucun moteur de jeu n'est lance.

Code de sortie : 0 tout vert, 1 au moins un ecart (ou, avec --strict, une suite non listee),
2 erreur d'usage (fichier d'attendus illisible, suite inconnue).
"""
import argparse
import concurrent.futures as cf
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

AIDE = """\
Emploi :
  py -3.9 tools/batterie.py --rapide             verdict en 2 a 3 min de calcul (sans pvp_test ni les suites de plus d'1 min)
  py -3.9 tools/batterie.py                      tout, y compris les suites lentes (pvp_test seul : environ 8 min de calcul)
  py -3.9 tools/batterie.py --seulement levels_test,api_lint     quelques suites ; --liste : voir sans lancer
Les attendus sont dans tools/batterie_attendus.json ; apres un lot qui change des comptes ou ajoute une suite,
relancer en entier puis `--regenerer-attendus --oui` (seulement avec l'accord de l'integrateur). Le journal du
dernier passage est tools/batterie_derniere.txt."""

DEFAUT_REGEX = r"(?P<ok>\d+) OK, (?P<echec>\d+) ECHEC"
VERDICTS_VERTS = ("OK", "OK*", "SAUT")
FALLBACK_LUA = r"C:\Users\evan2\bin\lua5.2.exe"

# --------------------------------------------------------------------------------------------------
# Lecture des attendus
# --------------------------------------------------------------------------------------------------


def charger_attendus(chemin):
    with open(chemin, "r", encoding="utf-8") as f:
        data = json.load(f)
    noms = set()
    for s in data.get("suites", []):
        for cle in ("nom", "cmd"):
            if cle not in s:
                raise ValueError("suite sans '%s' : %r" % (cle, s))
        if s["nom"] in noms:
            raise ValueError("suite en double : %s" % s["nom"])
        noms.add(s["nom"])
        if "regex" not in s and "zeros" not in s:
            s["regex"] = DEFAUT_REGEX
    return data


def racine_jeu(mod, explicite=None):
    """Dossier du jeu : celui qui contient doc-html et data, en remontant depuis le mod."""
    if explicite:
        return os.path.abspath(explicite)
    if os.environ.get("FO_RACINE"):
        return os.path.abspath(os.environ["FO_RACINE"])
    d = os.path.abspath(mod)
    while True:
        if os.path.isdir(os.path.join(d, "doc-html")) and os.path.isdir(os.path.join(d, "data")):
            return d
        p = os.path.dirname(d)
        if p == d:
            return None
        d = p


def trouver_lua(explicite=None):
    if explicite:
        return explicite
    if os.environ.get("FO_LUA"):
        return os.environ["FO_LUA"]
    return shutil.which("lua5.2") or (FALLBACK_LUA if os.path.exists(FALLBACK_LUA) else "lua5.2")


# --------------------------------------------------------------------------------------------------
# Lecture du bilan et verdict (regles pures, testees par tools/tests/test_batterie.py)
# --------------------------------------------------------------------------------------------------


def lire_bilan(suite, sortie):
    """(ok, echec) lus dans la sortie, ou None si le bilan est introuvable.

    - mode 'regex' : DERNIERE occurrence du motif (groupes nommes ok puis echec, ou total) ;
    - mode 'zeros' : liste de motifs a un groupe ; chaque occurrence compte, ok = occurrences a 0,
      echec = occurrences non nulles (pour harness : « 0 violation(s) », « 0 ecart(s) »...).
    """
    if "zeros" in suite:
        ok = echec = 0
        for motif in suite["zeros"]:
            for m in re.finditer(motif, sortie):
                if int(m.group(1)) == 0:
                    ok += 1
                else:
                    echec += 1
        if ok + echec == 0:
            return None
        return ok, echec
    derniere = None
    for m in re.finditer(suite.get("regex", DEFAUT_REGEX), sortie):
        derniere = m
    if derniere is None:
        return None
    gd = derniere.groupdict()
    ok = int(gd["ok"])
    if gd.get("echec") is not None:
        return ok, int(gd["echec"])
    if gd.get("total") is not None:  # « 18/18 mutants detectes » : l'echec est ce qui manque au total
        return ok, max(0, int(gd["total"]) - ok)
    return ok, 0


def juger(suite, code, sortie, duree, delai_depasse):
    """Verdict d'UNE execution. Rend (verdict, ok, echec, note)."""
    bilan = lire_bilan(suite, sortie)
    ok, echec = bilan if bilan else (None, None)
    if delai_depasse:
        return "DELAI", ok, echec, "tue apres %.0f s (max %s s)" % (duree, suite.get("duree_max"))
    if bilan is None:
        return "PLANTAGE", None, None, "aucun bilan lu (code %s)" % code
    if echec > suite.get("echec_max", 0):
        return "ECHEC", ok, echec, "%d echec(s) pour %d permis" % (echec, suite.get("echec_max", 0))
    if ok < suite.get("ok_min", 1):
        return "ECART", ok, echec, "%d OK pour au moins %d attendus" % (ok, suite.get("ok_min", 1))
    if code != suite.get("code_ok", 0):
        return "CODE", ok, echec, "code de sortie %s au lieu de %s" % (code, suite.get("code_ok", 0))
    return "OK", ok, echec, ""


def est_vert(verdict):
    return verdict in VERDICTS_VERTS


def verdict_global(resultats, avertissements=(), strict=False):
    """Code de sortie : 0 tout vert, 1 un ecart."""
    if any(not est_vert(r["verdict"]) for r in resultats):
        return 1
    if strict and avertissements:
        return 1
    return 0


# --------------------------------------------------------------------------------------------------
# Execution
# --------------------------------------------------------------------------------------------------


def substituer(arg, ctx):
    for cle in ("lua", "py", "mod", "racine", "tmp"):
        arg = arg.replace("{" + cle + "}", ctx.get(cle) or "")
    return arg


class _Job:
    """Objet job Windows : mesure le temps de calcul (CPU) de la suite ET de ses processus fils, independant de
    la charge du PC (le temps ecoule, lui, depend des bancs voisins). Sans effet hors Windows."""

    def __init__(self):
        self.h = None
        if os.name != "nt":
            return
        try:
            import ctypes
            self.k = ctypes.windll.kernel32
            self.k.CreateJobObjectW.restype = ctypes.c_void_p
            self.h = self.k.CreateJobObjectW(None, None)
        except Exception:
            self.h = None

    def attacher(self, proc):
        if not self.h:
            return
        try:
            import ctypes
            self.k.AssignProcessToJobObject.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
            if not self.k.AssignProcessToJobObject(self.h, int(proc._handle)):
                self.h = None  # deja dans un job qui l'interdit : pas de mesure, la suite tourne quand meme
        except Exception:
            self.h = None

    def cpu(self):
        """Secondes de CPU (utilisateur + noyau) de tous les processus du job, ou None."""
        if not self.h:
            return None
        try:
            import ctypes

            class Compte(ctypes.Structure):
                _fields_ = [("user", ctypes.c_int64), ("noyau", ctypes.c_int64), ("u2", ctypes.c_int64),
                            ("n2", ctypes.c_int64), ("fautes", ctypes.c_uint32), ("total", ctypes.c_uint32),
                            ("actifs", ctypes.c_uint32), ("tues", ctypes.c_uint32)]
            c = Compte()
            self.k.QueryInformationJobObject.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p,
                                                         ctypes.c_uint32, ctypes.c_void_p]
            if not self.k.QueryInformationJobObject(self.h, 1, ctypes.byref(c), ctypes.sizeof(c), None):
                return None
            return (c.user + c.noyau) / 1e7
        except Exception:
            return None

    def fermer(self):
        if self.h:
            try:
                import ctypes
                self.k.CloseHandle.argtypes = [ctypes.c_void_p]
                self.k.CloseHandle(self.h)
            except Exception:
                pass
            self.h = None


def _tuer(proc):
    try:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=30)
        else:
            import signal
            os.killpg(proc.pid, signal.SIGKILL)
    except Exception:
        pass
    try:
        proc.kill()
    except Exception:
        pass


def executer(suite, ctx, facteur_delai=1.0):
    """Lance la suite une fois. Rend un dict de resultat."""
    tmp = tempfile.mkdtemp(prefix="batterie_") if any("{tmp}" in a for a in suite["cmd"]) else None
    ctx = dict(ctx, tmp=tmp or "")
    cmd = [substituer(a, ctx) for a in suite["cmd"]]
    env = dict(os.environ)
    env["PYTHONUTF8"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    if ctx.get("racine"):
        env["FO_DATA_DIR"] = os.path.join(ctx["racine"], "data")
    if os.path.isabs(ctx.get("lua", "")):  # les outils Python qui lancent « lua5.2 » le trouvent par le PATH
        env["PATH"] = os.path.dirname(ctx["lua"]) + os.pathsep + env.get("PATH", "")
    env.update({k: substituer(v, ctx) for k, v in suite.get("env", {}).items()})
    delai = float(suite.get("duree_max", 600)) * facteur_delai
    t0 = time.time()
    delai_depasse = False
    code = None
    cpu = None
    job = _Job()
    try:
        kw = {}
        if os.name == "nt":
            kw["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
        else:
            kw["start_new_session"] = True
        try:
            proc = subprocess.Popen(cmd, cwd=ctx["mod"], env=env, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kw)
        except OSError as e:
            return {"nom": suite["nom"], "verdict": "PLANTAGE", "ok": None, "echec": None, "code": None,
                    "duree": 0.0, "cpu": None, "note": "lancement impossible : %s" % e, "sortie": "", "essais": 1}
        job.attacher(proc)
        try:
            brut, _ = proc.communicate(timeout=delai)
            code = proc.returncode
        except subprocess.TimeoutExpired:
            delai_depasse = True
            _tuer(proc)
            try:
                brut, _ = proc.communicate(timeout=30)
            except Exception:
                brut = b""
            code = None
        sortie = (brut or b"").decode("utf-8", errors="replace")
        cpu = job.cpu()
    finally:
        job.fermer()
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)
    duree = time.time() - t0
    verdict, ok, echec, note = juger(suite, code, sortie, duree, delai_depasse)
    return {"nom": suite["nom"], "verdict": verdict, "ok": ok, "echec": echec, "code": code,
            "duree": duree, "cpu": cpu, "note": note, "sortie": sortie, "essais": 1}


def lancer_tout(suites, ctx, jobs=4, lents=1, facteur_delai=1.0, rapide=False, rappel=None):
    """Lance les suites. Les lentes partent tout de suite sur leurs propres emplacements (arriere-plan),
    les autres sur un pool de `jobs`, les plus longues d'abord. Rend la liste des resultats dans l'ordre
    du fichier d'attendus."""
    resultats = {}
    verrou = threading.Lock()
    a_lancer = []
    for s in suites:
        if rapide and s.get("lent"):
            resultats[s["nom"]] = {"nom": s["nom"], "verdict": "SAUT", "ok": None, "echec": None, "code": None,
                                   "duree": 0.0, "cpu": None, "note": "suite lente, sautee par --rapide", "sortie": "",
                                   "essais": 0}
        else:
            a_lancer.append(s)
    normales = sorted([s for s in a_lancer if not s.get("lent")], key=lambda s: -s.get("duree_ref", 0))
    lentes = sorted([s for s in a_lancer if s.get("lent")], key=lambda s: -s.get("duree_ref", 0))

    def travail(s):
        r = executer(s, ctx, facteur_delai)
        with verrou:
            resultats[s["nom"]] = r
            if rappel:
                rappel(r, len(resultats), len(suites))
        return r

    with cf.ThreadPoolExecutor(max_workers=max(1, jobs)) as ex_n, \
            cf.ThreadPoolExecutor(max_workers=max(1, lents)) as ex_l:
        futs = [ex_l.submit(travail, s) for s in lentes] + [ex_n.submit(travail, s) for s in normales]
        for f in futs:
            f.result()

    # Reessai SEUL (sans bancs voisins) des suites declarees sensibles a la charge qui ont echoue.
    for s in suites:
        r = resultats[s["nom"]]
        if s.get("reessais", 0) > 0 and not est_vert(r["verdict"]):
            premier = r["verdict"]
            r2 = executer(s, ctx, facteur_delai)
            r2["essais"] = 2
            if r2["verdict"] == "OK":
                r2["verdict"] = "OK*"
                r2["note"] = "1er essai en charge : %s (%s) ; 2e essai seul : OK" % (premier, r["note"])
            else:
                r2["note"] = "1er essai %s ; 2e essai seul %s %s" % (premier, r2["verdict"], r2["note"])
            r2["sortie"] = r["sortie"] + "\n--- 2e essai, seul ---\n" + r2["sortie"]
            r2["duree"] += r["duree"]
            if r["cpu"] is not None and r2["cpu"] is not None:
                r2["cpu"] += r["cpu"]
            resultats[s["nom"]] = r2
            if rappel:
                rappel(r2, len(suites), len(suites))
    return [resultats[s["nom"]] for s in suites]


# --------------------------------------------------------------------------------------------------
# Suites non listees
# --------------------------------------------------------------------------------------------------


def suites_non_listees(mod, data):
    """Fichiers de test du depot qu'aucune suite ne lance et qu'aucune exclusion ne justifie."""
    connus = set()
    for s in data.get("suites", []):
        for a in s["cmd"]:
            connus.add(a.replace("\\", "/"))
    ignorees = set(i["fichier"].replace("\\", "/") for i in data.get("ignorees", []))
    trouves = []
    motifs = (re.compile(r"^tests/[A-Za-z0-9_]+_test\.lua$"), re.compile(r"^tests/run\.lua$"),
              re.compile(r"^tools/.*/(test_[^/]+|mut_[^/]+|check_[^/]+)\.py$"),
              re.compile(r"^tests/datastage/mut_[^/]+\.py$"))
    for base, dirs, files in os.walk(mod):
        rel = os.path.relpath(base, mod).replace("\\", "/")
        dirs[:] = [d for d in dirs if d not in (".git", ".claude", "__pycache__", "cache", "out", "node_modules")]
        for fn in files:
            p = fn if rel == "." else rel + "/" + fn
            if any(m.match(p) for m in motifs):
                trouves.append(p)
    return sorted(p for p in trouves if p not in connus and p not in ignorees)


# --------------------------------------------------------------------------------------------------
# Table, journal, regeneration
# --------------------------------------------------------------------------------------------------


def attendu_texte(suite):
    t = ">=%d OK" % suite.get("ok_min", 1)
    if suite.get("echec_max", 0):
        t += ", <=%d ECHEC" % suite["echec_max"]
    return t


def table(suites, resultats):
    par_nom = {r["nom"]: r for r in resultats}
    lignes = [("suite", "OK", "ECHEC", "attendu", "duree", "cpu", "verdict")]
    for s in suites:
        r = par_nom[s["nom"]]
        lignes.append((s["nom"], "-" if r["ok"] is None else str(r["ok"]), "-" if r["echec"] is None else str(r["echec"]),
                       attendu_texte(s), "-" if r["verdict"] == "SAUT" else "%.0f s" % r["duree"],
                       "-" if r.get("cpu") is None else "%.1f s" % r["cpu"], r["verdict"]))
    largeurs = [max(len(l[i]) for l in lignes) for i in range(7)]
    sortie = []
    for k, l in enumerate(lignes):
        sortie.append("  ".join(l[i].ljust(largeurs[i]) if i in (0, 3, 6) else l[i].rjust(largeurs[i]) for i in range(7)).rstrip())
        if k == 0:
            sortie.append("  ".join("-" * w for w in largeurs))
    return "\n".join(sortie)


def estimation_repos(resultats, jobs):
    """Duree attendue sur un PC au repos : CPU cumulee des suites lancees repartie sur `jobs`, jamais moins que
    la plus longue. None si le CPU n'est pas mesure (hors Windows)."""
    cpus = [r["cpu"] for r in resultats if r.get("cpu") is not None]
    if not cpus:
        return None, None
    return max(sum(cpus) / max(1, jobs), max(cpus)), sum(cpus)


def resume(suites, resultats, avertissements, strict, duree_totale, jobs=4):
    n = len(resultats)
    ecarts = [r for r in resultats if not est_vert(r["verdict"])]
    sautees = sum(1 for r in resultats if r["verdict"] == "SAUT")
    etoiles = [r for r in resultats if r["verdict"] == "OK*"]
    lignes = []
    for r in ecarts:
        lignes.append("ECART  %-28s %s %s" % (r["nom"], r["verdict"], r["note"]))
    for r in etoiles:
        lignes.append("REMARQUE %-26s OK au 2e essai seul : %s" % (r["nom"], r["note"]))
    for a in avertissements:
        lignes.append("AVERTISSEMENT suite non listee : %s (l'ajouter a batterie_attendus.json ou a `ignorees`)" % a)
    code = verdict_global(resultats, avertissements, strict)
    lignes.append("")
    lignes.append("VERDICT GLOBAL : %s  (%d suite(s), %d vertes, %d en ecart, %d sautee(s), %.0f s)" % (
        "VERT" if code == 0 else "ECART", n, sum(1 for r in resultats if est_vert(r["verdict"]) and r["verdict"] != "SAUT"),
        len(ecarts), sautees, duree_totale))
    repos, cumul = estimation_repos(resultats, jobs)
    if repos is not None:
        lignes.append("CPU cumulee %.0f s ; estimation sur PC au repos avec %d travailleur(s) : environ %.0f s "
                      "(le temps ecoule ci-dessus depend de la charge des autres agents)" % (cumul, jobs, repos))
    return code, "\n".join(lignes)


def commit_court(mod):
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=mod, capture_output=True, text=True,
                              timeout=20).stdout.strip() or "?"
    except Exception:
        return "?"


def ecrire_journal(chemin, mod, argv, suites, resultats, texte_table, texte_resume, duree_totale):
    out = []
    out.append("Batterie hors jeu - %s - commit %s" % (datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), commit_court(mod)))
    out.append("Commande : batterie.py %s" % " ".join(argv))
    out.append("Duree totale : %.0f s" % duree_totale)
    out.append("")
    out.append(texte_table)
    out.append("")
    out.append(texte_resume)
    for r in resultats:
        if not est_vert(r["verdict"]) or r["verdict"] == "OK*":
            out.append("")
            out.append("=" * 100)
            out.append("%s : %s %s" % (r["nom"], r["verdict"], r["note"]))
            out.append("--- fin de la sortie (40 dernieres lignes) ---")
            out.extend(r["sortie"].rstrip().splitlines()[-40:])
    with open(chemin, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


def regenerer(chemin, data, suites_lancees, resultats, marge_delai=15.0):
    """Reecrit ok_min, duree_ref et duree_max d'apres les resultats ; ne touche pas une suite en ecart.
    Rend (mises_a_jour, refusees)."""
    par_nom = {r["nom"]: r for r in resultats}
    mises, refusees = [], []
    for s in data["suites"]:
        r = par_nom.get(s["nom"])
        if r is None or r["verdict"] == "SAUT":
            continue
        propre = r["verdict"] in ("OK", "OK*", "ECART") and r["echec"] == 0 and r["ok"] is not None and r["code"] == s.get("code_ok", 0)
        if not propre:
            refusees.append("%s (%s)" % (s["nom"], r["verdict"]))
            continue
        avant = (s.get("ok_min"), s.get("duree_max"))
        s["ok_min"] = r["ok"]
        s["echec_max"] = 0
        ref = r["cpu"] if r.get("cpu") is not None else r["duree"]  # le CPU ne depend pas de la charge du PC
        s["duree_ref"] = int(round(ref))
        s["duree_max"] = min(3600, max(300, int(-(-ref * marge_delai // 10)) * 10))
        if ref > 60:
            s["lent"] = True
        if avant != (s["ok_min"], s["duree_max"]):
            mises.append("%s : ok_min %s -> %s" % (s["nom"], avant[0], s["ok_min"]))
    with open(chemin, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return mises, refusees


# --------------------------------------------------------------------------------------------------
# Programme principal
# --------------------------------------------------------------------------------------------------


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    ici = os.path.dirname(os.path.abspath(__file__))
    mod_defaut = os.path.dirname(ici)
    p = argparse.ArgumentParser(description="Batterie hors jeu du mod.", add_help=False)
    p.add_argument("--aide", "-h", "--help", action="store_true")
    p.add_argument("--rapide", action="store_true", help="sans les suites marquees lentes (pvp_test...)")
    p.add_argument("--seulement", default="", help="noms de suites separes par des virgules")
    p.add_argument("--liste", action="store_true", help="liste les suites sans rien lancer")
    p.add_argument("--jobs", type=int, default=4)
    p.add_argument("--lents", type=int, default=1, help="emplacements supplementaires pour les suites lentes")
    p.add_argument("--facteur-delai", type=float, default=1.0, help="multiplie les durees max (PC charge)")
    p.add_argument("--regenerer-attendus", action="store_true")
    p.add_argument("--oui", action="store_true", help="confirme --regenerer-attendus (accord de l'integrateur)")
    p.add_argument("--strict", action="store_true", help="une suite non listee compte comme un ecart")
    p.add_argument("--attendus", default=os.path.join(ici, "batterie_attendus.json"))
    p.add_argument("--journal", default=os.path.join(ici, "batterie_derniere.txt"))
    p.add_argument("--mod", default=mod_defaut)
    p.add_argument("--racine", default=None)
    p.add_argument("--lua", default=None)
    a = p.parse_args(argv)
    if a.aide:
        print(AIDE)
        return 0
    try:
        data = charger_attendus(a.attendus)
    except (OSError, ValueError) as e:
        print("batterie : fichier d'attendus illisible (%s) : %s" % (a.attendus, e), file=sys.stderr)
        return 2
    toutes = data["suites"]
    choisies = toutes
    if a.seulement:
        voulus = [x.strip() for x in a.seulement.split(",") if x.strip()]
        inconnus = [x for x in voulus if x not in {s["nom"] for s in toutes}]
        if inconnus:
            print("batterie : suite(s) inconnue(s) : %s" % ", ".join(inconnus), file=sys.stderr)
            return 2
        choisies = [s for s in toutes if s["nom"] in voulus]
    if a.regenerer_attendus and not a.oui:
        print("batterie : --regenerer-attendus REECRIT les attendus d'apres les resultats actuels : a n'utiliser "
              "qu'avec l'accord de l'integrateur. Ajouter --oui pour confirmer.", file=sys.stderr)
        return 2
    if a.liste:
        for s in choisies:
            print("%-28s %-16s %s%s" % (s["nom"], attendu_texte(s), "lent " if s.get("lent") else "",
                                        " ".join(s["cmd"][:3])))
        return 0
    mod = os.path.abspath(a.mod)
    racine = racine_jeu(mod, a.racine)
    ctx = {"lua": trouver_lua(a.lua), "py": sys.executable, "mod": mod, "racine": racine or ""}
    if racine is None and any("{racine}" in x for s in choisies for x in s["cmd"]):
        print("batterie : racine du jeu introuvable (doc-html et data) ; --racine ou FO_RACINE", file=sys.stderr)
        return 2

    def rappel(r, k, n):
        print("[batterie] %2d/%d %-28s %-8s %5.0f s  %s" % (k, n, r["nom"], r["verdict"], r["duree"], r["note"]),
              file=sys.stderr, flush=True)

    t0 = time.time()
    resultats = lancer_tout(choisies, ctx, jobs=a.jobs, lents=a.lents, facteur_delai=a.facteur_delai,
                            rapide=a.rapide, rappel=rappel)
    duree_totale = time.time() - t0
    avertissements = [] if a.seulement else suites_non_listees(mod, data)
    texte_table = table(choisies, resultats)
    code, texte_resume = resume(choisies, resultats, avertissements, a.strict, duree_totale, a.jobs)
    print(texte_table)
    print()
    print(texte_resume)
    if a.regenerer_attendus:
        mises, refusees = regenerer(a.attendus, data, choisies, resultats)
        print()
        print("ATTENDUS REGENERES (%s) : %d changement(s)" % (a.attendus, len(mises)))
        for m in mises:
            print("  " + m)
        for r in refusees:
            print("  NON REGENERE (suite en ecart) : " + r)
    try:
        ecrire_journal(a.journal, mod, argv, choisies, resultats, texte_table, texte_resume, duree_totale)
    except OSError as e:
        print("batterie : journal non ecrit : %s" % e, file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
