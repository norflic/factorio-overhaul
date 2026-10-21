#!/usr/bin/env python3
r"""
Pilote de la session graphique de test (lot P1, H-T1), appelé par fo-visual.bat : AUCUNE intervention humaine.

  1. Prépare fo-visual\ (dossier SÉPARÉ : config, mods, écriture) à partir du dernier banc fo-autotest\.
  2. Lance Factorio AVEC images sur la carte de ce banc, en mode --benchmark-graphics (le jeu s'arrête SEUL
     au bout de N ticks : aucune session ne peut rester ouverte, même si ce pilote est tué), fenêtre réduite
     sans prendre le focus, son coupé, priorité normale, cache des atlas de sprites activé (fenêtre réduite :
     Windows met le jeu sur les cœurs E et le chargement des sprites prend 35 à 140 s ; avec le cache, 5 s ;
     mesuré le 21/10).
  3. Attend le marqueur de fin du mod de test (shots.lua : done.txt, écrit après
     set_wait_for_screenshots_to_finish), avec un délai maximal ; échoue tôt si le jeu signale une erreur
     ou s'arrête sans marqueur (budget de ticks trop court).
  4. Revérifie chaque capture (décodage complet), puis ferme UNIQUEMENT le processus de test (son PID ;
     puis, par sécurité, tout factorio.exe dont la ligne de commande contient le dossier fo-visual) et
     vérifie qu'il n'en reste aucun. Les autres factorio.exe (partie du Directeur Créatif) ne sont jamais
     touchés.
  5. Écrit index.txt, planche-NN.png (gallery.py) et session.txt dans fo-shots\.

Usage : python visual_session.py --root <racine du jeu> [--window min|small|normal] [--timeout 900]
                                 [--mode benchmark|load] [--ticks N] [--priority normal|below]
                                 [--no-atlas-cache] [--pcores]
  --ticks : budget du mode benchmark ; par défaut 7200 (2 min de jeu) pour content, vitrine et les
            scénarios greffés, 40000 pour les scénarios de guerre (10 min de mise en route à ×8).
Codes : 0 succès ; 1 préparation ; 3 délai dépassé ; 4 captures manquantes ou illisibles ;
        5 processus de test encore présent ; 6 vitrine : entité refusée ; 7 erreur du jeu ou session
        fermée avant la fin.
"""
import argparse
import ctypes
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from ctypes import wintypes

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gallery  # noqa: E402

SW_SHOWNORMAL, SW_SHOWNOACTIVATE, SW_SHOWMINNOACTIVE = 1, 4, 7
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
SMALL_SIZE = "640x360"

# Erreurs qui arrêtent la partie (un script qui plante renvoie au menu : le marqueur ne viendrait jamais).
FATAL = re.compile(r"non-recoverable error|Error while running event|Exception at tick|Failed to load|"
                   r"Error ScriptRaised|Unexpected error", re.I)

user32 = ctypes.WinDLL("user32", use_last_error=True)
ENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)


def pid_of_window(hwnd):
    p = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(p))
    return p.value


def visible_windows(pid):
    """Fenêtres visibles du processus : [(iconique, largeur, hauteur)]."""
    found = []

    def cb(hwnd, _):
        if pid_of_window(hwnd) == pid and user32.IsWindowVisible(hwnd):
            r = wintypes.RECT()
            user32.GetWindowRect(hwnd, ctypes.byref(r))
            found.append((bool(user32.IsIconic(hwnd)), r.right - r.left, r.bottom - r.top))
        return True

    user32.EnumWindows(ENUMPROC(cb), 0)
    return found


def foreground_pid():
    h = user32.GetForegroundWindow()
    return pid_of_window(h) if h else 0


def factorio_processes():
    """Tous les factorio.exe : [(pid, ligne de commande)] (lecture seule, aucune action)."""
    ps = ("Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'factorio.exe' } | "
          "ForEach-Object { [string]$_.ProcessId + '|' + [string]$_.CommandLine }")
    try:
        out = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ps],
                             capture_output=True, text=True, timeout=120).stdout
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError("liste des processus impossible : %s" % exc)
    procs = []
    for line in out.splitlines():
        if "|" in line:
            pid, cl = line.split("|", 1)
            if pid.strip().isdigit():
                procs.append((int(pid), cl.strip()))
    return procs


