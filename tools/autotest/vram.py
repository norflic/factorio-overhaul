#!/usr/bin/env python3
r"""
Lot D4m (OBJECTIFS.md D4-1, D4-3, D4-5) : mémoire vidéo, chargement et images par seconde d'une session
AVEC images (fo-visual.bat / fo-captures.bat). Ne lance rien : lit des fichiers.

    python tools/autotest/vram.py <journal ou dossier> [--samples vram.tsv] [--perf perf-stats.csv]
                                  [--stdout stdout.txt] [--seuil-go 6] [--json sortie.json]
    python tools/autotest/vram.py --sonde      (essai des compteurs GPU de Windows, sans rien lancer)

Entrée : le journal d'une session avec images (fo-visual\write\factorio-current.log, ou visual.log d'une
archive fo-logs, ou factorio.log que le pilote copie dans fo-shots), ou un DOSSIER où chercher ces fichiers
(fo-shots, archive fo-logs, fo-visual, fo-visual\write). Les fichiers vram.tsv (mesure directe du pilote),
perf-stats.csv (option --output-perf-stats du jeu) et stdout.txt (résumés du mode benchmark) sont cherchés
au même endroit.

Rapport :
  1. réglages lus dans le journal : qualité des sprites, usage de la mémoire vidéo, compression DXT, budget
     Windows « [Local Video Memory] » (lu au démarrage du moteur graphique, AVANT tout chargement : son
     « CurrentUsage » n'est PAS l'occupation du jeu) ;
  2. atlas de sprites : une ligne « Created atlas bitmap LxH [drapeaux] » chacun (ligne du moteur, horodatée ; une
     impression de script ne compte pas), avec les niveaux de mipmaps (« Generated mipmaps (N) for atlas [i] »), et
     une FOURCHETTE d'octets estimés par la règle ci-dessous ; l'atlas VIRTUEL du plancher (« Created virtual atlas
     pages LxHxN ») est COMPTÉ à part dans l'estimation (règle « Atlas virtuel » ci-dessous), avec sa variante non
     compressée confrontée à la mesure directe ; le chiffre du moteur « Atlas memory size: … (virtual) » est
     rapporté s'il est écrit (aucun journal archivé ne le contient au 22/10) ;
     totaux par catégorie et comparaison au seuil D4-1 (6 Go en haute qualité) ;
  3. chargement (D4-3) : instants « Sprites loaded » et « Factorio initialised », cache des atlas lu ou refait ;
  4. mesure DIRECTE (vram.tsv) : mémoire vidéo dédiée du seul processus de test (compteurs Windows
     « GPU Process Memory(pid_<PID>_*)\Dedicated Usage »), pic, moyenne, et moyenne par phase du scénario
     d4-geant ; mémoire vive privée du processus ;
  5. images par seconde (D4-5) : fichier --output-perf-stats du jeu (colonnes de PerformanceLogger.cpp, lues
     dans le binaire ; sens NON prouvé), calculées par plusieurs voies à confronter (ci-dessous), et résumés
     « prepare/render/frame> avg » s'ils existent (écriture NON prouvée) ; images de jeu par seconde (UPS) de
     chaque phase d4-geant (LuaProfiler) ; état VSync et fréquence de l'écran (journal : plafond possible) ;
  6. champ réel des vues d4-geant (lignes « CHAMP ») : bâtiments à niveaux, tapis et bras réellement dessinés.

Images par seconde, voies de calcul (aucune n'est prouvée seule ; leur accord est la preuve) :
  - « phase » : nombre de lignes du fichier pendant la phase / durée réelle de la phase (LuaProfiler du
    greffon) ; suppose UNE ligne par image dessinée ;
  - « max » : 1000 / moyenne de max(cpu-frame, gpu-frame) par image : l'image ne peut pas être plus courte
    que la plus longue des deux ;
  - « cpu » : 1000 / moyenne de cpu-frame : HYPOTHÈSE « cpu-frame = durée totale de l'image » ; si cpu-frame
    n'inclut pas l'attente du processeur graphique, ce chiffre SURESTIME précisément le cas visé (usine
    limitée par le GPU). Test de l'hypothèse : somme des cpu-frame / durée de la phase ≈ 1 ;
  - compteurs cumulés present-count et refresh-count (s'ils croissent) : écart sur la phase / durée ; le
    second devrait valoir la fréquence de l'écran s'il compte les rafraîchissements (sens NON prouvé).
  VSync actif (« [VSync: 1] », toutes les sessions archivées le 21/10) : images/s plafonnées à la fréquence de
  l'écran (« Available displays … 144Hz ») ; un plafond à 60 imposé par le jeu lui-même n'est pas prouvé.

Règle d'octets par pixel (bas–haut), justifiée :
  - drapeau « not-compressed » : 4–4 (RGBA 8 bits ; le drapeau exclut l'atlas de la compression) ;
  - compression DXT « high-quality » (journal « [DXT: high-quality] ») : 1–1 (BC3 ou YCoCg-DXT5, les deux
    formats que teste le jeu : ligne « YCoCgDXT PSNR / BC3 PSNR » ; 16 octets par bloc de 4×4 pixels) ;
  - compression « low-quality » : 0,5–1. HYPOTHÈSE (BC1, 8 octets par bloc) ; sources partielles : le sens
    (« select low quality to reduce the size of sprites even more », data/core/locale/en/core.cfg, clé
    texture-compression) et le nuanceur compress-rygDXT du binaire (compresseur DXT1/DXT5) ; le format exact
    n'est pas écrit dans le journal ;
  - compression désactivée (« none ») : 4–4 ;
  - drapeau « alpha-mask » (ombres, masques) : HYPOTHÈSE, un seul canal utile : compressé 0,5–1 (BC4 : le
    binaire contient le nuanceur compress-bc4 ; ou A8/BC3), non compressé 1–4 (A8 ou RGBA) ; le format réel
    n'est pas écrit dans le journal ;
  - mipmaps : « Generated mipmaps (N) » → facteur 1 + 1/4 + … ; bas = N niveaux en tout, haut = N niveaux
    en plus de l'image de base ; drapeau « mipmap » sans ligne : 1 à 4/3.
  Unités : 1 Go = 10^9 octets, 1 Mo = 10^6 octets ; les « MB » du journal du jeu valent 2^20 octets.

Atlas virtuel (« Video memory usage: low », « Tex.Stream.: 1 » ; RD_LOG F81), règle justifiée :
  - PROUVÉ par le journal : le moteur crée N pages de LxH pixels (« Created virtual atlas pages 4096x4096x9 » :
    9 × 16,8 = 151,0 Mpx) et produit des mipmaps pour un atlas virtuel de VLxVH (« Generated mipmaps for virtual
    atlas of size 16384x12288 », 201,3 Mpx : 12 surfaces de page, plus que les 9 pages ; nombre de niveaux non écrit) ;
  - lu dans le binaire 1.1.91 (chaînes, sens déduit) : clés de config.ini « texture-streaming »,
    « streamed-atlas-physical-vram-size » et « compress-virtual-atlas » (valeurs par défaut inconnues) ; assertion
    « virtualAtlasPage->getFormat() == BitmapFormat::RGBA_8888 » (Atlas.cpp) ; message « Couldn't create %s bitmap
    … Probably not enough video memory » partagé par « virtual atlas » et « atlas » ; ligne « Atlas memory size:
    %.2fMB; %.2fMB (virtual) », jamais écrite dans les 13 journaux archivés ;
  - locale du jeu (data/core/locale/en/core.cfg, clé texture-streaming) : « Sprites that were not put into any
    sprite atlas … will be kept in RAM until needed by the GPU » ;
  - règle COMPTÉE : les pages comme si elles résidaient en mémoire vidéo, compressées comme les sprites principaux
    (règle DXT du journal, celle d'un atlas « [none] ») : bas = pages × octets/px bas, sans mipmaps ; haut = (pages +
    1/3 de la plus grande des deux surfaces, pages ou atlas virtuel annoncé, si la ligne de mipmaps existe) ×
    octets/px haut. HYPOTHÈSES : résidence (les pages peuvent rester en mémoire vive, la carte ne gardant qu'un
    cache physique dont la taille n'est pas écrite ; compter les pages est alors le sens PRUDENT d'un budget),
    compression (option compress-virtual-atlas), emplacement des mipmaps (1/3 borne la série 1/4 + 1/16 + …) ;
  - variante NON compressée (RGBA 8888, format de l'assertion) : pages × 4 octets, sans mipmaps ; NON comptée, mais
    confrontée à la mesure directe : si les atlas (bas) plus cette variante dépassent le pic dédié + le pic partagé,
    elle est exclue par la mesure (sous l'hypothèse que les pages sont allouées en entier).
L'estimation ne remplace pas la mesure directe (point 4), qui seule prouve D4-1 et D4-5.
"""
import argparse
import ctypes
import json
import math
import os
import re
import sys
import time

