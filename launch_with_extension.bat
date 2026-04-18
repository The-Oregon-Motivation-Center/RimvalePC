@echo off
title Rimvale - Launch with Extension

rem Write extension_list.cfg
if not exist "%~dp0.godot" mkdir "%~dp0.godot"
>"C:\Users\Acata\RimvaleGodot\.godot\extension_list.cfg" echo res://addons/rimvale_engine/rimvale_engine.gdextension

echo Written extension_list.cfg:
type "C:\Users\Acata\RimvaleGodot\.godot\extension_list.cfg"
echo.

if exist "C:\Users\Acata\RimvaleGodot\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll" (
    echo [OK] DLL exists on disk.
) else (
    echo [MISSING] DLL NOT FOUND
)
echo.

echo Launching Godot - watch this window for any DLL or GDExtension errors...
echo.

set GODOT=C:\Users\Acata\Documents\Lumen movies\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe
"%GODOT%" --path "C:\Users\Acata\RimvaleGodot" --editor 2>&1

echo.
echo Godot exited.
pause
