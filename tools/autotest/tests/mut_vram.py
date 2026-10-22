r"""Mutations de la règle « atlas virtuel » de vram.py : chaque mutant doit faire échouer unit_vram.py (HORS JEU).

    python -B tools/autotest/tests/mut_vram.py [--work DOSSIER] [--lua lua5.2]

Suite vram (R1, 22/10). Le premier banc de mutations du constructeur (archivé dans fo-logs\2026-10-22_R1\vram\) ne
copiait que vram.py et visual_session.py dans le dossier du mutant : visual_session.py fait « import gallery », donc
CHAQUE copie, même intacte, plantait (ModuleNotFoundError) et le plantage comptait comme « détecté ». Ce banc-ci :
  - copie TOUS les modules .py de tools/autotest (pas les tests) dans le dossier de chaque copie ;
  - joue d'abord un TÉMOIN NUL (copie intacte) qui doit SURVIVRE avec « BILAN unitaire : n OK, 0 ECHEC(S) » ; sinon
    le banc échoue (code 1) et aucun mutant n'est jugé ;
  - distingue un mutant détecté par un CONTRÔLE (ligne « ECHEC » de unit_vram.py) d'un mutant qui fait PLANTER les
    unitaires : les deux comptent comme détectés, mais le second est écrit à part ;
  - échoue si un motif n'est pas trouvé exactement une fois (le banc ne doit pas suivre en silence une vram.py
    réécrite).
Fixtures : journal de d4_dryrun.lua et make_fixtures.py, refaits dans le dossier de travail (comme run_d4m.py).
Code de sortie 0 si le témoin survit et si tous les mutants sont détectés. N'éprouve que unit_vram.py contre la règle
écrite : rien n'est prouvé du moteur réel.
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
AUTOTEST = os.path.dirname(HERE)
ROOT = os.path.dirname(os.path.dirname(AUTOTEST))

# (nom, motif exact dans vram.py, remplacement). Le témoin nul remplace un motif par lui-même.
TEMOIN = ("temoin nul (copie intacte)", 'tot["bas"] += tot["virtuel_bas"]', 'tot["bas"] += tot["virtuel_bas"]')
MUTANTS = [
    # Les 14 mutants du constructeur, inchangés.
    ("virtuel hors du total bas", 'tot["bas"] += tot["virtuel_bas"]', 'tot["bas"] += 0'),
    ("virtuel hors du total haut", 'tot["haut"] += tot["virtuel_haut"]', 'tot["haut"] += 0'),
    ("mipmaps 1/4 au lieu de 1/3", 'mip_px = max(px, mip["w"] * mip["h"]) / 3.0', 'mip_px = max(px, mip["w"] * mip["h"]) / 4.0'),
    ("mipmaps sur les pages seules", 'mip_px = max(px, mip["w"] * mip["h"]) / 3.0', "mip_px = px / 3.0"),
    ("bas avec mipmaps", '"bas": px * b_lo,', '"bas": (px + mip_px) * b_lo,'),
    ("pages non compressees comptees", 'b_lo, b_hi, _ = bpp_range(["none"], r.get("dxt"))', "b_lo, b_hi = 4.0, 4.0"),
    ("appariement des mipmaps au dernier", 'mip = mips[i] if i < len(mips) else None', 'mip = mips[-1] if mips else None'),
    ("plafond sans partage", 'plafond = d["max"] + (p["max"] if p else 0.0)', 'plafond = d["max"]'),
    ("exclusion inversee", '"nc_exclue": plancher_nc > plafond', '"nc_exclue": plancher_nc < plafond'),
    ("non compresse a 1 octet", '"non_compresse": 4.0 * px,', '"non_compresse": 1.0 * px,'),
    ("singulier compte", 'r["virtual_page_lines"] += 1\n            continue',
     'r["virtual_page_lines"] += 1\n            r["virtual_atlases"].append({"w": 4096, "h": 4096, "pages": 1})\n'
     '            continue'),
    ("mipmaps virtuelles sans ancrage", r'RE_VIRTUAL_MIP = re.compile(r"^\s*\d+\.\d+ Generated',
     r'RE_VIRTUAL_MIP = re.compile(r".*Generated'),
    ("chiffre moteur sans ancrage", r'RE_ATLAS_MEM = re.compile(r"^\s*\d+\.\d+ Atlas', r'RE_ATLAS_MEM = re.compile(r".*Atlas'),
    ("categorie virtuelle absente", "    if virt:\n        cats[VIRTUEL]", "    if False:\n        cats[VIRTUEL]"),
    # Mutants du correcteur (défaut 2) : ancrages non éprouvés et base du verdict D4-1.
    ("singulier sans ancrage", r'RE_VIRTUAL_PAGE = re.compile(r"^\s*\d+\.\d+ Created',
     r'RE_VIRTUAL_PAGE = re.compile(r".*Created'),
    ("hors atlas sans ancrage", r'RE_OUTSIDE = re.compile(r"^\s*\d+\.\d+ Size', r'RE_OUTSIDE = re.compile(r".*Size'),
    ("verdict D4-1 sur les atlas seuls", 'verdict = "TENU" if t["haut"] <= seuil_go * GO',
     'verdict = "TENU" if t["atlas_haut"] <= seuil_go * GO'),
    # Mutants du correcteur : pages virtuelles et atlas bitmap mélangés.
    ("pixels virtuels dans les pixels bitmap", 'tot["bas"] += tot["virtuel_bas"]',
     'tot["bas"] += tot["virtuel_bas"]\n    tot["pixels"] += tot["pixels_virtuels"]'),
]
RE_BILAN = re.compile(r"BILAN unitaire : (\d+) OK, (\d+) ECHEC")


def copie(work, name, old, new):
    """Copie des modules de tools/autotest, vram.py muté. Renvoie le dossier, ou None si le motif n'est pas unique."""
    d = os.path.join(work, "m")
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    for f in sorted(glob.glob(os.path.join(AUTOTEST, "*.py"))):
        shutil.copy(f, d)
    p = os.path.join(d, "vram.py")
    with open(p, encoding="utf-8", newline="") as fh:
        text = fh.read()
    if text.count(old) != 1:
        print("%-42s MOTIF TROUVE %d FOIS (attendu 1) : banc a revoir" % (name, text.count(old)))
        return None
    with open(p, "w", encoding="utf-8", newline="") as fh:
        fh.write(text.replace(old, new))
    return d


