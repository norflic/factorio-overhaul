"""CONTRÔLE DE CONSTRUCTION (passe 5, deuxième temps du kit ; OUTIL COMMUN des familles depuis le lot K0) : construit
des variantes d'une famille dans Blender SANS RENDU et écrit leur EMPREINTE (pièces par type, sommets, objets, et une
somme SHA-1 de la géométrie de chaque objet : nom de l'objet, NOMS des matières, sommets arrondis au 1/100 000, faces).
Deux empreintes égales = même géométrie, mêmes matières aux mêmes endroits. Sert à prouver qu'un changement du kit ne
change RIEN quand ses clés valent None. FICHIER DU KIT.

TOUJOURS par le verrou de rendu (interdit n° 6) :
    python tools/render/with_render_lock.py -- blender -b --factory-startup -noaudio --python-exit-code 1
        -P tools/render/pieces/levels/commun/construction.py -- --out empreinte.json [--names a,b | --tout]
        [--famille gun_e | --dossier CHEMIN] [--matieres]
        [--habillage pionnier|fusion|legende | --habillages f_forge,f_vapeur,…] [--tailles 2,3,4,5,6]
--famille NOM (lot K0) : dossier tools/render/pieces/levels/NOM (défaut gun_e), qui donne piece.py (PIECE, build) ;
--dossier CHEMIN : un dossier de famille ailleurs (par exemple une copie d'archive de gun_e d'avant le lot K0, pour une
empreinte « avant » : le dossier de la famille passe DEVANT commun/ dans sys.path, ses propres kit.py et parts*.py
l'emportent s'il en a).
--tout : toutes les variantes de piece.PIECE (mitrailleuse : 72 ; e01-piece, eNN-socle|piece|tete-N|tete-E pour
N = 2 à 15, kS-socle|tete-N|tete-E).
--matieres (lot K0) : ajoute l'empreinte des MATIÈRES de chaque variante (pour chaque matière posée sur un objet :
nom, propriétés propres, nœuds, réglages des nœuds, valeurs des entrées ET des sorties (couleur d'un nœud RGB) arrondies
au 1/1 000 000, liens) : prouve qu'une
matière n'a changé ni de couleur, ni de rugosité, ni de graine de bruit, ce que l'empreinte de géométrie ne voit pas
(elle ne lit que les NOMS des matières).
--forte (correction K0, défaut 4 de la vérification, 23/10) : EMPREINTE FORTE, celle à rejouer après toute retouche du
kit. Sans elle, l'empreinte ne lit que les sommets LOCAUX des objets maillés de la pièce, les NOMS des matières et le
NOMBRE de halos : un mutant « puissance des halos × 1,5 » passait inaperçu, comme un objet déplacé ou tourné, un
biseau changé ou un réglage de nœud hors de _REGLAGES. Avec --forte, pour chaque variante :
  - TOUS les objets de bpy.data, lumières de halo comprises (fo_scene.halo_light les lie à la scène, hors de la
    collection de la pièce) : propriétés RNA scalaires (matrix_world, location, rotation…), collections, parent ;
  - les MODIFICATEURS de chaque objet et tous leurs réglages (largeur du biseau, angle de lissage…) ;
  - les données des lumières (couleur, énergie, rayon) ;
  - le maillage ÉVALUÉ (modificateurs appliqués) en coordonnées MONDE au 1/10 000, indices de matière, lissage,
    normales de coin ;
  - chaque matière : propriétés RNA, TOUS les nœuds (propriétés RNA, entrées ET sorties avec leur état actif, rampes,
    groupes), liens ; le monde ;
  - les APPELS de fo_scene.mat_metal, mat_emissive et mat_flat faits pendant la construction, avec tous leurs
    arguments, GRAINES comprises (« graines » : graine de chaque matière). Les graines sont aujourd'hui INERTES dans
    Blender 5.2.2 (commun/ages.py, en-tête) : seul ce relevé voit un glissement d'ordre des metal().
Reprise de l'empreinte forte du vérificateur adverse de K0 (fo-logs/2026-10-23_suite/K0/verification/empreinte_forte.py).
Comparer : empreintes.py AVANT.json APRES.json --forte (dit les objets, matières et graines qui diffèrent).
--habillages (passe 5, troisième temps) : plusieurs habillages d'essai du témoin dans UNE session, sur les variantes
kS-socle, kS-tete-N, kS-tete-E des tailles --tailles (défaut 2 à 6) ; clés « habillage/variante » ; une erreur de
construction est notée (« erreur ») et la suite continue ; code de sortie 1 s'il y en a une.
Comparer deux empreintes : py -3.9 tools/render/pieces/levels/commun/empreintes.py AVANT.json APRES.json.
"""
import argparse
import hashlib
import json
import os
import struct
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(RENDER, "blender"))
sys.path.insert(0, RENDER)
sys.path.insert(0, HERE)
import fo_calib as C  # noqa: E402
import fo_scene as S  # noqa: E402
import importlib.util  # noqa: E402

