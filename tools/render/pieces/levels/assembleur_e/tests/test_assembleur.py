"""TESTS DU KIT ASSEMBLEUR (lot F3-A, 25/10), hors Blender (Python 3.9) :

    py -3.9 tools/render/pieces/levels/assembleur_e/tests/test_assembleur.py   -> « [F3-ASM] N OK, 0 ECHEC(S) », code 0

Contrôle : profil (contrat de commun/famille.py, aller-retour avec gun_e et laser_e sans contamination), emprise (3, 4,
5, 6, 6 par ère, comme shared/levels/config.lua), cotes (croissantes, dans l'emprise, coins avant libres des joues,
table dans la baie, outil sous le portique et au-dessus de la table, places dans l'emprise), variantes, triplets « en 3
mots » (15, aucun mot répété, aucun recopié de la mitrailleuse ou du laser), habillage (formes refusées), silhouettes
(voisins de même taille différents sur au moins 2 traits), fichiers d'âge (TRIPLET, FOYER, TRAVAIL, fonctions du
contrat, matières de l'âge, silhouette déclarée = SILHOUETTES ; lecture du source, sans Blender), nommage (aucun module
du kit ne porte le nom d'un module de commun/), emprise lue dans shared/levels/config.lua.
"""
import ast
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
ASM = os.path.dirname(ICI)
LEVELS = os.path.dirname(ASM)
COMMUN = os.path.join(LEVELS, "commun")
MOD = os.path.normpath(os.path.join(LEVELS, "..", "..", "..", ".."))
sys.path.insert(0, COMMUN)
import famille as FAM  # noqa: E402

OK, KO = [], []


def check(nom, cond, detail=""):
    (OK if cond else KO).append(nom)
    print("[F3-ASM] %s %s%s" % ("OK    " if cond else "ECHEC ", nom, (" : " + detail) if detail and not cond else ""))


TRIPLETS_GUN = {
    1: ("sacs", "bois", "bricolé"), 2: ("fer", "boulons", "bouclier"), 3: ("cuivre", "vapeur", "manomètres"),
    4: ("fûts", "jaune", "vannes"), 5: ("blindé", "sombre", "braise"), 6: ("bobines", "isolateurs", "arcs"),
    7: ("bronze", "cristaux", "violet"), 8: ("verre", "bulles", "toxique"), 9: ("plomb", "hublots", "radioactif"),
    10: ("caréné", "câbles", "voyants"), 11: ("ailerons", "effilé", "titane"), 12: ("chrome", "givre", "anneaux"),
    13: ("antimatière", "bouteilles magnétiques", "annihilation"), 14: ("espace profond", "étoiles", "portail"),
    15: ("trou noir", "disque de lumière", "big bang"),
}
VIDES = {"de", "à", "d", "l", "la", "le", "les", "des", "du", "en", "et", "sur"}


def mots(triplet):
    out = []
    for t in triplet:
        for m in re.split(r"[\s'’]+", t.lower()):
            if m and m not in VIDES:
                out.append(m)
    return out