GO, MO = 1e9, 1e6
MIB = 1 << 20

RE_TIME = re.compile(r"^\s*(\d+\.\d+)\s")
# Lignes du MOTEUR seulement : l'horodatage en tête, puis le message. Une impression de script (« 1.0 Script @…: …
# Created atlas bitmap … ») ou tout autre texte libre qui contient ces mots n'est pas compté.
RE_ATLAS = re.compile(r"^\s*\d+\.\d+ Created atlas bitmap (\d+)x(\d+) \[([^\]]*)\]")
RE_MIP = re.compile(r"^\s*\d+\.\d+ Generated mipmaps \((\d+)\) for atlas \[(\d+)\] of size (\d+)x(\d+)")
# Atlas VIRTUEL (pages de textures en flux), créé au plancher « Video memory usage: low » (RD_LOG F81) : relevé dans
# r["virtual_atlases"] et compté à part par virtual_estimate (règle en tête du fichier).
RE_VIRTUAL = re.compile(r"^\s*\d+\.\d+ Created virtual atlas pages (\d+)x(\d+)x(\d+)\s*$")
# Mipmaps de l'atlas virtuel : taille de l'atlas virtuel, sans nombre de niveaux (« … of size 16384x12288 »).
RE_VIRTUAL_MIP = re.compile(r"^\s*\d+\.\d+ Generated mipmaps for virtual atlas of size (\d+)x(\d+)\s*$")
# Variante au singulier, lue dans le binaire (« Created virtual atlas page %ux%u [%s] ») mais jamais vue dans un
# journal : relevée pour être SIGNALÉE, pas comptée (on ne sait pas si elle double la ligne au pluriel).
RE_VIRTUAL_PAGE = re.compile(r"^\s*\d+\.\d+ Created virtual atlas page (\d+)x(\d+) \[([^\]]*)\]")
# Chiffres du moteur lui-même, lus dans le binaire, jamais écrits dans les 13 journaux archivés (22/10) : rapportés
# tels quels s'ils apparaissent (« MB » du jeu supposés valoir 2^20 octets, comme ceux des lignes de budget).
RE_ATLAS_MEM = re.compile(r"^\s*\d+\.\d+ Atlas memory size: ([0-9.]+)MB; ([0-9.]+)MB \(virtual\)")
RE_OUTSIDE = re.compile(r"^\s*\d+\.\d+ Size of sprites outside of atlas: ([0-9.]+)MB")
RE_QUALITY = re.compile(r"\[Graphics quality: ([^\]]+)\]")
RE_VMU = re.compile(r"\[Video memory usage: ([^\]]+)\]")
RE_DXT = re.compile(r"\[DXT: ([^\]]+)\]")
RE_STREAM = re.compile(r"\[Tex\.Stream\.: ([^\]]+)\]")
RE_MAXTEX = re.compile(r"\[Max texture size: ([^\]]+)\]")
RE_BUDGET = re.compile(r"\[(Local Video Memory|Non-Local Vid\.Mem\.)\] Budget: (\d+)MB, CurrentUsage: (\d+)MB, "
                       r"Reservation: (\d+)/(\d+)MB")
RE_DEDICATED = re.compile(r"Dedicated video memory size (\d+) MB")
RE_D3D = re.compile(r"Initialised (?:Direct3D|OpenGL)\[?\d*\]?: ([^;]+)")
RE_PRESET = re.compile(r"Graphics settings preset: (\S+)")
RE_VSYNC = re.compile(r"\[VSync: (\d)\]")
RE_DISPLAY = re.compile(r"\[\d+\]: (.+?) - (.+?) \{0x[0-9a-fA-F]+, \[-?\d+,-?\d+\], (\d+)x(\d+), \d+bit, (\d+)Hz\}")
RE_CHAMP = re.compile(r"\[FO-D4-GEANT\] CHAMP (\S+) (\S+) (\d+)x(\d+) zoom ([0-9.]+) : ([0-9.]+) x ([0-9.]+) tuiles, "
                      r"batiments a niveaux (\d+) \(machines (\d+), murs (\d+)\), tapis (\d+), bras (\d+) ; "
                      r"familles (\d+)/(\d+)")
RE_PERFORMED = re.compile(r"Performed (\d+) updates in ([0-9.]+) ms")
RE_UPD_AVG = re.compile(r"^\s*avg: ([0-9.]+) ms, min: ([0-9.]+) ms, max: ([0-9.]+) ms")
RE_PERFSUM = re.compile(r"^\s*(prepare|streaming|render|flip|frame)> avg: ([0-9.]+) ms,\s*med: ([0-9.]+) ms,\s*"
                        r"min: ([0-9.]+) ms,\s*max: ([0-9.]+) ms")
RE_PHASE_START = re.compile(r"\[FO-D4-GEANT\] PHASE debut (\S+) tick (\d+) zoom ([0-9.]+) daytime ([0-9.]+)")
RE_PHASE_END = re.compile(r"\[FO-D4-GEANT\] PHASE fin (\S+) tick (\d+) ticks (\d+) .*?(?:Duration|Dur\S{1,3}e)\s*:\s*"
                          r"([0-9.]+)\s*ms")

# Catégorie d'un atlas : premier drapeau trouvé dans cet ordre.
CATEGORIES = [
    ("shadow", "ombres"),
    ("terrain-effect-map", "effets de terrain"),
    ("terrain", "terrain"),
    ("decal", "decalcomanies au sol"),
    ("smoke", "fumees"),
    ("icon-background", "fonds d'icones"),
    ("icon", "icones"),
    ("alpha-mask", "masques alpha"),
    ("low-object", "objets bas"),
    ("mipmap", "objets avec mipmaps"),
]
OBJETS = "objets (sprites principaux)"


# ------------------------------------------------------------------------------------------------
# Lecture du journal
# ------------------------------------------------------------------------------------------------
def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def stamp(line):
    m = RE_TIME.match(line)
    return float(m.group(1)) if m else None


