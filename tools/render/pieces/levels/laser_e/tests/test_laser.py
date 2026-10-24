"""TESTS DU KIT LASER (lot F1-A, 24/10), hors Blender (Python 3.9) :

    py -3.9 tools/render/pieces/levels/laser_e/tests/test_laser.py      -> « [F1-LASER] N OK, 0 ECHEC(S) », code 0

Contrôle : profil (contrat de commun/famille.py, aller-retour avec gun_e sans contamination), cotes (croissantes,
emprise tenue, pose N : émetteur jamais plus long que large, pièce paire hors de la zone balayée par la tête),
variantes et directions, triplets « en 3 mots » (15, tous distincts, aucun mot répété, aucun égal à un triplet de la
mitrailleuse), habillage (formes refusées), fichiers d'âge écrits (TRIPLET et FOYER par lecture du source, sans
Blender), nommage (aucun module du kit ne porte le nom d'un module de commun/) ; quatrième jet (correction F1-A) :
proue dans le rayon balayé, caisson arrière bas et étroit, contours des gradins, maquettes des 15 affûts (habillage
valide, voisins de même taille de silhouettes différentes : règle M-6).
Le contrôle « gun_e et commun inchangés » (git) N'EST PLUS ICI (défaut m-7 : il échouait dans toute branche qui touche
légitimement commun/ ou gun_e/) : c'est une preuve du lot F1-A, fo-logs/2026-10-24_F1/outils/preuve_intact.py.
"""
import ast
import math
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
LASER = os.path.dirname(ICI)
LEVELS = os.path.dirname(LASER)
COMMUN = os.path.join(LEVELS, "commun")
MOD = os.path.normpath(os.path.join(LEVELS, "..", "..", "..", ".."))
sys.path.insert(0, COMMUN)
import famille as FAM  # noqa: E402

OK, KO = [], []


def check(nom, cond, detail=""):
    (OK if cond else KO).append(nom)
    print("[F1-LASER] %s %s%s" % ("OK    " if cond else "ECHEC ", nom, (" : " + detail) if detail and not cond else ""))


