# Banc en moteur réel AVEC FILE D'ATTENTE (orchestrateur, 27/10) : à utiliser par TOUS les agents à la place d'un appel
# direct à fo-autotest.bat ou fo-captures.bat.
#
# Pourquoi : le 25/10, cinq agents ont sondé le verrou fo-autotest.lock chacun à son rythme ; une chaîne de bancs le
# reprenait dès qu'il se libérait (45 min sans l'obtenir pour d'autres agents), et un banc a effacé fo-autotest\ AVANT
# que le précédent n'ait archivé ses journaux (le verrou était rendu par le .bat, l'archivage se faisait après).
#
# Ce que fait ce lanceur :
#   1. il prend un TICKET (fichier <racine>\fo-banc-file\<horloge>-<pid>.txt) : premier arrivé, premier servi ; les
#      tickets d'un processus mort sont retirés ;
#   2. quand son ticket est le plus ancien ET que le verrou est libre, il prend lui-même le verrou fo-autotest.lock (un
#      fichier owner.txt dit qui le tient) et lance le .bat avec FO_LOCK_HELD=1 ;
#   3. il ARCHIVE les journaux dans --out (journaux compressés, carte non copiée sauf --carte) AVANT de rendre le verrou ;
#   4. il rend le verrou, retire son ticket, affiche les lignes BILAN et rend le code du .bat.
# Un verrou VIDE est celui d'un appel direct au .bat (ancien usage) : on attend ; s'il reste vide plus de 20 min sans
# aucun factorio.exe de test, il est orphelin et retiré. Un verrou avec owner.txt d'un processus mort est retiré.
#
# Usage (depuis n'importe quel dossier ; racine du jeu trouvée en remontant depuis ce fichier) :
#   py -3.9 -B tools/autotest/banc.py --out <dossier> [--graine N] [--creation <source>] [--son] [--carte]
#          [--visuel "<FO_VISUAL_ARGS>"] [--qui <étiquette>] [--captures] -- <ticks> <scenario> <source du mod>
#   --captures : fo-captures.bat <scenario> <source> au lieu de fo-autotest.bat (ticks ignorés) ; archive aussi
#                fo-visual\write\script-output\fo-shots\ dans <out>\fo-shots.
#   --file : affiche la file et le verrou, sans rien lancer.
# Codes : ceux du .bat ; 9 = attente de plus de --attente-max secondes (défaut 6 h), rien n'a tourné.
import argparse
import ctypes
import gzip
import os
import shutil
import subprocess
import sys
import time

_kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)


def racine_du_jeu():
    if os.environ.get("FO_ROOT"):
        return os.environ["FO_ROOT"]
    d = os.path.dirname(os.path.abspath(__file__))
    while True:
        if os.path.isfile(os.path.join(d, "bin", "x64", "factorio.exe")):
            return d
        p = os.path.dirname(d)
        if p == d:
            raise SystemExit("[BANC] racine du jeu introuvable (bin\\x64\\factorio.exe) au-dessus de " + __file__)
        d = p


RACINE = racine_du_jeu()
FILE = os.path.join(RACINE, "fo-banc-file")
VERROU = os.path.join(RACINE, "fo-autotest.lock")
PROPRIO = os.path.join(VERROU, "owner.txt")


def vivant(pid):
    if pid <= 0:
        return False
    h = _kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not h:
        return False
    code = ctypes.c_ulong()
    ok = _kernel32.GetExitCodeProcess(h, ctypes.byref(code))
    _kernel32.CloseHandle(h)
    return bool(ok) and code.value == 259  # STILL_ACTIVE


def jeux_de_test():
    """Nombre de factorio.exe dont la ligne de commande vise un dossier de test (fo-autotest ou fo-visual)."""
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command",
                              "(Get-CimInstance Win32_Process -Filter \"Name='factorio.exe'\" | "
                              "? { $_.CommandLine -like '*fo-autotest*' -or $_.CommandLine -like '*fo-visual*' }).Count"],
                             capture_output=True, text=True, timeout=60).stdout.strip()
        return int(out or "0")
    except Exception:
        return 1  # dans le doute, on suppose qu'un jeu tourne


