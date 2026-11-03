"""Icônes des 15 TECHNOLOGIES de la robotique (s'exécute dans Blender, lot DA-ICONES) : 12 robots en miniature debout sur
un plateau de montage cerclé de la couleur de leur famille (bras de montage en plus pour les 4 qui ouvrent une usine),
3 technologies de pièces."""
import math

from scene_base import B, CY, TOR, capte, lathe, pivoter, tube
from rq_couleurs import peint
from rq_kits import FAMILLE, SIGNATURES, lum_fam
import rq_pieces as Q


def plateau(famille, R=3.5):
    lathe([(0, 0), (R, 0), (R + 0.12, 0.2), (R + 0.12, 0.42), (R - 0.1, 0.6), (0, 0.6)], 0, 0, 0, "acier_caisse", verts=96)
    TOR(R - 0.5, 0.1, 0, 0, 0.6, lum_fam(famille, force=1.25), minor=10)
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        B(0.9, 0.32, 0.12, (R - 0.05) * math.cos(a), (R - 0.05) * math.sin(a), 0.42, peint(famille), bev=0.03,
          rot=(0, 0, math.degrees(a) + 90))
    return 0.6


def pattes(n, r0, z0, R, m="fonte", phase=0.0, genou=0.6, pied="fonte", ep=0.13, sol=0.6):
    for k in range(n):
        a = phase + 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        rk = (r0 + R) / 2 * 1.12
        tube([(r0 * c, r0 * s, z0), (rk * c, rk * s, z0 + genou), (R * c, R * s, sol + 0.12)], ep, m, res=8)
        CY(0.3, 0.12, R * c, R * s, sol, pied, verts=20)


def grue(famille):
    """Bras de montage au-dessus du plateau (technologies qui ouvrent une usine)."""
    B(0.6, 0.6, 7.2, -3.4, 1.4, 0.6, peint(famille), bev=0.06)
    for k in range(6):
        B(0.64, 0.64, 0.22, -3.4, 1.4, 1.1 + k * 1.15, "jaune_danger" if k % 2 else "noir_mat", bev=0.02)
    B(4.6, 0.5, 0.55, -1.35, 1.4, 7.55, peint(famille), bev=0.06)
    B(0.9, 0.9, 0.6, -3.4, 1.4, 7.5, "acier_caisse", bev=0.06)
    CY(0.04, 1.3, 0.6, 1.4, 6.25, "alu_sombre", verts=6)
    TOR(0.22, 0.07, 0.6, 1.4, 6.1, "acier_caisse", rot=(90, 0, 0), minor=8)


# id : (échelle de la signature, z de la signature sur le plateau, pattes(...) ou None)
ROBOT = {
    "steam-trotter": (1.15, 1.25, dict(n=4, r0=1.0, z0=1.4, R=2.3, m="laiton_sombre", phase=math.pi / 4, ep=0.15)),
    "scalehide": (1.15, 0.8, dict(n=4, r0=1.8, z0=1.0, R=2.8, m="fonte", phase=math.pi / 4, genou=0.4, ep=0.24)),
    "coiler": (1.2, 1.2, dict(n=2, r0=0.7, z0=1.3, R=1.6, m="titane", phase=math.pi / 2, ep=0.15)),
    "needle": (1.15, 2.2, dict(n=4, r0=1.2, z0=2.3, R=2.8, m="laiton", phase=math.pi / 4, genou=0.8, ep=0.11)),
    "bellwether": (1.15, 1.0, dict(n=4, r0=1.7, z0=1.0, R=2.8, m="cuivre", phase=math.pi / 4, genou=0.5, ep=0.15)),
    "chamfer": (1.1, 0.9, dict(n=6, r0=1.8, z0=1.0, R=3.0, m="canon", phase=0.0, genou=0.5, ep=0.17)),
    "trowel": (1.15, 1.3, dict(n=4, r0=1.7, z0=1.4, R=2.8, m="titane", phase=math.pi / 4, genou=0.6, ep=0.15)),
    "finback": (1.05, 1.6, dict(n=3, r0=0.3, z0=1.6, R=1.2, m="titane", phase=math.pi / 2, genou=0.1, ep=0.1)),
    "levite": (1.2, 0.55, None),
    "toroid": (1.25, 0.0, None),
    "heliast": (1.1, 0.75, None),
    "crowned": (1.4, 0.0, None),
}
USINE = {"steam-trotter", "needle", "trowel", "toroid"}


def tech_robot(rid):
    def f():
        fam = FAMILLE[rid]
        zp = plateau(fam)
        s, z, pa = ROBOT[rid]
        if pa:
            d = dict(pa)
            d["z0"] = zp + d["z0"]
            pattes(sol=zp, **d)
        if rid == "heliast":
            CY(0.5, 0.7, 0, 0, zp, "or_sombre", verts=8)
        pivoter(capte(SIGNATURES[rid]), loc=(0, 0, zp + z), s=s)
        if rid in USINE:
            grue(fam)
    return f


def tech_servo_mechanisms():
    """Le servomoteur au centre, le capteur optique debout à gauche, le contrôleur à plat devant à droite."""
    pivoter(capte(Q.servo), loc=(0.2, 1.0, 0.4))
    pivoter(capte(Q.capteur), rot=(62, 0, 18), loc=(-3.2, -0.6, 0.9), s=0.8)
    pivoter(capte(Q.controleur), rot=(0, 0, 16), loc=(2.6, -2.2, 0.0), s=0.72)


def tech_robot_guidance():
    CY(3.2, 0.4, 0, 0, -0.4, "acier_caisse", verts=8, bev=0.04)
    TOR(2.8, 0.09, 0, 0, 0.0, Q.lum("voyant_bleu", force=1.2), minor=10)
    pivoter(capte(Q.noyau), loc=(0, 0, 0), s=1.25)


def tech_magnetic_drive():
    """Le vérin à aimants en diagonale devant, le module laser au-dessus qui tire vers la gauche, le barreau à droite."""
    pivoter(capte(Q.actionneur), rot=(0, 0, -20), loc=(0.0, -1.2, 0.9))
    pivoter(capte(Q.tete_laser), rot=(0, -4, -150), loc=(0.6, 1.6, 3.4), s=1.0)
    pivoter(capte(Q.barreau), rot=(0, -8, 62), loc=(3.6, 0.6, 0.7), s=0.6)


TECHS = {
    "fo-servo-mechanisms": tech_servo_mechanisms,
    "fo-robot-guidance": tech_robot_guidance,
    "fo-magnetic-drive": tech_magnetic_drive,
    "fo-robot-automata": tech_robot("steam-trotter"),
    "fo-robot-heavy": tech_robot("scalehide"),
    "fo-robot-coil": tech_robot("coiler"),
    "fo-robot-bay": tech_robot("needle"),
    "fo-robot-bellwether": tech_robot("bellwether"),
    "fo-robot-mortar": tech_robot("chamfer"),
    "fo-robot-dock": tech_robot("trowel"),
    "fo-robot-finback": tech_robot("finback"),
    "fo-robot-levite": tech_robot("levite"),
    "fo-robot-gantry": tech_robot("toroid"),
    "fo-robot-gantry-heliast": tech_robot("heliast"),
    "fo-robot-gantry-crowned": tech_robot("crowned"),
}
