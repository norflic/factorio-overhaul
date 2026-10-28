# -*- coding: utf-8 -*-
"""Lot MESURES : lecture des lignes [FO-FONCTION] (scenarios/fonction_common.lua) d'une ou plusieurs archives.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/fonction_mesures.py <archive> [<archive> ...]
            [--minutes 20,40,60] [--distribution] [--seul-dist] [--json <fichier>]
Chaque archive est un dossier rendu par banc.py (benchmark.log.gz ou benchmark.log, seed.txt).

Rend :
  - par archive (graine) et par force, les indicateurs FONCTIONNELS aux minutes demandées (20/40/60 par défaut) ;
  - avec plusieurs archives (ou --distribution) : par indicateur et par minute, la distribution sur toutes les
    (archive x force) VIVANTES (médiane, min, max, n), votre équipe à part des factions. Aucun seuil n'est appliqué :
    docs/PORTES_MESURES.md ne fixe les seuils qu'après lecture d'une distribution sur des graines de RÉGLAGE.
Une force « morte » (aucun corps de PNJ : champ morte=1) est listée mais exclue des distributions.
Valeurs en pourcentage (0 à 100) sauf mention contraire. « - » : indicateur sans objet (dénominateur nul).
"""
import gzip
import json
import os
import re
import sys

RE_LINE = re.compile(r"\[FO-FONCTION\] (\w+) minute (\d+) \| ([^|]+?) \| (.*)$")
RE_KV = re.compile(r"(\w+)=(\S+)")
RE_FRAC = re.compile(r"^(-?\d+)/(-?\d+)$")


def read_log(arch):
    for name in ("benchmark.log.gz", "benchmark.log"):
        p = os.path.join(arch, name)
        if os.path.exists(p):
            opener = gzip.open if name.endswith(".gz") else open
            with opener(p, "rt", encoding="utf-8", errors="replace") as fh:
                return fh.read().splitlines()
    return []


def read_seed(arch):
    try:
        with open(os.path.join(arch, "seed.txt"), encoding="utf-8") as fh:
            return fh.read().strip().splitlines()[0]
    except (OSError, IndexError):
        return "?"


def parse_kv(body):
    """« a=1 b=2.5 c=3/4 d=mot » -> {a: 1, b: 2.5, c: (3, 4), d: 'mot'}"""
    out = {}
    for k, v in RE_KV.findall(body):
        m = RE_FRAC.match(v)
        if m:
            out[k] = (int(m.group(1)), int(m.group(2)))
            continue
        try:
            out[k] = int(v)
        except ValueError:
            try:
                out[k] = float(v)
            except ValueError:
                out[k] = v
    return out


def parse_lines(lines):
    """-> { (clé, minute): { genre: dict | { classe: dict } pour 'statut', ... } } (dernière occurrence)."""
    data = {}
    for ln in lines:
        m = RE_LINE.search(ln)
        if not m:
            continue
        kind, minute, key, body = m.group(1), int(m.group(2)), m.group(3).strip(), m.group(4)
        kv = parse_kv(body)
        if kind == "parite":
            continue  # la parité se recalcule ici (parity()) sur les indicateurs dérivés
        slot = data.setdefault((key, minute), {})
        if kind == "statut":
            slot.setdefault("statut", {})[kv.get("classe", "?")] = kv
        else:
            slot[kind] = kv
    return data


def pct(a, b):
    return 100.0 * a / b if b else None


def get(d, k, default=0):
    v = d.get(k, default)
    return default if isinstance(v, (tuple, str)) else v


def status_share(slot, cls, names):
    st = slot.get("statut", {}).get(cls)
    if not st:
        return None
    n = get(st, "samples")
    return pct(sum(get(st, x) for x in names), n)


