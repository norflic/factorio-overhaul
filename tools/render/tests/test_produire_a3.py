"""Banc hors jeu de produire_a3.py (lot A3, correction M-1 de la vérification). Python 3.9, sans Blender.

    py -3.9 tools/render/tests/test_produire_a3.py [--script <produire_a3.py à tester>] [--garder]

Le banc ne lance JAMAIS Blender ni le verrou de rendu : produire_a3.py reçoit, par --rendre, un FAUX rendre.py écrit
dans un dossier jetable, qui recopie des têtes déjà produites et contrôlées par le pilote du lot A3
(fo-logs/2026-10-24_A3/sprites/e05-tete-d01 à d04, lues seulement) puis les abîme selon FAUX_MODE (la 1re tête de
chaque paquet). Les sorties, le journal et STOP sont dans le dossier jetable. Les masques de référence du contrôle
(fo-logs/2026-10-24_A3/masques/m16, bouchon/rampe80) sont lus, jamais écrits.

Ce qui est prouvé, pour chaque panne : aucun fil n'est tué (pas d'« Exception in thread »), la panne est ÉCRITE
(controle.json en échec, ligne du journal), les autres têtes du paquet et les paquets suivants sont quand même rendus
et contrôlés, et le code de sortie n'est 0 que si toutes les têtes du lancement sont faites et contrôlées.
--script permet de rejouer le banc sur une autre version du script (contre-épreuve : la version 16121ec échoue).
"""
import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.normpath(os.path.join(HERE, "..", "pieces", "levels", "gun_e", "produire_a3.py"))
A3 = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-24_A3"
SOURCE = os.path.join(A3, "sprites")
TETES = ["e05-tete-d%02d" % k for k in (1, 2, 3, 4)]

FAUX = r'''"""Faux rendre.py du banc test_produire_a3.py : recopie des têtes du pilote, puis les abîme (FAUX_MODE)."""
import json, os, shutil, sys
a = sys.argv[1:]
out = a[a.index("--out") + 1]
noms = a[a.index("--only") + 1].split(",")
src = os.environ["FAUX_SOURCE"]
mode = os.environ.get("FAUX_MODE", "ok")
if mode == "code3":
    print("faux rendu : Error simulée")
    sys.exit(3)
for i, n in enumerate(noms):
    d = os.path.join(out, n)
    os.makedirs(d, exist_ok=True)
    for f in sorted(os.listdir(os.path.join(src, n))):
        if f != "controle.json":
            shutil.copyfile(os.path.join(src, n, f), os.path.join(d, f))
    if i:
        continue
    sp = os.path.join(d, "spec.json")
    if mode == "nochecks":
        s = json.load(open(sp, encoding="utf-8")); del s["checks"]
        json.dump(s, open(sp, "w", encoding="utf-8"))
    elif mode == "sanslr":
        s = json.load(open(sp, encoding="utf-8")); del s["layers"]["main"]["lr"]
        json.dump(s, open(sp, "w", encoding="utf-8"))
    elif mode == "sansseconds":
        s = json.load(open(sp, encoding="utf-8")); del s["seconds"]
        json.dump(s, open(sp, "w", encoding="utf-8"))
    elif mode == "specasse":
        t = open(sp, "rb").read(); open(sp, "wb").write(t[:len(t) // 2])
    elif mode == "sansspec":
        os.remove(sp)
    elif mode == "pngcasse":
        open(os.path.join(d, "hr-gune-%s-glow.png" % n), "wb").write(b"pas un PNG")
    elif mode == "pngtronque":
        p = os.path.join(d, "hr-gune-%s-main.png" % n); t = open(p, "rb").read(); open(p, "wb").write(t[:len(t) // 3])
print("faux rendu : %d tête(s) recopiée(s), mode %s" % (len(noms), mode))
'''


