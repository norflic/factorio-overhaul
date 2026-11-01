"""SCULPTURE IMPLICITE des biters (lot RB-V0, 31/10) : numpy pur, sans Blender (testable hors rendu, tests/test_sdf.py).

Pourquoi : les pièces rigides du kit (boîtes, cylindres) donnent des machines. Une créature est ici un CHAMP de distance :
volumes fondus les uns dans les autres (union lisse), sillons creusés (soustraction lisse), peau déplacée par un bruit.
La surface est extraite par « surface nets » puis passée à Blender. Déterministe : bruit à graine fixe, aucun pairs, aucun temps.

Repère local d'une créature : +x avant, +y gauche, +z haut, z = 0 au sol, 1 unité = 1 tuile.
Un volume porte un REPÈRE DE REPOS (`q`) : le bruit de la peau y est lu, pour que la peau ne glisse pas entre deux images.
"""
import numpy as np


class Bruit:
    """Bruit de valeur lisse 3D sur un treillis périodique, à graine fixe."""

    def __init__(self, graine, n=64):
        self.n = n
        self.t = np.random.default_rng(graine).random((n, n, n), dtype=np.float32) * 2.0 - 1.0

    def __call__(self, q):
        n, t = self.n, self.t
        f = np.floor(q)
        i = f.astype(np.int64)
        w = (q - f).astype(np.float32)
        w = w * w * (3.0 - 2.0 * w)
        i0, j0, k0 = i[..., 0] % n, i[..., 1] % n, i[..., 2] % n
        i1, j1, k1 = (i0 + 1) % n, (j0 + 1) % n, (k0 + 1) % n
        wx, wy, wz = w[..., 0], w[..., 1], w[..., 2]
        c00 = t[i0, j0, k0] * (1 - wx) + t[i1, j0, k0] * wx
        c10 = t[i0, j1, k0] * (1 - wx) + t[i1, j1, k0] * wx
        c01 = t[i0, j0, k1] * (1 - wx) + t[i1, j0, k1] * wx
        c11 = t[i0, j1, k1] * (1 - wx) + t[i1, j1, k1] * wx
        return (c00 * (1 - wy) + c10 * wy) * (1 - wz) + (c01 * (1 - wy) + c11 * wy) * wz

    def fbm(self, q, octaves=3, gain=0.5, lac=2.03):
        s, a, tot = 0.0, 1.0, 0.0
        for o in range(octaves):
            s = s + a * self(q + 17.3 * o)
            tot += a
            a *= gain
            q = q * lac
        return s / tot


BRUIT = Bruit(20261031)


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return a * h + b * (1.0 - h) - k * h * (1.0 - h)      # h = 1 rend a exactement (volume écarté : b très grand)


def smax(a, b, k):
    return -smin(-a, -b, k)


def _v(x):
    return np.asarray(x, dtype=np.float32)


