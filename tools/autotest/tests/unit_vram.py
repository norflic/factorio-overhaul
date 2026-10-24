"""Contrôles unitaires HORS JEU de vram.py et de memory_summary (visual_session.py), lot D4m.

Usage : python -B unit_vram.py <dossier tools/autotest> <dossier des fixtures>
Les fixtures : factorio.log (journal de d4_dryrun.lua), vram.tsv et perf-stats.csv (make_fixtures.py).
N'éprouve que l'arithmétique et la lecture des formats SUPPOSÉS ; rien n'est prouvé du moteur réel.
"""
import os
import sys
import types

sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import vram  # noqa: E402
import visual_session as vs  # noqa: E402

ok = fail = 0


def check(cond, what):
    global ok, fail
    if cond:
        ok += 1
    else:
        fail += 1
        print("ECHEC", what)


def near(a, b, tol=0.05):
    return a is not None and b is not None and abs(a - b) <= tol * max(1.0, abs(b))


# Règles d'octets par pixel (en-tête de vram.py) : les hypothèses sont étiquetées.
check(vram.bpp_range(["none"], "high-quality")[:2] == (1.0, 1.0), "DXT haute : 1 o/px")
check(vram.bpp_range(["none"], "low-quality")[:2] == (0.5, 1.0), "DXT basse : 0,5-1")
check("HYPOTHESE" in vram.bpp_range(["none"], "low-quality")[2], "DXT basse etiquetee HYPOTHESE")
check(vram.bpp_range(["none"], "none")[:2] == (4.0, 4.0), "sans DXT : 4")
check(vram.bpp_range(["icon", "not-compressed"], "high-quality")[:2] == (4.0, 4.0), "not-compressed : 4")
check(vram.bpp_range(["shadow", "alpha-mask"], "high-quality")[:2] == (0.5, 1.0), "masque compresse")
check("HYPOTHESE" in vram.bpp_range(["shadow", "alpha-mask"], "high-quality")[2], "masque alpha etiquete HYPOTHESE")
check(vram.bpp_range(["shadow", "alpha-mask"], "none")[:2] == (1.0, 4.0), "masque sans DXT")
check(vram.bpp_range(["none"], None)[:2] == (0.5, 4.0), "compression inconnue")
check(abs(vram.mip_range({"mips": 3, "flags": []})[1] - (1 + 1 / 4 + 1 / 16 + 1 / 64)) < 1e-12, "mips haut")
check(abs(vram.mip_range({"mips": 3, "flags": []})[0] - (1 + 1 / 4 + 1 / 16)) < 1e-12, "mips bas")
check(vram.mip_range({"mips": None, "flags": ["mipmap"]}) == (1.0, 4 / 3), "mipmap sans ligne")
check(vram.category(["shadow", "mipmap", "alpha-mask"]) == "ombres", "categorie ombres")
check(vram.category(["none"]) == vram.OBJETS, "categorie objets")

LOG = r"""   0.114 Display options: [FullScreen: 0] [VSync: 1] [UIScale: automatic (100.0%)] [Native DPI: 1] [Screen: 255]
   0.337  [0]: \\.\DISPLAY25 - AMD Radeon RX 6900 XT {0x80005, [0,0], 3840x2160, 32bit, 144Hz}
   0.300 Graphics options: [Graphics quality: normal] [Video memory usage: high] [DXT: low-quality] [Color: 32bit]
   0.301                   [Max threads (load/render): 32/16] [Max texture size: 0] [Tex.Stream.: 0] [Rotation quality: normal]
   1.000 Created atlas bitmap 8192x4096 [none]
   1.001 Created atlas bitmap 4096x4096 [terrain, mipmap]
   2.000 Generated mipmaps (3) for atlas [1] of size 4096x4096
   2.100 Generated mipmaps (2) for atlas [0] of size 1024x1024
   3.000 Sprites loaded
   3.500 Factorio initialised
  Performed 3000 updates in 50123.456 ms
  avg: 16.708 ms, min: 0.512 ms, max: 120.000 ms
  frame> avg: 18.500 ms, med: 16.700 ms, min: 10.000 ms, max: 90.000 ms
  prepare> avg: 9.000 ms, med: 8.000 ms, min: 2.000 ms, max: 50.000 ms
  11.000 Script @__fo-autotest__/scenarios/d4-geant.lua:1: [FO-D4-GEANT] CHAMP vue z030-jour 158x26 zoom 0.30 : 8 x 1 tuiles, batiments a niveaux 9 (machines 9, murs 0), tapis 8, bras 4 ; familles 2/7 : command 0 (0/15 niv.)
  12.000 Script @__fo-autotest__/scenarios/d4-geant.lua:120: [FO-D4-GEANT] PHASE fin z030-jour tick 780 ticks 600 Durée : 12000.5ms
"""
r = vram.parse_log(LOG)
check(r["quality"] == "normal" and r["video_memory_usage"] == "high" and r["dxt"] == "low-quality", "reglages")
check(r["tex_stream"] == "0" and r["max_texture"] == "0", "flux et taille max")
check(r["vsync"] == "1" and vram.refresh_hz(r) == 144, "VSync et frequence de l'ecran")
check("144" in vram.vsync_text(r) and "ACTIF" in vram.vsync_text(r), "texte VSync : plafond a 144")
check(r["atlases"][1]["mips"] == 3 and r["atlases"][0]["mips"] is None and r["atlases"][0].get("mips_mismatch") == "1024x1024",
      "mipmaps par indice, taille verifiee")