def parse_log(text):
    """Tout ce que le journal dit de la mémoire vidéo, du chargement et des phases d4-geant."""
    r = {"atlases": [], "budgets": {}, "events": {}, "phases": [], "bench": {}, "perf_summary": {}, "champs": [],
         "displays": [], "virtual_atlases": [], "virtual_mips": [], "virtual_page_lines": 0}
    open_phase = {}
    for line in text.splitlines():
        t = stamp(line)
        m = RE_ATLAS.search(line)
        if m:
            flags = [f.strip() for f in m.group(3).split(",") if f.strip()]
            r["atlases"].append({"index": len(r["atlases"]), "w": int(m.group(1)), "h": int(m.group(2)),
                                 "flags": flags, "mips": None})
            continue
        m = RE_VIRTUAL.search(line)
        if m:
            r["virtual_atlases"].append({"w": int(m.group(1)), "h": int(m.group(2)), "pages": int(m.group(3))})
            continue
        m = RE_VIRTUAL_MIP.search(line)
        if m:
            r["virtual_mips"].append({"w": int(m.group(1)), "h": int(m.group(2))})
            continue
        if RE_VIRTUAL_PAGE.search(line):
            r["virtual_page_lines"] += 1
            continue
        m = RE_ATLAS_MEM.search(line)
        if m:
            r["engine_atlas_mb"] = {"atlas": float(m.group(1)), "virtuel": float(m.group(2))}
            continue
        m = RE_OUTSIDE.search(line)
        if m:
            r["engine_outside_mb"] = float(m.group(1))
            continue
        m = RE_MIP.search(line)
        if m:
            i = int(m.group(2))
            if i < len(r["atlases"]):
                a = r["atlases"][i]
                if (a["w"], a["h"]) == (int(m.group(3)), int(m.group(4))):
                    a["mips"] = int(m.group(1))
                else:
                    a["mips_mismatch"] = "%sx%s" % (m.group(3), m.group(4))
            continue
        if "Graphics options:" in line:
            for key, rx in (("quality", RE_QUALITY), ("video_memory_usage", RE_VMU), ("dxt", RE_DXT)):
                mm = rx.search(line)
                if mm:
                    r[key] = mm.group(1).strip()
            r["graphics_line"] = line.strip()
            continue
        for key, rx in (("tex_stream", RE_STREAM), ("max_texture", RE_MAXTEX)):
            mm = rx.search(line)
            if mm and key not in r:
                r[key] = mm.group(1).strip()
        m = RE_BUDGET.search(line)
        if m:
            r["budgets"][m.group(1)] = {"budget_mib": int(m.group(2)), "current_mib": int(m.group(3)),
                                        "reservation_mib": int(m.group(4)), "reservation_max_mib": int(m.group(5))}
            continue
        m = RE_DEDICATED.search(line)
        if m and "dedicated_mib" not in r:
            r["dedicated_mib"] = int(m.group(1))
        m = RE_D3D.search(line)
        if m and "adapter" not in r:
            r["adapter"] = m.group(1).strip()
        m = RE_PRESET.search(line)
        if m and "preset" not in r:
            r["preset"] = m.group(1).strip()
        m = RE_VSYNC.search(line)
        if m and "vsync" not in r:
            r["vsync"] = m.group(1)
        m = RE_DISPLAY.search(line)
        if m:
            r["displays"].append({"nom": m.group(1).strip(), "carte": m.group(2).strip(), "w": int(m.group(3)),
                                  "h": int(m.group(4)), "hz": int(m.group(5))})
            continue
        m = RE_CHAMP.search(line)
        if m:
            g = m.groups()
            r["champs"].append({"genre": g[0], "nom": g[1], "w": int(g[2]), "h": int(g[3]), "zoom": float(g[4]),
                                "tuiles": (float(g[5]), float(g[6])), "batiments": int(g[7]), "machines": int(g[8]),
                                "murs": int(g[9]), "tapis": int(g[10]), "bras": int(g[11]),
                                "familles": (int(g[12]), int(g[13]))})
            continue
        if "Program arguments:" in line:
            r["arguments"] = line.split("Program arguments:", 1)[1].strip()
        for ev in ("Atlases loaded from disk cache.", "Sprites loaded", "Factorio initialised", "Loading map",
                   "Quitting: automatic-quit", "Goodbye"):
            if ev in line and ev not in r["events"]:
                r["events"][ev] = t
        if "Initial atlas bitmap size" in line and "first_atlas" not in r["events"]:
            r["events"]["first_atlas"] = t
        m = RE_PERFORMED.search(line)
        if m:
            r["bench"]["updates"], r["bench"]["ms"] = int(m.group(1)), float(m.group(2))
        m = RE_UPD_AVG.search(line)
        if m:
            r["bench"]["avg"], r["bench"]["min"], r["bench"]["max"] = map(float, m.groups())
        m = RE_PERFSUM.search(line)
        if m:
            r["perf_summary"][m.group(1)] = dict(zip(("avg", "med", "min", "max"), map(float, m.groups()[1:])))
        m = RE_PHASE_START.search(line)
        if m:
            open_phase[m.group(1)] = {"name": m.group(1), "tick0": int(m.group(2)), "zoom": float(m.group(3)),
                                      "daytime": float(m.group(4)), "t0": t}
            continue
        m = RE_PHASE_END.search(line)
        if m:
            p = open_phase.pop(m.group(1), {"name": m.group(1)})
            p.update({"tick1": int(m.group(2)), "ticks": int(m.group(3)), "ms": float(m.group(4)), "t1": t})
            p["ups"] = p["ticks"] / (p["ms"] / 1000.0) if p["ms"] > 0 else None
            r["phases"].append(p)
    return r


def merge_stdout(r, text):
    """Les résumés du mode benchmark (« Performed », « avg: », « frame> avg: ») peuvent n'aller que sur stdout."""
    extra = parse_log(text)
    for k in ("bench", "perf_summary"):
        for kk, v in extra[k].items():
            r[k].setdefault(kk, v)


# ------------------------------------------------------------------------------------------------
# Estimation de la mémoire des atlas
# ------------------------------------------------------------------------------------------------
def dxt_kind(dxt):
    if not dxt:
        return "?"
    d = dxt.lower()
    if d in ("none", "disabled", "off", "false", "0"):
        return "none"
    if "high" in d:
        return "high"
    if "low" in d:
        return "low"
    return "?"


def bpp_range(flags, dxt):
    """Octets par pixel (bas, haut, règle) d'un atlas selon ses drapeaux et la compression du journal."""
    f = set(flags)
    comp = dxt_kind(dxt)
    if "not-compressed" in f:
        return 4.0, 4.0, "RGBA 8 bits (drapeau not-compressed)"
    if "alpha-mask" in f:
        if comp == "none":
            return 1.0, 4.0, "HYPOTHESE masque alpha sans compression : A8 (1) a RGBA (4)"
        if comp == "?":
            return 0.5, 4.0, "HYPOTHESE masque alpha, compression inconnue"
        return 0.5, 1.0, "HYPOTHESE masque alpha compresse : BC4 (0,5) a A8/BC3 (1)"
    if comp == "none":
        return 4.0, 4.0, "RGBA 8 bits (compression DXT desactivee)"
    if comp == "high":
        return 1.0, 1.0, "BC3 ou YCoCg-DXT5 : 16 octets par bloc 4x4"
    if comp == "low":
        return 0.5, 1.0, "HYPOTHESE DXT basse qualite : BC1 (0,5) a BC3 (1)"
    return 0.5, 4.0, "compression inconnue (ligne Graphics options absente)"


def geo(levels_beyond_base):
    return sum(0.25 ** i for i in range(levels_beyond_base + 1))


def mip_range(atlas):
    n = atlas.get("mips")
    if n is not None:
        return geo(max(0, n - 1)), geo(n)
    if "mipmap" in atlas["flags"]:
        return 1.0, 4.0 / 3.0
    return 1.0, 1.0


def category(flags):
    for flag, name in CATEGORIES:
        if flag in flags:
            return name
    return OBJETS


def estimate(r):
    """Ajoute à chaque atlas : pixels, octets bas/haut, catégorie ; renvoie les totaux."""
    tot = {"pixels": 0, "bas": 0.0, "haut": 0.0, "brut": 0.0, "brut_mips": 0.0}
    cats = {}
    for a in r["atlases"]:
        px = a["w"] * a["h"]
        b_lo, b_hi, rule = bpp_range(a["flags"], r.get("dxt"))
        m_lo, m_hi = mip_range(a)
        a.update({"pixels": px, "bas": px * b_lo * m_lo, "haut": px * b_hi * m_hi, "regle": rule,
                  "categorie": category(a["flags"]), "mip_facteur": (m_lo, m_hi)})
        tot["pixels"] += px
        tot["bas"] += a["bas"]
        tot["haut"] += a["haut"]
        tot["brut"] += 4.0 * px            # référence F66 : 4 octets par pixel, sans mipmaps
        tot["brut_mips"] += 4.0 * px * m_hi
        c = cats.setdefault(a["categorie"], {"n": 0, "pixels": 0, "bas": 0.0, "haut": 0.0})
        c["n"] += 1
        c["pixels"] += px
        c["bas"] += a["bas"]
        c["haut"] += a["haut"]
    # Atlas bitmap seuls (référence avant le comptage de l'atlas virtuel, et base de la variante non compressée).
    tot["atlas_bas"], tot["atlas_haut"] = tot["bas"], tot["haut"]
    virt = virtual_estimate(r)
    tot["pixels_virtuels"] = sum(v["pixels"] for v in virt)
    tot["virtuel_bas"] = sum(v["bas"] for v in virt)
    tot["virtuel_haut"] = sum(v["haut"] for v in virt)
    tot["virtuel_non_compresse"] = sum(v["non_compresse"] for v in virt)
    tot["bas"] += tot["virtuel_bas"]
    tot["haut"] += tot["virtuel_haut"]
    if virt:
        cats[VIRTUEL] = {"n": len(virt), "pixels": tot["pixels_virtuels"], "bas": tot["virtuel_bas"],
                         "haut": tot["virtuel_haut"]}
    r["totaux"], r["categories"], r["virtuels"] = tot, cats, virt
    return tot


