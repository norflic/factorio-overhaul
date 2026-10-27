# Lot IA3-k : rejouer la preuve en moteur réel (après fusion) : un banc à la fois, par la file (banc.py), --qui IA3-k.
# Usage (Git Bash, depuis la racine du mod) :
#   bash tools/autotest/ia3k_rejouer.sh "<source du mod, chemin Windows>" <dossier d'archives> [rapide]
# « rapide » : seulement les preuves C2, C5 (2 graines) et les gardes verif-guide (2 graines), content.
# Puis : py -3.9 -B tools/autotest/ia3k_bilan.py <dossier d'archives>  (FAIT et BILAN de chaque banc).
# Une archive déjà présente (banc.txt) n'est pas refaite : on peut relancer après une coupure.
SRC="$1"
OUT="$2"
MODE="$3"
if [ -z "$SRC" ] || [ -z "$OUT" ]; then
  echo "usage : bash tools/autotest/ia3k_rejouer.sh \"<source>\" <archives> [rapide]"
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
run route-20261020 --graine 20261020 -- 54700 ia3k-route "$SRC"
run memoire-20261020 --graine 20261020 -- 288700 ia3k-memoire "$SRC"
run route-123456789 --graine 123456789 -- 54700 ia3k-route "$SRC"
run memoire-123456789 --graine 123456789 -- 288700 ia3k-memoire "$SRC"
run verif-guide-271828182 --graine 271828182 -- 216000 verif-guide "$SRC"
run verif-guide-1618033988 --graine 1618033988 -- 216000 verif-guide "$SRC"
run content -- 4000 content "$SRC"
if [ "$MODE" = "rapide" ]; then echo "IA3-K REJEU RAPIDE TERMINE"; exit 0; fi
run peur-20261020 --graine 20261020 -- 30100 ia3k-peur "$SRC"
run variete-20261020 --graine 20261020 -- 54700 ia3k-variete "$SRC"
run soldats-20261020 --graine 20261020 -- 108100 ia3k-soldats "$SRC"
run pnj-reduit -- 216000 pnj-reduit "$SRC"
run peur-123456789 --graine 123456789 -- 30100 ia3k-peur "$SRC"
run variete-123456789 --graine 123456789 -- 54700 ia3k-variete "$SRC"
run soldats-123456789 --graine 123456789 -- 108100 ia3k-soldats "$SRC"
run route-temoin-20261020 --graine 20261020 -- 54700 ia3k-route-temoin "$SRC"
run variete-temoin-20261020 --graine 20261020 -- 54700 ia3k-variete-temoin "$SRC"
run memoire-temoin-20261020 --graine 20261020 -- 288700 ia3k-memoire-temoin "$SRC"
run captures-route --captures -- 54700 ia3k-route "$SRC"
run captures-peur --captures -- 30100 ia3k-peur "$SRC"
echo "IA3-K REJEU TERMINE"
