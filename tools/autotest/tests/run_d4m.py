"""Bancs HORS JEU du lot D4m, en une commande (ne lance pas Factorio, n'écrit rien dans la racine du jeu).

    python -B tools/autotest/tests/run_d4m.py [--work DOSSIER] [--lua lua5.2] [--logs <racine>/fo-logs]

  1. d4_dryrun.lua : le greffon d4-geant sur un moteur simulé (pose, champ réel, bras et foreuses reliés, BILAN,
     journal) ; son journal sert de fixture ;
  2. make_fixtures.py : vram.tsv et perf-stats.csv synthétiques ;
  3. unit_vram.py : vram.py et memory_summary (arithmétique, formats supposés) ;
  4. driver_it.py : visual_session.main() sur une racine factice avec un faux jeu (options, config.ini de test,
     codes 0 et 9, preuves recopiées, session.txt) ;
  5. (--logs) vram.py sur chaque visual.log des archives : aucune erreur, et le nombre d'atlas attendu POUR LES
     REGLAGES QUE LE JOURNAL DECLARE (table ATLAS_ATTENDUS ci-dessous ; des reglages non etalonnes = echec).
Dossier de travail : --work, sinon un dossier temporaire neuf. Code de sortie 0 si toutes les étapes passent.
Ce que ces bancs NE prouvent PAS : tout ce qui dépend du moteur réel (README §5.3, « Non prouvé »).
La table de l'étape 5 se vérifie elle-même par mutations : tests/mut_atlas.py (README §5.1).
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
AUTOTEST = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(AUTOTEST))

# Atlas de sprites attendus dans un journal de session avec images, selon les réglages que CE journal déclare
# (ligne « Graphics options: [Graphics quality: …] [Video memory usage: …] [DXT: …] »). Clé : (qualité, usage de la
# mémoire vidéo, compression DXT), en minuscules. Valeur : (atlas en tout, atlas « [none] », pages d'atlas virtuel
# présentes). Étalonnage : les 13 journaux de fo-logs au 22/10 (README §5.1), mod 0.4.1 et versions antérieures.
#   - Les 13 autres atlas (une signature de drapeaux chacun : decal, low-object, terrain, ombres, icônes...) sont
#     présents une fois dans chacun des 13 journaux. Seuls les atlas « [none] » (sprites principaux) changent de nombre.
#   - Haute qualité : le premier atlas « [none] » est plein (16384×16364 ou 16384×16380, pour un bord maximal de 16384 :
#     « Initial atlas bitmap size is 16384 ») et un second s'ouvre (16384×12676 ou 16384×12660). La qualité haute
#     charge les « hr_version » (prototype-api : « If this property exists and high resolution sprites are turned
#     on ») : 475,8 Mpx d'atlas « [none] » contre 141,0 en normale.
#   - Normale : un seul atlas « [none] » (16384×8604), rempli à moins de 53 %.
#   - Plancher (« Video memory usage: low », « Tex.Stream.: 1 ») : l'atlas « [none] » tombe à 2048×1316 et le journal
#     crée un atlas VIRTUEL (« Created virtual atlas pages 4096x4096x9 »), absent des 12 autres journaux.
# Une combinaison absente de la table est un ÉCHEC (« non étalonnée ») : on ajoute une entrée après lecture d'un
# journal réel, on n'élargit jamais une entrée existante. Si les sprites du mod grossissent au point d'ouvrir un
# troisième atlas « [none] » en haute qualité, ce banc échoue : c'est voulu (budget D4-1 à revoir, puis réétalonnage).
ATLAS_ATTENDUS = {
    ("high", "all", "high-quality"): (15, 2, False),    # 10 journaux : P1 (8), D4m 1 et 2
    ("normal", "all", "high-quality"): (14, 1, False),  # D4m 3 et 4
    ("normal", "low", "low-quality"): (14, 1, True),    # D4m 5 (plancher)
}
RE_ATLAS_LIGNE = re.compile(r"^-- Atlas de sprites \((\d+)\)")
VIRTUEL = "Created virtual atlas pages"


def atlas_attendus(r, texte):
    """Écarts entre un journal (r : JSON de vram.py ; texte : journal brut) et ATLAS_ATTENDUS ; liste vide = conforme."""
    cle = tuple((r.get(k) or "").strip().lower() for k in ("quality", "video_memory_usage", "dxt"))
    if not all(cle):
        return ["reglages absents du journal (ligne Graphics options) : qualite %r, memoire %r, DXT %r" % cle]
    nom = "/".join(cle)
    if cle not in ATLAS_ATTENDUS:
        return ["reglages non etalonnes %s : aucune attente connue (ajouter une entree a ATLAS_ATTENDUS)" % nom]
    total, n_none, virtuel = ATLAS_ATTENDUS[cle]
    atlases = r.get("atlases") or []
    # Atlas « [none] » : aucun drapeau, écrit « [none] » par le jeu.
    vus_none = sum(1 for a in atlases if [f.lower() for f in a.get("flags") or []] in ([], ["none"]))
    vu_virtuel = VIRTUEL in texte
    ecarts = []
    if len(atlases) != total:
        ecarts.append("%d atlas, %d attendus pour %s" % (len(atlases), total, nom))
    if vus_none != n_none:
        ecarts.append("%d atlas [none], %d attendus pour %s" % (vus_none, n_none, nom))
    if vu_virtuel != virtuel:
        ecarts.append("atlas virtuel %s, %s attendu pour %s" % ("present" if vu_virtuel else "absent",
                                                               "present" if virtuel else "absent", nom))
    return ecarts


def verifie_journal(lg, py, dossier_json):
    """vram.py, en ligne de commande, sur un journal archivé ; renvoie (conforme, résumé, écarts)."""
    os.makedirs(dossier_json, exist_ok=True)
    fd, js = tempfile.mkstemp(suffix=".json", dir=dossier_json)
    os.close(fd)
    out = subprocess.run(py + [os.path.join(AUTOTEST, "vram.py"), lg, "--json", js], capture_output=True, text=True,
                         encoding="utf-8", errors="replace")
    lines = out.stdout.splitlines()
    line = next((ln.strip() for ln in lines if RE_ATLAS_LIGNE.match(ln)), "")
    tot = next((ln.strip() for ln in lines if ln.strip().startswith("TOTAL")), "")
    load = next((ln.strip() for ln in lines if ln.startswith("atlas ")), "")
    resume = "%s | %s | %s" % (line, tot, load)
    if out.returncode != 0:
        return False, resume, ["vram.py : code %d" % out.returncode]
    try:
        with open(js, encoding="utf-8") as fh:
            r = json.load(fh)
    except (OSError, ValueError) as exc:
        return False, resume, ["JSON de vram.py illisible : %s" % exc]
    ecarts = []
    # Le rapport texte et le JSON viennent de la même analyse : un désaccord serait un défaut de vram.py.
    m = RE_ATLAS_LIGNE.match(line)
    if not m or int(m.group(1)) != len(r.get("atlases") or []):
        ecarts.append("rapport et JSON de vram.py en desaccord sur le nombre d'atlas (%r)" % line)
    with open(lg, encoding="utf-8", errors="replace") as fh:
        texte = fh.read()
    ecarts += atlas_attendus(r, texte)
    return not ecarts, resume, ecarts


def verifie_archives(logs_dir, py, dossier_json):
    """Étape 5 : vram.py sur chaque <logs_dir>/*/visual.log ; renvoie (journaux, journaux en écart)."""
    logs = sorted(glob.glob(os.path.join(logs_dir, "*", "visual.log")))
    bad = []
    for lg in logs:
        ok, resume, ecarts = verifie_journal(lg, py, dossier_json)
        print("  %s : %s" % (os.path.basename(os.path.dirname(lg)), resume))
        for e in ecarts:
            print("      ECART : %s" % e)
        if not ok:
            bad.append(lg)
    return logs, bad


def step(name, cmd, results):
    print("=" * 8, name, ":", subprocess.list2cmdline(cmd), flush=True)
    try:
        rc = subprocess.run(cmd).returncode
    except OSError as exc:
        print("impossible de lancer %s : %s" % (cmd[0], exc))
        rc = 127
    results.append((name, rc))
    print("=" * 8, name, ":", "OK" if rc == 0 else "ECHEC (code %d)" % rc, flush=True)
    return rc == 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", help="dossier de travail (defaut : dossier temporaire neuf)")
    ap.add_argument("--lua", default="lua5.2", help="interprete Lua 5.2 (defaut : lua5.2 du PATH)")
    ap.add_argument("--logs", help="dossier d'archives fo-logs : vram.py sur chaque visual.log")
    a = ap.parse_args()
    work = os.path.abspath(a.work) if a.work else tempfile.mkdtemp(prefix="fo-d4m-")
    fixture = os.path.join(work, "fixture")
    os.makedirs(fixture, exist_ok=True)
    py = [sys.executable, "-B"]
    lua = shutil.which(a.lua) or a.lua  # « lua5.2 » : CreateProcess n'ajoute pas .exe à un nom qui a déjà un point
    results = []
    step("essai a blanc du greffon", [lua, os.path.join(HERE, "d4_dryrun.lua"), ROOT, os.path.join(fixture, "factorio.log")],
         results)
    step("fixtures synthetiques", py + [os.path.join(HERE, "make_fixtures.py"), fixture], results)
    step("unitaires vram.py", py + [os.path.join(HERE, "unit_vram.py"), AUTOTEST, fixture], results)
    step("integration visual_session.py", py + [os.path.join(HERE, "driver_it.py"), AUTOTEST, work], results)
    if a.logs:
        logs, bad = verifie_archives(a.logs, py, os.path.join(work, "archives"))
        results.append(("vram.py sur %d journaux archives" % len(logs), 0 if logs and not bad else 1))
        print("=" * 8, "vram.py sur les archives :", "OK" if logs and not bad else "ECHEC %s" % bad)
    print()
    for name, rc in results:
        print("%-40s %s" % (name, "OK" if rc == 0 else "ECHEC (code %d)" % rc))
    n_ok = sum(1 for _, rc in results if rc == 0)
    print("BILAN d4m hors jeu : %d/%d etapes OK (dossier de travail : %s)" % (n_ok, len(results), work))
    return 0 if n_ok == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
