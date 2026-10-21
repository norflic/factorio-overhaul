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
check(len(r2["phases"]) == 8 and sum(1 for p in r2["phases"] if not p["name"].startswith("repere")) == 4,
      "8 phases dans le journal de l'essai a blanc, dont 4 vues mesurees")
kinds = {}
for c in r2["champs"]:
    kinds[c["genre"]] = kinds.get(c["genre"], 0) + 1
check(kinds.get("reference") == 8 and kinds.get("vue") == 4 and kinds.get("capture") == 8,
      "lignes CHAMP : 8 references, 4 vues, 8 captures (obtenu %s)" % kinds)
pf = r2["perf"]
check(not pf.get("erreur") and len(pf["colonnes"]) == 24, "24 colonnes du PerformanceLogger lues")
check(len(pf.get("par_phase") or []) == 4, "segmentation appariee aux 4 phases")
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
print("BILAN unitaire : %d OK, %d ECHEC(S)" % (ok, fail))
sys.exit(1 if fail else 0)
