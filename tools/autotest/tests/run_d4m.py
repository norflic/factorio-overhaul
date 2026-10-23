"""Bancs HORS JEU du lot D4m, en une commande (ne lance pas Factorio, n'écrit rien dans la racine du jeu).

    python -B tools/autotest/tests/run_d4m.py [--work DOSSIER] [--lua lua5.2] [--logs <racine>/fo-logs]

  1. d4_dryrun.lua : le greffon d4-geant sur un moteur simulé (pose, champ réel, bras et foreuses reliés, BILAN,
     journal) ; son journal sert de fixture ;
  2. make_fixtures.py : vram.tsv et perf-stats.csv synthétiques ;
  3. unit_vram.py : vram.py et memory_summary (arithmétique, formats supposés) ;
  4. driver_it.py : visual_session.main() sur une racine factice avec un faux jeu (options, config.ini de test,
     codes 0 et 9, preuves recopiées, session.txt) ;
  5. (--logs) vram.py sur chaque visual.log des archives : aucune erreur, et les atlas attendus POUR LES REGLAGES
     QUE LE JOURNAL DECLARE (table ATLAS_ATTENDUS ci-dessous : nombre en tout, nombre d'atlas « [none] », chacun des
     13 autres une fois, atlas virtuel, taille des « [none] » au plancher ; des reglages non etalonnes = echec).
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
# mémoire vidéo, compression DXT), en minuscules. Valeur : atlas en tout, atlas « [none] », pages d'atlas virtuel
# présentes ou non, atlas « [none] » réduits par le plancher ou non (SEUIL_NONE_PX). Étalonnage : les 13 journaux de
# fo-logs au 22/10 (README §5.1), mod 0.4.1 et versions antérieures.
#   - Les 13 autres atlas (AUTRES_ATLAS : decal, low-object, terrain, ombres, icônes...) sont présents une fois PAR
#     CATÉGORIE dans chacun des 13 journaux, avec les mêmes drapeaux, à une exception près : l'atlas [low-object]
#     porte « linear-minification » en haute qualité et au plancher, pas en qualité normale avec mémoire « all »
#     (observé, non expliqué ; seule variation tolérée). Seuls les atlas « [none] » (sprites principaux) changent de
#     nombre.
#   - Haute qualité : le premier atlas « [none] » est plein (16384×16364 ou 16384×16380, pour un bord maximal de 16384 :
#     « Initial atlas bitmap size is 16384 ») et un second s'ouvre (16384×12676 ou 16384×12660). La qualité haute
#     charge les « hr_version » (prototype-api : « If this property exists and high resolution sprites are turned
#     on ») : 475,8 Mpx d'atlas « [none] » contre 141,0 en normale.
#   - Normale : un seul atlas « [none] » (16384×8604), rempli à moins de 53 %.
#   - Plancher (« Video memory usage: low », « Tex.Stream.: 1 ») : l'atlas « [none] » tombe à 2048×1316 (2,7 Mpx) et
#     le journal crée un atlas VIRTUEL (« Created virtual atlas pages 4096x4096x9 »), absent des 12 autres journaux.
# Une combinaison absente de la table est un ÉCHEC (« non étalonnée ») : on ajoute une entrée après lecture d'un
# journal réel, on n'élargit jamais une entrée existante. Si les sprites du mod grossissent au point d'ouvrir un
# troisième atlas « [none] » en haute qualité, ce banc échoue : c'est voulu (budget D4-1 à revoir, puis réétalonnage).
ATLAS_ATTENDUS = {
    # (qualité, mémoire, DXT) : {total, [none], atlas virtuel, [none] réduits par le plancher}
    ("high", "all", "high-quality"): {"total": 15, "none": 2, "virtuel": False, "plancher": False},  # P1 (8), D4m 1 et 2
    ("normal", "all", "high-quality"): {"total": 14, "none": 1, "virtuel": False, "plancher": False},  # D4m 3 et 4
    ("normal", "low", "low-quality"): {"total": 14, "none": 1, "virtuel": True, "plancher": True},  # D4m 5
}
# Pixels « [none] » en tout : au plancher, au plus SEUIL_NONE_PX ; ailleurs, plus. C'est une LIGNE DE PARTAGE entre les
# valeurs observées (2,7 Mpx au plancher ; 141,0 et 475,8 ailleurs), choisie égale à une page d'atlas virtuel
# (4096×4096, 16,8 Mpx) : pas une limite du moteur. Elle refuse un plancher qui ne s'est pas appliqué, et l'inverse.
SEUIL_NONE_PX = 4096 * 4096
# Les 13 atlas hors « [none] », un par signature de drapeaux (ensembles, ordre du journal ignoré).
AUTRES_ATLAS = sorted([
    ("decal",),
    ("low-object",),  # « linear-minification » toléré en plus : voir VARIANTES
    ("mipmap", "linear-minification", "linear-magnification", "linear-mip-level"),
    ("terrain", "mipmap", "linear-minification", "linear-mip-level"),
    ("terrain-effect-map", "mipmap", "linear-minification", "linear-mip-level"),
    ("smoke", "mipmap", "linear-minification", "linear-magnification"),
    ("low-object", "mipmap", "linear-minification", "linear-magnification", "linear-mip-level"),
    ("mipmap",),
    ("icon", "not-compressed", "mipmap", "linear-minification", "linear-magnification", "linear-mip-level"),
    ("alpha-mask",),
    ("shadow", "linear-magnification", "alpha-mask"),
    ("shadow", "mipmap", "linear-magnification", "alpha-mask"),
    ("icon-background", "not-compressed", "mipmap", "linear-minification", "linear-magnification", "linear-mip-level"),
])
# Seule variation tolérée : l'atlas [low-object] avec ou sans « linear-minification » (voir plus haut).
VARIANTES = {frozenset(["low-object", "linear-minification"]): frozenset(["low-object"])}
# Variation tolérée SELON LA QUALITÉ déclarée ET LE CONTENU déclaré (lot A2, correction, 24/10) : en qualité NORMALE
# (mémoire « all » ou « low »), l'atlas [icon] peut perdre « linear-mip-level » avec les icônes d'âge de la mitrailleuse
# (graphics/levels/gun/gun-eNN-icone.png). Cause mesurée (F125, fo-logs 2026-10-24_A2/correction/d4m-icones) : le
# RANGEMENT de l'atlas, pas le contenu ni la taille : 14 icônes d'âge -> drapeau absent ; 13 ou 15 -> présent ; 14
# icônes au contenu vanilla -> absent ; atlas 8192 x 2288 dans les 4 cas. Tolérée SEULEMENT si le journal porte le
# marqueur du mod « [FO-GUN-ICONES] » (prototypes/levels/gun.lua) ; signalée à chaque journal (« TOLERE »). En haute
# qualité, le drapeau est exigé.
ICONE = ("icon", "not-compressed", "mipmap", "linear-minification", "linear-magnification", "linear-mip-level")
VARIANTES_QUALITE = {"normal": {frozenset(ICONE) - {"linear-mip-level"}: frozenset(ICONE)}}
MARQUEUR_ICONES = "[FO-GUN-ICONES]"
RE_ATLAS_LIGNE = re.compile(r"^-- Atlas de sprites \((\d+)\)")
VIRTUEL = "Created virtual atlas pages"


def signature(flags, qualite=None, icones_age=False):
    """Signature d'un atlas : ensemble de ses drapeaux en minuscules (« none » et vides ôtés), variante tolérée ramenée
    (VARIANTES, puis VARIANTES_QUALITE de la qualité déclarée par le journal)."""
    s = frozenset(f.strip().lower() for f in flags or [] if f.strip() and f.strip().lower() != "none")
    s = VARIANTES.get(s, s)
    if not icones_age:
        return s
    return VARIANTES_QUALITE.get(qualite, {}).get(s, s)


def atlas_attendus(r, icones_age=False, toleres=None):
    """Écarts entre un journal (r : JSON de vram.py) et ATLAS_ATTENDUS ; liste vide = conforme. icones_age : le journal
    porte MARQUEUR_ICONES ; toleres (liste) reçoit les variations tolérées rencontrées."""
    cle = tuple((r.get(k) or "").strip().lower() for k in ("quality", "video_memory_usage", "dxt"))
    if not all(cle):
        return ["reglages absents du journal (ligne Graphics options) : qualite %r, memoire %r, DXT %r" % cle]
    nom = "/".join(cle)
    if cle not in ATLAS_ATTENDUS:
        return ["reglages non etalonnes %s : aucune attente connue (ajouter une entree a ATLAS_ATTENDUS)" % nom]
    att = ATLAS_ATTENDUS[cle]
    atlases = r.get("atlases") or []
    # Atlas « [none] » : aucun drapeau, écrit « [none] » par le jeu.
    nones = [a for a in atlases if not signature(a.get("flags"), cle[0], icones_age)]
    px_none = sum(a["w"] * a["h"] for a in nones)
    # Atlas virtuel : relevé par vram.parse_log sur la ligne horodatée du MOTEUR seulement (une impression de script
    # qui contient ces mots ne compte pas).
    vu_virtuel = bool(r.get("virtual_atlases"))
    ecarts = []
    if len(atlases) != att["total"]:
        ecarts.append("%d atlas, %d attendus pour %s" % (len(atlases), att["total"], nom))
    if len(nones) != att["none"]:
        ecarts.append("%d atlas [none], %d attendus pour %s" % (len(nones), att["none"], nom))
    # Composition : chaque signature de AUTRES_ATLAS exactement une fois, aucune autre.
    vues = {}
    for a in atlases:
        s = signature(a.get("flags"), cle[0], icones_age)
        brut = signature(a.get("flags"))
        if s and s != brut and toleres is not None:
            toleres.append("atlas [%s] %dx%d ramene a [%s] (qualite %s, marqueur %s : F125)"
                           % (", ".join(sorted(brut)), a["w"], a["h"], ", ".join(sorted(s)), cle[0], MARQUEUR_ICONES))
        if s:
            vues[s] = vues.get(s, 0) + 1
    attendues = set(frozenset(t) for t in AUTRES_ATLAS)
    for t in AUTRES_ATLAS:
        n = vues.get(frozenset(t), 0)
        if n != 1:
            ecarts.append("atlas [%s] vu %d fois, 1 attendu" % (", ".join(t), n))
    for s in sorted(vues, key=sorted):
        if s not in attendues:
            ecarts.append("atlas [%s] inattendu (%d)" % (", ".join(sorted(s)), vues[s]))
    if vu_virtuel != att["virtuel"]:
        ecarts.append("atlas virtuel %s, %s attendu pour %s" % ("present" if vu_virtuel else "absent",
                                                               "present" if att["virtuel"] else "absent", nom))
    if att["plancher"] and px_none > SEUIL_NONE_PX:
        ecarts.append("atlas [none] : %.1f Mpx, au plus %.1f attendus au plancher %s (plancher non applique ?)"
                      % (px_none / 1e6, SEUIL_NONE_PX / 1e6, nom))
    if not att["plancher"] and px_none <= SEUIL_NONE_PX:
        ecarts.append("atlas [none] : %.1f Mpx, plus de %.1f attendus pour %s (plancher applique a tort ?)"
                      % (px_none / 1e6, SEUIL_NONE_PX / 1e6, nom))
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
    try:
        with open(lg, encoding="utf-8", errors="replace") as fh:
            icones_age = any(MARQUEUR_ICONES in ln and "Script @__factorio-overhaul__" in ln for ln in fh)
    except OSError:
        icones_age = False
    toleres = []
    ecarts += atlas_attendus(r, icones_age, toleres)
    for t in toleres:
        print("      TOLERE : %s" % t)
    return not ecarts, resume, ecarts


def journaux_archives(logs_dir):
    """Les journaux que lit l'étape 5 : <logs_dir>/*/visual.log, un seul niveau (mut_atlas.py s'en sert pour vérifier
    qu'il n'y dépose rien)."""
    return sorted(glob.glob(os.path.join(logs_dir, "*", "visual.log")))


def verifie_archives(logs_dir, py, dossier_json):
    """Étape 5 : vram.py sur chaque <logs_dir>/*/visual.log ; renvoie (journaux, journaux en écart)."""
    logs = journaux_archives(logs_dir)
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