VIRTUEL = "atlas virtuel (pages)"


def virtual_estimate(r):
    """Octets des pages d'atlas virtuel (règle « Atlas virtuel » en tête du fichier) : une entrée par ligne « Created
    virtual atlas pages LxHxN », appariée dans l'ordre à la ligne « Generated mipmaps for virtual atlas of size … »
    de même rang si elle existe. Les pixels comptés sont ceux des PAGES (prouvés par le journal) ; la surface de
    l'atlas virtuel annoncé n'intervient que dans la borne haute des mipmaps."""
    out = []
    mips = r.get("virtual_mips") or []
    for i, v in enumerate(r.get("virtual_atlases") or []):
        px = v["w"] * v["h"] * v["pages"]
        # HYPOTHÈSE de compression : celle d'un atlas « [none] » (sprites principaux) sous la DXT du journal.
        b_lo, b_hi, _ = bpp_range(["none"], r.get("dxt"))
        mip = mips[i] if i < len(mips) else None
        mip_px = max(px, mip["w"] * mip["h"]) / 3.0 if mip else 0.0
        out.append({"w": v["w"], "h": v["h"], "pages": v["pages"], "pixels": px, "bas": px * b_lo,
                    "haut": (px + mip_px) * b_hi, "octets_px": (b_lo, b_hi), "mip_px": mip_px,
                    "mip_taille": (mip["w"], mip["h"]) if mip else None,
                    "non_compresse": 4.0 * px,
                    "regle": "HYPOTHESE pages residentes en memoire video, compressees selon la DXT du journal "
                             "(%s) ; mipmaps au plus 1/3 de la plus grande surface" % (r.get("dxt") or "inconnue")})
    return out


def virtual_vs_measure(r):
    """Confronte la variante NON compressée des pages (RGBA 8888) et l'estimation comptée à la mesure directe.
    Renvoie None sans atlas virtuel ou sans mesure ; sinon un dict : plafond (pic dédié + pic partagé, ou dédié seul),
    plancher_nc (atlas bas + pages × 4 octets), nc_exclue (plancher_nc > plafond), bas_compatible (estimation basse
    comptée <= pic dédié). Les deux pics sont des maximums pris à des instants qui peuvent différer : leur somme est
    un plafond généreux, ce qui rend l'exclusion prudente."""
    t = r.get("totaux") or {}
    m = r.get("mesure") or {}
    d = m.get("dedie_o")
    if not t.get("pixels_virtuels") or not d:
        return None
    p = m.get("partage_o")
    plafond = d["max"] + (p["max"] if p else 0.0)
    plancher_nc = t["atlas_bas"] + t["virtuel_non_compresse"]
    return {"plafond": plafond, "avec_partage": bool(p), "plancher_nc": plancher_nc, "nc_exclue": plancher_nc > plafond,
            "pic_dedie": d["max"], "bas_compatible": t["bas"] <= d["max"]}


# ------------------------------------------------------------------------------------------------
# Mesure directe (vram.tsv écrit par visual_session.py)
# ------------------------------------------------------------------------------------------------
SAMPLE_COLUMNS = ["t_s", "dedie_o", "partage_o", "carte_dedie_o", "ram_privee_o", "ram_ws_o"]


def parse_samples(path):
    rows = []
    for line in read_text(path).splitlines():
        parts = line.strip().split("\t")
        if not parts or parts[0] in ("", "t_s"):
            continue
        try:
            vals = [float(p) if p not in ("", "-") else None for p in parts]
        except ValueError:
            continue
        rows.append(dict(zip(SAMPLE_COLUMNS, vals)))
    return rows


def stats(values):
    v = sorted(x for x in values if x is not None and not math.isnan(x))
    if not v:
        return None
    n = len(v)

    def pct(p):
        return v[min(n - 1, int(p * (n - 1) + 0.5))]

    return {"n": n, "moy": sum(v) / n, "min": v[0], "med": pct(0.5), "p95": pct(0.95), "p99": pct(0.99), "max": v[-1]}


def sample_summary(rows, phases):
    out = {"n": len(rows)}
    for col in ("dedie_o", "partage_o", "carte_dedie_o", "ram_privee_o", "ram_ws_o"):
        vals = [r[col] for r in rows if r.get(col) is not None]
        # Moyenne sur la partie chargée : après le premier échantillon non nul.
        out[col] = stats([x for x in vals if x > 0])
    by_phase = []
    for p in phases:
        if p.get("t0") is None or p.get("t1") is None:
            continue
        vals = [r["dedie_o"] for r in rows if r.get("dedie_o") and p["t0"] <= r["t_s"] <= p["t1"]]
        by_phase.append({"name": p["name"], "dedie": stats(vals)})
    out["phases"] = by_phase
    return out


# ------------------------------------------------------------------------------------------------
# Images par seconde : fichier --output-perf-stats (format NON prouvé : lecture tolérante)
# ------------------------------------------------------------------------------------------------
# Colonnes lues dans le binaire 1.1.91 (chaînes voisines de src\Benchmark\PerformanceLogger.cpp) ; leur SENS
# n'est pas documenté : seules les voies de calcul de frame_metrics, confrontées, font foi.
KNOWN_COLS = ("prepare", "texture-streaming-analysis", "texture-streaming-update", "cpu-render", "cpu-flip", "sleep",
              "cpu-frame", "sprite-count", "draw-call-count", "tiles-rendered", "vt-tiles-requested", "vt-tiles-added",
              "vt-tiles-reused", "vt-tiles-evicted", "vt-tiles-skipped", "gpu-terrain-render", "gpu-draw-engine-render",
              "gpu-frame", "sync-interval", "last-present-count", "present-count", "refresh-count",
              "sync-refresh-count", "frames-skipped")
TIME_COLS = ("prepare", "texture-streaming-analysis", "texture-streaming-update", "cpu-render", "cpu-flip", "sleep",
             "cpu-frame", "gpu-frame", "gpu-terrain-render", "gpu-draw-engine-render")
COUNTER_COLS = ("present-count", "refresh-count", "sync-refresh-count")
FRAME_60_MS = 1000.0 / 60


def _num(x):
    return x is not None and not (isinstance(x, float) and math.isnan(x))


def frame_metrics(sub, scale, phase_ms=None):
    """Images/s d'une suite de lignes du fichier, par plusieurs voies (aucune n'est prouvée seule) :
    fps_phase (lignes / durée réelle de la phase), fps_max (max(cpu-frame, gpu-frame)), fps_cpu (HYPOTHÈSE
    cpu-frame = durée totale de l'image), ratio_cpu (somme cpu-frame / durée de la phase : teste l'hypothèse),
    écarts des compteurs cumulés (present-count, refresh-count) par seconde, images sautées."""
    out = {"images": len(sub)}
    cpu = [r["cpu-frame"] * scale for r in sub if _num(r.get("cpu-frame"))]
    gpu_rows = [(r["cpu-frame"] * scale, r["gpu-frame"] * scale) for r in sub
                if _num(r.get("cpu-frame")) and _num(r.get("gpu-frame"))]
    if cpu and sum(cpu) > 0:
        out["fps_cpu"] = 1000.0 * len(cpu) / sum(cpu)
        out["cpu_moy_ms"] = sum(cpu) / len(cpu)
    if gpu_rows and any(g > 0 for _, g in gpu_rows):
        mx = [max(c, g) for c, g in gpu_rows]
        if sum(mx) > 0:
            out["fps_max"] = 1000.0 * len(mx) / sum(mx)
        out["lentes_max"] = sum(1 for x in mx if x > FRAME_60_MS + 0.5) / len(mx)
        out["gpu_moy_ms"] = sum(g for _, g in gpu_rows) / len(gpu_rows)
        out["gpu_limite"] = sum(1 for c, g in gpu_rows if g > c) / len(gpu_rows)
    elif cpu:
        out["lentes_cpu"] = sum(1 for x in cpu if x > FRAME_60_MS + 0.5) / len(cpu)
    if phase_ms and phase_ms > 0:
        out["phase_ms"] = phase_ms
        out["fps_phase"] = len(sub) / (phase_ms / 1000.0)
        if cpu:
            out["ratio_cpu"] = sum(cpu) / phase_ms
    for col in COUNTER_COLS:
        vals = [r[col] for r in sub if _num(r.get(col))]
        if len(vals) >= 2 and all(b >= a for a, b in zip(vals, vals[1:])) and vals[-1] > vals[0]:
            d = vals[-1] - vals[0]
            out[col + "_delta"] = d
            if phase_ms and phase_ms > 0:
                out[col + "_par_s"] = d / (phase_ms / 1000.0)
    skipped = [r["frames-skipped"] for r in sub if _num(r.get("frames-skipped"))]
    if skipped:
        out["sautees"] = sum(skipped)
    return out


