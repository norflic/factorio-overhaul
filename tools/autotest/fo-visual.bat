@echo off
rem ============================================================================================
rem  Factorio Overhaul - session VISUELLE de test, entierement automatique (lot P1, H-T1).
rem  Ouvre le jeu AVEC images sur la carte du dernier banc fo-autotest, dans des dossiers SEPARES
rem  (fo-visual\ : config, mods, ecriture ; tes sauvegardes, ta config et ton dossier mods\ ne sont
rem  pas touches). Le mod de test prend toutes ses captures ; le pilote (visual_session.py) ferme
rem  ensuite UNIQUEMENT ce processus de test, verifie qu'il n'en reste aucun, puis ecrit l'index et la
rem  planche-contact dans fo-visual\write\script-output\fo-shots\.
rem  Prerequis : un banc fo-autotest.bat (carte + mods de test), python et Pillow.
rem  Usage : fo-visual.bat [nopause] [fenetre] [delai_s]
rem          fenetre : min (defaut : reduite, sans prendre le focus) / small / normal
rem  Codes : 0 succes ; 1 preparation ; 2 verrou pris (rien n'a tourne) ; 3 delai depasse ;
rem          4 captures manquantes ou illisibles ; 5 processus de test encore present ;
rem          6 vitrine : entite refusee ; 7 erreur du jeu ou session fermee avant la fin.
rem ============================================================================================
setlocal
cd /d "%~dp0"
set ROOT=%cd%
set TEST=%ROOT%\fo-autotest
set WIN=min
set TMO=900
if not "%~2"=="" set WIN=%~2
if not "%~3"=="" set TMO=%~3
rem Le pilote vient de la copie du mod faite par le dernier banc : meme version que le mod de test.
set DRIVER=%TEST%\mods\factorio-overhaul\tools\autotest\visual_session.py
set RC=0

if not exist "%TEST%\fo-autotest-map.zip" (
  echo Pas de carte de test : lancer fo-autotest.bat d'abord.
  set RC=1
  goto :out
)
if not exist "%DRIVER%" (
  echo Pilote absent de la source testee : %DRIVER%
  echo La source du mod du dernier banc est anterieure au lot P1.
  set RC=1
  goto :out
)
where python >nul 2>nul || (
  echo python introuvable dans le PATH.
  set RC=1
  goto :out
)

if defined FO_LOCK_HELD goto :locked
mkdir "%ROOT%\fo-autotest.lock" 2>nul || (
  echo Un banc est deja en cours : verrou fo-autotest.lock pris.
  set RC=2
  goto :out
)
set OWN_LOCK=1
:locked

rem FO_VISUAL_ARGS : options de plus pour le pilote (essais : --mode benchmark --ticks N, --priority normal).
python -B "%DRIVER%" --root "%ROOT%" --window %WIN% --timeout %TMO% %FO_VISUAL_ARGS%
set RC=%errorlevel%
if defined OWN_LOCK rmdir "%ROOT%\fo-autotest.lock" 2>nul

:out
if /i not "%~1"=="nopause" pause
exit /b %RC%
