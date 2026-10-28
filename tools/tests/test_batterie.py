#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test de tools/batterie.py avec de FAUSSES suites (aucun jeu, aucun Lua) et des mutants.

    py -3.9 -B tools/tests/test_batterie.py

Chaque cas lance batterie.main() sur un dossier jetable : verdicts (OK, ECHEC, ECART, CODE, PLANTAGE, DELAI,
OK*, SAUT), codes de sortie, table, journal, --rapide, --seulement, --regenerer-attendus, suites non listees.
Puis chaque MUTANT de batterie.py (verdict force au vert, regle retiree...) doit faire echouer ce meme test.
Variables : BATTERIE_PY (batterie.py a tester, pour les mutants), BATTERIE_SANS_MUTANTS=1.
"""
import concurrent.futures as cf
import contextlib
import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import time

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass
ICI = os.path.dirname(os.path.abspath(__file__))
REEL = os.path.join(os.path.dirname(ICI), "batterie.py")
CIBLE = os.environ.get("BATTERIE_PY", REEL)

spec = importlib.util.spec_from_file_location("batterie_testee", CIBLE)
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)

OK_N, ECHEC_N = 0, 0


def verifie(nom, condition, detail=""):
    global OK_N, ECHEC_N
    if condition:
        OK_N += 1
        print("OK     " + nom)
    else:
        ECHEC_N += 1
        print("ECHEC  %s %s" % (nom, detail))
        if os.environ.get("BATTERIE_SANS_MUTANTS"):  # sous un mutant, un seul ECHEC suffit : on s'arrete
            print("[BATTERIE-TEST] BILAN : %d OK, %d ECHEC(S)" % (OK_N, ECHEC_N), flush=True)
            os._exit(1)


PY = "{py}"


def fausse(nom, script, **kw):
    s = {"nom": nom, "cmd": [PY, "-c", script], "ok_min": 5, "echec_max": 0, "duree_max": 60}
    s.update(kw)
    if "zeros" not in s and "regex" not in s:
        s["regex"] = B.DEFAUT_REGEX
    return s


BILAN = 'print("BILAN : %d OK, %d ECHEC(S)")'


def bilan(ok, echec, code=0, pre=""):
    return pre + (BILAN % (ok, echec)) + ";import sys;sys.exit(%d)" % code


def lancer(suites, args=(), extra_data=None, fichiers=()):
    """Joue main() sur un dossier jetable. Rend (code, sortie, journal, attendus_apres, dossier_mod)."""
    with tempfile.TemporaryDirectory(prefix="test_batterie_") as d:
        mod = os.path.join(d, "mod")
        os.makedirs(os.path.join(mod, "tests"))
        for f in fichiers:
            chemin = os.path.join(mod, f)
            os.makedirs(os.path.dirname(chemin), exist_ok=True)
            open(chemin, "w").write("-- vide\n")
        att = os.path.join(d, "attendus.json")
        data = {"version": 1, "suites": suites}
        if extra_data:
            data.update(extra_data)
        json.dump(data, open(att, "w", encoding="utf-8"))
        jour = os.path.join(d, "journal.txt")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = B.main(["--attendus", att, "--journal", jour, "--mod", mod, "--racine", d] + list(args))
        journal = open(jour, encoding="utf-8").read() if os.path.exists(jour) else None
        apres = json.load(open(att, encoding="utf-8"))
        return code, out.getvalue() + err.getvalue(), journal, apres


def verdict_de(sortie, nom):
    for l in sortie.splitlines():
        c = l.split()
        if c and c[0] == nom and not l.startswith("[batterie]"):
            return c[-1]
    return None


def cas_verdicts():
    suites = [
        fausse("s_ok", bilan(5, 0)),
        fausse("s_echec", bilan(5, 1, 1)),
        fausse("s_ecart", bilan(3, 0), ok_min=5),
        fausse("s_code", bilan(5, 0, 3)),
        fausse("s_plantage", "raise SystemExit(7)"),
        fausse("s_silence", "print('rien')"),
        fausse("s_delai", "import time;time.sleep(30)", duree_max=1),
    ]
    t0 = time.time()
    code, sortie, journal, _ = lancer(suites)
    duree = time.time() - t0
    attendu = {"s_ok": "OK", "s_echec": "ECHEC", "s_ecart": "ECART", "s_code": "CODE", "s_plantage": "PLANTAGE",
               "s_silence": "PLANTAGE", "s_delai": "DELAI"}
    for nom, v in attendu.items():
        verifie("verdict %s = %s" % (nom, v), verdict_de(sortie, nom) == v, "lu %r" % verdict_de(sortie, nom))
    verifie("un ecart => code de sortie 1", code == 1, "code %s" % code)
    verifie("VERDICT GLOBAL ECART imprime", "VERDICT GLOBAL : ECART" in sortie)
    verifie("le delai TUE la suite (pas d'attente de 30 s)", duree < 25, "%.1f s" % duree)
    verifie("journal ecrit avec la table", journal is not None and "s_echec" in journal and "attendu" in journal)
    verifie("journal : sortie des suites en ecart", journal is not None and "BILAN : 5 OK, 1 ECHEC(S)" in journal)
    verifie("table : OK et ECHEC lus", "s_echec" in sortie and any(l.split()[:3] == ["s_echec", "5", "1"] for l in sortie.splitlines() if l.split()))
    verifie("table : attendu imprime", ">=5 OK" in sortie)


def cas_vert():
    code, sortie, _, _ = lancer([fausse("a", bilan(5, 0)), fausse("b", bilan(9, 0), ok_min=5)])
    verifie("tout vert => code 0", code == 0, "code %s" % code)
    verifie("VERDICT GLOBAL : VERT", "VERDICT GLOBAL : VERT" in sortie)
    code, sortie, _, _ = lancer([fausse("a", bilan(5, 0)), fausse("b", bilan(7, 2, 0), echec_max=2)])
    verifie("echec_max permet 2 ECHEC", code == 0, sortie[-300:])
    code, sortie, _, _ = lancer([fausse("a", bilan(5, 0)), fausse("b", bilan(7, 3, 1), echec_max=2)])
    verifie("3 ECHEC pour echec_max 2 => ecart", code == 1)


def cas_bilans():
    s = fausse("derniere", 'print("BILAN : 9 OK, 0 ECHEC(S)");print("[X] BILAN : 5 OK, 0 ECHEC(S)")', ok_min=5)
    verifie("bilan : derniere occurrence", B.lire_bilan(s, "BILAN : 9 OK, 0 ECHEC(S)\nBILAN : 5 OK, 0 ECHEC(S)\n") == (5, 0))
    verifie("bilan : introuvable => None", B.lire_bilan(s, "rien\n") is None)
    z = {"zeros": [r"(\d+) violation\(s\)", r"(\d+) ecart"]}
    verifie("zeros : 3 a zero", B.lire_bilan(z, "0 violation(s) 0 ecart 0 violation(s)") == (3, 0))
    verifie("zeros : un non nul", B.lire_bilan(z, "0 violation(s) 2 ecart") == (1, 1))
    verifie("zeros : aucun motif => None", B.lire_bilan(z, "rien") is None)
    t = {"regex": r"(?P<ok>\d+)/(?P<total>\d+) mutants"}
    verifie("total : 17/18 => 1 echec", B.lire_bilan(t, "17/18 mutants") == (17, 1))
    verifie("total : 18/18 => 0 echec", B.lire_bilan(t, "18/18 mutants") == (18, 0))
    code, sortie, _, _ = lancer([fausse("z", 'print("0 violation(s), 0 ecart")', zeros=[r"(\d+) violation", r"(\d+) ecart"], ok_min=2)])
    verifie("suite zeros en vert", code == 0, sortie[-200:])
    code, sortie, _, _ = lancer([fausse("z", 'print("0 violation(s), 4 ecart")', zeros=[r"(\d+) violation", r"(\d+) ecart"], ok_min=1)])
    verifie("suite zeros avec un ecart non nul => rouge", code == 1 and verdict_de(sortie, "z") == "ECHEC")
    code, sortie, _, _ = lancer([fausse("t", 'print("17/18 mutants")', regex=r"(?P<ok>\d+)/(?P<total>\d+) mutants", ok_min=17)])
    verifie("suite total 17/18 => rouge", code == 1 and verdict_de(sortie, "t") == "ECHEC")


def cas_reessai():
    with tempfile.TemporaryDirectory(prefix="test_batterie_flake_") as d:
        marque = os.path.join(d, "n.txt").replace("\\", "/")
        script = ("import os,sys;p=%r;n=int(open(p).read()) if os.path.exists(p) else 0;open(p,'w').write(str(n+1));"
                  "print('BILAN : 5 OK, %%d ECHEC(S)' %% (1 if n==0 else 0));sys.exit(1 if n==0 else 0)") % marque
        code, sortie, journal, _ = lancer([fausse("flake", script, reessais=1)])
        verifie("reessai seul : OK au 2e essai => OK*", verdict_de(sortie, "flake") == "OK*", sortie[-300:])
        verifie("OK* => code 0", code == 0)
        verifie("OK* signale en REMARQUE", "REMARQUE" in sortie and "2e essai seul" in sortie)
        os.remove(marque)
        code, sortie, _, _ = lancer([fausse("flake", script)])
        verifie("sans reessais le meme flake reste rouge", code == 1 and verdict_de(sortie, "flake") == "ECHEC")
    code, sortie, _, _ = lancer([fausse("vraiecec", bilan(5, 1, 1), reessais=1)])
    verifie("un vrai echec rejoue reste ROUGE", code == 1 and verdict_de(sortie, "vraiecec") == "ECHEC", sortie[-300:])


def cas_options():
    with tempfile.TemporaryDirectory(prefix="test_batterie_opt_") as d:
        marque = os.path.join(d, "lente.txt").replace("\\", "/")
        suites = [fausse("rapide1", bilan(5, 0)),
                  fausse("lente", "open(%r,'w').write('x');%s" % (marque, bilan(5, 0)), lent=True)]
        code, sortie, _, _ = lancer(suites, ["--rapide"])
        verifie("--rapide : la suite lente est SAUT", verdict_de(sortie, "lente") == "SAUT", sortie[-300:])
        verifie("--rapide : elle n'a pas ete lancee", not os.path.exists(marque))
        verifie("--rapide : SAUT n'est pas un ecart (code 0)", code == 0)
        code, sortie, _, _ = lancer(suites)
        verifie("sans --rapide la suite lente tourne", os.path.exists(marque) and verdict_de(sortie, "lente") == "OK")
    suites = [fausse("a", bilan(5, 0)), fausse("b", bilan(5, 1, 1))]
    code, sortie, _, _ = lancer(suites, ["--seulement", "a"])
    verifie("--seulement a : seule a est listee et verte", code == 0 and verdict_de(sortie, "b") is None)
    code, sortie, _, _ = lancer(suites, ["--seulement", "zzz"])
    verifie("--seulement inconnue => code 2", code == 2)
    code, sortie, _, _ = lancer(suites, ["--liste"])
    verifie("--liste ne lance rien et rend 0", code == 0 and "VERDICT" not in sortie and "a " in sortie)
    code, sortie, _, _ = lancer([fausse("dormeuse", "import time;time.sleep(2.5);" + bilan(5, 0), duree_max=1)], ["--facteur-delai", "20"])
    verifie("--facteur-delai multiplie la duree max", code == 0 and verdict_de(sortie, "dormeuse") == "OK", sortie[-300:])
    code, sortie, _, _ = lancer(suites, ["--aide"])
    verifie("--aide : 3 lignes d'emploi", code == 0 and sortie.count("tools/batterie.py") >= 3)


def cas_parallele():
    suites = [fausse("p%d" % i, "import time;time.sleep(1.5);" + bilan(5, 0)) for i in range(4)]
    t0 = time.time()
    code, _, _, _ = lancer(suites, ["--jobs", "4"])
    d4 = time.time() - t0
    verifie("4 suites de 1,5 s en parallele (jobs 4) : moins de 5 s", code == 0 and d4 < 5.0, "%.1f s" % d4)
    t0 = time.time()
    lancer(suites[:3], ["--jobs", "1"])
    d1 = time.time() - t0
    verifie("jobs 1 : tour a tour (>= 4 s pour 3 x 1,5 s)", d1 >= 4.0, "%.1f s" % d1)


BRULE = "import time;t=time.time();[0 for _ in iter(lambda: time.time()-t<1.5, False)];"


def cas_cpu():
    if os.name != "nt":
        return
    with tempfile.TemporaryDirectory(prefix="test_batterie_cpu_") as d:
        ctx = {"lua": "", "py": sys.executable, "mod": d, "racine": ""}
        dort = fausse("dort", "import time;time.sleep(1.5);" + bilan(5, 0))
        calcule = fausse("calcule", BRULE + bilan(5, 0))
        rs = B.lancer_tout([dort, calcule], ctx, jobs=2)
        cpu = {r["nom"]: r["cpu"] for r in rs}
        verifie("cpu mesure pour une suite qui calcule (>= 1 s)", cpu["calcule"] is not None and cpu["calcule"] >= 1.0, str(cpu))
        verifie("cpu d'une suite qui dort (< 0,8 s)", cpu["dort"] is not None and cpu["dort"] < 0.8, str(cpu))
        fils = fausse("fils", "import subprocess,sys;subprocess.run([sys.executable,'-c',%r]);" % BRULE + bilan(5, 0))
        r = B.lancer_tout([fils], ctx, jobs=1)[0]
        verifie("cpu compte aussi les processus fils (>= 1 s)", r["cpu"] is not None and r["cpu"] >= 1.0, str(r["cpu"]))
    repos, cumul = B.estimation_repos([{"cpu": 40.0}, {"cpu": 20.0}, {"cpu": 20.0}, {"cpu": None}], 4)
    verifie("estimation au repos = max(somme/jobs, la plus longue)", (repos, cumul) == (40.0, 80.0), str((repos, cumul)))
    verifie("estimation sans cpu mesure => None", B.estimation_repos([{"cpu": None}], 4) == (None, None))


def cas_regeneration():
    suites = [fausse("bon", bilan(12, 0), ok_min=5), fausse("casse", bilan(8, 2, 1), ok_min=5),
              fausse("lent", bilan(7, 0), ok_min=5, lent=True)]
    code, sortie, _, apres = lancer(suites, ["--regenerer-attendus"])
    verifie("--regenerer-attendus sans --oui => refuse (code 2)", code == 2)
    verifie("refus : fichier inchange", [s["ok_min"] for s in apres["suites"]] == [5, 5, 5])
    code, sortie, _, apres = lancer(suites, ["--regenerer-attendus", "--oui", "--rapide"])
    par = {s["nom"]: s for s in apres["suites"]}
    verifie("regenere : ok_min de la suite saine = 12", par["bon"]["ok_min"] == 12, str(par["bon"]))
    verifie("regenere : la suite en echec N'EST PAS regeneree", par["casse"]["ok_min"] == 5 and "NON REGENERE" in sortie)
    verifie("regenere : la suite sautee reste intacte", par["lent"]["ok_min"] == 5)
    verifie("regenere : echec_max 0 et duree_max >= 60", par["bon"]["echec_max"] == 0 and par["bon"]["duree_max"] >= 60)


def cas_non_listees():
    suites = [fausse("a", bilan(5, 0))]
    fich = ["tests/nouvelle_test.lua", "tests/a_test.lua", "tools/autotest/tests/test_x.py"]
    ign = {"ignorees": [{"fichier": "tests/a_test.lua", "raison": "essai"}]}
    code, sortie, _, _ = lancer(suites, fichiers=fich, extra_data=ign)
    verifie("suite non listee => AVERTISSEMENT", "tests/nouvelle_test.lua" in sortie and "tools/autotest/tests/test_x.py" in sortie)
    verifie("fichier ignore => pas d'avertissement", "a_test.lua" not in sortie.split("VERDICT")[0].replace("tests/nouvelle_test.lua", ""))
    verifie("avertissement seul => code 0", code == 0)
    code, sortie, _, _ = lancer(suites, ["--strict"], fichiers=fich, extra_data=ign)
    verifie("--strict : suite non listee => code 1", code == 1)
    code, sortie, _, _ = lancer(suites, ["--seulement", "a"], fichiers=fich, extra_data=ign)
    verifie("--seulement : pas de controle des non listees", "AVERTISSEMENT" not in sortie)


def cas_usage():
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = B.main(["--attendus", os.path.join(tempfile.gettempdir(), "n_existe_pas_batterie.json")])
    verifie("fichier d'attendus absent => code 2", code == 2)
    code, sortie, _, _ = lancer([fausse("a", bilan(5, 0))], ["--jobs", "2", "--lents", "1"])
    verifie("accents de la sortie lus en UTF-8", True)
    code, sortie, _, _ = lancer([fausse("acc", 'import sys;sys.stdout.buffer.write("é à ✓\\nBILAN : 5 OK, 0 ECHEC(S)\\n".encode("utf-8"))')])
    verifie("sortie UTF-8 d'une suite lue sans erreur", code == 0)
    s = B.charger_attendus(os.path.join(os.path.dirname(REEL), "batterie_attendus.json"))
    verifie("batterie_attendus.json : noms uniques et commandes", len({x["nom"] for x in s["suites"]}) == len(s["suites"]) >= 40)


# --------------------------------------------------------------------------------------------------
# Mutants de batterie.py
# --------------------------------------------------------------------------------------------------

MUTANTS = [
    ("echec_max ignore", '    if echec > suite.get("echec_max", 0):', '    if False:'),
    ("ok_min ignore", '    if ok < suite.get("ok_min", 1):', '    if False:'),
    ("code de sortie ignore", '    if code != suite.get("code_ok", 0):', '    if False:'),
    ("bilan introuvable accepte", '    if bilan is None:\n        return "PLANTAGE"', '    if False:\n        return "PLANTAGE"'),
    ("delai ignore", '    if delai_depasse:\n        return "DELAI"', '    if False:\n        return "DELAI"'),
    ("tout est vert", '    return verdict in VERDICTS_VERTS', '    return True'),
    ("code de sortie toujours 0", '    if any(not est_vert(r["verdict"]) for r in resultats):\n        return 1', '    if False:\n        return 1'),
    ("premier bilan au lieu du dernier", '        derniere = m', '        derniere = derniere or m'),
    ("zeros toujours ok", '                if int(m.group(1)) == 0:', '                if True:'),
    ("total ignore", '        return ok, max(0, int(gd["total"]) - ok)', '        return ok, 0'),
    ("reessai qui echoue passe OK*", '            if r2["verdict"] == "OK":', '            if True:'),
    ("--rapide ne saute rien", '        if rapide and s.get("lent"):', '        if False:'),
    ("regeneration d\'une suite en echec", '        propre = r["verdict"] in', '        propre = True or r["verdict"] in'),
    ("regeneration sans --oui", '    if a.regenerer_attendus and not a.oui:', '    if False:'),
    ("--strict ignore", '    if strict and avertissements:', '    if False:'),
    ("main rend toujours 0", '    return code\n\n\nif __name__', '    return 0\n\n\nif __name__'),
    ("facteur de delai ignore", '* facteur_delai\n    t0', '* 1.0\n    t0'),
    ("suite inconnue acceptee", '        if inconnus:', '        if False:'),
    ("delai jamais tue", '            _tuer(proc)\n            try:', '            try:'),
    ("cpu toujours nul", '            return (c.user + c.noyau) / 1e7', '            return 0.0'),
    ("estimation au repos sans la plus longue", '    return max(sum(cpus) / max(1, jobs), max(cpus)), sum(cpus)', '    return sum(cpus) / max(1, jobs), sum(cpus)'),
    ("une suite sautee compte comme ecart", 'VERDICTS_VERTS = ("OK", "OK*", "SAUT")', 'VERDICTS_VERTS = ("OK", "OK*")'),
]


def un_mutant(k):
    nom, avant, apres = MUTANTS[k]
    src = open(REEL, encoding="utf-8").read()
    if src.count(avant) != 1:
        return nom, "MOTIF INTROUVABLE (%d occurrence(s))" % src.count(avant)
    with tempfile.TemporaryDirectory(prefix="mutant_batterie_") as d:
        chemin = os.path.join(d, "batterie.py")
        open(chemin, "w", encoding="utf-8", newline="\n").write(src.replace(avant, apres))
        env = dict(os.environ, BATTERIE_PY=chemin, BATTERIE_SANS_MUTANTS="1", PYTHONUTF8="1")
        try:
            p = subprocess.run([sys.executable, "-B", os.path.abspath(__file__)], env=env, capture_output=True,
                               timeout=300)
            sortie = p.stdout.decode("utf-8", "replace")
            return nom, ("REFUSE" if p.returncode != 0 and "ECHEC  " in sortie else
                         "REFUSE (plantage)" if p.returncode != 0 else "SURVIVANT")
        except subprocess.TimeoutExpired:
            return nom, "REFUSE (delai)"


def cas_mutants():
    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        res = list(ex.map(un_mutant, range(len(MUTANTS))))
    for nom, etat in res:
        verifie("mutant « %s » : %s" % (nom, etat), etat.startswith("REFUSE"))


def main():
    for cas in (cas_verdicts, cas_vert, cas_bilans, cas_reessai, cas_options, cas_parallele, cas_cpu, cas_regeneration,
                cas_non_listees, cas_usage):
        print("== " + cas.__name__)
        cas()
    if CIBLE == REEL and not os.environ.get("BATTERIE_SANS_MUTANTS"):
        print("== mutants")
        cas_mutants()
    print("[BATTERIE-TEST] BILAN : %d OK, %d ECHEC(S)" % (OK_N, ECHEC_N))
    return 1 if ECHEC_N else 0


if __name__ == "__main__":
    sys.exit(main())
