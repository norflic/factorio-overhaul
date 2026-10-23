"""LOT A3 (24/10) : PRODUCTION des têtes de la mitrailleuse à 64 directions (réponse du DC à Q-P2 : A, « 64 positions
comme la vanilla, une image par position »). Python 3.9. Lancé depuis la racine du mod.

    py -3.9 tools/render/pieces/levels/gun_e/produire_a3.py [--dry-run] [--ages 2-15] [--dirs 0-63] [--per 4]
        [--places 2] [--max-tetes N] [--sortie DIR] [--journal FICHIER] [--stop FICHIER] [--controle-seul]

Ce que fait l'outil :
  - cibles : têtes eNN-tete-dKK, âges 2 à 15 (l'âge 1 est la tête vanilla, rien à rendre), directions d00 à d63 SAUF
    les 4 poses déjà rendues et validées (d00 = tete-N et d16 = tete-E des sprites V3-E, d32 et d48 du lot A2) :
    14 × 60 = 840 têtes ;
  - qualité de PRODUCTION : 128 échantillons (jamais --quick), ombre à 32 (décision D-7, E66 ; identité des autres
    passes prouvée octet à octet, fo-logs/2026-10-24_A3/d7) ; bouchon arrière des âges 4 à 7 selon piece.py (secteurs
    mesurés et rampe, décision D-10) ;
  - par PAQUETS de --per têtes du même âge, une session Blender par paquet (rendre.py --only … --sessions 1), --places
    paquets en parallèle (2 au plus : chaque session prend une place du verrou de rendu, priorité basse, garde de
    disque à 1 Go) ; un cache par place (cache_p1, cache_p2), purgé des passes brutes par rendre.py ;
  - REPRENABLE : une tête est FAITE quand son dossier a un controle.json « ok » dont les sha256 égalent ceux des
    fichiers présents ; une tête faite n'est jamais refaite ; une tête absente, incomplète (passe ou spec.json manquant,
    sha256 différent) ou au contrôle en échec est (re)faite ; controle.json est effacé avant tout nouveau rendu ;
  - CONTRÔLE de chaque tête produite (controler()) : spec.json de production (128, ombre 32, ni rapide ni aperçu),
    couches = celles des poses validées de l'âge, chaque PNG hr et normal présent, sha256 et dimensions du spec.json,
    normale = moitié de hr, bords PAIRS relatifs à l'origine (exigence de feuilles.py : la normale tombe au pixel),
    CADRE commun avec les masques rapides de la même pose (boîte de la couche principale à 3 px près, pixels binaires
    identiques ≥ 99 %) ; TROUS enfermés (spec.json, passe brute) : ≤ 8 px, sinon accepté par trous_a3.py (classe et
    raison, plafond mesuré), sinon « HORS REGLE » (tête gardée, signalée, code de sortie 3) ;
  - journal --journal (défaut fo-logs/2026-10-24_A3/production.log) : chaque paquet, chaque tête (secondes, trous),
    têtes faites sur total, temps moyen, heure de fin estimée ;
  - ARRÊT PROPRE : si le fichier --stop (défaut fo-logs/2026-10-24_A3/STOP) existe, aucun nouveau paquet n'est pris ; les
    paquets en cours finissent ; relancer la même commande reprend (effacer STOP d'abord) ;
  - --dry-run : liste ce qui reste à faire (par âge, et la raison pour chaque tête incomplète), sans rien lancer ;
  - --controle-seul : recontrôle les têtes présentes et écrit leur controle.json, sans rien rendre.
Sorties : --sortie (défaut fo-logs/2026-10-24_A3/sprites), au format et aux noms de fo-logs/2026-10-24_A2/sprites
(<variante>/spec.json, hr-gune-<variante>-<couche>.png, gune-<variante>-<couche>.png), plus controle.json.
Codes : 0 toutes les têtes de ce lancement faites et contrôlées ; 1 erreur (rendu en échec, contrôle en échec ou
impossible, exception, OU tête de ce lancement toujours pas faite à la fin sans STOP) ; 2 arrêt par STOP (reste du
travail) ; 3 têtes hors règle des trous ; 4 garde de disque.
Robustesse (correction M-1 de la vérification, 24/10) : controler() et etat() ne lèvent jamais d'exception (une erreur
de lecture, spec.json, PNG ou champ absent, est un ÉCHEC du contrôle écrit dans controle.json) ; une exception pendant
un paquet est journalisée avec sa trace, comptée en erreur, et le fil passe au paquet suivant ; le code de sortie se
juge à la fin sur l'état RÉEL des têtes visées par le lancement. Banc hors jeu : tools/render/tests/test_produire_a3.py
(faux rendre.py, --rendre).
"""
import argparse
import hashlib
import json
import os
import queue
import subprocess
import sys
import threading
import time
import traceback

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import masques as MQ  # noqa: E402
import trous_a3  # noqa: E402

