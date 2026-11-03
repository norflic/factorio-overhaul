#!/usr/bin/env bash
# Planches d'états clés DA-ATELIERS (zoom 2 jour, zoom 1 jour, zoom 2 nuit) depuis un dossier de rendus post-traités.
#   bash tools/render/pieces/ateliers/planches.sh <src> <dossier de sortie> [variantes, défaut a,b,c]
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$1"; OUT="$2"; VS="${3:-a,b,c}"
py -3.9 "$HERE/planche.py" --src "$SRC" --dest "$OUT/etats-cles.png" --zoom 2 --variantes "$VS"
py -3.9 "$HERE/planche.py" --src "$SRC" --dest "$OUT/etats-cles-z1.png" --zoom 1 --variantes "$VS"
py -3.9 "$HERE/planche.py" --src "$SRC" --dest "$OUT/etats-cles-nuit.png" --zoom 2 --nuit --variantes "$VS"
