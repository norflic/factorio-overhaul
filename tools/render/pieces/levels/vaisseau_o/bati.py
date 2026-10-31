"""ARCHITECTURE du kit vaisseau_o (lot CENTRE-OPUS) : murs percés de baies (encadrement, appui, linteau, vitre en
retrait), toitures à deux pans (joints debout, faîtage, rives), escaliers, garde-corps, poteaux. Tout est posé le long
d'un mur ALIGNÉ sur X ou sur Y (les bâtiments du centre-vaisseau sont orthogonaux).
"""
import geo as G


def mur(lot, M, Mcadre, Mvitre, axe, c, l0, l1, z0, z1, ep, baies=(), cote=-1, Mlinteau=None, appui=True):
    """Mur le long de l'axe « x » (c = y du plan du mur) ou « y » (c = x), de l0 à l1, entre z0 et z1.
    baies = [(centre, largeur, z_bas, z_haut)] ; cote = côté de la face vue (−1 : vers −y ou −x)."""
    def box(a0, a1, zz0, zz1, m, dep=0.0, e=None):
        e = ep if e is None else e
        if a1 - a0 <= 1e-4 or zz1 - zz0 <= 1e-4:
            return
        ca, cz = (a0 + a1) / 2, (zz0 + zz1) / 2
        cc = c + cote * dep
        if axe == "x":
            lot.put(m, G.boite((ca, cc, cz), (a1 - a0, e, zz1 - zz0)))
        else:
            lot.put(m, G.boite((cc, ca, cz), (e, a1 - a0, zz1 - zz0)))
    bs = sorted(baies)
    a = l0
    for (bc, bw, zb, zh) in bs:
        b0, b1 = bc - bw / 2, bc + bw / 2
        box(a, b0, z0, z1, M)
        box(b0, b1, z0, zb, M)
        box(b0, b1, zh, z1, M)
        # vitre en retrait, encadrement, appui, linteau
        box(b0, b1, zb, zh, Mvitre, dep=-ep * 0.25, e=ep * 0.3)
        f = 0.045
        box(b0 - f, b0, zb - f, zh + f, Mcadre, dep=0.02, e=ep + 0.03)
        box(b1, b1 + f, zb - f, zh + f, Mcadre, dep=0.02, e=ep + 0.03)
        box(b0 - f, b1 + f, zh, zh + f, Mlinteau or Mcadre, dep=0.03, e=ep + 0.05)
        if appui:
            box(b0 - f * 1.6, b1 + f * 1.6, zb - f * 1.2, zb, Mcadre, dep=0.06, e=ep + 0.12)
        box((b0 + b1) / 2 - 0.012, (b0 + b1) / 2 + 0.012, zb, zh, Mcadre, dep=0.0, e=ep * 0.5)
        a = b1
    box(a, l1, z0, z1, M)


def toit(lot, M, Mfaite, x0, x1, y0, y1, ze, zf, debord=0.12, joints=0.28, ep=0.05, Mjoint=None):
    """Toit à deux pans le long de X (faîtage à mi-largeur), avec joints debout tous les « joints » et faîtière."""
    ym = (y0 + y1) / 2
    for (ya, yb) in ((y0 - debord, ym), (y1 + debord, ym)):
        za = ze - debord * (zf - ze) / abs(ym - y0)
        quad_top = [(x0 - debord, ya, za + ep), (x1 + debord, ya, za + ep), (x1 + debord, yb, zf + ep), (x0 - debord, yb, zf + ep)]
        quad_bot = [(x0 - debord, ya, za), (x1 + debord, ya, za), (x1 + debord, yb, zf), (x0 - debord, yb, zf)]
        lot.put(M, G.loft([quad_bot, quad_top], closed=True))
        lot.put(M, (quad_top, [(0, 1, 2, 3)], [(p[0], p[1] + p[2]) for p in quad_top]))
        lot.put(M, (list(reversed(quad_bot)), [(0, 1, 2, 3)], [(p[0], p[1] + p[2]) for p in quad_bot]))
        if joints:
            n = int((x1 - x0 + 2 * debord) / joints)
            for i in range(1, n):
                x = x0 - debord + (x1 - x0 + 2 * debord) * i / n
                lot.put(Mjoint or M, G.tube([(x, ya, za + ep + 0.012), (x, yb, zf + ep + 0.012)], 0.018, 4))
    lot.put(Mfaite, G.tube([(x0 - debord - 0.03, ym, zf + ep + 0.02), (x1 + debord + 0.03, ym, zf + ep + 0.02)], 0.05, 8))
    # pignons (triangles) aux deux bouts
    for x in (x0, x1):
        tri = [(x, y0, ze), (x, y1, ze), (x, ym, zf)]
        lot.put(M, (tri, [(0, 1, 2)], [(p[1], p[2]) for p in tri]))


