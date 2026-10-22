"""Boîte à outils de modélisation du centre de commandement (lot V3-a, phase 1).

S'exécute DANS Blender (appelé par centre.py) : reçoit S (tools/render/blender/fo_scene.py) et C
(tools/render/fo_calib.py). Ne modifie aucun fichier partagé du pipeline : tout ce qui manque au pipeline
(lofts, surfaces de révolution, repère de jeu, étiquettes de couches) est écrit ici.

Repère de JEU (celui de la bible) : x vers l'est, ty vers le SUD, en tuiles, origine au centre de l'entité,
z vers le haut en unités Blender (1 unité de hauteur = 45,25 px HR à l'écran, soit 0,707 tuile).
Une tuile vers le sud vaut 1/cos 45° = 1,414 unité Blender en Y (CALIBRATION.md §2).
Écran (tuiles) : u = x ; v = ty - 0,707·z (v vers le bas).

Étiquettes de pièces (propriété « fo_role ») :
  mass : masse principale (compte dans O et dans tous les masques) ;
  tige : tige fine, mât, antenne, drapeau du mât (compte dans les masques, PAS dans O, bible §1.4) ;
  flat : couche plate posée au sol (dalle, plate-forme basse) : exclue du masque D1-3 amendé (Q13).
Variantes : « -sil » omet les pièces flat ; « -mass » omet flat et tige ; « -jour » éteint les émissifs (couches
main, ao et shadow de TOUTES les époques) ; sans suffixe, ils sont allumés (couches glow et light).

Correction V3 du 22/10 (vérification adverse) :
  - matières : grain >= 0,24, crasse des creux >= 0,5, rouille (ères I à III) ou salissure (ères IV et V) sur
    toutes les matières sauf les accents propres, relief fin (bump), taches et coulures verticales (enrich) ;
    cible : densité de détail du vanilla (Laplacien moyen du roboport 31,2 ; cheminée V0 validée 31,7) ;
  - lueur de jour : couleur du cœur CALIBRÉE (centre_params.glow_core), teinte de la bible préservée, et
    surface éteinte presque noire sous la lueur : la couche principale ne contient plus l'éclat ;
  - panneaux rapportés, nervures, bandes, grilles (panels, ribs, bands, louvres) : détail géométrique des
    grandes faces lisses.
"""
import math

R2 = 2.0 ** 0.5          # profondeur Blender d'une tuile de jeu vers le sud (1/cos 45°)
K = 0.5 ** 0.5           # projection de la hauteur et de la profondeur à l'écran (cos 45° = sin 45°)


def srgb(hexcol):
    """'#5A5048' -> couleur LINÉAIRE (r, g, b)."""
    h = hexcol.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def mix(a, b, t):
    return tuple(x * (1 - t) + y * t for x, y in zip(a, b))


def scale(c, g):
    return tuple(min(1.0, x * g) for x in c)


def grime(hexcol, k=0.42):
    """Salissure d'une matière claire (ères IV et V) : la base assombrie et légèrement réchauffée."""
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return "#%02X%02X%02X" % (min(255, int(r * k * 1.06)), int(g * k), int(b * k * 0.88))


def enrich(m, bump=0.35, bump_scale=80.0, stain=0.2, streak=0.16, seed=0.0):
    """Enrichit un matériau de fo_scene.mat_metal SANS modifier le pipeline partagé :
      - relief fin : bruit fin -> nœud Bump -> normale (micro-reflets, comme le grain des sprites vanilla) ;
      - taches : bruit à grande échelle qui module la couleur (patine, salissure inégale) ;
      - coulures : bruit étiré verticalement (coordonnées objet × (22 ; 22 ; 1,2)) qui assombrit en traînées."""
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    tc = N.new("ShaderNodeTexCoord")
    if bump > 0:
        nb = N.new("ShaderNodeTexNoise")
        if "W" in nb.inputs:
            nb.noise_dimensions = "4D"
            nb.inputs["W"].default_value = seed + 11.3
        nb.inputs["Scale"].default_value = bump_scale
        nb.inputs["Detail"].default_value = 6.0
        nb.inputs["Roughness"].default_value = 0.62
        L.new(tc.outputs["Object"], nb.inputs["Vector"])
        bp = N.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        if "Distance" in bp.inputs:
            bp.inputs["Distance"].default_value = 0.02
        L.new(nb.outputs["Fac"], bp.inputs["Height"])
        L.new(bp.outputs["Normal"], p.inputs["Normal"])
    if stain <= 0 and streak <= 0:
        return m
    links = list(p.inputs["Base Color"].links)
    if links:
        src = links[0].from_socket
        L.remove(links[0])
    else:
        rgb = N.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = tuple(p.inputs["Base Color"].default_value)
        src = rgb.outputs[0]
    if stain > 0:
        ns = N.new("ShaderNodeTexNoise")
        if "W" in ns.inputs:
            ns.noise_dimensions = "4D"
            ns.inputs["W"].default_value = seed + 23.1
        ns.inputs["Scale"].default_value = 3.2
        ns.inputs["Detail"].default_value = 4.0
        L.new(tc.outputs["Object"], ns.inputs["Vector"])
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.35
        mr.inputs["From Max"].default_value = 0.65
        mr.inputs["To Min"].default_value = 1.0 - stain
        mr.inputs["To Max"].default_value = 1.0 + 0.5 * stain
        L.new(ns.outputs["Fac"], mr.inputs["Value"])
        vm = N.new("ShaderNodeVectorMath")
        vm.operation = "SCALE"
        L.new(src, vm.inputs[0])
        L.new(mr.outputs["Result"], vm.inputs["Scale"])
        src = vm.outputs["Vector"]
    if streak > 0:
        mp = N.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (22.0, 22.0, 1.2)
        L.new(tc.outputs["Object"], mp.inputs["Vector"])
        nk = N.new("ShaderNodeTexNoise")
        if "W" in nk.inputs:
            nk.noise_dimensions = "4D"
            nk.inputs["W"].default_value = seed + 41.7
        nk.inputs["Scale"].default_value = 1.0
        nk.inputs["Detail"].default_value = 3.0
        L.new(mp.outputs["Vector"], nk.inputs["Vector"])
        mr2 = N.new("ShaderNodeMapRange")
        mr2.inputs["From Min"].default_value = 0.42
        mr2.inputs["From Max"].default_value = 0.66
        mr2.inputs["To Min"].default_value = 1.0 - streak
        mr2.inputs["To Max"].default_value = 1.0
        L.new(nk.outputs["Fac"], mr2.inputs["Value"])
        vm2 = N.new("ShaderNodeVectorMath")
        vm2.operation = "SCALE"
        L.new(src, vm2.inputs[0])
        L.new(mr2.outputs["Result"], vm2.inputs["Scale"])
        src = vm2.outputs["Vector"]
    L.new(src, p.inputs["Base Color"])
    return m


