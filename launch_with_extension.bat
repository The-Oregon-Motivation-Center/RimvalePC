@echo off
title Rimvale - Launch with Extension
setlocal

set PROJECT=%~dp0
set PROJECT=%PROJECT:~0,-1%

rem Load user's Godot path from local_config.bat
if exist "%PROJECT%\local_config.bat" (
    call "%PROJECT%\local_config.bat"
) else (
    echo [ERROR] local_config.bat not found!
    echo Copy local_config.bat.example to local_config.bat and set your Godot path.
    pause
    exit /b 1
)

if not exist "%GODOT%" (
    echo [ERROR] Godot not found at: %GODOT%
    echo Edit local_config.bat to set the correct path.
    pause
    exit /b 1
)

rem Write extension_list.cfg
if not exist "%PROJECT%\.godot" mkdir "%PROJECT%\.godot"
>"%PROJECT%\.godot\extension_list.cfg" echo res://addons/rimvale_engine/rimvale_engine.gdextension

echo Written extension_list.cfg:
type "%PROJECT%\.godot\extension_list.cfg"
echo.

if exist "%PROJECT%\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll" (
    echo [OK] DLL exists on disk.
) else (
    echo [MISSING] DLL NOT FOUND
)
echo.

echo Launching Godot - watch this window for any DLL or GDExtension errors...
echo.

"%GODOT%" --path "%PROJECT%" --editor 2>&1

echo.
echo Godot exited.
pause
