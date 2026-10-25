"""TESTS DU KIT FOREUSE (lot F4-A, 25/10), hors Blender (Python 3.9) :

    py -3.9 tools/render/pieces/levels/foreuse_e/tests/test_foreuse.py      -> « [F4-FOREUSE] N OK, 0 ECHEC(S) », code 0

Contrôle : profil (contrat de commun/famille.py, aller-retour avec gun_e sans contamination) ; emprise par âge contre
shared/levels/config.lua ; points de jeu (sortie du minerai, raccords du fluide, rayon d'extraction) contre la règle de
shared/levels/points.lua (et contre le Lua lui-même si lua5.2 est dans le PATH) ; rotation des 4 directions = rotation des
points par le moteur ; cotes (sommet de la tour sous le bord arrière du tablier à l'écran, goulotte qui pointe le point
de dépôt) ; variantes ; triplets « en 3 mots » (15, aucun mot répété, aucun égal à un triplet de la mitrailleuse ou du
laser) ; fichiers d'âge écrits (TRIPLET, FOYER, HABILLAGE, fonctions obligatoires, lus dans le source sans Blender) ;
matières citées par chaque fichier d'âge (M["…"]) toutes définies (lignée de kit.py, matières de l'âge, alias) ;
nommage (aucun module du kit ne porte le nom d'un module de commun/).
"""
import ast
import math
import os
import re
import shutil
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.dirname(ICI)
LEVELS = os.path.dirname(KIT)
COMMUN = os.path.join(LEVELS, "commun")
MOD = os.path.normpath(os.path.join(LEVELS, "..", "..", "..", ".."))
sys.path.insert(0, COMMUN)
import famille as FAM  # noqa: E402

OK, KO = [], []


def check(nom, cond, detail=""):
    (OK if cond else KO).append(nom)
    print("[F4-FOREUSE] %s %s%s" % ("OK    " if cond else "ECHEC ", nom, (" : " + detail) if detail and not cond else ""))


TRIPLETS_GUN = {
    1: ("sacs", "bois", "bricolé"), 2: ("fer", "boulons", "bouclier"), 3: ("cuivre", "vapeur", "manomètres"),
    4: ("fûts", "jaune", "vannes"), 5: ("blindé", "sombre", "braise"), 6: ("bobines", "isolateurs", "arcs"),
    7: ("bronze", "cristaux", "violet"), 8: ("verre", "bulles", "toxique"), 9: ("plomb", "hublots", "radioactif"),
    10: ("caréné", "câbles", "voyants"), 11: ("ailerons", "effilé", "titane"), 12: ("chrome", "givre", "anneaux"),
    13: ("antimatière", "bouteilles magnétiques", "annihilation"), 14: ("espace profond", "étoiles", "portail"),
    15: ("trou noir", "disque de lumière", "big bang"),
}
VIDES = {"de", "à", "d", "l", "la", "le", "les", "des", "du", "en", "et"}