check(r["bench"]["updates"] == 3000 and abs(r["bench"]["avg"] - 16.708) < 1e-9, "resume benchmark")
check(abs(r["perf_summary"]["frame"]["avg"] - 18.5) < 1e-9, "resume du rendu")
check(len(r["phases"]) == 1 and abs(r["phases"][0]["ups"] - 600 / 12.0005) < 1e-6, "phase en francais (Duree)")
check(len(r["champs"]) == 1 and r["champs"][0]["batiments"] == 9 and r["champs"][0]["w"] == 158, "ligne CHAMP lue")
t = vram.estimate(r)
check(abs(t["bas"] - (8192 * 4096 * 0.5 + 4096 * 4096 * 0.5 * (1 + 0.25 + 1 / 16))) < 1, "estimation basse")
lines = vram.report_lines(r)
check(any("ATTENTION qualite normal" in ln for ln in lines), "seuil D4-1 signale hors haute qualite")
check(any("1000 / moyenne de frame : 54.1 (HYPOTHESE" in ln for ln in lines), "resume du rendu : HYPOTHESE ecrite")
check(any("NON prouve" in ln and "Performed" in ln for ln in lines), "resume Performed : non prouve en images")
check(any("moins de 1280x720" in ln for ln in lines), "vue mesuree en fenetre reduite signalee")

# Voies d'images/s sur des lignes simples (unité ms) : GPU limitant.
rows = [{"cpu-frame": 10.0, "gpu-frame": 20.0, "present-count": float(i), "refresh-count": 2.4 * i} for i in range(100)]
mm = vram.frame_metrics(rows, 1.0, phase_ms=2000.0)
check(near(mm["fps_cpu"], 100.0) and near(mm["fps_max"], 50.0) and near(mm["fps_phase"], 50.0), "voies cpu, max, phase")
check(near(mm["ratio_cpu"], 0.5), "somme cpu-frame / duree")
check(near(mm["present-count_par_s"], 99 / 2.0) and near(mm["refresh-count_par_s"], 2.4 * 99 / 2.0), "compteurs cumules")
check(near(mm["gpu_limite"], 1.0) and near(mm["lentes_max"], 1.0), "GPU limitant, images lentes")
check("HYPOTHESE" in vram.ips_text(mm, 144), "texte : cpu-frame HYPOTHESE")

# Fichiers synthétiques : journal du greffon (essai à blanc), relevés, statistiques de rendu.
fx = sys.argv[2]
r2 = vram.analyse(os.path.join(fx, "factorio.log"), os.path.join(fx, "vram.tsv"), os.path.join(fx, "perf-stats.csv"), None)
check(len(r2["phases"]) == 10 and sum(1 for p in r2["phases"] if not p["name"].startswith("repere")) == 5,
      "10 phases dans le journal de l'essai a blanc, dont 5 vues mesurees (galerie des tetes comprise)")
kinds = {}
for c in r2["champs"]:
    kinds[c["genre"]] = kinds.get(c["genre"], 0) + 1
check(kinds.get("reference") == 10 and kinds.get("vue") == 5 and kinds.get("capture") == 10,
      "lignes CHAMP : 10 references, 5 vues, 10 captures (obtenu %s)" % kinds)
