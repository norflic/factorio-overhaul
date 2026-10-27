r"""Sonie du tir par âge (lot TIRS, 27/10) : le son S0 de l'ère PLUS les couches ajoutées par shared/tirs/ages.lua,
mixées hors jeu comme le moteur les joue (une variation par couche, volume du prototype, vitesse de lecture), comparées
au tir vanilla (gun-turret-gunshot-01 à 04, volume 0,4). AUCUN son n'est joué : décodage (PyAV) et calcul seulement.

    py -3.9 -B tools/sound/tirs_sonie.py [--mod RACINE] [--json SORTIE] [--cible]

Mesures (mêmes définitions que tools/sound/rafales.py : sonie K BS.1770 sans porte, momentanée max sur 400 ms, crête) :
  - tir isolé : moyenne sur les 4 variations S0 (la couche k prend la variation i mod n_k ; vitesse au milieu de
    [min_speed, max_speed]) ;
  - rafale de 2,4 s à 10 tirs/s (cadence de base) : une couche à `aggregation` max_count M ne démarre un son que s'il
    en joue moins de M (count_already_playing, remove : HYPOTHÈSE de lecture de la doc, à prouver en jeu, PLAN.md §6).
Contrat proposé (PLAN.md §4, ronde 4 du correcteur, à faire trancher par le DC) : il porte sur la RAFALE, ce que le
joueur entend d'une tourelle (le contrat de la ronde 3, +0,25 dB par âge sur le tir isolé, laissait les 4 âges SOUS la
vanilla en rafale) :
  - rafale : ère I = S0 tel quel ; à partir de l'âge 4 (ère II), Δrafale(âge) = 1 + (âge − 4) / 3 dB au-dessus de la
    rafale vanilla (âge 5 : +1,33 ; 8 : +2,33 ; 10 : +3,0 ; 15 : +4,67 ; 1 dB d'une ère à la suivante), à ± 0,4 dB ;
  - tir isolé : croissant d'un âge témoin au suivant ;
  - crête : tir isolé ≤ −1 dBFS (comme S0) ; rafale ≤ crête de la rafale vanilla + Δ visé + 1 dB (pas plus « pointue »
    que la vanilla). Une crête de rafale ≤ −1 dBFS (demande du critique) est INCOMPATIBLE avec +4 à +6 dB : la rafale
    vanilla elle-même a sa crête à −3,0 dBFS au volume du prototype ; à faire trancher.
Le chiffre de la rafale repose sur une HYPOTHÈSE de lecture d'`aggregation` (F360, ouvert) : à confirmer en session
disk (tools/sound/tirs_couches.py). --cible : rend aussi le facteur de volume des couches ajoutées qui atteint la
rafale visée. Code 0 si le contrat est tenu, 1 sinon.
"""
import argparse
import json
import math
import os
import subprocess
import sys
from fractions import Fraction

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import rafales  # noqa: E402  (mêmes mesures que S0-suite)

GAME = os.path.normpath(os.path.join(REPO, "..", ".."))
if not os.path.isdir(os.path.join(GAME, "data", "base")):
    GAME = r"F:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
LUA = r"C:\Users\evan2\bin\lua5.2.exe"
RATE = 44100
VANILLA = ["__base__/sound/fight/gun-turret-gunshot-0%d.ogg" % i for i in (1, 2, 3, 4)]
VOL_VANILLA = 0.4

DUMP = r"""
package.path = "./?.lua;" .. package.path
local T = require("shared.tirs.ages")
local S = require("sound.levels.gun.sons")
local function q(s) return '"' .. s .. '"' end
local out = {}
for _, e in ipairs(T.temoins) do
  local ere = math.floor((e - 1) / 3) + 1
  local s0 = {}
  for _, f in ipairs(S.eres[ere]) do s0[#s0 + 1] = q(f) end
  local cs = {}
  for _, c in ipairs((T.ages[e].son and T.ages[e].son.couches) or {}) do
    local fs = {}
    for i = c.fichiers[2], c.fichiers[3] do fs[#fs + 1] = q(string.format(c.fichiers[1], i)) end
    local v = c.vitesse or { 1, 1 }
    cs[#cs + 1] = string.format('{"fichiers":[%s],"volume":%s,"vmin":%s,"vmax":%s,"max":%d}', table.concat(fs, ","),
      c.volume, v[1], v[2], c.max)
  end
  out[#out + 1] = string.format('{"age":%d,"ere":%d,"vol_s0":%s,"s0":[%s],"couches":[%s]}', e, ere,
    (S.volumes and S.volumes[ere]) or S.volume, table.concat(s0, ","), table.concat(cs, ","))
end
print("[" .. table.concat(out, ",") .. "]")
"""