def lire_controle(sortie, n):
    p = os.path.join(sortie, n, "controle.json")
    if not os.path.exists(p):
        return None
    return json.load(open(p, encoding="utf-8"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--script", default=SCRIPT)
    ap.add_argument("--garder", action="store_true", help="garder le dossier jetable")
    args = ap.parse_args()
    for n in TETES:
        if not os.path.exists(os.path.join(SOURCE, n, "spec.json")):
            print("ECHEC  source du faux rendu absente : %s (pilote du lot A3, à GARDER)" % os.path.join(SOURCE, n))
            return 1
    tmp = tempfile.mkdtemp(prefix="fo-produire-a3-")
    faux = os.path.join(tmp, "faux_rendre.py")
    open(faux, "w", encoding="utf-8").write(FAUX)
    ok = ko = 0

    def verifie(nom, cond, detail=""):
        nonlocal ok, ko
        print("%-6s %s%s" % ("OK" if cond else "ECHEC", nom, (" : " + str(detail)[:300]) if (detail and not cond) else ""),
              flush=True)
        ok, ko = ok + bool(cond), ko + (not cond)

    def opts(cas, places=1):
        d = os.path.join(tmp, cas)
        return d, ["--ages", "5", "--dirs", "1-4", "--per", "2", "--places", str(places),
                   "--sortie", os.path.join(d, "sprites"), "--journal", os.path.join(d, "production.log"),
                   "--stop", os.path.join(d, "STOP"), "--rendre", faux]

    def lancer(cas, mode, places=1, extra=()):
        d, o = opts(cas, places)
        env = dict(os.environ, FAUX_SOURCE=SOURCE, FAUX_MODE=mode, PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
        p = subprocess.run([sys.executable, args.script] + o + list(extra), stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, env=env)
        jr = os.path.join(d, "production.log")
        return (p.returncode, p.stdout.decode("utf-8", "replace"), os.path.join(d, "sprites"),
                open(jr, encoding="utf-8").read() if os.path.exists(jr) else "")

    def sans_fil_tue(cas, out):
        verifie("%s : aucun fil tué (pas d'« Exception in thread », pas de trace hors journal)" % cas,
                "Exception in thread" not in out and "Traceback (most recent call last)" not in out, out[-600:])

    try:
        # 1. témoin sain, 2 places
        rc, out, so, jr = lancer("ok", "ok", places=2)
        cs = [lire_controle(so, n) for n in TETES]
        verifie("témoin sain (2 places) : code 0", rc == 0, "code %d ; %s" % (rc, out[-400:]))
        verifie("témoin sain : 4 controle.json « ok »", all(c and c["ok"] for c in cs))
        verifie("témoin sain : « manquent 0 sur 4 »", "manquent 0 sur 4" in jr, jr[-400:])
        sans_fil_tue("témoin", out)
        # 2. pannes de lecture dans controler() : la 1re tête de chaque paquet (d01, d03) est abîmée
        pannes = [("nochecks", "checks.largest_hole_px"), ("pngcasse", "PNG illisible"),
                  ("pngtronque", "PNG illisible"), ("specasse", "spec.json illisible"),
                  ("sanslr", "contrôle impossible"), ("sansseconds", "seconds")]
        for mode, motif in pannes:
            rc, out, so, jr = lancer(mode, mode)
            cs = {n: lire_controle(so, n) for n in TETES}
            verifie("%s : code 1 (pas 0)" % mode, rc == 1, "code %d" % rc)
            sans_fil_tue(mode, out)
            abimees = [cs[n] for n in ("e05-tete-d01", "e05-tete-d03")]
            verifie("%s : d01 et d03 contrôlées EN ÉCHEC, motif « %s » écrit" % (mode, motif),
                    all(c and not c["ok"] and any(motif in x for x in c["echecs"]) for c in abimees),
                    [c and c["echecs"] for c in abimees])
            verifie("%s : d02 et d04 quand même contrôlées « ok »" % mode,
                    all(cs[n] and cs[n]["ok"] for n in ("e05-tete-d02", "e05-tete-d04")))
            verifie("%s : journal « CONTROLE EN ECHEC » ×2 et « erreurs 2 »" % mode,
                    jr.count("CONTROLE EN ECHEC") == 2 and "erreurs 2 ;" in jr, jr[-500:])
            if mode == "specasse":
                # m-5 : --controle-seul sur un spec.json corrompu
                d, o = opts(mode)
                p = subprocess.run([sys.executable, args.script, "--controle-seul"] + o, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, env=dict(os.environ, PYTHONIOENCODING="utf-8"))
                t = p.stdout.decode("utf-8", "replace")
                verifie("specasse --controle-seul : code 1, sans trace, « 2 têtes contrôlées OK, 2 en échec »",
                        p.returncode == 1 and "Traceback" not in t and "2 têtes contrôlées OK, 2 en échec" in t, t[-400:])
                p = subprocess.run([sys.executable, args.script, "--dry-run"] + o, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, env=dict(os.environ, PYTHONIOENCODING="utf-8"))
                t = p.stdout.decode("utf-8", "replace")
                verifie("specasse --dry-run : « reste : 2 », d01 et d03 « incomplète »",
                        p.returncode == 0 and "reste : 2" in t and "e05-tete-d01 : incomplète" in t
                        and "e05-tete-d03 : incomplète" in t, t[-400:])
        # 3. spec.json absent après le rendu
        rc, out, so, jr = lancer("sansspec", "sansspec")
        verifie("sansspec : code 1, « AUCUN spec.json » ×2, d02 et d04 « ok »",
                rc == 1 and jr.count("AUCUN spec.json") == 2
                and all((lire_controle(so, n) or {}).get("ok") for n in ("e05-tete-d02", "e05-tete-d04")),
                "code %d ; %s" % (rc, jr[-400:]))
        # 4. rendu en échec (code 3) : les 2 paquets sont tentés, code 1
        rc, out, so, jr = lancer("code3", "code3")
        verifie("rendu en échec : code 1, 2 paquets en ECHEC, aucune tête faite",
                rc == 1 and jr.count("paquet en ECHEC") == 2 and "manquent 4 sur 4" in jr, "code %d ; %s" % (rc, jr[-400:]))
        # 5. reprise après la panne : relancer en mode sain ne refait que d01 et d03
        rc, out, so, jr = lancer("nochecks", "ok")
        verifie("reprise après nochecks : code 0, seules d01 et d03 refaites (2 têtes, 1 paquet chacune)",
                rc == 0 and "4 têtes cibles, 2 faites et contrôlées, 2 à faire" in jr, "code %d ; %s" % (rc, jr[-500:]))
        # 6. pannes injectées en mémoire (le script importé, fonctions remplacées), dans ce processus
        spec = importlib.util.spec_from_file_location("produire_a3_sous_test", args.script)
        P = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(P)

        def en_memoire(cas, prepare):
            d, o = opts(cas)
            os.environ.update(FAUX_SOURCE=SOURCE, FAUX_MODE="ok")
            sauve = {k: getattr(P, k) for k in ("controler", "estimation")}
            sauve_run = P.subprocess.run
            vus = []
            ancien = threading.excepthook
            threading.excepthook = lambda x: vus.append(x.exc_type.__name__)
            argv = sys.argv
            try:
                prepare(P)
                sys.argv = ["produire_a3.py"] + o
                try:
                    rc = P.main()
                except Exception as ex:
                    rc = "exception %s" % type(ex).__name__
            finally:
                sys.argv = argv
                threading.excepthook = ancien
                for k, v in sauve.items():
                    setattr(P, k, v)
                P.subprocess.run = sauve_run
            jr = os.path.join(d, "production.log")
            return rc, vus, os.path.join(d, "sprites"), open(jr, encoding="utf-8").read() if os.path.exists(jr) else ""

        # 6a. exception dans le paquet (lancement du rendu) : le 1er paquet est en erreur, le 2e est quand même fait
        def run_qui_casse(P):
            orig = P.subprocess.run
            n = [0]

            def run(*a, **k):
                n[0] += 1
                if n[0] == 1:
                    raise OSError("panne simulée au lancement du rendu")
                return orig(*a, **k)
            P.subprocess.run = run
        rc, vus, so, jr = en_memoire("exc-paquet", run_qui_casse)
        verifie("exception au lancement du 1er paquet : code 1, fil vivant, 2e paquet fait (d03, d04 « ok »)",
                rc == 1 and not vus and "EXCEPTION pendant le paquet" in jr
                and all((lire_controle(so, n) or {}).get("ok") for n in ("e05-tete-d03", "e05-tete-d04")),
                "code %s ; fils tués %s ; %s" % (rc, vus, jr[-400:]))

        # 6b. controler() qui lève (au-delà du filet) : erreur comptée, les autres têtes contrôlées
        def ctl_qui_casse(P):
            orig = P.controler

            def ctl(sortie, e, k, *a):
                if k == 1:
                    raise RuntimeError("panne simulée du contrôle")
                return orig(sortie, e, k, *a)
            P.controler = ctl
        rc, vus, so, jr = en_memoire("exc-controle", ctl_qui_casse)
        verifie("controler() qui lève sur d01 : code 1, fil vivant, d02 à d04 « ok »",
                rc == 1 and not vus and "EXCEPTION au contrôle" in jr
                and all((lire_controle(so, n) or {}).get("ok") for n in TETES[1:]),
                "code %s ; fils tués %s ; %s" % (rc, vus, jr[-400:]))

        # 6c. contrôle qui dit « ok » sans écrire controle.json : têtes non faites SANS erreur enregistrée → code 1
        def ctl_menteur(P):
            P.controler = lambda sortie, e, k, *a: {"ok": True, "echecs": [], "trous": {"plus_grand": 0, "verdict": "OK"},
                                                    "cadre": None, "seconds": 10.0}
        rc, vus, so, jr = en_memoire("menteur", ctl_menteur)
        verifie("têtes non faites sans erreur enregistrée : code 1 (« FIN EN ERREUR »), pas 0",
                rc == 1 and "FIN EN ERREUR" in jr and "erreurs 0 ;" in jr, "code %s ; %s" % (rc, jr[-400:]))

        # 6d. PROGRESSION qui lève : incident écrit, têtes faites, code 0
        def estim_casse(P):
            def est(*a, **k):
                raise ZeroDivisionError("panne simulée de l'estimation")
            P.estimation = est
        rc, vus, so, jr = en_memoire("exc-progression", estim_casse)
        verifie("PROGRESSION qui lève : code 0, 4 têtes faites, « PROGRESSION impossible » ×2, incidents 2",
                rc == 0 and not vus and jr.count("PROGRESSION impossible") == 2 and "incidents de journal 2" in jr
                and all((lire_controle(so, n) or {}).get("ok") for n in TETES), "code %s ; fils tués %s ; %s" % (
                    rc, vus, jr[-400:]))
    finally:
        if args.garder:
            print("dossier jetable gardé : %s" % tmp)
        else:
            shutil.rmtree(tmp, ignore_errors=True)
    print("BILAN test_produire_a3 : %d OK, %d ECHEC(S)" % (ok, ko))
    return 0 if not ko else 1


if __name__ == "__main__":
    sys.exit(main())