pf = r2["perf"]
check(not pf.get("erreur") and len(pf["colonnes"]) == 24, "24 colonnes du PerformanceLogger lues")
check(len(pf.get("par_phase") or []) == 5, "segmentation appariee aux 5 phases")
ph = {p["name"]: p["ips"] for p in pf.get("par_phase") or []}
z = ph.get("z030-jour", {})
check(near(z.get("fps_phase"), 60.0) and near(z.get("fps_max"), 1000 / 16.6) and near(z.get("fps_cpu"), 1000 / 12.0),
      "z030-jour : phase 60, max 60,2, cpu 83,3 (la voie cpu surestime)")
check(near(z.get("ratio_cpu"), 600 * 12.0 / 10000.0), "z030-jour : somme cpu-frame / duree = 0,72 (hypothese refutee)")
check(near(z.get("refresh-count_par_s"), 144.0, 0.02), "z030-jour : refresh-count 144/s")
n = ph.get("z030-nuit", {})
check(near(n.get("fps_phase"), 55.5) and near(n.get("fps_max"), 1000 / 18.0), "z030-nuit : 55,5 images/s par deux voies")
rep = vram.report_lines(r2)
check(any("controle du zoom : tuiles z030/z050 = 2.78" in ln for ln in rep), "controle du zoom")
check(any("CHAMP" in ln or "Champ reel" in ln for ln in rep), "section champ reel")

# memory_summary du pilote, avec un enregistreur factice.
rec = types.SimpleNamespace(proc=types.SimpleNamespace(pid=1234), gpu=types.SimpleNamespace(error=None),
                            peaks={"pic_privee": 3.2e9, "pic_ws": 3.0e9})
ms = vs.memory_summary(r2, rec, True, "hd")
for ln in ms:
    print("   ", ln)
check(any("pic 2.80 Go" in ln and "PID 1234" in ln for ln in ms), "resume : memoire dediee")
check(not any("borne BASSE" in ln for ln in ms), "fenetre hd : pas d'avertissement de borne basse")
check(any("borne BASSE" in ln for ln in vs.memory_summary(r2, rec, True, "min")), "fenetre reduite : borne basse")
check(any(ln.startswith("images/s phase z030-jour") and "phase 60.0" in ln and "HYPOTHESE" in ln for ln in ms),
      "resume : images/s par phase, voies et hypothese")
check(any("champ reel de la vue z030-jour" in ln for ln in ms), "resume : champ reel des vues")
check(any("UPS" in ln for ln in ms), "resume : UPS par phase")
r3 = vram.analyse(None, None, os.path.join(fx, "absent.csv"), None)
check(r3["perf"].get("erreur", "").startswith("fichier absent"), "perf absent")
ms3 = vs.memory_summary(r3, types.SimpleNamespace(proc=types.SimpleNamespace(pid=1), gpu=types.SimpleNamespace(error="PDH"),
                                                  peaks=None), True)
check(any("NON MESUREE (PDH)" in ln for ln in ms3), "resume : non mesuree")
# Lignes du moteur seulement (suite d4m, défaut 3 du correcteur) : une impression de script qui CONTIENT les mots
# d'une ligne d'atlas ne compte pas ; l'atlas virtuel du plancher est relevé à part (RD_LOG F81).
LOG4 = r"""   1.000 Created atlas bitmap 2048x1316 [none]
   1.500 Script @__factorio-overhaul__/x.lua:1: note : Created atlas bitmap 1x1 [none]
   1.600 Script @__factorio-overhaul__/x.lua:2: note : Created virtual atlas pages 4096x4096x9
   1.700 Script @__factorio-overhaul__/x.lua:3: Generated mipmaps (9) for atlas [0] of size 2048x1316
Created atlas bitmap 4x4 [decal]
   2.681 Created virtual atlas pages 4096x4096x9
   3.000 Generated mipmaps (3) for atlas [0] of size 2048x1316
"""
r4 = vram.parse_log(LOG4)
check(len(r4["atlases"]) == 1 and r4["atlases"][0]["h"] == 1316, "atlas : impression de script et ligne sans horodatage ignorees")
check(r4["virtual_atlases"] == [{"w": 4096, "h": 4096, "pages": 9}], "atlas virtuel releve une fois (pas la ligne de script)")
check(r4["atlases"][0]["mips"] == 3, "mipmaps : ligne de script ignoree")
vram.estimate(r4)
check(any("atlas VIRTUEL : 9 page(s) de 4096x4096 (151.0 Mpx) ; COMPTE dans l'estimation" in ln
          for ln in vram.report_lines(r4)), "rapport : atlas virtuel signale et compte")
