@echo off
rem ============================================================================================
rem  Factorio Overhaul - UNE commande pour une galerie complete, sans intervention humaine (lot P1) :
rem  1. banc fo-autotest.bat (carte + controles, sans affichage) ;
rem  2. session visuelle fo-visual.bat (captures, fermeture de la session, index, planche-contact).
rem  Le verrou fo-autotest.lock est tenu pendant toute la chaine.
rem  Usage : fo-captures.bat [scenario] [source du mod] [fenetre]
rem    scenario : content (defaut : 4000 ticks, controles + galerie) / vitrine (fo-vitrine.lua)
rem               / un scenario greffe (scenarios\<nom>.lua) / default, waves, pteam... (600 ticks)
rem    source   : chemin absolu du mod a tester ; "" ou absent : 3e champ de fo-autotest-params.txt,
rem               sinon mods\factorio-overhaul
rem    fenetre  : min (defaut) / small / normal
rem  Variables FO_CREATE_SRC et FO_MAP_SEED (graine de la carte) : transmises telles quelles a fo-autotest.bat,
rem    qui les lit (graine refusee : code 8, aucune session visuelle).
rem  Captures : fo-visual\write\script-output\fo-shots\ (index.txt, planche-NN.png, session.txt).
rem  Codes : ceux de fo-visual.bat (0 succes, 2 verrou pris, 3 delai, 4 captures, 5 processus,
rem          6 vitrine, 7 erreur du jeu) ; 8 = le banc fo-autotest a echoue (pas de carte).
rem ============================================================================================
setlocal
cd /d "%~dp0"
set ROOT=%cd%
set SCEN=content
if not "%~1"=="" set SCEN=%~1
set SRC=%~2
set WIN=min
if not "%~3"=="" set WIN=%~3
set TICKS=600
if /i "%SCEN%"=="content" set TICKS=4000

mkdir "%ROOT%\fo-autotest.lock" 2>nul || (
  echo Un banc est deja en cours : verrou fo-autotest.lock pris. Rien n'a tourne.
  exit /b 2
)
set FO_LOCK_HELD=1
echo === fo-captures : scenario %SCEN%, %TICKS% ticks, fenetre %WIN% ===
call "%ROOT%\fo-autotest.bat" nopause %TICKS% %SCEN% "%SRC%"
set RC=%errorlevel%
if not "%RC%"=="0" (
  echo Banc fo-autotest en echec, code %RC%.
  set RC=8
  goto :unlock
)
findstr /c:"BILAN" "%ROOT%\fo-autotest\create.log" "%ROOT%\fo-autotest\benchmark.log" 2>nul
call "%ROOT%\fo-visual.bat" nopause %WIN%
set RC=%errorlevel%

:unlock
rmdir "%ROOT%\fo-autotest.lock" 2>nul
echo === fo-captures : code de sortie %RC% ===
exit /b %RC%
