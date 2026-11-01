"""ÈRE V STELLAIRE : ce que les QG des âges 13 et 14 partagent (lot QG, série du 31/10). Cousins de l'âge 15 validé :
même carcasse (ere5_vaisseau.py, copie corrigée de l15_vaisseau.py : crâne en coin, nacelles, dérive, cœur), mêmes pièces (greb.py), même pose (lacet de −8°,
roulis de 10°). Ici : la pose, les matières communes, les tuiles posées sur une sphère, la feuille froissée, les pylônes,
les menus détails, le chargement des ponts.
"""
import math

import geo as G
import greb as R
import ere5_vaisseau as N
import mat as MT

PSI = -math.radians(8.0)        # lacet : nez vers le sud-est
PHI = math.radians(10.0)        # roulis du vaisseau : dos vers la caméra
OY = -0.5                       # tout le sol dans l'emprise 16×8
CAM = (0.0, -0.7071, 0.7071)


def F_sol(v):
    return (v[0], v[1], max(0.0, v[2]))


def F_pal(v):
    p = G.rot_z(v, PSI)
    return (p[0], p[1] + OY, max(0.0, p[2]))


def fait_F_nav(zs):
    def F_nav(v):
        p = G.rot_z(G.rot_x(v, PHI, (0.0, 0.0, zs)), PSI)
        return (p[0], p[1] + OY, max(0.0, p[2]))
    return F_nav