def derive(slot):
    """Indicateurs fonctionnels d'une force à une minute (dict nom -> nombre ou None)."""
    out = {}
    fo = slot.get("fours")
    pr = slot.get("prod", {})
    if fo:
        n = get(fo, "n")
        pop = sum(get(fo, "pop_" + g) for g in ("auto", "coffre", "main"))
        a50 = sum(get(fo, "a50_" + g) for g in ("auto", "coffre", "main"))
        prod = sum(get(fo, "prod_" + g) for g in ("auto", "coffre", "main"))
        ws = sum(get(fo, "ws_" + g) for g in ("auto", "coffre", "main"))
        ns = sum(get(fo, "ns_" + g) for g in ("auto", "coffre", "main"))
        eq = sum(get(fo, "eq_" + g, 0.0) for g in ("auto", "coffre", "main"))
        nom = sum(get(fo, "nom_" + g, 0.0) for g in ("auto", "coffre", "main"))
        out["fours_poses"] = n
        out["fours_part_alimentee"] = pct(get(fo, "n_auto"), n)
        out["fours_part_coffre"] = pct(get(fo, "n_coffre"), n)
        out["fours_part_main"] = pct(get(fo, "n_main"), n)
        out["fours_part_ayant_produit"] = pct(prod, pop)
        out["fours_part_productive"] = pct(a50, pop)  # >= 50 % de la cadence nominale
        out["fours_part_productive_auto"] = pct(get(fo, "a50_auto"), get(fo, "pop_auto"))
        out["fours_part_productive_main"] = pct(get(fo, "a50_main"), get(fo, "pop_main"))
        out["fours_part_working"] = pct(ws, ns)
        out["fours_part_nominale"] = pct(eq, nom)  # production mesurée aux machines / cadence nominale
        cap = get(fo, "cap_min", 0.0)
        eqs = get(pr, "plaques_min", 0.0) + 5 * get(pr, "acier_min", 0.0)
        if pr:
            out["fours_part_nominale_stats"] = pct(eqs, cap)
            out["fours_equivalents"] = (eqs / (cap / n)) if cap and n else None
        out["fours_jeunes"] = get(fo, "jeunes")
    if pr:
        out["plaques_min"] = get(pr, "plaques_min", 0.0)
        out["minerai_min"] = sum(get(pr, k, 0.0) for k in ("ore_fer_min", "ore_cuivre_min", "charbon_min", "pierre_min"))
        out["packs_fab"] = get(pr, "packs_fab")
        out["packs_conso"] = get(pr, "packs_conso")
        out["pnj"] = get(pr, "pnj")
    # foreuses
    for cls, tag in (("foreuse_elec", "fe"), ("foreuse_comb", "fc")):
        st = slot.get("statut", {}).get(cls)
        if st:
            out[tag + "_n"] = get(st, "n")
            out[tag + "_working"] = status_share(slot, cls, ["working"])
            out[tag + "_no_power"] = status_share(slot, cls, ["no_power", "low_power", "not_plugged_in_electric_network"])
            out[tag + "_no_fuel"] = status_share(slot, cls, ["no_fuel"])
            out[tag + "_epuisees"] = status_share(slot, cls, ["no_minable_resources"])
            out[tag + "_sortie_pleine"] = status_share(slot, cls, ["waiting_for_space_in_destination"])
        else:
            out[tag + "_n"] = 0
    # électricité
    el = slot.get("elec")
    if el:
        out["kw_moy"] = get(el, "kw_moy", 0.0)
        out["poteaux"] = get(el, "poteaux")
        out["poteaux_part_reseau_gen"] = pct(get(el, "poteaux_reseau_gen"), get(el, "poteaux"))
        out["reseaux_poteaux"] = get(el, "reseaux_poteaux")
        for cls in ("foreuse_elec", "bras_elec", "assembleur", "labo"):
            out["alim_" + cls] = pct(get(el, cls + "_alimentes"), get(el, cls + "_pose"))
    br = slot.get("bras")
    if br:
        out["bras_elec"] = get(br, "elec")
        out["bras_therm"] = get(br, "therm")
        out["bras_part_therm"] = pct(get(br, "therm"), get(br, "elec") + get(br, "therm"))
        out["bras_elec_sains"] = status_share(slot, "bras_elec", ["working", "waiting_for_source_items", "waiting_for_space_in_destination"])
        out["bras_elec_no_power"] = status_share(slot, "bras_elec", ["no_power", "low_power", "not_plugged_in_electric_network"])
        out["bras_elec_working"] = status_share(slot, "bras_elec", ["working"])
    tp = slot.get("tapis")
    if tp:
        out["tapis"] = get(tp, "tapis")
        out["tapis_part_utile"] = pct(get(tp, "utiles"), get(tp, "tapis"))
        out["tapis_part_pleine_inutile"] = pct(get(tp, "pleines_inutiles"), get(tp, "tapis"))
        out["tapis_culdesac_plein"] = pct(get(tp, "terminaux_pleins_inutiles"), get(tp, "terminaux"))
    tu = slot.get("tourelles")
    if tu:
        out["tourelles"] = get(tu, "n")
        out["tourelles_part_armee"] = pct(get(tu, "armees"), get(tu, "n"))
    co = slot.get("corps")
    if co:
        b = get(co, "relevés") or get(co, "releves")
        out["corps_part_inerte"] = pct(get(co, "inerte"), b)
        out["corps_part_mine"] = pct(get(co, "mine"), b)
        out["corps_part_fabrique"] = pct(get(co, "fabrique"), b)
        out["corps_part_marche"] = pct(get(co, "marche"), b)
        v = get(co, "inactifs_mod_pct", -1.0)
        out["inactifs_mod"] = v if v >= 0 else None
        if pr and get(pr, "fenetre", 0.0) and b:
            out["plaques_par_pnj_min"] = out.get("plaques_min", 0.0) / max(1, get(co, "corps"))
    do = slot.get("dormants")
    if do:
        out["stock_fours"] = get(do, "stock_coffre_fours") + get(do, "stock_corps_fours")
        out["stock_foreuses"] = get(do, "stock_coffre_foreuses") + get(do, "stock_corps_foreuses")
        out["stock_assembleurs"] = get(do, "stock_coffre_assembleurs") + get(do, "stock_corps_assembleurs")
        for k, tag in (("inactifs_fours", "fours"), ("inactifs_foreuses_elec", "foreuses_elec"),
                       ("inactifs_foreuses_comb", "foreuses_comb"), ("inactifs_assembleurs", "assembleurs")):
            v = do.get(k)
            if isinstance(v, tuple):
                out["capital_inactif_" + tag] = pct(v[0], v[1])
        out["assembleurs_recette"] = get(do, "assembleurs_recette")
        out["assembleurs_produit"] = get(do, "assembleurs_produit")
    te = slot.get("tech")
    if te:
        out["techs"] = get(te, "researched")
        out["techs_depuis_debut"] = get(te, "depuis_debut")
    return out


