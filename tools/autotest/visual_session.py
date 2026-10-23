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
  6. (lot D4m) Mesure DIRECTE, pendant toute la session, de la mémoire vidéo du SEUL processus de test
     (compteurs Windows « GPU Process Memory(pid_<PID>_*)\Dedicated Usage », lus par PDH sous leurs noms
     anglais : vram.py) et de sa mémoire vive ; échantillons dans fo-shots\vram.tsv, pic et moyenne dans
     session.txt, rapport complet (atlas, chargement, images/s) dans fo-shots\memoire.txt. Le journal du
     jeu et sa sortie standard sont recopiés dans fo-shots (factorio.log, stdout.txt).

Usage : python visual_session.py --root <racine du jeu> [--window min|small|hd|normal] [--size LxH]
                                 [--timeout 900] [--mode benchmark|load] [--ticks N]
                                 [--priority normal|below] [--no-atlas-cache] [--pcores]
                                 [--quality high|normal] [--video-memory all|high|medium|low]
                                 [--texture-compression none|high-quality|low-quality] [--measure]
  --ticks : budget du mode benchmark ; par défaut 7200 (2 min de jeu) pour content, vitrine et les
            scénarios greffés, 40000 pour les scénarios de guerre (10 min de mise en route à ×8).
  --quality : qualité des sprites de la session (« Sprite resolution » du jeu), écrite dans le config.ini
            de TEST (clé graphics-quality de [graphics]) ; normal, low et very-low sont aussi passées en option
            du binaire (--graphics-quality, qui n'accepte qu'elles ; low et very-low y sont migrées vers normal).
            Vérifiée dans le journal (« [Graphics quality: …] ») : écart = code 9. Alias : --graphics-quality
            (même nom que l'option du lot V0b, valeurs compatibles).
  --video-memory : « Video memory usage » du jeu (clé video-memory-usage et option du binaire), vérifiée.
  --texture-compression : « Texture compression » du jeu (clé texture-compression-level du config.ini de TEST,
            nom lu dans le binaire ; valeurs supposées d'après le journal « [DXT: high-quality] » et la locale
            texture-compression-none/-high-quality/-low-quality : NON prouvées). Vérifiée dans le journal
            (« [DXT: …] ») : écart = code 9. Aucune option du binaire ne la règle.
  --measure : mesure d'images par seconde : le jeu écrit ses statistiques de rendu (--output-perf-stats
            fo-visual\perf-stats.csv, recopié dans fo-shots) et le pilote attend la FIN NATURELLE du mode
            benchmark (budget --ticks) au lieu de fermer la session au marqueur. Fenêtre conseillée : hd
            (1920×1080, sans prendre le focus) ; en fenêtre réduite, le jeu peut ne rien dessiner.
Son (lot S0, E69) : variable d'environnement FO_AUDIO (la même que fo-autotest.bat). Absente ou vide : session
            lancée avec --disable-audio, comme avant. « 1 » : SANS --disable-audio, pour que le jeu CHARGE les
            fichiers son (un son manquant y bloque les mods, F151), mais SANS SORTIE AUDIO :
              - le factorio.exe de test, et lui seul, reçoit SDL_AUDIODRIVER=disk (pilote SDL « direct-to-disk
                audio » : aucun périphérique ouvert, la sortie mixée est écrite dans fo-visual\audio-disk.raw, puis
                mesurée dans session.txt) ; le journal doit dire « Driver:disk » puis « Loading sounds », sinon
                code 10 (et un autre pilote vu dans le journal tue la session). « dummy » n'existe pas dans le SDL
                du jeu : il retombe alors sur wasapi ;
              - un garde (audio_guard.py) relève toutes les 10 ms les sessions audio Windows de toutes les sorties
                actives : session ouverte par le processus de test ou crête non nulle → ce processus est tué tout de
                suite et le code est 10 ; garde indisponible → code 1, rien n'est lancé ;
              - les 9 volumes de la section [sound] du config.ini de TEST (fo-visual\config.ini) restent écrits à 0
                et relus avant le lancement (sinon code 1), mais ils NE suffisent PAS : avec le pilote wasapi, ils
                ont laissé sortir −34,6 dBFS (vérification du lot S0, F152).
            Toute autre valeur : code 1, rien n'est lancé. Les lignes du journal du jeu qui parlent de son et le
            rapport du garde sont recopiés dans session.txt.