check(vram.estimate(r4)["pixels"] == 2048 * 1316, "pixels des atlas bitmap seuls (pages virtuelles a part)")
check(vram.parse_log(LOG)["virtual_atlases"] == [], "pas d'atlas virtuel sans la ligne")

# ------------------------------------------------------------------------------------------------
# Suite vram (22/10) : l'atlas virtuel COMPTE dans l'estimation (règle « Atlas virtuel » en tête de vram.py).
# ------------------------------------------------------------------------------------------------
PAGES_PX = 4096 * 4096 * 9            # « Created virtual atlas pages 4096x4096x9 »
VIRT_PX = 16384 * 12288               # « Generated mipmaps for virtual atlas of size 16384x12288 »
# Sans atlas virtuel : l'estimation ne change pas (12 journaux archivés sur 13).
t0 = vram.estimate(vram.parse_log(LOG))
check(t0["virtuel_bas"] == 0 and t0["virtuel_haut"] == 0 and t0["pixels_virtuels"] == 0, "sans atlas virtuel : rien en plus")
check(t0["bas"] == t0["atlas_bas"] and t0["haut"] == t0["atlas_haut"], "sans atlas virtuel : total = atlas bitmap")
r0 = vram.parse_log(LOG)
vram.estimate(r0)
check(any(ln.startswith("  TOTAL : ") and "virtuel" not in ln for ln in vram.report_lines(r0)),
      "sans atlas virtuel : ligne TOTAL inchangee")
check(vram.VIRTUEL not in r0["categories"], "sans atlas virtuel : pas de categorie virtuelle")

# Lignes RÉELLES du journal du plancher (fo-logs\2026-10-22_D4m_5-plancher-mesure\visual.log, lignes 30 et 49 à 80,
# copiées telles quelles, espaces finals compris : les 33 lignes, y compris « Texture processor created », « Parallel
# Sprite Loader initialized » et « Sprite atlas cached. », qui ne doivent rien compter ; égalité octet pour octet
# vérifiée le 22/10 par le correcteur de la suite vram) : l'ancienne estimation d'E40 (0,20 à 0,31 Go) reste la part
# des atlas bitmap ; la nouvelle compte en plus les pages.
PLANCHER = (
    "   0.324 Graphics options: [Graphics quality: normal] [Video memory usage: low] [DXT: low-quality] [Color: 32bit]\n"
    "   2.579 Initial atlas bitmap size is 16384\n"
    "   2.579 Created atlas bitmap 2048x1316 [none]\n"
    "   2.579 Created atlas bitmap 4096x2120 [decal]\n"
    "   2.580 Created atlas bitmap 8192x2960 [low-object, linear-minification]\n"
    "   2.580 Created atlas bitmap 4096x3072 [mipmap, linear-minification, linear-magnification, linear-mip-level]\n"
    "   2.581 Created atlas bitmap 8192x3840 [terrain, mipmap, linear-minification, linear-mip-level]\n"
    "   2.581 Created atlas bitmap 4096x1632 [terrain-effect-map, mipmap, linear-minification, linear-mip-level]\n"
    "   2.581 Created atlas bitmap 4096x1664 [smoke, mipmap, linear-minification, linear-magnification]\n"
    "   2.581 Created atlas bitmap 256x112 [low-object, mipmap, linear-minification, linear-magnification, "
    "linear-mip-level]\n"
    "   2.581 Created atlas bitmap 4096x928 [mipmap]\n"
    "   2.581 Created atlas bitmap 8192x2272 [icon, not-compressed, mipmap, linear-minification, linear-magnification, "
    "linear-mip-level]\n"
    "   2.581 Created atlas bitmap 4096x828 [alpha-mask]\n"
    "   2.584 Created atlas bitmap 16384x4352 [shadow, linear-magnification, alpha-mask]\n"
    "   2.584 Created atlas bitmap 4096x1328 [shadow, mipmap, linear-magnification, alpha-mask]\n"
    "   2.584 Created atlas bitmap 2048x240 [icon-background, not-compressed, mipmap, linear-minification, "
    "linear-magnification, linear-mip-level, ]\n"
    "   2.681 Created virtual atlas pages 4096x4096x9\n"
    "   2.685 Texture processor created (2048). GPU accelerated compression Supported: yes, Enabled: yes/yes. "
    "Test passed. YCoCgDXT PSNR: 35.83, BC3 PSNR: 33.82\n"
    "   2.685 Atlases were not loaded from disk cache.\n"
    "   2.962 Parallel Sprite Loader initialized (threads: 15)\n"
    "   5.653 Sprites loaded\n"
    "   6.128 Sprite atlas cached.\n"
    "   6.140 Generated mipmaps (3) for atlas [2] of size 8192x2960   \n"
    "   6.152 Generated mipmaps (3) for atlas [3] of size 4096x3072   \n"
    "   6.163 Generated mipmaps (3) for atlas [4] of size 8192x3840   \n"
    "   6.174 Generated mipmaps (3) for atlas [5] of size 4096x1632   \n"
    "   6.185 Generated mipmaps (3) for atlas [6] of size 4096x1664   \n"
    "   6.196 Generated mipmaps (3) for atlas [7] of size 256x112   \n"
    "   6.218 Generated mipmaps (3) for atlas [8] of size 4096x928   \n"
    "   6.229 Generated mipmaps (5) for atlas [9] of size 8192x2272   \n"
    "   6.240 Generated mipmaps (3) for atlas [12] of size 4096x1328   \n"
    "   6.243 Custom mipmaps uploaded (1945)\n"
    "   6.404 Generated mipmaps for virtual atlas of size 16384x12288\n")