# réglages des nœuds qui changent le rendu (les autres propriétés d'un nœud sont de l'interface : place, largeur…)
_REGLAGES = ("operation", "noise_dimensions", "noise_type", "normalize", "data_type", "blend_type", "clamp_factor",
             "clamp_result", "interpolation_type", "clamp", "use_clamp", "factor_mode", "only_local", "samples",
             "inside", "from_instancer", "distribution", "subsurface_method")


def _val(v):
    if isinstance(v, float):
        return repr(round(v, 6))
    if isinstance(v, (int, bool, str)) or v is None:
        return repr(v)
    try:
        return repr(tuple(round(float(x), 6) for x in v))
    except TypeError:
        return repr(getattr(v, "name", str(type(v))))


def empreinte_matiere(m):
    """SHA-1 d'une matière : nom, propriétés propres (fo_reflet…), nœuds (type, réglages, valeurs des entrées), liens."""
    h = hashlib.sha1()
    h.update(m.name.encode("utf-8"))
    for k in sorted(m.keys()):
        h.update(("|%s=%s" % (k, _val(m[k]))).encode("utf-8"))
    h.update(("|diffuse=%s" % _val(m.diffuse_color)).encode("utf-8"))
    nt = m.node_tree if m.use_nodes else None
    if nt is not None:
        for n in sorted(nt.nodes, key=lambda n: n.name):
            h.update(("|N:%s:%s" % (n.name, n.bl_idname)).encode("utf-8"))
            for a in _REGLAGES:
                if hasattr(n, a):
                    h.update(("|%s=%s" % (a, _val(getattr(n, a)))).encode("utf-8"))
            for i in n.inputs:
                if hasattr(i, "default_value"):
                    h.update(("|i:%s=%s" % (i.identifier, _val(i.default_value))).encode("utf-8"))
            # les nœuds RGB et Valeur portent leur couleur sur leur SORTIE (fo_scene.mat_metal : base, rouille) ; sans
            # elle, une couleur changée passait inaperçue (mutant du 23/10, lot K0)
            for o in n.outputs:
                if hasattr(o, "default_value"):
                    h.update(("|o:%s=%s" % (o.identifier, _val(o.default_value))).encode("utf-8"))
        for ln in sorted(nt.links, key=lambda l: (l.from_node.name, l.from_socket.identifier, l.to_node.name,
                                                   l.to_socket.identifier)):
            h.update(("|L:%s.%s>%s.%s" % (ln.from_node.name, ln.from_socket.identifier, ln.to_node.name,
                                          ln.to_socket.identifier)).encode("utf-8"))
    return h.hexdigest()


def empreinte_matieres(objs):
    mats = {}
    for o in objs:
        if o.type != "MESH":
            continue
        for m in o.data.materials:
            if m is not None and m.name not in mats:
                mats[m.name] = empreinte_matiere(m)
    tot = hashlib.sha1("".join("%s:%s;" % (k, mats[k]) for k in sorted(mats)).encode("utf-8")).hexdigest()
    return tot, dict(sorted(mats.items()))


def charger_piece(a):
    """piece.py de la famille (--dossier, sinon --famille) ; le dossier de la famille passe devant commun/."""
    d = os.path.abspath(a.dossier) if a.dossier else os.path.join(os.path.dirname(HERE), a.famille)
    if not os.path.isfile(os.path.join(d, "piece.py")):
        raise SystemExit("piece.py introuvable dans %s" % d)
    if d in sys.path:
        sys.path.remove(d)
    sys.path.insert(0, d)
    spec = importlib.util.spec_from_file_location("famille_piece", os.path.join(d, "piece.py"))
    piece = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(piece)
    for k, v in piece.PIECE.get("calib", {}).items():
        setattr(C, k, v)
    return piece, d


def empreinte(objs):
    out = []
    for o in sorted(objs, key=lambda o: o.name):
        if o.type != "MESH":
            continue
        me = o.data
        h = hashlib.sha1()
        h.update(o.name.encode("utf-8"))
        h.update(",".join(m.name for m in me.materials if m).encode("utf-8"))
        for v in me.vertices:
            h.update(struct.pack("<3q", *(int(round(c * 100000)) for c in v.co)))
        for p in me.polygons:
            h.update(struct.pack("<%di" % len(p.vertices), *p.vertices))
        out.append({"objet": o.name, "sommets": len(me.vertices), "faces": len(me.polygons), "sha1": h.hexdigest()})
    return out


