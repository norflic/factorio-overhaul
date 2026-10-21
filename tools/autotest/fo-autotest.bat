@echo off
rem ============================================================================================
rem  Factorio Overhaul - test automatise en moteur reel (aucune interaction necessaire).
rem  1. Copie le mod dans un dossier de mods SEPARE (ton dossier mods\ n'est pas touche).
rem  2. Utilise un dossier d'ecriture SEPARE (fo-autotest\write) : ta partie, tes sauvegardes et ton
rem     journal ne sont pas touches, et le test peut tourner pendant que tu joues.
rem  3. Cree une carte (etape data + generation des biomes + on_init : guerre et compagnons).
rem  4. Joue N ticks en mode benchmark (sans affichage) et mesure le temps par tick, poste par poste.
rem  Resultats : fo-autotest\create.log, benchmark.log, benchmark-stdout.txt, done.txt
rem  Usage : fo-autotest.bat [nopause] [ticks] [scenario] [source du mod]
rem          (defaut : fo-autotest-params.txt, sinon 36000 ticks = 10 minutes de jeu, scenario default)
rem  Vitrine : <racine>\fo-vitrine.lua (ou le fichier nomme par la variable FO_VITRINE) est recopie
rem          dans le mod de test (vitrine_params.lua). Format : tools\autotest\README.md.
rem  Codes : 0 termine (lire le BILAN), 1 erreur (pas de carte creee...), 2 verrou pris (rien n'a
rem          tourne : fo-autotest\ contient encore les resultats du test PRECEDENT).
rem ============================================================================================
setlocal
cd /d "%~dp0"
set ROOT=%cd%
set TEST=%ROOT%\fo-autotest
set MODS=%TEST%\mods
set WRITE=%TEST%\write
set EXE=%ROOT%\bin\x64\factorio.exe
set TICKS=36000
set SCENARIO=default
set MODSRC=%ROOT%\mods\factorio-overhaul
set RC=0
rem Parametres deposes par Claude (une ligne : "<ticks> <scenario> [source du mod]"), lus a chaque
rem lancement. La source optionnelle (chemin absolu, espaces permis) sert a tester un worktree git.
if exist "%ROOT%\fo-autotest-params.txt" for /f "usebackq tokens=1,2,*" %%a in ("%ROOT%\fo-autotest-params.txt") do (
  set TICKS=%%a
  if not "%%b"=="" set SCENARIO=%%b
  if not "%%c"=="" set MODSRC=%%c
)
rem Les arguments l'emportent sur le fichier de parametres.
if not "%~2"=="" set TICKS=%~2
if not "%~3"=="" set SCENARIO=%~3
if not "%~4"=="" set MODSRC=%~4
set VITRINE=%ROOT%\fo-vitrine.lua
if defined FO_VITRINE set VITRINE=%FO_VITRINE%

if not exist "%EXE%" (
  echo factorio.exe introuvable : placer ce fichier a la racine de Factorio.v1.1.91
  if /i not "%~1"=="nopause" pause
  exit /b 1
)

rem Verrou : un seul banc moteur a la fois (fo-autotest, fo-visual, fo-captures partagent ce verrou).
rem FO_LOCK_HELD : l'appelant (fo-captures.bat) tient deja le verrou pour toute la chaine.
if defined FO_LOCK_HELD goto :locked
mkdir "%ROOT%\fo-autotest.lock" 2>nul || (
  echo Un test est deja en cours.
  exit /b 2
)
set OWN_LOCK=1
:locked

if not exist "%MODSRC%\info.json" (
  echo Source du mod introuvable : %MODSRC%
  set RC=1
  goto :end
)

echo [1/4] Preparation du dossier de test (source : %MODSRC%, scenario %SCENARIO%, %TICKS% ticks)...
if exist "%TEST%" rmdir /s /q "%TEST%"
mkdir "%MODS%"
mkdir "%WRITE%"
rem Ni le depot git ni les worktrees des agents (.claude\worktrees) ni les rendus du pipeline graphique.
robocopy "%MODSRC%" "%MODS%\factorio-overhaul" /E /XD .git .claude "%MODSRC%\tools\render" __pycache__ /NFL /NDL /NJH /NJS /NP >nul
robocopy "%MODSRC%\tools\autotest\fo-autotest" "%MODS%\fo-autotest" /E /XD __pycache__ /NFL /NDL /NJH /NJS /NP >nul
> "%TEST%\source.txt" echo %MODSRC%
> "%MODS%\fo-autotest\scenario.lua" echo return "%SCENARIO%"
if exist "%VITRINE%" (
  copy /y "%VITRINE%" "%MODS%\fo-autotest\vitrine_params.lua" >nul
  > "%TEST%\vitrine-source.txt" echo %VITRINE%
)
> "%MODS%\mod-list.json" echo {"mods":[{"name":"base","enabled":true},{"name":"factorio-overhaul","enabled":true},{"name":"fo-autotest","enabled":true}]}
set WRITE_FWD=%WRITE:\=/%
> "%TEST%\config.ini" echo [path]
>> "%TEST%\config.ini" echo read-data=__PATH__executable__/../../data
>> "%TEST%\config.ini" echo write-data=%WRITE_FWD%

echo [2/4] Creation de la carte (graine 20261020)...
"%EXE%" --config "%TEST%\config.ini" --mod-directory "%MODS%" --create "%TEST%\fo-autotest-map.zip" --map-gen-seed 20261020 --disable-audio > "%TEST%\create-stdout.txt" 2>&1
copy /y "%WRITE%\factorio-current.log" "%TEST%\create.log" >nul
if not exist "%TEST%\fo-autotest-map.zip" (
  echo Carte NON creee : lire fo-autotest\create.log
  set RC=1
  goto :end
)

rem Processeur hybride (12e gen. Intel : 12 fils P puis 4 coeurs E) : un benchmark en arriere-plan est
rem deplace par Windows sur les coeurs E (x3 plus lent, pauses jusqu'a 170 ms, mesure par l'etalon
rem [FO-CALIB]). On le garde sur les coeurs P, priorite au-dessus de la normale.
set RUNOPT=/ABOVENORMAL
if "%NUMBER_OF_PROCESSORS%"=="16" set RUNOPT=/ABOVENORMAL /AFFINITY FFF
echo [3/4] Benchmark : %TICKS% ticks, scenario %SCENARIO%...
start "" /B /WAIT %RUNOPT% "%EXE%" --config "%TEST%\config.ini" --mod-directory "%MODS%" --benchmark "%TEST%\fo-autotest-map.zip" --benchmark-ticks %TICKS% --benchmark-runs 1 --benchmark-verbose all --disable-audio > "%TEST%\benchmark-stdout.txt" 2>&1
copy /y "%WRITE%\factorio-current.log" "%TEST%\benchmark.log" >nul

> "%TEST%\done.txt" echo termine %date% %time%
echo [4/4] Termine. Resultats dans %TEST%

:end
if defined OWN_LOCK rmdir "%ROOT%\fo-autotest.lock" 2>nul
if /i not "%~1"=="nopause" (
  echo Tu peux fermer cette fenetre et prevenir Claude.
  pause
)
exit /b %RC%
