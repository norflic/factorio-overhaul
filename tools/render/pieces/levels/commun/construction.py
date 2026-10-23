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
        S.reset()
        S.HALO_LIGHTS.clear()
        S.EXTRA_LIGHTS.clear()
        S._BLACK = S._WHITE = S._AO = None
        S._BOOSTED.clear()
        info = piece.build(S, C, name)
        bpy.context.view_layer.update()
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
        print("[FO-CONSTRUCTION] %s %d pièces %d sommets %d objets %s%s" % (
            name, res[name]["nb_pieces"], res[name]["sommets"], len(emp), h[:12], hm), flush=True)
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump({"dossier": dossier, "kit": HERE, "habillage": a.habillage or None,
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
            S.reset()
            S.HALO_LIGHTS.clear()
            S.EXTRA_LIGHTS.clear()
            S._BLACK = S._WHITE = S._AO = None
            S._BOOSTED.clear()
            cle = "%s/%s" % (h, name)
            try:
                info = piece.build(S, C, name)
            except Exception:
                err += 1
                res[cle] = {"erreur": traceback.format_exc()}
                print("[FO-CONSTRUCTION] %s ERREUR" % cle, flush=True)
                print(res[cle]["erreur"], flush=True)
                continue
            bpy.context.view_layer.update()
            objs = S.piece_objects()
            emp = empreinte(objs)
            # lot K0 : somme SHA-1 aussi pour les habillages d'essai (comparables avec empreintes.py)
            sha = hashlib.sha1("".join(e["sha1"] for e in emp).encode("ascii")).hexdigest()
            res[cle] = {"pieces": info["count"], "nb_pieces": sum(info["count"].values()), "halos": info["halos"],
                        "sommets": sum(e["sommets"] for e in emp), "objets": len(emp), "sha1": sha}
            if a.matieres:
                res[cle]["sha1_matieres"] = empreinte_matieres(objs)[0]
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
