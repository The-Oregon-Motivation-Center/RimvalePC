@echo off
title Rimvale - Update godot-cpp to 4.6.1-stable + Rebuild
setlocal

set GODOT=C:\Users\Acata\Documents\Lumen movies\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe
set PROJECT=C:\Users\Acata\RimvaleGodot
set GDEXT=%PROJECT%\gdextension
set GODOTCPP=%GDEXT%\godot-cpp
set BUILD=%GDEXT%\build_fresh
set API_FILE=%GDEXT%\extension_api_461_dumped.json
set CMAKE="C:\Program Files\CMake\bin\cmake.exe"

echo ============================================================
echo  Step 1: Update godot-cpp submodule to godot-4.6.1-stable
echo ============================================================
cd /d "%GODOTCPP%"
git fetch --tags 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] git fetch failed - trying without network...
)
git checkout godot-4.6.1-stable 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [WARN] Tag godot-4.6.1-stable not found, trying godot-4.6-stable...
    git checkout godot-4.6-stable 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo [WARN] Could not checkout any 4.6 tag, using current HEAD
        git log --oneline -3 2>&1
    )
)
echo.
echo Current godot-cpp commit:
git log --oneline -1 2>&1
echo.

echo ============================================================
echo  Step 2: Dump Godot 4.6.1 API (both files)
echo ============================================================
cd /d "%PROJECT%"
"%GODOT%" --headless --dump-extension-api 2>&1
if exist "%PROJECT%\extension_api.json" (
    move /y "%PROJECT%\extension_api.json" "%API_FILE%" >nul
    echo [OK] extension_api.json dumped
) else (
    echo [WARN] Using existing API file
)
echo.

echo ============================================================
echo  Step 3: Wipe old build_fresh and reconfigure
echo ============================================================
if exist "%BUILD%" (
    takeown /f "%BUILD%" /r /d y >nul 2>&1
    icacls "%BUILD%" /grant "%USERNAME%":F /t /q >nul 2>&1
    rmdir /s /q "%BUILD%" 2>nul
    timeout /t 2 >nul
)
mkdir "%BUILD%"

cd /d "%BUILD%"
%CMAKE% -G "Visual Studio 18 2026" -A x64 ^
    -DGODOTCPP_TARGET=template_debug ^
    -DGODOTCPP_DEBUG_CRT=OFF ^
    -DGODOTCPP_USE_STATIC_CPP=ON ^
    -DGODOTCPP_CUSTOM_API_FILE="%API_FILE%" ^
    -S "%GDEXT%" ^
    -B "%BUILD%"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] CMake configure failed
    pause
    exit /b 1
)
echo.

echo ============================================================
echo  Step 4: Build (several minutes)
echo ============================================================
%CMAKE% --build "%BUILD%" --config Debug --parallel 4

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed
    pause
    exit /b 1
)
echo.

echo ============================================================
echo  Step 5: Write extension_list.cfg and verify
echo ============================================================
>"C:\Users\Acata\RimvaleGodot\.godot\extension_list.cfg" echo res://addons/rimvale_engine/rimvale_engine.gdextension

if exist "%PROJECT%\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll" (
    echo [OK] DLL present
) else (
    echo [ERROR] DLL missing - check build output
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  DONE. Launch Godot now - extension should load.
echo ============================================================
pause