Codes : 0 succès ; 1 préparation ; 3 délai dépassé ; 4 captures manquantes ou illisibles ;
        5 processus de test encore présent ; 6 vitrine : entité refusée ; 7 erreur du jeu ou session
        fermée avant la fin ; 9 qualité graphique, usage de la mémoire vidéo ou compression des textures
        non appliqués (journal) ; 10 son : sortie audio réelle ouverte ou crête non nulle (garde), pilote SDL
        autre que disk, ou chargement des sons absent du journal (FO_AUDIO=1 seulement).
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
import audio_guard  # noqa: E402
import gallery  # noqa: E402
import vram  # noqa: E402

SW_SHOWNORMAL, SW_SHOWNOACTIVATE, SW_SHOWMINNOACTIVE = 1, 4, 7
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
SMALL_SIZE = "640x360"
HD_SIZE = "1920x1080"
SAMPLE_PERIOD = 0.5  # s entre deux relevés de mémoire (compteurs Windows : moins de 1 ms par relevé)

# Erreurs qui arrêtent la partie (un script qui plante renvoie au menu : le marqueur ne viendrait jamais).
# Lot S0 (E69) : un son manquant, son actif, laisse le jeu au menu sans les mods (« Error SoundLibrary.cpp:56:
# Missing sound when loading sound library: <fichier> », puis « Resetting config ») jusqu'à la fin du budget du mode
# benchmark (122 s observées) : on s'arrête dès la ligne.
FATAL = re.compile(r"non-recoverable error|Error while running event|Exception at tick|Failed to load|"
                   r"Error ScriptRaised|Unexpected error|Missing sound when loading|Error SoundLibrary", re.I)

# Lot S0 (E69) : clés de volume de la section [sound] (chaînes du binaire 1.1.91 : « sound », « master-volume »,
# « music-volume » après « Config path », puis le mélangeur SoundMixerManager) ; mêmes clés que fo-autotest.bat.
AUDIO_KEYS = ("master-volume", "music-volume", "game-effects-volume", "gui-effects-volume", "walking-sound-volume",
              "environment-sounds-volume", "alerts-volume", "wind-volume", "simulation-volume")
AUDIO_LOG = re.compile(r"audio|sound|\.ogg|\.wav|\.voc", re.I)
# Correction du lot S0 : pilote SDL du seul processus de test quand le son est actif. Le pilote « dummy » n'existe pas
# dans le SDL de Factorio 1.1.91 (« Audio target 'dummy' not available », puis le jeu RETOMBE sur wasapi : session du
# 23/10, 22:22, tuée par le garde à 0,88 s) ; le pilote « disk » (« direct-to-disk audio », chaînes du binaire)
# n'ouvre aucun périphérique et écrit la sortie mixée du jeu dans un fichier brut (SDL_DISKAUDIOFILE).
AUDIO_DRIVER = "disk"
AUDIO_DISK_FILE = "audio-disk.raw"  # dans fo-visual\ (dossier de TEST), réécrit à chaque session
AUDIO_DRIVER_LINE = re.compile(r"\[Audio\][^\n]*?Driver:\s*([^,;\s]+)")
AUDIO_FORMAT_LINE = re.compile(r"\[Audio\][^\n]*?Depth:\s*(\d+)[^\n]*?Channels:\s*(\d+)[^\n]*?Frequency:\s*(\d+)")
SDL_AUDIO_VARS = ("SDL_AUDIODRIVER", "SDL_AUDIO_DEVICE_NAME", "SDL_DISKAUDIOFILE", "SDL_DISKAUDIOFILEIN",
                  "SDL_DISKAUDIODELAY")


def audio_env(audio, disk_file, env=None):
    """Environnement du processus de test : None (hérité, comme avant) sans son ; avec son, une copie où
    SDL_AUDIODRIVER vaut « disk » et SDL_DISKAUDIOFILE le fichier de sortie du dossier de test (les autres variables
    audio de SDL héritées sont retirées), pour ce seul processus."""
    if not audio:
        return None
    e = dict(os.environ if env is None else env)
    for k in list(e):
        if k.upper() in SDL_AUDIO_VARS:
            del e[k]
    e["SDL_AUDIODRIVER"] = AUDIO_DRIVER
    e["SDL_DISKAUDIOFILE"] = disk_file
    return e


