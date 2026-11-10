@echo off
setlocal
if exist "%~dp0RifleArena.exe" (
    start "" "%~dp0RifleArena.exe"
    exit /b 0
)
if exist "%~dp0build\RifleArena.exe" (
    start "" "%~dp0build\RifleArena.exe"
    exit /b 0
)
echo Ouvrez RifleArena.exe dans le ZIP Windows disponible dans GitHub Releases.
echo Pour developper, ouvrez project.godot dans Godot 4.6.3.
pause
exit /b 1