# triplets de la MITRAILLEUSE (catalogue §C pour 1 à 12, FICHES_ERE_V.md pour 13 à 15)
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
    # --- profil et aller-retour de familles
    P = FAM.charger("laser_e")
    check("profil chargé, contrat complet", P.NOM == "laser_e" and all(hasattr(P, c) for c in FAM.CHAMPS))
    G = FAM.charger("gun_e")
    check("aller-retour : gun_e rechargé", G.NOM == "gun_e" and G.REF_VANILLA["mesure"] == "gun-turret")
    P = FAM.charger("laser_e")
    import epoques as E
    import cotes
    import piece
    check("aucun module de gun_e chargé après laser_e",
          all("gun_e" not in (getattr(m, "__file__", "") or "") for m in list(sys.modules.values())),
          ", ".join(n for n, m in sys.modules.items() if "gun_e" in (getattr(m, "__file__", "") or "")))
    check("epoques est celui du laser", os.path.dirname(os.path.abspath(E.__file__)) == LASER, E.__file__)
    check("référence vanilla laser-turret", P.REF_VANILLA == dict(dump="electric-turret_laser-turret",
                                                                    mesure="laser-turret"))
    check("emprise 2, 3, 4, 5, 6 par ère comme la mitrailleuse",
          [P.COTE[e] for e in (1, 3, 4, 6, 7, 9, 10, 12, 13, 15)] == [2, 2, 3, 3, 4, 4, 5, 5, 6, 6])
    # --- cotes
    S = (2, 3, 4, 5, 6)
    for cle in ("R1", "H"):
        v = [cotes.TAILLES[s]["affut"][cle] for s in S]
        check("affût %s croissant" % cle, all(a < b for a, b in zip(v, v[1:])), str(v))
    for cle in ("re", "Rt", "zh", "xc"):
        v = [cotes.TAILLES[s]["tete"][cle] for s in S]
        check("tête %s croissant" % cle, all(a < b for a, b in zip(v, v[1:])), str(v))
    for s in S:
        T = cotes.TAILLES[s]
        t = T["tete"]
        check("%d×%d : affût dans l'emprise (R1 < s/2)" % (s, s), T["affut"]["R1"] < s / 2.0)
        env = cotes.enveloppe_tete(s)
        check("%d×%d : tête dans l'emprise (balayage %.2f < %.2f)" % (s, s, env, s / 2.0), env < s / 2.0)
        L, D = t["y_av"] - t["y_ar"], 2 * t["re"]
        check("%d×%d : pose N, émetteur pas plus long que large (%.2f / %.2f)" % (s, s, L, D), L / D <= 1.05)
        pc = T["piece"]
        dist = math.hypot(pc["x"], pc["yn"]) - pc["r"]
        check("%d×%d : pièce paire hors de la zone balayée (%.2f > %.2f)" % (s, s, dist, env), dist > env)
        check("%d×%d : pièce paire dans l'emprise" % (s, s), abs(pc["x"]) + pc["r"] <= s / 2.0 + 1e-9)
        rg = cotes.rayons_gradins(s)
        check("%d×%d : gradins décroissants, pivot logé" % (s, s),
              all(a > b for a, b in zip(rg, rg[1:])) and rg[-1] > T["pivot"]["R"])
        C = T["condensateurs"]
        check("%d×%d : couronne de condensateurs paire (n = %d)" % (s, s, C["n"]), C["n"] % 2 == 0 and C["n"] >= 8)
        z = cotes.hauteurs_gradins(s)
        check("%d×%d : la tête est au-dessus du pivot (zh %.2f > %.2f)" % (s, s, t["zh"], z[-1] + T["pivot"]["h"]),
              t["zh"] - t["re"] > z[-1] + T["pivot"]["h"])
        # quatrième jet (M-1, M-4)
        check("%d×%d : caisson arrière SOUS l'axe des tourillons (%.2f < %.2f) et plus étroit que l'émetteur"
              % (s, s, t["zb1"], t["zh"]), t["zb1"] < t["zh"] - 0.2 * t["re"] and t["bx"] < t["re"])
        check("%d×%d : proue devant l'émetteur et dans le rayon que balaie déjà l'émetteur (%.2f <= %.2f)"
              % (s, s, t["py1"], math.hypot(t["re"], t["y_av"])),
              t["y_av"] < t["py1"] <= math.hypot(t["re"], t["y_av"]) and t["pw_ep"] < t["pw0"] < t["re"])
    # --- variantes et directions
    V = piece.PIECE["variants"]
    check("114 variantes explicites (1 + 14 × 4 + 5 × 3 + 14 × 3 maquettes)", len(sorted(V)) == 114,
          str(len(sorted(V))))
    check("têtes tournées à la demande", "e05-tete-d16" in V and "k6-tete-d63" in V and "e05-tete-d64" not in V
          and "e01-tete-d00" not in V and "m14-tete-d08" in V and "m01-tete-d00" not in V)
    check("maquettes : socle et têtes N, E des âges 2 à 15, à l'emprise de l'âge",
          all(V["m%02d-%s" % (e, p)]["side"] == E.COTE[e] and V["m%02d-%s" % (e, p)].get("maquette")
              for e in range(2, 16) for p in ("socle", "tete-N", "tete-E")))
    check("d00 = N et d16 = E au bit près", piece.DIRS["d00"] == piece.DIRS["N"] and piece.DIRS["d16"] == piece.DIRS["E"])
    check("ronde : variantes existantes", all(n in V for e in range(1, 16) for n in P.ronde(e)))
    check("préfixe des fichiers « lase »", P.est_piece_paire(1, "hr-lase-e01-piece-main.png")
          and P.est_piece_paire(7, "hr-lase-e07-piece-main.png") and not P.est_piece_paire(7, "hr-lase-e07-socle-main.png"))
    # --- triplets
    T3 = E.TRIPLETS
    check("15 triplets", sorted(T3) == list(range(1, 16)))
    tous = [m for e in sorted(T3) for m in mots(T3[e])]
    dbl = sorted({m for m in tous if tous.count(m) > 1})
    check("aucun mot répété entre les 15 triplets du laser", not dbl, ", ".join(dbl))
    pareils = [e for e in T3 if set(T3[e]) == set(TRIPLETS_GUN[e])]
    # défaut m-3 : ce contrôle refuse seulement une COPIE du triplet de la mitrailleuse ; il ne garantit PAS la
    # non-confusion (seul le jeu mixte la mesure). Les mots partagés avec la mitrailleuse du même âge sont IMPRIMÉS.
    check("refus d'un triplet recopié de la mitrailleuse (ne prouve pas la non-confusion : jeu mixte)", not pareils,
          str(pareils))

    def racine(m):
        return m[:-1] if m.endswith("s") or m.endswith("x") else m
    communs = {e: sorted({m for m in mots(T3[e]) if racine(m) in {racine(x) for x in mots(TRIPLETS_GUN[e])}})
               for e in T3}
    print("[F1-LASER] (info) mots partagés avec la mitrailleuse du même âge : %s" % (
        "; ".join("%d : %s" % (e, ", ".join(communs[e])) for e in sorted(communs) if communs[e]) or "aucun"))
    # --- habillage : formes refusées
    class Ep:
        HABILLAGE = {}
    for mauvais in (dict(forme_tete="canon"), dict(forme_affut=dict(gradins=6)), dict(forme_affut=dict(pans=4)),
                    dict(forme_affut=dict(profil="carre")), dict(forme_affut=dict(motif="x")),
                    dict(condensateurs=dict(n=7)), dict(tremie="ochre")):
        Ep.HABILLAGE = mauvais
        try:
            E.habillage(Ep)
            refuse = False
        except (KeyError, ValueError):
            refuse = True
        check("habillage refusé : %s" % mauvais, refuse)
    for mauvais in (dict(forme_affut=dict(pans=8, contour=dict(forme="lobes", n=3, prof=0.2))),
                    dict(forme_affut=dict(contour=dict(forme="spirale", n=3, prof=0.2))),
                    dict(forme_affut=dict(contour=dict(forme="lobes", n=2, prof=0.2))),
                    dict(forme_affut=dict(contour=dict(forme="lobes", n=3, prof=0.6))),
                    dict(forme_affut=dict(rayons=dict(forme="pied", n=4))),
                    dict(forme_affut=dict(rayons=dict(forme="aileron", n=12)))):
        Ep.HABILLAGE = mauvais
        try:
            E.habillage(Ep)
            refuse = False
        except (KeyError, ValueError):
            refuse = True
        check("habillage refusé : %s" % mauvais, refuse)
    Ep.HABILLAGE = dict(forme_tete="anneau", forme_affut=dict(gradins=4, pans=8, profil="cone", lisere="emit"),
                        condensateurs=dict(n=10))
    check("habillage permis : anneau, 4 gradins à 8 pans, cône, liseré, 10 condensateurs", bool(E.habillage(Ep)))
    # --- contours (quatrième jet)
    for forme, n in (("lobes", 3), ("lobes", 4), ("etoile", 8), ("dents", 12)):
        ct = dict(forme=forme, n=n, prof=0.25)
        pr = cotes.profil_contour(ct, 24)
        ks = [k for _, k in pr]
        angs = [a for a, _ in pr]
        check("contour %s %d : facteurs dans [1 - prof, 1], angles croissants sur un tour" % (forme, n),
              min(ks) >= 0.75 - 1e-9 and max(ks) <= 1.0 + 1e-9 and abs(min(ks) - 0.75) < 0.02
              and all(b > a for a, b in zip(angs, angs[1:])) and angs[-1] - angs[0] < 2 * math.pi)
        check("contour %s %d : facteur 1 au premier sommet (phase 90 : nord)" % (forme, n),
              abs(cotes.facteur_contour(ct, math.pi / 2) - 1.0) < 1e-9)
    check("contour rond : profil = cercle régulier",
          cotes.profil_contour(None, 8) == [(2 * math.pi * i / 8, 1.0) for i in range(8)])
    # --- maquettes des 15 affûts (M-6)
    check("maquettes : âges 2 à 15", sorted(E.MAQUETTES) == list(range(2, 16)))
    ok_hab = []
    for e in sorted(E.MAQUETTES):
        try:
            h = E.habillage(E.maquette(e))
            ok_hab.append(h["forme_affut"] is not None)
        except (KeyError, ValueError) as ex:
            ok_hab.append(False)
            print("[F1-LASER]   maquette %d : %s" % (e, ex))
    check("maquettes : habillage complet et valide aux 14 âges", all(ok_hab))

    def silhouette(e):
        fa = E.MAQUETTES[e]["forme_affut"]
        ct = fa.get("contour")
        if fa.get("pans"):
            ctr = ("pans", fa.get("pans"))
        elif ct:
            ctr = (ct["forme"], ct["n"])
        else:
            ctr = "rond"
        return (fa.get("gradins"), ctr, fa.get("profil", "droit"), (fa.get("rayons") or {}).get("forme"),
                bool(fa.get("pilotis")), bool(fa.get("interstice")))
    for e in range(2, 15):
        if E.COTE[e] != E.COTE[e + 1]:
            continue
        a, b = silhouette(e), silhouette(e + 1)
        nd = sum(x != y for x, y in zip(a, b))
        check("M-6 : affûts %d et %d (même taille) : silhouettes différentes sur au moins 2 traits (%d)" % (e, e + 1, nd),
              nd >= 2, "%s / %s" % (a, b))
    # --- fichiers d'âge écrits (lecture du source)
    import ages
    for f in sorted(os.listdir(LASER)):
        m = re.match(r"^ep(\d\d)\.py$", f)
        if not m:
            continue
        e = int(m.group(1))
        src = open(os.path.join(LASER, f), encoding="utf-8").read()
        tree = ast.parse(src)
        vals = {}
        for node in tree.body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
                vals[node.targets[0].id] = node.value
        fonctions = {n.name for n in tree.body if isinstance(n, ast.FunctionDef)}
        if e >= 1:
            trip = ast.literal_eval(vals["TRIPLET"]) if "TRIPLET" in vals else None
            check("ep%02d : TRIPLET = epoques.TRIPLETS[%d]" % (e, e), trip == T3[e], str(trip))
            fy = vals.get("FOYER")
            check("ep%02d : FOYER = ages.FOYER[%d] (même lumière que la mitrailleuse)" % (e, e),
                  isinstance(fy, ast.Subscript) and ast.unparse(fy) == "ages.FOYER[%d]" % e if hasattr(ast, "unparse")
                  else "ages.FOYER[%d]" % e in src)
            check("ep%02d : FAISCEAU déclaré" % e, "FAISCEAU" in vals)
        besoin = {"piece"} if e in (0, 1) else {"socle", "piece", "emetteur"}
        check("ep%02d : fonctions du contrat (%s)" % (e, ", ".join(sorted(besoin))), besoin <= fonctions,
              str(sorted(besoin - fonctions)))
        if e >= 2:
            check("ep%02d : matières de l'âge par ages.matieres(%d, …)" % (e, e), "ages.matieres(%d," % e in src)
    check("familles de foyers : voisines distinctes", ages.verifier_familles())
    # --- nommage : aucun module du kit ne porte le nom d'un module de commun/
    com = {f for f in os.listdir(COMMUN) if f.endswith(".py")}
    las = {f for f in os.listdir(LASER) if f.endswith(".py")}
    check("aucun nom de module commun repris dans laser_e", not (com & las), str(sorted(com & las)))
    print("[F1-LASER] %d OK, %d ECHEC(S)" % (len(OK), len(KO)))
    return 1 if KO else 0


if __name__ == "__main__":
    sys.exit(main())
