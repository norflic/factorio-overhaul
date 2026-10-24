#!/usr/bin/env python3
"""bp2lua.py : convertit un plan Factorio 1.1 (chaîne exportée du jeu) en gabarit Lua pour shared/team/modules.lua.

Option du lot IA1-c (docs/EQUIPES_PNJ.md §6.4, Q-IA1-4) : le Directeur Créatif dessine un module en jeu, l'exporte
(« Exporter dans une chaîne »), puis :

    py -3.9 tools/team/bp2lua.py plan.txt --key mon-module > mon-module.lua

La sortie est une table Lua { key, name_fr, entities = { { name, x, y, dir, recipe } }, ports = {} } en coordonnées
de gabarit (coin nord-ouest de l'emprise en (0, 0), centres en demi-tuiles). Les PORTS et les points d'appui ne sont
pas dans un plan : ils s'ajoutent à la main, puis `M.check` (lua5.2) dit ce qui manque. Bibliothèque standard
seulement (base64, zlib, json).

Format d'un plan 1.1 : un caractère de version ("0"), puis base64( zlib( json ) ).
"""
import argparse
import base64
import json
import math
import os
import shutil
import subprocess
import sys
import zlib

# Côtés (largeur, hauteur) au nord des entités usuelles ; inconnue : 1 × 1 (signalée en commentaire).
SIZES = {
    "stone-furnace": (2, 2), "steel-furnace": (2, 2), "burner-mining-drill": (2, 2),
    "assembling-machine-1": (3, 3), "assembling-machine-2": (3, 3), "assembling-machine-3": (3, 3),
    "chemical-plant": (3, 3), "lab": (3, 3), "electric-mining-drill": (3, 3), "pumpjack": (3, 3),
    "storage-tank": (3, 3), "radar": (3, 3), "oil-refinery": (5, 5), "boiler": (3, 2), "steam-engine": (3, 5),
    "splitter": (2, 1), "fast-splitter": (2, 1), "express-splitter": (2, 1), "big-electric-pole": (2, 2),
    "substation": (2, 2), "electric-energy-interface": (2, 2),
}


def decode(text):
    """Chaîne de plan → dictionnaire JSON."""
    text = text.strip()
    if not text or text[0] != "0":
        raise ValueError("version de plan inconnue (attendu '0', vu %r)" % text[:1])
    raw = zlib.decompress(base64.b64decode(text[1:]))
    return json.loads(raw.decode("utf-8"))


def encode(obj):
    """Dictionnaire JSON → chaîne de plan (pour les tests)."""
    raw = json.dumps(obj, separators=(",", ":")).encode("utf-8")
    return "0" + base64.b64encode(zlib.compress(raw, 9)).decode("ascii")


LEVEL_PREFIX = "fo-lvl-"
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def _lua_exe():
    exe = os.environ.get("FO_LUA") or shutil.which("lua5.2") or shutil.which("lua5.2.exe")
    home_lua = os.path.join(os.path.expanduser("~"), "bin", "lua5.2.exe")   # emplacement de CLAUDE.md §5
    if not exe and os.path.exists(home_lua):
        exe = home_lua
    return exe


def level_sizes(names, lua_exe=None):
    """Côtés ACTUELS des bâtiments à niveaux (fo-lvl-<famille>-<n>) : lus dans le modèle Lua (M.spec, qui suit
    L.footprint de shared/levels/config.lua). Correction IA1-c (mineur 6 de la vérification adverse) : avant, un
    bâtiment à niveaux était compté 1 × 1, ce qui décalait l'origine et l'emprise du gabarit. Sans lua5.2, ou pour
    un nom inconnu du modèle : ValueError (plan refusé plutôt que faux)."""
    names = sorted(set(names))
    if not names:
        return {}
    exe = lua_exe or _lua_exe()
    if not exe:
        raise ValueError("bâtiments à niveaux dans le plan (%s) : lua5.2 introuvable pour lire leurs emprises "
                         "(lancer depuis Git Bash, ou FO_LUA=<chemin de lua5.2.exe>)" % ", ".join(names))
    # séparateur « | » (aucun nom d'entité n'en contient) ; lignes jointes par chr(10)
    script = chr(10).join([
        'package.path = "./?.lua;" .. package.path',
        'local M = require("shared.team.modules")',
        'for _, n in ipairs({' + ",".join(json.dumps(n) for n in names) + '}) do',
        '  local s = M.spec(n)',
        '  print(n .. "|" .. (s and (s.w .. "|" .. s.h) or "?|?"))',
        'end',
    ])
    r = subprocess.run([exe, "-e", script], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=60)
    if r.returncode != 0:
        raise ValueError("lecture des emprises des bâtiments à niveaux impossible : " + (r.stderr or r.stdout).strip()[:300])
    out = {}
    for line in r.stdout.splitlines():
        parts = line.strip().split("|")
        if len(parts) == 3:
            if parts[1] == "?":
                raise ValueError("bâtiment à niveaux inconnu du modèle : " + parts[0])
            out[parts[0]] = (int(parts[1]), int(parts[2]))
    missing = [n for n in names if n not in out]
    if missing:
        raise ValueError("emprises non lues : " + ", ".join(missing))
    return out


