@echo off
setlocal
pushd "%~dp0"
set "RIFT_ENGINE=%~1"
if defined RIFT_ENGINE if not exist "%RIFT_ENGINE%" set "RIFT_ENGINE="
if not defined RIFT_ENGINE if exist "%CD%\godot.exe" set "RIFT_ENGINE=%CD%\godot.exe"
if not defined RIFT_ENGINE for %%G in ("%CD%\Godot_v*_win64.exe") do if exist "%%~fG" set "RIFT_ENGINE=%%~fG"
if not defined RIFT_ENGINE for /f "delims=" %%G in ('where godot.exe 2^>nul') do if not defined RIFT_ENGINE set "RIFT_ENGINE=%%G"
if not defined RIFT_ENGINE goto no_engine
if not exist "%CD%\build\NeonRiftArenaV3.pck" goto no_pack
start "" "%RIFT_ENGINE%" --main-pack "%CD%\build\NeonRiftArenaV3.pck"
popd
exit /b 0

:no_engine
echo Utilisez Godot 4.6.3 Standard x64.
echo Glissez son fichier .exe sur ce .bat, ou placez-le dans le meme dossier.
echo Pour ouvrir le projet dans Godot, importez project.godot puis appuyez sur F5.
pause
popd
exit /b 1

:no_pack
echo Paquet portable introuvable. Decompressez toute l'archive dans un dossier.
echo Le projet reste accessible via project.godot dans Godot.
pause
popd
exit /b 1
