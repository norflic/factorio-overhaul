r"""Rafales TIRÉES AU HASARD : marge de volume des tirs du mod sur la vanilla (lot S0-suite, mineur 1 de la vérification
de S0). Sans Blender : décodage par PyAV (FFmpeg) des fichiers du mod et des tirs vanilla.

    py -3.9 tools/sound/rafales.py [--mod RACINE] [--data <racine>\data] [--suites 100] [--marge 0.5]
                                   [--appliquer] [--page DOSSIER] [--sortie rapport.txt]

Pourquoi : S0 mesurait UNE rafale (24 tirs à 10/s, suite de variations fixe, graine 4242) ; la vérification en a mesuré une
autre (30 tirs, variations en boucle, 2,5 s de traîne) et trouvé l'ère IV à +0,01 dB de la vanilla (RMS sur 50 ms) :
« jamais au-dessus » dépendait de la longueur et de l'ordre de la rafale. En jeu, la variation est tirée au hasard.

Campagne : pour chaque longueur de rafale (LONGUEURS tirs à 10 tirs/s, cadence de la mitrailleuse vanilla) et chaque
suite de variations (--suites suites tirées au hasard, graines fixes, plus la suite en boucle 1, 2, 3, 4 de la
vérification), la MÊME suite est jouée par la vanilla et par chaque ère (volume du prototype : 0,4 × volume de l'ère),
puis mesurée : crête, RMS (toute la rafale), RMS max sur 50 ms et sur 400 ms, sonie K intégrée et momentanée max
(400 ms).
CONTRAT (« distribution ») : pour chaque longueur et chaque mesure, la médiane, le 90e et le 99e centile et le MAXIMUM
des rafales de l'ère tirées au hasard sont au moins `marge` dB (0,5 par défaut) sous les mêmes quantiles de la vanilla ;
et chaque tir seul est sous la vanilla (crête, RMS). En jeu, la vanilla et l'ère jouent des suites INDÉPENDANTES : c'est
la loi de leurs rafales qui se compare.
Mesure « appariée » (même suite jouée par les deux, rapportée, HORS contrat) : sur une fenêtre de 50 ms, la somme de
tirs qui se chevauchent dépend de la phase ; une suite donnée peut tomber sur une annulation dans la vanilla et pas dans
l'ère, d'où des écarts appariés de plus de 1 dB alors que la loi de l'ère reste sous celle de la vanilla (24/10 : voir
le rapport). L'exiger aussi coûterait 1,1 à 2,0 dB de volume selon l'ère.
Volume de l'ère proposé : volume actuel × 10^((−marge − pire)/20), arrondi vers le bas au millième, jamais au-dessus du
volume actuel (les mesures sont linéaires en gain : l'écart baisse exactement d'autant ; vérifié en rejouant la
campagne avec --appliquer).

--appliquer : écrit les volumes par ère dans sound/levels/gun/sons.lua (champ `volumes`, lu par
prototypes/levels/gun.lua) et la campagne dans MANIFEST.json (« rafales_hasard ») ; les fichiers OGG ne changent pas.
--page : refait la page d'écoute (index.html + 12 MP3 encodés par PyAV, libmp3lame) au volume EN JEU de chaque ère.
Code de sortie : 0 si le contrat tient (avec les volumes écrits dans sons.lua, ou appliqués), 1 sinon.
"""
import argparse
import json
import math
import os
import re
import sys

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
GAME = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
RATE = 44100
VOLUME = 0.4
CADENCE = 0.1
TRAINE = 2.5
LONGUEURS = (5, 10, 24, 30, 60)
MESURES = ("crete", "rms", "rms50", "rms400", "sonie_k", "momentanee")
NOMS_ERES = {1: "I Industrielle", 2: "II Lourde", 3: "III Exotique", 4: "IV Haute techno", 5: "V Stellaire, cosmique"}


def decode(path):
    """Fichier son -> tableau (n, 2) float64 à 44 100 Hz (PyAV)."""
    import av
    c = av.open(path)
    s = c.streams.audio[0]
    if s.rate != RATE:
        raise ValueError("%s : %d Hz" % (path, s.rate))
    parts = []
    for fr in c.decode(s):
        a = fr.to_ndarray()
        if a.dtype.kind == "i":
            a = a.astype(np.float64) / float(np.iinfo(a.dtype).max)
        a = a.astype(np.float64)
        if not fr.format.is_planar:
            a = a.reshape(-1, len(fr.layout.channels)).T
        parts.append(a)
    c.close()
    x = np.concatenate(parts, axis=1).T
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    return x