def size_of(name, direction, extra=None):
    w, h = (extra or {}).get(name) or SIZES.get(name, (1, 1))
    if direction in (2, 6):
        w, h = h, w
    return w, h


def to_gabarit(bp, key, lua_exe=None):
    """Plan (dictionnaire 'blueprint') → gabarit (dictionnaire Python) ; entités triées par (y, x, nom). Les
    bâtiments à niveaux prennent leur emprise ACTUELLE (level_sizes)."""
    if "blueprint" in bp:
        bp = bp["blueprint"]
    ents = bp.get("entities", [])
    if not ents:
        raise ValueError("plan sans entité")
    extra = level_sizes([e["name"] for e in ents if e["name"].startswith(LEVEL_PREFIX)], lua_exe)
    x0 = y0 = math.inf
    for e in ents:
        w, h = size_of(e["name"], e.get("direction", 0), extra)
        x0 = min(x0, e["position"]["x"] - w / 2)
        y0 = min(y0, e["position"]["y"] - h / 2)
    x0, y0 = math.floor(x0 + 1e-9), math.floor(y0 + 1e-9)
    out = []
    unknown = sorted({e["name"] for e in ents if e["name"] not in SIZES and e["name"] not in extra and not _one_by_one(e["name"])})
    for e in ents:
        d = {"name": e["name"], "x": e["position"]["x"] - x0, "y": e["position"]["y"] - y0, "dir": e.get("direction", 0)}
        if e.get("recipe"):
            d["recipe"] = e["recipe"]
        if e.get("type"):
            d["type"] = e["type"]
        out.append(d)
    out.sort(key=lambda d: (d["y"], d["x"], d["name"]))
    return {"key": key, "name_fr": bp.get("label", key), "entities": out, "unknown": unknown}


def _one_by_one(name):
    return any(s in name for s in ("belt", "inserter", "pipe", "chest", "electric-pole", "wall", "lamp", "combinator"))


def _num(v):
    return ("%d" % v) if v == int(v) else repr(float(v))


def to_lua(g):
    lines = ["-- Gabarit converti par tools/team/bp2lua.py : ajouter les ports, les points d'appui et w, h, puis M.check."]
    if g["unknown"]:
        lines.append("-- Entités de taille inconnue de bp2lua (comptées 1 × 1) : " + ", ".join(g["unknown"]))
    lines.append("return {")
    lines.append('  key = "%s",' % g["key"])
    lines.append('  name_fr = %s,' % json.dumps(g["name_fr"], ensure_ascii=False))
    lines.append("  entities = {")
    for e in g["entities"]:
        extra = ""
        if "recipe" in e:
            extra += ', recipe = "%s"' % e["recipe"]
        if "type" in e:
            extra += ', type = "%s"' % e["type"]
        lines.append('    { name = "%s", x = %s, y = %s, dir = %d%s },' % (e["name"], _num(e["x"]), _num(e["y"]), e["dir"], extra))
    lines.append("  },")
    lines.append("  ports = {},")
    lines.append("  anchors = {},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("plan", help="fichier contenant la chaîne du plan (ou '-' pour l'entrée standard)")
    ap.add_argument("--key", default="module-dc", help="clé du gabarit")
    a = ap.parse_args(argv)
    text = sys.stdin.read() if a.plan == "-" else open(a.plan, encoding="utf-8").read()
    sys.stdout.write(to_lua(to_gabarit(decode(text), a.key)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