def main():
    # --- profil et aller-retour de familles
    P = FAM.charger("assembleur_e")
    check("profil chargé, contrat complet", P.NOM == "assembleur_e" and all(hasattr(P, c) for c in FAM.CHAMPS))
    G = FAM.charger("gun_e")
    check("aller-retour : gun_e rechargé", G.NOM == "gun_e")
    L = FAM.charger("laser_e")
    check("aller-retour : laser_e rechargé", L.NOM == "laser_e")
    P = FAM.charger("assembleur_e")
    import epoques as E
    import cotes
    import piece
    check("aucun module de gun_e ni de laser_e chargé après assembleur_e",
          all(("gun_e" not in (getattr(m, "__file__", "") or "") and "laser_e" not in (getattr(m, "__file__", "") or ""))
              for m in list(sys.modules.values())))
    check("epoques est celui de l'assembleur", os.path.dirname(os.path.abspath(E.__file__)) == ASM, E.__file__)
    check("référence vanilla assembling-machine-2", P.REF_VANILLA["mesure"] == "assembling-machine-2")
    check("une seule pose « F »", P.POSES == ("F",))
    # emprise lue dans shared/levels/config.lua
    cfg = open(os.path.join(MOD, "shared", "levels", "config.lua"), encoding="utf-8").read()
    m = re.search(r"assembler\s*=\s*\{\s*era\s*=\s*\{([^}]*)\}", cfg)
    eras = [int(x) for x in m.group(1).split(",")] if m else []
    check("emprise lue dans shared/levels/config.lua : %s" % eras,
          [P.COTE[e] for e in (1, 4, 7, 10, 13)] == eras and all(P.COTE[e] == P.COTE[3 * ((e - 1) // 3) + 1]
                                                                 for e in range(1, 16)), str(eras))
    m2 = re.search(r'key = "assembler".*?base = "([^"]+)"', cfg, re.S)
    check("niveau 1 = assembling-machine-2 (config.lua)", m2 is not None and m2.group(1) == "assembling-machine-2")
    # --- cotes
    S = (3, 4, 5, 6)
    for chemin in (("embase", "ze"), ("dos", "Hd"), ("dos", "dd"), ("joues", "Hj"), ("joues", "wj"), ("table", "tx"),
                   ("table", "zt"), ("portique", "zp"), ("coin", "wc")):
        v = [cotes.TAILLES[s][chemin[0]][chemin[1]] for s in S]
        check("cote %s.%s croissante" % chemin, all(a < b for a, b in zip(v, v[1:])), str(v))
    for s in S:
        T = cotes.TAILLES[s]
        h = T["h"]
        J, D, Tb, Pq, O = T["joues"], T["dos"], T["table"], T["portique"], T["outil"]
        check("%d×%d : embase dans l'emprise" % (s, s), h < s / 2.0)
        check("%d×%d : dos plus haut que les joues, joues plus hautes que la table" % (s, s),
              D["Hd"] > J["Hj"] > Tb["zt"] > T["embase"]["ze"])
        check("%d×%d : coins avant libres (joues commencent à -h + wc)" % (s, s),
              abs(J["yf"] - (-h + T["coin"]["wc"])) < 1e-9 and J["yf"] < D["yb"])
        check("%d×%d : table dans la baie" % (s, s),
              Tb["tx"] < J["xb"] - 0.05 and Tb["yt"] - Tb["ty"] > -h + 0.05 and Tb["yt"] + Tb["ty"] < D["yb"] - 0.05)
        check("%d×%d : outil entre la table et la poutre, plus étroit que la table" % (s, s),
              O["z0"] == Tb["zt"] and O["z1"] == Pq["zp"] > Tb["zt"] + 0.4 and O["ox"] < Tb["tx"])
        check("%d×%d : portique au-dessus des joues" % (s, s), Pq["zp"] > J["Hj"] + 0.2)
        pl = cotes.places(s)
        dans = all(abs(p["x"]) + p["r"] <= s / 2.0 + 1e-9 and abs(p["yn"]) + p["r"] <= s / 2.0 + 1e-9
                   for k, p in pl.items() if not k.startswith(("port_", "face")))
        check("%d×%d : places (coins, joues, toit) dans l'emprise ; brides au bord" % (s, s),
              dans and abs(pl["port_N"]["yn"] - T["h"]) < 1e-9 and abs(pl["port_S"]["yn"] + T["h"]) < 1e-9)
        cs = pl["coin_SE"]
        check("%d×%d : pièce paire hors des joues (coin avant)" % (s, s),
              cs["yn"] + cs["r"] < J["yf"] + 1e-9 and cs["r"] > 0.2)
        jo = pl["joue_O"]
        check("%d×%d : trémie d'entrée sur la joue, entre le montant et le dos" % (s, s),
              jo["r"] > 0.15 and jo["yn"] - jo["r"] > Pq["yt"] + Pq["wm"] / 2 - 1e-9 and jo["yn"] + jo["r"] < D["yb"])
        x, y = cotes.ecran(0, Tb["yt"], Tb["zt"])
        check("%d×%d : table à l'écran près du centre (icône de la recette, |y| %.2f < 0,6)" % (s, s, y), abs(y) < 0.6)
    # --- variantes
    V = piece.PIECE["variants"]
    check("33 variantes (1 + 14 × 2 + 4 témoins)", len(V) == 33, str(len(V)))
    check("emprise des variantes = epoques.COTE", all(V["e%02d-machine" % e]["side"] == E.COTE[e] for e in range(2, 16)))
    check("niveaux : machine impaire, pièce paire", all(V["e%02d-machine" % e]["level"] == 2 * e - 1 and
                                                        V["e%02d-piece" % e]["level"] == 2 * e for e in range(2, 16)))
    check("ronde : variantes existantes", all(n in V for e in range(1, 16) for n in P.ronde(e)))
    check("préfixe des fichiers « asm »", P.est_piece_paire(1, "hr-asm-e01-piece-main.png")
          and P.est_piece_paire(7, "hr-asm-e07-piece-main.png") and not P.est_piece_paire(7, "hr-asm-e07-machine-main.png"))
    # --- triplets
    T3 = E.TRIPLETS
    check("15 triplets", sorted(T3) == list(range(1, 16)))
    tous = [m for e in sorted(T3) for m in mots(T3[e])]
    dbl = sorted({m for m in tous if tous.count(m) > 1})
    check("aucun mot répété entre les 15 triplets de l'assembleur", not dbl, ", ".join(dbl))
    src_las = open(os.path.join(LEVELS, "laser_e", "epoques.py"), encoding="utf-8").read()
    tl = ast.literal_eval(re.search(r"^TRIPLETS = (\{.*?\n\})", src_las, re.S | re.M).group(1))
    pareils = [e for e in T3 if set(T3[e]) in (set(TRIPLETS_GUN[e]), set(tl[e]))]
    check("aucun triplet recopié de la mitrailleuse ou du laser", not pareils, str(pareils))
    # --- habillage : formes refusées
    class Ep:
        HABILLAGE = {}
    for mauvais in (dict(forme_dos="cheminee"), dict(forme_embase="rond"), dict(plan="hexagone"), dict(forme_joues="x"),
                    dict(forme_portique="grue"), dict(forme_affut=dict(gradins=3)), dict(tremie="ochre")):
        Ep.HABILLAGE = mauvais
        try:
            E.habillage(Ep)
            refuse = False
        except (KeyError, ValueError):
            refuse = True
        check("habillage refusé : %s" % mauvais, refuse)
    # --- silhouettes : voisins de même taille
    check("silhouettes des âges 2 à 15", sorted(E.SILHOUETTES) == list(range(2, 16)))
    for e in range(2, 15):
        if E.COTE[e] != E.COTE[e + 1]:
            continue
        a, b = E.SILHOUETTES[e], E.SILHOUETTES[e + 1]
        check("ronde F3-A2 : âges %d et %d (même taille) de PLANS différents (%s / %s)" % (e, e + 1, a[0], b[0]),
              a[0] != b[0])
    plans = [E.SILHOUETTES[e][0] for e in range(2, 16)]
    check("ronde F3-A2 : au moins 5 plans différents, dont rond ou octo et tour (%s)" % sorted(set(plans)),
          len(set(plans)) >= 5 and ({"rond", "octo"} & set(plans)) and "tour" in plans)
    check("teinte du niveau pair : multiplication douce (0,8 à 1) aux 15 âges",
          all(0.8 <= v <= 1.0 for e in range(1, 16) for v in E.teinte_pair(e)))
    # --- fichiers d'âge (lecture du source)
    import ages
    vus = []
    for f in sorted(os.listdir(ASM)):
        mm = re.match(r"^ep(\d\d)\.py$", f)
        if not mm:
            continue
        e = int(mm.group(1))
        vus.append(e)
        src = open(os.path.join(ASM, f), encoding="utf-8").read()
        tree = ast.parse(src)
        vals = {}
        for node in tree.body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                vals[node.targets[0].id] = node.value
        fonctions = {n.name for n in tree.body if isinstance(n, ast.FunctionDef)}
        if e >= 1:
            trip = ast.literal_eval(vals["TRIPLET"]) if "TRIPLET" in vals else None
            check("ep%02d : TRIPLET = epoques.TRIPLETS[%d]" % (e, e), trip == T3[e], str(trip))
            check("ep%02d : FOYER = ages.FOYER[%d]" % (e, e), "FOYER" in vals and
                  ast.unparse(vals["FOYER"]) == "ages.FOYER[%d]" % e)
        check("ep%02d : TRAVAIL déclaré (couches, images, organe)" % e, "TRAVAIL" in vals and
              all(k in ast.unparse(vals["TRAVAIL"]) for k in ("couches", "images", "organe")))
        besoin = {"piece"} if e in (0, 1) else {"socle", "piece", "outil", "ouvrage", "sortie"}
        check("ep%02d : fonctions du contrat (%s)" % (e, ", ".join(sorted(besoin))), besoin <= fonctions,
              str(sorted(besoin - fonctions)))
        for nomf in ("entree", "sortie"):
            fn = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == nomf]
            if fn:
                check("ep%02d : %s(g, c, p) (place donnée par la lignée)" % (e, nomf), len(fn[0].args.args) == 3)
        if e >= 2:
            check("ep%02d : matières de l'âge par ages.matieres(%d, …)" % (e, e), "ages.matieres(%d," % e in src)
            hab = ast.unparse(vals.get("HABILLAGE", ast.Constant(None)))
            sil = []
            for cle, defaut in (("plan", "carre"), ("forme_embase", "carre"), ("forme_dos", "plat"), ("forme_joues", "caisson"),
                                ("forme_portique", "poutre")):
                mt = re.search(r"%s='([A-Za-z]+)'" % cle, hab)
                sil.append(mt.group(1) if mt else defaut)
            check("ep%02d : silhouette déclarée = SILHOUETTES[%d]" % (e, e), tuple(sil) == E.SILHOUETTES[e],
                  "%s / %s" % (tuple(sil), E.SILHOUETTES[e]))
    check("fichiers d'âge 0 à 15 présents", vus == list(range(0, 16)), str(vus))
    check("familles de foyers : voisines distinctes", ages.verifier_familles())
    com = {f for f in os.listdir(COMMUN) if f.endswith(".py")}
    asm = {f for f in os.listdir(ASM) if f.endswith(".py")}
    check("aucun nom de module commun repris dans assembleur_e", not (com & asm), str(sorted(com & asm)))
    print("[F3-ASM] %d OK, %d ECHEC(S)" % (len(OK), len(KO)))
    return 1 if KO else 0


if __name__ == "__main__":
    sys.exit(main())