def test_processes(vis_dir):
    """factorio.exe de CETTE session de test : ceux dont la ligne de commande contient le dossier fo-visual."""
    key = os.path.normcase(os.path.abspath(vis_dir))
    return [(p, c) for p, c in factorio_processes() if key in os.path.normcase(c)]


def prepare(root, vis, test, atlas_cache):
    mods_src = os.path.join(test, "mods")
    map_src = os.path.join(test, "fo-autotest-map.zip")
    if not os.path.exists(map_src) or not os.path.isdir(mods_src):
        raise RuntimeError("pas de carte de test dans %s : lancer fo-autotest.bat d'abord" % test)
    os.makedirs(vis, exist_ok=True)
    mods = os.path.join(vis, "mods")
    if os.path.isdir(mods):
        shutil.rmtree(mods)
    shutil.copytree(mods_src, mods, ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copy2(map_src, os.path.join(vis, "fo-visual-map.zip"))
    write = os.path.join(vis, "write")
    os.makedirs(write, exist_ok=True)
    shots = os.path.join(write, "script-output", "fo-shots")
    if os.path.isdir(shots):
        shutil.rmtree(shots)  # captures de la session précédente (sorties de test)
    cfg = os.path.join(vis, "config.ini")
    with open(cfg, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s\n" % write.replace("\\", "/"))
        f.write("[general]\nlocale=fr\n[graphics]\nfull-screen=false\n")
        if atlas_cache:
            # Cache des atlas de sprites (dans fo-visual\write) : le chargement ne dépend plus des cœurs E.
            f.write("cache-sprite-atlas=true\ncompress-sprite-atlas-cache=true\n")
    return cfg, mods, os.path.join(vis, "fo-visual-map.zip"), write, shots


def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True)
    ap.add_argument("--window", choices=["min", "small", "normal"], default="min")
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--mode", choices=["benchmark", "load"], default="benchmark")
    ap.add_argument("--ticks", type=int, default=0, help="mode benchmark : durée de la session en ticks")
    ap.add_argument("--priority", choices=["normal", "below"], default="normal")
    ap.add_argument("--no-atlas-cache", dest="atlas_cache", action="store_false", default=True,
                    help="sans le cache des atlas de sprites (fo-visual\\write\\atlas-cache.dat, 391 Mo)")
    ap.add_argument("--pcores", action="store_true",
                    help="épingle la session sur les cœurs P (i5-12600KF : 12 fils P) : plus rapide, mais prend "
                         "ces cœurs à une partie en cours")
    a = ap.parse_args()

    root = os.path.abspath(a.root)
    vis, test = os.path.join(root, "fo-visual"), os.path.join(root, "fo-autotest")
    exe = os.path.join(root, "bin", "x64", "factorio.exe")
    t0 = time.time()
    summary = ["Session visuelle de test (visual_session.py)", "debut " + time.strftime("%Y-%m-%d %H:%M:%S")]

    def out(msg):
        print("[fo-visual] " + msg, flush=True)
        summary.append(msg)

    def finish(code, shots=None):
        summary.append("code de sortie %d, duree totale %.1f s" % (code, time.time() - t0))
        if shots and os.path.isdir(shots):
            with open(os.path.join(shots, "session.txt"), "w", encoding="utf-8", newline="\n") as f:
                f.write("\n".join(summary) + "\n")
        print("[fo-visual] code de sortie %d (%.1f s)" % (code, time.time() - t0), flush=True)
        return code

    # 0. Aucune session de test déjà ouverte (une session oubliée fausserait tout).
    try:
        left = test_processes(vis)
    except RuntimeError as exc:
        out("ECHEC " + str(exc))
        return finish(1)
    if left:
        out("ECHEC une session de test est deja ouverte (PID %s) : la fermer d'abord" % ", ".join(str(p) for p, _ in left))
        return finish(1)
    if not os.path.exists(exe):
        out("ECHEC factorio.exe introuvable : " + exe)
        return finish(1)

    # 1. Préparation des dossiers séparés.
    try:
        cfg, mods, game_map, write, shots = prepare(root, vis, test, a.atlas_cache)
    except (RuntimeError, OSError) as exc:
        out("ECHEC preparation : %s" % exc)
        return finish(1)
    source = read_text(os.path.join(test, "source.txt")).strip()
    scenario = read_text(os.path.join(mods, "fo-autotest", "scenario.lua")).strip()
    out("source du mod : %s ; %s" % (source or "?", scenario or "scenario ?"))

    name = scenario.replace("return", "").strip().strip('"')
    quick = name in ("content", "vitrine") or os.path.exists(os.path.join(mods, "fo-autotest", "scenarios", name + ".lua"))
    ticks = a.ticks or (7200 if quick else 40000)
    cmd = [exe, "--config", cfg, "--mod-directory", mods, "--disable-audio", "--disable-migration-window"]
    if a.mode == "benchmark":
        cmd += ["--benchmark-graphics", game_map, "--benchmark-ticks", str(ticks)]
    else:
        cmd += ["--load-game", game_map]
    if a.window == "small":
        cmd += ["--window-size", SMALL_SIZE]
    si = subprocess.STARTUPINFO()
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    si.wShowWindow = {"min": SW_SHOWMINNOACTIVE, "small": SW_SHOWNOACTIVATE, "normal": SW_SHOWNORMAL}[a.window]
    flags = BELOW_NORMAL_PRIORITY_CLASS if a.priority == "below" else 0
    out("mode %s%s, fenetre %s, priorite %s, cache d'atlas %s, delai %d s" % (
        a.mode, " (%d ticks au plus)" % ticks if a.mode == "benchmark" else "", a.window, a.priority,
        "oui" if a.atlas_cache else "non", a.timeout))
    out("commande : " + subprocess.list2cmdline(cmd))

    fg_before = foreground_pid()
    stdout = open(os.path.join(vis, "stdout.txt"), "w", encoding="utf-8", errors="replace")
    log_path = os.path.join(write, "factorio-current.log")
    t_launch = time.time()
    proc = subprocess.Popen(cmd, stdout=stdout, stderr=subprocess.STDOUT, startupinfo=si, creationflags=flags)
    out("processus de test lance : PID %d" % proc.pid)
    if a.pcores and os.cpu_count() == 16:
        ok = ctypes.WinDLL("kernel32").SetProcessAffinityMask(wintypes.HANDLE(int(proc._handle)), 0xFFF)
        out("epinglage sur les coeurs P (masque FFF) : %s" % ("fait" if ok else "REFUSE"))

    done_path = os.path.join(shots, "done.txt")
    samples = focus = shown = 0
    sizes = set()
    code, reason, last_progress, t_done = 0, "", 0.0, None
    while True:
        time.sleep(0.5)
        samples += 1
        if foreground_pid() == proc.pid:
            focus += 1
        for iconic, w, h in visible_windows(proc.pid):
            sizes.add("%dx%d%s" % (w, h, " (reduite)" if iconic else ""))
            if not iconic:
                shown += 1
                break
        if os.path.exists(done_path):
            t_done = time.time()
            out("marqueur de fin : %s apres %.1f s" % (read_text(done_path).strip(), t_done - t_launch))
            break
        rc = proc.poll()
        # Journal de CETTE session seulement (l'ancien est renommé au démarrage du jeu).
        fresh = os.path.exists(log_path) and os.path.getmtime(log_path) >= t_launch - 1
        log = read_text(log_path) if fresh else ""
        fatal = [ln for ln in log.splitlines() if FATAL.search(ln)]
        if fatal:
            code, reason = 7, "erreur du jeu : " + fatal[0].strip()
            break
        if rc is not None:
            time.sleep(1)  # le marqueur a pu être écrit juste avant la fin du budget de ticks
            if os.path.exists(done_path):
                continue
            code, reason = 7, "session fermee avant la fin (code %s) sans marqueur" % rc
            break
        if time.time() - t_launch > a.timeout:
            code, reason = 3, "delai de %d s depasse" % a.timeout
            break
        if time.time() - last_progress > 15:
            last_progress = time.time()
            n = len(gallery.read_index(shots))
            out("  ... %.0f s : %d capture(s) demandee(s)" % (time.time() - t_launch, n))
    if code:
        out("ECHEC " + reason)

    # 2. Les captures sont-elles toutes sur disque et lisibles ? (quelques secondes de marge)
    rows, problems = [], ["session interrompue"]
    if not code:
        deadline = time.time() + 30
        while True:
            rows, problems = gallery.validate(shots)
            if not problems or time.time() > deadline:
                break
            time.sleep(1)
        out("verification des fichiers : %d/%d lisibles%s" % (
            sum(1 for r in rows if r.get("ok")), len(rows), "" if not problems else " ; " + " | ".join(problems[:5])))

    # 3. Fermeture : uniquement le processus de test.
    natural = proc.poll() is not None
    if not natural:
        proc.terminate()  # TerminateProcess sur CE PID seulement
        try:
            proc.wait(timeout=20)
        except subprocess.TimeoutExpired:
            pass
    stdout.close()
    t_closed = time.time()
    out("session %s %.1f s apres le lancement" % ("terminee seule" if natural else "fermee par le pilote", t_closed - t_launch))
    remaining = []
    for attempt in range(3):
        remaining = test_processes(vis)
        if not remaining:
            break
        for pid, _ in remaining:
            try:
                os.kill(pid, signal.SIGTERM)  # PID d'un factorio.exe de test (ligne de commande fo-visual)
            except OSError:
                pass
        time.sleep(2)
    others = len(factorio_processes())
    if remaining:
        out("ECHEC processus de test encore presents : " + ", ".join(str(p) for p, _ in remaining))
        code = code or 5
    else:
        out("aucun factorio.exe de test restant (factorio.exe hors test en cours : %d, non touches)" % others)

    # 4. Gêne : focus pris, fenêtre affichée.
    out("gene : focus pris %d/%d echantillons (avant lancement : PID %s), fenetre non reduite %d/%d, tailles vues %s" % (
        focus, samples, fg_before, shown, samples, ", ".join(sorted(sizes)) or "aucune fenetre visible"))

    # 5. Index et planche (même en cas d'échec : on voit ce qui a été pris).
    if os.path.isdir(shots):
        titre = "%s - %s - %s" % (name or "?", time.strftime("%d/%m %H:%M"), a.window)
        rows, problems, idx, sheets = gallery.build(shots, titre)
        plan = gallery.read_plan(shots)
        ok = sum(1 for r in rows if r.get("ok"))
        out("captures : prevues %s, obtenues et lisibles %d" % (plan, ok))
        out("index : " + idx)
        for s in sheets:
            out("planche : " + s)
        if not code and (problems or not rows or ok != len(rows)):
            code = 4
            out("ECHEC captures : " + " | ".join(problems[:10]))
        vit = os.path.join(shots, "vitrine.txt")
        if os.path.exists(vit):
            txt = read_text(vit)
            fails = [ln for ln in txt.splitlines() if "ECHEC" in ln]
            m = re.search(r"^echecs\t(\S+)", txt, re.M)
            if fails or (m and m.group(1) != "0"):
                out("ECHEC vitrine : " + " | ".join(fails[:10] or [txt.splitlines()[0]]))
                code = code or 6
            else:
                out("vitrine : toutes les entites posees")
    else:
        out("aucun dossier de captures")
        code = code or 4
    if t_done:
        summary.append("duree jusqu'au marqueur %.1f s" % (t_done - t_launch))
    return finish(code, shots)


if __name__ == "__main__":
    sys.exit(main())
