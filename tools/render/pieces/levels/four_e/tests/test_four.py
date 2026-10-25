"""TESTS DU KIT FOUR (lot F2-A, 25/10), hors Blender (Python 3.9) :

    py -3.9 tools/render/pieces/levels/four_e/tests/test_four.py [--sprites DIR ...]   -> « [F2-FOUR] N OK, 0 ECHEC(S) »

Contrôle : profil (contrat de commun/famille.py, aller-retour avec gun_e et laser_e sans contamination), emprise égale à
la ligne « furnace » de shared/levels/config.lua, cotes (croissantes, caisson du foyer et places avant dans l'emprise,
places hors du caisson, plafond à l'écran dans la fenêtre des planches), règle de la bouche de fumée (cas acceptés et
refusés), variantes (noms, niveaux, tailles), triplets « en 3 mots » (15, distincts, aucun mot répété, aucun égal au
triplet de la mitrailleuse ni du laser du même âge), fichiers d'âge LUS SANS BLENDER (EPOQUE, TRIPLET, FOYER =
ages.FOYER[N], HABILLAGE fondé sur ages.CORPS[N], clés gueule et foyer valides, fonctions du contrat, ages.matieres(N)
appelé en premier), nommage (aucun module du kit ne porte le nom d'un module de commun/).
Avec --sprites DIR (sorties de rendre.py) : chaque eNN-socle rendu a sa bouche de fumée relevée (spec.json « fumee »),
dans le quart arrière droit et sous le plafond à l'écran.
"""
import argparse
import ast
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
FOUR = os.path.dirname(ICI)
LEVELS = os.path.dirname(FOUR)
COMMUN = os.path.join(LEVELS, "commun")
MOD = os.path.normpath(os.path.join(LEVELS, "..", "..", "..", ".."))
sys.path.insert(0, COMMUN)
import famille as FAM  # noqa: E402

OK, KO = [], []


def check(nom, cond, detail=""):
    (OK if cond else KO).append(nom)
    print("[F2-FOUR] %s %s%s" % ("OK    " if cond else "ECHEC ", nom, (" : " + str(detail)) if detail and not cond
                                 else ""))


VIDES = {"de", "à", "d", "l", "la", "le", "les", "des", "du", "en", "et", "d'or"}


def mots(triplet):
    out = []
    for t in triplet:
        for m in re.split(r"[\s'’]+", t.lower()):
            if m and m not in VIDES and m != "or":
                out.append(m)
    return out


