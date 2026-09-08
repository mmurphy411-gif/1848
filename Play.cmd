@echo off
setlocal
set "TASK_GODOT=%~dp0.tools\Godot_v4.7.2-stable_win64.exe"
if defined GODOT_BIN set "TASK_GODOT=%GODOT_BIN%"
if exist "%TASK_GODOT%" goto play
where godot.exe >nul 2>&1
if errorlevel 1 goto missing
set "TASK_GODOT=godot.exe"
:play
start "1848" "%TASK_GODOT%" --path "%~dp0." -- %*
exit /b 0
:missing
echo Godot was not found. Open project.godot in Godot 4.7.2 and press F5,
echo or set GODOT_BIN to the full path of your Godot executable.
pause
exit /b 1
