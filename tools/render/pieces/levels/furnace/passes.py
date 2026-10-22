"""Passes de rendu propres au four (lot V3, correction V3). S'exécute DANS Blender (bpy).

Enveloppe tools/render/blender/fo_scene.render_passes SANS modifier ce fichier partagé (lot V0b) : la pièce
(furnace_levels.build) remplace l'attribut S.render_passes du module déjà importé par render_piece.py, qui
l'appelle après build(). Le rendu V0 reste intact ; seules l'organisation et le nombre de passes changent.

Corrections de la vérification adverse (problème majeur 1, « émission cuite dans la couche principale ») :
- passe « main » rendue avec les émetteurs ÉTEINTS : chaque matériau émissif est remplacé par son matériau
  froid (furnace_levels.Kit.emit : braise éteinte, verre teinté sombre), comme la bouche du four vanilla au
  repos (luminance médiane 41) ; les couches de lueur restent les seules sources de couleur vive ;
- lueur séparée en deux couches :
  « glow »     : feu de MARCHE (bouche, bain, lave, arcs, cœur…) -> working_visualisations, fadeout, flicker ;
  « glowdeco » : lueurs de DÉCOR (anneaux, cristaux, voyants, perles…) -> working_visualisations, always_draw ;
  chacune est rendue avec les émetteurs de l'autre classe remplacés par du noir opaque (ils masquent ce qui
  est derrière eux, comme dans la passe lueur V0) ;
- correction du problème majeur 2 (ancrage au sol des ères IV et V) : les objets marqués o["fo_patch"]
  (plaque au sol de l'époque) sont absents de toutes les passes V0 et rendus seuls dans une couche
  « patch » (integration_patch du prototype, couche lower-object, bible §1.8.8) : elle n'entre pas dans le
  masque D1 (couche plate au sol, Q13).
"""
import os


def _is_emit(m):
    return m is not None and m.get("fo_kind") == "emissive"


def install(S):
    if getattr(S, "_fo_furnace_passes", None):
        return
    orig = S.render_passes
    cold_cache = {}

    def cold_of(m):
        if not _is_emit(m):
            return m
        c = cold_cache.get(m.name)
        if c is None:
            col = tuple(m.get("fo_cold", (0.02, 0.015, 0.012)))
            c = S.mat_metal(m.name + "_froid", col, rough=float(m.get("fo_cold_rough", 0.6)),
                            metallic=float(m.get("fo_cold_metal", 0.15)), grain=0.30, grain_scale=40.0, dirt=0.5,
                            seed=3.0)
            cold_cache[m.name] = c
        return c

    def only_class(cls):
        def fn(m):
            if _is_emit(m) and m.get("fo_emit_class", "feu") != cls:
                return S._black_mat()
            return m
        return fn

    def sub(scene, out_dir, prefix, key, layer, sun, ground):
        tmp = "%s~%s" % (prefix, key)
        r = orig(scene, out_dir, tmp, [layer], sun, ground)
        if layer not in r:
            return {}
        dst = os.path.join(out_dir, "%s-%s.png" % (prefix, key))
        if os.path.exists(dst):
            os.remove(dst)
        os.replace(r[layer], dst)
        return {key: dst}

    def render_passes(scene, out_dir, prefix, layers, sun, ground):
        objs = S.piece_objects()
        patch = [o for o in objs if o.get("fo_patch")]
        body = [o for o in objs if not o.get("fo_patch")]
        for o in patch:
            o.hide_render = True
        res = {}
        if "main" in layers:
            saved = S._swap_materials(body, cold_of)
            res.update(orig(scene, out_dir, prefix, ["main"], sun, ground))
            S._restore(saved)
        rest = [x for x in layers if x in ("ao", "shadow", "light")]
        if rest:
            res.update(orig(scene, out_dir, prefix, rest, sun, ground))
        if "glow" in layers:
            for cls, key in (("feu", "glow"), ("decor", "glowdeco")):
                saved = S._swap_materials(body, only_class(cls))
                res.update(sub(scene, out_dir, prefix, key, "glow", sun, ground))
                S._restore(saved)
        if patch and "main" in layers:
            for o in body:
                o.hide_render = True
            for o in patch:
                o.hide_render = False
            res.update(sub(scene, out_dir, prefix, "patch", "main", sun, ground))
            for o in body:
                o.hide_render = False
        for o in patch:
            o.hide_render = False
        return res

    S.render_passes = render_passes
    S._fo_furnace_passes = True