# ---------------------------------------------------------------------------------------------------------------------
# EMPREINTE FORTE (--forte)
# ---------------------------------------------------------------------------------------------------------------------
_SKIP = {"rna_type", "name_full", "session_uid", "is_evaluated", "original", "users", "use_fake_user", "use_extra_user",
         "is_embedded_data", "is_missing", "is_runtime_data", "tag", "is_library_indirect", "library",
         "library_weak_reference", "asset_data", "override_library", "preview", "id_type", "select", "is_editmode",
         "mode", "bound_box", "dimensions", "width", "height", "location_absolute", "is_active_output",
         "warning_propagation", "internal_links", "is_registered_node_type", "type", "parent"}


def _plat(v):
    try:
        out = []
        for x in v:
            out.extend(_plat(x))
        return out
    except TypeError:
        return [v]


def _f5(x):
    if isinstance(x, float):
        r = round(x, 5)
        return repr(0.0 if r == 0 else r)
    return repr(x)


def _scal(obj, pre):
    """Propriétés RNA scalaires (nombres, tableaux, énumérations, chaînes, pointeurs vers un ID) et propriétés propres."""
    out = []
    for p in obj.bl_rna.properties:
        k = p.identifier
        if k in _SKIP or k.startswith("bl_") or k.startswith("show_"):
            continue
        try:
            v = getattr(obj, k)
        except Exception:
            continue
        t = p.type
        if t in ("BOOLEAN", "INT", "FLOAT"):
            if isinstance(v, (bool, int, float)):
                txt = _f5(v)
            else:
                try:
                    txt = "(" + ",".join(_f5(x) for x in _plat(v)) + ")"
                except Exception:
                    continue
        elif t == "ENUM":
            txt = repr(sorted(v)) if isinstance(v, set) else repr(v)
        elif t == "STRING":
            txt = repr(v)
        elif t == "POINTER":
            if v is None:
                txt = "None"
            elif isinstance(v, bpy.types.ID):
                txt = "ID:" + v.name
            else:
                continue
        else:
            continue
        out.append("%s.%s=%s" % (pre, k, txt))
    try:
        for k in sorted(obj.keys()):
            vv = obj[k]
            try:
                vv = _plat(vv)
            except Exception:
                pass
            out.append("%s[%s]=%s" % (pre, k, ",".join(_f5(x) for x in vv) if isinstance(vv, list) else _f5(vv)))
    except Exception:
        pass
    return out


def _prise(sk):
    if not hasattr(sk, "default_value"):
        return "-"
    v = sk.default_value
    try:
        return "(" + ",".join(_f5(float(x)) for x in v) + ")"
    except TypeError:
        return _f5(v) if isinstance(v, (int, float, bool, str)) else repr(getattr(v, "name", type(v).__name__))


def _arbre(nt, pre, prof=0):
    L = []
    for n in sorted(nt.nodes, key=lambda n: n.name):
        q = "%s/N:%s" % (pre, n.name)
        L.append("%s:%s" % (q, n.bl_idname))
        L += _scal(n, q)
        for i, sk in enumerate(n.inputs):
            L.append("%s.in%d:%s:%s=%s" % (q, i, sk.identifier, getattr(sk, "enabled", True), _prise(sk)))
        for i, sk in enumerate(n.outputs):
            L.append("%s.out%d:%s=%s" % (q, i, sk.identifier, _prise(sk)))
        if getattr(n, "color_ramp", None) is not None:
            cr = n.color_ramp
            L.append("%s.ramp=%s/%s:%s" % (q, cr.interpolation, cr.color_mode, ";".join(
                "%s@%s" % (_f5(el.position), ",".join(_f5(x) for x in el.color)) for el in cr.elements)))
        if getattr(n, "node_tree", None) is not None and prof < 3:
            L += _arbre(n.node_tree, q + "/G", prof + 1)
    for ln in sorted(nt.links, key=lambda l: (l.from_node.name, l.from_socket.identifier, l.to_node.name,
                                               l.to_socket.identifier)):
        L.append("%s/L:%s.%s(%d)>%s.%s(%d)" % (pre, ln.from_node.name, ln.from_socket.identifier,
                                             list(ln.from_node.outputs).index(ln.from_socket), ln.to_node.name,
                                             ln.to_socket.identifier, list(ln.to_node.inputs).index(ln.to_socket)))
    return L