A3 = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91\fo-logs\2026-10-24_A3"
SORTIE = os.path.join(A3, "sprites")
JOURNAL = os.path.join(A3, "production.log")
STOP = os.path.join(A3, "STOP")
MASQUES = os.path.join(A3, "masques", "m16")
MASQUES_BOUCHON = os.path.join(A3, "bouchon", "rampe80")
VALIDES = MQ.plages(MQ.VALIDES)
DEJA = (0, 16, 32, 48)            # poses déjà rendues et validées : jamais refaites
SAMPLES = 128
PAR_PASSE = {"shadow": 32}        # décision D-7 (E66)
# temps de Blender d'une tête à 128 échantillons, 2 sessions en parallèle (moyenne des poses d32 et d48 du lot A2) :
# première estimation, remplacée par les temps mesurés dès qu'une tête de l'âge est faite
A2_S = {2: 37.0, 3: 37.8, 4: 60.3, 5: 70.4, 6: 74.7, 7: 78.9, 8: 82.9, 9: 76.9, 10: 90.3, 11: 100.8, 12: 107.4,
        13: 132.4, 14: 130.1, 15: 142.5}
# disque d'une tête (Ko) : têtes d32 et d48 du lot A2 × 1,09 (ombre à 32 : PNG plus gros de 9 % à l'âge 5, pilote A3)
A2_KO = {2: 43, 3: 43, 4: 84, 5: 87, 6: 98, 7: 130, 8: 133, 9: 132, 10: 159, 11: 195, 12: 198, 13: 235, 14: 237,
         15: 310}
GAIN_D7 = 0.428                  # mesuré dos à dos par le lot A3 (d7_temps.py : 3 têtes, ordre ABBA ; E66 : 0,447)
RATIO_HORLOGE = 1.05              # pilote A3 : horloge / (Σ Blender / 2 places) = 1,05 (âge 5) et 1,02 (âge 15)
TOL_CADRE_PX = 3
TAUX_CADRE = 0.99


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def nom(e, k):
    return "e%02d-tete-d%02d" % (e, k)


def cibles(ages, dirs):
    return [(e, k) for e in ages for k in dirs if k not in DEJA]


_COUCHES = {}


def couches_attendues(e):
    if e not in _COUCHES:
        s = json.load(open(os.path.join(VALIDES[e], "e%02d-tete-N" % e, "spec.json"), encoding="utf-8"))
        _COUCHES[e] = sorted(s["layers"])
    return _COUCHES[e]


def etat(sortie, e, k):
    """(« faite » | « absente » | « incomplète : raison »). Ne lève jamais d'exception (M-1) : un état illisible est
    « incomplète », donc la tête est refaite."""
    try:
        return _etat(sortie, e, k)
    except Exception as ex:
        return "incomplète : état illisible (%s: %s)" % (type(ex).__name__, ex)


def _etat(sortie, e, k):
    d = os.path.join(sortie, nom(e, k))
    if not os.path.isdir(d) or not os.path.exists(os.path.join(d, "spec.json")):
        return "absente"
    c = os.path.join(d, "controle.json")
    if not os.path.exists(c):
        return "incomplète : pas de controle.json"
    try:
        cj = json.load(open(c, encoding="utf-8"))
    except ValueError:
        return "incomplète : controle.json illisible"
    if not cj.get("ok"):
        return "incomplète : contrôle en échec (%s)" % "; ".join(cj.get("echecs", [])[:2])
    for f, h in sorted(cj.get("fichiers", {}).items()):
        p = os.path.join(d, f)
        if not os.path.exists(p):
            return "incomplète : %s absent" % f
        if sha(p) != h:
            return "incomplète : %s modifié" % f
    return "faite"


