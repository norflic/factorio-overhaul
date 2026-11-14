"""s43 scen-moteur : lanceur des scénarios en boucle fermée (format : shared/scenarios/format.lua).

Joue une liste de scénarios par banc.py, UN ticket à la fois (chaque banc attend la fin du précédent), lit les lignes
[FO-SCEN] du journal du banc, juge les prédicats « ligne » (regex sur le journal, entre deux marques de relevé) et écrit
le bilan <out>/bilan.txt (et l'affiche).

Usage (depuis la racine de la source du mod jouée) :
  py -3.9 -B tools/autotest/scenarios_loop.py --out <dossier neuf> [--graine N ...] [--qui s43-xxx] [--source <mod>]
         [--lire] <id> [<id> ...]
  <id> = fichier shared/scenarios/<id>.lua (ex. famine_fer_attaque) ; le banc joue le greffon scen-<nom>.
  --graine : une ou plusieurs graines (panel) ; chaque (scénario, graine) est un banc, joué dans l'ordre.
  --lire : ne lance rien, relit les journaux déjà dans <out>/<id>-g<graine>/ (rejuger après une correction du lanceur).
  La racine du jeu : variable FO_ROOT, sinon banc.py la trouve en remontant depuis son fichier.
Lua : lua5.2 (même interpréteur que tests/run.lua) lit la déclaration (nom, ticks, prédicats « ligne »).
"""
import argparse
import gzip
import os
import re
import shutil
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
TAG = "[FO-SCEN]"

LUA_EXPORT = r"""
package.path = './?.lua;' .. package.path
local F = require('shared.scenarios.format')
local S = require('shared.scenarios.' .. SID)
local e = F.valider(S)
if e then io.stderr:write(e .. '\n'); os.exit(2) end
print('nom\t' .. S.nom)
print('ticks\t' .. F.ticks(S))
for _, att in ipairs(S.theorie) do
  local p = att.predicat
  if p.type == 'ligne' then
    print(table.concat({ 'ligne', att.id, p.motif, p.de, p.a, p.fn or 'nombre', p.op, p.valeur }, '\t'))
  end
end
"""

OPS = {"<": lambda x, v: x < v, "<=": lambda x, v: x <= v, "==": lambda x, v: x == v,
       ">=": lambda x, v: x >= v, ">": lambda x, v: x > v, "~=": lambda x, v: x != v}


def lua_exe():
    """FO_LUA, sinon lua5.2 dans le PATH, sinon ~/bin/lua5.2.exe (installation de ce poste)."""
    for c in (os.environ.get("FO_LUA"), shutil.which("lua5.2"), os.path.expanduser(os.path.join("~", "bin", "lua5.2.exe"))):
        if c and os.path.isfile(c):
            return c
    raise SystemExit("[SCEN] lua5.2 introuvable (variable FO_LUA)")


def lire_declaration(source, sid):
    if not re.fullmatch(r"[a-z0-9_]+", sid):
        raise SystemExit(f"[SCEN] id de scenario invalide : {sid!r} (minuscules, chiffres, soulignés)")
    r = subprocess.run([lua_exe(), "-e", f"SID = '{sid}'" + LUA_EXPORT], cwd=source, capture_output=True, text=True, input="")
    if r.returncode != 0:
        raise SystemExit(f"[SCEN] declaration {sid} invalide : {r.stderr.strip() or r.stdout.strip()}")
    d = {"lignes": []}
    for l in r.stdout.splitlines():
        c = l.split("\t")
        if c[0] == "nom":
            d["nom"] = c[1]
        elif c[0] == "ticks":
            d["ticks"] = int(c[1])
        elif c[0] == "ligne":
            d["lignes"].append({"id": c[1], "motif": c[2], "de": int(c[3]), "a": int(c[4]), "fn": c[5], "op": c[6],
                                "valeur": float(c[7])})
    return d


def journal(dossier):
    for n in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(dossier, n)
        if os.path.exists(p):
            op = gzip.open if n.endswith(".gz") else open
            with op(p, "rt", encoding="utf-8", errors="replace") as f:
                return f.read().splitlines()
    return []


def num(x):
    if x is None:
        return "nil"
    return "%d" % x if float(x).is_integer() else "%.2f" % x


