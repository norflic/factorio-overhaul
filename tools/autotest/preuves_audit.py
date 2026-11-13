"""Lot PREUVES (13/11) : tableau d'audit par gisement, et rangement des captures en JPEG.

    py -3.9 -B tools/autotest/preuves_audit.py <archive> [<archive> ...] [--ressources iron-ore,copper-ore]
        [--minutes 30,60,120] [--jpeg <dossier>] [--qualite 82]

<archive> : archive d'un banc `partie-reelle-photos` (ou partie-reelle-N) faite par banc.py --captures ; on lit
fo-shots/factorio.log (lignes [FO-PAVAGE-PREUVE], pavage_common.lua). Pour chaque équipe et gisement des ressources
demandées, aux minutes demandées : foreuses posées (électriques + à brûleur), tuiles couvertes / tuiles, sortie par tapis,
tronçons morts, états des foreuses, et le nombre de foreuses PERDUES par défaut :
  - figees     foreuses waiting_for_space_in_destination (le minerai ne part plus) ;
  - mortes     foreuses qui déversent sur un tapis qu'aucun bras ne lit (sous-ensemble des figées en général) ;
  - courant    foreuses no_power ou low_power ;
  - thermiques foreuses à brûleur encore en place (relique : jamais remplacée par une électrique) ;
  - manquantes foreuses qu'il faudrait pour couvrir les tuiles nues, à la densité de celles qui sont posées
               (tuiles nues / (tuiles couvertes / foreuses)) ; gisement sans foreuse : « jamais exploité ».
La ligne lue est celle de la phase « capture » (re-mesure au tick même de l'image) quand elle existe, sinon la mesure au
tick T. --jpeg : copie les captures de ces gisements en JPEG (qualité 82) sous <dossier>/<graine>/, nom du PNG gardé.
Aucune dépendance hors bibliothèque standard, sauf Pillow pour --jpeg.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pavage_mesures  # noqa: E402


def etats(r):
    out = {}
    for kv in r.get("etats", "-").split(","):
        k, _, v = kv.partition(":")
        if v.isdigit():
            out[k] = int(v)
    return out


def pertes(r):
    e = etats(r)
    n = int(r["foreuses_elec"]) + int(r["foreuses_comb"])
    tuiles, couv = int(r["tuiles"]), int(r["couvertes"])
    manq = None
    if n > 0 and couv > 0:
        manq = int(round((tuiles - couv) / (couv / n)))
    return {
        "foreuses": n,
        "figees": e.get("waiting_for_space_in_destination", 0),
        "mortes": pavage_mesures.num(r, "foreuses_mortes"),
        "courant": e.get("no_power", 0) + e.get("low_power", 0),
        "thermiques": int(r["foreuses_comb"]),
        "manquantes": manq,
        "marche": e.get("working", 0),
    }


def graine(archive):
    p = os.path.join(archive, "seed.txt")
    if os.path.exists(p):
        with open(p, encoding="utf-8", errors="replace") as f:
            t = "".join(c for c in f.read() if c.isdigit())
        if t:
            return t
    return os.path.basename(os.path.normpath(archive))


def lire(archive, ressources, minutes):
    """{(equipe, ressource, n): {minute: ligne}} : phase capture si elle existe, sinon T."""
    rows, _, real = pavage_mesures.parse(os.path.join(archive, "fo-shots", "factorio.log"))
    out = {}
    for phase in ("T", "capture"):  # la phase capture écrase la mesure au tick T
        for r in rows:
            if r.get("phase", "T") != phase or r["ressource"] not in ressources:
                continue
            m = int(r["minute"])
            if m not in minutes or (phase == "capture" and "gros-plan" in r.get("capture", "")):
                continue
            out.setdefault((r["equipe"], r["ressource"], int(r["n"])), {})[m] = r
    return out, real


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("archives", nargs="+")
    ap.add_argument("--ressources", default="iron-ore,copper-ore")
    ap.add_argument("--minutes", default="30,60,120")
    ap.add_argument("--jpeg")
    ap.add_argument("--qualite", type=int, default=82)
    a = ap.parse_args()
    ress = a.ressources.split(",")
    minutes = [int(x) for x in a.minutes.split(",")]
    for arch in a.archives:
        g = graine(arch)
        data, real = lire(arch, ress, minutes)
        print(f"\n## Graine {g}\n\nJournal : {real}\n")
        print("| équipe | gisement | min | tuiles | dist. QG | foreuses (élec + brûleur) | en marche | couvertes / tuiles | sortie par tapis "
              "| fin de chaîne | figées | mortes (bout du tapis) | sans courant | thermiques | manquantes | fantômes | image |")
        print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        tot = {m: dict(foreuses=0, marche=0, figees=0, mortes=0, courant=0, thermiques=0, manquantes=0, jamais=0, tuiles_jamais=0)
               for m in minutes}
        files = []
        for key in sorted(data):
            for m in minutes:
                r = data[key].get(m)
                if not r:
                    continue
                p = pertes(r)
                t = tot[m]
                for k in ("foreuses", "marche", "figees", "mortes", "courant", "thermiques"):
                    t[k] += p[k]
                if p["manquantes"] is None:
                    t["jamais"] += 1
                    t["tuiles_jamais"] += int(r["tuiles"])
                else:
                    t["manquantes"] += p["manquantes"]
                cap = r.get("capture", "-")
                if cap != "-":
                    files.append(cap)
                manq = "jamais exploité" if p["manquantes"] is None else str(p["manquantes"])
                morts = f'{p["mortes"]} ({r.get("morts", "-")})' if p["mortes"] else "0"
                print(f'| {key[0]} | {key[1]} {key[2]} | {m} | {r["tuiles"]} | {r["distance_qg"]} | {p["foreuses"]} ({r["foreuses_elec"]} + '
                      f'{r["foreuses_comb"]}) | {p["marche"]} | {r["couvertes"]} / {r["tuiles"]} ({r["couverture"]}) | {r["sortie_tapis"]} | '
                      f'{r.get("fin_chaine", "-")} | {p["figees"]} | {morts} | {p["courant"]} | {p["thermiques"]} | {manq} | '
                      f'{r.get("fantomes", "-")} | {cap} |')
        print()
        for m in minutes:
            t = tot[m]
            print(f'- minute {m} : {t["foreuses"]} foreuses posées, {t["marche"]} en marche ; perdues : figées {t["figees"]} '
                  f'(dont sur tapis mort {t["mortes"]}), sans courant {t["courant"]}, thermiques {t["thermiques"]}, manquantes '
                  f'{t["manquantes"]} ; gisements jamais exploités {t["jamais"]} ({t["tuiles_jamais"]} tuiles)')
        if a.jpeg:
            from PIL import Image
            dest = os.path.join(a.jpeg, g)
            os.makedirs(dest, exist_ok=True)
            shots = os.path.join(arch, "fo-shots")
            names = sorted(os.listdir(shots))
            n = 0
            for cap in sorted(set(files)):
                stem = cap[:-4] if cap.endswith(".png") else cap
                # le journal de la mesure au tick T nomme l'image sans son rang (NNN-) : on la retrouve par la fin du nom
                for name in names:
                    if name.endswith(".png") and (name == cap or name[4:] == stem + ".png"):
                        with Image.open(os.path.join(shots, name)) as im:
                            im.convert("RGB").save(os.path.join(dest, name[:-4] + ".jpg"), quality=a.qualite, optimize=True)
                        n += 1
            print(f"\n{n} image(s) en JPEG (qualité {a.qualite}) dans {dest}")


if __name__ == "__main__":
    main()
