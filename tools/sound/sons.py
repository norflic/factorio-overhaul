r"""Chaîne des sons du lot S0 : le TIR de la mitrailleuse par ÈRE, dérivé des sons vanilla.

    py -3.9 tools/sound/sons.py [--work DOSSIER] [--page DOSSIER] [--mod RACINE] [--blender EXE] [--check]

Déroulé (déterministe : aucune source aléatoire hors du générateur à graine fixe, aucun temps mesuré) :
  1. Blender (module `aud`, FFmpeg embarqué ; TOUJOURS par tools/render/with_render_lock.py, CLAUDE.md §4) décode
     les sons vanilla utilisés (<racine>\data\base\sound\, lecture seule) en WAV dans <work>\vanilla\ ;
  2. numpy et scipy fabriquent, pour chacune des 5 ères et chacune des 4 variations du tir vanilla
     (gun-turret-gunshot-01 à 04), un WAV : hauteur (rééchantillonnage), grain (saturation), filtres, couches
     (autres sons vanilla, coup sourd synthétique, balayage), durée bornée à celle de la variation vanilla ;
  3. Blender encode chaque WAV en OGG Vorbis (le format des sons vanilla ; le moteur 1.1.91 lit .ogg, .wav et .voc,
     doc prototype-api.json, Sound.filename) puis DÉCODE cet OGG : les mesures portent sur ce que le jeu jouera ;
  4. contrôle du volume, variation par variation, contre la variation vanilla de même rang, sur le décodé :
     crête, RMS (énergie rapportée à la durée vanilla), sonie pondérée K (BS.1770, sans porte, même fenêtre) et
     sonie momentanée maximale (400 ms) ; plus une rafale de 10 tirs/s pendant 2,4 s (cadence de la mitrailleuse
     vanilla : cooldown 6 ticks). Toute mesure au-dessus de la vanilla : gain de l'ère réduit, on recommence ;
  5. écrit dans le mod sound/levels/gun/tir-ere<N>-<i>.ogg, sons.lua (généré, lu par prototypes/levels/gun.lua) et
     MANIFEST.json (sha256, octets, mesures) ;
  6. --page : page d'écoute pour le Directeur Créatif (index.html, MP3 lus par tous les téléphones) : vanilla
     d'abord, puis les 5 ères, un tir seul et une rafale chacun.
--check : ne fabrique rien ; relit le manifeste et contrôle les fichiers du mod (sha256, octets, en-tête OggS).

Volume du prototype : 0,4 pour chaque variation, comme la vanilla (sounds.gun_turret_gunshot) : le rapport des
fichiers EST le rapport en jeu.
"""
import argparse
import hashlib
import json
import math
import os
import subprocess
import sys
import wave
from fractions import Fraction

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
GAME = r"H:\Factorio.v1.1.91 Modding\Factorio.v1.1.91"
VANILLA_SOUND = os.path.join(GAME, "data", "base", "sound")
BLENDER = r"C:\Users\evan2\tools\blender-5.2.2\blender.exe"
DEFAULT_WORK = os.path.join(GAME, "fo-logs", "2026-10-24_S0", "travail")
MOD_DIR = ("sound", "levels", "gun")
MOD_PREFIX = "__factorio-overhaul__/sound/levels/gun/"
RATE = 44100
VOLUME = 0.4            # volume du prototype, celui de la vanilla (sounds.gun_turret_gunshot)
CADENCE = 0.1           # s entre deux tirs (gun-turret : cooldown 6 ticks)
RAFALE_S = 2.4
OGG_BITRATE = 112000
MP3_BITRATE = 160000
MARGE = 10 ** (-0.3 / 20)  # 0,3 dB sous la limite au premier passage (le codec Vorbis déplace un peu la crête)

TIR = ["fight/gun-turret-gunshot-0%d.ogg" % i for i in (1, 2, 3, 4)]

