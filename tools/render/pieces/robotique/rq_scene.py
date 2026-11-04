"""Point d'entrée Blender des icônes de la robotique (lot DA-ICONES). Lancé par icones.py (jamais à la main) :
    blender -b --factory-startup -noaudio -P rq_scene.py -- --quoi a,b,c --out <dossier> --samples N --taille PX
Sortie : <out>/<quoi>.png (sRGB 16 bits, alpha). Socle de rendu, lumières et matières : ceux des icônes du calcul
(tools/render/pieces/calcul/scene_base.py), pour un style commun."""
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "..", "calcul"))
sys.path.insert(0, ICI)
import scene_base as P  # noqa: E402
import rq_couleurs  # noqa: E402,F401  (ajoute les matières de la robotique à celles du calcul)
import rq_kits as K  # noqa: E402
import rq_pieces as Q  # noqa: E402
import rq_technos as T  # noqa: E402

# nom : (fonction, élévation, azimut, remplissage du cadre)
SCENES = {
    "fo-servo-motor": (Q.ic_servo_motor, 30, 22, 0.93),
    "fo-optical-sensor": (Q.ic_optical_sensor, 30, 18, 0.93),
    "fo-controller": (Q.ic_controller, 50, 18, 0.93),
    "fo-guidance-core": (Q.ic_guidance_core, 28, 24, 0.93),
    "fo-magnetic-actuator": (Q.ic_magnetic_actuator, 26, 18, 0.93),
    "fo-ndyag-rod": (Q.ic_ndyag_rod, 30, 18, 0.93),
    "fo-laser-module": (Q.ic_laser_module, 24, 22, 0.93),
    "fo-printed-circuit-board": (Q.ic_printed_circuit_board, 66, 18, 0.93),
    "fo-crystal-oscillator": (Q.ic_crystal_oscillator, 22, 20, 0.93),
    "fo-metallurgical-silicon": (Q.ic_metallurgical_silicon, 34, 20, 0.93),
    "fo-pure-silicon": (Q.ic_pure_silicon, 36, 20, 0.93),
    "fo-silicon-wafer": (Q.ic_silicon_wafer, 40, 18, 0.93),
    "fo-enameled-wire": (Q.ic_enameled_wire, 26, 20, 0.93),
    "fo-coil": (Q.ic_coil, 28, 24, 0.93),
    "fo-superconducting-tape": (Q.ic_superconducting_tape, 42, 18, 0.93),
}
for rid in ("steam-trotter", "scalehide", "coiler", "needle", "bellwether", "chamfer", "trowel", "finback", "levite", "toroid",
            "heliast", "crowned"):
    SCENES["fo-robot-kit-" + rid] = (K._kit(rid), 26, 24, 0.93)
SCENES["fo-robot-segment-toroid"] = (K.seg_torique, 52, 20, 0.93)
SCENES["fo-robot-segment-heliast"] = (K.seg_heliaste, 34, 20, 0.93)
SCENES["fo-robot-segment-crowned"] = (K.seg_couronne, 22, 22, 0.93)
for t, fn in T.TECHS.items():
    SCENES["tech-" + t] = (fn, 28, 26, 0.93)


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
