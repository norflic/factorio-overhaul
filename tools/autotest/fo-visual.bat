@echo off
rem ============================================================================================
rem  Factorio Overhaul - test VISUEL : ouvre le jeu (avec images) sur la derniere carte de test.
rem  Dossier separe fo-visual\ : tes sauvegardes, ta config et ton dossier mods\ ne sont pas touches.
rem  Prerequis : avoir lance fo-autotest.bat au moins une fois (il fabrique la carte et les mods de test).
rem ============================================================================================
setlocal
cd /d "%~dp0"
set ROOT=%cd%
set TEST=%ROOT%\fo-autotest
set VIS=%ROOT%\fo-visual
if not exist "%TEST%\fo-autotest-map.zip" (
  echo Pas de carte de test : lancer fo-autotest.bat d'abord.
  pause
  exit /b 1
)
if exist "%VIS%\mods" rmdir /s /q "%VIS%\mods"
if not exist "%VIS%\write" mkdir "%VIS%\write"
xcopy /e /i /q /y "%TEST%\mods" "%VIS%\mods" >nul
copy /y "%TEST%\fo-autotest-map.zip" "%VIS%\fo-visual-map.zip" >nul
set WRITE_FWD=%VIS:\=/%/write
> "%VIS%\config.ini" echo [path]
>> "%VIS%\config.ini" echo read-data=__PATH__executable__/../../data
>> "%VIS%\config.ini" echo write-data=%WRITE_FWD%
>> "%VIS%\config.ini" echo [general]
>> "%VIS%\config.ini" echo locale=fr
>> "%VIS%\config.ini" echo [graphics]
>> "%VIS%\config.ini" echo full-screen=false
start "" "%ROOT%\bin\x64\factorio.exe" --config "%VIS%\config.ini" --mod-directory "%VIS%\mods" --load-game "%VIS%\fo-visual-map.zip"