# Ères (DESIGN_EPOQUES §1.2 ; ère V « cosmique » : 13 Antimatière, 14 La Porte, 15 Néant). Paramètres de
# fabrication, tous déterministes. pitch : rapport de hauteur (< 1 : plus grave et plus long) ; drive : saturation
# (grain) ; lp/hp : filtres (Hz) ; couches : autres sons vanilla (fichier par variation, gain en dB, hauteur,
# passe-bas, durée gardée) ; sub : coup sourd synthétique (f0 -> f1 Hz, durée s, gain dB) ; sweep : balayage
# descendant (f0 -> f1, durée, gain dB) ; vide : souffle inversé (« aspiration du néant ») ; ring : modulation en
# anneau (Hz, mélange) ; comb : résonance en peigne (Hz, retour, mélange).
ERES = [
    {"n": 1, "nom": "I Industrielle", "ages": (1, 2, 3), "pitch": 0.92, "drive": 1.25, "lp": 8000, "hp": 30,
     "sub": (105, 75, 0.06, -13.0),
     "texte": "Le tir vanilla un peu plus bas (1,4 demi-ton), sec et granuleux : fer et poudre."},
    {"n": 2, "nom": "II Lourde", "ages": (4, 5, 6), "pitch": 0.84, "drive": 1.9, "lp": 8500, "hp": 45,
     "couches": [("fight/heavy-gunshot-%d.ogg", (1, 2, 3, 4), -5.0, 0.80, 5000, 0.6)],
     "sub": (95, 60, 0.09, -9.0),
     "texte": "Plus grave, la détonation lourde de la vanilla en dessous, un coup sourd court."},
    {"n": 3, "nom": "III Exotique", "ages": (7, 8, 9), "pitch": 0.75, "drive": 2.2, "lp": 7500, "hp": 40,
     "couches": [("fight/tank-cannon-%d.ogg", (1, 2, 3, 4), -8.0, 0.85, 1400, 0.35)],
     "sub": (80, 50, 0.12, -7.0), "comb": (1180.0, 0.55, 0.22),
     "texte": "Encore plus grave, le corps du canon de char, et une résonance cristalline."},
    {"n": 4, "nom": "IV Haute techno", "ages": (10, 11, 12), "pitch": 0.66, "drive": 2.4, "lp": 9500, "hp": 35,
     "couches": [("fight/heavy-gunshot-%d.ogg", (1, 2, 3, 4), -6.0, 0.62, 4000, 0.5),
                 ("fight/laser-%d.ogg", (1, 2, 3, 1), -11.0, 0.70, 9000, 0.30)],
     "sub": (70, 42, 0.15, -5.0),
     "texte": "Lourd et net, avec une décharge électrique (laser vanilla) et un coup de basse."},
    {"n": 5, "nom": "V Stellaire, cosmique", "ages": (13, 14, 15), "pitch": 0.56, "drive": 2.8, "lp": 8000,
     "hp": 30,
     "couches": [("fight/nuclear-explosion-%d.ogg", (1, 2, 3, 1), -4.0, 0.62, 700, 0.55),
                 ("fight/tank-cannon-%d.ogg", (4, 3, 2, 1), -7.0, 0.62, 1200, 0.40)],
     "sub": (62, 32, 0.22, -3.0), "sweep": (420.0, 38.0, 0.30, -10.0), "vide": (0.22, -14.0),
     "ring": (37.0, 0.18),
     "texte": "Âges 13 Antimatière, 14 La Porte, 15 Néant. Le plus grave : un mini big bang (explosion nucléaire vanilla très ralentie), un balayage qui "
              "tombe et un souffle aspiré, la maîtrise du néant."},
]


def age_to_era(age):
    return (age - 1) // 3 + 1


# --------------------------------------------------------------------------------------------- E/S WAV

def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw != 2:
        raise ValueError("%s : %d octets par échantillon (16 bits attendus)" % (path, sw))
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    x = x.reshape(-1, ch)
    if ch == 1:
        x = np.repeat(x, 2, axis=1)
    if rate != RATE:
        raise ValueError("%s : %d Hz (44 100 attendus)" % (path, rate))
    return x


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    y = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(y.tobytes())


# --------------------------------------------------------------------------------------------- Blender

def blender(jobs, work, tag, exe):
    """Travaux audio par Blender (blender_audio.py), À TRAVERS le verrou de rendu. Rend le rapport."""
    jf = os.path.join(work, "blender-%s.json" % tag)
    rep = os.path.join(work, "blender-%s-rapport.json" % tag)
    with open(jf, "w", encoding="utf-8") as f:
        json.dump({"jobs": jobs, "report": rep}, f, indent=1)
    if os.path.exists(rep):
        os.remove(rep)
    cmd = [sys.executable, os.path.join(REPO, "tools", "render", "with_render_lock.py"), "--",
           exe, "-b", "--factory-startup", "--python-exit-code", "1",
           "--python", os.path.join(HERE, "blender_audio.py"), "--", jf]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    with open(os.path.join(work, "blender-%s.log" % tag), "w", encoding="utf-8") as f:
        f.write(r.stdout + "\n" + r.stderr)
    if r.returncode != 0 or not os.path.exists(rep):
        raise RuntimeError("Blender (%s) en échec, code %d : voir %s" % (tag, r.returncode,
                                                                          os.path.join(work, "blender-%s.log" % tag)))
    with open(rep, encoding="utf-8") as f:
        return json.load(f)


# --------------------------------------------------------------------------------------------- traitement

def resample(x, pitch):
    """Hauteur × pitch (et durée ÷ pitch) : rééchantillonnage polyphasé, lu ensuite à 44 100 Hz."""
    if abs(pitch - 1.0) < 1e-9:
        return x.copy()
    fr = Fraction(1.0 / pitch).limit_denominator(64)
    return signal.resample_poly(x, fr.numerator, fr.denominator, axis=0)


