# -*- coding: utf-8 -*-
"""Lot PROGRESSION (directive du DC du 8/11, 18 h 40) : la progression d'une partie, par équipe et par tranche de 10 min.

Usage : PYTHONUTF8=1 py -3.9 -B tools/autotest/progression.py <archive> [<archive> ...] [--json <fichier>] [--inventaire]
  <archive> : dossier rendu par banc.py (benchmark.log.gz ou benchmark.log), ou le fichier de journal lui-même.
  --inventaire : compte les lignes [FO-...] par étiquette (ce qui apparaît et ce qui n'apparaît jamais).
  --json : écrit le détail (tranches, facteurs, verdicts) pour un autre outil.

Lecture seule : aucun jeu lancé, rien n'est écrit dans l'archive.

Sources (toutes lues dans le journal, aucune recalculée) :
  - PRODUCTION par minute (plaques de fer, de cuivre, acier, circuits, packs fabriqués) : [FO-FONCTION] prod minute N | équipe |
    fenetre=… fer_min=… cuivre_min=… acier_min=… circuits_min=… packs_fab=… (fenêtres de 10 min, scenarios/fonction_common.lua).
    Il n'existe PAS de ligne [FO-PRODUCTION] dans le jeu : le tag n'est émis que par un outil de rendu, pas par le mod.
    [FO-BILAN] ne donne que les soldes sous/sur-production (pas des débits totaux) : non utilisé pour la production.
  - FOREUSES : [FO-GEANTS] TOTAL (foreuses posées sur les gisements géants, électriques et thermiques),
    [FO-ELECTRIQUE] (thermiques debout, électriques qui tournent, à « a X min »),
    [FO-ETAPE1-GUIDE] base (foreuses_elec, foreuses_comb, par équipe toutes les 10 min).
  - TAPIS : [FO-FONCTION] tapis (tapis=…), [FO-LIAISON] et [FO-PIQUAGE] « projet … planifie … N tuile(s) de tapis ».
  - LIAISONS, PIQUAGES, BUS, RANGÉES : comptes de lignes (un projet = une ligne). Une ligne sans minute est rattachée à la
    dernière minute de jeu vue dans le journal (approximation, dite dans la sortie).
  - INACTIVITÉ : [FO-ZERO-IDLE] (PNJ libres sans tâche, moyenne de la tranche), [FO-ACTIF] (comptes de lignes).
  - MALL : [FO-MALL] (comptes de lignes). RECHERCHES FINIES : tech= de [FO-ETAPE1-GUIDE] base (ou recherches_faites= du kit).

Croissance : facteur de la production d'une tranche à la suivante (×N par 10 min) ; une série est « exponentielle » quand
le facteur reste au-dessus de 1,3 sur 3 tranches de suite (règle du DC). Un facteur n'existe que si la tranche
précédente est > 0 (pas de division par zéro : un début à zéro n'est pas compté comme une croissance infinie).
"""
import argparse
import gzip
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

TRANCHE_MIN = 10
SEUIL_CROISSANCE = 1.3
SERIES_EXPO = 3  # nombre de facteurs de suite au-dessus du seuil

PRODUCTION = ("fer_min", "cuivre_min", "acier_min", "circuits_min", "packs_fab", "plaques_min")

RE_TAG = re.compile(r"\[FO-([A-Z0-9-]+)\]")
RE_MIN = re.compile(r"\[FO-(?P<tag>[A-Z0-9-]+)\] (?:(?P<genre>[a-z][a-z-]*) )?minute (?P<m>\d+(?:\.\d+)?) \| "
                    r"(?P<key>[^|]+?) \| (?P<body>.*)$")
RE_KEY_MIN = re.compile(r"\[FO-(?P<tag>ZERO-IDLE|MALL)\] (?P<key>\S+) minute (?P<m>\d+(?:\.\d+)?) \| (?P<body>.*)$")
RE_A_MIN = re.compile(r"\ba (\d+(?:\.\d+)?) min\b")
RE_KV = re.compile(r"(\w+)=(-?\d+(?:\.\d+)?)")
RE_TOT = re.compile(r"\[FO-GEANTS\] minute (?P<m>\d+(?:\.\d+)?) \| (?P<key>[^|]+?) \| TOTAL .*?\| foreuses dessus "
                    r"elec=(?P<e>\d+) therm=(?P<t>\d+)")
