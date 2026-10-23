"""Test de la garde de disque de tools/render/with_render_lock.py (lot A3, reste du lot A0). Python 3.9.

    py -3.9 tools/render/tests/test_garde_disque.py

Les verrous sont pris dans un dossier JETABLE (FO_RENDER_LOCK_DIR) : le test ne prend aucune place du vrai verrou de
rendu et ne lance pas Blender (la commande est un petit Python qui écrit un fichier témoin).
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
LOCK = os.path.normpath(os.path.join(HERE, "..", "with_render_lock.py"))
sys.path.insert(0, os.path.dirname(LOCK))
import with_render_lock as W  # noqa: E402


def lancer(tmp, opts, env_extra=None):
    temoin = os.path.join(tmp, "temoin.txt")
    if os.path.exists(temoin):
        os.remove(temoin)
    env = dict(os.environ, FO_RENDER_LOCK_DIR=os.path.join(tmp, "verrous"), PYTHONIOENCODING="utf-8")
    env.pop("FO_RENDER_MIN_LIBRE_GO", None)
    env.update(env_extra or {})
    os.makedirs(env["FO_RENDER_LOCK_DIR"], exist_ok=True)
    cmd = [sys.executable, LOCK] + opts + ["--", sys.executable, "-c",
                                           "import sys; open(sys.argv[1], 'w').write('ok')", temoin]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    reste = os.listdir(env["FO_RENDER_LOCK_DIR"])
    return p.returncode, p.stdout.decode("utf-8", "replace"), os.path.exists(temoin), reste


def main():
    tmp = tempfile.mkdtemp(prefix="fo-garde-")
    ok = ko = 0

    def verifie(nom, cond, detail=""):
        nonlocal ok, ko
        print("%-6s %s%s" % ("OK" if cond else "ECHEC", nom, (" : " + detail) if (detail and not cond) else ""))
        ok, ko = ok + bool(cond), ko + (not cond)

    try:
        libre = shutil.disk_usage(tmp).free / 1e9
        rc, out, fait, reste = lancer(tmp, ["--min-libre-go", "1000000", "--disque", tmp])
        verifie("seuil impossible (1 000 000 Go) : refus, code 4", rc == 4, "code %d" % rc)
        verifie("refus : commande NON lancée", not fait)
        verifie("refus : message clair (REFUS, Go libres, seuil, option)",
                "REFUS" in out and "Go libres" in out and "--min-libre-go" in out, out.strip())
        verifie("refus : place du verrou rendue", not reste, str(reste))
        rc, out, fait, reste = lancer(tmp, ["--min-libre-go", "0", "--disque", tmp])
        verifie("seuil 0 (garde coupée) : commande lancée, code 0", rc == 0 and fait, "code %d" % rc)
        rc, out, fait, reste = lancer(tmp, ["--disque", tmp])
        attendu = libre >= 1.0
        verifie("seuil par défaut 1 Go (%.1f Go libres) : %s" % (libre, "lancée" if attendu else "refusée"),
                (rc == 0 and fait) if attendu else (rc == 4 and not fait), "code %d" % rc)
        rc, out, fait, reste = lancer(tmp, ["--min-libre-go", "0.001", "--disque",
                                            os.path.join(tmp, "pas", "encore", "cree")])
        verifie("chemin pas encore créé : parent existant mesuré, commande lancée", rc == 0 and fait, out.strip())
        rc, out, fait, reste = lancer(tmp, ["--disque", tmp], {"FO_RENDER_MIN_LIBRE_GO": "1000000"})
        verifie("variable FO_RENDER_MIN_LIBRE_GO=1000000 : refus, code 4", rc == 4 and not fait, "code %d" % rc)
        rc, out, fait, reste = lancer(tmp, ["--disque", tmp, "--min-libre-go", "0.001", "--disque", tmp, "--min-libre-go",
                                            "1000000"])
        verifie("dernière valeur de --min-libre-go retenue (1 000 000) : refus", rc == 4 and not fait, "code %d" % rc)
        verifie("garde_disque : None sous le seuil libre", W.garde_disque([tmp], 0.001) is None)
        m = W.garde_disque([tmp], 1e6)
        verifie("garde_disque : message qui nomme le disque", m is not None and os.path.abspath(tmp) in m, str(m))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print("BILAN : %d OK, %d ECHEC(S)" % (ok, ko))
    return 0 if ko == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
