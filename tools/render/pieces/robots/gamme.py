"""Commun à la gamme des robots (lot RB-V1) : un marcheur à n pattes (squelette, IK, cycle) et un géant (torse, positions du moteur). Python pur, sauf patine()."""
import math

import geo as G
import marionette as Mr


def patine(ta=0.14, ra=0.24, ec=0.4, nu_k=1.35, ec_col=(0.03, 0.017, 0.008), sans=()):
    import mat as MT
    MT.PATINE.clear()
    MT.PATINE.update(ta=ta, ra=ra, ec=ec, nu_k=nu_k, ec_col=ec_col, sans=sans)


def corps_marche(phase, z0, bob=0.03, tangage=0.03, roulis=0.03, lacet=0.0):
    """Matrice du corps à la phase : deux rebonds par cycle, balancement d'avant en arrière et de côté."""
    bat = 0.0 if phase is None else 1.0
    a = G.TAU * (phase or 0.0)
    return a, Mr.chaine(Mr.tr(0.0, 0.0, z0 + bat * bob * math.cos(2.0 * a)), Mr.rz(bat * lacet * math.sin(a)), Mr.ry(bat * tangage * math.sin(2.0 * a)),
                        Mr.rx(bat * roulis * math.sin(a + 0.6)))


def pattes(sq, m_corps, phase, pas, beta, leve, l1, l2, table, pied_z=0.02, incl=0.6):
    """table : (nom, hanche (x, y, z) dans le corps, pied (x, y) neutre, décalage de phase, pôle du genou). Os cuisse_<nom>, tibia_<nom>, pied_<nom>, repère du robot."""
    for nom, h_c, p0, dec, pole in table:
        dx, dz, appui, u = Mr.pied(phase, dec, pas, beta, leve)
        h = Mr.app(m_corps, h_c)
        p = (p0[0] + dx, p0[1], pied_z + dz)
        g, tendu = Mr.ik2(h, p, l1, l2, pole)
        sq.os("cuisse_" + nom, "racine", Mr.repere(h, G.sub(g, h)))
        sq.os("tibia_" + nom, "racine", Mr.repere(g, G.sub(p, g)))
        sq.os("pied_" + nom, "racine", Mr.chaine(Mr.tr(p[0], p[1], p[2]), Mr.ry(0.0 if appui else -incl * math.sin(math.pi * u))))
        sq.marques[nom] = {"pied": p, "appui": appui, "tendu": tendu}


def table_quatre(hx, hy, hz, fx, fy, genou=0.15, decs=(0.0, 0.5, 0.5, 0.0), opposes=True):
    """4 pattes : avant gauche, avant droite, arrière gauche, arrière droite. opposes : genoux avant vers l'avant, arrière vers l'arrière."""
    t = []
    for nom, av, co, d in (("ag", 1.0, 1.0, decs[0]), ("ad", 1.0, -1.0, decs[1]), ("rg", -1.0, 1.0, decs[2]), ("rd", -1.0, -1.0, decs[3])):
        t.append((nom, (av * hx, co * hy, hz), (av * fx, co * fy), d, (av if opposes else 1.0, 0.0, genou)))
    return t


def table_cercle(n, rh, rp, hz, a0=0.0, genou=1.1, decs=None):
    """n pattes en cercle : hanches au rayon rh, pieds au rayon rp, genoux vers l'extérieur et le haut."""
    t = []
    for k in range(n):
        a = a0 + G.TAU * k / n
        c, s = math.cos(a), math.sin(a)
        d = decs[k] if decs else (0.0 if k % 2 == 0 else 0.5)
        t.append((str(k), (rh * c, rh * s, hz), (rp * c, rp * s), d, (c, s, genou)))
    return t


def plaques(lot, mats, r, n, point, taille=(0.05, 0.16), ep=0.016):
    """Menus détails : n plaques, regards et boîtiers de tailles et matières variées, sur une surface. point(r) rend (position, normale). Casse les aplats."""
    import formes as F
    for i in range(n):
        p, nrm = point(r)
        w, h = r.f(taille[0], taille[1]), r.f(taille[0], taille[1])
        e = ep * r.f(0.6, 2.4)
        lot.put(mats[i % len(mats)], F.sur_face(G.prisme([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], 0.0, e, 0.86), p, nrm))


# ---------------------------------------------------------------------------------------------------- géants
def jambes_jeu(phis, rh, rp):
    """Hanches et pieds du moteur, orientation nord, y × PROJ (compression de la vue). phis : angle depuis le nord, sens horaire, dans l'ordre des pattes
    de create_spidertron (droite du nord au sud, puis gauche)."""
    out = []
    for phi in phis:
        a = math.radians(phi)
        out.append({"mx": round(rh * math.sin(a), 3), "my": round(-rh * math.cos(a) * Mr.PROJ, 3), "gx": round(rp * math.sin(a), 3), "gy": round(-rp * math.cos(a) * Mr.PROJ, 3)})
    return out