RE_ELEC = re.compile(r"\[FO-ELECTRIQUE\] (?P<key>\S+) : thermiques debout (?P<th>\d+) .*?electriques qui tournent (?P<el>\d+)")
RE_IDLE = re.compile(r"PNJ libres (\d+) sans tache")
RE_TUILES = re.compile(r"(\d+) tuile\(s\) de tapis")

# Mesures : (reducteur, est-ce une moyenne sur la tranche ?) ; « last » = la dernière valeur de la tranche.
MESURES = {
    "fer_min": "last", "cuivre_min": "last", "acier_min": "last", "circuits_min": "last", "packs_fab": "last",
    "plaques_min": "last", "fe_elec": "last", "fe_therm": "last", "th_debout": "last", "el_live": "last",
    "base_elec": "last", "base_comb": "last", "tapis_fn": "last", "tech": "last", "pnj_libres": "moyenne",
}
COMPTES = ("liaison", "piquage", "bus", "rangee", "actif", "mall", "tuiles_liaison", "tuiles_piquage")


def lire_journal(chemin):
    """Lignes du journal d'une archive (dossier) ou d'un fichier ; [] si rien."""
    if os.path.isdir(chemin):
        for nom in ("benchmark.log.gz", "benchmark.log"):
            p = os.path.join(chemin, nom)
            if os.path.exists(p):
                chemin = p
                break
        else:
            return []
    opener = gzip.open if chemin.endswith(".gz") else open
    with opener(chemin, "rt", encoding="utf-8", errors="replace") as fh:
        return fh.read().splitlines()


def tranche_de(minute):
    """Fin de la tranche de 10 min qui contient cette minute (9,5 -> 10 ; 10 -> 10 ; 10,5 -> 20)."""
    return int(math.ceil(minute / TRANCHE_MIN - 1e-9)) * TRANCHE_MIN


def kv(body):
    return {k: float(v) for k, v in RE_KV.findall(body)}