def rot_x(a):
    c, s = np.cos(a), np.sin(a)
    return _v([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(a):
    c, s = np.cos(a), np.sin(a)
    return _v([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(a):
    c, s = np.cos(a), np.sin(a)
    return _v([[c, -s, 0], [s, c, 0], [0, 0, 1]])


class Repere:
    """Repère rigide d'un morceau : q = Rᵀ (P - t) donne les coordonnées de repos."""

    def __init__(self, t=(0, 0, 0), R=None):
        self.t = _v(t)
        self.R = np.eye(3, dtype=np.float32) if R is None else _v(R)

    def q(self, P):
        return (P - self.t) @ self.R   # P lignes : (P - t) R = Rᵀ (P - t)

    def monde(self, p):
        return self.R @ _v(p) + self.t

    def compose(self, t=(0, 0, 0), R=None):
        """Repère enfant, donné dans ce repère."""
        Rc = np.eye(3, dtype=np.float32) if R is None else _v(R)
        return Repere(self.monde(t), self.R @ Rc)


REPERE_ID = Repere()


class Volume:
    """Un volume : d(P) -> (distance, q, g). g : valeur scalaire (0 à 1) le long du volume, lue par la matière."""
    k = 0.03
    d_seul = None

    def d(self, P):
        raise NotImplementedError

    def detail(self, P):
        return self.d(P), self.rep.q(P), np.zeros(len(P), np.float32)


class Ell(Volume):
    """Ellipsoïde, axes du repère rep ; g constant. peau = (amplitude, fréquence, graine) ; plis = fn(q) optionnelle."""

    def __init__(self, c, r, rep=REPERE_ID, R=None, k=0.03, peau=None, g=0.0, plis=None):
        self.rep = rep.compose(c, R)
        self.r = _v(r)
        self.k, self.peau, self.g, self.plis = k, peau, g, plis
        self.ref = rep

    def d(self, P):
        q = self.rep.q(P)
        k0 = np.linalg.norm(q / self.r, axis=1)
        k1 = np.linalg.norm(q / (self.r * self.r), axis=1)
        d = k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)
        if self.plis is not None:
            d = d - self.plis(q)
        if self.peau is not None:
            a, f, s = self.peau
            d = d - a * BRUIT.fbm(q * f + s)
        return d

    def detail(self, P):
        return self.d(P), self.ref.q(P), np.full(len(P), self.g, np.float32)


class Os(Volume):
    """Segment à rayon variable, ventre musculaire (`ventre` > 0) ; repère de repos propre au segment.
    g va de g0 (a) à g1 (b). `plis` : fn(t, rayon_local) -> déplacement (anneaux, nœuds)."""

    def __init__(self, a, b, ra, rb, k=0.03, ventre=0.0, peau=None, g0=0.0, g1=0.0, graine=0.0, plis=None):
        self.a, self.b = _v(a), _v(b)
        self.ra, self.rb, self.k, self.ventre, self.peau = ra, rb, k, ventre, peau
        self.g0, self.g1, self.graine, self.plis = g0, g1, graine, plis
        u = self.b - self.a
        self.L = float(np.linalg.norm(u))
        self.u = u / max(self.L, 1e-6)
        # repère stable : w = la direction la plus perpendiculaire possible à u parmi z et y
        h = _v((0, 0, 1)) if abs(self.u[2]) < 0.85 else _v((0, 1, 0))
        self.v = np.cross(h, self.u)
        self.v /= np.linalg.norm(self.v)
        self.w = np.cross(self.u, self.v)

    def _t(self, P):
        pa = P - self.a
        return pa, np.clip(pa @ self.u / max(self.L, 1e-6), 0.0, 1.0)

    def d(self, P):
        pa, t = self._t(P)
        c = pa - t[:, None] * (self.u * self.L)[None, :]
        r = self.ra + (self.rb - self.ra) * t + self.ventre * np.sin(np.pi * t)
        dist = np.linalg.norm(c, axis=1)
        d = dist - r
        if self.plis is not None:
            d = d - self.plis(t, np.arctan2(c @ self.w, c @ self.v))
        if self.peau is not None:
            a, f, s = self.peau
            d = d - a * BRUIT.fbm(self._q(pa) * f + s + self.graine)
        return d

    def _q(self, pa):
        return np.stack([pa @ self.u, pa @ self.v, pa @ self.w], axis=1)

    def detail(self, P):
        pa, t = self._t(P)
        q = self._q(pa) + self.graine
        return self.d(P), q, self.g0 + (self.g1 - self.g0) * t.astype(np.float32)


class Fn(Volume):
    """Volume libre : fn(q) -> distance, dans le repère rep ; g par fn_g(q) (facultatif)."""

    def __init__(self, fn, rep=REPERE_ID, k=0.03, fn_g=None):
        self.fn, self.rep, self.k, self.fn_g = fn, rep, k, fn_g

    def d(self, P):
        return self.fn(self.rep.q(P))

    def detail(self, P):
        q = self.rep.q(P)
        g = self.fn_g(q) if self.fn_g else np.zeros(len(P), np.float32)
        return self.fn(q), q, g


def ell_sur(a, b, r_large, r_mince, haut, k=0.02, peau=None, g=0.0):
    """Plaque ellipsoïdale de a à b, aplatie selon haut (direction du dessus) : grand axe le long de ab."""
    a, b, haut = np.asarray(a, np.float64), np.asarray(b, np.float64), np.asarray(haut, np.float64)
    u = b - a
    L = float(np.linalg.norm(u))
    u = u / max(L, 1e-6)
    w = haut - haut.dot(u) * u
    w = w / max(np.linalg.norm(w), 1e-6)
    v = np.cross(w, u)
    R = np.stack([u, v, w], axis=1)
    return Ell((a + b) / 2.0, (L / 2.0, r_large, r_mince), R=R, k=k, peau=peau, g=g)


class Forme:
    """Groupes de volumes (une matière par groupe), fondus entre eux, puis sillons creusés."""

    def __init__(self, nom, boite, voxel):
        self.nom = nom
        self.boite = (_v(boite[0]), _v(boite[1]))
        self.voxel = float(voxel)
        self.groupes = []      # [(nom, k_union, [volumes])]
        self.creux = []        # [(volume, k)] : soustraits à la fin
        self.marge = 0.0       # marge de la bande étroite pour les champs très éloignés d'une vraie distance

    def groupe(self, nom, k=0.04):
        self.groupes.append((nom, k, []))
        return self.groupes[-1][2]

    def creuse(self, vol, k=0.02):
        self.creux.append((vol, k))

    def _volumes(self):
        return [v for _n, _k, vols in self.groupes for v in vols] + [c for c, _k in self.creux]

    def selection(self, P, H, extra=0.0):
        """Quels volumes comptent, bloc de côté H par bloc : calcule chaque volume sur les seuls points proches de lui.
        Renvoie une liste de masques (N,), dans l'ordre de _volumes. Une fois calculée, valable pour de petits décalages."""
        lo = P.min(axis=0)
        ijk = np.floor((P - lo) / H).astype(np.int64)
        cle = ijk[:, 0] * 2000000 + ijk[:, 1] * 2000 + ijk[:, 2]
        uniq, inv = np.unique(cle, return_inverse=True)
        c = np.stack([uniq // 2000000, (uniq // 2000) % 1000, uniq % 2000], axis=1)
        c = (lo + (c + 0.5) * H).astype(np.float32)
        kmax = max([g[1] for g in self.groupes] + [c_[1] for c_ in self.creux] + [0.0])
        masques = []
        for v in self._volumes():
            portee = H * 0.87 * 1.5 + self.marge + kmax + getattr(v, "k", 0.0) + self.voxel * 4.0 + extra
            masques.append((v.d(c) < portee)[inv.ravel()])
        return masques

    def champ(self, P, sel=None):
        total = None
        i = 0
        loin = np.float32(50.0)
        for _nom, kg, vols in self.groupes:
            dg = None
            for v in vols:
                if sel is None:
                    d = v.d(P)
                else:
                    d = np.full(len(P), loin, np.float32)
                    m = sel[i]
                    if m.any():
                        d[m] = v.d(P[m])
                i += 1
                dg = d if dg is None else smin(dg, d, v.k)
            if dg is None:
                continue
            total = dg if total is None else smin(total, dg, kg)
        for vol, k in self.creux:
            if sel is None:
                total = smax(total, -vol.d(P), k)
            else:
                m = sel[i]
                if m.any():
                    total[m] = smax(total[m], -vol.d(P[m]), k)
            i += 1
        return total

    def attributs(self, P, sel=None):
        """Par sommet : poids de chaque groupe, q et g du volume le plus proche. Renvoie (poids (N, ng), q, g)."""
        n = len(P)
        dgs = np.zeros((n, len(self.groupes)), np.float32)
        q = np.zeros((n, 3), np.float32)
        g = np.zeros(n, np.float32)
        meilleur = np.full(n, 1e9, np.float32)
        i = 0
        for ig, (_nom, _k, vols) in enumerate(self.groupes):
            dg = None
            for v in vols:
                m = np.ones(n, bool) if sel is None else sel[i]
                i += 1
                d = np.full(n, 50.0, np.float32)
                if m.any():
                    dv, qv, gv = v.detail(P[m])
                    d[m] = dv
                    mi = np.where(m)[0]
                    mieux = dv < meilleur[mi]
                    meilleur[mi[mieux]] = dv[mieux]
                    q[mi[mieux]] = qv[mieux]
                    g[mi[mieux]] = gv[mieux]
                dg = d if dg is None else smin(dg, d, v.k)
            dgs[:, ig] = 50.0 if dg is None else dg
        s = max(self.voxel * 1.5, 1e-4)
        p = np.exp(-np.clip((dgs - dgs.min(axis=1, keepdims=True)) / s, 0.0, 30.0))
        return p / p.sum(axis=1, keepdims=True), q, g


def echantillonne(champ, lo, hi, h, bloc=6, marge=0.0, par_paquet=300000, forme=None):
    """Grille dense du champ, calculée seulement près de la surface. Renvoie (vol (nx,ny,nz), origine, h, nb calculés).
    forme : si donnée, chaque volume n'est calculé que près de lui (Forme.selection)."""
    lo = np.asarray(lo, np.float64)
    hi = np.asarray(hi, np.float64)
    n = np.ceil((hi - lo) / h).astype(int) + 1
    nb = np.ceil(n / bloc).astype(int)
    H = h * bloc
    ax = [lo[i] + (np.arange(nb[i]) + 0.5) * H - 0.5 * h for i in range(3)]
    gx, gy, gz = np.meshgrid(*ax, indexing="ij")
    C = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], axis=1).astype(np.float32)
    dc = np.concatenate([champ(C[i:i + par_paquet]) for i in range(0, len(C), par_paquet)]).reshape(nb)
    bande = H * 0.87 * 1.5 + marge
    actif = np.abs(dc) < bande
    vol = np.repeat(np.repeat(np.repeat(np.where(dc < 0, -1.0, 1.0).astype(np.float32) * 9.0, bloc, 0), bloc, 1), bloc, 2)
    vol = vol[:n[0], :n[1], :n[2]]
    masque = np.repeat(np.repeat(np.repeat(actif, bloc, 0), bloc, 1), bloc, 2)[:n[0], :n[1], :n[2]]
    idx = np.argwhere(masque)
    P = (lo + idx * h).astype(np.float32)
    if not len(P):
        return vol, lo, h, 0
    tranche = par_paquet * 8 if forme is not None else par_paquet
    vals = []
    for i in range(0, len(P), tranche):
        p = P[i:i + tranche]
        vals.append(forme.champ(p, forme.selection(p, H)) if forme is not None else champ(p))
    vol[masque] = np.concatenate(vals)
    return vol, lo, h, len(P)


_COINS = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0], [1, 1, 0], [0, 0, 1], [1, 0, 1], [0, 1, 1], [1, 1, 1]])
_ARETES = [(0, 1), (2, 3), (4, 5), (6, 7), (0, 2), (1, 3), (4, 6), (5, 7), (0, 4), (1, 5), (2, 6), (3, 7)]