def force_dead(slot):
    pr = slot.get("prod", {})
    return get(pr, "morte", 0) == 1 or get(pr, "pnj", 1) == 0


ORDER = [
    ("fours_poses", "fours posés (compte, pour mémoire)"),
    ("fours_part_alimentee", "fours alimentés structurellement (foreuse, tapis, coffre alimenté) %"),
    ("fours_part_main", "fours posés et servis à la main %"),
    ("fours_part_ayant_produit", "fours ayant produit (>= 1 plaque dans la fenêtre) %"),
    ("fours_part_productive", "fours à >= 50 % de la cadence nominale %"),
    ("fours_part_productive_auto", "  dont parmi les alimentés %"),
    ("fours_part_productive_main", "  dont parmi les servis à la main %"),
    ("fours_part_working", "fours working (part des relevés) %"),
    ("fours_part_nominale", "production des fours / cadence nominale (products_finished) %"),
    ("fours_part_nominale_stats", "plaques des statistiques / cadence nominale des fours posés %"),
    ("fours_equivalents", "fours-équivalents (statistiques de force)"),
    ("plaques_min", "plaques/min (fer, cuivre, brique) statistiques de force"),
    ("minerai_min", "minerai/min (fer, cuivre, charbon, pierre)"),
    ("fe_n", "foreuses électriques posées"),
    ("fe_working", "foreuses électriques working %"),
    ("fe_no_power", "foreuses électriques sans courant %"),
    ("fc_n", "foreuses à combustion posées"),
    ("fc_working", "foreuses à combustion working %"),
    ("fc_no_fuel", "foreuses à combustion sans combustible %"),
    ("fc_sortie_pleine", "foreuses à combustion sortie pleine %"),
    ("fc_epuisees", "foreuses à combustion sans minerai %"),
    ("kw_moy", "kW générés (moyenne des relevés)"),
    ("poteaux", "poteaux (compte)"),
    ("poteaux_part_reseau_gen", "poteaux dans le réseau d'un générateur %"),
    ("reseaux_poteaux", "réseaux de poteaux distincts"),
    ("alim_foreuse_elec", "foreuses électriques alimentées (réseau du générateur, courant) %"),
    ("alim_bras_elec", "bras électriques alimentés %"),
    ("alim_assembleur", "assembleurs alimentés %"),
    ("alim_labo", "labos alimentés %"),
    ("bras_elec", "bras électriques posés"),
    ("bras_therm", "bras thermiques posés"),
    ("bras_elec_sains", "bras électriques en état sain (working ou en attente) %"),
    ("bras_elec_no_power", "bras électriques sans courant %"),
    ("tapis", "tapis posés (compte)"),
    ("tapis_part_utile", "tapis utiles (en amont d'une prise de bras) %"),
    ("tapis_part_pleine_inutile", "tapis pleins inutiles % des tapis"),
    ("tapis_culdesac_plein", "culs-de-sac pleins sans prise % des fins de tapis"),
    ("tourelles", "tourelles à munitions posées"),
    ("tourelles_part_armee", "tourelles armées (>= 5 chargeurs) %"),
    ("corps_part_inerte", "corps de PNJ inertes (immobiles, ni minage ni fabrication) %"),
    ("corps_part_mine", "corps de PNJ qui minent à la main %"),
    ("corps_part_fabrique", "corps de PNJ qui fabriquent à la main %"),
    ("corps_part_marche", "corps de PNJ en déplacement %"),
    ("inactifs_mod", "inactifs selon le mod (task nil) %"),
    ("plaques_par_pnj_min", "plaques/min par PNJ"),
    ("stock_fours", "fours en stock non posés (coffre, annexes, corps)"),
    ("stock_foreuses", "foreuses en stock non posées"),
    ("capital_inactif_fours", "fours posés inactifs (<= 20 % working sur >= 5 relevés) %"),
    ("capital_inactif_foreuses_elec", "foreuses électriques posées inactives %"),
    ("capital_inactif_foreuses_comb", "foreuses à combustion posées inactives %"),
    ("capital_inactif_assembleurs", "assembleurs posés inactifs %"),
    ("assembleurs_produit", "assembleurs ayant produit"),
    ("techs", "technologies terminées"),
    ("techs_depuis_debut", "technologies terminées depuis le début"),
    ("packs_fab", "packs fabriqués (machines) dans la fenêtre"),
    ("packs_conso", "packs consommés (labos) dans la fenêtre"),
]