rp = vram.parse_log(PLANCHER)
check(PLANCHER.count("\n") == 33, "plancher : les 33 lignes du journal (30 et 49 a 80)")
check(rp["virtual_atlases"] == [{"w": 4096, "h": 4096, "pages": 9}] and rp["virtual_mips"] == [{"w": 16384, "h": 12288}],
      "plancher : pages et mipmaps de l'atlas virtuel relevees")
check(len(rp["atlases"]) == 14 and rp["virtual_page_lines"] == 0, "plancher : 14 atlas bitmap, aucune ligne au singulier")
tp = vram.estimate(rp)
check(vram.fmt_range(tp["atlas_bas"], tp["atlas_haut"]) == "0.20 a 0.31 Go", "plancher : part des atlas = E40 (0,20 a 0,31)")
check(abs(tp["virtuel_bas"] - PAGES_PX * 0.5) < 1, "plancher : virtuel bas = pages x 0,5 (DXT basse), sans mipmaps")
check(abs(tp["virtuel_haut"] - (PAGES_PX + VIRT_PX / 3.0) * 1.0) < 1,
      "plancher : virtuel haut = (pages + 1/3 de l'atlas virtuel annonce) x 1")
check(abs(tp["bas"] - (tp["atlas_bas"] + tp["virtuel_bas"])) < 1 and abs(tp["haut"] - (tp["atlas_haut"] + tp["virtuel_haut"])) < 1,
      "plancher : total = atlas + virtuel")
check(vram.fmt_range(tp["bas"], tp["haut"]) == "0.28 a 0.53 Go", "plancher : nouvelle estimation 0,28 a 0,53 Go")
check(tp["pixels"] == sum(a["w"] * a["h"] for a in rp["atlases"]) and tp["pixels_virtuels"] == PAGES_PX,
      "plancher : pixels bitmap et pixels de pages separes")
check(abs(tp["virtuel_non_compresse"] - 4.0 * PAGES_PX) < 1, "plancher : variante non compressee = pages x 4")
c = rp["categories"].get(vram.VIRTUEL)
check(c is not None and c["n"] == 1 and c["pixels"] == PAGES_PX and c["haut"] == tp["virtuel_haut"],
      "plancher : categorie atlas virtuel")
lp = vram.report_lines(rp)
check(any(ln.startswith("  TOTAL : ") and "0.151 de pages d'atlas virtuel" in ln and "estimation 0.28 a 0.53 Go" in ln
          and "atlas 0.20 a 0.31 Go" in ln and "atlas virtuel 0.08 a 0.22 Go" in ln for ln in lp), "plancher : ligne TOTAL")
