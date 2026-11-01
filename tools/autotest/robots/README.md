# Lot RB-0 : essais moteur des robots (31/10)

Plan : `fo-logs/2026-10-31_ROBOTS/PLAN.md` §3 (E1 à E8) et E9 (araignée « ultra énorme »). Rapport : `fo-logs/2026-10-31_ROBOTS/RB0/RAPPORT.md`.
Aucun code du mod livré ne change : tout passe par une COPIE JETABLE.

```
py -3.9 -B tools/autotest/robots/jetable.py --dest <dossier neuf hors du dépôt>            # copie + prototypes de test
py -3.9 -B tools/autotest/robots/jetable.py --dest <copie existante> --maj                 # rafraîchit scénarios et prototypes
py -3.9 -B tools/autotest/robots/jetable.py --dest <neuf> --remplissage 30                 # E8 : feuilles de remplissage (Mpx)
py -3.9 -B tools/autotest/banc.py --out <archive> --qui RB0 -- <ticks> <scénario> <copie>  # toujours par la file
```

Le mod de test (scénarios) est recopié DEPUIS la copie (`fo-autotest.bat` prend `<source>\tools\autotest\fo-autotest`) :
après toute modification d'un scénario, relancer `--maj`. Un scénario a besoin de 100 ticks de plus que son `check_tick`.

| Essai | Scénario | Ticks | Prototypes de test (`rb0_jetable_data.lua`) |
|---|---|---|---|
| E1 kit de sortie, pile de 1 | `rb0-sortie` | 1 700 | `rb0-atelier`, `rb0-kit`, `rb0-kit-b`, recettes |
| E2 grosses boîtes | `rb0-boite` | 2 500 | `rb0-u-04` à `rb0-u-24` |
| E3 araignée sans conducteur | `rb0-geant` | 2 550 | `rb0-spider-1` |
| E4 biters contre unité et araignée | `rb0-cible` | 1 500 | idem + `rb0-spider-1-nomt`, `-3`, `-5` |
| E5 masque réduit, eau | `rb0-flotte` | 1 500 | `rb0-u-flot` |
| E6 outil de sélection | `rb0-selection` | 600 | `rb0-selection` |
| E7 `set_recipe` | `rb0-file` | 1 000 | recettes `rb0-kit-*` |
| E8 atlas au plancher | `rb0-atlas` | 700, `--captures` | `rb0-fill-<k>` (copie avec `--remplissage`) |
| E9 araignées énormes | `rb0-colosse` | 2 550 | `rb0-spider-2` à `-8`, canons `rb0-gun-45/60/100` |
| E9 coût par tick | `rb0-cout-vide`, `-u60`, `-s1`, `-s5`, `-s5t` | 3 000, `--seul` | idem |

## E6 : ce que le banc ne peut pas faire

Aucun événement de sélection (`on_player_selected_area` et ses trois variantes) ne se produit sans un joueur qui glisse la
souris : le banc charge l'outil, pose des unités et des araignées, et branche les gestionnaires qui écrivent
`[FO-RB0-SELECTION] EVENT …` au journal. Protocole pour le Directeur Créatif (5 minutes, une partie jetable) :

1. Monter la copie jetable comme mod `factorio-overhaul` et `fo-autotest` dans un dossier de mods de TEST (jamais
   `mods\` du jeu du DC).
2. Nouvelle carte, `/c game.player.cursor_stack.set_stack{name="rb0-selection"}` après avoir posé quelques unités
   (`/c game.surfaces[1].create_entity{name="rb0-u-04",position=game.player.position,force="player"}`).
3. Noter dans le journal : glisser, Maj + glisser, bouton droit + glisser, Maj + bouton droit ; clic sans glisser ; la
   même chose en vue carte. Le journal dit la zone et la liste d'entités reçues.
