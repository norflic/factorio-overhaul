"""Point d'entrée Blender des icônes du calcul. Lancé par icones.py (jamais à la main) :
    blender -b --factory-startup -noaudio -P scene_icones.py -- --quoi a,b,c --out <dossier> --samples N --taille PX
Sortie : <out>/<quoi>.png (sRGB 16 bits, alpha)."""
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import scene_base as P  # noqa: E402
import scene_baies as Z  # noqa: E402
import scene_fluides as F  # noqa: E402
import scene_objets as O  # noqa: E402
import scene_technos as T  # noqa: E402

# nom : (fonction, élévation, azimut, remplissage du cadre)
SCENES = {
    "fo-silicon-ingot": (O.ic_silicon_ingot, 30, 22, 0.97),
    "fo-photomask": (O.ic_photomask, 52, 0, 0.98),
    "fo-etched-wafer": (O.ic_etched_wafer, 56, 18, 0.98),
    "fo-exposed-wafer": (O.ic_exposed_wafer, 40, 18, 0.98),
    "fo-crystal-laser": (O.ic_crystal_laser, 18, 18, 0.97),
    "fo-logic-die": (O.ic_logic_die, 54, 20, 0.98),
    "fo-dram-die": (O.ic_dram_die, 56, 18, 0.98),
    "fo-sram-die": (O.ic_sram_die, 32, 0, 0.98),
    "fo-nand-die": (O.ic_nand_die, 36, 20, 0.98),
    "fo-heat-sink": (O.ic_heat_sink, 36, 20, 0.97),
    "fo-memory-module": (O.ic_memory_module, 60, 20, 0.98),
    "fo-motherboard": (O.ic_motherboard, 52, 18, 0.98),
    "fo-graphics-card": (O.ic_graphics_card, 52, 20, 0.98),
    "fo-degassed-ilmenite": (O.ic_degassed_ilmenite, 40, 15, 0.97),
    "fo-flash-drive": (O.ic_flash_drive, 50, 18, 0.98),
    "fo-optical-fiber": (O.ic_fiber_complet, 12, 0, 0.97),
    "fo-network-switch": (O.ic_network_switch, 26, 22, 0.98),
    "fo-qubit-chip": (O.ic_qubit_chip, 50, 18, 0.98),
    "fo-dilution-stage": (O.ic_dilution_stage, 20, 18, 0.97),
    "fo-quantum-processor": (O.ic_quantum_processor, 26, 18, 0.98),
    "fo-server-blade": (Z.ic_server_blade, 20, 28, 0.97),
    "fo-memory-rack": (Z.ic_memory_rack, 20, 28, 0.97),
    "fo-storage-rack": (Z.ic_storage_rack, 20, 28, 0.97),
    "fo-network-rack": (Z.ic_network_rack, 20, 28, 0.97),
    "fo-cooling-rack": (Z.ic_cooling_rack, 20, 28, 0.97),
    "fo-gpu-blade": (Z.ic_gpu_blade, 20, 28, 0.97),
    "fo-quantum-rack": (Z.ic_quantum_rack, 20, 28, 0.97),
    "fo-chilled-water": (F.ic_chilled_water, 8, 15, 0.97),
    "fo-warm-water": (F.ic_warm_water, 8, 15, 0.97),
    "fo-photoresist": (F.ic_photoresist, 22, 15, 0.97),
    "fo-helium-3": (F.ic_helium_3, 14, 12, 0.97),
    "fo-dilution-mix": (F.ic_dilution_mix, 8, 15, 0.97),
    "tech-fo-wafer-fab": (T.tech_wafer_fab, 22, -42, 0.93),
    "tech-fo-chip-foundry": (T.tech_chip_foundry, 36, 8, 0.93),
    "tech-fo-data-centers": (T.tech_data_centers, 24, 52, 0.93),
    "tech-fo-data-centers-2": (T.tech_data_centers_2, 22, 26, 0.93),
    "tech-fo-gpu-computing": (T.tech_gpu_computing, 42, 18, 0.93),
    "tech-fo-regolith-degassing": (T.tech_regolith_degassing, 30, 18, 0.93),
    "tech-fo-quantum-computing": (T.tech_quantum_computing, 16, 20, 0.93),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    quoi, out, samples, taille = None, None, 16, 512
    for i in range(0, len(argv), 2):
        k, v = argv[i], argv[i + 1]
        if k == "--quoi":
            quoi = v.split(",")
        elif k == "--out":
            out = v
        elif k == "--samples":
            samples = int(v)
        elif k == "--taille":
            taille = int(v)
    os.makedirs(out, exist_ok=True)
    for q in quoi:
        fn, el, az, remplir = SCENES[q]
        P.rendre(fn, os.path.join(out, q + ".png"), samples, taille, el, az, remplir, q)


main()