def parse_perf_csv(path, phases=None):
    text = read_text(path)
    if not text:
        return {"erreur": "fichier absent ou vide : " + path}
    lines = text.splitlines()
    header, sep, hdr_i = None, ",", None
    for i, ln in enumerate(lines):
        for s in (",", ";", "\t"):
            cols = [c.strip().strip('"') for c in ln.split(s)]
            if sum(1 for c in cols if c in KNOWN_COLS) >= 3:
                header, sep, hdr_i = cols, s, i
                break
        if header:
            break
    if not header:
        return {"erreur": "en-tete introuvable (colonnes attendues : %s)" % ", ".join(KNOWN_COLS[:7]),
                "debut": lines[:5]}
    meta = {}
    for ln in lines[:hdr_i]:
        parts = [p.strip().strip('"') for p in re.split(r"[,;\t]", ln, maxsplit=1)]
        if len(parts) == 2 and parts[0]:
            meta[parts[0]] = parts[1]
    rows = []
    for ln in lines[hdr_i + 1:]:
        parts = ln.split(sep)
        if len(parts) < 3:
            continue
        try:
            vals = [float(p) if p.strip() else float("nan") for p in parts]
        except ValueError:
            continue
        rows.append(dict(zip(header, vals)))
    res = {"fichier": path, "colonnes": header, "meta": meta, "images": len(rows)}
    if not rows:
        res["erreur"] = "aucune ligne numerique"
        return res
    # Unité des temps : DEVINÉE par la médiane de cpu-frame (≈ 16,7 ms à 60 images/s) ; non prouvée.
    ref = stats([r.get("cpu-frame") for r in rows]) or stats([r.get("prepare") for r in rows])
    scale, unit = 1.0, "ms (devinee)"
    if ref and ref["med"] > 200000:
        scale, unit = 1e-6, "ns (devinee, convertie en ms)"
    elif ref and ref["med"] > 200:
        scale, unit = 1e-3, "us (devinee, convertie en ms)"
    res["unite"] = unit

    def col_stats(sub):
        out = {}
        for c in header:
            v = [r.get(c) for r in sub]
            if c in TIME_COLS:
                v = [x * scale for x in v if _num(x)]
            st = stats(v)
            if st:
                out[c] = st
        return out

    res["global"] = col_stats(rows)
    res["global_ips"] = frame_metrics(rows, scale)
    # Segmentation par les vues « repère » du scénario d4-geant (zone vide : très peu de sprites).
    if "sprite-count" in header and phases:
        sc = stats([r.get("sprite-count") for r in rows])
        thr = max(50.0, 0.05 * sc["p95"]) if sc else 50.0
        segs, cur = [], []
        for r in rows:
            if (r.get("sprite-count") or 0) <= thr:
                if len(cur) >= 30:
                    segs.append(cur)
                cur = []
            else:
                cur.append(r)
        if len(cur) >= 30:
            segs.append(cur)
        mesures = [p for p in phases if not p["name"].startswith("repere")]
        res["segmentation"] = {"seuil_sprites": thr, "segments": len(segs), "phases": len(mesures)}
        if len(segs) == len(mesures):
            res["par_phase"] = [{"name": p["name"], "stats": col_stats(sg), "ips": frame_metrics(sg, scale, p.get("ms"))}
                                for p, sg in zip(mesures, segs)]
    return res


def ips_text(m, hz=None):
    """Une ligne lisible des voies de calcul d'images/s (frame_metrics)."""
    parts = []
    if m.get("fps_phase") is not None:
        parts.append("phase %.1f (%d images / %.1f s)" % (m["fps_phase"], m["images"], m["phase_ms"] / 1000.0))
    if m.get("fps_max") is not None:
        parts.append("max(cpu,gpu) %.1f" % m["fps_max"])
    if m.get("fps_cpu") is not None:
        parts.append("cpu-frame %.1f (HYPOTHESE)" % m["fps_cpu"])
    if m.get("ratio_cpu") is not None:
        parts.append("somme cpu-frame / duree %.2f (1 si cpu-frame couvre toute l'image)" % m["ratio_cpu"])
    for col in COUNTER_COLS:
        if col + "_par_s" in m:
            parts.append("%s %.1f/s" % (col, m[col + "_par_s"]))
        elif col + "_delta" in m:
            parts.append("%s +%d" % (col, m[col + "_delta"]))
    if hz and m.get("refresh-count_par_s") is not None:
        parts.append("ecran %d Hz" % hz)
    if m.get("gpu_limite") is not None:
        parts.append("gpu-frame > cpu-frame sur %.0f %% des images" % (100 * m["gpu_limite"]))
    lent = m.get("lentes_max", m.get("lentes_cpu"))
    if lent is not None:
        parts.append("images > 16,7 ms : %.1f %%" % (100 * lent))
    if m.get("sautees"):
        parts.append("sautees %d" % m["sautees"])
    return " ; ".join(parts) or "aucune colonne exploitable"


def phase_note(name):
    """Repères d4-geant : zone vide, la simulation de l'usine tourne, presque rien n'est dessiné."""
    if name == "repere-debut":
        return " (zone vide ; contient les controles du tick 120 : ne pas s'en servir)"
    if name.startswith("repere"):
        return " (zone vide : cout de la SIMULATION seule)"
    return ""


def refresh_hz(r):
    """Fréquence de l'écran (journal : « Available displays … NNHz ») ; la plus haute s'il y en a plusieurs."""
    return max((d["hz"] for d in r.get("displays") or []), default=None)


def vsync_text(r):
    hz = refresh_hz(r)
    v = r.get("vsync")
    if v == "1":
        return ("VSync ACTIF, ecran %s Hz : images/s plafonnees a %s par l'ecran (un plafond a 60 impose par le jeu "
                "lui-meme n'est pas prouve)" % (hz or "?", hz or "la frequence de l'ecran"))
    if v == "0":
        return "VSync coupe, ecran %s Hz : pas de plafond par l'ecran" % (hz or "?")
    return "VSync inconnu (journal), ecran %s Hz" % (hz or "?")


# ------------------------------------------------------------------------------------------------
# Compteurs GPU de Windows (PDH, noms ANGLAIS : indépendants de la langue du système)
# ------------------------------------------------------------------------------------------------
class _PdhU(ctypes.Union):
    _fields_ = [("longValue", ctypes.c_long), ("doubleValue", ctypes.c_double), ("largeValue", ctypes.c_longlong),
                ("AnsiStringValue", ctypes.c_char_p), ("WideStringValue", ctypes.c_wchar_p)]


class _PdhValue(ctypes.Structure):
    _fields_ = [("CStatus", ctypes.c_ulong), ("u", _PdhU)]


class _PdhItem(ctypes.Structure):
    _fields_ = [("szName", ctypes.c_wchar_p), ("FmtValue", _PdhValue)]


class _MemCounters(ctypes.Structure):
    _fields_ = [("cb", ctypes.c_ulong), ("PageFaultCount", ctypes.c_ulong), ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t), ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t), ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t), ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t), ("PrivateUsage", ctypes.c_size_t)]


PDH_FMT_LARGE = 0x00000400
COUNTERS = {
    "dedie": r"\GPU Process Memory(*)\Dedicated Usage",
    "partage": r"\GPU Process Memory(*)\Shared Usage",
    "carte": r"\GPU Adapter Memory(*)\Dedicated Usage",
}