def _lignes_matiere(m):
    L = _scal(m, "M:" + m.name)
    if getattr(m, "use_nodes", False) and m.node_tree is not None:
        L += _arbre(m.node_tree, "M:" + m.name)
    return L


def _h(lignes):
    return hashlib.sha1(chr(10).join(lignes).encode("utf-8")).hexdigest()


def empreinte_forte():
    """Empreinte forte de la scène entière (voir --forte dans l'en-tête) : objets, matières, monde."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    objs, mats = {}, {}
    for o in sorted(bpy.data.objects, key=lambda o: o.name):
        L = ["O:%s:%s" % (o.name, o.type)]
        L += _scal(o, "O")
        L.append("colls=%s" % sorted(c.name for c in o.users_collection))
        L.append("parent=%s" % (o.parent.name if o.parent else None))
        for md in o.modifiers:
            L += _scal(md, "MOD:" + md.name)
        if o.type == "MESH":
            L.append("mats=%s" % [m.name if m else None for m in o.data.materials])
            for m in o.data.materials:
                if m is not None and m.name not in mats:
                    mats[m.name] = _h(_lignes_matiere(m))
            oe = o.evaluated_get(dg)
            me = oe.to_mesh()
            mw = oe.matrix_world
            gh = hashlib.sha1()
            for v in me.vertices:
                w = mw @ v.co
                gh.update(("%d,%d,%d;" % tuple(int(round(c * 10000)) for c in w)).encode())
            for p in me.polygons:
                gh.update(("%s|%d|%d;" % (",".join(map(str, p.vertices)), p.material_index, int(p.use_smooth))).encode())
            try:
                for cn in me.corner_normals:
                    gh.update(("%d,%d,%d;" % tuple(int(round(c * 1000)) for c in cn.vector)).encode())
            except Exception:
                pass
            L.append("eval_v=%d eval_f=%d geo=%s" % (len(me.vertices), len(me.polygons), gh.hexdigest()))
            oe.to_mesh_clear()
        elif o.data is not None:
            L += _scal(o.data, "D")
        objs[o.name] = _h(L)
    w = bpy.context.scene.world
    wh = _h(_lignes_matiere(w) if w is not None else [])
    return objs, mats, wh


def _rep(v):
    if isinstance(v, dict):
        return "{" + ", ".join("%r: %s" % (k, _rep(x)) for k, x in v.items()) + "}"
    if isinstance(v, (list, tuple)):
        return ("[%s]" if isinstance(v, list) else "(%s)") % ", ".join(_rep(x) for x in v)
    return repr(v)


class Releve:
    """Relève les appels de S.mat_metal / mat_emissive / mat_flat pendant une construction (arguments complets, graines
    comprises). Les fonctions d'origine sont appelées telles quelles : la construction ne change pas."""
    FONCTIONS = ("mat_metal", "mat_emissive", "mat_flat")

    def __init__(self):
        self.appels, self.graines, self._orig = [], {}, {}

    def __enter__(self):
        for fn in self.FONCTIONS:
            if hasattr(S, fn):
                self._orig[fn] = getattr(S, fn)

                def emballe(*args, _fn=fn, **kw):
                    self.appels.append("%s %s %s" % (_fn, _rep(list(args)), _rep(dict(sorted(kw.items())))))
                    if "seed" in kw and args:
                        self.graines[str(args[0])] = kw["seed"]
                    return self._orig[_fn](*args, **kw)
                setattr(S, fn, emballe)
        return self

    def __exit__(self, *exc):
        for fn, f in self._orig.items():
            setattr(S, fn, f)
        return False


def forte(res, cle, rel):
    """Ajoute à res[cle] l'empreinte forte de la scène et le relevé des appels de matières ; rend la somme totale."""
    objs, mats, wh = empreinte_forte()
    ah = _h(rel.appels)
    tot = _h(["%s:%s" % (k, objs[k]) for k in sorted(objs)] + ["%s:%s" % (k, mats[k]) for k in sorted(mats)]
             + [wh, ah])
    res[cle]["sha1_forte"] = tot
    res[cle]["forte"] = {"objets": objs, "matieres": mats, "monde": wh, "appels": ah, "nb_appels": len(rel.appels),
                         "graines": dict(sorted(rel.graines.items()))}
    return tot


