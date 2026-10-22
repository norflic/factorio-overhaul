"""Manifeste de la famille gun pour le branchement de la phase 2 : tools/render/manifests/levels-gun.json.

    python tools/render/pieces/levels/gun/manifest.py [--measures <mesures.json>]

Lit : gun.py (variantes, niveaux, halo), params.json (hauteur d'axe des canons), les aperçus
(tools/render/out/levels/gun/<variante>/spec.json : tailles et shift hr EXACTS des 4 couches), la géométrie
exportée (cache/levels-gun/geo : bout des canons) et, si fourni, le JSON de measure_d1.py (enveloppe,
drawing_box). Écrit, pour chaque niveau 1 à 30 : couches du socle (base_picture) et de la tête (poses de
référence), tailles, ancrages (shift), pièce du niveau pair, halo, points d'ancrage de jeu proposés.
Conçu pour l'interface de prototypes/levels/common.lua (dress(p, ctx) / icons(icons, ctx)) : voir « interface ».
"""
import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import d1lib as D  # noqa: E402
import gun as G  # noqa: E402

MANIFEST = os.path.join(D.MOD_ROOT, "tools", "render", "manifests", "levels-gun.json")
GEO = os.path.join(D.MOD_ROOT, "tools", "render", "cache", "levels-gun", "geo")
SIN45 = math.sin(math.radians(45))
V_PROJ_CENTER = (0.0, -0.0875)          # turrets.lua:831
V_PROJ_DIST = 1.39375                   # turrets.lua:830
V_MUZZLE_E = (1.000, -1.045)            # bout du canon vanilla, pose E, mesuré sur hr-gun-turret-shooting-2 (image 0)
# halo de nuit (vérification adverse, mineur 2) : la bible §1.6 écrit « rayon S(N) = s × (1 + 0,05·N) » ; la phase 1
# lit S(N) comme la TAILLE (diamètre) d'une LightDefinition : rayon nul = S(N)/2 (2,5 tuiles au niveau 30). Lecture
# « rayon » : 5 tuiles au niveau 30 (halo 2 fois plus large, 4 fois plus d'aire). Choix à trancher par le Directeur
# Créatif ; les deux valeurs sont écrites ci-dessous pour chaque niveau.
HALO_NOTE = ("PROPOSITION À TRANCHER : S(N) = 2 × (1 + 0,05·N) lu comme un DIAMÈTRE (LightDefinition.size) ; rayon nul "
             "= S(N)/2. La bible §1.6 dit « rayon » : l'autre lecture double le rayon (champ "
             "rayon_si_S_est_un_rayon_tuiles).")


def rel(p):
    return os.path.relpath(p, D.MOD_ROOT).replace("\\", "/")