def sos_filter(x, kind, freq, order=2):
    sos = signal.butter(order, freq, btype=kind, fs=RATE, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def saturate(x, drive):
    if drive <= 1.0:
        return x
    return np.tanh(drive * x) / np.tanh(drive)


def db(g):
    return 10 ** (g / 20.0)


def fit(x, n):
    """Longueur n exactement (coupe ou complète de silence)."""
    if len(x) >= n:
        return x[:n].copy()
    return np.vstack([x, np.zeros((n - len(x), x.shape[1]))])


def fade_out(x, seconds):
    k = min(len(x), int(seconds * RATE))
    if k > 1:
        x[-k:] *= (0.5 * (1 + np.cos(np.linspace(0, math.pi, k))))[:, None]
    return x


def stereo(mono, width=0.0):
    return np.column_stack([mono * (1 - width), mono * (1 + width)])


def sub_thump(f0, f1, dur, n):
    t = np.arange(n) / RATE
    f = f1 + (f0 - f1) * np.exp(-t / (dur / 3.0))
    ph = 2 * math.pi * np.cumsum(f) / RATE
    env = np.exp(-t / dur) * (1 - np.exp(-t / 0.002))
    # saturation : harmoniques (2f, 3f) audibles même sur un petit haut-parleur (téléphone)
    return stereo(saturate(np.sin(ph) * env, 2.5))


def sweep(f0, f1, dur, n):
    t = np.arange(n) / RATE
    tt = np.minimum(t, dur)
    f = f0 * (f1 / f0) ** (tt / dur)
    ph = 2 * math.pi * np.cumsum(f) / RATE
    env = np.where(t < dur, np.sin(math.pi * np.minimum(t / dur, 1.0)) ** 2, 0.0)
    return stereo(np.sin(ph) * env * 0.8, 0.15)


def void_swell(dur, n, seed):
    """Souffle filtré qui MONTE puis se coupe net (bruit inversé) : l'air aspiré par le néant."""
    rng = np.random.default_rng(seed)
    m = int(dur * RATE)
    noise = rng.standard_normal((m, 2))
    noise = sos_filter(noise, "bandpass", [300, 3500], 2)
    env = np.linspace(0, 1, m) ** 3
    sw = noise * env[:, None] / (np.max(np.abs(noise)) + 1e-12)
    out = np.zeros((n, 2))
    start = int(0.05 * RATE)
    end = min(n, start + m)
    out[start:end] = sw[:end - start]
    return out


def comb(x, freq, fb, mix):
    d = max(1, int(round(RATE / freq)))
    b = np.zeros(d + 1)
    b[0] = 1.0
    a = np.zeros(d + 1)
    a[0] = 1.0
    a[d] = -fb
    y = signal.lfilter(b, a, x, axis=0) * (1 - fb)
    return (1 - mix) * x + mix * y


def ring(x, freq, mix):
    t = np.arange(len(x)) / RATE
    return (1 - mix) * x + mix * x * np.sin(2 * math.pi * freq * t)[:, None]


def build_era(era, i, vanilla, n_ref):
    """Variation i (0 à 3) de l'ère : signal float (n_ref, 2), AVANT le gain de sonie."""
    base = vanilla[TIR[i]]
    x = resample(base, era["pitch"])
    x = saturate(x * 1.2, era["drive"])
    if era.get("comb"):
        x = comb(x, *era["comb"])
    x = fit(x, n_ref)
    for pat, idx, gdb, pitch, lp, keep in era.get("couches", []):
        src = vanilla[pat % idx[i]]
        c = resample(src[:int(keep / pitch * RATE) + 1], pitch)
        c = sos_filter(c, "lowpass", lp)
        c = fade_out(fit(c, int(keep * RATE)), 0.06)
        x[:len(c)] += c * db(gdb) / (np.max(np.abs(c)) + 1e-12) * np.max(np.abs(x))
    peak = np.max(np.abs(x))
    if era.get("sub"):
        f0, f1, dur, gdb = era["sub"]
        x += sub_thump(f0, f1, dur, n_ref) * db(gdb) * peak
    if era.get("sweep"):
        f0, f1, dur, gdb = era["sweep"]
        x += sweep(f0, f1, dur, n_ref) * db(gdb) * peak
    if era.get("vide"):
        dur, gdb = era["vide"]
        x += void_swell(dur, n_ref, 6900 + 10 * era["n"] + i) * db(gdb) * peak
    if era.get("ring"):
        x = ring(x, *era["ring"])
    x = sos_filter(x, "highpass", era["hp"])
    x = sos_filter(x, "lowpass", era["lp"])
    x = fade_out(x, 0.08)
    # limiteur doux : la crête ne mène pas la normalisation
    x = saturate(x / (np.max(np.abs(x)) + 1e-12), 1.6) * 0.9
    return x


# --------------------------------------------------------------------------------------------- mesures

def k_weight(x):
    """Filtre K de la norme BS.1770 (plateau aigu + passe-haut), coefficients recalculés pour 44,1 kHz."""
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
    y = signal.lfilter(b1, a1, x, axis=0)
    return signal.lfilter(b2, a2, y, axis=0)


def to_db(v):
    return -200.0 if v <= 0 else 20 * math.log10(v)


def measure(x, n_ref):
    """Crête (dBFS), RMS (dBFS, énergie / n_ref), sonie K (LKFS-like, sans porte, / n_ref), momentanée max (400 ms)."""
    peak = float(np.max(np.abs(x))) if len(x) else 0.0
    energy = float(np.sum(x ** 2)) / x.shape[1]
    rms = math.sqrt(energy / n_ref)
    y = k_weight(x)
    lk = -0.691 + 10 * math.log10(max(1e-20, float(np.sum(y ** 2)) / n_ref))
    win, hop = int(0.4 * RATE), int(0.01 * RATE)
    c = np.concatenate([[0.0], np.cumsum(np.sum(y ** 2, axis=1))])
    best = 0.0
    for s in range(0, max(1, len(y) - win + 1), hop):
        e = c[min(len(y), s + win)] - c[s]
        best = max(best, e)
    mom = -0.691 + 10 * math.log10(max(1e-20, best / win))
    # timbre (hors contrôle du volume) : centroïde spectral et part de l'énergie sous 200 Hz, « plus grave »
    spec = np.abs(np.fft.rfft(np.mean(x, axis=1))) ** 2
    fr = np.fft.rfftfreq(len(x), 1.0 / RATE)
    tot = float(np.sum(spec)) or 1.0
    return {"crete_dbfs": round(to_db(peak), 3), "rms_dbfs": round(to_db(rms), 3), "sonie_k": round(lk, 3),
            "momentanee_max": round(mom, 3), "duree_s": round(len(x) / RATE, 3),
            "centroide_hz": round(float(np.sum(fr * spec)) / tot, 1),
            "part_sous_200hz": round(float(np.sum(spec[fr < 200])) / tot, 4)}


def burst(singles, seed):
    """Rafale de 10 tirs/s pendant RAFALE_S : variations tirées au hasard (graine fixe), volume du prototype."""
    rng = np.random.default_rng(seed)
    n = int((RAFALE_S + 1.6) * RATE)
    out = np.zeros((n, 2))
    k = 0
    t = 0.0
    while t < RAFALE_S - 1e-9:
        s = singles[int(rng.integers(0, len(singles)))]
        a = int(round(t * RATE))
        m = min(len(s), n - a)
        out[a:a + m] += s[:m] * VOLUME
        k += 1
        t = k * CADENCE
    return out


def over(m, ref):
    """Mesures au-dessus de la référence : liste de (nom, écart dB)."""
    return [(k, m[k] - ref[k]) for k in ("crete_dbfs", "rms_dbfs", "sonie_k", "momentanee_max") if m[k] > ref[k] + 1e-9]


# --------------------------------------------------------------------------------------------- manifeste

def _ogg_crc_table():
    t = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) if r & 0x80000000 else (r << 1)
        t.append(r & 0xFFFFFFFF)
    return t