def surface_nets(vol, origine, h):
    """Surface nets vectorisés. Renvoie (sommets (N,3), quads (M,4), normales vers l'extérieur)."""
    s = vol < 0
    compte = np.zeros(np.array(vol.shape) - 1, np.int8)
    for c in _COINS:
        compte += s[c[0]:vol.shape[0] - 1 + c[0], c[1]:vol.shape[1] - 1 + c[1], c[2]:vol.shape[2] - 1 + c[2]]
    cellules = np.argwhere((compte > 0) & (compte < 8))
    carte = np.full(compte.shape, -1, np.int32)
    carte[tuple(cellules.T)] = np.arange(len(cellules), dtype=np.int32)
    somme = np.zeros((len(cellules), 3), np.float64)
    nb = np.zeros(len(cellules), np.int32)
    for a, b in _ARETES:
        ca, cb = cellules + _COINS[a], cellules + _COINS[b]
        va, vb = vol[tuple(ca.T)], vol[tuple(cb.T)]
        m = (va < 0) != (vb < 0)
        t = (va[m] / (va[m] - vb[m]))[:, None]
        somme[m] += _COINS[a] + t * (_COINS[b] - _COINS[a])
        nb[m] += 1
    pos = cellules + somme / np.maximum(nb, 1)[:, None]
    sommets = (np.asarray(origine) + pos * h).astype(np.float32)
    quads = []
    # arête x : (y,z) tourne dans le sens direct vu de +x ; arête y : (z,x) ; arête z : (x,y)
    for ax, (u, v) in ((0, (1, 2)), (1, (2, 0)), (2, (0, 1))):
        d = [0, 0, 0]
        d[ax] = 1
        a = s[:s.shape[0] - d[0], :s.shape[1] - d[1], :s.shape[2] - d[2]]
        b = s[d[0]:, d[1]:, d[2]:]
        i = np.argwhere(a != b)
        i = i[(i[:, u] >= 1) & (i[:, v] >= 1) & (i[:, u] < compte.shape[u] + 0) & (i[:, v] < compte.shape[v] + 0)
              & (i[:, ax] < compte.shape[ax])]
        if not len(i):
            continue
        du, dv = np.zeros(3, int), np.zeros(3, int)
        du[u], dv[v] = 1, 1
        q = np.stack([carte[tuple((i - du - dv).T)], carte[tuple((i - dv).T)], carte[tuple(i.T)],
                      carte[tuple((i - du).T)]], axis=1)
        dedans_bas = s[tuple(i.T)]
        q[~dedans_bas] = q[~dedans_bas][:, ::-1]
        quads.append(q[(q >= 0).all(axis=1)])
    return sommets, np.concatenate(quads) if quads else np.zeros((0, 4), np.int32)