def juger_lignes(nom, decl, lignes):
    """Prédicats « ligne » : rend la liste des lignes de verdict, au format du jeu."""
    re_rel = re.compile(r"\[FO-SCEN\] " + re.escape(nom) + r" releve min (\d+) (\S+) \|")
    debut = {}  # minute -> indice de la première marque de relevé
    equipes = []
    for i, l in enumerate(lignes):
        m = re_rel.search(l)
        if m:
            debut.setdefault(int(m.group(1)), i)
            if m.group(2) not in equipes:
                equipes.append(m.group(2))
    out = []
    for p in decl["lignes"]:
        i0 = debut.get(p["de"])
        i1 = debut.get(p["a"] + 1, len(lignes))
        for k in sorted(equipes):
            if i0 is None:
                etat, x = "ECHEC", None
            else:
                rx = re.compile(p["motif"].replace("{equipe}", re.escape(k)))
                vals = []
                for l in lignes[i0:i1]:
                    m = rx.search(l)
                    if m:
                        vals.append(1.0 if p["fn"] == "nombre" else float(m.group(1)))
                if p["fn"] == "nombre":
                    x = float(len(vals))
                elif not vals:
                    x = None
                else:
                    x = {"max": max, "min": min, "somme": sum}[p["fn"]](vals)
                etat = "OK" if x is not None and OPS[p["op"]](x, p["valeur"]) else "ECHEC"
            out.append(f"{TAG} {nom} min {p['a']} | attendu {p['id']}@{k} : {etat} {num(x)} "
                       f"(attendu {p['fn']} {p['op']} {num(p['valeur'])}) [lanceur]")
    return out


def bilan_scenario(nom, decl, lignes):
    jeu = [l[l.index(TAG):] for l in lignes if TAG + " " + nom + " " in l and " releve min " not in l]
    verdicts = [l for l in jeu if "| attendu " in l and "EN ATTENTE" not in l] + juger_lignes(nom, decl, lignes)
    scenes = [l for l in jeu if "| mise en scene " in l]
    autres = [l for l in jeu if "| attendu " not in l and "| mise en scene " not in l]
    par_id = {}
    for l in verdicts:
        m = re.search(r"\| attendu ([a-z0-9-]+)@(\S+) : (OK|ECHEC)", l)
        if m:
            par_id.setdefault(m.group(1), {"OK": 0, "ECHEC": 0})[m.group(3)] += 1
    return verdicts, scenes, autres, par_id


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--graine", nargs="+", default=["123456789"])
    ap.add_argument("--qui", default="scenarios-loop")
    ap.add_argument("--source", default=os.path.abspath(os.path.join(ICI, "..", "..")))
    ap.add_argument("--lire", action="store_true")
    ap.add_argument("ids", nargs="+")
    a = ap.parse_args(argv)
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    rapport = []
    total = {"OK": 0, "ECHEC": 0}
    for sid in a.ids:
        decl = lire_declaration(a.source, sid)
        for g in a.graine:
            d = os.path.join(out, f"{sid}-g{g}")
            code = None
            if not a.lire:
                cmd = [sys.executable, "-B", os.path.join(ICI, "banc.py"), "--out", d, "--graine", g, "--qui", a.qui,
                       "--", str(decl["ticks"]), "scen-" + decl["nom"], a.source]
                print("[SCEN] " + " ".join(cmd), flush=True)
                code = subprocess.run(cmd).returncode
            lignes = journal(d)
            verdicts, scenes, autres, par_id = bilan_scenario(decl["nom"], decl, lignes)
            rapport.append(f"== {decl['nom']} (shared/scenarios/{sid}.lua), graine {g}, {decl['ticks']} ticks"
                           + (f", code du banc {code}" if code is not None else "") + f", journal {len(lignes)} lignes")
            if not lignes:
                rapport.append("   AUCUN JOURNAL : banc non joue ou plante (voir ECHEC.txt du dossier)")
            rapport += ["   " + l for l in scenes + autres + verdicts]
            for k in sorted(par_id):
                rapport.append(f"   -> {k} : {par_id[k]['OK']} OK, {par_id[k]['ECHEC']} ECHEC")
                total["OK"] += par_id[k]["OK"]
                total["ECHEC"] += par_id[k]["ECHEC"]
    rapport.append(f"BILAN scenarios_loop : {total['OK']} OK, {total['ECHEC']} ECHEC")
    txt = "\n".join(rapport) + "\n"
    with open(os.path.join(out, "bilan.txt"), "w", encoding="utf-8") as f:
        f.write(txt)
    print(txt)
    return 0 if total["ECHEC"] == 0 and total["OK"] > 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
