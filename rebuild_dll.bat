@echo off
title Rimvale Engine DLL Rebuild
echo ============================================
echo  Rimvale Engine -- FULL Rebuild (Debug)
echo ============================================
echo.
setlocal

set PROJECT=%~dp0
set PROJECT=%PROJECT:~0,-1%
set VCXPROJ=%PROJECT%\gdextension\build\rimvale_engine.vcxproj

rem Find MSBuild via vswhere
set MSBUILD=
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath 2^>nul') do (
    if exist "%%i\MSBuild\Current\Bin\MSBuild.exe" set MSBUILD="%%i\MSBuild\Current\Bin\MSBuild.exe"
)
if not defined MSBUILD (
    echo [ERROR] MSBuild not found. Install Visual Studio Build Tools.
    pause
    exit /b 1
)

echo Using MSBuild: %MSBUILD%
echo Force-rebuilding rimvale_engine (skipping generate_bindings)...
echo.

%MSBUILD% "%VCXPROJ%" ^
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
if not exist "%PROJECT%\.godot" mkdir "%PROJECT%\.godot"
>"%PROJECT%\.godot\extension_list.cfg" echo res://addons/rimvale_engine/rimvale_engine.gdextension

echo ============================================
echo  Done! Now open Godot normally.
echo ============================================
pause