def normales(forme, P, e, par_paquet=400000):
    """Normales par différences centrées du champ : ombrage plus fin que le maillage."""
    out = np.zeros_like(P)
    for i in range(0, len(P), par_paquet):
        p = P[i:i + par_paquet]
        sel = forme.selection(p, forme.voxel * 6.0, extra=e)
        for a in range(3):
            d = np.zeros(3, np.float32)
            d[a] = e
            out[i:i + par_paquet, a] = forme.champ(p + d, sel) - forme.champ(p - d, sel)
    return out / np.maximum(np.linalg.norm(out, axis=1, keepdims=True), 1e-9)


def creux_et_relief(forme, P, N, r, par_paquet=400000):
    """(ouverture, relief) à l'échelle r : ouverture ≈ 1 à l'air libre, < 1 dans une fente ; relief > 0 sur une arête ou une
    bosse, < 0 dans un sillon (moyenne du champ à r de part et d'autre, DANS le plan tangent)."""
    ouv = np.zeros(len(P), np.float32)
    rel = np.zeros(len(P), np.float32)
    for i in range(0, len(P), par_paquet):
        p, n = P[i:i + par_paquet], N[i:i + par_paquet]
        sel = forme.selection(p, forme.voxel * 6.0, extra=r)
        ouv[i:i + par_paquet] = np.clip(forme.champ(p + n * r, sel) / r, 0.0, 1.0)
        h = np.where(np.abs(n[:, 2:3]) < 0.85, np.array([[0, 0, 1]], np.float32), np.array([[0, 1, 0]], np.float32))
        t1 = np.cross(h, n)
        t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-6)
        t2 = np.cross(n, t1)
        rel[i:i + par_paquet] = (forme.champ(p + t1 * r, sel) + forme.champ(p - t1 * r, sel) + forme.champ(p + t2 * r, sel)
                                 + forme.champ(p - t2 * r, sel)) / (4.0 * r)
    return ouv, rel


def extraire(forme):
    """Maillage d'une Forme : (sommets, quads, nb de points calculés)."""
    lo, hi = forme.boite
    vol, o, h, nb = echantillonne(forme.champ, lo, hi, forme.voxel, marge=forme.marge, forme=forme)
    V, Q = surface_nets(vol, o, h)
    return V, Q, nb