def spec(name):
    p = os.path.join(D.OUT_DIR, name, "spec.json")
    if not os.path.exists(p):
        return None
    with open(p, encoding="utf-8") as f:
        s = json.load(f)
    out = {}
    for layer, d in s["layers"].items():
        out[layer] = {"apercu": rel(os.path.join(D.OUT_DIR, name, d["file"])), "hr": {
            "width": d["width"], "height": d["height"], "shift": d["shift"], "scale": 0.5},
            "lr_prevu": {"width": d["width"] // 2, "height": d["height"] // 2, "shift": d["shift"], "scale": 1},
            "sha256_apercu": d["sha256"]}
        if layer == "shadow":
            out[layer]["draw_as_shadow"] = True
        if layer == "glow":
            out[layer].update({"draw_as_glow": True, "blend_mode": "additive"})
        if layer == "light":
            out[layer].update({"draw_as_light": True, "blend_mode": "additive"})
    return {"couches": out, "echantillons": s["samples"], "secondes_rendu": s["seconds"]}


def muzzle(e, zg):
    p = os.path.join(GEO, "e%02d-tete-N.npz" % e)
    if not os.path.exists(p):
        return None
    t = np.load(p)["tris"].reshape(-1, 3).astype(np.float64)
    ymax = t[:, 1].max()
    tip = t[t[:, 1] >= ymax - 0.03]
    z = float(np.median(tip[:, 2]))
    # écran (tuiles) du bout des canons dans les 4 poses : x' = x cos a - y sin a, y' = x sin a + y cos a
    poses = {}
    for pose, a in (("N", 0.0), ("E", -math.pi / 2), ("S", math.pi), ("O", math.pi / 2)):
        x, y = -math.sin(a) * ymax, math.cos(a) * ymax
        poses[pose] = [round(x, 4), round(-(y * SIN45 + z * SIN45), 4)]
    h = z * SIN45
    reach = ymax
    return {"portee_blender": round(ymax, 4), "hauteur_axe_blender": round(z, 4), "hauteur_axe_ecran_tuiles": round(h, 4),
            "bout_ecran_tuiles": poses,
            "proposition": {
                "projectile_center": [0.0, round(V_PROJ_CENTER[1] - (h - (-V_MUZZLE_E[1])), 4)],
                "projectile_creation_distance": round(V_PROJ_DIST * reach / V_MUZZLE_E[0], 4),
                "statut": "PROPOSITION non vérifiée : décalage vanilla (centre −0,0875, distance 1,39375) translaté de "
                          "l'écart de hauteur d'axe à l'écran et mis à l'échelle de la portée ; à caler en phase 2 sur "
                          "capture de tir (flash de bouche)."}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--measures", default="")
    a = ap.parse_args()
    meas = {}
    if a.measures and os.path.exists(a.measures):
        with open(a.measures, encoding="utf-8") as f:
            meas = json.load(f)
    P = G.load_params()
    levels = {}
    for lv in range(1, 31):
        e = (lv + 1) // 2
        step = 1 if lv % 2 else 2
        L = {"epoque": e, "etape": step, "epoch_key_ctx": "ctx.epoch_key (config L.epochs)",
             "description": G.DESCR.get(lv, "")}
        if lv == 1:
            L.update({"vanilla": True, "note": "Q11 : sprite vanilla inchangé ; dress() n'est pas appelée au niveau 1"})
            levels[str(lv)] = L
            continue
        vv = G.level_variants(lv)
        if lv == 2:
            L["base_picture"] = {
                "ordre_des_couches": ["vanilla hr-gun-turret-base (inchangé)", "vanilla hr-gun-turret-base-mask (inchangé)",
                                      "e01-piece-flancs (masquée au pixel par l'alpha du socle vanilla)",
                                      "e01-piece-avant (devant le socle)"],
                "variantes": {n: spec(n) for n in vv["socle"]}}
            L["tete"] = {"vanilla": True, "note": "tête vanilla inchangée (toutes ses animations)"}
        else:
            L["base_picture"] = {"variante": vv["socle"][0], **(spec(vv["socle"][0]) or {"manquant": True})}
            L["tete"] = {"poses_de_reference_rendues": {d: {"variante": n, **(spec(n) or {"manquant": True})}
                                                        for d, n in vv["tete"].items()},
                         "phase2": {"prepared_animation": "64 directions × 1 image (stripes 4 × 16, comme le vanilla)",
                                    "attacking_animation": "64 directions × 2 images (recul ; Q12 : aucune économie)",
                                    "folded / preparing / folding": "4 directions × 5 images (durée inchangée : garde de dress)",
                                    "masque_couleur_de_force": "À AJOUTER (passe matériau d'équipe, absente en phase 1)",
                                    "angle_direction_k": "−k × 5,625° autour de Z (K.rotate), k = 0..63, 0 = nord"},
                         "hauteur_axe_zg_blender": P["zg"][e], "dessus_du_socle_z": G.SOCLE_TOP[e],
                         "canons": muzzle(e, P["zg"][e])}
        if step == 2:
            L["piece"] = {"nom": G.PIECE_NAME.get(e, ""), "module": "socle (base_picture), zone toujours visible",
                          "rendue_avec_le_socle": lv != 2}
        if e >= 3:
            L["halo"] = {"couche": "light du socle (draw_as_light)", "intensite_I": round(G.halo_intensity(lv), 3),
                         "rayon_nul_tuiles": round(G.halo_radius(lv), 3),
                         "rayon_si_S_est_un_rayon_tuiles": round(2.0 * G.halo_radius(lv), 3),
                         "interpretation_S": HALO_NOTE, "couleur": G.EMIT_HEX[e],
                         "normalisation": "max alpha = LIGHT_MAX × I(N)/I(30)"}
            L["lueur_de_jour"] = {"couleur": G.EMIT_HEX[e], "couches": "glow du socle et de la tête (draw_as_glow)"}
        m = (meas.get("levels") or {}).get(str(lv))
        if m:
            L["enveloppe_mesuree"] = {"O": round(m["O"], 3), "O_cible_bible": G.O_TARGET[e], "L": round(m["L"], 3),
                                      "haut_ecran": round(m["top"], 3), "bas_ecran": round(m["bottom"], 3),
                                      "x": [round(x, 3) for x in m["x"]], "haut_du_socle_ecran": round(m["socle_top"], 3)}
            L["drawing_box_proposee"] = [[round(min(-1.0, m["x"][0]), 3), round(min(-1.0, m["top"]), 3)],
                                         [round(max(1.0, m["x"][1]), 3), round(max(1.0, m["bottom"]), 3)]]
        levels[str(lv)] = L
    out = {
        "famille": "gun", "phase": 1, "statut": "APERÇUS (échantillons réduits) : rien n'est branché en jeu ; design NON validé "
                                                  "(seul le verdict du Directeur Créatif valide, D1 à D3)",
        "source": rel(os.path.join(HERE, "gun.py")),
        "interface": {
            "fichier": "prototypes/levels/gun.lua (V2 : dress(p, ctx) / icons(icons, ctx), en tête de prototypes/levels/common.lua)",
            "dress": "niveau n = ctx.level : époque ctx.epoch ; ctx.step == 1 → p.base_picture = socle de l'époque, têtes "
                     "(prepared/attacking/folded/preparing/folding) de l'époque ; ctx.step == 2 → même tête, "
                     "p.base_picture = variante socle-piece (socle + pièce rendus ensemble, 1 pose)",
            "couches_base_picture": "layers = {main, glow (draw_as_glow), light (draw_as_light)} + ombre (draw_as_shadow)",
            "champs_visuels_a_poser": ["base_picture", "prepared_animation", "attacking_animation", "folded_animation",
                                       "preparing_animation", "folding_animation", "water_reflection (à retirer ou refaire)",
                                       "icons (rendu de la pose de référence + numéro, ctx.kit / lib.tier_icons)"],
            "champs_de_jeu_suivant_la_geometrie": ["attack_parameters.projectile_center",
                                                   "attack_parameters.projectile_creation_distance",
                                                   "attack_parameters.shell_particle.center (non calculé)"],
            "inchanges": "collision_box ±0,7, selection_box ±1 (D1-4) ; fast_replaceable_group (F39)",
            "garde_V2b": {
                "duree_des_animations_de_jeu": "images / vitesse inchangé (garde de dress, common.lua) : vanilla "
                                               "preparing et folding = 5 images à 0,08 (62,5 ticks), attacking = 2 "
                                               "images à 0,5 (4 ticks) ; Q12 : on garde 5 et 2 images, vitesses "
                                               "inchangées",
                "sous_cles_de_jeu_libres": "attack_parameters.projectile_center, projectile_creation_distance, "
                                           "shell_particle (VISUAL_SUBKEYS de common.lua) : seules ces valeurs de jeu "
                                           "peuvent suivre la nouvelle géométrie",
                "water_reflection": "à RETIRER ou à refaire par époque (bible §1.8.5 : le reflet vanilla sous une "
                                    "autre silhouette est un défaut D3)",
                "drawing_box": "champ graphique (GRAPHIC_KEYS) : enveloppe mesurée du niveau, ci-dessous "
                               "(drawing_box_proposee) ; découpe des sprites hauts en bord d'écran NON vérifiée"},
            "chemins_phase2": "graphics/levels/gun/e<NN>/{socle,tete,piece}-{couleur,ombre,emissif,lumiere,masque}.png "
                              "(bible §1.9 ; hr seulement ou hr + lr réduite : à trancher par V0b)"},
        "a_trancher_par_le_directeur_creatif": [
            "Halo de nuit : S(N) de la bible §1.6 lu comme un DIAMÈTRE (rayon nul 2,5 tuiles au niveau 30) ou comme un "
            "RAYON (5 tuiles) ; voir niveaux.*.halo.interpretation_S.",
            "Plafond L = 2,20 (bible §1.4) contre débord des pièces paires (F42 : 0,10 à 0,25 ; fiches : sacs de sable et "
            "caisse 0,10, passerelle et jupe 0,15 de chaque côté = L 2,30 par construction) : aux niveaux pairs, L = "
            "portée des canons d'un côté + débord de la pièce de l'autre ; planche gun-g-rangs-zoom1.png (3 tourelles "
            "jointives) pour juger le recouvrement entre voisines.",
            "Part émissive du corps au-dessus de la proposition ❔ de la bible (5 à 15 %) aux époques 8, 12, 13 et 15 "
            "(chiffres dans docs/epoques/planches/gun/gun-mesures-d1.txt, tableau 2).",
            "Seuil de l'IoU normalisée (D1-3) : proposition 0,75 NON étalonnée.",
            "Design : verdict sur les planches (D1 à D3) ; rien n'est validé sans lui."],
        "conventions": {"hr_px_par_tuile": 64, "scale_hr": 0.5, "shift": "tuiles, multiples exacts de 1/64",
                        "origine": "position de l'entité au sol", "projection": "orthographique 45°, tuile sud = √2 unité",
                        "poses": "N = canons vers le nord (direction 0), E = 16, S = 32, O = 48"},
        "niveaux": levels,
    }
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, indent=1, sort_keys=True, ensure_ascii=False)
    print(MANIFEST)


if __name__ == "__main__":
    main()
