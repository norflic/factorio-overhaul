"""Manifeste du centre de commandement pour le branchement de la phase 2 (lot V3-a). Python système.

    python -P tools/render/pieces/levels/centre/manifeste_centre.py

Écrit tools/render/manifests/levels-centre.json à partir des aperçus (tools/render/out/levels/centre/nNN/
render.json et pieces.json), de centre_params.py et de mesures_d1.json. Pour chaque niveau : couches
(fichier cible, taille, shift hr et lr, drapeaux moteur), ordre des couches, drawing_box, pièces,
lumières et animations à poser PAR SCRIPT (F44 : un container n'est pas animable par prototype).

Les tailles et shift viennent des APERÇUS (échantillons réduits) : la géométrie ne dépend pas du nombre
d'échantillons, mais le recadrage peut bouger d'un pixel pair au rendu final (bruit de l'AO, des halos).
La phase 2 régénère ce manifeste après le rendu final ; prototypes/levels/command.lua ne doit lire que des
valeurs régénérées (jamais réglées à la main : bible §1.8-1).
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(RENDER, "out", "levels", "centre")
DEST = os.path.join(RENDER, "manifests", "levels-centre.json")
sys.path.insert(0, HERE)
import centre_params as PR  # noqa: E402

K = 0.5 ** 0.5

FLAGS = {
    "main": {},
    "shadow": {"draw_as_shadow": True},
    "glow": {"draw_as_glow": True, "blend_mode": "additive"},
    "light": {"draw_as_light": True, "blend_mode": "additive"},
}


def stems(objs, role):
    out = set()
    for o in objs:
        if o.get("role", "mass") != role:
            continue
        out.add(re.sub(r"(_-?\d+)+$", "", o["name"]))
    return sorted(out)


def sha(path):
    import hashlib
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def fingerprints(e, rec):
    """Empreintes des scripts qui DÉTERMINENT le niveau e (centre.py, centre_kit.py, centre_params.py,
    centre_ere<ère>.py, render_centre.py), relevées au rendu (render.json) et comparées aux fichiers actuels.
    Les autres scripts du dossier (autres ères) n'influent pas sur le niveau : leur écart est seulement signalé."""
    rec_sha = rec.get("scripts_sha256") or {}
    era = (e - 1) // 3 + 1
    rel = ["centre.py", "centre_kit.py", "centre_params.py", "centre_ere%d.py" % era, "render_centre.py"]
    # imports entre ères (centre_ere3 et centre_ere5 : _ogive, _panel_xz de centre_ere2 ; centre_ere5 : _dish de
    # centre_ere4) : ces scripts déterminent aussi le niveau
    rel += {3: ["centre_ere2.py"], 5: ["centre_ere2.py", "centre_ere4.py"]}.get(era, [])
    bad = [f for f in rel if rec_sha.get(f) != sha(os.path.join(HERE, f))]
    other = sorted(f for f, h in rec_sha.items() if f not in rel and os.path.exists(os.path.join(HERE, f))
                   and h != sha(os.path.join(HERE, f)))
    return {"conformes": not bad and bool(rec_sha), "ecarts_determinants": bad, "ecarts_sans_effet": other}