_K = None


def k_sos():
    """Filtre K (BS.1770) à 44,1 kHz, mêmes coefficients que sons.py (k_weight)."""
    global _K
    if _K is None:
        G, Q, fc = 3.99984385397, 0.7071752369554193, 1681.9744509555319
        A = 10 ** (G / 40.0)
        w0 = 2 * math.pi * fc / RATE
        al = math.sin(w0) / (2 * Q)
        cw, sa = math.cos(w0), 2 * math.sqrt(A) * al
        b1 = [A * ((A + 1) + (A - 1) * cw + sa), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sa)]
        a1 = [(A + 1) - (A - 1) * cw + sa, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sa]
        Q2, fc2 = 0.5003270373253953, 38.13547087613982
        w2 = 2 * math.pi * fc2 / RATE
        al2 = math.sin(w2) / (2 * Q2)
        b2 = [1.0, -2.0, 1.0]
        a2 = [1 + al2, -2 * math.cos(w2), 1 - al2]
        _K = np.vstack([signal.tf2sos(b1, a1), signal.tf2sos(b2, a2)])
    return _K


def db(v):
    return -200.0 if v <= 0 else 20 * math.log10(v)


def winmax(p, w):
    """Moyenne glissante maximale de p (puissance par échantillon) sur w échantillons."""
    if len(p) <= w:
        return float(p.mean())
    c = np.concatenate([[0.0], np.cumsum(p)])
    return float(((c[w:] - c[:-w]) / w).max())


def mesures(x):
    """Mesures d'un signal (n, 2) : dict en dB (crête, RMS, RMS max 50 ms et 400 ms, sonie K, momentanée max)."""
    p = (x ** 2).mean(axis=1)
    y = signal.sosfilt(k_sos(), x, axis=0)
    pk = (y ** 2).sum(axis=1)
    return {"crete": db(float(np.abs(x).max())), "rms": db(math.sqrt(float(p.mean()))),
            "rms50": db(math.sqrt(winmax(p, int(0.05 * RATE)))), "rms400": db(math.sqrt(winmax(p, int(0.4 * RATE)))),
            "sonie_k": -0.691 + 10 * math.log10(max(1e-20, float(pk.mean()))),
            "momentanee": -0.691 + 10 * math.log10(max(1e-20, winmax(pk, int(0.4 * RATE))))}


def rafale(singles, suite, vol):
    n = int(round((len(suite) * CADENCE + TRAINE) * RATE))
    out = np.zeros((n, 2))
    for k, v in enumerate(suite):
        s = singles[v]
        a = int(round(k * CADENCE * RATE))
        m = min(len(s), n - a)
        out[a:a + m] += s[:m] * vol
    return out


def suites(n_suites):
    """(longueur, nom, suite) : suites tirées au hasard (graines fixes) et la suite en boucle de la vérification."""
    out = []
    for L in LONGUEURS:
        out.append((L, "boucle", [k % 4 for k in range(L)]))
        for g in range(n_suites):
            rng = np.random.default_rng(100000 * L + g)
            out.append((L, "hasard-%d" % g, [int(v) for v in rng.integers(0, 4, L)]))
    return out


QUANTILES = (50, 90, 99, 100)


def campagne(van, eres, vols, n_suites):
    """Mesures de chaque rafale : {source: {longueur: tableau (suites, mesures)}} ; source « van » (volume 0,4) et
    chaque ère n (volume 0,4 × vols[n]). La suite d'indice 0 de chaque longueur est la boucle 1, 2, 3, 4."""
    res = {"van": {}}
    for n in eres:
        res[n] = {}
    for L in LONGUEURS:
        sts = [s for (LL, _, s) in suites(n_suites) if LL == L]
        def ligne(x):
            mm = mesures(x)
            return [mm[m] for m in MESURES]

        res["van"][L] = np.array([ligne(rafale(van, s, VOLUME)) for s in sts])
        for n, singles in eres.items():
            res[n][L] = np.array([ligne(rafale(singles, s, VOLUME * vols[n])) for s in sts])
    return res