def lire_age(n):
    """Lecture statique d'un fichier d'âge : constantes simples, appels de HABILLAGE, fonctions, premier appel."""
    src = open(os.path.join(FOUR, "ep%02d.py" % n), encoding="utf-8").read()
    t = ast.parse(src)
    info = {"fonctions": set(), "src": src}
    for nd in t.body:
        if isinstance(nd, ast.FunctionDef):
            info["fonctions"].add(nd.name)
            if nd.name == "matieres" and nd.body:
                b = nd.body[0]
                info["matieres_premier"] = ast.get_source_segment(src, b) if b else ""
        if isinstance(nd, ast.Assign) and len(nd.targets) == 1 and isinstance(nd.targets[0], ast.Name):
            nom = nd.targets[0].id
            seg = ast.get_source_segment(src, nd.value)
            info[nom + "_src"] = seg
            try:
                info[nom] = ast.literal_eval(nd.value)
            except ValueError:
                pass
            if nom == "HABILLAGE" and isinstance(nd.value, ast.Call):
                info["hab_kw"] = {k.arg: ast.literal_eval(k.value) for k in nd.value.keywords
                                  if isinstance(k.value, ast.Constant)}
    return info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sprites", action="append", default=[])
    a = ap.parse_args()
    # --- profil et aller-retour de familles
    P = FAM.charger("four_e")
    check("profil chargé, contrat complet", P.NOM == "four_e" and all(hasattr(P, c) for c in FAM.CHAMPS))
    G = FAM.charger("gun_e")
    check("aller-retour : gun_e rechargé", G.NOM == "gun_e")
    Ls = FAM.charger("laser_e")
    check("aller-retour : laser_e rechargé", Ls.NOM == "laser_e")
    import epoques as EL
    TRI_LASER = dict(EL.TRIPLETS)
    P = FAM.charger("four_e")
    import epoques as E
    import cotes
    import piece
    check("aucun module de gun_e ni de laser_e chargé après four_e",
          all(not re.search(r"[\\/](gun_e|laser_e)[\\/]", getattr(m, "__file__", "") or "")
              for m in list(sys.modules.values())))
    check("epoques est celui du four", os.path.dirname(os.path.abspath(E.__file__)) == FOUR, E.__file__)
    check("référence vanilla steel-furnace", P.REF_VANILLA["mesure"] == "steel-furnace"
          and os.path.isfile(P.DUMP_VANILLA), P.DUMP_VANILLA)
    # --- emprise : ligne furnace de shared/levels/config.lua
    cfg = open(os.path.join(MOD, "shared", "levels", "config.lua"), encoding="utf-8").read()
    m = re.search(r"furnace\s*=\s*\{\s*era\s*=\s*\{([^}]*)\}", cfg)
    era = [int(x) for x in m.group(1).split(",")] if m else []
    check("emprise = ligne furnace de config.lua (%s)" % era,
          [P.COTE[e] for e in range(1, 16)] == [era[(e - 1) // 3] for e in range(1, 16)] if era else False)
    # --- cotes
    S = cotes.TAILLES_PERMISES
    T = cotes.TAILLES
    for cle in ("sole_h", "tablier", "H", "zmax", "halo", "ecran"):
        v = [T[s][cle] for s in S]
        check("cote %s croissante" % cle, all(x < y for x, y in zip(v, v[1:])), v)
    for cle in ("w", "h", "wf", "hf", "avance", "entre"):
        v = [T[s]["gueule"][cle] for s in S]
        check("gueule %s croissante" % cle, all(x < y for x, y in zip(v, v[1:])), v)
    for s in S:
        t = T[s]
        gq = t["gueule"]
        check("%d×%d : caisson du foyer dans l'emprise et sur le tablier" % (s, s),
              gq["y_face"] > -s / 2.0 + 0.04 and gq["wf"] / 2 < t["xa"] and gq["y_fond"] > t["y_av"])
        check("%d×%d : bouche sous le caisson, au ras du tablier" % (s, s),
              gq["zb"] > t["sole_h"] and gq["zb"] + gq["h"] < gq["zb"] + gq["hf"] - 0.06 and gq["w"] < gq["wf"])
        for nom in ("coin_SO", "coin_SE"):
            p = t["coins"][nom]
            check("%d×%d : %s dans l'emprise, hors du caisson" % (s, s, nom),
                  abs(p["x"]) - p["rw"] >= gq["wf"] / 2 and abs(p["x"]) + p["rw"] <= s / 2.0
                  and p["yn"] - p["prof"] / 2 >= -s / 2.0 and p["rw"] > 0.15)
        f = t["fumee"]
        check("%d×%d : place de fumée conseillée valide" % (s, s),
              cotes.fumee_valide(t, f["x"], f["yn"], 0.8 * t["H"]))
        check("%d×%d : bouche refusée à l'ouest, au sud, trop basse, au-dessus du plafond" % (s, s),
              not cotes.fumee_valide(t, -f["x"], f["yn"], t["H"]) and not cotes.fumee_valide(t, f["x"], -f["yn"],
                                                                                              t["H"])
              and not cotes.fumee_valide(t, f["x"], f["yn"], 0.3 * t["H"])
              and not cotes.fumee_valide(t, f["x"], f["yn"], cotes.z_plafond(t, f["yn"]) + 0.1))
        check("%d×%d : plafond à l'écran dans la fenêtre des planches (côté + 3)" % (s, s),
              t["ecran"] < (s + 3) / 2.0 and t["ecran"] > s / 2.0 + 0.3, t["ecran"])
    # --- variantes
    V = piece.PIECE["variants"]
    check("variantes : e01-piece, 14 socles, 14 pièces, 10 témoins", len(V) == 1 + 28 + 10 and "e01-piece" in V)
    check("niveaux impair (socle) et pair (pièce)", all(V["e%02d-socle" % e]["level"] == 2 * e - 1
                                                         and V["e%02d-piece" % e]["level"] == 2 * e for e in
                                                         range(2, 16)))
    check("tailles des variantes = emprise", all(V["e%02d-socle" % e]["side"] == E.COTE[e] for e in range(2, 16)))
    check("e01-piece sous le vanilla", V["e01-piece"]["sous_vanilla"] and not V["e02-piece"]["sous_vanilla"])
    # --- triplets
    TR = E.TRIPLETS
    check("15 triplets de 3 mots", sorted(TR) == list(range(1, 16)) and all(len(t) == 3 for t in TR.values()))
    tous = [m_ for e in range(1, 16) for m_ in mots(TR[e])]
    dbl = sorted({m_ for m_ in tous if tous.count(m_) > 1})
    check("aucun mot répété entre les 15 triplets du four", not dbl, dbl)
    check("aucun triplet égal à celui du laser du même âge", all(TR[e] != TRI_LASER[e] for e in range(1, 16)))
    commun_laser = {e: sorted(set(mots(TR[e])) & set(mots(TRI_LASER[e]))) for e in range(1, 16)}
    print("[F2-FOUR] info : mots communs avec le laser du même âge : %s"
          % {e: v for e, v in commun_laser.items() if v})
    # --- fichiers d'âge (lecture statique)
    import ages
    for n in range(0, 16):
        p = os.path.join(FOUR, "ep%02d.py" % n)
        if not os.path.isfile(p):
            check("ep%02d.py présent" % n, False)
            continue
        inf = lire_age(n)
        besoin = {"piece"} if n == 1 else {"chambre", "fumee", "piece"}
        check("ep%02d : fonctions du contrat %s" % (n, sorted(besoin)), besoin <= inf["fonctions"],
              sorted(besoin - inf["fonctions"]))
        if n == 0:
            continue
        check("ep%02d : EPOQUE et TRIPLET" % n, inf.get("EPOQUE") == n and inf.get("TRIPLET") == TR[n],
              (inf.get("EPOQUE"), inf.get("TRIPLET")))
        check("ep%02d : FOYER = ages.FOYER[%d]" % (n, n), (inf.get("FOYER_src") or "").replace(" ", "")
              == "ages.FOYER[%d]" % n, inf.get("FOYER_src"))
        if n >= 2:
            hs = (inf.get("HABILLAGE_src") or "").replace(" ", "")
            check("ep%02d : HABILLAGE fondé sur ages.CORPS[%d]" % (n, n), hs.startswith("dict(ages.CORPS[%d]" % n), hs)
            kw = inf.get("hab_kw", {})
            inconnues = sorted(set(kw) - {"gueule", "foyer"})
            check("ep%02d : clés propres connues (gueule, foyer)" % n, not inconnues, inconnues)
            check("ep%02d : forme de gueule valide" % n, kw.get("gueule") in (None,) + E.FORMES_GUEULE, kw.get("gueule"))
            check("ep%02d : matière du foyer de l'âge" % n,
                  kw.get("foyer") is None or kw["foyer"] in ages.CLES_MATIERES[n], kw.get("foyer"))
        check("ep%02d : ages.matieres(%d, …) appelé en premier" % (n, n),
              (inf.get("matieres_premier") or "").replace(" ", "").startswith("ages.matieres(%d," % n),
              inf.get("matieres_premier"))
    # --- nommage
    noms_commun = {f[:-3] for f in os.listdir(COMMUN) if f.endswith(".py")}
    noms_four = {f[:-3] for f in os.listdir(FOUR) if f.endswith(".py")}
    check("aucun module du kit four ne porte le nom d'un module de commun/", not (noms_commun & noms_four),
          sorted(noms_commun & noms_four))
    # --- bouches de fumée rendues
    for d in a.sprites:
        for e in range(2, 16):
            sp = os.path.join(d, "e%02d-socle" % e, "spec.json")
            if not os.path.isfile(sp):
                continue
            f = json.load(open(sp, encoding="utf-8")).get("fumee")
            t = T[E.COTE[e]]
            check("rendu e%02d-socle : bouche de fumée relevée et valide %s" % (e, f),
                  bool(f) and cotes.fumee_valide(t, f[0], f[1], f[2]))
    print("[F2-FOUR] %d OK, %d ECHEC(S)" % (len(OK), len(KO)))
    sys.exit(1 if KO else 0)


if __name__ == "__main__":
    main()