def fmt(v):
    if v is None:
        return "-"
    if isinstance(v, float):
        return ("%.1f" % v)
    return str(v)


def load(arch):
    """-> { 'graine', 'forces': { clé: { minute: {'ind': dict, 'morte': bool} } } }"""
    data = parse_lines(read_log(arch))
    forces = {}
    for (key, minute), slot in sorted(data.items()):
        if "prod" not in slot and "fours" not in slot:
            continue
        forces.setdefault(key, {})[minute] = {"ind": derive(slot), "morte": force_dead(slot)}
    return {"graine": read_seed(arch), "forces": forces, "archive": arch}


def nearest(minutes, want):
    best = None
    for m in minutes:
        if m <= want and (best is None or m > best):
            best = m
    return best


def print_archive(rec, minutes, out=None):
    out = out or sys.stdout
    out.write("== graine %s (%s)\n" % (rec["graine"], os.path.basename(rec["archive"].rstrip("/\\"))))
    keys = sorted(rec["forces"], key=lambda k: (k != "player", k))
    for key in keys:
        fm = rec["forces"][key]
        cols = [(m, nearest(fm.keys(), m)) for m in minutes]
        head = "  %s" % ("VOTRE EQUIPE" if key == "player" else key)
        dead = [m for m, mm in cols if mm is not None and fm[mm]["morte"]]
        out.write(head + ("   [MORTE aux minutes %s]" % ",".join(str(x) for x in dead) if dead else "") + "\n")
        out.write("    %-78s %s\n" % ("indicateur", " ".join("%8s" % ("m%d" % m) for m, _ in cols)))
        for name, label in ORDER:
            vals = [fm[mm]["ind"].get(name) if mm is not None else None for _, mm in cols]
            if all(v is None for v in vals):
                continue
            out.write("    %-78s %s\n" % (label[:78], " ".join("%8s" % fmt(v) for v in vals)))