def mots(triplet):
    out = []
    for t in triplet:
        for m in re.split(r"[\s'’]+", t.lower()):
            if m and m not in VIDES:
                out.append(m)
    return out


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")   # signes − et × sous une console cp1252
    except AttributeError:
        pass
    # --- profil et famille -------------------------------------------------------------------------------------------
    pr = FAM.charger("foreuse_e")
    check("profil : champs du contrat", all(hasattr(pr, k) for k in FAM.CHAMPS))
    import epoques as E
    import cotes
    import piece
    check("profil : epoques chargé depuis foreuse_e", os.path.dirname(os.path.abspath(E.__file__)) == KIT,
          E.__file__)
    gun = FAM.charger("gun_e")
    pr2 = FAM.charger("foreuse_e")
    check("aller-retour gun_e -> foreuse_e : emprise de la foreuse", pr2.COTE[2] == 3 and pr2.COTE[15] == 6
          and gun.COTE[2] != pr2.COTE[2], "%r / %r" % (pr2.COTE.get(2), gun.COTE.get(2)))
    import epoques as E2
    check("aller-retour : epoques n'est pas celui de gun_e", os.path.dirname(os.path.abspath(E2.__file__)) == KIT)
    import importlib
    if KIT not in sys.path:
        sys.path.insert(0, KIT)
    E, cotes, piece = E2, importlib.import_module("cotes"), importlib.import_module("piece")
    check("aller-retour : cotes et piece de foreuse_e",
          os.path.dirname(os.path.abspath(cotes.__file__)) == KIT == os.path.dirname(os.path.abspath(piece.__file__)))

    # --- emprise contre shared/levels/config.lua ----------------------------------------------------------------------
    cfg = open(os.path.join(MOD, "shared", "levels", "config.lua"), encoding="utf-8").read()
    m = re.search(r"\n\s*drill\s*=\s*\{\s*era\s*=\s*\{([^}]*)\}", cfg)
    m2 = re.search(r"L\.ERA_EPOCHS\s*=\s*(\d+)", cfg)
    ok = bool(m and m2)
    if ok:
        era = [int(x) for x in m.group(1).split(",")]
        ne = int(m2.group(1))
        attendu = {e: era[(e - 1) // ne] for e in range(1, 16)}
        ok = all(E.COTE[e] == attendu[e] for e in range(1, 16))
    check("emprise par âge = config.lua (drill, ères de 3 âges)", ok)

    # --- points de jeu -----------------------------------------------------------------------------------------------
    check("sortie 3×3 = vanilla (0 ; 1,85 au nord)", cotes.sortie(3) == (0.0, 1.85), repr(cotes.sortie(3)))
    check("sortie 4×4 = (−0,5 ; 2,35)", cotes.sortie(4) == (-0.5, 2.35), repr(cotes.sortie(4)))
    check("sortie 5×5 = (0 ; 2,85)", cotes.sortie(5) == (0.0, 2.85), repr(cotes.sortie(5)))
    check("sortie 6×6 = (−0,5 ; 3,35)", cotes.sortie(6) == (-0.5, 3.35), repr(cotes.sortie(6)))
    r3, r6 = cotes.raccords(3), cotes.raccords(6)
    check("raccords 3×3 = vanilla", r3 == {"O": (-2.0, 0.0), "E": (2.0, 0.0), "S": (0.0, -2.0)}, repr(r3))
    check("raccords 6×6 (O, E, S)", r6 == {"O": (-3.5, 0.5), "E": (3.5, 0.5), "S": (-0.5, -3.5)}, repr(r6))
    check("rayon d'extraction 3×3 2,49 et 6×6 3,99", abs(cotes.rayon_extraction(3) - 2.49) < 1e-9
          and abs(cotes.rayon_extraction(6) - 3.99) < 1e-9)
    lua = shutil.which("lua5.2")
    if lua:
        prog = ("package.path = %r .. '/?.lua;' .. package.path\n"
                "local P = require('shared.levels.points')\n"
                "for _, b in ipairs({3, 4, 5, 6}) do\n"
                "  for _, p in ipairs({{0, -1.85}, {-2, 0}, {2, 0}, {0, 2}}) do\n"
                "    local q = P.move_point({p[1], p[2]}, 3, b)\n"
                "    print(b, p[1], p[2], q[1] or q.x, q[2] or q.y)\n"
                "  end\n"
                "end\n") % MOD.replace("\\", "/")
        try:
            out = subprocess.run([lua, "-"], input=prog, capture_output=True, text=True, timeout=30, cwd=MOD).stdout
            lignes = [l.split() for l in out.strip().splitlines()]
            bon = len(lignes) == 16
            for l in lignes:
                b, x, y, qx, qy = int(l[0]), float(l[1]), float(l[2]), float(l[3]), float(l[4])
                px, py = cotes.point_jeu((x, y), b)
                bon = bon and abs(px - qx) < 1e-9 and abs(py - qy) < 1e-9
            check("points de jeu = shared/levels/points.lua (lua5.2, 16 cas)", bon, out[:300])
        except Exception as ex:   # noqa: BLE001
            check("points de jeu = shared/levels/points.lua (lua5.2)", False, repr(ex))
    else:
        print("[F4-FOREUSE] (lua5.2 absent du PATH : contrôle croisé avec points.lua sauté)")

    # rotation des 4 directions = rotation des points par le moteur (sens horaire, y de jeu vers le sud)
    bon = True
    for s in (3, 4, 5, 6):
        x, y = cotes.sortie(s)
        gx, gy = x, -y                     # repère de jeu (y vers le sud)
        for k, d in enumerate(("N", "E", "S", "O")):
            a = E.ANGLE[d]
            rx, ry = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
            mx, my = gx, gy
            for _ in range(k):
                mx, my = -my, mx           # rotation horaire d'un quart de tour (moteur)
            bon = bon and abs(rx - mx) < 1e-9 and abs(ry + my) < 1e-9
    check("4 directions : rotation du repère = rotation des points du moteur", bon)

    # --- cotes -------------------------------------------------------------------------------------------------------
    for s in (3, 4, 5, 6):
        T = cotes.taille(s)
        G = T["goulotte"]
        check("taille %d : sommet de tour sous le bord arrière du tablier à l'écran" % s,
              T["H"] * 0.7071 < T["d"] + T["zt"] * 0.7071, "%.2f >= %.2f" % (T["H"] * 0.7071, T["d"] + T["zt"] * 0.7071))
        check("taille %d : goulotte alignée sur le point de dépôt et au-delà du bord" % s,
              G["x"] == T["sortie"][0] and T["a"] < G["y1"] < T["sortie"][1] and G["z0"] > G["z1"] > T["zt"])
        check("taille %d : treillis permis sous le sommet, au-dessus du tablier" % s,
              T["zt"] < T["z_treillis_max"] < T["H"] + 0.5)
        m0 = T["moteur"]
        check("taille %d : moteur à l'arrière, dans le tablier" % s,
              m0["y"] < 0 and m0["y"] - m0["p"] / 2 > -T["d"] and 0.5 * T["a"] * 0.84 + m0["w"] / 2 < T["d"])

    # --- variantes ---------------------------------------------------------------------------------------------------
    V = piece.PIECE["variants"]
    check("variantes : 1 + 14 × 5 + 4 × 5 = 91", len(V) == 91, str(len(V)))
    check("variantes : niveaux (eNN-N = 2N−1, eNN-piece = 2N)", all(
        V["e%02d-N" % e]["level"] == 2 * e - 1 and V["e%02d-piece" % e]["level"] == 2 * e for e in range(2, 16)))
    check("variantes : côté = emprise de l'âge", all(V["e%02d-E" % e]["side"] == E.COTE[e] for e in range(2, 16)))
    check("variantes : directions", all(V["e09-%s" % d]["dir"] == d for d in E.DIRECTIONS))
    check("variantes : âge 1 = pièce seule (niveau 1 vanilla)", "e01-piece" in V and "e01-N" not in V)

    # --- triplets ------------------------------------------------------------------------------------------------------
    T3 = E.TRIPLETS
    check("triplets : 15 âges, 3 mots chacun", sorted(T3) == list(range(1, 16)) and all(len(t) == 3 for t in T3.values()))
    tous = [m_ for e in sorted(T3) for m_ in mots(T3[e])]
    dbl = sorted({m_ for m_ in tous if tous.count(m_) > 1})
    check("triplets : aucun mot répété d'un âge à l'autre", not dbl, ", ".join(dbl))
    check("triplets : aucun égal à celui de la mitrailleuse", all(T3[e] != TRIPLETS_GUN[e] for e in T3))
    lz = os.path.join(LEVELS, "laser_e", "epoques.py")
    tl = {}
    if os.path.exists(lz):
        src = open(lz, encoding="utf-8").read()
        mm = re.search(r"TRIPLETS = (\{.*?\n\})", src, re.S)
        tl = ast.literal_eval(mm.group(1)) if mm else {}
    check("triplets : aucun égal à celui du laser", tl and all(T3[e] != tl.get(e) for e in T3))

    # --- fichiers d'âge (source) ---------------------------------------------------------------------------------------
    import ages
    lignee = set(re.findall(r'(?:metal|accent)\("([a-z_0-9]+)"', open(os.path.join(COMMUN, "kit.py"),
                                                                          encoding="utf-8").read()))
    lignee |= {"emit", "emit_soft", "emit2", "amber", "accent", "tablier", "_emit_rgb", "_emit2_rgb"}
    for e in range(0, 16):
        f = os.path.join(KIT, "ep%02d.py" % e)
        if not os.path.exists(f):
            check("ep%02d.py présent" % e, False)
            continue
        src = open(f, encoding="utf-8").read()
        tree = ast.parse(src)
        fonctions = {n.name for n in tree.body if isinstance(n, ast.FunctionDef)}
        besoin = {"piece", "matieres"} | ({"tour"} if e >= 2 or e == 0 else set())
        check("ep%02d : fonctions %s" % (e, ", ".join(sorted(besoin))), besoin <= fonctions,
              ", ".join(sorted(besoin - fonctions)))
        if e >= 1:
            tri = None
            for n in tree.body:
                if isinstance(n, ast.Assign) and any(getattr(t, "id", None) == "TRIPLET" for t in n.targets):
                    tri = ast.literal_eval(n.value)
            check("ep%02d : TRIPLET = epoques.TRIPLETS" % e, tri == T3[e], repr(tri))
            check("ep%02d : FOYER = ages.FOYER[%d] (lumière de la mitrailleuse)" % (e, e),
                  ("FOYER = ages.FOYER[%d]" % e) in src)
            check("ep%02d : matières de l'âge appelées (ages.matieres(%d, …))" % (e, e),
                  ("ages.matieres(%d, metal, M)" % e) in src)
        if e >= 2:
            check("ep%02d : HABILLAGE = ages.CORPS[%d] (+ clés propres)" % (e, e), ("dict(ages.CORPS[%d]" % e) in src)

            class _Ep:
                HABILLAGE = dict(ages.CORPS[e])
            try:
                E.habillage(_Ep)
                okh = True
            except Exception:   # noqa: BLE001
                okh = False
            check("ep%02d : habillage valide" % e, okh)
        cles = set(re.findall(r'M\["([a-zA-Z_0-9]+)"\]', src))
        defn = lignee | set(ages.CLES_MATIERES.get(e, ())) | set(re.findall(r'M\["([a-zA-Z_0-9]+)"\]\s*=', src))
        manque = sorted(cles - defn)
        check("ep%02d : matières citées toutes définies" % e, not manque, ", ".join(manque))

    # --- formes du tablier (ronde 2) : deux âges voisins de même taille n'ont pas la même ----------------------------
    formes = {}
    for e in range(2, 16):
        src = open(os.path.join(KIT, "ep%02d.py" % e), encoding="utf-8").read()
        mm = re.search(r'forme_tablier="([a-z]+)"', src)
        formes[e] = mm.group(1) if mm else "carre"
    check("formes du tablier connues", all(f in E.FORMES_TABLIER for f in formes.values()), repr(formes))
    voisins = [(e, e + 1) for e in range(2, 15) if E.COTE[e] == E.COTE[e + 1] and formes[e] == formes[e + 1]
               and formes[e] != "carre"]
    check("formes du tablier : aucun voisin de même taille avec la même forme non carrée", not voisins, repr(voisins))
    check("formes du tablier : au moins 6 âges non carrés", sum(f != "carre" for f in formes.values()) >= 6,
          repr(formes))

    # --- nommage -------------------------------------------------------------------------------------------------------
    communs = {os.path.splitext(x)[0] for x in os.listdir(COMMUN) if x.endswith(".py")}
    kit = {os.path.splitext(x)[0] for x in os.listdir(KIT) if x.endswith(".py")}
    check("nommage : aucun module du kit ne porte le nom d'un module de commun/", not (communs & kit),
          ", ".join(sorted(communs & kit)))

    print("[F4-FOREUSE] %d OK, %d ECHEC(S)" % (len(OK), len(KO)))
    return 1 if KO else 0


if __name__ == "__main__":
    sys.exit(main())
