#!/usr/bin/env python3
"""Tests hors jeu de tools/autotest/fonction_mesures.py (lot MESURES) sur des journaux synthétiques, cas dégénérés compris.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/tests/test_fonction_mesures.py   -> « BILAN : N OK, 0 ECHEC(S) », code 0.
"""
import contextlib
import gzip
import io
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import fonction_mesures as M  # noqa: E402

ok = fail = 0


def check(cond, msg):
    global ok, fail
    if cond:
        ok += 1
    else:
        fail += 1
        print("  ECHEC : " + msg)


def near(a, b, eps=1e-6):
    return a is not None and abs(a - b) <= eps


PREFIX = "  40.286 Script @__fo-autotest__/scenarios/fonction_common.lua:366: [FO-FONCTION] "


def line(kind, minute, key, body):
    return "%s%s minute %d | %s | %s" % (PREFIX, kind, minute, key, body)


def force_lines(minute, key, *, pnj=10, fours, auto=0, coffre=0, main=0, prod=(0, 0, 0), a50=(0, 0, 0),
                ws=(0, 0, 0), ns=(0, 0, 0), eq=(0.0, 0.0, 0.0), nom=(0.0, 0.0, 0.0), cap=None, plaques=0.0,
                extra=()):
    """prod, a50, ws, ns, eq, nom : (auto, coffre, main) ; la population productive = tous les fours posés (sans jeunes)."""
    cap = 18.75 * 60 / 60 * fours if cap is None else cap
    body = ("n=%d jeunes=0 cap_min=%.1f foreuse=%d tapis=0 coffre_alimente=0 coffre=%d autre=0 aucun=%d "
            "n_auto=%d n_coffre=%d n_main=%d pop_auto=%d pop_coffre=%d pop_main=%d prod_auto=%d prod_coffre=%d prod_main=%d "
            "a50_auto=%d a50_coffre=%d a50_main=%d ws_auto=%d ws_coffre=%d ws_main=%d ns_auto=%d ns_coffre=%d ns_main=%d "
            "eq_auto=%.1f eq_coffre=%.1f eq_main=%.1f nom_auto=%.1f nom_coffre=%.1f nom_main=%.1f") % (
        fours, cap, auto, coffre, main, auto, coffre, main, auto, coffre, main, *prod, *a50, *ws, *ns, *eq, *nom)
    out = [
        line("prod", minute, key, "fenetre=10.0 pnj=%d morte=%d plaques_min=%.1f fer_min=%.1f cuivre_min=0.0 brique_min=0.0 "
             "acier_min=0.0 ore_fer_min=10.0 ore_cuivre_min=0.0 charbon_min=5.0 pierre_min=0.0 engrenages_min=0.0 "
             "circuits_min=0.0 packs_fab=0 packs_conso=0" % (pnj, 1 if pnj == 0 else 0, plaques, plaques)),
        line("fours", minute, key, body),
        line("statut", minute, key, "classe=foreuse_elec n=4 samples=80 no_power=60 working=20"),
        line("elec", minute, key, "kw_moy=0.0 kw_now=0.0 generateurs=0 chaudieres=0 poteaux=10 poteaux_reseau_gen=0 "
             "reseaux_poteaux=3 reseaux_gen=0 fours_elec=0 foreuse_elec_pose=4 foreuse_elec_reseau=0 foreuse_elec_alimentes=0 "
             "bras_elec_pose=0 bras_elec_reseau=0 bras_elec_alimentes=0"),
        line("tapis", minute, key, "tapis=100 utiles=20 pleines=60 pleines_inutiles=50 vides=10 terminaux=10 "
             "terminaux_pleins_inutiles=9"),
        line("corps", minute, key, "corps=%d relevés=200 mine=20 fabrique=20 marche=60 inerte=100 inactifs_mod_pct=0.0" % pnj),
        line("dormants", minute, key, "stock_coffre_fours=40 stock_coffre_foreuses=0 stock_coffre_assembleurs=0 "
             "stock_coffre_labos=0 stock_coffre_bras=0 stock_corps_fours=0 stock_corps_foreuses=0 stock_corps_assembleurs=0 "
             "stock_corps_labos=0 stock_corps_bras=0 inactifs_fours=%d/%d inactifs_foreuses_elec=0/0 "
             "inactifs_foreuses_comb=0/0 inactifs_assembleurs=0/0 assembleurs_recette=0 assembleurs_produit=0" % (fours - sum(prod), fours)),
        line("tech", minute, key, "researched=12 depuis_debut=9 palier_mod=2 packs_conso=0 packs_fab=0"),
        line("parite", minute, "plaques_min", "joueur=1.00 mediane=2.00 min=1.00 max=3.00 nviv=2 joueur_vivant=1"),
    ]
    out.extend(extra)
    return out