def joue(d, fixture):
    """Joue unit_vram.py sur la copie : ('survit'|'controle'|'plantage', détail)."""
    res = subprocess.run([sys.executable, "-B", os.path.join(HERE, "unit_vram.py"), d, fixture],
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    m = RE_BILAN.search(res.stdout)
    if m and int(m.group(2)) > 0:
        return "controle", "%s ECHEC(S) : %s" % (m.group(2), "; ".join(
            ln[6:] for ln in res.stdout.splitlines() if ln.startswith("ECHEC "))[:110])
    if m and res.returncode == 0:
        return "survit", "%s OK" % m.group(1)
    last = (res.stderr.strip().splitlines() or ["code %d sans BILAN" % res.returncode])[-1]
    return "plantage", last[:110]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", help="dossier de travail (defaut : dossier temporaire neuf, efface a la fin)")
    ap.add_argument("--lua", default="lua5.2", help="interprete Lua 5.2 (defaut : lua5.2 du PATH)")
    a = ap.parse_args()
    work = os.path.abspath(a.work) if a.work else tempfile.mkdtemp(prefix="fo-mut-vram-")
    fixture = os.path.join(work, "fixture")
    os.makedirs(fixture, exist_ok=True)
    lua = shutil.which(a.lua) or a.lua
    rc1 = subprocess.run([lua, os.path.join(HERE, "d4_dryrun.lua"), ROOT, os.path.join(fixture, "factorio.log")],
                         capture_output=True).returncode
    rc2 = subprocess.run([sys.executable, "-B", os.path.join(HERE, "make_fixtures.py"), fixture],
                         capture_output=True).returncode
    if rc1 or rc2:
        print("ECHEC : fixtures non produites (d4_dryrun.lua code %d, make_fixtures.py code %d)" % (rc1, rc2))
        return 1
    d = copie(work, *TEMOIN)
    etat, detail = joue(d, fixture) if d else ("motif", "")
    print("%-42s %s (%s)" % (TEMOIN[0], "SURVIT, attendu" if etat == "survit" else "ECHEC : " + etat.upper(), detail))
    if etat != "survit":
        print("BILAN mutations vram : temoin nul NON survivant, aucun mutant juge (banc invalide)")
        return 1
    det = plant = surv = absents = 0
    for name, old, new in MUTANTS:
        d = copie(work, name, old, new)
        if d is None:
            absents += 1
            continue
        etat, detail = joue(d, fixture)
        if etat == "controle":
            det += 1
            print("%-42s DETECTE par un controle (%s)" % (name, detail))
        elif etat == "plantage":
            plant += 1
            print("%-42s DETECTE par un PLANTAGE (%s)" % (name, detail))
        else:
            surv += 1
            print("%-42s SURVIT (%s)" % (name, detail))
    if not a.work:
        shutil.rmtree(work, ignore_errors=True)
    else:
        shutil.rmtree(os.path.join(work, "m"), ignore_errors=True)
    n = len(MUTANTS)
    print("BILAN mutations vram : temoin nul survivant ; %d/%d mutants detectes (%d par un controle, %d par un plantage),"
          " %d survivant(s), %d motif(s) introuvable(s)" % (det + plant, n, det, plant, surv, absents))
    return 0 if det + plant == n and not absents else 1


if __name__ == "__main__":
    sys.exit(main())
