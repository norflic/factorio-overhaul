# Lot IA3-k : rejouer la preuve en moteur réel (après fusion) : un banc à la fois, par la file (banc.py), --qui IA3-k.
# Usage (Git Bash, depuis la racine du mod) :
#   bash tools/autotest/ia3k_rejouer.sh "<source du mod, chemin Windows>" <dossier d'archives> [rapide|complet|temoins]
#   rapide  : C2 et C5 (2 graines), gardes verif-guide (2 graines) et content : 7 bancs ;
#   complet : (par défaut) rapide + C1, C3, B5 (graine 20261020), pnj-reduit, captures de route et de peur : 13 bancs ;
#   temoins : les témoins seuls (réglage du lot éteint ; à jouer UNE fois par graine et par base, pas à chaque commit).
# Puis : py -3.9 -B tools/autotest/ia3k_bilan.py <dossier d'archives>  (FAIT et BILAN de chaque banc) et
#        py -3.9 -B tools/autotest/ia3k_economie.py <archive memoire-*> 70  (économie d'Écarlate à 70 min).
# Une archive déjà présente (banc.txt) n'est pas refaite : on peut relancer après une coupure. Un seul lanceur à la fois
# (consigne de l'intégrateur, 27/10 : pas deux parties identiques en file).
SRC="$1"
OUT="$2"
MODE="${3:-complet}"
if [ -z "$SRC" ] || [ -z "$OUT" ]; then
  echo "usage : bash tools/autotest/ia3k_rejouer.sh \"<source>\" <archives> [rapide|complet|temoins]"
  exit 1
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
BANC="$HERE/banc.py"
mkdir -p "$OUT"
run() {
  local name="$1"; shift
  if [ -f "$OUT/$name/banc.txt" ]; then echo "[deja fait] $name"; return; fi
  py -3.9 -B "$BANC" --out "$OUT/$name" --qui IA3-k "$@" 2>&1 | grep -a "BANC\]" | tail -2
}
if [ "$MODE" = "temoins" ]; then
  run route-temoin-20261020 --graine 20261020 -- 54700 ia3k-route-temoin "$SRC"
  run route-temoin-123456789 --graine 123456789 -- 54700 ia3k-route-temoin "$SRC"
  run variete-temoin-20261020 --graine 20261020 -- 54700 ia3k-variete-temoin "$SRC"
  run memoire-temoin-20261020 --graine 20261020 -- 288700 ia3k-memoire-temoin "$SRC"
  run memoire-temoin-123456789 --graine 123456789 -- 288700 ia3k-memoire-temoin "$SRC"
  echo "IA3-K TEMOINS TERMINES"
  exit 0
fi
run route-20261020 --graine 20261020 -- 54700 ia3k-route "$SRC"
run memoire-20261020 --graine 20261020 -- 288700 ia3k-memoire "$SRC"
run route-123456789 --graine 123456789 -- 54700 ia3k-route "$SRC"
run memoire-123456789 --graine 123456789 -- 288700 ia3k-memoire "$SRC"
run verif-guide-271828182 --graine 271828182 -- 216000 verif-guide "$SRC"
run verif-guide-1618033988 --graine 1618033988 -- 216000 verif-guide "$SRC"
run content -- 4000 content "$SRC"
if [ "$MODE" = "rapide" ]; then echo "IA3-K REJEU RAPIDE TERMINE"; exit 0; fi
run variete-20261020 --graine 20261020 -- 54700 ia3k-variete "$SRC"
run peur-20261020 --graine 20261020 -- 30100 ia3k-peur "$SRC"
run soldats-20261020 --graine 20261020 -- 108100 ia3k-soldats "$SRC"
run pnj-reduit -- 216000 pnj-reduit "$SRC"
run captures-route --captures -- 54700 ia3k-route "$SRC"
run captures-peur --captures -- 30100 ia3k-peur "$SRC"
echo "IA3-K REJEU TERMINE"
