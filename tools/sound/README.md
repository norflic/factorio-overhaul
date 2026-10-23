# Sons du mod : `tools/sound/` (lot S0)

## Ce que fait la chaîne
`sons.py` fabrique le tir de la mitrailleuse par ÈRE à partir des sons vanilla (`<racine>\data\base\sound\`, lecture
seule), écrit les fichiers du mod dans `sound/levels/gun/` et, sur demande, une page d'écoute pour le Directeur
Créatif.

```
py -3.9 tools/sound/sons.py --page "<racine>\fo-logs\<date>_<lot>\ecoute"   # fabrique, mesure, écrit le mod et la page
py -3.9 tools/sound/sons.py --check                                       # contrôle seul (manifeste, sha256, pages Ogg)
```
Environ 1 min (4 appels de Blender de quelques secondes). `PYTHONUTF8=1` conseillé. Dossier de travail par défaut :
`<racine>\fo-logs\2026-10-24_S0\travail\` (`--work` pour un autre).

## Codecs : Blender, par le verrou de rendu
Aucun outil audio n'est installé sur le PC (ni ffmpeg, ni sox, ni oggenc ; pas de `soundfile` pour Python). Le module
`aud` de Blender 5.2.2 (Audaspace, avec le FFmpeg qu'il embarque) lit l'OGG et le MP3 et écrit WAV, OGG Vorbis et MP3.
`blender_audio.py` ne fait que ces conversions (travaux décrits en JSON) ; `sons.py` le lance TOUJOURS par
`tools/render/with_render_lock.py` (CLAUDE.md §4, interdit 6), en priorité basse. Aucun son n'est joué.

Le moteur 1.1.91 lit `.ogg`, `.wav` et `.voc` (doc `prototype-api.json`, `Sound.filename`). Le mod livre de l'OGG
Vorbis (débit demandé à l'encodeur : 112 kb/s), comme la vanilla : 21 à 28 Ko par tir (vanilla : 27 à 36 Ko), 478 Ko
pour les 20.

## Le traitement (numpy, scipy ; `py -3.9`)
Pour chaque ère (âges 1-3, 4-6, 7-9, 10-12, 13-15) et chacune des 4 variations du tir vanilla
(`gun-turret-gunshot-01` à `04`) : hauteur (rééchantillonnage polyphasé), grain (saturation `tanh`), filtres, couches
d'autres sons vanilla (détonation lourde, canon de char, laser, explosion nucléaire très ralentie), coup sourd
synthétique saturé (ses harmoniques s'entendent sur un téléphone), balayage descendant et souffle aspiré (ère V),
résonance en peigne (ère III), modulation en anneau (ère V). Durée bornée à celle de la variation vanilla. Paramètres :
table `ERES` en tête de `sons.py`.

## Le volume : jamais au-dessus de la vanilla
Mesuré sur l'OGG livré, DÉCODÉ (ce que le jeu joue), contre la variation vanilla de même rang :
- crête (dBFS) ;
- RMS : énergie rapportée à la durée de la variation vanilla (un son plus long ne gagne rien) ;
- sonie pondérée K (filtre de la norme BS.1770, recalculé pour 44,1 kHz ; sans porte, même fenêtre) ;
- sonie momentanée maximale (fenêtres de 400 ms) ;
- et une rafale de 10 tirs/s pendant 2,4 s (cadence de la mitrailleuse vanilla), même suite de variations.
Une mesure au-dessus de la vanilla : le gain de l'ère baisse et on recommence (5 passages au plus, sinon échec). Le
volume du prototype reste celui de la vanilla (0,4) : le rapport des fichiers est le rapport en jeu.
Timbre : le centroïde spectral doit baisser et la part d'énergie sous 200 Hz monter d'une ère à la suivante (vanilla
comprise), sinon échec.

## Reproductibilité
WAV et audio décodé identiques d'un passage à l'autre. libogg tire au hasard le numéro de série du flux : `sons.py` le
fixe (dérivé du nom du fichier) et recalcule la somme CRC de chaque page, puis vérifie, par Blender, que chaque
fichier du mod se décode à l'échantillon près comme le fichier mesuré. Deux passages donnent les mêmes octets (sha256).

## Fichiers du mod
- `sound/levels/gun/tir-ere<N>-<i>.ogg` : 5 ères × 4 variations ;
- `sound/levels/gun/sons.lua` : GÉNÉRÉ, lu par `prototypes/levels/gun.lua` (champ `attack_parameters.sound`) ;
- `sound/levels/gun/MANIFEST.json` : sha256, octets, mesures, écarts à la vanilla, timbre.
Ces fichiers sont petits : ils sont COMMITÉS (contrairement aux PNG de la mitrailleuse, décision D-6).

## Contrôles
- harness (`tests/datastage/sounds.lua`) : tout son cité existe, est en .ogg/.wav/.voc et commence par le bon en-tête ;
  étalonné sur toute la vanilla ;
- en moteur réel : `FO_AUDIO=1` puis `fo-captures.bat` (`tools/autotest/README.md` §1.3) : seule la session avec images
  charge les sons.