class GpuSampler:
    """Mémoire vidéo d'UN processus (son PID) par les compteurs « GPU Process Memory » de Windows.

    Lecture seule : aucune action sur aucun processus. Les instances s'appellent pid_<PID>_luid_..._phys_N ;
    on additionne celles du PID (une par carte). Si le PID n'apparaît pas encore (le jeu n'a pas créé son
    périphérique Direct3D), la requête est rouverte au plus toutes les 2 s (les instances d'un compteur à
    joker peuvent être figées à l'ouverture). « carte » : occupation de TOUTE la carte (tous programmes).
    """

    def __init__(self, pid):
        self.pid = pid
        self.prefix = "pid_%d_" % pid
        self.error = None
        self.query = None
        self.handles = {}
        self.last_open = 0.0
        self.seen = False
        try:
            self.pdh = ctypes.WinDLL("pdh")
            p = self.pdh
            H = ctypes.c_void_p
            p.PdhOpenQueryW.argtypes = [ctypes.c_wchar_p, ctypes.c_size_t, ctypes.POINTER(H)]
            p.PdhAddEnglishCounterW.argtypes = [H, ctypes.c_wchar_p, ctypes.c_size_t, ctypes.POINTER(H)]
            p.PdhCollectQueryData.argtypes = [H]
            p.PdhCloseQuery.argtypes = [H]
            p.PdhGetFormattedCounterArrayW.argtypes = [H, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong),
                                                       ctypes.POINTER(ctypes.c_ulong), ctypes.c_void_p]
            for fn in (p.PdhOpenQueryW, p.PdhAddEnglishCounterW, p.PdhCollectQueryData, p.PdhCloseQuery,
                       p.PdhGetFormattedCounterArrayW):
                fn.restype = ctypes.c_ulong
            self._open()
        except (OSError, AttributeError) as exc:
            self.error = "PDH indisponible : %s" % exc

    def _open(self):
        self.close()
        self.last_open = time.time()
        q = ctypes.c_void_p()
        rc = self.pdh.PdhOpenQueryW(None, 0, ctypes.byref(q))
        if rc:
            self.error = "PdhOpenQuery 0x%08x" % rc
            return
        self.query = q
        for key, path in COUNTERS.items():
            h = ctypes.c_void_p()
            rc = self.pdh.PdhAddEnglishCounterW(q, path, 0, ctypes.byref(h))
            if rc:
                self.error = "PdhAddEnglishCounter %s 0x%08x" % (path, rc)
                continue
            self.handles[key] = h
        self.pdh.PdhCollectQueryData(q)

    def _array(self, h):
        size, count = ctypes.c_ulong(0), ctypes.c_ulong(0)
        self.pdh.PdhGetFormattedCounterArrayW(h, PDH_FMT_LARGE, ctypes.byref(size), ctypes.byref(count), None)
        if not size.value:
            return []
        buf = (ctypes.c_byte * size.value)()
        rc = self.pdh.PdhGetFormattedCounterArrayW(h, PDH_FMT_LARGE, ctypes.byref(size), ctypes.byref(count), buf)
        if rc:
            return []
        items = ctypes.cast(buf, ctypes.POINTER(_PdhItem))
        return [(items[i].szName or "", items[i].FmtValue.u.largeValue, items[i].FmtValue.CStatus)
                for i in range(count.value)]

    def sample(self):
        """{dedie, partage, carte} en octets (None si le PID n'a pas encore d'instance), ou None si PDH manque."""
        if self.query is None:
            return None
        if self.pdh.PdhCollectQueryData(self.query):
            return None
        out = {"dedie": None, "partage": None, "carte": None}
        for key in ("dedie", "partage"):
            h = self.handles.get(key)
            if h is None:
                continue
            vals = [v for name, v, st in self._array(h) if name.startswith(self.prefix) and st in (0, 1)]
            if vals:
                out[key] = sum(vals)
        h = self.handles.get("carte")
        if h is not None:
            vals = [v for _, v, st in self._array(h) if st in (0, 1)]
            out["carte"] = max(vals) if vals else None
        if out["dedie"] is None and not self.seen and time.time() - self.last_open > 2:
            self._open()
        elif out["dedie"] is not None:
            self.seen = True
        return out

    def close(self):
        if self.query is not None:
            try:
                self.pdh.PdhCloseQuery(self.query)
            except OSError:
                pass
        self.query, self.handles = None, {}


def process_memory(handle):
    """Mémoire vive d'un processus (poignée de subprocess.Popen) : privée, pic privé, ensemble de travail, pic."""
    try:
        k32 = ctypes.WinDLL("kernel32")
        fn = k32.K32GetProcessMemoryInfo
        fn.argtypes = [ctypes.c_void_p, ctypes.POINTER(_MemCounters), ctypes.c_ulong]
        fn.restype = ctypes.c_int
        mc = _MemCounters()
        mc.cb = ctypes.sizeof(mc)
        if not fn(ctypes.c_void_p(int(handle)), ctypes.byref(mc), mc.cb):
            return None
        return {"privee": mc.PrivateUsage, "pic_privee": mc.PeakPagefileUsage, "ws": mc.WorkingSetSize,
                "pic_ws": mc.PeakWorkingSetSize}
    except (OSError, AttributeError, ValueError):
        return None


# ------------------------------------------------------------------------------------------------
# Rapport
# ------------------------------------------------------------------------------------------------
def go(x):
    return "%.2f Go" % (x / GO)


def fmt_range(lo, hi):
    a, b = "%.2f" % (lo / GO), "%.2f" % (hi / GO)
    return a + " Go" if a == b else "%s a %s Go" % (a, b)


def find_inputs(path):
    """Journal, échantillons, statistiques de rendu et stdout à partir d'un fichier ou d'un dossier."""
    found = {"log": None, "samples": None, "perf": None, "stdout": None}
    if os.path.isfile(path):
        found["log"] = path
        base = os.path.dirname(os.path.abspath(path))
    else:
        base = os.path.abspath(path)
    dirs = [base, os.path.join(base, "fo-shots"), os.path.join(base, "write"),
            os.path.join(base, "write", "script-output", "fo-shots"), os.path.dirname(base)]
    names = {"log": ("factorio.log", "visual.log", "factorio-current.log"), "samples": ("vram.tsv",),
             "perf": ("perf-stats.csv",), "stdout": ("stdout.txt", "visual-stdout.txt")}
    for key, cands in names.items():
        if found[key]:
            continue
        for d in dirs:
            hit = next((os.path.join(d, n) for n in cands if os.path.isfile(os.path.join(d, n))), None)
            if hit:
                found[key] = hit
                break
    return found


def analyse(log_path, samples_path=None, perf_path=None, stdout_path=None):
    r = parse_log(read_text(log_path)) if log_path else parse_log("")
    r["fichiers"] = {"journal": log_path, "echantillons": samples_path, "perf": perf_path, "stdout": stdout_path}
    if stdout_path:
        merge_stdout(r, read_text(stdout_path))
    estimate(r)
    if samples_path:
        r["mesure"] = sample_summary(parse_samples(samples_path), r["phases"])
    if perf_path:
        r["perf"] = parse_perf_csv(perf_path, r["phases"])
    return r


