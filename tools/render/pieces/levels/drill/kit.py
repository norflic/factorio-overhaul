"""Kit de modélisation de la famille « foreuse électrique » (lot V3, phase 1). S'exécute DANS Blender.

Repère des 4 directions (le point délicat de la foreuse) :
- on modélise TOUJOURS dans le repère « N » : a = tuiles vers l'est, b = tuiles vers le SUD, z = hauteur
  en unités Blender ; la goulotte de sortie est au nord (b < 0), « l'arrière » est au sud ;
- la grille de jeu est étirée de 1/cos 45° en profondeur dans la scène (CALIBRATION §2, F60) : une
  rotation de 90° de la scène ne laisse donc PAS l'emprise carrée. On distingue :
  * les pièces « de grille » (cadres, plaques, plates-formes qui suivent l'emprise) : rectangle donné en
    tuiles, tourné dans l'espace des tuiles, puis étiré (tbox, tfrustum, tpoly) ;
  * les pièces « vraies 3D » (cylindres, sphères, anneaux, cristaux, roues) : proportions réelles,
    position tournée dans l'espace des tuiles, orientation propre tournée de l'angle de la direction ;
  * les poutres entre deux points (beam, rod) : extrémités tournées dans l'espace des tuiles.
- rotation : N -> E : (a, b) -> (-b, a) ; S : (-a, -b) ; O : (b, -a). Angle Blender autour de Z :
  N 0°, E -90°, S 180°, O +90° (le nord du modèle regarde la direction de la foreuse).

Hauteurs : un point (a, b, z) apparaît à l'écran en (a, b - 0,7071 z) tuiles. Le haut de l'emprise est à
-1,5 : O = -(b - 0,7071 z) - 1,5. Comme chaque pièce passe au nord dans une des 4 directions, sa hauteur
utile est bornée par z <= (O_époque + 1,5 - max(|a|, |b|)) / 0,7071 (budget « pyramide »).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

DIR_ANG = {"N": 0.0, "E": -90.0, "S": 180.0, "W": 90.0}
K = 1.0 / math.sqrt(2.0)   # 0,7071 : une unité de hauteur = 0,7071 tuile d'écran


def srgb(hexstr):
    """Couleur sRGB '#RRGGBB' -> RGB linéaire (couleurs de la bible §1.5)."""
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def scale(col, k):
    return tuple(min(1.0, c * k) for c in col)


class Ctx:
    """Contexte de construction d'une pose : direction, aides de modélisation, matériaux."""

    def __init__(self, S, C, direction):
        self.S, self.C, self.d = S, C, direction
        self.ang = math.radians(DIR_ANG[direction])
        self.n = 0
        self.mats = {}

    # ---------------- repères ----------------
    def rt(self, a, b):
        d = self.d
        if d == "N":
            return a, b
        if d == "E":
            return -b, a
        if d == "S":
            return -a, -b
        return b, -a

    def P(self, a, b, z=0.0):
        x, y = self.rt(a, b)
        return Vector(self.C.tile_to_blender(x, y, z))

    def name(self, base):
        self.n += 1
        return "%s_%03d" % (base, self.n)

    def _finish(self, o, local=None, at=None, turn=True):
        """Oriente une pièce vraie 3D créée à l'origine : rotation locale, puis direction, puis position."""
        M = Matrix.Identity(4)
        if local is not None:
            M = local @ M
        if turn and self.ang:
            M = Matrix.Rotation(self.ang, 4, "Z") @ M
        o.data.transform(M)
        o.data.update()
        if at is not None:
            o.location = at
        return o

    # ---------------- pièces de grille (suivent l'emprise) ----------------
    def tbox(self, a0, b0, a1, b1, z0, z1, mat, bevel=0.012, name="tbox"):
        x0, y0 = self.rt(a0, b0)
        x1, y1 = self.rt(a1, b1)
        ka = self.C.TILE_DEPTH_UNITS
        sx, sy = abs(x1 - x0), abs(y1 - y0) * ka
        cx, cy = (x0 + x1) / 2.0, -(y0 + y1) / 2.0 * ka
        return self.S.box((max(sx, 1e-3), max(sy, 1e-3), max(z1 - z0, 1e-3)), (cx, cy, (z0 + z1) / 2.0), mat,
                          self.name(name), bevel_w=bevel)

    def tfrustum(self, a0, b0, a1, b1, z0, inset, z1, mat, name="tfrustum", bevel=0.01, top_rect=None):
        """Tronc de pyramide de grille : base [a0,a1]x[b0,b1] en z0, sommet rétréci de `inset` tuiles en z1."""
        if top_rect is None:
            top_rect = (a0 + inset, b0 + inset, a1 - inset, b1 - inset)
        ta0, tb0, ta1, tb1 = top_rect
        v = [self.P(a0, b0, z0), self.P(a1, b0, z0), self.P(a1, b1, z0), self.P(a0, b1, z0),
             self.P(ta0, tb0, z1), self.P(ta1, tb0, z1), self.P(ta1, tb1, z1), self.P(ta0, tb1, z1)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        o = self.mesh([tuple(x) for x in v], f, mat, name)
        if bevel:
            self.S.bevel(o, bevel)
        return o

    def tprism(self, poly_ab, z0, z1, mat, name="tprism", bevel=0.01):
        """Prisme vertical de base polygonale donnée en tuiles (repère N), sens quelconque."""
        n = len(poly_ab)
        v = [tuple(self.P(a, b, z0)) for a, b in poly_ab] + [tuple(self.P(a, b, z1)) for a, b in poly_ab]
        # orientation : aire signée dans le plan Blender (x, y)
        s = 0.0
        for i in range(n):
            x0, y0 = v[i][0], v[i][1]
            x1, y1 = v[(i + 1) % n][0], v[(i + 1) % n][1]
            s += x0 * y1 - x1 * y0
        idx = list(range(n)) if s > 0 else list(range(n))[::-1]
        f = [tuple(idx[::-1]), tuple(i + n for i in idx)]
        for k in range(n):
            i, j = idx[k], idx[(k + 1) % n]
            f.append((i, j, j + n, i + n))
        o = self.mesh(v, f, mat, name)
        if bevel:
            self.S.bevel(o, bevel)
        return o

    # ---------------- maillages libres ----------------
    def mesh(self, verts, faces, mat, name="mesh", smooth_deg=None):
        me = bpy.data.meshes.new(self.name(name))
        me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        o = bpy.data.objects.new(me.name, me)
        self.S.piece_collection().objects.link(o)
        if mat is not None:
            me.materials.append(mat)
        if smooth_deg:
            self.S.smooth(o, smooth_deg)
        return o

    def lathe(self, a, b, profile, mat, seg=48, z_base=0.0, name="lathe", caps=True, smooth_deg=50, phase=0.0,
              local=None):
        """Surface de révolution (vraie 3D) d'axe vertical en (a, b) : profil [(r, z), ...] de bas en haut."""
        verts, faces = [], []
        n = len(profile)
        for i in range(seg):
            t = phase + 2 * math.pi * i / seg
            c, s = math.cos(t), math.sin(t)
            for r, z in profile:
                verts.append((r * c, r * s, z))
        for i in range(seg):
            j = (i + 1) % seg
            for k in range(n - 1):
                faces.append((i * n + k, j * n + k, j * n + k + 1, i * n + k + 1))
        if caps:
            if profile[0][0] > 1e-6:
                verts.append((0, 0, profile[0][1]))
                cb = len(verts) - 1
                for i in range(seg):
                    j = (i + 1) % seg
                    faces.append((j * n, i * n, cb))
            if profile[-1][0] > 1e-6:
                verts.append((0, 0, profile[-1][1]))
                ct = len(verts) - 1
                for i in range(seg):
                    j = (i + 1) % seg
                    faces.append((i * n + n - 1, j * n + n - 1, ct))
        o = self.mesh(verts, faces, mat, name, smooth_deg=smooth_deg)
        return self._finish(o, local=local, at=self.P(a, b, z_base))

    # ---------------- pièces vraies 3D ----------------
    def cyl(self, a, b, z0, z1, r, mat, r2=None, verts=40, bevel=0.006, caps=True, name="cyl"):
        o = self.S.cylinder(r, z1 - z0, (0, 0, 0), mat, self.name(name), verts=verts, bevel_w=bevel, radius2=r2,
                            caps=caps)
        return self._finish(o, at=self.P(a, b, (z0 + z1) / 2.0), turn=False)

    def sph(self, a, b, z, r, mat, seg=32, rings=16, sz=1.0, name="sph"):
        o = self.S.sphere(r, (0, 0, 0), mat, self.name(name), seg=seg, rings=rings)
        if sz != 1.0:
            o.data.transform(Matrix.Diagonal((1, 1, sz, 1)))
        return self._finish(o, at=self.P(a, b, z), turn=False)

    def tor(self, a, b, z, R, r, mat, rot=(0.0, 0.0, 0.0), seg=64, mseg=12, name="tor", turn=True):
        o = self.S.torus(R, r, (0, 0, 0), mat, self.name(name), major_seg=seg, minor_seg=mseg)
        loc = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
        return self._finish(o, local=loc, at=self.P(a, b, z), turn=turn)

    def box3(self, a, b, z, size, mat, rotz=0.0, bevel=0.01, name="box3", turn=True, local=None):
        """Boîte vraie 3D (dimensions en unités Blender), tournée avec la direction."""
        o = self.S.box(size, (0, 0, 0), mat, self.name(name), bevel_w=bevel)
        M = Matrix.Rotation(rotz, 4, "Z")
        if local is not None:
            M = local @ M
        return self._finish(o, local=M, at=self.P(a, b, z), turn=turn)

    def _between(self, o, p0, p1):
        d = p1 - p0
        L = d.length
        q = d.normalized().to_track_quat("Z", "Y")
        o.data.transform(Matrix.Diagonal((1, 1, L, 1)))
        o.data.transform(q.to_matrix().to_4x4())
        o.data.update()
        o.location = (p0 + p1) / 2.0
        return o

    def beam(self, p0, p1, w, mat, h=None, bevel=0.006, name="beam"):
        """Poutre de section w x h (unités) entre deux points (a, b, z) du repère N."""
        o = self.S.box((w, h or w, 1.0), (0, 0, 0), mat, self.name(name), bevel_w=bevel)
        return self._between(o, self.P(*p0), self.P(*p1))

    def rod(self, p0, p1, r, mat, verts=12, bevel=0.0, name="rod", r2=None):
        o = self.S.cylinder(r, 1.0, (0, 0, 0), mat, self.name(name), verts=verts, bevel_w=bevel, radius2=r2)
        return self._between(o, self.P(*p0), self.P(*p1))

    def pipe_path(self, pts, r, mat, name="tuyau"):
        """Tuyau polyligne (tronçons + rotules aux coudes)."""
        objs = []
        for i in range(len(pts) - 1):
            objs.append(self.rod(pts[i], pts[i + 1], r, mat, verts=16, name=name))
        for p in pts[1:-1]:
            objs.append(self.sph(p[0], p[1], p[2], r * 1.02, mat, seg=16, rings=8, name=name + "_coude"))
        return objs

    def wheel(self, a, b, z, R, rim, mat, spokes=6, axis="NS", hub=None, name="roue", turn=True):
        """Roue verticale (jante + rayons + moyeu). axis « NS » : axe nord-sud, plan est-ouest, vue de face
        (ellipse b/a = 0,707 à l'écran) ; « EW » : axe est-ouest (vue par la tranche)."""
        objs = []
        plane = Matrix.Rotation(math.pi / 2, 4, "Z") if axis == "EW" else Matrix.Identity(4)
        o = self.S.torus(R, rim, (0, 0, 0), mat, self.name(name + "_jante"), major_seg=48, minor_seg=8)
        objs.append(self._finish(o, local=plane @ Matrix.Rotation(math.pi / 2, 4, "X"), at=self.P(a, b, z), turn=turn))
        for i in range(spokes):
            t = 2 * math.pi * i / spokes
            s = self.S.box((rim * 1.3, rim * 1.3, R), (0, 0, 0), mat, self.name(name + "_rayon"), bevel_w=0)
            M = plane @ Matrix.Rotation(t, 4, "Y") @ Matrix.Translation((0, 0, R / 2.0))
            objs.append(self._finish(s, local=M, at=self.P(a, b, z), turn=turn))
        hr = hub or rim * 2.4
        h = self.S.cylinder(hr, rim * 3.0, (0, 0, 0), mat, self.name(name + "_moyeu"), verts=20, bevel_w=0.004)
        objs.append(self._finish(h, local=plane @ Matrix.Rotation(math.pi / 2, 4, "X"), at=self.P(a, b, z), turn=turn))
        return objs

    def crystal(self, base, direction, length, r, mat, name="cristal", tip=0.32):
        """Cristal hexagonal à pointe : base (a, b, z) dans le repère N, direction 3D (dx, dy, dz) Blender
        exprimée dans le repère N (tournée avec la foreuse)."""
        prof = [(r * 0.85, 0.0), (r, length * 0.08), (r * 0.92, length * (1 - tip)), (0.0, length)]
        o = self.lathe(0, 0, prof, mat, seg=6, name=name, smooth_deg=None, phase=0.3)
        o.location = (0, 0, 0)
        dv = Vector(direction).normalized()
        q = dv.to_track_quat("Z", "Y")
        o.data.transform(q.to_matrix().to_4x4())
        if self.ang:
            o.data.transform(Matrix.Rotation(self.ang, 4, "Z"))
        o.data.update()
        o.location = self.P(*base)
        return o

    def fin(self, root_a, root_b, z0, z1, reach, sweep, mat, heading_deg, thick=0.035, name="aileron"):
        """Aileron triangulaire vertical : bord d'attache sur l'axe (z0..z1) en (root_a, root_b), pointe à
        `reach` unités dans le cap heading_deg (0 = est, 90 = nord, repère N) à la hauteur z0 + sweep."""
        h = math.radians(heading_deg)
        pts = [(0.0, z0), (0.0, z1), (reach, z0 + sweep)]
        v = []
        for side in (-thick / 2, thick / 2):
            for (u, z) in pts:
                v.append((u, side, z))
        f = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
        o = self.mesh(v, f, mat, name)
        return self._finish(o, local=Matrix.Rotation(h, 4, "Z"), at=self.P(root_a, root_b, 0.0))

    def sph2(self, a, b, z, r, mat_top, mat_bot, level=0.0, seg=40, rings=20, name="bulbe"):
        """Sphère à deux matériaux : sous la cote relative `level` (fraction du rayon), `mat_bot`
        (liquide lumineux), au-dessus `mat_top` (verre). Seule la partie basse est émissive."""
        o = self.S.sphere(r, (0, 0, 0), mat_top, self.name(name), seg=seg, rings=rings)
        o.data.materials.append(mat_bot)
        for p in o.data.polygons:
            if p.center.z < level * r:
                p.material_index = 1
        return self._finish(o, at=self.P(a, b, z), turn=False)

    def fixed(self):
        """Contexte qui ne tourne pas avec la direction (pièces paires invariantes : 1 rendu pour 4)."""
        f = Ctx(self.S, self.C, "N")
        f.n = self.n + 5000
        f.level = getattr(self, "level", 0)
        f.mats = self.mats
        return f

    def join(self, objs, name):
        objs = [o for o in objs if o is not None]
        if len(objs) < 2:
            return objs[0] if objs else None
        return self.S.join(objs, self.name(name))
