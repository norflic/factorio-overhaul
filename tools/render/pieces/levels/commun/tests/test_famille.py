"""TEST du choix de famille des outils communs (lot K0, correction du défaut 1 de la vérification, 23/10). Python 3.9,
hors Blender (numpy, Pillow, comme compo.py).

    py -3.9 tools/render/pieces/levels/commun/tests/test_famille.py

Famille factice tests/fam_essai (emprise 1×1 à tous les âges, un trou voulu), dont le profil fait « import epoques »
comme gun_e/profil.py. Chaque cas tourne dans un processus Python NEUF (sys.modules vierge) :
  A  --famille : compo importé SANS FO_FAMILLE (gun_e chargé à l'import), puis utiliser(fam_essai) ;
  B  FO_FAMILLE=fam_essai : compo importé avec la variable ;
  C  aller-retour : utiliser(fam_essai), utiliser(gun_e), utiliser(fam_essai) ;
  D  un script qui a déjà importé gun_e/epoques (comme les scripts de gun_e) puis famille.charger(fam_essai)
     (chemin de dominance.py) ;
  E  témoin : sans rien choisir, la mitrailleuse (comportement d'avant le lot K0).
A et B doivent donner EXACTEMENT le même résultat. Avant la correction, A rendait l'epoques de gun_e (COTE[5] = 3).
Sortie : une ligne par contrôle, puis « [K0-FAMILLE] N OK, M ECHEC(S) » ; code 1 en cas d'échec.
"""
import json
import os
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
COMMUN = os.path.dirname(ICI)
LEVELS = os.path.dirname(COMMUN)
FIX = os.path.join(ICI, "fam_essai")
GUN = os.path.join(LEVELS, "gun_e")

ETAT = r"""
import json, os, sys
def etat(K, P):
    E = sys.modules.get("epoques")
    return dict(profil=P.NOM, epoques_profil=os.path.normcase(os.path.abspath(P.E.__file__)),
                epoques_sys=os.path.normcase(os.path.abspath(E.__file__)) if E else None,
                cote5=P.COTE[5], side5=(K.SIDE.get(5) if K else None),
                trous=sorted("%s" % (k,) for k in P.TROUS_VOULUS))
"""

CAS = {
    "A": ETAT + r"""
sys.path.insert(0, COMMUN)
import compo as K
P = K.utiliser(FIX)
print("JSON" + json.dumps(etat(K, P)))
""",
    "B": ETAT + r"""
sys.path.insert(0, COMMUN)
import compo as K
P = K.utiliser(None)
assert K.PROFIL is P
print("JSON" + json.dumps(etat(K, P)))
""",
    "C": ETAT + r"""
sys.path.insert(0, COMMUN)
import compo as K
r = [etat(K, K.utiliser(FIX)), etat(K, K.utiliser("gun_e")), etat(K, K.utiliser(FIX))]
print("JSON" + json.dumps(r))
""",
    "D": ETAT + r"""
sys.path.insert(0, GUN)
import epoques as GE          # un script de gun_e a déjà importé SON epoques
sys.path.insert(0, COMMUN)
import famille as FAM
P = FAM.charger(FIX)
print("JSON" + json.dumps(etat(None, P)))
""",
    "E": ETAT + r"""
sys.path.insert(0, COMMUN)
import compo as K
print("JSON" + json.dumps(etat(K, K.PROFIL)))
""",
}


def lancer(cas, fo_famille=None):
    env = dict(os.environ)
    env.pop("FO_FAMILLE", None)
    if fo_famille:
        env["FO_FAMILLE"] = fo_famille
    env["PYTHONUTF8"] = "1"
    code = "COMMUN = %r\nFIX = %r\nGUN = %r\n" % (COMMUN, FIX, GUN) + CAS[cas]
    p = subprocess.run([sys.executable, "-c", code], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                       encoding="utf-8", errors="replace", env=env, cwd=ICI)
    for ligne in p.stdout.splitlines():
        if ligne.startswith("JSON"):
            return json.loads(ligne[4:])
    raise SystemExit("cas %s : pas de résultat (code %d)\n%s" % (cas, p.returncode, p.stdout))


def main():
    fix_e = os.path.normcase(os.path.abspath(os.path.join(FIX, "epoques.py")))
    gun_e = os.path.normcase(os.path.abspath(os.path.join(GUN, "epoques.py")))
    ok = ko = 0

    def ctrl(nom, cond, detail=""):
        nonlocal ok, ko
        if cond:
            ok += 1
        else:
            ko += 1
        print("%s %s%s" % ("OK    " if cond else "ECHEC ", nom, (" : " + detail) if detail and not cond else ""))

    a = lancer("A")
    b = lancer("B", fo_famille=FIX)
    c = lancer("C")
    d = lancer("D")
    e = lancer("E")
    print("A (--famille)      :", a)
    print("B (FO_FAMILLE)     :", b)
    ctrl("A : le profil lit l'epoques de SA famille", a["epoques_profil"] == fix_e, a["epoques_profil"])
    ctrl("A : sys.modules['epoques'] est celui de la famille", a["epoques_sys"] == fix_e, str(a["epoques_sys"]))
    ctrl("A : COTE[5] = 1", a["cote5"] == 1, str(a["cote5"]))
    ctrl("A : compo.SIDE[5] = 1", a["side5"] == 1, str(a["side5"]))
    ctrl("A : trous voulus de la famille", a["trous"] == ["(5, 'essai')"], str(a["trous"]))
    ctrl("B : COTE[5] = 1 et compo.SIDE[5] = 1", b["cote5"] == 1 and b["side5"] == 1, str(b))
    ctrl("A et B identiques (--famille contre FO_FAMILLE)", a == b, "%s / %s" % (a, b))
    ctrl("C : fam_essai puis gun_e puis fam_essai : SIDE[5] = 1, 3, 1",
         [x["side5"] for x in c] == [1, 3, 1], str([x["side5"] for x in c]))
    ctrl("C : epoques suit la famille à chaque changement",
         [x["epoques_sys"] for x in c] == [fix_e, gun_e, fix_e], str([x["epoques_sys"] for x in c]))
    ctrl("C : retour sur fam_essai identique au premier chargement", c[0] == c[2], "%s / %s" % (c[0], c[2]))
    ctrl("D : epoques de gun_e déjà importé, famille.charger(fam_essai) lit le sien",
         d["epoques_profil"] == fix_e and d["cote5"] == 1, str(d))
    ctrl("E : sans choix, la mitrailleuse (COTE[5] = 3, epoques de gun_e)",
         e["profil"] == "gun_e" and e["side5"] == 3 and e["epoques_profil"] == gun_e, str(e))
    print("[K0-FAMILLE] %d OK, %d ECHEC(S)" % (ok, ko))
    sys.exit(1 if ko else 0)


if __name__ == "__main__":
    main()
