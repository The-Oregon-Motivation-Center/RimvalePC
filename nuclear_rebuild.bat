@echo off
title Rimvale - NUCLEAR REBUILD (godot-cpp + rimvale_engine)
setlocal

set PROJECT=%~dp0
set PROJECT=%PROJECT:~0,-1%
set GDEXT=%PROJECT%\gdextension
set BUILD_NEW=%GDEXT%\build_fresh
set API_FILE=%GDEXT%\extension_api_461_dumped.json

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

echo ============================================================
echo  NUCLEAR REBUILD: godot-cpp + rimvale_engine (Godot 4.6.1)
echo ============================================================
echo.

echo [Step 1] Dumping Godot 4.6.1 extension API...
cd /d "%PROJECT%"
"%GODOT%" --headless --dump-extension-api 2>&1
if exist "%PROJECT%\extension_api.json" (
    move /y "%PROJECT%\extension_api.json" "%API_FILE%" >nul
    echo [OK] API dumped to: %API_FILE%
) else (
    echo [WARN] Dump failed - checking for existing API file...
    if not exist "%API_FILE%" (
        echo [ERROR] No API file found. Cannot continue.
        pause
        exit /b 1
    )
    echo [OK] Using existing API file: %API_FILE%
)
echo.

echo [Step 2] Removing old build_fresh directory (if it exists)...
if exist "%BUILD_NEW%" (
    takeown /f "%BUILD_NEW%" /r /d y >nul 2>&1
    icacls "%BUILD_NEW%" /grant "%USERNAME%":F /t /q >nul 2>&1
    rmdir /s /q "%BUILD_NEW%" 2>nul
    timeout /t 2 >nul
)
mkdir "%BUILD_NEW%"
echo [OK] Fresh build directory: %BUILD_NEW%
echo.

echo [Step 3] CMake configure with Godot 4.6.1 API...
cd /d "%BUILD_NEW%"
cmake -G "Visual Studio 18 2026" -A x64 ^
    -DGODOTCPP_TARGET=template_debug ^
    -DGODOTCPP_DEBUG_CRT=OFF ^
    -DGODOTCPP_CUSTOM_API_FILE="%API_FILE%" ^
    -S "%GDEXT%" ^
    -B "%BUILD_NEW%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] CMake configure FAILED. See errors above.
    pause
    exit /b 1
)
echo.

echo [Step 4] Building (this will take a few minutes - be patient)...
cmake --build "%BUILD_NEW%" --config Debug --parallel 4

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] BUILD FAILED. See errors above.
    pause
    exit /b 1
)
echo.

echo [Step 5] Writing extension_list.cfg...
if not exist "%PROJECT%\.godot" mkdir "%PROJECT%\.godot"
>"%PROJECT%\.godot\extension_list.cfg" echo res://addons/rimvale_engine/rimvale_engine.gdextension

echo [Step 6] Verifying DLL exists...
if exist "%PROJECT%\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll" (
    echo [OK] DLL is present!
) else (
    echo [WARN] DLL not found at expected location - check build output above.
)

echo.
echo ============================================================
echo  DONE! Fresh godot-cpp + DLL built against Godot 4.6.1 API.
echo  Now launch Godot - the extension WILL load this time.
echo ============================================================
pause