def median(xs):
    xs = sorted(xs)
    n = len(xs)
    if n == 0:
        return None
    return xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2


def distribution(recs, minutes):
    """-> { (groupe, minute, indicateur): [valeurs] } sur les forces vivantes ; groupe 'joueur' ou 'factions'."""
    dist = {}
    for rec in recs:
        for key, fm in rec["forces"].items():
            group = "joueur" if key == "player" else "factions"
            for m in minutes:
                mm = nearest(fm.keys(), m)
                if mm is None or fm[mm]["morte"]:
                    continue
                for name, v in fm[mm]["ind"].items():
                    if v is not None:
                        dist.setdefault((group, m, name), []).append(v)
    return dist


def count_alive(recs, minutes):
    """-> { (groupe, minute): (vivantes, total) }"""
    cnt = {}
    for rec in recs:
        for key, fm in rec["forces"].items():
            group = "joueur" if key == "player" else "factions"
            for m in minutes:
                mm = nearest(fm.keys(), m)
                if mm is None:
                    continue
                a, t = cnt.get((group, m), (0, 0))
                cnt[(group, m)] = (a + (0 if fm[mm]["morte"] else 1), t + 1)
    return cnt


def print_distribution(recs, minutes, out=None):
    out = out or sys.stdout
    dist = distribution(recs, minutes)
    alive = count_alive(recs, minutes)
    out.write("== distribution sur %d archive(s) : graines %s ; forces vivantes seulement\n" % (
        len(recs), ",".join(r["graine"] for r in recs)))
    for m in minutes:
        out.write("-- minute %d : joueur vivant %s, factions vivantes %s\n" % (
            m, "%d/%d" % alive.get(("joueur", m), (0, 0)), "%d/%d" % alive.get(("factions", m), (0, 0))))
        out.write("    %-78s %-26s %-26s\n" % ("indicateur", "joueur (med min max n)", "factions (med min max n)"))
        for name, label in ORDER:
            cells = []
            for g in ("joueur", "factions"):
                v = dist.get((g, m, name))
                cells.append("%s %s %s %d" % (fmt(median(v)), fmt(min(v)), fmt(max(v)), len(v)) if v else "-")
            if cells == ["-", "-"]:
                continue
            out.write("    %-78s %-26s %-26s\n" % (label[:78], cells[0], cells[1]))


def parity(rec, minute, indicators):
    """Joueur contre la médiane des factions VIVANTES d'une archive (information, aucun seuil) ->
    { indicateur: (joueur, médiane, nviv) } ; joueur mort : (None, médiane, nviv)."""
    res = {}
    fm_all = rec["forces"]
    for name in indicators:
        vals = []
        for key, fm in fm_all.items():
            mm = nearest(fm.keys(), minute)
            if key == "player" or mm is None or fm[mm]["morte"]:
                continue
            v = fm[mm]["ind"].get(name)
            if v is not None:
                vals.append(v)
        pj = None
        if "player" in fm_all:
            mm = nearest(fm_all["player"].keys(), minute)
            if mm is not None and not fm_all["player"][mm]["morte"]:
                pj = fm_all["player"][mm]["ind"].get(name)
        res[name] = (pj, median(vals), len(vals))
    return res


def main(argv):
    args = argv[1:]
    minutes = [20, 40, 60]
    js = None
    force_dist = False
    only_dist = False
    archs = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--minutes":
            minutes = [int(x) for x in args[i + 1].split(",")]
            i += 1
        elif a == "--json":
            js = args[i + 1]
            i += 1
        elif a == "--distribution":
            force_dist = True
        elif a == "--seul-dist":
            force_dist = only_dist = True
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            archs.append(a)
        i += 1
    if not archs:
        print(__doc__)
        return 2
    recs = [load(a) for a in archs]
    recs = [r for r in recs if r["forces"]]
    if not recs:
        print("aucune ligne [FO-FONCTION] dans les archives données")
        return 1
    if not only_dist:
        for r in recs:
            print_archive(r, minutes)
    if len(recs) > 1 or force_dist:
        print_distribution(recs, minutes)
    if js:
        dist = distribution(recs, minutes)
        payload = {"%s|%d|%s" % k: v for k, v in sorted(dist.items())}
        with open(js, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