def main():
    meas = {}
    mp = os.path.join(HERE, "mesures_d1.json")
    if os.path.exists(mp):
        with open(mp, encoding="utf-8") as f:
            meas = {r["level"]: r for r in json.load(f)["levels"]}
    levels = []
    for e in range(1, 16):
        d = os.path.join(OUT, "n%02d" % e)
        rj = os.path.join(d, "render.json")
        if not os.path.exists(rj):
            continue
        with open(rj, encoding="utf-8") as f:
            r = json.load(f)
        pieces = []
        pj = os.path.join(d, "pieces.json")
        if os.path.exists(pj):
            with open(pj, encoding="utf-8") as f:
                pieces = json.load(f)["objects"]
        dest = "graphics/levels/centre/e%02d" % e
        layers = []
        x0 = y0 = 1e9
        x1 = y1 = -1e9
        for layer in ("main", "shadow", "glow", "light"):
            if layer not in r.get("spec", {}):
                continue
            sd = r["spec"][layer]
            fl = dict(FLAGS[layer])
            if layer == "glow" and e in PR.NIGHT_ONLY:
                # époques 1-2 : aucune lueur de jour (bible §5) ; la lanterne / la forge n'existent que la nuit
                fl = dict(FLAGS["light"])
            ent = {"role": layer, "flags": fl}
            for res in ("hr", "lr"):
                s = sd[res]
                tgt = s["filename"].replace("centre-n%02d" % e, "centre-e%02d" % e)
                ent[res] = {"filename": "__factorio-overhaul__/%s/%s" % (dest, tgt), "apercu": "tools/render/out/levels/centre/n%02d/%s" % (e, s["filename"]),
                            "width": s["width"], "height": s["height"], "shift": s["shift"],
                            "scale": 0.5 if res == "hr" else 1.0}
            if layer in ("main", "shadow"):
                s = sd["hr"]
                x0 = min(x0, s["shift"][0] - s["width"] / 128.0)
                x1 = max(x1, s["shift"][0] + s["width"] / 128.0)
                y0 = min(y0, s["shift"][1] - s["height"] / 128.0)
                y1 = max(y1, s["shift"][1] + s["height"] / 128.0)
            layers.append(ent)
        m = meas.get(e, {})
        halo = PR.halo_script(e)
        lights = []
        for (x, ty, z, col, pw, r0, r1, g0, g1) in PR.HALO.get(e, []):
            lights.append({"source_tiles": [x, ty, z], "ecran_tiles": [round(x, 3), round(ty - K * z, 3)], "couleur": col,
                           "fenetre_sprite_tiles": [r0, r1], "flaque_sol_tiles": [g0, g1] if g1 > 0 else None})
        levels.append({
            "level": e, "epoch": e, "era": PR.ERA[e], "nom": PR.NAMES[e], "dest": dest,
            "layers": layers,
            "ordre": [l["role"] for l in layers],
            "drawing_box": [[round(x0, 4), round(y0, 4)], [round(x1, 4), round(y1, 4)]] if layers else None,
            "mesures": {k: m.get(k) for k in ("O", "O_tige", "L", "area_t2", "iou_prev", "events", "V_pct") if k in m},
            "pieces": {"masses": stems(pieces, "mass"), "tiges": stems(pieces, "tige"), "plates_au_sol": stems(pieces, "flat")},
            "lumiere_jour": e not in PR.NIGHT_ONLY,
            "halo_sprite": lights,
            "halo_script": {"intensite": halo["intensity"], "taille_tuiles": halo["size"], "formule": "I = 0,05 + 0,02 N ; S = 4 (1 + 0,05 N) ; N = 2e (bible §1.6)",
                            "minimum_darkness": 0.3 if e in PR.NIGHT_ONLY else 0.0},
            "animation_script": PR.ANIMATION[e],
            "water_reflection": "retirer (bible §1.8-5 : garder le reflet vanilla sous une autre silhouette est un défaut D3)",
            "lumiere_sprite": {"energie_visee_t2": r.get("light_target_t2"), "gain": r.get("light_gain"),
                               "regle": "énergie de la couche light normalisée sur centre_params.light_target (croissante, D2-3)"},
            "couche_principale_sans_emission": bool(r.get("main_sans_emission")),
            "apercu": {"samples": r.get("samples"), "canvas": r.get("canvas"), "origin_px": r.get("origin_px"),
                       "blender": r.get("blender"), "blender_hash": r.get("blender_hash"), "seconds": r.get("seconds"),
                       "variantes": r.get("variants"), "verrou_de_rendu": r.get("render_lock"),
                       "rendu_le": r.get("rendered_at"), "scripts_sha256": r.get("scripts_sha256"),
                       "empreintes": fingerprints(e, r)},
        })
    man = {
        "famille": "centre", "cle_v2": "command", "type": "container", "niveaux": 15,
        "statut": "APERÇU de la phase 1 (lot V3-a) : rien n'est validé ni vu en jeu ; tailles et shift à régénérer au rendu final",
        "source": "tools/render/pieces/levels/centre/ (centre.py, centre_kit.py, centre_ere1..5.py, centre_params.py)",
        "convention": {"px_par_tuile_hr": 64, "scale_hr": 0.5, "shift": "tuiles, multiples exacts de 1/64 (hr) ; même origine pour toutes les couches",
                       "dimensions_hr": "paires (la version lr = hr/2 tombe juste)"},
        "emprise": {"collision_box": [[-1.7, -1.7], [1.7, 1.7]], "selection_box": [[-2, -2], [2, 2]],
                    "regle": "inchangée à tous les niveaux (D1-4) ; seules drawing_box et la hauteur visuelle changent"},
        "interface_v2": {
            "fichier": "prototypes/levels/command.lua",
            "dress": "p.picture = { layers = { <une couche par entrée de « layers », dans l'ordre « ordre »> } } ; chaque couche : "
                     "filename, width, height, shift, scale = 1 (lr) avec hr_version { filename, width, height, shift, scale = 0.5 } "
                     "et les drapeaux « flags » ; p.drawing_box = drawing_box ; p.water_reflection = nil",
            "icons": "icône = rendu de la pose de référence (64 px, 4 mipmaps) + numéro de niveau (lib.tier_icons), à rendre en phase 2",
            "script": "halo_script (rendering.draw_light, minimum_darkness) et animation_script (rendering.draw_animation) attachés à "
                      "l'entité, recréés à chaque remplacement (Levels.on_replaced) ; F44",
            "garde": "dress ne modifie que des champs graphiques (garde de prototypes/levels/common.lua)"},
        "levels": levels,
    }
    os.makedirs(os.path.dirname(DEST), exist_ok=True)
    with open(DEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, ensure_ascii=False)
    ok = sum(1 for lv in levels if lv["apercu"]["empreintes"]["conformes"])
    print("[FO-MANIFESTE] %s : %d niveaux ; empreintes des scripts déterminants conformes : %d/%d ; verrou tracé : %d/%d" % (
        DEST, len(levels), ok, len(levels), sum(1 for lv in levels if lv["apercu"]["verrou_de_rendu"]), len(levels)))


if __name__ == "__main__":
    main()
