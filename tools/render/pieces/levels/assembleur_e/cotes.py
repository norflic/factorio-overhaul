"""COTES DE LA LIGNÉE de la MACHINE D'ASSEMBLAGE (lot F3-A, 25/10), Python PUR (importable hors Blender : profil.py,
outils, tests).

Unités : x et yn en TUILES DE JEU (yn vers le nord ; Blender Y = yn × √2, commun/repere.Y) ; z en unités Blender (une
unité de hauteur se lit 0,707 tuile à l'écran). Vue de trois quarts depuis le sud : un point (x, yn, z) se dessine à
l'écran en (x, −yn − 0,707 z) (vers le bas positif).

Formules (côté s = 3 à 6, emprise de l'ère, epoques.COTE), toutes CROISSANTES en s (test : tests/test_assembleur.py) :
  embase     demi-côté h = s/2 − 0,06 ; hauteur ze = 0,08 + 0,025 s ;
  plateau    PLATEAU DE BAIE surélevé entre les joues (x ±xb, yn de −h à yb), dessus zs = ze + 0,08 + 0,05 s ; parapet
             au bord sud, haut de 0,1 + 0,025 s ;
  dos        bloc nord : yn de yb = h − 0,22 s à h, sur toute la largeur, hauteur Hd = Hj + 0,16 + 0,04 s ;
  joues      x de ±(h − wj) à ±h, wj = 0,22 s ; yn de yf = −h + wc à yb ; hauteur Hj = zs + 0,22 + 0,07 s ;
  coins      coins AVANT libres de côté wc = 0,2 s + 0,04 (pièce du niveau pair, places coin_SO et coin_SE) ;
  baie       x ±xb (xb = h − wj), yn de −h à yb ;
  table      centre (0, yt), yt = (−h + yb) / 2 ; demi-côté tw = 0,16 s + 0,05 (x), 0,8 tw (yn) ; dessus zt = zs + 0,10
             + 0,03 s ;
  portique   montants au milieu des joues, en yn = yt ; dessous de la poutre zp = Hj + 0,30 + 0,08 s ; section bp = 0,06
             + 0,012 s ;
  outil      enveloppe de l'outil de l'âge : x ±0,8 tw, yn yt ± 0,7 tw, z de zt à zp ;
  places     coin_SO, coin_SE (avant, sur l'embase) ; joue_O, joue_E (trémie d'entrée, bac de sortie : arrière des joues,
             entre le montant du portique et le dos) ; toit (dessus du dos) ; face (face sud du dos) ; port_N, port_S
             (brides de fluide au milieu des bords nord et sud) ; coin_NO, coin_NE (coins du toit).
Deuxième jet (25/10, après le témoin k3-k6 du premier : dos 0,30 s × 0,30 + 0,20 s, joues 0,19 s × 0,22 + 0,10 s, table
0,13 s + 0,05 : vu de la caméra, un grand toit plat et une baie vide ; dos moins profond et plus haut, joues et table
plus grandes). Troisième jet (25/10, après la ronde 1 des âges 1 à 6 : vu de la caméra, un PLAN au sol, la baie et les coins
lus comme un dallage plat) : PLATEAU DE BAIE surélevé et parapet (la machine devient un bloc ; seuls les coins avant restent
au sol, pour la pièce paire), dos moins haut au-dessus du bord nord (0,70 tuile en 3×3 ; la mitrailleuse validée dépasse
de 0,34 à 0,53 tuile), joues plus hautes que le plateau.
"""
import math

SQ2 = math.sqrt(2.0)
TAILLES_PERMISES = (3, 4, 5, 6)


def _taille(s):
    h = s / 2.0 - 0.06
    ze = 0.08 + 0.025 * s
    dd = 0.22 * s
    yb = h - dd
    zs = ze + 0.08 + 0.05 * s
    wj = 0.22 * s
    Hj = zs + 0.22 + 0.07 * s
    Hd = Hj + 0.16 + 0.04 * s
    wc = 0.2 * s + 0.04
    yf = -h + wc
    xb = h - wj
    yt = (-h + yb) / 2.0
    tw = 0.16 * s + 0.05
    zt = zs + 0.10 + 0.03 * s
    zp = Hj + 0.30 + 0.08 * s
    bp = 0.06 + 0.012 * s
    return dict(
        s=s, h=h,
        embase=dict(h=h, ze=ze, chanfrein=0.09 * s, marche=0.07 * s),
        dos=dict(yb=yb, dd=dd, Hd=Hd),
        joues=dict(wj=wj, Hj=Hj, yf=yf, xb=xb),
        coin=dict(wc=wc),
        plateau=dict(zs=zs, hpar=0.1 + 0.025 * s, epar=0.04 + 0.01 * s),
        table=dict(yt=yt, tx=tw, ty=0.8 * tw, zt=zt),
        portique=dict(yt=yt, zp=zp, bp=bp, xm=xb + wj / 2.0, wm=0.08 + 0.02 * s),
        outil=dict(ox=0.8 * tw, oy=0.7 * tw, z0=zt, z1=zp),
    )


TAILLES = {s: _taille(s) for s in TAILLES_PERMISES}


def places(s):
    """Places libres des superstructures d'âge (tuiles de jeu ; z_sol : hauteur du support ; r : rayon libre)."""
    T = TAILLES[s]
    h, ze = T["h"], T["embase"]["ze"]
    wc = T["coin"]["wc"]
    J, D, P = T["joues"], T["dos"], T["portique"]
    out = {}
    for nom, sx in (("coin_SO", -1), ("coin_SE", 1)):
        out[nom] = dict(x=sx * (h - wc / 2.0), yn=-(h - wc / 2.0), z_sol=ze, r=wc / 2.0 - 0.04)
    yj = (P["yt"] + P["wm"] / 2.0 + D["yb"]) / 2.0
    rj = min(J["wj"] / 2.0, (D["yb"] - P["yt"] - P["wm"] / 2.0) / 2.0) - 0.04
    for nom, sx in (("joue_O", -1), ("joue_E", 1)):
        out[nom] = dict(x=sx * (J["xb"] + J["wj"] / 2.0), yn=yj, z_sol=J["Hj"], r=rj)
    out["toit"] = dict(x=0.0, yn=(D["yb"] + h) / 2.0, z_sol=D["Hd"], r=D["dd"] / 2.0 - 0.05)
    out["face"] = dict(x=0.0, yn=D["yb"], z_sol=ze, r=h - 0.1, haut=D["Hd"] - ze)
    out["port_N"] = dict(x=0.0, yn=h, z_sol=0.0, r=0.16)
    out["port_S"] = dict(x=0.0, yn=-h, z_sol=0.0, r=0.16)
    for nom, sx in (("coin_NO", -1), ("coin_NE", 1)):
        out[nom] = dict(x=sx * (h - D["dd"] / 2.0), yn=(D["yb"] + h) / 2.0, z_sol=D["Hd"], r=D["dd"] / 2.0 - 0.05)
    return out


def ecran(x, yn, z):
    """Position à l'écran (tuiles, vers le bas positif) d'un point de la scène."""
    return (x, -yn - z / SQ2)