class Kit:
    def __init__(self, S, C, level, flags, gain=1.0):
        import bpy  # noqa: F401  (présent : on est dans Blender)
        self.S, self.C = S, C
        self.level = level
        self.flags = set(flags)
        self.skip_flat = "sil" in self.flags or "mass" in self.flags
        self.skip_tige = "mass" in self.flags
        # émissifs : allumés sauf « -jour » (époques 1-2 de jour)
        self.lit = "jour" not in self.flags
        self.gain = gain
        self._mats = {}
        self._seed = 1.0
        self.objects = []

    # ---------------------------------------------------------------- repère
    @staticmethod
    def P(tx, ty, z=0.0):
        """Point du jeu -> Blender."""
        return (tx, -ty * R2, z)

    def _skip(self, role):
        return (role == "flat" and self.skip_flat) or (role == "tige" and self.skip_tige)

    def _tag(self, o, role):
        if o is None:
            return None
        o["fo_role"] = role
        self.objects.append(o)
        return o

    # ---------------------------------------------------------------- matériaux
    def _next_seed(self):
        self._seed += 1.37
        return self._seed

    # Politique de matière (correction V3 du 22/10) : patine, usure et AO obligatoires (bible §1.5-2). Valeurs
    # réglées par 2 essais d'aperçus rapides (époques 2, 5, 7, 13 ; 7 réglages) :
    #  - relief fin à l'échelle de 2 px (BUMP_SCALE 0,55 × grain_scale) : à 1,6, le relief faisait des pixels
    #    isolés qui scintillent (« sable ») et gonflaient le Laplacien sans détail lisible : refusé ;
    #  - vernis léger (COAT 0,25) : reflets francs sur les arêtes sans blanc pur (à 0,6 : p95 = 255, refusé) ;
    #  - crasse des creux forte aux ères I à III (0,85), plus légère sur les matières claires des ères IV et V.
    GRAIN_MIN = 0.30
    DIRT_MIN = {1: 0.85, 2: 0.85, 3: 0.85, 4: 0.6, 5: 0.6}
    DIRT_LEVEL = {11: 0.4, 15: 0.42}     # matières très claires (alliage blanc, nacre) : salissure légère
    STAIN_LEVEL = {11: 0.14, 15: 0.16}   # (passe 3 : L50 87 pour 100 à l'époque 11, 99 pour 108 à l'époque 15)
    STREAK_LEVEL = {11: 0.10, 15: 0.12}
    STAIN, STREAK, ROUGH_ADD = 0.30, 0.25, -0.15
    # (rouille, ou None = salissure : base assombrie ; part minimale) par ère
    WEAR = {1: ("#5E3E2A", 0.30), 2: ("#4E3426", 0.28), 3: ("#4A3A30", 0.26), 4: (None, 0.16), 5: (None, 0.14)}
    BUMP = {1: 0.42, 2: 0.40, 3: 0.38, 4: 0.34, 5: 0.32}
    BEVEL_MIN = 0.02        # arêtes biseautées : liseré clair des sprites vanilla (reflet du soleil et du zénith)
    BUMP_SCALE = 0.55       # échelle du relief fin, en multiple de grain_scale (traits de 2 px environ)
    COAT = 0.25             # vernis (Coat) des matières patinées : reflets francs
    COAT_ROUGH = 0.22

    def era(self):
        return (self.level - 1) // 3 + 1

    @staticmethod
    def tune():
        """Réglages d'ESSAI (variable d'environnement FO_CENTRE_TUNE = "cle=valeur,..." : bump, grain, dirt,
        stain, streak, gain, rough) : servent aux aperçus rapides de réglage (render_centre.py --only quick) ;
        jamais aux rendus livrés (render_centre.py refuse un rendu complet si la variable existe)."""
        import os
        out = {}
        for kv in os.environ.get("FO_CENTRE_TUNE", "").split(","):
            if "=" in kv:
                key, val = kv.split("=", 1)
                out[key.strip()] = float(val)
        return out

    def metal(self, key, hexcol, rough=0.45, metallic=0.6, grain=0.18, grain_scale=55.0, rust=None,
              rust_amount=0.0, dirt=0.45, gain=None, clean=False, bump=None, stain=None, streak=None):
        """Métal (ou matière si metallic=0) de fo_scene.mat_metal, ENRICHI (enrich). La politique de patine
        s'applique sauf aux accents propres (clean=True : rivets, laiton poli, chromes), qui portent les
        reflets francs."""
        name = "c%02d_%s" % (self.level, key)
        if name in self._mats:
            return self._mats[name]
        T = self.tune()
        import centre_params as PR
        g = (self.gain if gain is None else gain) * T.get("gain", PR.GAIN_MUL[self.level])
        col = scale(srgb(hexcol), g)
        if not clean:
            rough = min(1.0, max(0.05, rough + T.get("rough", self.ROUGH_ADD)))
            grain = max(grain, T.get("grain", self.GRAIN_MIN))
            dirt = max(dirt, T.get("dirt", self.DIRT_LEVEL.get(self.level, self.DIRT_MIN[self.era()])))
            wc, wa = self.WEAR[self.era()]
            if rust is None:
                rust = wc or grime(hexcol)
            rust_amount = max(rust_amount, wa)
        rc = scale(srgb(rust), g) if rust else None
        m = self.S.mat_metal(name, col, rough=rough, metallic=metallic, grain=grain, grain_scale=grain_scale,
                             rust=rc, rust_amount=rust_amount, dirt=dirt, seed=self._next_seed())
        b = (self.BUMP[self.era()] if bump is None else bump) * T.get("bump", 1.0)
        coat = T.get("coat", self.COAT) if not clean else 0.0
        if coat > 0:
            pb = m.node_tree.nodes["Principled BSDF"]
            if "Coat Weight" in pb.inputs:
                pb.inputs["Coat Weight"].default_value = coat
                pb.inputs["Coat Roughness"].default_value = T.get("coat_rough", self.COAT_ROUGH)
        enrich(m, bump=b * (0.5 if clean else 1.0), bump_scale=grain_scale * T.get("bscale", self.BUMP_SCALE),
               stain=(0.06 if clean else T.get("stain", self.STAIN_LEVEL.get(self.level, self.STAIN))) if stain is None else stain,
               streak=(0.0 if clean else T.get("streak", self.STREAK_LEVEL.get(self.level, self.STREAK))) if streak is None
               else streak, seed=self._seed)
        self._mats[name] = m
        return m

    def matte(self, key, hexcol, rough=0.75, grain=0.22, grain_scale=40.0, dirt=0.5, gain=None, **kw):
        """Matière non métallique (bois, toile, pierre, brique, béton, céramique) : grain + crasse des creux."""
        return self.metal(key, hexcol, rough=rough, metallic=0.0, grain=grain, grain_scale=grain_scale, dirt=dirt,
                          gain=gain, **kw)

    def glass(self, key, hexcol, gain=None):
        """Verre stylisé OPAQUE (alpha 1, bible §5 époque 8 : le verre doit compter dans la silhouette) :
        brillant, peu rugueux, non métallique."""
        name = "c%02d_%s" % (self.level, key)
        if name in self._mats:
            return self._mats[name]
        g = self.gain if gain is None else gain
        m = self.S.mat_flat(name, scale(srgb(hexcol), g), rough=0.12, metallic=0.0)
        self._mats[name] = m
        return m

    def clear_glass(self, key, hexcol, transp=0.42, rough=0.06):
        """Verre TRANSLUCIDE (époque 8) : mélange d'un BSDF transparent (part transp) et d'un verre réfléchissant
        teinté : on voit à travers (structure intérieure) et l'alpha d'une paroi reste 1 - transp >= 0,5 (bible
        §5, époque 8 : le verre compte dans la silhouette)."""
        name = "c%02d_%s" % (self.level, key)
        if name in self._mats:
            return self._mats[name]
        import bpy
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        N, L = nt.nodes, nt.links
        p = N["Principled BSDF"]
        c = srgb(hexcol)
        p.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
        p.inputs["Roughness"].default_value = rough
        p.inputs["Metallic"].default_value = 0.0
        if "Coat Weight" in p.inputs:
            p.inputs["Coat Weight"].default_value = 0.6
        tr = N.new("ShaderNodeBsdfTransparent")
        mx = N.new("ShaderNodeMixShader")
        mx.inputs["Fac"].default_value = transp
        out = N["Material Output"]
        for lk in list(out.inputs["Surface"].links):
            L.remove(lk)
        L.new(p.outputs["BSDF"], mx.inputs[1])
        L.new(tr.outputs["BSDF"], mx.inputs[2])
        L.new(mx.outputs["Shader"], out.inputs["Surface"])
        m["fo_kind"] = "surface"
        self._mats[name] = m
        return m

    # Surface lumineuse ÉTEINTE (variante « -jour ») des époques 3 à 15 : presque noire et mate. La couche
    # principale ne porte donc rien de l'éclat ; la lueur draw_as_glow, additive, l'apporte seule. Correction
    # V3 (vérification adverse du 22/10) : avant, main + glow doublaient l'éclat (80 à 96 % des pixels de
    # lueur saturés, blanc pur aux époques 11 et 15, teintes faussées). En jeu, la lueur est toujours dessinée
    # par-dessus (container : aucun état éteint) : la surface éteinte n'est jamais vue seule.
    OFF_LIN = 0.0035

    def emit(self, key, hexcol, strength=1.0, off_hex=None):
        """Surface lumineuse. Époques >= 3 : couleur de cœur CALIBRÉE (centre_params.glow_emission : teinte de
        la bible, luminance du cœur = médiane cible du corps + marge, canal max borné à GLOW_V) ; `strength`
        y est un NIVEAU relatif (1 = cœur calibré). Époques 1-2 (lumière de nuit seulement) : `strength`
        absolu, et off_hex donne la lampe éteinte vue de jour."""
        name = "c%02d_%s%s" % (self.level, key, "" if self.lit else "_off")
        if name in self._mats:
            return self._mats[name]
        import centre_params as PR
        night = self.level in PR.NIGHT_ONLY
        if self.lit:
            if night:
                m = self.S.mat_emissive(name, srgb(hexcol), strength=strength)
            else:
                col, st = PR.glow_emission(self.level, hexcol)
                m = self.S.mat_emissive(name, col, strength=st * strength)
        elif night:
            m = self.S.mat_flat(name, srgb(off_hex) if off_hex else scale(srgb(hexcol), 0.045), rough=0.55,
                                metallic=0.0)
        else:
            m = self.S.mat_flat(name, (self.OFF_LIN,) * 3, rough=1.0, metallic=0.0)
            # aucun reflet spéculaire (passe 1 du 22/10 : le reflet diélectrique de 4 % donnait un gris 28 à 39 sous
            # la lueur, et le composite saturait sur 27 à 66 % des pixels de lueur)
            p = m.node_tree.nodes["Principled BSDF"]
            for key in ("Specular IOR Level", "Specular"):
                if key in p.inputs:
                    p.inputs[key].default_value = 0.0
        self._mats[name] = m
        return m

    # ---------------------------------------------------------------- objets
    def adopt(self, o, mat=None, name=None):
        coll = self.S.piece_collection()
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        if name:
            o.name = name
        if mat is not None:
            o.data.materials.clear()
            o.data.materials.append(mat)
        return o

    def box(self, x0, x1, ty0, ty1, z0, z1, mat, name, bevel=0.012, role="mass", rot_z=0.0):
        """Boîte alignée sur la grille du jeu (étendues en tuiles de jeu, hauteurs en unités)."""
        if self._skip(role):
            return None
        if bevel:
            bevel = max(bevel, self.BEVEL_MIN)
        cx, cty, cz = (x0 + x1) / 2.0, (ty0 + ty1) / 2.0, (z0 + z1) / 2.0
        o = self.S.box((abs(x1 - x0), abs(ty1 - ty0) * R2, abs(z1 - z0)), self.P(cx, cty, cz), mat, name,
                       bevel_w=bevel)
        if rot_z:
            o.rotation_euler = (0, 0, rot_z)
        return self._tag(o, role)

    def bbox(self, cx, cty, cz, sx, sy, sz, mat, name, rot=(0, 0, 0), bevel=0.01, role="mass"):
        """Boîte en unités BLENDER (sx, sy, sz), centrée en un point du jeu, avec rotation libre."""
        if self._skip(role):
            return None
        o = self.S.box((sx, sy, sz), self.P(cx, cty, cz), mat, name, bevel_w=bevel)
        o.rotation_euler = rot
        return self._tag(o, role)

    def cyl(self, tx, ty, r, z0, z1, mat, name, verts=40, r2=None, caps=True, bevel=0.006, role="mass", rot_z=0.0):
        """Cylindre (ou tronc de cône) VERTICAL, rond en 3D, pied en (tx, ty)."""
        if self._skip(role):
            return None
        o = self.S.cylinder(r, z1 - z0, self.P(tx, ty, (z0 + z1) / 2.0), mat, name, verts=verts, bevel_w=bevel,
                            radius2=r2, caps=caps, rot=(0, 0, rot_z))
        return self._tag(o, role)

    def hcyl(self, axis, a0, a1, tx, ty, zc, r, mat, name, verts=32, bevel=0.006, role="mass", r2=None):
        """Cylindre HORIZONTAL : axis 'x' (de x=a0 à a1, à ty) ou 'y' (de ty=a0 à a1, à x=tx)."""
        if self._skip(role):
            return None
        if axis == "x":
            c = self.P((a0 + a1) / 2.0, ty, zc)
            depth = abs(a1 - a0)
            rot = (0, math.pi / 2, 0)
        else:
            c = self.P(tx, (a0 + a1) / 2.0, zc)
            depth = abs(a1 - a0) * R2
            rot = (math.pi / 2, 0, 0)
        o = self.S.cylinder(r, depth, c, mat, name, verts=verts, rot=rot, bevel_w=bevel, radius2=r2)
        return self._tag(o, role)

    def sphere(self, tx, ty, zc, R, mat, name, seg=48, rings=24, sz=1.0, role="mass"):
        if self._skip(role):
            return None
        o = self.S.sphere(R, self.P(tx, ty, zc), mat, name, seg=seg, rings=rings)
        if sz != 1.0:
            o.scale = (1, 1, sz)
        return self._tag(o, role)

    def torus(self, tx, ty, zc, R, r, mat, name, rot=(0, 0, 0), major_seg=72, minor_seg=14, role="mass"):
        if self._skip(role):
            return None
        o = self.S.torus(R, r, self.P(tx, ty, zc), mat, name, rot=rot, major_seg=major_seg, minor_seg=minor_seg)
        return self._tag(o, role)

    def mesh(self, name, verts, faces, mat, smooth=None, bevel=0.0, role="mass"):
        """Maillage libre (sommets Blender), normales recalculées vers l'extérieur."""
        if self._skip(role):
            return None
        import bpy
        import bmesh
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
        me.validate()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
        o = bpy.data.objects.new(name, me)
        self.adopt(o, mat)
        if smooth:
            self.S.smooth(o, smooth)
        if bevel:
            self.S.bevel(o, bevel)
        return self._tag(o, role)

    def loft(self, rings, mat, name, cap0=True, cap1=True, smooth=None, bevel=0.0, role="mass"):
        """Surface qui relie des anneaux de points 3D Blender (même nombre de points, ou 1 point = pointe)."""
        verts, faces, idx = [], [], []
        for ring in rings:
            start = len(verts)
            verts.extend(ring)
            idx.append(list(range(start, start + len(ring))))
        for a, b in zip(idx[:-1], idx[1:]):
            if len(a) == 1 and len(b) == 1:
                continue
            if len(b) == 1:
                for i in range(len(a)):
                    faces.append((a[i], a[(i + 1) % len(a)], b[0]))
            elif len(a) == 1:
                for i in range(len(b)):
                    faces.append((b[(i + 1) % len(b)], b[i], a[0]))
            else:
                n = len(a)
                for i in range(n):
                    faces.append((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
        if cap0 and len(idx[0]) > 2:
            faces.append(tuple(reversed(idx[0])))
        if cap1 and len(idx[-1]) > 2:
            faces.append(tuple(idx[-1]))
        return self.mesh(name, verts, faces, mat, smooth=smooth, bevel=bevel, role=role)

    def prism(self, poly_game, z0, z1, mat, name, top_poly_game=None, bevel=0.01, role="mass", smooth=None):
        """Prisme (ou tronc) vertical : polygone en coordonnées de JEU (x, ty), de z0 à z1 ; le polygone du
        haut peut différer (même nombre de sommets) pour un tronc, un coin, un contrefort."""
        top = top_poly_game or poly_game
        r0 = [self.P(x, ty, z0) for x, ty in poly_game]
        r1 = [self.P(x, ty, z1) for x, ty in top]
        return self.loft([r0, r1], mat, name, bevel=bevel, role=role, smooth=smooth)

    def lathe(self, tx, ty, profile, mat, name, segs=48, smooth=70, role="mass", sx=1.0, sy=1.0):
        """Surface de révolution autour d'un axe vertical en (tx, ty) : profile = [(rayon, z), ...] (unités
        Blender, du bas vers le haut ; rayon 0 = pôle). sx, sy : étirement de la section (ellipse)."""
        cx, cy, _ = self.P(tx, ty, 0)
        rings = []
        for r, z in profile:
            if r <= 1e-6:
                rings.append([(cx, cy, z)])
            else:
                rings.append([(cx + sx * r * math.cos(2 * math.pi * i / segs),
                               cy + sy * r * math.sin(2 * math.pi * i / segs), z) for i in range(segs)])
        return self.loft(rings, mat, name, smooth=smooth, role=role)

    def ngon(self, tx, ty, r, n, z0, z1, mat, name, r_top=None, rot=0.0, sy=1.0, bevel=0.01, role="mass"):
        """Prisme régulier à n côtés (r en unités Blender ; sy étire en profondeur), tronc si r_top."""
        cx, cy, _ = self.P(tx, ty, 0)
        rt = r if r_top is None else r_top

        def ring(rr, z):
            if rr <= 1e-6:
                return [(cx, cy, z)]
            return [(cx + rr * math.cos(rot + 2 * math.pi * i / n), cy + sy * rr * math.sin(rot + 2 * math.pi * i / n), z)
                    for i in range(n)]
        return self.loft([ring(r, z0), ring(rt, z1)], mat, name, bevel=bevel, role=role)

    def rod(self, p0, p1, r, mat, name, verts=10, role="mass", bevel=0.0):
        """Barre cylindrique entre deux points BLENDER (poutres, haubans, pieds, arcs segmentés)."""
        if self._skip(role):
            return None
        from mathutils import Vector
        a, b = Vector(p0), Vector(p1)
        d = b - a
        L = d.length
        o = self.S.cylinder(r, L, tuple((a + b) / 2), mat, name, verts=verts, bevel_w=bevel)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        return self._tag(o, role)

    def join(self, objs, name):
        objs = [o for o in objs if o is not None]
        if not objs:
            return None
        role = objs[0].get("fo_role", "mass")
        for o in objs:
            if o in self.objects:
                self.objects.remove(o)
        j = self.S.join(objs, name)
        return self._tag(j, role)

    def halo(self, tx, ty, z, hexcol, power, radius=0.06, name="halo"):
        """Source ponctuelle de la seule passe halo (draw_as_light)."""
        return self.S.halo_light(self.P(tx, ty, z), srgb(hexcol), power, radius=radius, name=name)

    # ---------------------------------------------------------------- éléments récurrents
    def door(self, x0, x1, ty, z1, frame_mat, leaf_mat, name="porte", depth=0.06, arch=False):
        """Porte centrale au SUD (invariant de famille) : cadre + vantail, plaquée sur une façade à ty."""
        objs = []
        objs.append(self.box(x0 - 0.05, x1 + 0.05, ty - 0.02, ty + depth, 0.0, z1 + 0.06, frame_mat, name + "_cadre",
                             bevel=0.008))
        objs.append(self.box(x0, x1, ty, ty + depth + 0.02, 0.02, z1, leaf_mat, name + "_vantail", bevel=0.006))
        return objs

    def mast(self, tx, ty, z0, z1, r, mat, name="mat", verts=10):
        """Mât de commandement (tige : ne compte pas dans O)."""
        return self.cyl(tx, ty, r, z0, z1, mat, name, verts=verts, bevel=0, role="tige")

    def flag(self, tx, ty, z_top, w, h, mat, name="drapeau", side=1):
        """Drapeau rectangulaire légèrement ondulé, accroché au mât (rôle tige : accessoire du mât)."""
        if self._skip("tige"):
            return None
        cx, cy, _ = self.P(tx, ty, 0)
        n = 6
        verts, faces = [], []
        for i in range(n + 1):
            t = i / n
            x = cx + side * (0.02 + t * w)
            yy = cy + 0.05 * math.sin(t * math.pi * 1.6)
            zz = z_top - 0.03 * t
            verts.append((x, yy, zz))
            verts.append((x, yy, zz - h + 0.04 * t))
        for i in range(n):
            a = 2 * i
            faces.append((a, a + 2, a + 3, a + 1))
        o = self.mesh(name, verts, faces, mat, role="tige")
        if o is not None:
            mod = o.modifiers.new("epais", "SOLIDIFY")
            mod.thickness = 0.012
        return o

    def lattice_mast(self, tx, ty, z0, z1, w0, w1, mat, name="treillis", panels=6, r=0.012):
        """Mât en treillis à 4 montants (tige), largeur w0 en bas, w1 en haut (unités Blender)."""
        if self._skip("tige"):
            return None
        cx, cy, _ = self.P(tx, ty, 0)
        parts = []
        cs = ((-1, -1), (1, -1), (1, 1), (-1, 1))
        for i in range(panels + 1):
            t = i / panels
            z = z0 + (z1 - z0) * t
            w = w0 + (w1 - w0) * t
            pts = [(cx + sx * w / 2, cy + sy * w / 2, z) for sx, sy in cs]
            if i < panels:
                t2 = (i + 1) / panels
                z2 = z0 + (z1 - z0) * t2
                w2 = w0 + (w1 - w0) * t2
                pts2 = [(cx + sx * w2 / 2, cy + sy * w2 / 2, z2) for sx, sy in cs]
                for k in range(4):
                    parts.append(self.rod(pts[k], pts2[k], r * 1.3, mat, "%s_m%d_%d" % (name, i, k), verts=6, role="tige"))
                    parts.append(self.rod(pts[k], pts2[(k + 1) % 4], r * 0.8, mat, "%s_d%d_%d" % (name, i, k), verts=6,
                                          role="tige"))
            for k in range(4):
                parts.append(self.rod(pts[k], pts[(k + 1) % 4], r * 0.8, mat, "%s_h%d_%d" % (name, i, k), verts=6,
                                      role="tige"))
        return self.join(parts, name)

    def rivets_line(self, p0, p1, n, r, mat, name):
        """Rangée de rivets (demi-sphères) entre deux points Blender."""
        objs = []
        for i in range(n):
            t = (i + 0.5) / n
            p = tuple(a + (b - a) * t for a, b in zip(p0, p1))
            objs.append(self.S.sphere(r, p, mat, "%s_%d" % (name, i), seg=10, rings=5))
        for o in objs:
            self._tag(o, "mass")
        return self.join(objs, name)

    def railing(self, pts_game, z, h, mat, name, posts_every=0.35, r=0.008):
        """Garde-corps (tige fine) le long d'une polyligne de jeu, à la hauteur z."""
        parts = []
        P = [self.P(x, ty, z) for x, ty in pts_game]
        for a, b in zip(P[:-1], P[1:]):
            parts.append(self.rod((a[0], a[1], a[2] + h), (b[0], b[1], b[2] + h), r, mat, name + "_main", verts=6, role="tige"))
            parts.append(self.rod((a[0], a[1], a[2] + h * 0.5), (b[0], b[1], b[2] + h * 0.5), r * 0.8, mat, name + "_mi",
                                  verts=6, role="tige"))
            L = math.dist(a[:2], b[:2])
            n = max(1, int(L / posts_every))
            for i in range(n + 1):
                t = i / n
                p = tuple(u + (v - u) * t for u, v in zip(a, b))
                parts.append(self.rod(p, (p[0], p[1], p[2] + h), r, mat, name + "_p", verts=6, role="tige"))
        return self.join(parts, name)

    # ---------------------------------------------------------------- détail de surface (correction V3 du 22/10)
    # La vérification adverse du 22/10 a mesuré un Laplacien moyen de 6,9 à 22,8 sur les corps (roboport
    # vanilla 31,2) : grandes faces lisses. Ces aides posent des plaques biseautées, des nervures, des bandes,
    # des grilles et des goujons en UN maillage chacune (rapide), sans toucher à la silhouette.
    def _plates(self, name, rects, origin, U, V, Nn, thick, mat, bevel=0.007, role="mass"):
        """Plaques minces posées sur un plan : rects = [(u0, u1, v0, v1)] dans le repère (origin, U, V) Blender,
        épaisseur `thick` selon la normale Nn (vecteurs unitaires). Un seul maillage."""
        if self._skip(role) or not rects:
            return None
        verts, faces = [], []
        for (u0, u1, v0, v1) in rects:
            b = len(verts)
            for (u, v) in ((u0, v0), (u1, v0), (u1, v1), (u0, v1)):
                for t in (0.0, thick):
                    verts.append(tuple(origin[i] + U[i] * u + V[i] * v + Nn[i] * t for i in range(3)))

            def f(c, t, b=b):
                return b + 2 * c + t
            faces.append((f(0, 0), f(3, 0), f(2, 0), f(1, 0)))
            faces.append((f(0, 1), f(1, 1), f(2, 1), f(3, 1)))
            for c in range(4):
                d = (c + 1) % 4
                faces.append((f(c, 0), f(d, 0), f(d, 1), f(c, 1)))
        return self.mesh(name, verts, faces, mat, bevel=bevel, role=role)

    @staticmethod
    def _grid(w, h, nu, nv, gap, margin):
        cu = (w - 2 * margin - (nu - 1) * gap) / nu
        cv = (h - 2 * margin - (nv - 1) * gap) / nv
        out = []
        for i in range(nu):
            for j in range(nv):
                u0 = margin + i * (cu + gap)
                v0 = margin + j * (cv + gap)
                out.append((u0, u0 + cu, v0, v0 + cv))
        return out

    def panels(self, x0, x1, ty0, ty1, z0, z1, mat, name, top=(3, 2), south=(3, 2), gap=0.035, thick=0.016,
               margin=0.03, bevel=0.007, skip=None, role="mass"):
        """Plaques rapportées sur la face du DESSUS (top = (n en x, n en ty)) et la face SUD (south = (n en x,
        n en z)) d'une boîte de jeu (x0..x1, ty0..ty1, z0..z1) : joints creux entre plaques biseautées.
        skip(face, xa, xb, a, b) -> True laisse un trou (face 'top' : a, b en ty ; 'south' : en z)."""
        objs = []
        if top:
            ox, oy, _ = self.P(x0, ty1, 0)
            rects = self._grid(x1 - x0, (ty1 - ty0) * R2, top[0], top[1], gap, margin)
            if skip:
                rects = [r for r in rects if not skip("top", x0 + r[0], x0 + r[1], ty1 - r[3] / R2, ty1 - r[2] / R2)]
            objs.append(self._plates(name + "_dessus", rects, (ox, oy, z1), (1, 0, 0), (0, 1, 0), (0, 0, 1), thick, mat,
                                     bevel, role))
        if south:
            ox, oy, _ = self.P(x0, ty1, 0)
            rects = self._grid(x1 - x0, z1 - z0, south[0], south[1], gap, margin)
            if skip:
                rects = [r for r in rects if not skip("south", x0 + r[0], x0 + r[1], z0 + r[2], z0 + r[3])]
            objs.append(self._plates(name + "_sud", rects, (ox, oy, z0), (1, 0, 0), (0, 0, 1), (0, -1, 0), thick, mat,
                                     bevel, role))
        return objs

    def louvres(self, x0, x1, ty, z0, z1, n, mat, name, depth=0.03, role="mass"):
        """Grille d'aération : n lames horizontales sur une face sud (ty), en relief de `depth`."""
        ox, oy, _ = self.P(x0, ty, 0)
        h = (z1 - z0) / n
        rects = [(0.0, x1 - x0, i * h, i * h + h * 0.55) for i in range(n)]
        return self._plates(name, rects, (ox, oy, z0), (1, 0, 0), (0, 0, 1), (0, -1, 0), depth, mat, 0.004, role)

    def ribs(self, tx, ty, r, z0, z1, n, mat, name, w=0.035, d=0.022, a0=math.pi, a1=2 * math.pi, role="mass"):
        """Nervures verticales sur un cylindre vertical (rayon r, Blender), réparties de l'angle a0 à a1 (la
        demi-face tournée vers la caméra, au sud, par défaut). Un seul maillage."""
        if self._skip(role):
            return None
        cx, cy, _ = self.P(tx, ty, 0)
        verts, faces = [], []
        for i in range(n):
            a = a0 + (a1 - a0) * (i + 0.5) / n
            c, s = math.cos(a), math.sin(a)
            tg = (-s, c)
            b = len(verts)
            for (rr, ww) in ((r - 0.004, -w / 2), (r - 0.004, w / 2), (r + d, w / 2), (r + d, -w / 2)):
                for z in (z0, z1):
                    verts.append((cx + c * rr + tg[0] * ww, cy + s * rr + tg[1] * ww, z))

            def f(k, t, b=b):
                return b + 2 * k + t
            for k in range(4):
                q = (k + 1) % 4
                faces.append((f(k, 0), f(q, 0), f(q, 1), f(k, 1)))
            faces.append((f(0, 0), f(3, 0), f(2, 0), f(1, 0)))
            faces.append((f(0, 1), f(1, 1), f(2, 1), f(3, 1)))
        return self.mesh(name, verts, faces, mat, bevel=0.004, role=role)

    def bands(self, tx, ty, r, zs, mat, name, minor=0.018, role="mass"):
        """Cerclages (tores) autour d'un cylindre vertical de rayon r, aux hauteurs zs."""
        objs = [self.torus(tx, ty, z, r + minor * 0.4, minor, mat, "%s_%d" % (name, i), minor_seg=8, role=role)
                for i, z in enumerate(zs)]
        return self.join(objs, name)

    def studs(self, pts, r, mat, name, h=None, sides=6, role="mass"):
        """Goujons, boulons, rivets : petits prismes à `sides` pans posés aux points Blender, axe selon la
        normale donnée (pts = [((x, y, z), (nx, ny, nz))]). Un seul maillage (rapide)."""
        if self._skip(role) or not pts:
            return None
        hh = r * 0.8 if h is None else h
        verts, faces = [], []
        for (p, n) in pts:
            a = (1.0, 0.0, 0.0) if abs(n[0]) < 0.9 else (0.0, 1.0, 0.0)
            u = (n[1] * a[2] - n[2] * a[1], n[2] * a[0] - n[0] * a[2], n[0] * a[1] - n[1] * a[0])
            lu = math.sqrt(sum(x * x for x in u))
            u = tuple(x / lu for x in u)
            v = (n[1] * u[2] - n[2] * u[1], n[2] * u[0] - n[0] * u[2], n[0] * u[1] - n[1] * u[0])
            b = len(verts)
            for t, rr in ((0.0, r), (hh, r * 0.7)):
                for k in range(sides):
                    ang = 2 * math.pi * k / sides
                    verts.append(tuple(p[i] + n[i] * t + rr * (math.cos(ang) * u[i] + math.sin(ang) * v[i])
                                       for i in range(3)))
            for k in range(sides):
                q = (k + 1) % sides
                faces.append((b + k, b + q, b + sides + q, b + sides + k))
            faces.append(tuple(b + sides + k for k in range(sides)))
            faces.append(tuple(b + k for k in reversed(range(sides))))
        return self.mesh(name, verts, faces, mat, role=role)

    def stud_row(self, x0, x1, ty, z, n, r, mat, name, face="south", role="mass"):
        """Rangée de n goujons entre x0 et x1, sur une face sud (en ty, à la hauteur z) ou du dessus (z)."""
        pts = []
        for i in range(n):
            x = x0 + (x1 - x0) * (i + 0.5) / n
            px, py, _ = self.P(x, ty, 0)
            pts.append(((px, py, z), (0.0, -1.0, 0.0) if face == "south" else (0.0, 0.0, 1.0)))
        return self.studs(pts, r, mat, name, role=role)

    def ring_studs(self, tx, ty, r, z, n, rr, mat, name, a0=math.pi, a1=2 * math.pi, role="mass"):
        """Goujons en couronne sur un cylindre vertical (demi-face sud par défaut)."""
        cx, cy, _ = self.P(tx, ty, 0)
        pts = []
        for i in range(n):
            a = a0 + (a1 - a0) * (i + 0.5) / n
            pts.append(((cx + r * math.cos(a), cy + r * math.sin(a), z), (math.cos(a), math.sin(a), 0.0)))
        return self.studs(pts, rr, mat, name, role=role)

    def sphere_seams(self, tx, ty, zc, R, mat, name, lats=(-0.5, 0.0, 0.5), mers=6, minor=0.014, sz=1.0,
                     role="mass"):
        """Coutures d'une sphère (ou d'un sphéroïde aplati sz) : parallèles aux latitudes `lats` (radians) et
        `mers` méridiens."""
        objs = []
        for i, lat in enumerate(lats):
            objs.append(self.torus(tx, ty, zc + R * sz * math.sin(lat), R * math.cos(lat) + minor * 0.3, minor, mat,
                                   "%s_par_%d" % (name, i), minor_seg=6, role=role))
        for j in range(mers):
            a = math.pi * j / mers
            o = self.torus(tx, ty, zc, R + minor * 0.3, minor, mat, "%s_mer_%d" % (name, j), rot=(math.pi / 2, 0, a),
                           minor_seg=6, role=role)
            if o is not None and sz != 1.0:
                o.scale = (1, 1, sz)
            objs.append(o)
        return self.join(objs, name)

    def sphere_tiles(self, tx, ty, zc, R, mat, name, lat0=-0.3, lat1=1.2, nlat=6, lon0=math.pi, lon1=2 * math.pi, nlon=16,
                     gap=0.12, thick=0.014, role="mass"):
        """Tuiles en relief sur une sphère (protection thermique, plaques) : cellules de latitude lat0..lat1 et de
        longitude lon0..lon1 (radians, Blender), jointes par un creux (gap = part de la cellule). Un seul maillage."""
        if self._skip(role):
            return None
        cx, cy, _ = self.P(tx, ty, 0)
        verts, faces = [], []

        def pt(lat, lon, rr):
            return (cx + rr * math.cos(lat) * math.cos(lon), cy + rr * math.cos(lat) * math.sin(lon), zc + rr * math.sin(lat))
        dl, dn = (lat1 - lat0) / nlat, (lon1 - lon0) / nlon
        for i in range(nlat):
            for j in range(nlon):
                la0, la1 = lat0 + (i + gap / 2) * dl, lat0 + (i + 1 - gap / 2) * dl
                off = 0.5 * dn if i % 2 else 0.0
                lo0, lo1 = lon0 + off + (j + gap / 2) * dn, lon0 + off + (j + 1 - gap / 2) * dn
                b = len(verts)
                for rr in (R - 0.004, R + thick):
                    verts += [pt(la0, lo0, rr), pt(la0, lo1, rr), pt(la1, lo1, rr), pt(la1, lo0, rr)]
                faces.append((b, b + 3, b + 2, b + 1))
                faces.append((b + 4, b + 5, b + 6, b + 7))
                for k in range(4):
                    q = (k + 1) % 4
                    faces.append((b + k, b + q, b + 4 + q, b + 4 + k))
        return self.mesh(name, verts, faces, mat, bevel=0.004, role=role)
