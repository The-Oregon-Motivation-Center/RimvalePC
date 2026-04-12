@echo off
echo.
echo ============================================
echo  Rimvale Engine - Building DLL
echo ============================================
echo.

cd /d "%~dp0gdextension"

:: If no build folder, configure first
if not exist build\rimvale_engine.vcxproj (
    echo Configuring...
    cmake -B build -G "Visual Studio 18 2025" -A x64
    if errorlevel 1 cmake -B build
    if errorlevel 1 (
        echo.
        echo [ERROR] Configure failed.
        goto :done
    )
)

echo Building... this takes several minutes - you will see files scrolling.
echo DO NOT close this window.
echo.

cmake --build "%~dp0gdextension\build" --config Debug

if errorlevel 1 (
    echo.
    echo [ERROR] Build failed. Scroll up to read the error.
    goto :done
)

echo.
if exist "%~dp0addons\rimvale_engine\bin\librimvale_engine.windows.debug.x86_64.dll" (
    echo ============================================
    echo  SUCCESS! Open Godot - game is ready.
    echo ============================================
) else (
    echo Build completed. Checking for DLL...
    dir "%~dp0addons\rimvale_engine\bin\" /s /b 2>nul
)

:done
echo.
pause