def report_lines(r, seuil_go=6.0):
    L = []
    f = r.get("fichiers", {})
    L.append("== Memoire video d'une session avec images (vram.py, lot D4m)")
    L.append("journal : %s" % (f.get("journal") or "absent"))
    L.append("")
    L.append("-- Reglages lus dans le journal")
    L.append("carte : %s ; memoire dediee declaree %s Mio ; preset %s ; VSync %s ; ecran %s" % (
        r.get("adapter", "?"), r.get("dedicated_mib", "?"), r.get("preset", "?"), r.get("vsync", "?"),
        ", ".join("%dx%d %d Hz" % (d["w"], d["h"], d["hz"]) for d in r.get("displays") or []) or "?"))
    L.append("qualite des sprites : %s ; usage de la memoire video : %s ; compression DXT : %s ; "
             "taille max de texture : %s ; flux de textures : %s" % (
                 r.get("quality", "?"), r.get("video_memory_usage", "?"), r.get("dxt", "?"),
                 r.get("max_texture", "?"), r.get("tex_stream", "?")))
    for name, b in sorted(r["budgets"].items()):
        L.append("[%s] budget Windows %.2f Go (%d Mio) ; CurrentUsage %d Mio lu AVANT le chargement "
                 "(ce n'est pas l'occupation du jeu)" % (name, b["budget_mib"] * MIB / GO, b["budget_mib"],
                                                        b["current_mib"]))
    L.append("")
    L.append("-- Atlas de sprites (%d) : estimation, regle par drapeau en tete de vram.py" % len(r["atlases"]))
    for v in r.get("virtuels") or []:
        L.append("  atlas VIRTUEL : %d page(s) de %dx%d (%.1f Mpx) ; COMPTE dans l'estimation : %s (%.1f-%.1f octets/px%s ; "
                 "%s)" % (v["pages"], v["w"], v["h"], v["pixels"] / 1e6, fmt_range(v["bas"], v["haut"]),
                          v["octets_px"][0], v["octets_px"][1],
                          (" ; mipmaps de l'atlas virtuel %dx%d : au plus %.1f Mpx en plus" % (
                              v["mip_taille"][0], v["mip_taille"][1], v["mip_px"] / 1e6)) if v["mip_taille"] else
                          " ; aucune ligne de mipmaps", v["regle"]))
        L.append("    variante NON compressee (RGBA 8888, format affirme par le binaire pour une page) : %s sans mipmaps ; "
                 "NON comptee, confrontee a la mesure directe plus bas (RD_LOG F81)" % go(v["non_compresse"]))
    if r.get("virtual_page_lines"):
        L.append("  ATTENTION %d ligne(s) « Created virtual atlas page LxH [...] » (singulier) : format jamais etalonne, "
                 "NON comptees" % r["virtual_page_lines"])
    em = r.get("engine_atlas_mb")
    if em:
        L.append("  chiffre du MOTEUR « Atlas memory size » : atlas %.2f MB, virtuel %.2f MB (%s et %s si MB = 2^20 "
                 "octets ; sens non documente)" % (em["atlas"], em["virtuel"], go(em["atlas"] * MIB),
                                                   go(em["virtuel"] * MIB)))
    if r.get("engine_outside_mb") is not None:
        L.append("  chiffre du MOTEUR « Size of sprites outside of atlas » : %.2f MB (%s si MB = 2^20 octets)" % (
            r["engine_outside_mb"], go(r["engine_outside_mb"] * MIB)))
    if r["atlases"]:
        L.append("  #  taille        Mpx   mips  octets/px   estimation       categorie / drapeaux")
        for a in r["atlases"]:
            lo, hi, _ = bpp_range(a["flags"], r.get("dxt"))
            L.append("%3d  %5dx%-5d %6.1f  %4s  %4.1f-%-4.1f  %-15s  %s / %s" % (
                a["index"], a["w"], a["h"], a["pixels"] / 1e6, a["mips"] if a["mips"] is not None else "-",
                lo, hi, fmt_range(a["bas"], a["haut"]), a["categorie"], ", ".join(a["flags"]) or "-"))
        L.append("")
        L.append("  par categorie :")
        for name, c in sorted(r["categories"].items(), key=lambda kv: -kv[1]["haut"]):
            L.append("    %-28s %2d atlas  %7.1f Mpx  %s" % (name, c["n"], c["pixels"] / 1e6, fmt_range(c["bas"], c["haut"])))
        t = r["totaux"]
        if t.get("pixels_virtuels"):
            # Atlas virtuel compté : le total le dit, avec la part des atlas bitmap seuls (ancienne estimation).
            L.append("  TOTAL : %.3f milliard de pixels d'atlas + %.3f de pages d'atlas virtuel ; estimation %s (atlas %s, "
                     "atlas virtuel %s) ; atlas sans compression %s (4 octets/px, sans mipmaps : reference F66) ou %s "
                     "avec mipmaps" % (t["pixels"] / 1e9, t["pixels_virtuels"] / 1e9, fmt_range(t["bas"], t["haut"]),
                                       fmt_range(t["atlas_bas"], t["atlas_haut"]),
                                       fmt_range(t["virtuel_bas"], t["virtuel_haut"]), go(t["brut"]),
                                       go(t["brut_mips"])))
        else:
            L.append("  TOTAL : %.3f milliard de pixels ; estimation %s ; sans compression %s (4 octets/px, "
                     "sans mipmaps : reference F66) ou %s avec mipmaps" % (
                         t["pixels"] / 1e9, fmt_range(t["bas"], t["haut"]), go(t["brut"]), go(t["brut_mips"])))
        q = (r.get("quality") or "?").lower()
        verdict = "TENU" if t["haut"] <= seuil_go * GO else "DEPASSE"
        L.append("  D4-1 (atlas <= %.0f Go en haute qualite) : %s par l'estimation haute (%s)%s" % (
            seuil_go, verdict, go(t["haut"]),
            "" if q == "high" else " ; ATTENTION qualite %s : le seuil vise la haute qualite" % q))
    else:
        L.append("  aucun atlas dans le journal (session sans images, ou journal tronque)")
    L.append("")
    ev = r["events"]
    L.append("-- Chargement (D4-3)")
    if ev:
        cache = "lus depuis le cache disque" if "Atlases loaded from disk cache." in ev else "REFAITS (pas de cache, ou sprites changes)"
        L.append("atlas %s ; sprites charges a %s s ; jeu initialise a %s s ; carte chargee a %s s" % (
            cache, ev.get("Sprites loaded", "?"), ev.get("Factorio initialised", "?"), ev.get("Loading map", "?")))
        L.append("(D4-3 se juge par DIFFERENCE entre deux sessions de meme cache : avant et apres le lot de sprites)")
    else:
        L.append("aucun repere de chargement dans le journal")
    L.append("")
    L.append("-- Mesure directe (compteurs GPU de Windows, seul PID de la session de test)")
    m = r.get("mesure")
    if not m:
        L.append("non mesuree : pas de vram.tsv (session anterieure au lot D4m, ou compteurs indisponibles)")
    else:
        d = m.get("dedie_o")
        if d:
            L.append("memoire video DEDIEE du jeu : pic %s, moyenne %s, mediane %s (%d echantillons non nuls sur %d)" % (
                go(d["max"]), go(d["moy"]), go(d["med"]), d["n"], m["n"]))
        else:
            L.append("memoire video dediee : aucun echantillon non nul (%d echantillons)" % m["n"])
        for col, lab in (("partage_o", "memoire partagee (RAM vue par la carte)"),
                         ("carte_dedie_o", "occupation de TOUTE la carte (tous programmes)"),
                         ("ram_privee_o", "memoire vive privee du jeu"), ("ram_ws_o", "ensemble de travail du jeu")):
            s = m.get(col)
            if s:
                L.append("%s : pic %s, moyenne %s" % (lab, go(s["max"]), go(s["moy"])))
        for p in m.get("phases", []):
            if p["dedie"]:
                L.append("  phase %-12s : memoire dediee moyenne %s, pic %s" % (p["name"], go(p["dedie"]["moy"]), go(p["dedie"]["max"])))
        if d and r["atlases"]:
            ecart = d["max"] - r["totaux"]["haut"]
            L.append("ecart mesure - estimation haute des atlas : %+.2f Go (%s)" % (
                ecart / GO, "rendus intermediaires, tampons, sprites hors atlas..." if ecart >= 0 else
                "NEGATIF : l'estimation haute depasse toute la memoire dediee mesuree, elle surestime cette session"))
        vm = virtual_vs_measure(r)
        if vm:
            L.append("atlas virtuel et mesure : estimation basse comptee %s %s le pic dedie %s%s" % (
                go(r["totaux"]["bas"]), "<=" if vm["bas_compatible"] else "> (INCOMPATIBLE)", go(vm["pic_dedie"]),
                "" if vm["bas_compatible"] else " : les pages ne sont pas toutes residentes, ou la regle est fausse"))
            L.append("  variante NON compressee : atlas (bas) + pages x 4 octets = %s %s %s (pic dedie%s) : %s" % (
                go(vm["plancher_nc"]), ">" if vm["nc_exclue"] else "<=", go(vm["plafond"]),
                " + pic partage" if vm["avec_partage"] else "",
                "EXCLUE par la mesure, si les pages sont allouees en entier" if vm["nc_exclue"] else
                "NON exclue par la mesure"))
    L.append("")
    L.append("-- Champ reel des vues d4-geant (ce qui est dessine : lignes CHAMP du greffon)")
    if r.get("champs"):
        for c in r["champs"]:
            L.append("  %-9s %-22s %4dx%-4d zoom %.2f : %4.0f x %3.0f tuiles, %5d batiments a niveaux (machines %5d, "
                     "murs %4d), tapis %5d, bras %5d, familles %d/%d" % (
                         c["genre"], c["nom"], c["w"], c["h"], c["zoom"], c["tuiles"][0], c["tuiles"][1], c["batiments"],
                         c["machines"], c["murs"], c["tapis"], c["bras"], c["familles"][0], c["familles"][1]))
        small = [c for c in r["champs"] if c["genre"] == "vue" and c["w"] * c["h"] < 1280 * 720]
        if small:
            L.append("  ATTENTION vue(s) mesuree(s) dans une fenetre de moins de 1280x720 (%s) : images/s et memoire "
                     "video ne representent PAS l'usine geante (fenetre reduite ?)" % ", ".join(
                         "%s %dx%d" % (c["nom"], c["w"], c["h"]) for c in small))
    else:
        L.append("  aucune ligne CHAMP (autre scenario, ou greffon anterieur a la correction du lot D4m)")
    L.append("")
    hz = refresh_hz(r)
    L.append("-- Images par seconde (D4-5 : 60 visees)")
    L.append(vsync_text(r))
    if r["phases"]:
        L.append("phases du scenario d4-geant (UPS = ticks / duree mesuree par LuaProfiler ; ce n'est PAS le "
                 "nombre d'images dessinees) :")
        for p in r["phases"]:
            L.append("  %-12s zoom %-4s %s : %5d ticks en %8.1f ms -> %5.1f UPS%s" % (
                p["name"], p.get("zoom", "?"), "nuit" if abs(p.get("daytime", 0) - 0.5) < 0.2 else "jour",
                p["ticks"], p["ms"], p["ups"] or 0, phase_note(p["name"])))
    b = r["bench"]
    if b:
        L.append("resume \"Performed / avg\" (ecrit par le mode benchmark SANS images ; en --benchmark-graphics : NON "
                 "prouve) : %s mises a jour en %s ms ; par mise a jour moy %s ms, min %s, max %s" % (
                     b.get("updates", "?"), b.get("ms", "?"), b.get("avg", "?"), b.get("min", "?"), b.get("max", "?")))
    ps = r["perf_summary"]
    if ps:
        L.append("resume \"prepare/render/frame> avg\" (PerformanceLogger ; ecriture et sens NON prouves) :")
        for k in ("prepare", "streaming", "render", "flip", "frame"):
            if k in ps:
                s = ps[k]
                L.append("  %-9s moy %.3f ms, med %.3f, min %.3f, max %.3f" % (k, s["avg"], s["med"], s["min"], s["max"]))
        if "frame" in ps and ps["frame"]["avg"] > 0:
            L.append("  1000 / moyenne de frame : %.1f (HYPOTHESE : frame = duree totale de l'image)" % (
                1000.0 / ps["frame"]["avg"]))
    pf = r.get("perf")
    if pf:
        if pf.get("erreur"):
            L.append("statistiques de rendu (%s) : %s" % (pf.get("fichier", "?"), pf["erreur"]))
        else:
            g = pf["global"]
            L.append("statistiques de rendu : %d lignes, unite %s, colonnes %s" % (
                pf["images"], pf["unite"], ", ".join(pf["colonnes"])))
            L.append("  ensemble : " + ips_text(pf.get("global_ips") or {}, hz))
            for c in ("cpu-frame", "gpu-frame", "sleep", "cpu-flip", "prepare", "cpu-render", "sprite-count",
                      "draw-call-count"):
                if c in g:
                    s = g[c]
                    L.append("  %-16s moy %10.3f  med %10.3f  p95 %10.3f  p99 %10.3f  max %10.3f" % (
                        c, s["moy"], s["med"], s["p95"], s["p99"], s["max"]))
            seg = pf.get("segmentation")
            if seg:
                L.append("  segmentation par les vues repere : %d segments pour %d phases (seuil %d sprites)%s" % (
                    seg["segments"], seg["phases"], seg["seuil_sprites"],
                    "" if pf.get("par_phase") else " : NON appariee, chiffres par phase indisponibles"))
            tiles = {}
            for p in pf.get("par_phase", []):
                s = p["stats"]
                L.append("  phase %-12s : %s%s%s" % (
                    p["name"], ips_text(p.get("ips") or {}, hz),
                    (" ; sprites moy %d" % s["sprite-count"]["moy"]) if "sprite-count" in s else "",
                    (" ; tuiles moy %d" % s["tiles-rendered"]["moy"]) if "tiles-rendered" in s else ""))
                if "tiles-rendered" in s:
                    tiles[p["name"]] = s["tiles-rendered"]["moy"]
            # Le zoom écrit par le greffon (LuaPlayer.zoom, en écriture seule) est-il appliqué ? La surface vue
            # varie comme 1/zoom² : 0,3 contre 0,5 donne (0,5/0,3)² = 2,78 fois plus de tuiles.
            if tiles.get("z030-jour") and tiles.get("z050-jour"):
                L.append("  controle du zoom : tuiles z030/z050 = %.2f (attendu 2,78 si le zoom 0,3 est applique)" % (
                    tiles["z030-jour"] / tiles["z050-jour"]))
            L.append("  (voies : \"phase\" suppose une ligne par image ; \"max(cpu,gpu)\" borne la duree de l'image ; "
                     "\"cpu-frame\" est une HYPOTHESE, sur-estimee si l'image attend le GPU ; elles doivent concorder)")
    if not (r["phases"] or b or ps or pf):
        L.append("aucune source : ni phases d4-geant, ni resume benchmark, ni statistiques de rendu")
    return L