def sc(poly, k, c=None):
    if c is None:
        c = (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
    return [(c[0] + (p[0] - c[0]) * k, c[1] + (p[1] - c[1]) * k) for p in poly]


def rect(x, y, w, h=None):
    h = w if h is None else h
    return [(x - w, y - h), (x + w, y - h), (x + w, y + h), (x - w, y + h)]


def lumiere_degrade(S, name, coeur, mi, bord, force=0.8, main=0.35):
    """Surface lumineuse À DÉGRADÉ (critique du 1/11 : « aucune surface émissive sans dégradé ») : cœur clair face à la caméra,
    bord sombre en incidence rasante ; veut une surface bombée (tube, sphère, lentille). Aperçu hors Blender : couleur mi."""
    m = MT.lumiere(S, name, mi, force, main=main)
    if not hasattr(m, "node_tree"):
        return m
    N_, L = m.node_tree.nodes, m.node_tree.links
    lw = N_.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    ra = N_.new("ShaderNodeValToRGB")
    els = ra.color_ramp.elements
    els[0].position, els[1].position = 0.0, 0.88
    els[0].color, els[1].color = (coeur[0], coeur[1], coeur[2], 1.0), (bord[0], bord[1], bord[2], 1.0)
    e = els.new(0.34)
    e.color = (mi[0], mi[1], mi[2], 1.0)
    L.new(lw.outputs["Facing"], ra.inputs["Fac"])
    L.new(ra.outputs["Color"], N_["Principled BSDF"].inputs["Emission Color"])
    return m


def anneau(c, Rr, m, a0=0.0, a1=G.TAU, na=12, nm=14):
    """Secteur de tore d'axe z, de rayon Rr, de section m."""
    rings = []
    for i in range(na + 1):
        t = a0 + (a1 - a0) * i / na
        u = (math.cos(t), math.sin(t))
        rings.append([(c[0] + (Rr + m * math.cos(G.TAU * j / nm)) * u[0], c[1] + (Rr + m * math.cos(G.TAU * j / nm)) * u[1], c[2] + m * math.sin(G.TAU * j / nm))
                      for j in range(nm)])
    return G.loft(rings, cap0=True, cap1=True)


def froisse(name, col, **kw):
    """Surface à FEUILLE FROISSÉE (bible §5, époque 14 : « jamais lisse ») : grandes facettes de Voronoï dans le relief et
    dans la valeur (critique du 1/11 : facettes 3 fois plus grandes, le scintillement fin faisait du bruit au zoom 1).
    Dans l'aperçu hors Blender : surface simple."""
    m = MT.surface(name, col, **kw)
    if not hasattr(m, "node_tree"):
        return m
    N_, L = m.node_tree.nodes, m.node_tree.links
    p = N_["Principled BSDF"]
    tc = N_.new("ShaderNodeTexCoord")
    v1 = N_.new("ShaderNodeTexVoronoi")
    v1.inputs["Scale"].default_value = 3.7
    v2 = N_.new("ShaderNodeTexVoronoi")
    v2.inputs["Scale"].default_value = 10.0
    L.new(tc.outputs["Object"], v1.inputs["Vector"])
    L.new(tc.outputs["Object"], v2.inputs["Vector"])
    # valeur par facette (la grande échelle domine) : ± 18 %
    sep = N_.new("ShaderNodeSeparateColor")
    L.new(v1.outputs["Color"], sep.inputs["Color"])
    sep2 = N_.new("ShaderNodeSeparateColor")
    L.new(v2.outputs["Color"], sep2.inputs["Color"])
    k = MT._range(N_, L, MT._math(N_, L, "ADD", MT._math(N_, L, "MULTIPLY", sep.outputs[0], 0.7), MT._math(N_, L, "MULTIPLY", sep2.outputs[0], 0.3)),
                  0.15, 0.85, 0.82, 1.18)
    base_l = p.inputs["Base Color"].links
    if base_l:
        s = base_l[0].from_socket
        L.new(MT._scale(N_, L, s, k), p.inputs["Base Color"])
    # relief : plis
    h = MT._math(N_, L, "ADD", v1.outputs["Distance"], MT._math(N_, L, "MULTIPLY", v2.outputs["Distance"], 0.45))
    bp = N_.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.45
    bp.inputs["Distance"].default_value = 0.14
    L.new(h, bp.inputs["Height"])
    nl = p.inputs["Normal"].links
    if nl:
        L.new(nl[0].from_socket, bp.inputs["Normal"])
    L.new(bp.outputs["Normal"], p.inputs["Normal"])
    return m


def feuille(p0, ex, ey, w, h, rnd, amp=0.03, pas=0.14):
    """Feuille plissée (maille) : rectangle de p0 selon ex × w, ey × h, sommets déplacés le long de la normale."""
    ez = G.norm(G.cross(ex, ey))
    nx, ny = max(2, int(w / pas)), max(2, int(h / pas))
    rings = []
    for i in range(nx + 1):
        rg = []
        for j in range(ny + 1):
            bord = 0.3 if i in (0, nx) or j in (0, ny) else 1.0
            d = rnd.f(-amp, amp) * bord
            q = G.add(G.add(p0, G.mul(ex, w * i / nx)), G.mul(ey, h * j / ny))
            rg.append(G.add(q, G.mul(ez, d)))
        rings.append(rg)
    return G.loft(rings, closed=False)


def sph_pt(c, Rr):
    def f(lat, lon, g=0.0):
        r = Rr + g
        cl = math.cos(lat)
        return (c[0] + r * cl * math.cos(lon), c[1] + r * cl * math.sin(lon), c[2] + r * math.sin(lat))
    f.rayon = Rr
    return f


def tuiles_sphere(lot, surf, lats, pas, mats, rnd, xf, gap=0.018, g=(0.012, 0.045), saut=None, Mriv=None):
    """Tuiles de céramique sur une sphère, par bandes de latitude ; bords décalés d'une bande à l'autre, largeurs inégales
    (jamais de grille), face cachée sautée. `lats` : limites des bandes ; `pas` : largeur moyenne en unités."""
    n = 0
    Rr = surf.rayon
    for bi in range(len(lats) - 1):
        la0, la1 = lats[bi], lats[bi + 1]
        lam = (la0 + la1) / 2
        c = max(0.12, math.cos(lam))
        lon = rnd.f(0.0, 0.5)
        lon_fin = lon + G.TAU
        while lon < lon_fin - 1e-6:
            d = pas * rnd.f(0.55, 1.5) / (Rr * c)
            l1 = min(lon_fin, lon + d)
            lo = (lon + l1) / 2
            q = surf(lam, lo, 0.0)
            o = surf(lam, lo, -Rr)
            nrm = G.norm(G.sub(q, o))
            if G.dot(nrm, CAM) > -0.25 and not (saut and saut(lam, lo)):
                gg = rnd.f(*g)
                dl = gap / (Rr * c)
                da = gap / Rr
                lot.put(mats(rnd, lam, lo), N.patch(surf, la0 + da / 2, la1 - da / 2, lon + dl / 2, l1 - dl / 2, gg, 2, 3), xf)
                n += 1
                if Mriv is not None and rnd.f() < 0.28:
                    pts = []
                    for a, b in ((la0 + 2.2 * da, lon + 2.2 * dl), (la1 - 2.2 * da, l1 - 2.2 * dl)):
                        pts.append((surf(a, b, gg + 0.002), nrm))
                    lot.put(Mriv, G.rivets_le_long(pts, 0.016, 0.01), xf)
            lon = l1
    R.compte("toles", n)


def pylone(lot, M, x, y, z0, h, r, lum=True, xf=None):
    """Pylône de champ ou d'amarrage (cousin direct de ceux de l'âge 15) : dé, fût effilé, panneau clair, colliers, pointe."""
    xf = xf or F_sol
    lot.put(M["pierre2"], G.prisme(rect(x, y, 0.4), z0 - 0.02, z0 + 0.3, top_scale=0.85), xf)
    lot.put(M["bronze"], G.prisme(rect(x, y, 0.27), z0 + 0.3, h, top_scale=0.55), xf)
    lot.put(M["nacre"], G.boite((x, y - 0.23, z0 + 0.3 + (h - z0 - 0.3) * 0.45), (0.2, 0.04, (h - z0 - 0.3) * 0.5), rx=0.08), xf)
    lot.put(M["or"], G.prisme(rect(x, y, 0.17), h, h + 0.4, top_scale=0.05), xf)
    for k in range(2):
        lot.put(M["or_sombre"], G.boite((x, y, z0 + 0.65 + k * 0.55), (0.53 - 0.08 * k, 0.53 - 0.08 * k, 0.06)), xf)
    R.mat_antenne(lot, M["or_sombre"], M["bronze"], M["balise"], (x + 0.12, y + 0.1, h + 0.1), 0.65, r, xf=xf, lum=lum)
    R.compte("pylones")


def terrasses(lot, M, liste, r, xf=None):
    xf = xf or F_sol
    for poly0, h in liste:
        poly = sc(poly0, 0.95)
        lot.put(M["pierre2"], G.prisme(poly, 0.0, h - 0.07, top_scale=0.985), xf)
        lot.put(M["pierre"], G.prisme(sc(poly, 0.965), h - 0.07, h, top_scale=0.985), xf)
        n = len(poly)
        best = max(range(n), key=lambda i: -abs(poly[i][1] + poly[(i + 1) % n][1]))
        a, b = poly[best], poly[(best + 1) % n]
        lot.put(M["or_sombre"], G.boite(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, h - 0.035), (math.hypot(b[0] - a[0], b[1] - a[1]) * 0.9, 0.05, 0.035),
                                        rz=math.atan2(b[1] - a[1], b[0] - a[0])), xf)


