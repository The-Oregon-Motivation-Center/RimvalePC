@echo off
title Rimvale Engine DLL Rebuild
echo ============================================
echo  Rimvale Engine -- FULL Rebuild (Debug)
echo ============================================
echo.

set MSBUILD="C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
set VCXPROJ="C:\Users\Acata\RimvaleGodot\gdextension\build\rimvale_engine.vcxproj"

echo Force-rebuilding rimvale_engine (skipping generate_bindings)...
echo.

%MSBUILD% %VCXPROJ% ^
    /t:Rebuild ^
    /p:Configuration=Debug ^
    /p:Platform=x64 ^
    /p:TrackFileAccess=false ^
    /p:BuildProjectReferences=false ^
    /nologo

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FAILED
    pause
    exit /b 1
)

echo.
echo Writing extension_list.cfg...
>"C:\Users\Acata\RimvaleGodot\.godot\extension_list.cfg" echo res://addons/rimvale_engine/rimvale_engine.gdextension

echo ============================================
echo  Done! Now open Godot normally.
echo ============================================
pause