def mk_archive(root, name, seed, lines):
    d = os.path.join(root, name)
    os.makedirs(d)
    with open(os.path.join(d, "seed.txt"), "w", encoding="utf-8") as fh:
        fh.write(seed + "\n")
    with gzip.open(os.path.join(d, "benchmark.log.gz"), "wt", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return d


with tempfile.TemporaryDirectory() as tmp:
    # Cas dégénéré : 54 fours posés en carré, jamais alimentés, jamais productifs (le DC : « remplis à la main »)
    carre = force_lines(60, "scarlet", fours=54, main=54, ns=(0, 0, 1080), nom=(0.0, 0.0, 54 * 600 / 3.2), plaques=0.0)
    # Une faction saine : 10 fours alimentés par foreuse, tous à plein régime
    sain = force_lines(60, "azure", fours=10, auto=10, prod=(10, 0, 0), a50=(10, 0, 0), ws=(180, 0, 0), ns=(200, 0, 0),
                       eq=(1800.0, 0.0, 0.0), nom=(1875.0, 0.0, 0.0), plaques=180.0)
    # Votre équipe morte (aucun PNJ) : comptes figés de fours posés mais exclue des distributions
    morte = force_lines(60, "player", pnj=0, fours=11, main=11, ns=(0, 0, 220), nom=(0.0, 0.0, 11 * 600 / 3.2))
    a1 = mk_archive(tmp, "a1", "111", carre + sain + morte)
    rec = M.load(a1)
    check(rec["graine"] == "111", "graine lue dans seed.txt")
    s = rec["forces"]["scarlet"][60]["ind"]
    check(s["fours_poses"] == 54, "54 fours comptés")
    check(near(s["fours_part_alimentee"], 0.0), "54 fours en carré jamais alimentés : part alimentée 0 %% (%r)" % s["fours_part_alimentee"])
    check(near(s["fours_part_main"], 100.0), "part servie à la main 100 %")
    check(s["fours_part_productive"] == 0.0 and s["fours_part_ayant_produit"] == 0.0,
          "part productive nulle et aucun four ayant produit (%r, %r)" % (s["fours_part_productive"], s["fours_part_ayant_produit"]))
    check(s["fours_part_productive"] < 10.0, "« part productive faible » (< 10 %)")
    check(near(s["fours_equivalents"], 0.0), "0 four-équivalent")
    check(near(s["fours_part_nominale_stats"], 0.0), "0 % de la cadence nominale")
    check(near(s["tapis_part_utile"], 20.0) and near(s["tapis_part_pleine_inutile"], 50.0) and near(s["tapis_culdesac_plein"], 90.0),
          "tapis : 20 % utiles, 50 % pleins inutiles, 90 % des fins pleines sans prise")
    check(near(s["fe_no_power"], 75.0) and near(s["alim_foreuse_elec"], 0.0), "foreuses électriques : 75 % sans courant, 0 % alimentées")
    check(near(s["corps_part_inerte"], 50.0), "corps inertes 50 %")
    check(near(s["capital_inactif_fours"], 100.0), "capital posé inactif 100 % (fraction a/b lue)")
    check(s["stock_fours"] == 40, "stock de fours non posés lu")
    az = rec["forces"]["azure"][60]["ind"]
    check(near(az["fours_part_alimentee"], 100.0) and near(az["fours_part_productive"], 100.0), "faction saine : 100 % alimentés, 100 % productifs")
    check(near(az["fours_part_working"], 90.0), "part working = 180/200")
    check(near(az["fours_part_nominale"], 96.0), "production / nominal = 1800/1875")
    check(near(az["fours_equivalents"], 180.0 / (18.75)), "fours-équivalents = plaques/min ÷ cadence d'un four")
    check(rec["forces"]["player"][60]["morte"] and not rec["forces"]["azure"][60]["morte"], "équipe sans PNJ marquée morte")

    # Distribution : la force morte est exclue ; médiane de deux archives
    sain2 = force_lines(60, "azure", fours=10, auto=5, main=5, prod=(5, 0, 5), a50=(5, 0, 0), ws=(90, 0, 20), ns=(100, 0, 100),
                        eq=(900.0, 0.0, 100.0), nom=(937.5, 0.0, 937.5), plaques=100.0)
    a2 = mk_archive(tmp, "a2", "222", sain2 + force_lines(60, "scarlet", fours=54, main=54, ns=(0, 0, 1080), nom=(0.0, 0.0, 9000.0)))
    recs = [rec, M.load(a2)]
    dist = M.distribution(recs, [60])
    v = dist[("factions", 60, "fours_part_alimentee")]
    check(sorted(v) == [0.0, 0.0, 50.0, 100.0], "distribution des factions : 4 valeurs (0, 0, 50, 100) : %r" % v)
    check(M.median(v) == 25.0, "médiane de la distribution = 25")
    check(("joueur", 60, "fours_part_alimentee") not in dist, "l'équipe du joueur morte n'entre pas dans la distribution")
    al = M.count_alive(recs, [60])
    check(al[("joueur", 60)] == (0, 2) or al[("joueur", 60)] == (0, 1), "décompte des vivantes : joueur mort listé")
    par = M.parity(rec, 60, ["plaques_min", "fours_part_alimentee"])
    check(par["plaques_min"][0] is None and par["plaques_min"][1] == 90.0 and par["plaques_min"][2] == 2,
          "parité : joueur mort -> None ; médiane des 2 factions vivantes (0 et 180) = 90 : %r" % (par["plaques_min"],))

    # Sortie texte : lisible, sans plantage ; CLI avec deux archives
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = M.main(["x", a1, a2, "--minutes", "60"])
    txt = buf.getvalue()
    check(rc == 0 and "fours alimentés structurellement" in txt and "MORTE aux minutes 60" in txt and "distribution sur 2" in txt,
          "CLI : tableau par force, force morte signalée, distribution")
    # journal non compressé et archive vide
    d3 = os.path.join(tmp, "a3")
    os.makedirs(d3)
    with open(os.path.join(d3, "benchmark.log"), "w", encoding="utf-8") as fh:
        fh.write("rien\n")
    check(M.load(d3)["forces"] == {} and M.read_seed(d3) == "?", "archive sans ligne [FO-FONCTION] : vide")

check(M.parse_kv("a=1 b=2.5 c=3/4 d=mot relevés=7") == {"a": 1, "b": 2.5, "c": (3, 4), "d": "mot", "relevés": 7}, "parse_kv")
check(M.pct(1, 0) is None and M.pct(1, 4) == 25.0, "pct : dénominateur nul = rien")

print("BILAN : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(0 if fail == 0 else 1)
