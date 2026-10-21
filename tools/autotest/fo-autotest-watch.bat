@echo off
rem ============================================================================================
rem  Factorio Overhaul - surveillance des demandes de test de Claude.
rem  Lance une fois, laisse la fenetre ouverte (reduite) : chaque fois que Claude depose
rem  fo-autotest-request.txt a cote de ce fichier, le test en moteur reel est relance tout seul,
rem  sans prise de controle de ton PC. Le test n'utilise ni ton dossier mods\ ni tes sauvegardes.
rem  Ferme la fenetre pour arreter la surveillance.
rem ============================================================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0"
set ROOT=%cd%
title Factorio Overhaul - surveillance des tests (fermer pour arreter)
echo Surveillance active. Ferme cette fenetre pour arreter.
:loop
if exist "%ROOT%\fo-autotest-request.txt" (
  set TICKS=
  set /p TICKS=<"%ROOT%\fo-autotest-request.txt"
  del /q "%ROOT%\fo-autotest-request.txt"
  echo.
  echo === Demande de test recue %date% %time% ===
  call "%ROOT%\fo-autotest.bat" nopause !TICKS!
)
timeout /t 5 /nobreak >nul
goto loop
