#!/usr/bin/env python3
"""Tests de bp2lua.py (lot IA1-c) : aller-retour d'un plan, décalage au coin nord-ouest, tri, recettes, refus.

    py -3.9 -B tools/team/test_bp2lua.py   -> « BILAN : n OK, 0 ECHEC(S) »
Le gabarit produit est en plus contrôlé par le modèle Lua (lua5.2, depuis Git Bash) s'il est présent.
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bp2lua  # noqa: E402

ok = fail = 0


def check(cond, msg):
    global ok, fail
    if cond:
        ok += 1
    else:
        fail += 1
        print("  ECHEC : " + msg)


# Un engrenage simple, dessiné en jeu autour de (100, 50) : tapis au nord, bras, assembleur 2, bras, tapis au sud.
plan = {"blueprint": {"item": "blueprint", "label": "Engrenages DC", "version": 281479278886912, "entities": [
    {"entity_number": 1, "name": "transport-belt", "position": {"x": 99.5, "y": 49.5}, "direction": 2},
    {"entity_number": 2, "name": "transport-belt", "position": {"x": 100.5, "y": 49.5}, "direction": 2},
    {"entity_number": 3, "name": "transport-belt", "position": {"x": 101.5, "y": 49.5}, "direction": 2},
    {"entity_number": 4, "name": "fast-inserter", "position": {"x": 99.5, "y": 50.5}},
    {"entity_number": 5, "name": "assembling-machine-2", "position": {"x": 100.5, "y": 52.5}, "recipe": "iron-gear-wheel"},
    {"entity_number": 6, "name": "fast-inserter", "position": {"x": 99.5, "y": 54.5}},
    {"entity_number": 7, "name": "medium-electric-pole", "position": {"x": 100.5, "y": 50.5}},
    {"entity_number": 11, "name": "medium-electric-pole", "position": {"x": 100.5, "y": 54.5}},
    {"entity_number": 8, "name": "transport-belt", "position": {"x": 99.5, "y": 55.5}, "direction": 2},
    {"entity_number": 9, "name": "transport-belt", "position": {"x": 100.5, "y": 55.5}, "direction": 2},
    {"entity_number": 10, "name": "transport-belt", "position": {"x": 101.5, "y": 55.5}, "direction": 2},
]}}
s = bp2lua.encode(plan)
check(s.startswith("0"), "chaîne de plan : version 0")
back = bp2lua.decode(s)
check(back == plan, "aller-retour base64 + zlib + json")
g = bp2lua.to_gabarit(back, "engrenages-dc")
check(g["entities"][0]["x"] == 0.5 and g["entities"][0]["y"] == 0.5, "coin nord-ouest en (0, 0)")
am = [e for e in g["entities"] if e["name"] == "assembling-machine-2"][0]
check(am["x"] == 1.5 and am["y"] == 3.5 and am["recipe"] == "iron-gear-wheel", "assembleur 3 × 3 centré en (1,5 ; 3,5), recette gardée")
check([e["y"] for e in g["entities"]] == sorted(e["y"] for e in g["entities"]), "entités triées par rangée")
lua = bp2lua.to_lua(g)
check('name = "assembling-machine-2", x = 1.5, y = 3.5, dir = 0, recipe = "iron-gear-wheel"' in lua, "sortie Lua lisible")
try:
    bp2lua.decode("1abc")
    check(False, "version inconnue refusée")
except ValueError:
    check(True, "version inconnue refusée")
try:
    bp2lua.to_gabarit({"blueprint": {"entities": []}}, "vide")
    check(False, "plan vide refusé")
except ValueError:
    check(True, "plan vide refusé")

# Correction IA1-c (mineur 6) : un bâtiment à niveaux prend son emprise ACTUELLE (assembleur de niveau 7 : 4 × 4),
# lue dans le modèle Lua ; un nom de niveau inconnu refuse le plan. Assembleur de niveau 7 centré en (10, 10), bras au
# nord : coin nord-ouest en (8, 7) si le côté est 4 (en (9,5 ; 7) s'il était compté 1 × 1).
plan7 = {"blueprint": {"entities": [
    {"entity_number": 1, "name": "fo-lvl-assembler-7", "position": {"x": 10, "y": 10}, "recipe": "iron-gear-wheel"},
    {"entity_number": 2, "name": "fast-inserter", "position": {"x": 9.5, "y": 7.5}},
]}}
try:
    g7 = bp2lua.to_gabarit(plan7, "n7")
    a7 = [e for e in g7["entities"] if e["name"] == "fo-lvl-assembler-7"][0]
    check(a7["x"] == 2 and a7["y"] == 3 and "fo-lvl-assembler-7" not in g7["unknown"],
          "assembleur de niveau 7 : emprise 4 × 4 lue dans le modèle, centre en (2, 3) (" + repr(a7) + ")")
except ValueError as ex:
    check(False, "assembleur de niveau 7 : " + str(ex))
try:
    bp2lua.to_gabarit({"blueprint": {"entities": [
        {"entity_number": 1, "name": "fo-lvl-assembler-99", "position": {"x": 0.5, "y": 0.5}}]}}, "x")
    check(False, "bâtiment à niveaux inconnu refusé")
except ValueError:
    check(True, "bâtiment à niveaux inconnu refusé")

# Contrôle par le modèle Lua : le gabarit converti, complété de ses ports, passe M.check.
root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
import shutil  # noqa: E402
lua_exe = shutil.which("lua5.2") or shutil.which("lua5.2.exe") or os.environ.get("FO_LUA") or "lua5.2"
if not shutil.which(lua_exe) and os.path.exists(os.path.expanduser(r"~\bin\lua5.2.exe")):
    lua_exe = os.path.expanduser(r"~\bin\lua5.2.exe")   # emplacement de CLAUDE.md §5
with tempfile.TemporaryDirectory() as d:
    f = os.path.join(d, "g.lua")
    with open(f, "w", encoding="utf-8") as h:
        h.write(lua)
    script = (
        'package.path = "./?.lua;" .. package.path\n'
        'local M = require("shared.team.modules")\n'
        'local g = dofile([[' + f + ']])\n'
        'g.w, g.h = 3, 7\n'
        'g.ports = { { kind = "tapis", io = "in", ent = 1, lanes = { "iron-plate", "iron-plate" } }, { kind = "tapis", io = "out", ent = #g.entities } }\n'
        'for i, e in ipairs(g.entities) do if e.name == "medium-electric-pole" then g.power_pole = i end end\n'
        'g.anchors = { { x = 1.5, y = -2 }, { x = 1.5, y = 9 } }\n'
        'local e1 = M.check(g)\n'
        'print("PLEINE CADENCE " .. (e1[1] or "OK"))\n'
        'for _, e in ipairs(g.entities) do if e.name == "assembling-machine-2" then e.rate = 0.75 end end\n'
        'local errs = M.check(g)\n'
        'print(#errs == 0 and "MODELE OK" or ("MODELE " .. errs[1]))\n'
    )
    try:
        r = subprocess.run([lua_exe, "-e", script], cwd=root, capture_output=True, text=True, encoding="utf-8", timeout=60)
        outp = (r.stdout + r.stderr).strip()
        # un seul bras rapide ne nourrit pas un assembleur 2 d'engrenages à pleine cadence (3 fer/s) : le modèle le dit
        check("PLEINE CADENCE" in outp and "débit de iron-plate" in outp, "pleine cadence refusée par M.check (" + outp[:160] + ")")
        check("MODELE OK" in outp, "à mi-cadence, gabarit converti accepté par M.check (" + outp[-200:] + ")")
    except FileNotFoundError:
        print("  (lua5.2 absent du PATH : contrôle par le modèle sauté ; lancer depuis Git Bash)")

print("BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(0 if fail == 0 else 1)