check(any("TENU par l'estimation haute (0.53 Go)" in ln for ln in lp), "plancher : verdict D4-1 sur le total compte")
# Base du verdict éprouvée (correcteur, défaut 2) : un seuil de 0,4 Go est AU-DESSUS de la part des atlas bitmap
# (0,31 Go) et AU-DESSOUS du total compté (0,53 Go). Le verdict doit dire DEPASSE : il porte sur le total.
check(tp["atlas_haut"] < 0.4 * vram.GO < tp["haut"], "plancher : seuil de 0,4 Go entre atlas seuls et total")
check(any("D4-1 (atlas <= 0.4 Go" in ln and "DEPASSE par l'estimation haute (0.53 Go)" in ln
          for ln in vram.report_lines(rp, 0.4)), "plancher : seuil 0,4 Go DEPASSE par le total (pages comprises)")
check(any("au plus 67.1 Mpx en plus" in ln and "HYPOTHESE" in ln for ln in lp), "plancher : mipmaps et hypothese ecrites")
check(any("variante NON compressee" in ln and "0.60 Go" in ln for ln in lp), "plancher : variante non compressee ecrite")
check(not any("atlas virtuel et mesure" in ln for ln in lp), "plancher sans releve : pas de confrontation")

# Confrontation à la mesure directe (relevés synthétiques aux pics du passage 5 d'E40 : dédiée 0,42 Go, partagée 0,10).
def mesure(dedie, partage=None):
    m = {"n": 3, "dedie_o": vram.stats([dedie * 0.9, dedie, dedie * 0.95]), "phases": []}
    if partage is not None:
        m["partage_o"] = vram.stats([partage])
    return m


rp["mesure"] = mesure(0.42e9, 0.10e9)
vm = vram.virtual_vs_measure(rp)
check(vm is not None and abs(vm["plafond"] - 0.52e9) < 1 and vm["avec_partage"], "mesure : plafond = dedie + partage")
check(vm["nc_exclue"] and abs(vm["plancher_nc"] - (tp["atlas_bas"] + 4.0 * PAGES_PX)) < 1,
      "mesure : variante non compressee (0,81 Go) exclue par 0,52 Go")
check(vm["bas_compatible"], "mesure : estimation basse comptee (0,28) sous le pic dedie (0,42)")
lm = vram.report_lines(rp)
check(any("EXCLUE par la mesure" in ln and "0.81 Go > 0.52 Go" in ln for ln in lm), "mesure : exclusion ecrite")
check(any("ecart mesure - estimation haute" in ln and "NEGATIF" in ln for ln in lm), "mesure : ecart negatif signale")
rp["mesure"] = mesure(1.2e9)
vm = vram.virtual_vs_measure(rp)
check(not vm["nc_exclue"] and not vm["avec_partage"] and abs(vm["plafond"] - 1.2e9) < 1,
      "mesure : sans partage, plafond = dedie seul ; variante non exclue")
check(any("NON exclue par la mesure" in ln for ln in vram.report_lines(rp)), "mesure : non-exclusion ecrite")
rp["mesure"] = mesure(0.25e9, 0.0)
check(not vram.virtual_vs_measure(rp)["bas_compatible"]
      and any("INCOMPATIBLE" in ln for ln in vram.report_lines(rp)), "mesure : estimation basse au-dessus du pic signalee")
check(vram.virtual_vs_measure(r0) is None, "mesure : rien sans atlas virtuel")

# Règle de compression des pages : celle d'un atlas « [none] » sous la DXT du journal ; sans ligne de mipmaps, pas de
# mipmaps comptées ; plusieurs atlas virtuels appariés dans l'ordre à leurs lignes de mipmaps.
def virt(dxt, extra=""):
    return vram.parse_log("   0.3 Graphics options: [Graphics quality: normal] [Video memory usage: low] [DXT: %s]\n"
                          "   1.0 Created atlas bitmap 64x64 [none]\n%s" % (dxt, extra))


rh = virt("high-quality", "   2.0 Created virtual atlas pages 1024x1024x2\n")
th = vram.estimate(rh)
check(th["virtuel_bas"] == th["virtuel_haut"] == 2 * 1024 * 1024 * 1.0, "DXT haute : 1 o/px, sans ligne de mipmaps")
rn = virt("none", "   2.0 Created virtual atlas pages 1024x1024x2\n   3.0 Generated mipmaps for virtual atlas of size 512x512\n")
tn = vram.estimate(rn)
check(tn["virtuel_bas"] == 2 * 1024 * 1024 * 4.0 and abs(tn["virtuel_haut"] - 2 * 1024 * 1024 * 4.0 * (4 / 3.0)) < 1,
      "sans DXT : 4 o/px ; mipmaps = 1/3 des pages quand elles sont plus grandes que l'atlas annonce")