def _construire(piece, name, a):
    """Remet la scène à zéro et construit la variante ; avec --forte, sous relevé des appels de matières."""
    S.reset()
    S.HALO_LIGHTS.clear()
    S.EXTRA_LIGHTS.clear()
    S._BLACK = S._WHITE = S._AO = None
    S._BOOSTED.clear()
    rel = Releve()
    if a.forte:
        with rel:
            info = piece.build(S, C, name)
    else:
        info = piece.build(S, C, name)
    bpy.context.view_layer.update()
    return info, rel


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", default="")
    ap.add_argument("--tout", action="store_true")
    ap.add_argument("--out", required=True)
    ap.add_argument("--habillage", default="")
    ap.add_argument("--habillages", default="")
    ap.add_argument("--tailles", default="2,3,4,5,6")
    ap.add_argument("--famille", default="gun_e")
    ap.add_argument("--dossier", default="")
    ap.add_argument("--matieres", action="store_true")
    ap.add_argument("--forte", action="store_true")
    a = ap.parse_args(argv)
    if a.habillages:
        return plusieurs(a)
    if a.habillage:
        os.environ["FO_HABILLAGE_ESSAI"] = a.habillage
    piece, dossier = charger_piece(a)
    names = sorted(piece.PIECE["variants"]) if a.tout else [n for n in a.names.split(",") if n]
    res = {}
    t0 = time.time()
    for name in names:
        info, rel = _construire(piece, name, a)
        objs = S.piece_objects()
        emp = empreinte(objs)
        h = hashlib.sha1("".join(e["sha1"] for e in emp).encode("ascii")).hexdigest()
        res[name] = {"pieces": info["count"], "nb_pieces": sum(info["count"].values()), "halos": info["halos"],
                     "sommets": sum(e["sommets"] for e in emp), "objets": len(emp), "sha1": h, "detail": emp}
        hm = ""
        if a.matieres:
            tot, det = empreinte_matieres(objs)
            res[name]["sha1_matieres"] = tot
            res[name]["matieres"] = det
            hm = " matières %s (%d)" % (tot[:12], len(det))
        if a.forte:
            hm += " forte %s (%d objets, %d appels)" % (forte(res, name, rel)[:12], len(res[name]["forte"]["objets"]),
                                                        res[name]["forte"]["nb_appels"])
        print("[FO-CONSTRUCTION] %s %d pièces %d sommets %d objets %s%s" % (
            name, res[name]["nb_pieces"], res[name]["sommets"], len(emp), h[:12], hm), flush=True)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump({"dossier": dossier, "kit": HERE, "habillage": a.habillage or None, "forte": a.forte,
                   "secondes": round(time.time() - t0, 1), "variantes": res}, f, indent=1, sort_keys=True)
    print("[FO-CONSTRUCTION] %d variantes en %.0f s -> %s" % (len(names), time.time() - t0, a.out), flush=True)


def plusieurs(a):
    import traceback
    piece, dossier = charger_piece(a)
    names = ["k%s-%s" % (s, p) for s in a.tailles.split(",") if s for p in ("socle", "tete-N", "tete-E")]
    res, err = {}, 0
    t0 = time.time()
    for h in [x for x in a.habillages.split(",") if x]:
        os.environ["FO_HABILLAGE_ESSAI"] = h
        for name in names:
            cle = "%s/%s" % (h, name)
            try:
                info, rel = _construire(piece, name, a)
            except Exception:
                err += 1
                res[cle] = {"erreur": traceback.format_exc()}
                print("[FO-CONSTRUCTION] %s ERREUR" % cle, flush=True)
                print(res[cle]["erreur"], flush=True)
                continue
            objs = S.piece_objects()
            emp = empreinte(objs)
            # lot K0 : somme SHA-1 aussi pour les habillages d'essai (comparables avec empreintes.py)
            sha = hashlib.sha1("".join(e["sha1"] for e in emp).encode("ascii")).hexdigest()
            res[cle] = {"pieces": info["count"], "nb_pieces": sum(info["count"].values()), "halos": info["halos"],
                        "sommets": sum(e["sommets"] for e in emp), "objets": len(emp), "sha1": sha}
            if a.matieres:
                res[cle]["sha1_matieres"] = empreinte_matieres(objs)[0]
            if a.forte:
                forte(res, cle, rel)
            print("[FO-CONSTRUCTION] %s %d pièces %d sommets %s" % (cle, res[cle]["nb_pieces"], res[cle]["sommets"],
                                                                   sha[:12]), flush=True)
    os.environ.pop("FO_HABILLAGE_ESSAI", None)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump({"dossier": dossier, "kit": HERE, "habillages": a.habillages, "secondes": round(time.time() - t0, 1),
                   "erreurs": err, "variantes": res}, f, indent=1, sort_keys=True)
    print("[FO-CONSTRUCTION] %d constructions, %d erreur(s), %.0f s -> %s" % (len(res), err, time.time() - t0, a.out),
          flush=True)
    if err:
        sys.exit(1)


main()