class Journal:
    """Accumule les mesures par équipe et par tranche, et les comptes de lignes."""

    def __init__(self):
        self.mesures = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))  # équipe -> tranche -> nom -> [valeurs]
        self.comptes = defaultdict(lambda: defaultdict(Counter))  # équipe -> tranche -> nom -> n
        self.inventaire = Counter()
        self.minute_courante = None
        self.equipes = set()

    @staticmethod
    def _eq(equipe):
        # le guide écrit « VOTRE EQUIPE » là où les autres lignes écrivent « player » : une seule clé
        return "player" if equipe.upper().startswith("VOTRE EQUIPE") else equipe

    def _mesure(self, equipe, minute, nom, valeur):
        equipe = self._eq(equipe)
        self.mesures[equipe][tranche_de(minute)][nom].append(valeur)
        self.equipes.add(equipe)

    def _compte(self, equipe, minute, nom, n=1):
        equipe = self._eq(equipe)
        self.comptes[equipe][tranche_de(minute)][nom] += n
        self.equipes.add(equipe)

    def _minute_de(self, ligne):
        m = RE_A_MIN.search(ligne)
        if m:
            return float(m.group(1))
        return self.minute_courante

    def ligne(self, texte):
        tags = RE_TAG.findall(texte)
        for t in tags:
            self.inventaire[t] += 1
        if not tags:
            return
        mk = RE_KEY_MIN.search(texte)  # équipe AVANT « minute » : essayé d'abord, sinon « 3 pensee(s) » serait pris pour l'équipe
        if mk:
            minute = float(mk.group("m"))
            self.minute_courante = max(self.minute_courante or 0.0, minute)
            self._min(mk.group("tag"), None, minute, mk.group("key"), mk.group("body"))
            return
        mm = RE_MIN.search(texte)
        if mm:
            minute = float(mm.group("m"))
            self.minute_courante = max(self.minute_courante or 0.0, minute)
            self._min(mm.group("tag"), mm.group("genre"), minute, mm.group("key").strip(), mm.group("body"))
            return
        self._sans_minute(texte)

    def _min(self, tag, genre, minute, equipe, body):
        if tag == "FONCTION" and genre == "prod":
            v = kv(body)
            for nom in ("fer_min", "cuivre_min", "acier_min", "circuits_min", "packs_fab", "plaques_min"):
                if nom in v:
                    self._mesure(equipe, minute, nom, v[nom])
        elif tag == "FONCTION" and genre == "tapis":
            v = kv(body)
            if "tapis" in v:
                self._mesure(equipe, minute, "tapis_fn", v["tapis"])
        elif tag == "ETAPE1-GUIDE" and genre == "base":
            v = kv(body)
            for src, dst in (("foreuses_elec", "base_elec"), ("foreuses_comb", "base_comb"), ("tech", "tech")):
                if src in v:
                    self._mesure(equipe, minute, dst, v[src])
        elif tag == "ETAPE1-GUIDE" and genre == "kit-mesure":
            v = kv(body)
            if "recherches_faites" in v:
                self._mesure(equipe, minute, "tech", v["recherches_faites"])
        elif tag == "GEANTS":
            if body.startswith("TOTAL"):
                t = RE_TOT.search(f"[FO-GEANTS] minute {minute} | {equipe} | {body}")
                if t:
                    self._mesure(equipe, minute, "fe_elec", float(t.group("e")))
                    self._mesure(equipe, minute, "fe_therm", float(t.group("t")))
        elif tag == "ZERO-IDLE":
            mi = RE_IDLE.search(body)
            if mi:
                self._mesure(equipe, minute, "pnj_libres", float(mi.group(1)))
            self._compte(equipe, minute, "zero_idle")
        elif tag == "MALL":
            self._compte(equipe, minute, "mall")

    def _sans_minute(self, texte):
        mel = RE_ELEC.search(texte)
        if mel:
            minute = self._minute_de(texte)
            if minute is not None:
                self._mesure(mel.group("key"), minute, "th_debout", float(mel.group("th")))
                self._mesure(mel.group("key"), minute, "el_live", float(mel.group("el")))
            return
        mt = re.search(r"\[FO-ACTIF\] (\S+) :", texte)
        mg = re.search(r"\[FO-(LIAISON|PIQUAGE|BUS|RANGEES)\] (\S+) :", texte)
        if mt:
            minute = self._minute_de(texte)
            if minute is not None:
                self._compte(mt.group(1), minute, "actif")
            return
        if mg:
            tag, equipe = mg.group(1), mg.group(2)
            minute = self._minute_de(texte)
            if minute is None:
                return
            if tag in ("LIAISON", "PIQUAGE") and "planifie" in texte:
                nom = "liaison" if tag == "LIAISON" else "piquage"
                self._compte(equipe, minute, nom)
                tu = RE_TUILES.search(texte)
                if tu:
                    self._compte(equipe, minute, "tuiles_" + nom, int(tu.group(1)))
            elif tag == "BUS":
                self._compte(equipe, minute, "bus")
            elif tag == "RANGEES":
                self._compte(equipe, minute, "rangee")
            return

    def moyenne(self, equipe, tranche, nom):
        vals = self.mesures.get(equipe, {}).get(tranche, {}).get(nom)
        if not vals:
            return None
        return sum(vals) / len(vals)

    def valeur(self, equipe, tranche, nom):
        if nom not in MESURES:
            return None
        if MESURES[nom] == "moyenne":
            return self.moyenne(equipe, tranche, nom)
        vals = self.mesures.get(equipe, {}).get(tranche, {}).get(nom)
        return vals[-1] if vals else None

    def compte(self, equipe, tranche, nom):
        return self.comptes.get(equipe, {}).get(tranche, Counter()).get(nom, 0)

    def tranches(self):
        s = set()
        for equipe in self.mesures:
            s.update(self.mesures[equipe].keys())
        for equipe in self.comptes:
            s.update(self.comptes[equipe].keys())
        return sorted(t for t in s if t > 0)


def croissance(serie):
    """Facteurs v(t) / v(t-1) entre tranches consécutives ; None quand la tranche précédente est absente ou nulle."""
    facteurs = []
    for prev, cur in zip(serie, serie[1:]):
        if prev is None or cur is None or prev <= 0:
            facteurs.append(None)
        else:
            facteurs.append(cur / prev)
    return facteurs


def exponentielle(facteurs, seuil=SEUIL_CROISSANCE, serie_longue=SERIES_EXPO):
    """Vrai si le facteur reste au-dessus du seuil sur serie_longue tranches de suite (None coupe la suite)."""
    run = 0
    for f in facteurs:
        if f is not None and f > seuil:
            run += 1
            if run >= serie_longue:
                return True
        else:
            run = 0
    return False