r2v = virt("low-quality", "   2.0 Created virtual atlas pages 1024x1024x1\n   2.1 Created virtual atlas pages 2048x2048x1\n"
           "   3.0 Generated mipmaps for virtual atlas of size 4096x4096\n")
t2v = vram.estimate(r2v)
v1, v2 = r2v["virtuels"]
check(v1["mip_taille"] == (4096, 4096) and v2["mip_taille"] is None and abs(v1["mip_px"] - 4096 * 4096 / 3.0) < 1e-6,
      "deux atlas virtuels : mipmaps appariees dans l'ordre")
check(t2v["pixels_virtuels"] == 1024 * 1024 + 2048 * 2048 and (r2v["categories"].get(vram.VIRTUEL) or {}).get("n") == 2,
      "deux atlas virtuels comptes")

# Lignes du MOTEUR seulement : impressions de script ignorées ; ligne au singulier signalée, pas comptée ; chiffres du
# moteur « Atlas memory size » rapportés s'ils existent.
# Correcteur (défauts 1 et 2) : chaque impression de script qui imite un chiffre du moteur vient APRÈS la ligne du
# moteur de même type ; sinon la dernière écriture masquerait un motif sans ancrage (mutant qui survivait). Les
# impressions de la ligne au singulier et des sprites hors atlas éprouvent l'ancrage de RE_VIRTUAL_PAGE et RE_OUTSIDE.
LOG6 = (r"""   1.000 Created atlas bitmap 64x64 [none]
   1.100 Script @__factorio-overhaul__/x.lua:1: Generated mipmaps for virtual atlas of size 16384x12288
   1.300 Created virtual atlas page 4096x4096 [none]
   1.400 Created virtual atlas pages 4096x4096x2
   1.500 Atlas memory size: 1234.50MB; 96.25MB (virtual)
   1.600 Size of sprites outside of atlas: 12.00MB
   1.700 Script @__factorio-overhaul__/x.lua:2: Atlas memory size: 1.00MB; 2.00MB (virtual)
   1.800 Script @__factorio-overhaul__/x.lua:3: Created virtual atlas page 4096x4096 [none]
   1.900 Script @__factorio-overhaul__/x.lua:4: Size of sprites outside of atlas: 99.00MB
""")
r6 = vram.parse_log(LOG6)
check(r6["virtual_mips"] == [] and r6["engine_atlas_mb"] == {"atlas": 1234.5, "virtuel": 96.25},
      "impressions de script ignorees (mipmaps virtuelles, chiffre du moteur)")
check(r6["virtual_page_lines"] == 1 and r6["virtual_atlases"] == [{"w": 4096, "h": 4096, "pages": 2}],
      "ligne au singulier relevee a part, non comptee")
check(r6["engine_outside_mb"] == 12.0, "chiffre du moteur : sprites hors atlas (impression de script ignoree)")
vram.estimate(r6)
l6 = vram.report_lines(r6)
check(any("ATTENTION 1 ligne(s)" in ln and "NON comptees" in ln for ln in l6), "ligne au singulier signalee")
check(any("chiffre du MOTEUR" in ln and "96.25 MB" in ln and "0.10 Go" in ln for ln in l6), "chiffre du moteur rapporte")
check(r6["totaux"]["pixels_virtuels"] == 2 * 4096 * 4096, "seule la ligne au pluriel compte")

# Résumé du pilote : les pages virtuelles y sont nommées, l'estimation les compte.
rp["mesure"] = mesure(0.42e9, 0.10e9)
rec6 = types.SimpleNamespace(proc=types.SimpleNamespace(pid=7), gpu=types.SimpleNamespace(error=None), peaks=None)
ms6 = vs.memory_summary(rp, rec6, True, "hd")
check(any("151.0 Mpx de pages d'atlas virtuel" in ln and "0.28 a 0.53 Go" in ln for ln in ms6),
      "resume du pilote : pages virtuelles comptees")
print("BILAN unitaire : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(1 if fail else 0)
