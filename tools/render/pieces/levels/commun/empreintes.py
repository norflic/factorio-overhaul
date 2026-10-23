"""COMPARAISON DE DEUX EMPREINTES de construction.py (lot K0, 23/10). Python pur (3.9).

    py -3.9 tools/render/pieces/levels/commun/empreintes.py AVANT.json APRES.json [--matieres]

Compare, variante par variante : la somme SHA-1 de la géométrie (« sha1 » : objets, NOMS des matières, sommets, faces),
le nombre de pièces, de sommets, d'objets et de halos ; avec --matieres, aussi l'empreinte des matières
(« sha1_matieres », écrite par construction.py --matieres : valeurs des nœuds, graines de bruit, liens). Pour une
variante qui diffère, dit le premier objet (ou la première matière) qui change.
Sortie : une ligne par variante différente, puis « [FO-EMPREINTES] N variantes comparées, D différente(s), A absente(s) ».
Code de sortie 0 si tout est IDENTIQUE (mêmes variantes des deux côtés), 1 sinon.
"""
import argparse
import json
import sys


def premier_ecart(da, db, cle):
    """Premier élément qui diffère entre deux listes de détails (objets) ou deux dict (matières)."""
    if isinstance(da, dict):
        for k in sorted(set(da) | set(db)):
            if da.get(k) != db.get(k):
                return "%s %s : %s -> %s" % (cle, k, (da.get(k) or "absent")[:12], (db.get(k) or "absent")[:12])
        return None
    ia = {d["objet"]: d for d in da}
    ib = {d["objet"]: d for d in db}
    for k in sorted(set(ia) | set(ib)):
        a, b = ia.get(k), ib.get(k)
        if a != b:
            return "objet %s : %s -> %s" % (k, a and "%d sommets %s" % (a["sommets"], a["sha1"][:12]) or "absent",
                                            b and "%d sommets %s" % (b["sommets"], b["sha1"][:12]) or "absent")
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("avant")
    ap.add_argument("apres")
    ap.add_argument("--matieres", action="store_true")
    a = ap.parse_args()
    A = json.load(open(a.avant, encoding="utf-8"))["variantes"]
    B = json.load(open(a.apres, encoding="utf-8"))["variantes"]
    noms = sorted(set(A) | set(B))
    diff = absent = 0
    champs = ["sha1", "nb_pieces", "sommets", "objets", "halos"] + (["sha1_matieres"] if a.matieres else [])
    for n in noms:
        if n not in A or n not in B:
            absent += 1
            print("%-26s ABSENTE %s" % (n, "avant" if n not in A else "après"))
            continue
        x, y = A[n], B[n]
        if "erreur" in x or "erreur" in y:
            diff += 1
            print("%-26s ERREUR de construction (%s)" % (n, "avant" if "erreur" in x else "après"))
            continue
        if a.matieres and ("sha1_matieres" not in x or "sha1_matieres" not in y):
            diff += 1
            print("%-26s pas d'empreinte des matières (construction.py --matieres)" % n)
            continue
        ecarts = [c for c in champs if x.get(c) != y.get(c)]
        if ecarts:
            diff += 1
            det = None
            if "detail" in x and "detail" in y:
                det = premier_ecart(x["detail"], y["detail"], "objet")
            if det is None and a.matieres and "matieres" in x and "matieres" in y:
                det = premier_ecart(x["matieres"], y["matieres"], "matière")
            print("%-26s DIFFÉRENTE (%s)%s" % (n, ", ".join(ecarts), (" ; " + det) if det else ""))
    print("[FO-EMPREINTES] %d variantes comparées, %d différente(s), %d absente(s)%s" % (
        len(noms), diff, absent, " (géométrie et matières)" if a.matieres else " (géométrie)"))
    sys.exit(1 if (diff or absent) else 0)


if __name__ == "__main__":
    main()
