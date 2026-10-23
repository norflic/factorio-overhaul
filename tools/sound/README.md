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
Une mesure au-dessus de la vanilla : le gain de l'ère baisse et on recommence (5 passages au plus, sinon échec). Lot
S0 : volume du prototype de la vanilla (0,4) pour toutes les ères ; depuis S0-suite, volume du prototype PAR ÈRE
(0,4 × marge des rafales tirées au hasard, `rafales.py` ci-dessous) : le son en jeu est le fichier × ce volume.
Timbre : le centroïde spectral doit baisser et la part d'énergie sous 200 Hz monter d'une ère à la suivante (vanilla
comprise), sinon échec.

### Rafales tirées au hasard et volume par ère (lot S0-suite, 24/10) : `rafales.py`
La rafale unique de S0 (24 tirs, une suite fixe) ne suffisait pas : la vérification de S0 a trouvé l'ère IV à +0,01 dB
de la vanilla avec une autre rafale. `rafales.py` (SANS Blender : décodage PyAV) joue, pour 5 longueurs (5, 10, 24, 30
et 60 tirs à 10/s, 2,5 s de traîne) et 100 suites de variations tirées au hasard par longueur (plus la suite en boucle
de la vérification), la vanilla et chaque ère, et mesure crête, RMS, RMS max sur 50 ms et 400 ms, sonie K intégrée et
momentanée. Contrat : chaque quantile (médiane, 90e, 99e centile, maximum) de chaque mesure de l'ère est au moins
0,5 dB sous le même quantile de la vanilla (la vanilla et l'ère jouent des suites indépendantes en jeu). La comparaison
« appariée » (même suite pour les deux) est rapportée hors contrat : elle dépend des annulations de phase (la pire suite,
`hasard-68` à 5 tirs, est la rafale vanilla la PLUS FAIBLE des 100 sur 50 ms, 1,4 dB sous la médiane).
```
py -3.9 tools/sound/rafales.py                       # mesure seule (environ 4 min)
py -3.9 tools/sound/rafales.py --appliquer --page "<racine>\fo-logs\<date>_<lot>\ecoute"
```
`--appliquer` écrit le volume du prototype PAR ÈRE dans `sons.lua` (champ `volumes`, lu par `prototypes/levels/gun.lua`)
et la campagne dans `MANIFEST.json` (« rafales_hasard ») ; les fichiers OGG ne changent pas. `--page` refait la page
d'écoute au volume EN JEU (MP3 par PyAV, libmp3lame). `sons.py` garde le champ `volumes` en régénérant `sons.lua` ;
si les fichiers OGG changent, relancer `rafales.py --appliquer`. `sons.py --check` vérifie que les volumes de `sons.lua`
sont ceux du manifeste et que la marge y est tenue.

### Le tir joué en jeu : `tirs_joues.py` (lot S0-suite)
Analyse de la sortie mixée du jeu (`audio-disk.raw`, session `FO_AUDIO=1`, scénario greffé `s0-tir` :
`tools/autotest/README.md` §4.1) : chaque tir écrit au journal est cherché dans la sortie par filtre adapté contre les 20
tirs du mod et les 4 tirs vanilla (PyAV) ; ère, instant (droite tick → temps ajustée) et volume relatif (`--json`, puis
`--avant` pour un contrôle différentiel entre deux sessions) :
```
py -3.9 tools/sound/tirs_joues.py "<racine>\fo-visual\audio-disk.raw" "<racine>\fo-visual\write\script-output\fo-shots\factorio.log"
```

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
  depuis S0-suite, un .ogg est relu en entier : flux Vorbis (Opus, FLAC dans Ogg refusés : « codec »), en-têtes Vorbis
  valides, pages complètes et suivies jusqu'à la fin de flux (fichier coupé : « tronqué ») ; étalonné sur toute la
  vanilla ; mutants : `py -3.9 -B tests/datastage/mut_sons.py --work <dossier jetable>` (6 OK). En moteur réel (F156,
  proposé) : un Ogg Opus passe le chargement puis lève une exception au premier tir qui le joue ; un Ogg coupé ne donne
  aucune erreur, le tir est muet ;
- en moteur réel : `FO_AUDIO=1` puis `fo-captures.bat` (`tools/autotest/README.md` §1.3) : seule la session avec images
  charge les sons.