def lire_ages(mod):
    r = subprocess.run([LUA, "-e", DUMP], cwd=mod, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("lua : " + r.stderr)
    return json.loads(r.stdout)


def chemin(mod, f):
    if f.startswith("__base__/"):
        return os.path.join(GAME, "data", "base", *f[len("__base__/"):].split("/"))
    if f.startswith("__factorio-overhaul__/"):
        return os.path.join(mod, *f[len("__factorio-overhaul__/"):].split("/"))
    raise ValueError(f)


_CACHE = {}


def decode(path):
    """Fichier -> (n, 2) float64 à 44 100 Hz (PyAV ; rééchantillonné si besoin)."""
    if path in _CACHE:
        return _CACHE[path]
    import av
    c = av.open(path)
    s = c.streams.audio[0]
    rate = s.rate
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
    if rate != RATE:
        fr_ = Fraction(RATE, rate).limit_denominator(1000)
        x = signal.resample_poly(x, fr_.numerator, fr_.denominator, axis=0)
    _CACHE[path] = x
    return x


def vitesse(x, v):
    """Lecture à la vitesse v (hauteur et durée), comme le moteur : rééchantillonnage."""
    if abs(v - 1) < 1e-9:
        return x
    fr_ = Fraction(1 / v).limit_denominator(200)
    return signal.resample_poly(x, fr_.numerator, fr_.denominator, axis=0)


def ajoute(out, x, a):
    m = min(len(x), len(out) - a)
    if m > 0:
        out[a:a + m] += x[:m]


def tir(age, mod, i, g=1.0):
    """Tir isolé de la variation S0 i : S0 + couches (gain g sur les couches ajoutées)."""
    parts = [decode(chemin(mod, age["s0"][i % len(age["s0"])])) * age["vol_s0"]]
    for c in age["couches"]:
        f = c["fichiers"][i % len(c["fichiers"])]
        x = vitesse(decode(chemin(mod, f)), 0.5 * (c["vmin"] + c["vmax"]))
        parts.append(x * c["volume"] * g)
    n = max(len(p) for p in parts)
    out = np.zeros((n, 2))
    for p in parts:
        ajoute(out, p, 0)
    return out


def tir_vanilla(i):
    return decode(chemin("", VANILLA[i % 4])) * VOL_VANILLA


def rafale(age, mod, g=1.0, n_tirs=24, cadence=0.1):
    """Rafale : S0 à chaque tir, couche k démarrée si moins de max_count de ses sons jouent (hypothèse)."""
    long = int((n_tirs * cadence + 4.0) * RATE)
    out = np.zeros((long, 2))
    en_cours = [[] for _ in (age or {}).get("couches", [])]
    for k in range(n_tirs):
        a = int(round(k * cadence * RATE))
        if age is None:
            ajoute(out, tir_vanilla(k), a)
            continue
        ajoute(out, decode(chemin(mod, age["s0"][k % len(age["s0"])])) * age["vol_s0"], a)
        for j, c in enumerate(age["couches"]):
            en_cours[j] = [fin for fin in en_cours[j] if fin > a]
            if len(en_cours[j]) >= c["max"]:
                continue
            f = c["fichiers"][k % len(c["fichiers"])]
            x = vitesse(decode(chemin(mod, f)), 0.5 * (c["vmin"] + c["vmax"])) * c["volume"] * g
            ajoute(out, x, a)
            en_cours[j].append(a + len(x))
    return out


def mesure_tir(age, mod, g=1.0):
    ms = [rafales.mesures(tir(age, mod, i, g)) for i in range(4)]
    return {k: float(np.mean([m[k] for m in ms])) for k in ms[0]}, max(m["crete"] for m in ms)


def mp3(path, x):
    """Écrit un MP3 stéréo 44,1 kHz (PyAV, libmp3lame) pour la page d'écoute du DC : aucun son joué sur le PC."""
    import av
    y = np.clip(x, -1.0, 1.0).astype(np.float32)
    c = av.open(path, "w")
    s = c.add_stream("libmp3lame", rate=RATE, layout="stereo")
    s.bit_rate = 160000
    fs = s.codec_context.frame_size or 1152
    for a in range(0, len(y), fs):
        fr = av.AudioFrame.from_ndarray(np.ascontiguousarray(y[a:a + fs].T), format="fltp", layout="stereo")
        fr.sample_rate = RATE
        for pk in s.encode(fr):
            c.mux(pk)
    for pk in s.encode(None):
        c.mux(pk)
    c.close()


def ecoute(dossier, ages, mod):
    os.makedirs(dossier, exist_ok=True)
    silence = np.zeros((int(0.3 * RATE), 2))
    mp3(os.path.join(dossier, "vanilla-tir.mp3"), np.concatenate([silence, tir_vanilla(0), silence]))
    mp3(os.path.join(dossier, "vanilla-rafale.mp3"), rafale(None, mod))
    for age in ages:
        mp3(os.path.join(dossier, "age%02d-tir.mp3" % age["age"]), np.concatenate([silence, tir(age, mod, 0), silence]))
        mp3(os.path.join(dossier, "age%02d-rafale.mp3" % age["age"]), rafale(age, mod))
    print("page d'ecoute : %d MP3 dans %s" % (2 + 2 * len(ages), dossier))


def vise_rafale(age):
    """Δ visé de la rafale (dB au-dessus de la rafale vanilla) ; None pour l'ère I (S0 tel quel)."""
    if age < 4:
        return None
    return 1.0 + (age - 4) / 3.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ecoute", help="dossier des MP3 (tir isolé et rafale de 2,4 s par âge et vanilla)")
    ap.add_argument("--mod", default=REPO)
    ap.add_argument("--json")
    ap.add_argument("--cible", action="store_true")
    ap.add_argument("--tol", type=float, default=0.4, help="tolérance sur la rafale visée (dB)")
    a = ap.parse_args()
    ages = lire_ages(a.mod)
    van = [rafales.mesures(tir_vanilla(i)) for i in range(4)]
    ref = {k: float(np.mean([m[k] for m in van])) for k in van[0]}
    raf_ref = rafales.mesures(rafale(None, a.mod))
    print("vanilla : tir isole momentanee %.2f LUFS, sonie K %.2f, crete %.2f dBFS ; rafale momentanee %.2f" % (
        ref["momentanee"], ref["sonie_k"], ref["crete"], raf_ref["momentanee"]))
    res, ok, prec = [], True, None
    for age in ages:
        m, crete = mesure_tir(age, a.mod)
        r = rafales.mesures(rafale(age, a.mod))
        d = m["momentanee"] - ref["momentanee"]
        dr = r["momentanee"] - raf_ref["momentanee"]
        vise = vise_rafale(age["age"])
        motifs = []
        if vise is None:
            if age["couches"]:
                motifs.append("ere I : S0 seul attendu")
        elif abs(dr - vise) > a.tol:
            motifs.append("rafale %+.2f hors de %+.2f +/- %.1f" % (dr, vise, a.tol))
        lim = raf_ref["crete"] + (vise or 0.0) + 1.0
        if crete > -1.0:
            motifs.append("crete du tir isole > -1 dBFS")
        if r["crete"] > lim:
            motifs.append("crete de la rafale %.2f > %.2f dBFS" % (r["crete"], lim))
        if prec is not None and d <= prec:
            motifs.append("tir isole pas plus fort que l'age precedent")
        prec = d
        tenu = not motifs
        ok = ok and tenu
        ligne = {"age": age["age"], "couches": len(age["couches"]), "delta_tir": round(d, 2), "delta_rafale": round(dr, 2),
                 "vise_rafale": vise, "delta_sonie_k": round(m["sonie_k"] - ref["sonie_k"], 2), "crete": round(crete, 2),
                 "crete_rafale": round(r["crete"], 2), "tenu": tenu, "motifs": motifs}
        if a.cible and age["couches"] and vise is not None:
            lo, hi = 0.0, 6.0
            for _ in range(24):
                g = 0.5 * (lo + hi)
                if rafales.mesures(rafale(age, a.mod, g))["momentanee"] - raf_ref["momentanee"] < vise:
                    lo = g
                else:
                    hi = g
            ligne["facteur_cible"] = round(0.5 * (lo + hi), 3)
        res.append(ligne)
        print("age %2d : %d couche(s) ajoutee(s) ; rafale %+.2f dB (vise %s), tir isole %+.2f, sonie K %+.2f, crete %.2f / "
              "rafale %.2f dBFS%s ; %s" % (
                  age["age"], len(age["couches"]), dr, "S0" if vise is None else "%+.2f" % vise, d,
                  ligne["delta_sonie_k"], crete, r["crete"],
                  (" ; facteur des couches pour la cible %.3f" % ligne["facteur_cible"]) if "facteur_cible" in ligne else "",
                  "TENU" if tenu else "NON TENU (" + "; ".join(motifs) + ")"))
    if a.ecoute:
        ecoute(a.ecoute, ages, a.mod)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"vanilla": ref, "rafale_vanilla": raf_ref, "ages": res,
                       "hypothese": "aggregation : une couche ne demarre un son que si moins de max_count jouent (F360)"},
                      f, indent=1)
    print("BILAN : %s" % ("contrat tenu" if ok else "contrat NON tenu"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