def boite_hr(L):
    w, h = L["width"], L["height"]
    gx = L["shift"][0] * 64 - w / 2.0
    gy = L["shift"][1] * 64 - h / 2.0
    return gx, gy, w, h


def controler(sortie, e, k, masques=MASQUES, masques_bouchon=MASQUES_BOUCHON):
    """Contrôle d'une tête produite ; écrit controle.json ; renvoie le dict du contrôle. Ne lève JAMAIS d'exception
    (correction M-1 de la vérification d'A3) : une erreur de lecture (spec.json, PNG, champ absent) est un ÉCHEC du
    contrôle, et une erreur imprévue aussi (trace dans « echecs »)."""
    n = nom(e, k)
    d = os.path.join(sortie, n)
    try:
        return _controler(sortie, e, k, masques, masques_bouchon)
    except Exception as ex:  # filet : toute autre erreur devient un échec écrit, jamais un fil mort
        res = {"variant": n, "ok": False, "notes": [], "cadre": None, "seconds": None, "fichiers": {},
               "echecs": ["contrôle impossible : %s: %s" % (type(ex).__name__, ex),
                          "trace : " + " | ".join(traceback.format_exc().strip().splitlines()[-4:])],
               "trous": {"plus_grand": None, "verdict": "INCONNU"}, "date": time.strftime("%Y-%m-%d %H:%M:%S")}
        try:
            with open(os.path.join(d, "controle.json"), "w", encoding="utf-8", newline="\n") as f:
                json.dump(res, f, indent=1, sort_keys=True)
        except OSError as ex2:
            res["echecs"].append("controle.json non écrit (%s)" % ex2)
        return res


