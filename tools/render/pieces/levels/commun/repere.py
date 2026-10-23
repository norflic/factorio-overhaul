"""REPÈRE DES FAMILLES (lot K0, 23/10) : y de jeu vers le nord et repère local posé. Sorti de gun_e/corps.py SANS
changer une ligne (corps.Y et corps.at restent : corps.py les réimporte). S'exécute DANS Blender (Geo.push)."""
from kit import SQ2


def Y(yn):
    """y de jeu en tuiles, vers le NORD -> Y Blender."""
    return yn * SQ2


class at:
    """Repère local posé en (x, y de jeu vers le nord, z), tourné de rz : `with at(g, x, yn, rz): ...`."""

    def __init__(self, g, x, yn, rz=0.0, z=0.0):
        self.g, self.a = g, ((x, Y(yn), z), rz)

    def __enter__(self):
        self.g.push(self.a[0], rz=self.a[1])
        return self.g

    def __exit__(self, *exc):
        self.g.pop()