def sonde():
    """Essai des compteurs sans rien lancer : instances vues, et l'occupation de toute la carte."""
    s = GpuSampler(os.getpid())
    if s.error and s.query is None:
        print("compteurs GPU indisponibles : " + s.error)
        return 1
    if s.query is None:
        print("compteurs GPU : requete non ouverte")
        return 1
    s.pdh.PdhCollectQueryData(s.query)
    for key in ("dedie", "partage", "carte"):
        h = s.handles.get(key)
        arr = s._array(h) if h is not None else []
        top = max((v for _, v, _ in arr), default=0)
        print("%-8s %-42s instances %3d, plus grande %s" % (key, COUNTERS[key], len(arr), go(top)))
    s.close()
    print("compteurs GPU de Windows lisibles (noms anglais, PDH)" + ("" if not s.error else " ; remarque : " + s.error))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("entree", nargs="?", help="journal de session, ou dossier (fo-shots, archive fo-logs, fo-visual)")
    ap.add_argument("--samples", help="vram.tsv (mesure directe du pilote)")
    ap.add_argument("--perf", help="perf-stats.csv (option --output-perf-stats du jeu)")
    ap.add_argument("--stdout", help="sortie standard du jeu (resumes du mode benchmark)")
    ap.add_argument("--seuil-go", type=float, default=6.0, help="seuil D4-1 en Go (defaut 6)")
    ap.add_argument("--json", help="ecrit aussi le rapport complet en JSON")
    ap.add_argument("--sonde", action="store_true", help="essai des compteurs GPU de Windows, sans rien lancer")
    a = ap.parse_args()
    if a.sonde:
        return sonde()
    if not a.entree:
        ap.error("donner un journal ou un dossier (ou --sonde)")
    found = find_inputs(a.entree)
    log = found["log"]
    if not log:
        print("aucun journal trouve dans " + a.entree)
        return 1
    r = analyse(log, a.samples or found["samples"], a.perf or found["perf"], a.stdout or found["stdout"])
    print("\n".join(report_lines(r, a.seuil_go)))
    if a.json:
        with open(a.json, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(r, fh, ensure_ascii=False, indent=1, default=str)
    return 0


if __name__ == "__main__":
    sys.exit(main())