_OGG_CRC = _ogg_crc_table()


def ogg_fixed_serial(data, serial):
    """Même flux Ogg avec un numéro de série FIXE (libogg le tire au hasard à chaque encodage : seuls ces 4 octets et
    la somme de contrôle de chaque page changeaient d'un passage à l'autre, l'audio décodé étant identique) ; la
    somme CRC de chaque page est recalculée. Rend des octets reproductibles d'un passage à l'autre."""
    out = bytearray(data)
    pos = 0
    pages = 0
    while pos < len(out):
        if out[pos:pos + 4] != b"OggS":
            raise ValueError("page Ogg attendue à l'octet %d" % pos)
        nseg = out[pos + 26]
        size = 27 + nseg + sum(out[pos + 27:pos + 27 + nseg])
        out[pos + 14:pos + 18] = serial.to_bytes(4, "little")
        out[pos + 22:pos + 26] = b"\0\0\0\0"
        crc = 0
        for b in out[pos:pos + size]:
            crc = ((crc << 8) & 0xFFFFFFFF) ^ _OGG_CRC[((crc >> 24) ^ b) & 0xFF]
        out[pos + 22:pos + 26] = crc.to_bytes(4, "little")
        pos += size
        pages += 1
    return bytes(out), pages


def ogg_pages_ok(data):
    """Chaque page Ogg a sa signature et une somme CRC juste : (vrai, nombre de pages) ou (faux, motif)."""
    pos = pages = 0
    while pos < len(data):
        if data[pos:pos + 4] != b"OggS" or pos + 27 > len(data):
            return False, "page %d : signature OggS absente (octet %d)" % (pages, pos)
        nseg = data[pos + 26]
        size = 27 + nseg + sum(data[pos + 27:pos + 27 + nseg])
        page = bytearray(data[pos:pos + size])
        want = int.from_bytes(page[22:26], "little")
        page[22:26] = b"\0\0\0\0"
        crc = 0
        for b in page:
            crc = ((crc << 8) & 0xFFFFFFFF) ^ _OGG_CRC[((crc >> 24) ^ b) & 0xFF]
        if crc != want or len(page) != size:
            return False, "page %d : somme CRC fausse" % pages
        pos += size
        pages += 1
    return pages > 0, pages


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def write_lua(path, files):
    # Lot S0-suite : le champ `volumes` (volume du prototype par ère, écrit par tools/sound/rafales.py --appliquer) est
    # GARDÉ tel quel ; si les fichiers changent, relancer rafales.py --appliquer (marge des rafales tirées au hasard).
    keep = ""
    if os.path.exists(path):
        import re
        m = re.search(r"  -- Volume du prototype PAR ÈRE.*?\n  volumes = \{[^}]*\},\n",
                      open(path, encoding="utf-8").read(), re.S)
        keep = m.group(0) if m else ""
    lines = ["-- GÉNÉRÉ par tools/sound/sons.py (lot S0) : ne pas modifier à la main.",
             "-- Tir de la mitrailleuse par ère (âges 1-3, 4-6, 7-9, 10-12, 13-15) : 4 variations par ère, dérivées",
             "-- des 4 tirs vanilla (gun-turret-gunshot-01 à 04), volume du prototype vanilla (0,4).",
             "return {", "  volume = %s," % repr(VOLUME)] + ([keep.rstrip("\n")] if keep else []) + ["  eres = {"]
    for era in ERES:
        lines.append("    [%d] = { -- %s, âges %s" % (era["n"], era["nom"], ", ".join(str(a) for a in era["ages"])))
        for name in files[era["n"]]:
            lines.append('      "%s%s",' % (MOD_PREFIX, name))
        lines.append("    },")
    lines += ["  },", "}", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def check_mod(mod):
    d = os.path.join(mod, *MOD_DIR)
    man = os.path.join(d, "MANIFEST.json")
    with open(man, encoding="utf-8") as f:
        m = json.load(f)
    ok = fail = 0
    for name, info in sorted(m["fichiers"].items()):
        p = os.path.join(d, name)
        good = os.path.exists(p) and os.path.getsize(p) == info["octets"] and sha256(p) == info["sha256"]
        if good:
            with open(p, "rb") as f:
                good, _ = ogg_pages_ok(f.read())
        ok, fail = ok + good, fail + (not good)
        if not good:
            print("[FO-SONS] ECHEC %s" % p)
    listed = set(m["fichiers"])
    extra = sorted(f for f in os.listdir(d) if f.endswith(".ogg") and f not in listed)
    for e in extra:
        fail += 1
        print("[FO-SONS] ECHEC fichier hors manifeste : %s" % e)
    # Lot S0-suite : volumes par ère de sons.lua = ceux du manifeste (rafales.py --appliquer écrit les deux)
    raf = m.get("rafales_hasard")
    if raf:
        import re
        txt = open(os.path.join(d, "sons.lua"), encoding="utf-8").read()
        mv = re.search(r"volumes\s*=\s*\{([^}]*)\}", txt)
        lua = {k: float(v) for k, v in re.findall(r"\[(\d)\]\s*=\s*([\d.]+)", mv.group(1))} if mv else {}
        want = {k: float(v) for k, v in raf["volume_prototype_par_ere"].items()}
        if lua != want:
            fail += 1
            print("[FO-SONS] ECHEC volumes par ère : sons.lua %s, manifeste %s" % (lua, want))
        else:
            worst = max(v[0] for v in raf["distribution_pire_ecart_db"].values())
            print("[FO-SONS] volumes par ère (sons.lua = manifeste) : %s ; rafales au hasard : pire écart %+.3f dB "
                  "(marge demandée %.2f)" % (", ".join("%s : %s" % kv for kv in sorted(lua.items())), worst,
                                            raf["marge_db"]))
            if worst > -raf["marge_db"] + 1e-9:
                fail += 1
                print("[FO-SONS] ECHEC marge des rafales non tenue au manifeste")
    print("[FO-SONS] contrôle : %d fichier(s) conformes au manifeste, %d ECHEC(S)" % (ok, fail))
    return 0 if fail == 0 else 1


# --------------------------------------------------------------------------------------------- page

PAGE_HTML = """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sons de la mitrailleuse</title>
<style>
:root {{ --bg:#f6f4ef; --fg:#1d1b18; --mut:#6b665c; --card:#ffffff; --line:#e2ddd2; --acc:#a4452c; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg:#16150f; --fg:#ece8df; --mut:#a59f92;
  --card:#211f18; --line:#37332a; --acc:#e0805f; }} }}
:root[data-theme="dark"] {{ --bg:#16150f; --fg:#ece8df; --mut:#a59f92; --card:#211f18; --line:#37332a; --acc:#e0805f; }}
* {{ box-sizing: border-box; }}
body {{ margin:0; background:var(--bg); color:var(--fg); font:16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }}
main {{ max-width:680px; margin:0 auto; padding:20px 16px 48px; }}
h1 {{ font-size:1.45rem; margin:0 0 6px; }}
p.lead {{ color:var(--mut); margin:0 0 18px; }}
section {{ background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px 14px 10px; margin:0 0 14px; }}
h2 {{ font-size:1.08rem; margin:0 0 2px; }}
.ages {{ color:var(--acc); font-weight:600; font-size:.9rem; }}
.txt {{ margin:6px 0 10px; }}
.row {{ display:flex; flex-wrap:wrap; gap:6px 14px; align-items:center; margin:0 0 8px; }}
.row span {{ min-width:78px; font-size:.92rem; color:var(--mut); }}
audio {{ width:100%; max-width:440px; height:40px; }}
.mes {{ font-size:.78rem; color:var(--mut); margin:4px 0 0; }}
footer {{ font-size:.8rem; color:var(--mut); margin-top:22px; }}
</style>
</head>
<body>
<main>
<h1>Le tir de la mitrailleuse, ère par ère</h1>
<p class="lead">Écoute d'abord la vanilla, puis les 5 ères. Chaque ère a un tir seul et une rafale (10 tirs par seconde,
comme en jeu). Aucun son n'est plus fort que la vanilla : crête et énergie mesurées, chiffres sous chaque ère.
Un casque ou des écouteurs font entendre les basses, qu'un haut-parleur de téléphone coupe en partie.</p>
{sections}
<footer>Lot S0, {date}. Sons dérivés des sons du jeu (data/base/sound) : hauteur, grain, filtres, couches.
Fichiers du jeu : OGG ; ici : MP3, lus par tous les téléphones. Ta réponse : garder, changer (quelle ère, et quoi :
plus grave, plus sec, moins de basse...), ou refaire.</footer>
</main>
</body>
</html>
"""


def fr(text):
    """Virgule décimale française dans les nombres d'une ligne de mesures."""
    import re
    return re.sub(r"(\d)\.(\d)", r"\1,\2", text)


def page_section(title, ages, text, single, rafale, mes):
    return ("<section>\n<h2>%s</h2>\n<div class=\"ages\">%s</div>\n<p class=\"txt\">%s</p>\n"
            "<div class=\"row\"><span>Un tir</span><audio controls preload=\"none\" src=\"%s\"></audio></div>\n"
            "<div class=\"row\"><span>Rafale</span><audio controls preload=\"none\" src=\"%s\"></audio></div>\n"
            "<p class=\"mes\">%s</p>\n</section>" % (title, ages, text, single, rafale, mes))


# --------------------------------------------------------------------------------------------- principal

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", default=DEFAULT_WORK)
    ap.add_argument("--page", default=None, help="dossier de la page d'écoute (index.html + MP3)")
    ap.add_argument("--mod", default=REPO)
    ap.add_argument("--blender", default=BLENDER)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        return check_mod(a.mod)
    work = os.path.abspath(a.work)
    os.makedirs(work, exist_ok=True)
    print("[FO-SONS] dossier de travail : %s" % work)

    # 1. sources vanilla
    srcs = sorted(set(TIR + [pat % k for era in ERES for pat, idx, *_ in era.get("couches", []) for k in idx]))
    jobs = [{"op": "decode", "src": os.path.join(VANILLA_SOUND, *s.split("/")),
             "dst": os.path.join(work, "vanilla", s.replace("/", "_").replace(".ogg", ".wav"))} for s in srcs]
    blender(jobs, work, "1-decode", a.blender)
    vanilla = {s: read_wav(j["dst"]) for s, j in zip(srcs, jobs)}
    ref_n = [len(vanilla[t]) for t in TIR]
    refs = [measure(vanilla[t], ref_n[i]) for i, t in enumerate(TIR)]
    ref_burst = burst([vanilla[t] for t in TIR], 4242)
    ref_burst_m = measure(ref_burst, len(ref_burst))
    print("[FO-SONS] vanilla : %d source(s) décodée(s) ; tirs %s" % (len(srcs), ", ".join(
        "%d : %.2f s, crête %.2f dBFS, RMS %.2f dBFS" % (i + 1, r["duree_s"], r["crete_dbfs"], r["rms_dbfs"])
        for i, r in enumerate(refs))))

    # 2 à 4. ères, encodage, mesure sur le décodé, gain réduit tant qu'une mesure dépasse la vanilla
    raw = {(e["n"], i): build_era(e, i, vanilla, ref_n[i]) for e in ERES for i in range(4)}
    gains = {}
    for (n, i), x in raw.items():
        m = measure(x, ref_n[i])
        g = min(db(refs[i][k] - m[k]) for k in ("crete_dbfs", "rms_dbfs", "sonie_k", "momentanee_max")) * MARGE
        gains[(n, i)] = g
    era_gain = {e["n"]: 1.0 for e in ERES}
    final = {}
    for rnd in range(1, 6):
        jobs = []
        for (n, i), x in sorted(raw.items()):
            base = "tir-ere%d-%d" % (n, i + 1)
            wavp = os.path.join(work, "wav", base + ".wav")
            write_wav(wavp, x * gains[(n, i)] * era_gain[n])
            oggp = os.path.join(work, "ogg", base + ".ogg")
            jobs.append({"op": "ogg", "src": wavp, "dst": oggp, "bitrate": OGG_BITRATE})
            jobs.append({"op": "decode", "src": oggp, "dst": os.path.join(work, "decode", base + ".wav")})
        blender(jobs, work, "2-encode-%d" % rnd, a.blender)
        bad = {}
        final = {}
        for (n, i) in sorted(raw):
            base = "tir-ere%d-%d" % (n, i + 1)
            y = read_wav(os.path.join(work, "decode", base + ".wav"))
            m = measure(y, ref_n[i])
            final[(n, i)] = (y, m)
            ov = over(m, refs[i])
            if ov:
                bad[n] = min(bad.get(n, 1.0), min(db(-d) for _, d in ov) * MARGE)
        bursts = {}
        for e in ERES:
            b = burst([final[(e["n"], i)][0] for i in range(4)], 4242)  # même suite de variations que la vanilla
            bm = measure(b, len(ref_burst))
            bursts[e["n"]] = (b, bm)
            ov = over(bm, ref_burst_m)
            if ov:
                bad[e["n"]] = min(bad.get(e["n"], 1.0), min(db(-d) for _, d in ov) * MARGE)
        print("[FO-SONS] passage %d : %d ère(s) au-dessus de la vanilla%s" % (
            rnd, len(bad), "" if not bad else " (" + ", ".join("ère %d × %.3f" % kv for kv in sorted(bad.items())) + ")"))
        if not bad:
            break
        for n, f in bad.items():
            era_gain[n] *= f
    else:
        print("[FO-SONS] ECHEC : volume au-dessus de la vanilla après 5 passages")
        return 1

    # 5. fichiers du mod
    dmod = os.path.join(a.mod, *MOD_DIR)
    os.makedirs(dmod, exist_ok=True)
    files, manifest = {}, {"genere_par": "tools/sound/sons.py (lot S0)", "volume_prototype": VOLUME,
                           "debit_ogg": OGG_BITRATE, "reference": {}, "fichiers": {}, "rafales": {}}
    for i, t in enumerate(TIR):
        manifest["reference"]["vanilla-%d" % (i + 1)] = dict(refs[i], source="__base__/sound/" + t)
    manifest["reference"]["rafale-vanilla"] = ref_burst_m
    rows = []
    for e in ERES:
        files[e["n"]] = []
        for i in range(4):
            base = "tir-ere%d-%d.ogg" % (e["n"], i + 1)
            src = os.path.join(work, "ogg", base)
            dst = os.path.join(dmod, base)
            with open(src, "rb") as f:
                data = f.read()
            # numéro de série fixe, propre au fichier (premiers octets du sha256 de son nom)
            data, _ = ogg_fixed_serial(data, int(hashlib.sha256(base.encode()).hexdigest()[:8], 16))
            with open(dst, "wb") as f:
                f.write(data)
            files[e["n"]].append(base)
            m = final[(e["n"], i)][1]
            ecart = {k: round(m[k] - refs[i][k], 3) for k in ("crete_dbfs", "rms_dbfs", "sonie_k", "momentanee_max")}
            manifest["fichiers"][base] = {"ere": e["n"], "variation": i + 1, "octets": len(data),
                                          "sha256": sha256(dst), "mesures": m, "ecart_vanilla_db": ecart}
            rows.append((base, m, ecart))
        bm = bursts[e["n"]][1]
        manifest["rafales"]["ere-%d" % e["n"]] = dict(bm, ecart_vanilla_db={
            k: round(bm[k] - ref_burst_m[k], 3) for k in ("crete_dbfs", "rms_dbfs", "sonie_k", "momentanee_max")})
    # les fichiers du mod (numéro de série fixé) se décodent à l'échantillon près comme ceux qui ont été mesurés
    jobs = [{"op": "decode", "src": os.path.join(dmod, b), "dst": os.path.join(work, "verif", b.replace(".ogg", ".wav"))}
            for b in sorted(manifest["fichiers"])]
    blender(jobs, work, "4-verif", a.blender)
    same = 0
    for j in jobs:
        base = os.path.basename(j["src"])
        n, i = manifest["fichiers"][base]["ere"], manifest["fichiers"][base]["variation"] - 1
        y = read_wav(j["dst"])
        ok_pages, _ = ogg_pages_ok(open(j["src"], "rb").read())
        same += int(ok_pages and y.shape == final[(n, i)][0].shape and bool(np.array_equal(y, final[(n, i)][0])))
    print("[FO-SONS] fichiers du mod relus : %d/%d identiques au décodé mesuré (pages Ogg et CRC justes)" % (
        same, len(jobs)))
    if same != len(jobs):
        print("[FO-SONS] ECHEC : un fichier du mod ne se décode pas comme le fichier mesuré")
        return 1
    write_lua(os.path.join(dmod, "sons.lua"), files)
    with open(os.path.join(dmod, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    total = sum(v["octets"] for v in manifest["fichiers"].values())
    print("[FO-SONS] mod : %d fichiers OGG, %.1f Ko, dans %s" % (len(manifest["fichiers"]), total / 1024.0, dmod))

    # tableau des mesures (texte)
    lines = ["Mesures du lot S0 (décodé de l'OGG livré ; écarts à la variation vanilla de même rang, en dB ; "
             "négatif = plus faible)", "",
             "fichier                crête   RMS    sonieK  mom.max | écart crête  RMS   sonieK mom.max"]
    for i, r in enumerate(refs):
        lines.append("vanilla-%d             %6.2f %6.2f %6.2f %6.2f |" % (i + 1, r["crete_dbfs"], r["rms_dbfs"],
                                                                         r["sonie_k"], r["momentanee_max"]))
    for base, m, e in rows:
        lines.append("%-22s %6.2f %6.2f %6.2f %6.2f | %6.2f %6.2f %6.2f %6.2f" % (
            base, m["crete_dbfs"], m["rms_dbfs"], m["sonie_k"], m["momentanee_max"],
            e["crete_dbfs"], e["rms_dbfs"], e["sonie_k"], e["momentanee_max"]))
    lines.append("")
    lines.append("rafale-vanilla         %6.2f %6.2f %6.2f %6.2f |" % (
        ref_burst_m["crete_dbfs"], ref_burst_m["rms_dbfs"], ref_burst_m["sonie_k"], ref_burst_m["momentanee_max"]))
    for e in ERES:
        bm = manifest["rafales"]["ere-%d" % e["n"]]
        d = bm["ecart_vanilla_db"]
        lines.append("rafale-ere%d           %6.2f %6.2f %6.2f %6.2f | %6.2f %6.2f %6.2f %6.2f" % (
            e["n"], bm["crete_dbfs"], bm["rms_dbfs"], bm["sonie_k"], bm["momentanee_max"],
            d["crete_dbfs"], d["rms_dbfs"], d["sonie_k"], d["momentanee_max"]))
    worst = max(max(v["ecart_vanilla_db"].values()) for v in manifest["fichiers"].values())
    worst_b = max(max(v["ecart_vanilla_db"].values()) for v in manifest["rafales"].values())
    lines.append("")
    lines.append("écart MAXIMAL à la vanilla : tirs %+.3f dB, rafales %+.3f dB (doit être <= 0)" % (worst, worst_b))
    cent = [("vanilla", sum(r["centroide_hz"] for r in refs) / 4, sum(r["part_sous_200hz"] for r in refs) / 4)]
    for e in ERES:
        ms = [final[(e["n"], i)][1] for i in range(4)]
        cent.append(("ère %d" % e["n"], sum(m["centroide_hz"] for m in ms) / 4, sum(m["part_sous_200hz"] for m in ms) / 4))
    manifest["timbre_moyen"] = {k: {"centroide_hz": round(c, 1), "part_sous_200hz": round(p, 4)} for k, c, p in cent}
    dec = all(cent[k + 1][1] < cent[k][1] for k in range(len(cent) - 1))
    inc = all(cent[k + 1][2] > cent[k][2] for k in range(len(cent) - 1))
    lines.append("timbre moyen (4 variations) : " + " ; ".join(
        "%s centroïde %.0f Hz, %.1f %% sous 200 Hz" % (k, c, 100 * p) for k, c, p in cent))
    lines.append("plus grave à chaque ère : centroïde décroissant %s, part sous 200 Hz croissante %s" % (
        "OUI" if dec else "NON", "OUI" if inc else "NON"))
    with open(os.path.join(dmod, "MANIFEST.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False, sort_keys=True)
        f.write("\n")
    with open(os.path.join(work, "mesures.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    if not (dec and inc and worst <= 0 and worst_b <= 0):
        print("[FO-SONS] ECHEC : contrat non tenu (volume au-dessus de la vanilla, ou ères pas plus graves une à une)")
        return 1

    # 6. page d'écoute
    if a.page:
        page = os.path.abspath(a.page)
        os.makedirs(page, exist_ok=True)
        jobs = []
        listen = [("vanilla", None)] + [("ere%d" % e["n"], e) for e in ERES]
        for key, e in listen:
            if e is None:
                single = vanilla[TIR[0]]
                b = ref_burst
            else:
                single = final[(e["n"], 0)][0]
                b = bursts[e["n"]][0]
            for kind, sig in (("tir", single * VOLUME), ("rafale", b)):
                wavp = os.path.join(work, "page", "%s-%s.wav" % (key, kind))
                write_wav(wavp, sig)
                jobs.append({"op": "mp3", "src": wavp, "dst": os.path.join(page, "%s-%s.mp3" % (key, kind)),
                             "bitrate": MP3_BITRATE})
        blender(jobs, work, "3-page", a.blender)
        secs = []
        ref = refs[0]
        secs.append(page_section("Vanilla (référence)", "la mitrailleuse du jeu de base",
                                 "Le son d'origine, pour comparer.", "vanilla-tir.mp3", "vanilla-rafale.mp3",
                                 fr("tir : crête %.1f dBFS, RMS %.1f dBFS ; rafale : RMS %.1f dBFS ; timbre : "
                                    "centroïde %.0f Hz" % (ref["crete_dbfs"], ref["rms_dbfs"], ref_burst_m["rms_dbfs"],
                                                           manifest["timbre_moyen"]["vanilla"]["centroide_hz"]))))
        for e in ERES:
            m = final[(e["n"], 0)][1]
            d = manifest["fichiers"]["tir-ere%d-1.ogg" % e["n"]]["ecart_vanilla_db"]
            bd = manifest["rafales"]["ere-%d" % e["n"]]["ecart_vanilla_db"]
            secs.append(page_section(
                "Ère " + e["nom"], "âges %s" % " à ".join([str(e["ages"][0]), str(e["ages"][-1])]), e["texte"],
                "ere%d-tir.mp3" % e["n"], "ere%d-rafale.mp3" % e["n"],
                fr("tir : %+.1f dB de crête, %+.1f dB d'énergie face à la vanilla ; rafale : %+.1f dB d'énergie ; "
                   "timbre : centroïde %.0f Hz" % (d["crete_dbfs"], d["rms_dbfs"], bd["rms_dbfs"],
                                                   manifest["timbre_moyen"]["ère %d" % e["n"]]["centroide_hz"]))))
        import datetime
        html = PAGE_HTML.format(sections="\n".join(secs), date=datetime.date.today().strftime("%d/%m/%Y"))
        with open(os.path.join(page, "index.html"), "w", encoding="utf-8", newline="\n") as f:
            f.write(html)
        print("[FO-SONS] page d'écoute : %s (%d MP3)" % (os.path.join(page, "index.html"), len(jobs)))
    print("[FO-SONS] BILAN : 20 tirs, 5 rafales, aucune mesure au-dessus de la vanilla")
    return 0


if __name__ == "__main__":
    sys.exit(main())