def audio_driver(log):
    """Pilote audio annoncé par le journal du jeu (« [Audio] Backend:SDL(default); Driver:<pilote>, … ») ou None."""
    m = AUDIO_DRIVER_LINE.search(log or "")
    return m.group(1) if m else None


def disk_output(path, log):
    """Mesure de la sortie écrite par le pilote disk (entiers 16 bits signés, format lu dans la ligne [Audio] du
    journal) : dict (secondes, crête, RMS, part non nulle, premier instant non nul) ou None si illisible."""
    import array
    import math
    import operator
    m = AUDIO_FORMAT_LINE.search(log or "")
    if not m or not os.path.exists(path):
        return None
    depth, ch, freq = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if depth != 16 or ch < 1 or freq < 1:
        return {"format": "%d bits, %d voies, %d Hz (non lu)" % (depth, ch, freq)}
    a = array.array("h")
    with open(path, "rb") as f:
        data = f.read()
    a.frombytes(data[:len(data) - len(data) % 2])
    n = len(a)
    peak = max(max(a), -min(a)) if n else 0
    nonzero = n - a.count(0)
    lead = len(data) - len(data.lstrip(b"\x00"))  # octets nuls en tête
    rms = math.sqrt(sum(map(operator.mul, a, a)) / n) if n else 0.0
    return {"format": "%d bits, %d voies, %d Hz" % (depth, ch, freq), "octets": len(data),
            "secondes": n / float(ch * freq), "crete": peak / 32768.0, "rms": rms / 32768.0,
            "non_nuls": nonzero / float(n) if n else 0.0,
            "premier": (lead // 2 / float(ch * freq)) if nonzero else None}


def db(x):
    import math
    return "-inf" if x <= 0 else "%.1f" % (20 * math.log10(x))


def audio_from_env(env=None):
    """FO_AUDIO : (actif, erreur). Absente ou vide : (False, None) ; « 1 » : (True, None) ; sinon (False, motif)."""
    v = (os.environ if env is None else env).get("FO_AUDIO")
    if v is None or v == "":
        return False, None
    if v == "1":
        return True, None
    return False, "valeur invalide dans FO_AUDIO : [%s] (attendu : 1, ou variable absente)" % v


def audio_volumes(cfg):
    """Volumes lus dans la section [sound] d'un config.ini : {clé: texte}."""
    vols, section = {}, ""
    for line in read_text(cfg).splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
        elif section == "sound" and "=" in line and not line.startswith(";"):
            k, v = line.split("=", 1)
            vols[k.strip()] = v.strip()
    return vols


def audio_silent(cfg):
    """Toutes les clés de AUDIO_KEYS présentes et nulles dans le config.ini de test : (vrai, détail)."""
    vols = audio_volumes(cfg)
    bad = []
    for k in AUDIO_KEYS:
        try:
            if float(vols.get(k, "x")) != 0.0:
                bad.append("%s=%s" % (k, vols[k]))
        except ValueError:
            bad.append("%s absente ou illisible" % k)
    return not bad, (", ".join(bad) if bad else "%d volumes a 0 (%s)" % (len(AUDIO_KEYS), ", ".join(AUDIO_KEYS)))


def base_cmd(exe, cfg, mods, audio):
    """Début de la ligne de commande du jeu : --disable-audio sauf si le son est demandé (FO_AUDIO=1)."""
    return [exe, "--config", cfg, "--mod-directory", mods] + ([] if audio else ["--disable-audio"]) + [
        "--disable-migration-window"]


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


def test_processes(vis_dir, procs=None):
    """factorio.exe de CETTE session de test : ceux dont la ligne de commande contient le dossier fo-visual."""
    key = os.path.normcase(os.path.abspath(vis_dir))
    return [(p, c) for p, c in (factorio_processes() if procs is None else procs) if key in os.path.normcase(c)]


def prepare(root, vis, test, atlas_cache, quality=None, video_memory=None, texture_compression=None, audio=False):
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
        # Lot D4m. Noms des clés : chaînes du binaire 1.1.91, les mêmes que ses options (« graphics-quality »,
        # « video-memory-usage ») ; valeurs de la qualité : high, normal (low et very-low « are deprecated and
        # will be migrated to 'normal' », chaîne du binaire). Ce config.ini est CELUI DE TEST (fo-visual\) :
        # celui du joueur (<racine>\config\) n'est jamais lu ni écrit.
        if quality:
            f.write("graphics-quality=%s\n" % quality)
        if video_memory:
            f.write("video-memory-usage=%s\n" % video_memory)
        if texture_compression:
            # Clé du même bloc de réglages graphiques que full-screen et compress-sprite-atlas-cache (binaire).
            f.write("texture-compression-level=%s\n" % texture_compression)
        if audio:
            # Lot S0 (E69) : son actif pour charger les fichiers son, mais TOUS les volumes à 0 (config de TEST).
            f.write("[sound]\n")
            for k in AUDIO_KEYS:
                f.write("%s=0.000000\n" % k)
    perf = os.path.join(vis, "perf-stats.csv")
    if os.path.exists(perf):
        os.remove(perf)  # statistiques de rendu de la session précédente (sortie de test)
    return cfg, mods, os.path.join(vis, "fo-visual-map.zip"), write, shots


def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


class MemoryRecorder:
    """Lot D4m : relevés de mémoire du SEUL processus de test, toutes les SAMPLE_PERIOD secondes.

    Mémoire vidéo : compteurs Windows « GPU Process Memory » filtrés sur pid_<PID>_ (vram.GpuSampler, lecture
    seule) ; mémoire vive : GetProcessMemoryInfo sur la poignée du processus lancé. Aucune action sur aucun
    processus. Lignes : (t depuis le lancement, dédiée, partagée, toute la carte, RAM privée, RAM de travail).
    """

    def __init__(self, proc, t_launch):
        self.proc, self.t_launch = proc, t_launch
        self.rows, self.next, self.peaks = [], 0.0, None
        self.gpu = vram.GpuSampler(proc.pid)

    def tick(self):
        now = time.time()
        if now < self.next:
            return
        self.next = now + SAMPLE_PERIOD
        g = self.gpu.sample() or {}
        m = vram.process_memory(self.proc._handle) if self.proc.poll() is None else None
        if m:
            self.peaks = m  # pics tenus par Windows (PeakPagefileUsage, PeakWorkingSetSize)
        self.rows.append((now - self.t_launch, g.get("dedie"), g.get("partage"), g.get("carte"),
                          m["privee"] if m else None, m["ws"] if m else None))

    def write(self, path):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("\t".join(vram.SAMPLE_COLUMNS) + "\n")
            for row in self.rows:
                f.write("%.2f\t" % row[0] + "\t".join("-" if v is None else str(int(v)) for v in row[1:]) + "\n")

    def close(self):
        self.gpu.close()


def memory_summary(r, rec, measure, window="min"):
    """Lignes de session.txt : réglages appliqués, mémoire mesurée, atlas estimés, chargement, champ réel, images/s."""
    lines = ["reglages appliques (journal) : qualite des sprites %s, usage de la memoire video %s, DXT %s" % (
        r.get("quality", "?"), r.get("video_memory_usage", "?"), r.get("dxt", "?"))]
    m = r.get("mesure") or {}
    d = m.get("dedie_o")
    if d:
        lines.append("memoire video DEDIEE du jeu (compteurs Windows, PID %d) : pic %.2f Go, moyenne %.2f Go, "
                     "%d releves" % (rec.proc.pid, d["max"] / vram.GO, d["moy"] / vram.GO, d["n"]))
        if window in ("min", "small"):
            lines.append("ATTENTION fenetre %s : memoire video mesuree = borne BASSE (tampons de rendu et de "
                         "lumieres a la taille de la fenetre) ; D4-1 et D4-5 se lisent sur les passages en fenetre hd"
                         % ("reduite" if window == "min" else "640x360"))
    else:
        lines.append("memoire video dediee du jeu : NON MESUREE (%s)" % (rec.gpu.error or "aucun releve non nul"))
    for col, lab in (("carte_dedie_o", "occupation de toute la carte (tous programmes)"),
                     ("partage_o", "memoire partagee du jeu"), ("ram_privee_o", "memoire vive privee du jeu")):
        s = m.get(col)
        if s:
            lines.append("%s : pic %.2f Go, moyenne %.2f Go" % (lab, s["max"] / vram.GO, s["moy"] / vram.GO))
    if rec.peaks:
        lines.append("pics Windows du jeu : memoire privee %.2f Go, ensemble de travail %.2f Go" % (
            rec.peaks["pic_privee"] / vram.GO, rec.peaks["pic_ws"] / vram.GO))
    t = r.get("totaux") or {}
    if r.get("atlases"):
        lines.append("atlas de sprites : %d, %.3f milliard de pixels%s, estimation %s (regles : vram.py)" % (
            len(r["atlases"]), t["pixels"] / 1e9,
            (" + %.1f Mpx de pages d'atlas virtuel (comptees : HYPOTHESE residentes et compressees)"
             % (t["pixels_virtuels"] / 1e6)) if t.get("pixels_virtuels") else "",
            vram.fmt_range(t["bas"], t["haut"])))
    ev = r.get("events") or {}
    if ev:
        lines.append("chargement : atlas %s, sprites charges a %s s, jeu initialise a %s s" % (
            "lus depuis le cache" if "Atlases loaded from disk cache." in ev else "REFAITS",
            ev.get("Sprites loaded", "?"), ev.get("Factorio initialised", "?")))
    for c in r.get("champs") or []:
        if c["genre"] == "vue":
            lines.append("champ reel de la vue %s (%dx%d, zoom %.2f) : %d batiments a niveaux (machines %d, murs %d), "
                         "tapis %d, bras %d" % (c["nom"], c["w"], c["h"], c["zoom"], c["batiments"], c["machines"],
                                               c["murs"], c["tapis"], c["bras"]))
    for p in r.get("phases") or []:
        lines.append("phase d4-geant %s : %d ticks en %.1f ms -> %.1f UPS%s" % (p["name"], p["ticks"], p["ms"],
                                                                              p["ups"] or 0, vram.phase_note(p["name"])))
    lines.append(vram.vsync_text(r))
    hz = vram.refresh_hz(r)
    ps = r.get("perf_summary") or {}
    if "frame" in ps and ps["frame"]["avg"] > 0:
        lines.append("resume \"frame> avg\" du jeu (ecriture et sens NON prouves) : 1000 / moyenne = %.1f (HYPOTHESE : "
                     "frame = duree totale de l'image)" % (1000.0 / ps["frame"]["avg"]))
    pf = r.get("perf") or {}
    if pf.get("global_ips"):
        lines.append("images/s (perf-stats.csv, %d lignes), ensemble : %s" % (
            pf["images"], vram.ips_text(pf["global_ips"], hz)))
        for p in pf.get("par_phase") or []:
            lines.append("images/s phase %s : %s" % (p["name"], vram.ips_text(p.get("ips") or {}, hz)))
        if pf.get("segmentation") and not pf.get("par_phase"):
            lines.append("images/s par phase : segmentation NON appariee (%d segments pour %d phases)" % (
                pf["segmentation"]["segments"], pf["segmentation"]["phases"]))
    elif pf.get("erreur"):
        lines.append("statistiques de rendu : " + pf["erreur"])
    elif measure:
        lines.append("images/s : NON MESUREES (aucune statistique de rendu ecrite par le jeu)")
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True)
    ap.add_argument("--window", choices=["min", "small", "hd", "normal"], default="min",
                    help="min : reduite sans focus ; small : 640x360 sans focus ; hd : 1920x1080 sans focus ; "
                         "normal : fenetre du jeu, AVEC focus")
    ap.add_argument("--size", help="taille de fenetre LxH (remplace celle de small, hd ou normal)")
    ap.add_argument("--quality", "--graphics-quality", dest="quality", choices=["high", "normal", "low", "very-low"],
                    default=None, help="qualite des sprites (Sprite resolution) de la session ; defaut : celle du "
                                       "preset (high ici) ; low et very-low sont migrees vers normal par le jeu")
    ap.add_argument("--video-memory", dest="video_memory", choices=["all", "high", "medium", "low"], default=None,
                    help="usage de la memoire video (Video memory usage) de la session ; defaut : all")
    ap.add_argument("--texture-compression", dest="texture_compression",
                    choices=["none", "high-quality", "low-quality"], default=None,
                    help="compression des textures (Texture compression) de la session : cle texture-compression-level "
                         "du config.ini de test ; defaut : celle du preset")
    ap.add_argument("--measure", action="store_true",
                    help="statistiques de rendu du jeu (--output-perf-stats) et attente de la fin naturelle")
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
        procs = factorio_processes()
        left = test_processes(vis, procs)
        others_before = len(procs) - len(left)
    except RuntimeError as exc:
        out("ECHEC " + str(exc))
        return finish(1)
    if left:
        out("ECHEC une session de test est deja ouverte (PID %s) : la fermer d'abord" % ", ".join(str(p) for p, _ in left))
        return finish(1)
    if not os.path.exists(exe):
        out("ECHEC factorio.exe introuvable : " + exe)
        return finish(1)
    out("factorio.exe hors test au lancement : %d (jamais touches)%s" % (
        others_before, " ; ATTENTION mesure : une autre partie partage la carte et le processeur, images/s et "
                       "occupation de la carte faussees" if (others_before and a.measure) else ""))
    if a.measure and a.window == "min":
        out("ATTENTION mesure en fenetre reduite : le jeu peut ne rien dessiner (images/s non representatives) ; "
            "fenetre conseillee : hd")

    # 0 bis. Son (lot S0, E69) : FO_AUDIO filtrée AVANT toute préparation.
    audio, audio_err = audio_from_env()
    guard = None
    if audio_err:
        out("ECHEC " + audio_err + " : rien n'est lance")
        return finish(1)

    # 1. Préparation des dossiers séparés.
    try:
        cfg, mods, game_map, write, shots = prepare(root, vis, test, a.atlas_cache, a.quality, a.video_memory,
                                                    a.texture_compression, audio)
    except (RuntimeError, OSError) as exc:
        out("ECHEC preparation : %s" % exc)
        return finish(1)
    if audio:
        silent, detail = audio_silent(cfg)
        if not silent:
            out("ECHEC son : volumes non nuls ou absents dans %s : %s ; rien n'est lance" % (cfg, detail))
            return finish(1)
        disk_file = os.path.join(vis, AUDIO_DISK_FILE)
        if os.path.exists(disk_file):
            os.remove(disk_file)  # sortie audio de la session précédente (dossier de test)
        out("son ACTIF (FO_AUDIO=1) : %s, relus dans %s avant le lancement ; pilote SDL du processus de test : "
            "SDL_AUDIODRIVER=%s, sortie dans %s" % (detail, cfg, AUDIO_DRIVER, disk_file))
        guard = audio_guard.Guard()
        gerr = guard.start_and_wait()
        if gerr:
            guard.stop()
            out("ECHEC garde de crete indisponible (%s) : sans elle, le silence n'est pas prouve ; rien n'est lance"
                % gerr)
            return finish(1)
        out("garde de crete prete : %d sortie(s) audio active(s), releve toutes les %d ms" % (
            guard.outputs, round(guard.period * 1000)))
    else:
        out("son coupe (--disable-audio)")
    source = read_text(os.path.join(test, "source.txt")).strip()
    scenario = read_text(os.path.join(mods, "fo-autotest", "scenario.lua")).strip()
    out("source du mod : %s ; %s" % (source or "?", scenario or "scenario ?"))

    name = scenario.replace("return", "").strip().strip('"')
    quick = name in ("content", "vitrine") or os.path.exists(os.path.join(mods, "fo-autotest", "scenarios", name + ".lua"))
    ticks = a.ticks or (7200 if quick else 40000)
    cmd = base_cmd(exe, cfg, mods, audio)
    if a.mode == "benchmark":
        cmd += ["--benchmark-graphics", game_map, "--benchmark-ticks", str(ticks)]
    else:
        cmd += ["--load-game", game_map]
    # Lot D4m : qualité et usage de la mémoire vidéo AUSSI en options du binaire (en plus du config.ini de test).
    # --graphics-quality n'accepte que normal, low, very-low (chaîne du binaire) : « high » passe par la clé seule.
    if a.quality and a.quality != "high":
        cmd += ["--graphics-quality", a.quality]
    if a.video_memory:
        cmd += ["--video-memory-usage", a.video_memory]
    perf_path = os.path.join(vis, "perf-stats.csv")
    if a.measure:
        # « path of file to which rendering performance statistics measurements should be saved » (binaire).
        cmd += ["--output-perf-stats", perf_path]
    size = a.size or {"small": SMALL_SIZE, "hd": HD_SIZE}.get(a.window)
    if size and a.window != "min":
        cmd += ["--window-size", size]
    si = subprocess.STARTUPINFO()
    si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    si.wShowWindow = {"min": SW_SHOWMINNOACTIVE, "small": SW_SHOWNOACTIVATE, "hd": SW_SHOWNOACTIVATE,
                      "normal": SW_SHOWNORMAL}[a.window]
    flags = BELOW_NORMAL_PRIORITY_CLASS if a.priority == "below" else 0
    out("mode %s%s, fenetre %s%s, priorite %s, cache d'atlas %s, delai %d s" % (
        a.mode, " (%d ticks au plus)" % ticks if a.mode == "benchmark" else "", a.window,
        " " + size if size and a.window != "min" else "", a.priority, "oui" if a.atlas_cache else "non", a.timeout))
    out("qualite des sprites demandee : %s ; usage de la memoire video demande : %s ; compression des textures "
        "demandee : %s ; mesure d'images/s : %s" % (
            a.quality or "defaut", a.video_memory or "defaut", a.texture_compression or "defaut",
            "oui (fin naturelle attendue)" if a.measure else "non"))
    out("commande : " + subprocess.list2cmdline(cmd))

    fg_before = foreground_pid()
    stdout_path = os.path.join(vis, "stdout.txt")
    stdout = open(stdout_path, "w", encoding="utf-8", errors="replace")
    log_path = os.path.join(write, "factorio-current.log")
    t_launch = time.time()
    proc = subprocess.Popen(cmd, stdout=stdout, stderr=subprocess.STDOUT, startupinfo=si, creationflags=flags,
                            env=audio_env(audio, os.path.join(vis, AUDIO_DISK_FILE)))
    if guard:
        guard.watch(proc.pid, proc.terminate)  # violation : TerminateProcess sur CE PID seulement, tout de suite
    out("processus de test lance : PID %d" % proc.pid)
    if a.pcores and os.cpu_count() == 16:
        ok = ctypes.WinDLL("kernel32").SetProcessAffinityMask(wintypes.HANDLE(int(proc._handle)), 0xFFF)
        out("epinglage sur les coeurs P (masque FFF) : %s" % ("fait" if ok else "REFUSE"))
    rec = MemoryRecorder(proc, t_launch)
    if rec.gpu.error:
        out("compteurs GPU de Windows : %s" % rec.gpu.error)

    done_path = os.path.join(shots, "done.txt")
    samples = focus = shown = 0
    sizes = set()
    code, reason, last_progress, t_done = 0, "", 0.0, None
    while True:
        time.sleep(0.5)
        rec.tick()
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
        if guard and guard.violation:
            code, reason = 10, "son : " + guard.violation
            break
        drv = audio_driver(log) if audio else None
        if drv is not None and drv != AUDIO_DRIVER:
            proc.terminate()
            code, reason = 10, "son : pilote SDL %s au lieu de %s (journal) : session tuee" % (drv, AUDIO_DRIVER)
            break
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

    # 1 bis. Mesure (lot D4m) : le jeu n'écrit ses statistiques de rendu qu'en quittant ; on attend donc la fin
    # NATURELLE du mode benchmark (budget --ticks) au lieu de fermer la session au marqueur.
    if not code and a.measure and a.mode == "benchmark":
        out("mesure : attente de la fin naturelle du mode benchmark (%d ticks)" % ticks)
        while proc.poll() is None and time.time() - t_launch <= a.timeout:
            time.sleep(0.5)
            rec.tick()
        if proc.poll() is None:
            code, reason = 3, "mesure : fin naturelle non atteinte dans le delai de %d s (reduire --ticks)" % a.timeout
            out("ECHEC " + reason)
        else:
            out("mesure : fin naturelle %.1f s apres le lancement (code %s)" % (time.time() - t_launch, proc.returncode))

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
    if guard:
        guard.stop()
        out(guard.report())
        if guard.violation and code != 10:
            out("ECHEC son : " + guard.violation)
        if guard.violation:
            code = 10
    how = "terminee seule" if natural else "fermee par le pilote"
    if guard and guard.violation:
        how = "TUEE par le garde de crete"
    out("session %s %.1f s apres le lancement" % (how, t_closed - t_launch))
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

    # 6. Mémoire et images par seconde (lot D4m) : preuves recopiées dans fo-shots, puis rapport vram.py.
    rec.close()
    fresh = os.path.exists(log_path) and os.path.getmtime(log_path) >= t_launch - 1
    dest = shots if os.path.isdir(shots) else vis
    files = {"log": None, "samples": os.path.join(dest, "vram.tsv"), "perf": None, "stdout": None}
    try:
        rec.write(files["samples"])
        for key, src, name_ in (("log", log_path if fresh else None, "factorio.log"),
                                ("stdout", stdout_path, "stdout.txt"),
                                ("perf", perf_path if os.path.exists(perf_path) else None, "perf-stats.csv")):
            if src and os.path.exists(src):
                target = os.path.join(dest, name_)
                if os.path.abspath(src) != os.path.abspath(target):
                    shutil.copy2(src, target)
                files[key] = target
        r = vram.analyse(files["log"], files["samples"], files["perf"], files["stdout"])
        with open(os.path.join(dest, "memoire.txt"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(vram.report_lines(r)) + "\n")
        for line in memory_summary(r, rec, a.measure, a.window):
            out(line)
        out("rapport memoire : " + os.path.join(dest, "memoire.txt"))
        # low et very-low : « deprecated and will be migrated to 'normal' » (binaire) : le journal dira normal.
        want_q = "normal" if a.quality in ("low", "very-low") else a.quality
        for want, got, label in ((want_q, r.get("quality"), "qualite des sprites"),
                                 (a.video_memory, r.get("video_memory_usage"), "usage de la memoire video"),
                                 (a.texture_compression, r.get("dxt"), "compression des textures")):
            if want and (got or "").lower() != want:
                out("ECHEC %s demandee %s, appliquee %s (journal) : mesure non valable" % (label, want, got or "?"))
                code = code or 9
        if a.measure and not files["perf"]:
            out("mesure : AUCUN fichier de statistiques de rendu ecrit par le jeu (--output-perf-stats)")
    except (OSError, ValueError, KeyError) as exc:
        out("ECHEC rapport memoire : %s" % exc)
    # 7. Son (lot S0, E69) : lignes du journal de CETTE session qui parlent de son (chargement, erreurs).
    if fresh:
        sl = [ln.strip() for ln in read_text(log_path).splitlines() if AUDIO_LOG.search(ln)
              and "Program arguments" not in ln]
        out("journal, lignes de son : %d%s" % (len(sl), "" if not sl else " ; " + " | ".join(sl[:12])))
    if audio and code == 0:
        log = read_text(log_path) if fresh else ""
        drv = audio_driver(log)
        if drv != AUDIO_DRIVER or "Loading sounds" not in log:
            out("ECHEC son : chargement des sons non prouve (pilote du journal : %s ; « Loading sounds » %s)" % (
                drv, "present" if "Loading sounds" in log else "ABSENT"))
            code = 10
        else:
            out("son : pilote %s et « Loading sounds » dans le journal, garde sans violation" % drv)
    if audio:
        # Ce que le jeu aurait envoyé aux haut-parleurs (pilote disk) : mesure seule, hors code de sortie.
        try:
            d = disk_output(os.path.join(vis, AUDIO_DISK_FILE), read_text(log_path) if fresh else "")
        except (OSError, ValueError, MemoryError) as exc:
            d = {"format": "illisible : %s" % exc}
        if d is None:
            out("sortie du pilote disk : AUCUN fichier ou format absent du journal (%s)" % AUDIO_DISK_FILE)
        elif "secondes" not in d:
            out("sortie du pilote disk : " + d["format"])
        else:
            out("sortie du pilote disk (ce que le jeu aurait joue, %s) : %.1f s, %d octets, crete %.6f (%s dBFS), "
                "RMS %.6f (%s dBFS), echantillons non nuls %.1f %%, premier non nul a %s" % (
                    d["format"], d["secondes"], d["octets"], d["crete"], db(d["crete"]), d["rms"], db(d["rms"]),
                    100 * d["non_nuls"], "%.2f s" % d["premier"] if d["premier"] is not None else "aucun"))
    if t_done:
        summary.append("duree jusqu'au marqueur %.1f s" % (t_done - t_launch))
    return finish(code, shots)


if __name__ == "__main__":
    sys.exit(main())