def bilan(res, n, decal=0.0):
    """Écarts de l'ère n à la vanilla (en dB, avec un décalage de volume `decal` dB appliqué à l'ère) :
    - distribution : pour chaque longueur, mesure et quantile (médiane, 90e, 99e centile, maximum) des rafales TIRÉES AU
      HASARD, quantile de l'ère − même quantile de la vanilla ; rend (pire, où) ;
    - apparié : même suite jouée par les deux, pire écart sur toutes les suites (boucle comprise) ; rend (pire, où),
      et la part des suites où l'ère dépasse la vanilla sur au moins une mesure."""
    pd, wd = -99.0, None
    pp, wp = -99.0, None
    au_dessus = total = 0
    for L in LONGUEURS:
        v, e = res["van"][L], res[n][L] + decal
        for k, m in enumerate(MESURES):
            for q in QUANTILES:
                d = float(np.percentile(e[1:, k], q) - np.percentile(v[1:, k], q))
                if d > pd:
                    pd, wd = d, "%d tirs, %s, %s" % (L, m, "max" if q == 100 else "q%d" % q)
            d = e[:, k] - v[:, k]
            j = int(np.argmax(d))
            if d[j] > pp:
                pp, wp = float(d[j]), "%d tirs, %s, %s" % (L, m, "boucle" if j == 0 else "hasard-%d" % (j - 1))
        au_dessus += int(np.sum((e - v).max(axis=1) > 0))
        total += len(v)
    return (pd, wd), (pp, wp), au_dessus / float(total)


def lire_volumes(mod):
    """Volumes par ère écrits dans sons.lua (champ volumes = { [n] = v }), 1,0 sinon."""
    txt = open(os.path.join(mod, "sound", "levels", "gun", "sons.lua"), encoding="utf-8").read()
    vols = {n: 1.0 for n in range(1, 6)}
    m = re.search(r"volumes\s*=\s*\{([^}]*)\}", txt)
    if m:
        for k, v in re.findall(r"\[(\d)\]\s*=\s*([\d.]+)", m.group(1)):
            vols[int(k)] = float(v) / VOLUME
    return vols, bool(m)