def _ecrire_controle(d, n, echecs, notes, trous, cadre, seconds, fichiers):
    res = {"variant": n, "ok": not echecs, "echecs": echecs, "notes": notes, "trous": trous, "cadre": cadre,
           "seconds": seconds, "date": time.strftime("%Y-%m-%d %H:%M:%S"), "fichiers": fichiers}
    with open(os.path.join(d, "controle.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, indent=1, sort_keys=True)
    return res


def _controler(sortie, e, k, masques, masques_bouchon):
    n = nom(e, k)
    d = os.path.join(sortie, n)
    echecs, notes = [], []
    fichiers = {}
    try:
        s = json.load(open(os.path.join(d, "spec.json"), encoding="utf-8"))
        if not isinstance(s, dict) or not isinstance(s.get("layers"), dict) or not s["layers"]:
            raise ValueError("pas de « layers »")
    except (OSError, ValueError) as ex:
        echecs.append("spec.json illisible (%s: %s)" % (type(ex).__name__, ex))
        return _ecrire_controle(d, n, echecs, notes, {"plus_grand": None, "verdict": "INCONNU"}, None, None,
                                fichiers)
    secondes = s.get("seconds")
    if not isinstance(secondes, (int, float)) or isinstance(secondes, bool) or secondes <= 0:
        echecs.append("spec.json : temps de rendu « seconds » absent ou invalide (%r)" % (secondes,))
        secondes = None
    if s.get("variant") != n:
        echecs.append("spec.json d'une autre variante (%s)" % s.get("variant"))
    if s.get("samples") != SAMPLES or s.get("quick") or s.get("apercu"):
        echecs.append("pas un rendu de production (échantillons %s, rapide %s, aperçu %s)" % (
            s.get("samples"), s.get("quick"), s.get("apercu")))
    if (s.get("samples_passes") or {}) != PAR_PASSE:
        echecs.append("échantillons par passe %s (attendu %s)" % (s.get("samples_passes"), PAR_PASSE))
    if sorted(s["layers"]) != couches_attendues(e):
        echecs.append("couches %s (attendu %s)" % (sorted(s["layers"]), couches_attendues(e)))
    fichiers["spec.json"] = sha(os.path.join(d, "spec.json"))
    for lay, L in sorted(s["layers"].items()):
        for res, LL in (("hr", L), ("lr", L["lr"])):
            p = os.path.join(d, LL["file"])
            if not os.path.exists(p):
                echecs.append("%s %s absent" % (lay, res))
                continue
            h = sha(p)
            fichiers[LL["file"]] = h
            if h != LL["sha256"]:
                echecs.append("%s %s : sha256 différent du spec.json" % (lay, res))
            try:
                with Image.open(p) as im:
                    taille = im.size
                    im.load()     # décode tout le PNG : un fichier tronqué ou corrompu échoue ici
            except Exception as ex:  # PIL lève OSError, UnidentifiedImageError, SyntaxError, ValueError…
                echecs.append("%s %s : PNG illisible (%s: %s)" % (lay, res, type(ex).__name__, ex))
                continue
            if taille != (LL["width"], LL["height"]):
                echecs.append("%s %s : %s au lieu de %sx%s" % (lay, res, taille, LL["width"], LL["height"]))
        if (L["lr"]["width"] * 2, L["lr"]["height"] * 2) != (L["width"], L["height"]):
            echecs.append("%s : normale %sx%s n'est pas la moitié de hr %sx%s" % (
                lay, L["lr"]["width"], L["lr"]["height"], L["width"], L["height"]))
        gx, gy, w, h = boite_hr(L)
        if abs(gx - round(gx)) > 1e-9 or abs(gy - round(gy)) > 1e-9 or round(gx) % 2 or round(gy) % 2 or w % 2 or h % 2:
            echecs.append("%s : bords non pairs relatifs à l'origine (%s, %s, %s, %s)" % (lay, gx, gy, w, h))
    # cadre : couche principale contre le masque rapide de la même pose
    cadre = None
    trou_masque = None
    try:
        if e in (4, 5, 6, 7) and masques_bouchon:
            MQ.AUTRES[e] = masques_bouchon
        z = MQ.charge(masques, e, "d%02d" % k)
        W, H = (int(v) for v in z["canvas"])
        ox, oy = (int(v) for v in z["origin"])
        L = s["layers"]["main"]
        im = np.asarray(Image.open(os.path.join(d, L["file"])).convert("RGBA"))[..., 3]
        gx, gy, w, h = boite_hr(L)
        x0, y0 = int(round(ox + gx)), int(round(oy + gy))
        prod = np.zeros((H, W), np.uint8)
        xa, ya, xb, yb = max(0, x0), max(0, y0), min(W, x0 + w), min(H, y0 + h)
        prod[ya:yb, xa:xb] = im[ya - y0:yb - y0, xa - x0:xb - x0]
        perdu = int((im > 0).sum()) - int((prod > 0).sum())
        a01 = MQ.alpha_prod(z, e, "d%02d" % k)
        trou_masque = MQ.plus_grand_trou(a01)[2]
        am = (a01 * 255).round().astype(np.uint8)
        bm, bp = am >= 128, prod >= 128
        union = bm | bp
        taux = float((bm == bp)[union].mean()) if union.any() else 1.0

        def bb(m):
            ys, xs = np.nonzero(m)
            return [int(xs.min()) - ox, int(ys.min()) - oy, int(xs.max()) - ox, int(ys.max()) - oy]
        bbm, bbp = bb(bm), bb(bp)
        ecart = max(abs(u - v) for u, v in zip(bbm, bbp))
        cadre = {"taux_binaire": round(taux, 5), "boite_prod": bbp, "boite_masque": bbm, "ecart_boite_px": ecart,
                 "px_hors_canevas": perdu}
        if taux < TAUX_CADRE or ecart > TOL_CADRE_PX or perdu:
            echecs.append("cadre : pixels binaires identiques au masque %.4f (seuil %.2f), écart de boîte %d px "
                          "(seuil %d), %d px hors canevas" % (taux, TAUX_CADRE, ecart, TOL_CADRE_PX, perdu))
    except Exception as ex:  # masque absent, PNG principal illisible, forme inattendue : échec, pas d'exception
        echecs.append("cadre : contrôle impossible (%s: %s)" % (type(ex).__name__, ex))
    # trous enfermés (passe brute, spec.json)
    big = (s.get("checks") or {}).get("largest_hole_px") if isinstance(s.get("checks"), dict) else None
    if not isinstance(big, int) or isinstance(big, bool) or big < 0:
        echecs.append("spec.json : « checks.largest_hole_px » absent ou invalide (%r)" % (big,))
        return _ecrire_controle(d, n, echecs, notes, {"plus_grand": None, "verdict": "INCONNU",
                                                      "masque": trou_masque}, cadre, secondes, fichiers)
    acc = trous_a3.accepte(n, trou_masque)
    if big <= 8:
        trous = {"plus_grand": big, "verdict": "OK", "masque": trou_masque}
    elif acc and big <= acc["plafond"]:
        trous = {"plus_grand": big, "verdict": "ACCEPTE", "classe": acc["classe"], "raison": acc["raison"],
                 "plafond": acc["plafond"]}
    else:
        trous = {"plus_grand": big, "verdict": "HORS REGLE",
                 "detail": ("accepté jusqu'à %d px seulement" % acc["plafond"]) if acc else "aucune acceptation"}
    return _ecrire_controle(d, n, echecs, notes, trous, cadre, secondes, fichiers)


class Journal:
    def __init__(self, path):
        self.path = path
        self.lock = threading.Lock()
        os.makedirs(os.path.dirname(path), exist_ok=True)

    def __call__(self, msg):
        ligne = "[%s] %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg)
        with self.lock:
            print(ligne, flush=True)
            with open(self.path, "a", encoding="utf-8") as f:
                f.write(ligne + "\n")


def echelle(faits_s):
    """Rapport temps mesuré / temps prévu (A2_S × (1 − GAIN_D7)) des âges déjà mesurés, interpolé linéairement selon
    A2_S pour les autres âges (pilote du lot A3 : âge 5 × 1,15, âge 15 × 1,76 : deux sessions en parallèle se gênent
    plus aux grandes têtes, F145) ; 1,0 sans mesure."""
    pts = sorted((A2_S[e], (sum(v) / len(v)) / (A2_S[e] * (1 - GAIN_D7))) for e, v in faits_s.items() if v)

    def f(e):
        if not pts:
            return 1.0
        x = A2_S[e]
        if x <= pts[0][0]:
            return pts[0][1]
        if x >= pts[-1][0]:
            return pts[-1][1]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if x0 <= x <= x1:
                return y0 + (y1 - y0) * (x - x0) / max(1e-9, x1 - x0)
        return pts[-1][1]
    return f


def mesures_faites(sortie, tout):
    """Temps de Blender (spec.json) des têtes faites, par âge."""
    res = {}
    for e, k in tout:
        c = os.path.join(sortie, nom(e, k), "controle.json")
        if os.path.exists(c):
            try:
                cj = json.load(open(c, encoding="utf-8"))
                s = cj.get("seconds")
            except Exception:  # controle.json illisible : pas de mesure, jamais d'exception (M-1)
                s = None
            if isinstance(s, (int, float)) and not isinstance(s, bool) and s > 0:
                res.setdefault(e, []).append(s)
    return res


def estimation(restants, faits_s, places, ratio_horloge):
    """Secondes d'horloge restantes : Σ temps de Blender estimé par tête / places × rapport horloge/Blender. Temps par
    tête : moyenne mesurée de l'âge, sinon A2_S × (1 − GAIN_D7) × échelle interpolée des âges mesurés."""
    f = echelle(faits_s)
    tot = 0.0
    for e, k in restants:
        m = faits_s.get(e)
        tot += (sum(m) / len(m)) if m else A2_S[e] * (1 - GAIN_D7) * f(e)
    return tot / max(1, places) * ratio_horloge


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--controle-seul", action="store_true")
    ap.add_argument("--ages", default="2-15")
    ap.add_argument("--dirs", default="0-63")
    ap.add_argument("--per", type=int, default=4)
    ap.add_argument("--places", type=int, default=2, choices=(1, 2))
    ap.add_argument("--max-tetes", type=int, default=0, help="au plus N têtes rendues par ce lancement (essais)")
    ap.add_argument("--sortie", default=SORTIE)
    ap.add_argument("--journal", default=JOURNAL)
    ap.add_argument("--stop", default=STOP)
    ap.add_argument("--masques", default=MASQUES)
    ap.add_argument("--masques-bouchon", default=MASQUES_BOUCHON)
    ap.add_argument("--rendre", default=os.path.join(HERE, "rendre.py"),
                    help="script de rendu lancé par paquet (défaut : rendre.py du kit ; les tests passent un faux)")
    a = ap.parse_args()
    ages = [e for e in MQ.plage(a.ages) if 2 <= e <= 15]
    dirs = [k for k in MQ.plage(a.dirs) if 0 <= k <= 63]
    tout = cibles(ages, dirs)
    log = Journal(a.journal)
    etats = {(e, k): etat(a.sortie, e, k) for e, k in tout}
    restants = [c for c in tout if etats[c] != "faite"]
    faits = len(tout) - len(restants)
    if a.dry_run or a.controle_seul:
        if a.controle_seul:
            n_ok = n_ko = 0
            for e, k in tout:
                if os.path.exists(os.path.join(a.sortie, nom(e, k), "spec.json")):
                    r = controler(a.sortie, e, k, a.masques, a.masques_bouchon)
                    n_ok, n_ko = n_ok + r["ok"], n_ko + (not r["ok"])
                    if not r["ok"] or r["trous"]["verdict"] != "OK":
                        print("%s : %s ; trous %s" % (nom(e, k), "OK" if r["ok"] else "; ".join(r["echecs"]),
                                                      r["trous"]))
            print("contrôle seul : %d têtes contrôlées OK, %d en échec" % (n_ok, n_ko))
            return 0 if not n_ko else 1
        print("[A3-DRY] cibles : %d têtes (âges %s, %d directions hors d00/d16/d32/d48) ; faites et contrôlées : %d ; "
              "reste : %d" % (len(tout), a.ages, len([k for k in dirs if k not in DEJA]), faits, len(restants)))
        for e in ages:
            r = [k for (ee, k) in restants if ee == e]
            nd = len([k for k in dirs if k not in DEJA])
            print("  âge %2d : %2d à faire%s" % (e, len(r), "" if not r else (" (toutes)" if len(r) == nd else
                                                                             " : " + " ".join("d%02d" % k for k in r))))
        for c in restants:
            if etats[c] != "absente":
                print("  %s : %s" % (nom(*c), etats[c]))
        hist = mesures_faites(a.sortie, cibles(range(2, 16), range(64)))
        est = estimation(restants, hist, a.places, RATIO_HORLOGE)
        print("[A3-DRY] estimation : %.1f h d'horloge avec %d place(s) (temps de Blender mesurés des âges %s, ailleurs "
              "temps d'A2 × (1 − %.3f) × échelle interpolée ; rapport horloge / (Blender / places) %.2f) ; disque : "
              "environ %.0f Mo de sprites, plus 0,2 Go au plus de passes brutes pendant les paquets"
              % (est / 3600, a.places, sorted(hist) or "aucun", GAIN_D7, RATIO_HORLOGE,
                 sum(A2_KO[e] * 1.09 for e, _ in restants) / 1e3))
        return 0
    if os.path.exists(a.stop):
        log("STOP présent (%s) : rien n'est lancé ; effacer le fichier pour reprendre" % a.stop)
        return 2
    if a.max_tetes:
        restants = restants[:a.max_tetes]
    log("DEBUT : %d têtes cibles, %d faites et contrôlées, %d à faire dans ce lancement ; %d place(s), %d par paquet ; "
        "sortie %s" % (len(tout), faits, len(restants), a.places, a.per, a.sortie))
    paquets = queue.Queue()
    for e in ages:
        r = [c for c in restants if c[0] == e]
        for i in range(0, len(r), a.per):
            paquets.put(r[i:i + a.per])
    faits_s = {}
    bilan = {"faites": faits, "hors_regle": [], "erreurs": [], "stop": False, "disque": False, "incidents": 0}
    t0 = time.time()
    somme_s = [0.0]
    verrou = threading.Lock()

    def fmt_s(v, f="%.1f s"):
        return (f % v) if isinstance(v, (int, float)) else "? s"

    def controler_et_noter(ip, e, k):
        """Contrôle d'une tête rendue ; ne lève pas (controler() ne lève pas, le reste est gardé ici)."""
        n = nom(e, k)
        try:
            if not os.path.exists(os.path.join(a.sortie, n, "spec.json")):
                log("  %s : AUCUN spec.json après le rendu" % n)
                with verrou:
                    bilan["erreurs"].append(([n], "spec"))
                return
            r = controler(a.sortie, e, k, a.masques, a.masques_bouchon)
            with verrou:
                if r["ok"]:
                    bilan["faites"] += 1
                    faits_s.setdefault(e, []).append(r["seconds"])
                    somme_s[0] += r["seconds"]
                else:
                    bilan["erreurs"].append(([n], "contrôle"))
                if r["trous"]["verdict"] == "HORS REGLE":
                    bilan["hors_regle"].append(n)
            t = r["trous"]
            log("  %s : %s ; %s ; trou %s px %s%s ; cadre %s" % (
                n, "CONTROLE OK" if r["ok"] else "CONTROLE EN ECHEC : " + "; ".join(r["echecs"]), fmt_s(r["seconds"]),
                "?" if t.get("plus_grand") is None else t["plus_grand"], t["verdict"],
                (" (%s)" % t["classe"]) if t.get("classe") else "",
                ("binaire %.4f, boîte ±%d px" % (r["cadre"]["taux_binaire"], r["cadre"]["ecart_boite_px"]))
                if r["cadre"] else "?"))
        except Exception:
            with verrou:
                bilan["erreurs"].append(([n], "exception au contrôle"))
            log("  %s : EXCEPTION au contrôle (tête comptée en erreur, refaite au prochain lancement) : %s" % (
                n, " | ".join(traceback.format_exc().strip().splitlines()[-6:])))

    def progression():
        with verrou:
            ecoule = time.time() - t0
            # rapport horloge / Blender du lancement en cours, borné (les premiers paquets attendent le démarrage)
            ratio = min(2.0, max(0.8, ecoule * a.places / somme_s[0])) if somme_s[0] else RATIO_HORLOGE
            reste = [c for c in tout if etat(a.sortie, *c) != "faite"]
            est = estimation(reste, mesures_faites(a.sortie, cibles(range(2, 16), range(64))), a.places, ratio)
            moy = {e: round(sum(v) / len(v), 1) for e, v in sorted(faits_s.items())}
            log("PROGRESSION : %d / %d têtes faites et contrôlées ; ce lancement : %d en %.0f s (%.1f s d'horloge par "
                "tête) ; temps moyen de Blender par âge %s ; reste %d têtes, fin estimée %s (%.1f h)" % (
                    len(tout) - len(reste), len(tout), sum(len(v) for v in faits_s.values()), ecoule,
                    ecoule / max(1, sum(len(v) for v in faits_s.values())), moy, len(reste),
                    time.strftime("%d/%m %H:%M", time.localtime(time.time() + est)), est / 3600))

    def traiter_paquet(ip, pq, cache):
        noms = [nom(e, k) for e, k in pq]
        for n in noms:
            c = os.path.join(a.sortie, n, "controle.json")
            if os.path.exists(c):
                os.remove(c)
        log("place %d : paquet %s" % (ip, ",".join(noms)))
        tp = time.time()
        cmd = [sys.executable, a.rendre, "--out", a.sortie, "--cache", cache, "--only",
               ",".join(noms), "--samples", str(SAMPLES), "--samples-passes",
               ",".join("%s=%d" % kv for kv in sorted(PAR_PASSE.items())), "--per", str(len(noms)), "--sessions",
               "1"]
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           env=dict(os.environ, PYTHONUTF8="1", PYTHONIOENCODING="utf-8"))
        txt = p.stdout.decode("utf-8", "replace")
        with open(os.path.join(os.path.dirname(a.journal), "rendre-p%d.log" % ip), "a", encoding="utf-8") as f:
            f.write(txt)
        dt = time.time() - tp
        if p.returncode:
            refus = "[fo-render] REFUS" in txt
            with verrou:
                bilan["erreurs"].append((noms, p.returncode))
                if refus:
                    bilan["disque"] = True
            log("place %d : paquet en ECHEC (code %d%s) après %.0f s : %s" % (
                ip, p.returncode, ", garde de disque" if refus else "", dt,
                " | ".join(x for x in txt.splitlines() if "REFUS" in x or "Error" in x or "Traceback" in x)[:400]))
            return
        for e, k in pq:
            controler_et_noter(ip, e, k)
        try:
            progression()
        except Exception:
            # la PROGRESSION n'est qu'un journal : son échec ne compte pas une tête en erreur (le code de sortie final
            # se juge sur les têtes réellement faites), mais il est écrit
            with verrou:
                bilan["incidents"] += 1
            log("place %d : PROGRESSION impossible (journal seulement) : %s" % (
                ip, " | ".join(traceback.format_exc().strip().splitlines()[-4:])))

    def ouvrier(ip):
        cache = os.path.join(os.path.dirname(a.sortie), "cache_p%d" % ip)
        while True:
            if os.path.exists(a.stop):
                with verrou:
                    if not bilan["stop"]:
                        log("STOP vu : aucun nouveau paquet ; les paquets en cours finissent")
                    bilan["stop"] = True
                return
            if bilan["disque"]:
                return
            try:
                pq = paquets.get_nowait()
            except queue.Empty:
                return
            try:
                traiter_paquet(ip, pq, cache)
            except Exception:
                # correction M-1 : une exception ne tue plus le fil ; le paquet compte en erreur, le fil continue
                noms = [nom(e, k) for e, k in pq]
                with verrou:
                    bilan["erreurs"].append((noms, "exception"))
                log("place %d : EXCEPTION pendant le paquet %s (compté en erreur ; le fil continue) : %s" % (
                    ip, ",".join(noms), " | ".join(traceback.format_exc().strip().splitlines()[-6:])))

    def ouvrier_sur(ip):
        try:
            ouvrier(ip)
        except BaseException:
            with verrou:
                bilan["erreurs"].append((["place %d" % ip], "fil arrêté"))
            try:
                log("place %d : FIL ARRÊTÉ par une exception : %s" % (
                    ip, " | ".join(traceback.format_exc().strip().splitlines()[-6:])))
            except Exception:
                traceback.print_exc()

    th = [threading.Thread(target=ouvrier_sur, args=(i + 1,)) for i in range(a.places)]
    for t in th:
        t.start()
        time.sleep(3)
    for t in th:
        t.join()
    reste = [c for c in tout if etat(a.sortie, *c) != "faite"]
    # têtes visées par CE lancement (après --max-tetes) et toujours pas faites : le code de sortie se juge sur elles
    manquent = [c for c in restants if etat(a.sortie, *c) != "faite"]
    log("FIN : %d / %d têtes faites et contrôlées en %.0f s ; reste %d ; de ce lancement, manquent %d sur %d ; "
        "erreurs %d ; incidents de journal %d ; trous HORS REGLE %d%s%s" % (
            len(tout) - len(reste), len(tout), time.time() - t0, len(reste), len(manquent), len(restants),
            len(bilan["erreurs"]), bilan["incidents"], len(bilan["hors_regle"]),
            (" (%s)" % ",".join(bilan["hors_regle"])) if bilan["hors_regle"] else "",
            " ; arrêt par STOP" if bilan["stop"] else ""))
    if bilan["disque"]:
        return 4
    if bilan["erreurs"]:
        return 1
    if manquent:
        if bilan["stop"]:
            return 2
        log("FIN EN ERREUR : %d tête(s) de ce lancement ni faites ni contrôlées sans erreur enregistrée (%s) : code 1"
            % (len(manquent), ",".join(nom(*c) for c in manquent[:12]) + (" …" if len(manquent) > 12 else "")))
        return 1
    if bilan["hors_regle"]:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