def chargement(lot, M, r, zones):
    """Caisses, fûts, bollards, trappes, conduits au ras du sol ; zones : (xf, z, (x0, x1), (y0, y1), n)."""
    for (xf, z, xr, yr, n) in zones:
        for k in range(n):
            x, y = r.f(*xr), r.f(*yr)
            u = r.f()
            rz = r.f(-0.5, 0.5)
            if u < 0.28:
                R.caisse(lot, M["bois"] if k % 3 else M["acier"], M["acier"], (x, y, z), (r.f(0.18, 0.34), r.f(0.16, 0.3), 0.26), rz, xf=xf)
            elif u < 0.48:
                R.fut(lot, M["cuivre"] if k % 2 else M["bronze"], M["or_sombre"], (x, y, z), r.f(0.07, 0.1), r.f(0.2, 0.3), couche=(k % 5 == 0), rz=rz, xf=xf)
            elif u < 0.68:
                lot.put(M["acier"], G.tour([(z, 0.06), (z + 0.14, 0.05), (z + 0.17, 0.075), (z + 0.2, 0.0)], 8, "z", (x, y, 0.0), cap0=True), xf)
            elif u < 0.86:
                lot.put(M["or_sombre"], G.boite((x, y, z + 0.015), (0.36, 0.26, 0.03), rz), xf)
                lot.put(M["noyau"], G.boite((x, y, z + 0.032), (0.28, 0.18, 0.006), rz), xf)
            else:
                R.tuyau(lot, M["cuivre"] if k % 2 else M["acier"], M["or_sombre"], [(x, y, z + 0.09), (x + r.f(0.3, 0.7), y + r.f(-0.1, 0.1), z + 0.09)], 0.04, xf=xf)


def menus(lot, mats, r, zones):
    """Menus détails de 3 à 10 px, clairs et sombres, sur les pans nus ; zones : (xf, z, (x0, x1), (y0, y1), n)."""
    for (xf, z, xr, yr, n) in zones:
        for k in range(n):
            lot.put(mats[k % len(mats)], G.boite((r.f(*xr), r.f(*yr), z + 0.015), (r.f(0.05, 0.15), r.f(0.04, 0.11), 0.05), r.f(-0.5, 0.5)), xf)


def jambe(lot, Mf, Mp, Mc, Mse, a, b, r_f=0.3, r_p=0.17):
    """Jambe télescopique de a (pied) à b (tête) : fourreau effilé, tige, colliers. xf par défaut du lot."""
    m = G.lerp(a, b, 0.62)
    d = G.norm(G.sub(b, a))
    L = G.length(G.sub(m, a))
    lot.put(Mf, G.oriente(G.tour([(0.0, r_f), (0.1, r_f * 1.1), (0.16, r_f), (L * 0.5, r_f * 0.92), (L * 0.52, r_f), (L * 0.56, r_f * 0.92), (L, r_f * 0.8),
                                  (L + 0.04, r_p * 1.2)], 16, "z", cap0=True, cap1=True), a, d))
    lot.put(Mp, G.tube([m, b], r_p, 14))
    for t in (0.72, 0.84, 0.95):
        q = G.lerp(a, b, t)
        lot.put(Mc, G.oriente(G.tour([(-0.03, r_p * 1.25), (0.03, r_p * 1.25)], 14, "z", cap0=True, cap1=True), q, d))
    lot.put(Mse, G.oriente(G.tour([(-0.05, r_f * 1.3), (0.05, r_f * 1.3)], 14, "z", cap0=True, cap1=True), G.lerp(a, b, 0.2), d))