def ecrire_volumes(mod, vols):
    """Ajoute (ou remplace) le champ `volumes` (volume du prototype par ère) dans sons.lua."""
    p = os.path.join(mod, "sound", "levels", "gun", "sons.lua")
    txt = open(p, encoding="utf-8").read()
    txt = re.sub(r"  -- Volume du prototype PAR ÈRE.*?\n  volumes = \{[^}]*\},\n", "", txt, flags=re.S)
    bloc = ("  -- Volume du prototype PAR ÈRE (lot S0-suite, tools/sound/rafales.py) : 0,4 × marge des rafales tirées au\n"
            "  -- hasard (pire écart à la vanilla <= -0,5 dB) ; les fichiers OGG ne changent pas.\n"
            "  volumes = { " + ", ".join("[%d] = %s" % (n, repr(round(VOLUME * vols[n], 4))) for n in sorted(vols))
            + " },\n")
    txt = txt.replace("  volume = 0.4,\n", "  volume = 0.4,\n" + bloc, 1)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(txt)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--mod", default=REPO)
    ap.add_argument("--data", default=os.path.join(GAME, "data"))
    ap.add_argument("--suites", type=int, default=100)
    ap.add_argument("--marge", type=float, default=0.5)
    ap.add_argument("--appliquer", action="store_true")
    ap.add_argument("--page", default=None)
    ap.add_argument("--sortie", default=None)
    a = ap.parse_args()
    lines = []

    def out(s):
        print(s, flush=True)
        lines.append(s)

    van = [decode(os.path.join(a.data, "base", "sound", "fight", "gun-turret-gunshot-0%d.ogg" % i)) for i in range(1, 5)]
    eres = {n: [decode(os.path.join(a.mod, "sound", "levels", "gun", "tir-ere%d-%d.ogg" % (n, i))) for i in range(1, 5)]
            for n in range(1, 6)}
    vols, ecrits = lire_volumes(a.mod)
    out("[FO-RAFALES] volumes par ere lus dans sons.lua : %s (%s)" % (
        ", ".join("%d : %.3f" % (n, vols[n]) for n in sorted(vols)), "champ volumes" if ecrits else "aucun : 1,0"))
    out("[FO-RAFALES] campagne : longueurs %s tirs a 10/s + %.1f s de traine ; %d suites au hasard par longueur + la "
        "suite en boucle ; %d rafales par source" % (",".join(str(L) for L in LONGUEURS), TRAINE, a.suites,
                                                    len(LONGUEURS) * (a.suites + 1)))
    r = campagne(van, eres, vols, a.suites)
    besoin = {}
    for n in sorted(eres):
        (pd, wd), (pp, wp), part = bilan(r, n)
        besoin[n] = pd
        out("[FO-RAFALES] ere %d (volume %.3f) : DISTRIBUTION pire ecart %+.3f dB (%s) ; APPARIE (meme suite) pire "
            "ecart %+.3f dB (%s), suites ou l'ere depasse sur au moins une mesure : %.1f %%" % (
                n, vols[n], pd, wd, pp, wp, 100 * part))
    # tirs seuls (au volume de l'ère)
    def seul(x, n_ref):
        e = float((x ** 2).mean(axis=1).sum()) / n_ref  # énergie rapportée à la durée vanilla (comme sons.py)
        return db(float(np.abs(x).max())), db(math.sqrt(e))

    seuls = []
    for n in sorted(eres):
        d = -99.0
        for i in range(4):
            ce, re_ = seul(eres[n][i] * vols[n], len(van[i]))
            cv, rv = seul(van[i], len(van[i]))
            d = max(d, ce - cv, re_ - rv)
        seuls.append(d)
    out("[FO-RAFALES] tirs seuls (crete, RMS rapportee a la duree vanilla) : pire ecart %s" % ", ".join(
        "ere %d %+.2f dB" % (n, d) for n, d in zip(sorted(eres), seuls)))
    tient = all(besoin[n] <= -a.marge + 1e-9 for n in besoin) and all(d <= 0 for d in seuls)
    out("[FO-RAFALES] contrat (distribution des rafales au hasard : chaque quantile de l'ere <= celui de la vanilla "
        "- %.2f dB ; tirs seuls <= 0) avec ces volumes : %s" % (a.marge, "TENU" if tient else "NON TENU"))
    prop = {n: min(vols[n], math.floor(vols[n] * 10 ** ((-a.marge - besoin[n]) / 20.0) * 1000) / 1000.0) for n in besoin}
    out("[FO-RAFALES] volumes d'ere proposes (marge %.2f dB ; jamais au-dessus du volume actuel) : %s" % (a.marge, ", ".join(
        "%d : %.3f (%+.2f dB)" % (n, prop[n], 20 * math.log10(prop[n] / vols[n])) for n in sorted(prop))))
    for n in sorted(eres):
        dec = 20 * math.log10(prop[n] / vols[n])
        (pd, wd), (pp, wp), part = bilan(r, n, dec)
        out("[FO-RAFALES]   avec ce volume (calcul : mesures lineaires en gain) : ere %d distribution %+.3f dB, apparie "
            "%+.3f dB (%s), suites ou l'ere depasse : %.1f %%" % (n, pd, pp, wp, 100 * part))
    code = 0 if tient else 1
    if a.appliquer:
        ecrire_volumes(a.mod, prop)
        vols2, _ = lire_volumes(a.mod)
        r2 = campagne(van, eres, vols2, a.suites)
        b2 = {n: bilan(r2, n) for n in eres}
        tient2 = all(b2[n][0][0] <= -a.marge + 1e-9 for n in b2)
        out("[FO-RAFALES] APPLIQUE : sons.lua volumes %s ; campagne REJOUEE a ces volumes : distribution %s : %s" % (
            ", ".join("%d : %.4f" % (n, VOLUME * vols2[n]) for n in sorted(vols2)),
            ", ".join("ere %d %+.3f dB" % (n, b2[n][0][0]) for n in sorted(b2)), "TENU" if tient2 else "NON TENU"))
        man = os.path.join(a.mod, "sound", "levels", "gun", "MANIFEST.json")
        m = json.load(open(man, encoding="utf-8"))
        m["rafales_hasard"] = {
            "outil": "tools/sound/rafales.py (lot S0-suite)", "marge_db": a.marge, "longueurs_tirs": list(LONGUEURS),
            "suites_au_hasard_par_longueur": a.suites, "traine_s": TRAINE, "quantiles": list(QUANTILES),
            "mesures": list(MESURES),
            "volume_prototype_par_ere": {str(n): round(VOLUME * vols2[n], 4) for n in sorted(vols2)},
            "distribution_pire_ecart_db_avant": {str(n): round(besoin[n], 3) for n in sorted(besoin)},
            "distribution_pire_ecart_db": {str(n): [round(b2[n][0][0], 3), b2[n][0][1]] for n in sorted(b2)},
            "apparie_pire_ecart_db": {str(n): [round(b2[n][1][0], 3), b2[n][1][1]] for n in sorted(b2)},
            "apparie_part_suites_au_dessus": {str(n): round(b2[n][2], 4) for n in sorted(b2)}}
        with open(man, "w", encoding="utf-8", newline="\n") as f:
            json.dump(m, f, indent=1, ensure_ascii=False, sort_keys=True)
            f.write("\n")
        vols = vols2
        code = 0 if tient2 else 1
    if a.page:
        page(a.page, van, eres, vols, a.mod, out)
    if a.sortie:
        with open(a.sortie, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
    return code


# --------------------------------------------------------------------------------------------- page d'écoute

def mp3(path, x):
    """Écrit x (n, 2) en MP3 160 kb/s par PyAV (libmp3lame)."""
    import av
    o = av.open(path, "w", format="mp3")
    st = o.add_stream("libmp3lame", rate=RATE)
    st.layout = "stereo"
    st.bit_rate = 160000
    y = np.clip(x, -1, 1).astype(np.float32).T.copy()
    fs = st.codec_context.frame_size or 1152
    for i in range(0, y.shape[1], fs):
        fr = __import__("av").AudioFrame.from_ndarray(np.ascontiguousarray(y[:, i:i + fs]), format="fltp", layout="stereo")
        fr.sample_rate = RATE
        fr.pts = i
        for pk in st.encode(fr):
            o.mux(pk)
    for pk in st.encode(None):
        o.mux(pk)
    o.close()


def page(dossier, van, eres, vols, mod, out):
    """Page d'écoute : vanilla puis 5 ères, un tir (variation 1) et une rafale (24 tirs, suite fixe, comme S0), au
    volume EN JEU (0,4 × volume de l'ère). Texte et mesures repris de sons.py et du manifeste."""
    sys.path.insert(0, HERE)
    import sons
    os.makedirs(dossier, exist_ok=True)
    man = json.load(open(os.path.join(mod, "sound", "levels", "gun", "MANIFEST.json"), encoding="utf-8"))
    rng = np.random.default_rng(4242)
    suite = [int(rng.integers(0, 4)) for _ in range(24)]  # même tirage que sons.burst (graine 4242, 24 tirs)
    ref_t = mesures(van[0] * VOLUME)
    ref_r = mesures(rafale(van, suite, VOLUME))
    secs = [sons.page_section("Vanilla (référence)", "la mitrailleuse du jeu de base", "Le son d'origine, pour comparer.",
                              "vanilla-tir.mp3", "vanilla-rafale.mp3",
                              sons.fr("tir : crête %.1f dBFS ; rafale : RMS %.1f dBFS ; timbre : centroïde %.0f Hz" % (
                                  ref_t["crete"] - db(VOLUME), ref_r["rms"],
                                  man["timbre_moyen"]["vanilla"]["centroide_hz"])))]
    mp3(os.path.join(dossier, "vanilla-tir.mp3"), van[0] * VOLUME)
    mp3(os.path.join(dossier, "vanilla-rafale.mp3"), rafale(van, suite, VOLUME))
    for n in sorted(eres):
        e = sons.ERES[n - 1]
        t = eres[n][0] * VOLUME * vols[n]
        b = rafale(eres[n], suite, VOLUME * vols[n])
        mt, mb = mesures(t), mesures(b)
        mp3(os.path.join(dossier, "ere%d-tir.mp3" % n), t)
        mp3(os.path.join(dossier, "ere%d-rafale.mp3" % n), b)
        secs.append(sons.page_section(
            "Ère " + e["nom"], "âges %d à %d" % (e["ages"][0], e["ages"][-1]), e["texte"],
            "ere%d-tir.mp3" % n, "ere%d-rafale.mp3" % n,
            sons.fr("tir : %+.1f dB de crête, %+.1f dB d'énergie face à la vanilla ; rafale : %+.1f dB d'énergie ; "
                    "volume en jeu %.3f (vanilla 0.4) ; timbre : centroïde %.0f Hz" % (
                        mt["crete"] - ref_t["crete"], mt["rms"] - ref_t["rms"], mb["rms"] - ref_r["rms"],
                        VOLUME * vols[n], man["timbre_moyen"]["ère %d" % n]["centroide_hz"]))))
    import datetime
    html = sons.PAGE_HTML.format(sections="\n".join(secs), date=datetime.date.today().strftime("%d/%m/%Y"))
    html = html.replace("Lot S0, ", "Lot S0 (volumes revus au lot S0-suite : marge de 0,5 dB sur les rafales tirées au "
                        "hasard), ")
    with open(os.path.join(dossier, "index.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    out("[FO-RAFALES] page d'ecoute : %s (12 MP3, PyAV libmp3lame 160 kb/s)" % os.path.join(dossier, "index.html"))


if __name__ == "__main__":
    sys.exit(main())