def escalier(lot, M, p0, p1, larg, n, Mrampe=None):
    """Escalier droit de p0 (bas) à p1 (haut) ; marches pleines ; rampe facultative."""
    d = G.sub(p1, p0)
    horiz = G.norm((d[0], d[1], 0.0))
    lat = (-horiz[1], horiz[0], 0.0)
    for i in range(n):
        t = (i + 0.5) / n
        q = G.lerp(p0, p1, t)
        sz = (abs(horiz[0]) * G.length((d[0], d[1], 0)) / n + abs(lat[0]) * larg + 0.01,
              abs(horiz[1]) * G.length((d[0], d[1], 0)) / n + abs(lat[1]) * larg + 0.01, d[2] / n)
        lot.put(M, G.boite((q[0], q[1], q[2] - d[2] / n / 2), sz))
    if Mrampe is not None:
        for s in (-0.5, 0.5):
            a = G.add(p0, G.mul(lat, s * larg))
            b = G.add(p1, G.mul(lat, s * larg))
            lot.put(Mrampe, G.tube([G.add(a, (0, 0, 0.45)), G.add(b, (0, 0, 0.45))], 0.018, 6))
            for t in (0.0, 0.5, 1.0):
                q = G.lerp(a, b, t)
                lot.put(Mrampe, G.tube([q, G.add(q, (0, 0, 0.45))], 0.016, 6))


def garde_corps(lot, M, pts, h=0.42, pas=0.4, r=0.016):
    """Garde-corps le long d'une polyligne au sol (main courante + lisse + montants)."""
    hand = [G.add(p, (0, 0, h)) for p in pts]
    mid = [G.add(p, (0, 0, h * 0.5)) for p in pts]
    lot.put(M, G.tube(hand, r * 1.2, 6, cap0=True, cap1=True))
    lot.put(M, G.tube(mid, r * 0.8, 6, cap0=True, cap1=True))
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = max(1, int(G.length(G.sub(b, a)) / pas))
        for j in range(n + (1 if i == len(pts) - 2 else 0)):
            q = G.lerp(a, b, j / float(n))
            lot.put(M, G.tube([q, G.add(q, (0, 0, h))], r, 6))


def plancher(lot, M, x0, x1, y0, y1, z, ep=0.05, Mpoutre=None, pas_poutre=0.6):
    lot.put(M, G.boite(((x0 + x1) / 2, (y0 + y1) / 2, z - ep / 2), (x1 - x0, y1 - y0, ep)))
    if Mpoutre is not None:
        n = max(1, int((x1 - x0) / pas_poutre))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            lot.put(Mpoutre, G.boite((x, (y0 + y1) / 2, z - ep - 0.05), (0.08, y1 - y0, 0.1)))


def pieu(lot, M, x, y, z0, z1, r=0.06, Mbague=None):
    lot.put(M, G.tour([(z0, r * 1.05), (z1, r)], 8, "z", (x, y, 0.0), cap1=True))
    if Mbague is not None:
        for z in (z0 + 0.15, z1 - 0.12):
            lot.put(Mbague, G.tour([(z - 0.02, r * 1.12), (z + 0.02, r * 1.12)], 8, "z", (x, y, 0.0)))


def lucarne(lot, M, Mtoit, Mcadre, Mvitre, x, y, z, w=0.42, h=0.36, prof=0.5, cote=-1):
    """Lucarne posée sur un pan de toit : jouées, fenêtre encadrée (vitre en retrait) tournée vers « cote », petit toit à
    deux pans."""
    yf = y + cote * prof / 2
    lot.put(M, G.boite((x, y, z + h / 2), (w, prof, h)))
    lot.put(Mvitre, G.boite((x, yf + cote * 0.005, z + h * 0.48), (w * 0.62, 0.02, h * 0.62)))
    for dx in (-1, 1):
        lot.put(Mcadre, G.boite((x + dx * w * 0.33, yf + cote * 0.015, z + h * 0.48), (0.04, 0.04, h * 0.72)))
    lot.put(Mcadre, G.boite((x, yf + cote * 0.015, z + h * 0.82), (w * 0.72, 0.05, 0.04)))
    lot.put(Mcadre, G.boite((x, yf + cote * 0.04, z + h * 0.13), (w * 0.8, 0.09, 0.035)))
    for s in (-1, 1):
        q0 = [(x + s * (w / 2 + 0.06), y - cote * prof / 2, z + h), (x + s * (w / 2 + 0.06), yf + cote * 0.06, z + h),
              (x, yf + cote * 0.06, z + h + 0.2), (x, y - cote * prof / 2, z + h + 0.2)]
        q1 = [(p[0], p[1], p[2] + 0.035) for p in q0]
        lot.put(Mtoit, G.loft([q0, q1], closed=True))
        lot.put(Mtoit, (q1, [(0, 1, 2, 3)], [(p[0], p[1]) for p in q1]))