def bilan_equipe(j, equipe, tranches):
    lignes = []
    for t in tranches:
        ligne = {"tranche": t}
        for nom in MESURES:
            ligne[nom] = j.valeur(equipe, t, nom)
        for nom in COMPTES:
            ligne[nom] = j.compte(equipe, t, nom)
        lignes.append(ligne)
    croissances = {}
    verdicts = {}
    for nom in PRODUCTION:
        serie = [ligne[nom] for ligne in lignes]
        f = croissance(serie)
        croissances[nom] = f
        verdicts[nom] = exponentielle(f)
    return {"equipe": equipe, "tranches": lignes, "croissance": croissances, "exponentielle": verdicts}


def fmt(v, n=1):
    if v is None:
        return "-"
    return f"{v:.{n}f}" if isinstance(v, float) else str(v)


def rendre(archive, rapport, inventaire):
    out = [f"== {archive}"]
    if inventaire:
        out.append("Inventaire des étiquettes [FO-...] (lignes) :")
        for t, n in rapport["inventaire"].most_common():
            out.append(f"  {t:<22} {n}")
    for eq in rapport["equipes"]:
        out.append(f"\nEquipe {eq['equipe']} :")
        out.append("  tr(min) | fer/min cuivre/min acier/min circ/min packs/min | fe_elec fe_therm | th_deb el_live |"
                   " base_elec base_comb | tapis tapis_pl | liaison piquage bus rangee | pnj_libres actif | mall tech")
        for L in eq["tranches"]:
            out.append("  {:>6} | {:>7} {:>8} {:>9} {:>7} {:>8} | {:>7} {:>8} | {:>5} {:>7} | {:>8} {:>8} | {:>5} {:>6} |"
                       " {:>8} {:>7} {:>8} {:>6} | {:>8} {:>5} | {:>4} {:>4}".format(
                           L["tranche"], fmt(L["fer_min"]), fmt(L["cuivre_min"]), fmt(L["acier_min"]),
                           fmt(L["circuits_min"]), fmt(L["packs_fab"]), fmt(L["fe_elec"], 0), fmt(L["fe_therm"], 0),
                           fmt(L["th_debout"], 0), fmt(L["el_live"], 0), fmt(L["base_elec"], 0), fmt(L["base_comb"], 0),
                           fmt(L["tapis_fn"], 0), fmt(L["tuiles_piquage"] + L["tuiles_liaison"], 0),
                           L["liaison"], L["piquage"], L["bus"], L["rangee"], fmt(L["pnj_libres"]), L["actif"],
                           L["mall"], fmt(L["tech"], 0)))
        out.append("  Croissance (facteur par tranche ; EXPONENTIELLE = > 1,3 sur 3 tranches de suite) :")
        for nom in PRODUCTION:
            facteurs = eq["croissance"][nom]
            txt = " ".join("-" if f is None else f"x{f:.2f}" for f in facteurs)
            verdict = "EXPONENTIELLE" if eq["exponentielle"][nom] else "non"
            out.append(f"    {nom:<13} {txt}  -> {verdict}")
    return "\n".join(out)


def analyser(archive):
    j = Journal()
    lignes = lire_journal(archive)
    for ln in lignes:
        if "[FO-" in ln:
            j.ligne(ln)
    tranches = j.tranches()
    equipes = []
    for eq in sorted(j.equipes):
        equipes.append(bilan_equipe(j, eq, tranches))
    return {"archive": archive, "lignes": len(lignes), "inventaire": j.inventaire, "equipes": equipes,
            "tranches": tranches}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("archives", nargs="+")
    ap.add_argument("--json")
    ap.add_argument("--inventaire", action="store_true")
    a = ap.parse_args(argv)
    resultats = []
    for arch in a.archives:
        rap = analyser(arch)
        resultats.append(rap)
        print(rendre(arch, rap, a.inventaire))
        print(f"({rap['lignes']} ligne(s) lue(s), {len(rap['tranches'])} tranche(s) de {TRANCHE_MIN} min)")
    if a.json:
        def plat(x):
            if isinstance(x, dict):
                return {str(k): plat(v) for k, v in x.items()}
            if isinstance(x, (list, tuple)):
                return [plat(v) for v in x]
            if isinstance(x, Counter):
                return dict(x)
            return x
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump(plat(resultats), fh, ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