def tickets():
    os.makedirs(FILE, exist_ok=True)
    res = []
    for n in sorted(os.listdir(FILE)):
        if not n.endswith(".txt"):
            continue
        try:
            pid = int(n.split("-")[1].split(".")[0])
        except (IndexError, ValueError):
            continue
        if not vivant(pid):
            try:
                os.remove(os.path.join(FILE, n))
            except OSError:
                pass
            continue
        res.append(n)
    return res


def lire(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


def verrou_libre(etat):
    """Vrai si le verrou est libre ; retire un verrou orphelin. etat garde l'heure où l'on a vu un verrou vide."""
    if not os.path.isdir(VERROU):
        etat.pop("vide_depuis", None)
        return True
    txt = lire(PROPRIO)
    if txt:
        try:
            pid = int(txt.split()[0])
        except (ValueError, IndexError):
            pid = 0
        if not vivant(pid) and jeux_de_test() == 0:
            print(f"[BANC] verrou orphelin (processus {pid} mort, aucun jeu de test) : retiré", flush=True)
            shutil.rmtree(VERROU, ignore_errors=True)
            return True
        return False
    t = etat.setdefault("vide_depuis", time.time())
    if time.time() - t > 20 * 60 and jeux_de_test() == 0:
        print("[BANC] verrou vide depuis plus de 20 min sans jeu de test : orphelin, retiré", flush=True)
        shutil.rmtree(VERROU, ignore_errors=True)
        return True
    return False


def prendre_verrou(qui):
    try:
        os.mkdir(VERROU)
    except OSError:
        return False
    with open(PROPRIO, "w", encoding="utf-8") as f:
        f.write(f"{os.getpid()} {qui} {time.strftime('%d/%m %H:%M:%S')}\n")
    return True


def rendre_verrou():
    try:
        os.remove(PROPRIO)
    except OSError:
        pass
    try:
        os.rmdir(VERROU)
    except OSError:
        pass


def gz(src, dst):
    with open(src, "rb") as fi, gzip.open(dst, "wb") as fo:
        shutil.copyfileobj(fi, fo)


def archiver(out, carte, captures):
    os.makedirs(out, exist_ok=True)
    res = os.path.join(RACINE, "fo-autotest")
    for n in sorted(os.listdir(res)) if os.path.isdir(res) else []:
        p = os.path.join(res, n)
        if not os.path.isfile(p):
            continue
        if n.endswith(".zip") and not carte:
            continue
        if n in ("benchmark.log", "benchmark-stdout.txt", "create-stdout.txt") or (n == "create.log" and os.path.getsize(p) > 1_000_000):
            gz(p, os.path.join(out, n + ".gz"))
        else:
            shutil.copy2(p, os.path.join(out, n))
    if captures:
        shots = os.path.join(RACINE, "fo-visual", "write", "script-output", "fo-shots")
        if os.path.isdir(shots):
            shutil.copytree(shots, os.path.join(out, "fo-shots"), dirs_exist_ok=True)


def bilans(out):
    lignes = []
    for n in ("create.log", "benchmark.log", "create.log.gz", "benchmark.log.gz"):
        p = os.path.join(out, n)
        if not os.path.exists(p):
            continue
        op = gzip.open if n.endswith(".gz") else open
        with op(p, "rt", encoding="utf-8", errors="replace") as f:
            for l in f:
                if "BILAN" in l:
                    lignes.append(n.split(".")[0] + " : " + l.strip()[-200:])
    return lignes


def montrer_file():
    t = tickets()
    print(f"[BANC] racine {RACINE}")
    print(f"[BANC] verrou : {'libre' if not os.path.isdir(VERROU) else ('tenu par ' + (lire(PROPRIO) or '(vide : appel direct au .bat)'))}")
    for i, n in enumerate(t):
        print(f"[BANC] file {i + 1} : {n} {lire(os.path.join(FILE, n))}")


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--graine")
    ap.add_argument("--creation")
    ap.add_argument("--son", action="store_true")
    ap.add_argument("--carte", action="store_true")
    ap.add_argument("--captures", action="store_true")
    ap.add_argument("--visuel")
    ap.add_argument("--qui", default="")
    ap.add_argument("--file", action="store_true")
    ap.add_argument("--attente-max", type=float, default=6 * 3600)
    ap.add_argument("reste", nargs="*")
    # F307 : argparse refuse « --visuel "--no-atlas-cache" » (valeur qui commence par « -- ») ; on la recolle.
    argv = list(argv)
    for i in range(len(argv) - 1):
        if argv[i] == "--visuel":
            argv[i:i + 2] = ["--visuel=" + argv[i + 1]]
            break
    a = ap.parse_args(argv)
    if a.file:
        montrer_file()
        return 0
    if not a.out or len(a.reste) != 3:
        ap.error("il faut --out <dossier> et, après --, <ticks> <scenario> <source du mod>")
    ticks, scenario, source = a.reste
    out = os.path.abspath(a.out)
    env = dict(os.environ)
    for k in ("FO_MAP_SEED", "FO_CREATE_SRC", "FO_AUDIO", "FO_VISUAL_ARGS", "FO_LOCK_HELD"):
        env.pop(k, None)
    if a.graine:
        env["FO_MAP_SEED"] = a.graine
    if a.creation:
        env["FO_CREATE_SRC"] = a.creation
    if a.son:
        env["FO_AUDIO"] = "1"
    if a.visuel:
        env["FO_VISUAL_ARGS"] = a.visuel
    qui = (a.qui or os.path.basename(out)).replace("\n", " ")
    os.makedirs(FILE, exist_ok=True)
    moi = f"{time.time_ns():020d}-{os.getpid()}.txt"
    with open(os.path.join(FILE, moi), "w", encoding="utf-8") as f:
        f.write(f"{qui} : {scenario} {ticks} ({time.strftime('%d/%m %H:%M:%S')})\n")
    t0 = time.time()
    etat = {}
    dernier = 0
    try:
        while True:
            t = tickets()
            if t and t[0] == moi and verrou_libre(etat) and prendre_verrou(qui):
                break
            if time.time() - t0 > a.attente_max:
                print(f"[BANC] {qui} : attente de plus de {a.attente_max:.0f} s, abandon (rien n'a tourné)", flush=True)
                return 9
            if time.time() - dernier > 300:
                rang = t.index(moi) + 1 if moi in t else "?"
                print(f"[BANC] {qui} : en file, rang {rang} sur {len(t)}, attente {time.time() - t0:.0f} s", flush=True)
                dernier = time.time()
            time.sleep(2)
        attente = time.time() - t0
        env["FO_LOCK_HELD"] = "1"
        t1 = time.time()
        if a.captures:
            cmd = [os.path.join(RACINE, "fo-captures.bat"), scenario, source]
        else:
            cmd = [os.path.join(RACINE, "fo-autotest.bat"), "nopause", str(ticks), scenario, source]
        p = subprocess.run(cmd, env=env, cwd=RACINE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "banc-sortie.txt"), "wb") as f:
            f.write(p.stdout)
        archiver(out, a.carte, a.captures)
        with open(os.path.join(out, "banc.txt"), "w", encoding="utf-8") as f:
            f.write(f"{qui}\ncommande : {' '.join(cmd)}\ngraine {a.graine or '-'} ; creation {a.creation or '-'} ; "
                    f"son {a.son} ; visuel {a.visuel or '-'}\ncode {p.returncode} ; attente {attente:.0f} s ; "
                    f"banc {time.time() - t1:.0f} s ; fin {time.strftime('%d/%m/%Y %H:%M:%S')}\n")
    finally:
        if os.path.isfile(PROPRIO) and lire(PROPRIO).split()[:1] == [str(os.getpid())]:
            rendre_verrou()
        try:
            os.remove(os.path.join(FILE, moi))
        except OSError:
            pass
    print(f"[BANC] {qui} : code {p.returncode}, attente {attente:.0f} s, banc {time.time() - t1:.0f} s, archive {out}",
          flush=True)
    for l in bilans(out):
        print("[BANC]   " + l, flush=True)
    return p.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
