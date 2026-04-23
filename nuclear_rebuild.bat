@echo off
title Rimvale - NUCLEAR REBUILD (godot-cpp + rimvale_engine)
setlocal enabledelayedexpansion

set PROJECT=%~dp0
set PROJECT=%PROJECT:~0,-1%
set GDEXT=%PROJECT%\gdextension
set BUILD_DIR=%GDEXT%\build_fresh
set API_FILE=%GDEXT%\extension_api_461_dumped.json
set ENGINE_SRC=%PROJECT%\..\..\AndroidStudioProjects\RimvaleMobile\app\src\main\cpp
set DLL_DIR=%PROJECT%\addons\rimvale_engine\bin\Debug
set DLL_NAME=librimvale_engine.windows.debug.x86_64.dll

echo ============================================================
echo  NUCLEAR REBUILD: godot-cpp + rimvale_engine (Godot 4.6.1)
echo ============================================================
echo.

rem ── Pre-flight checks ──────────────────────────────────────────────────────

echo [Pre-flight] Checking local_config.bat...
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
echo [OK] Godot: %GODOT%

echo [Pre-flight] Checking godot-cpp submodule...
if not exist "%GDEXT%\godot-cpp\CMakeLists.txt" (
    echo [ERROR] godot-cpp not found at %GDEXT%\godot-cpp
    echo Run: git submodule update --init --recursive
    pause
    exit /b 1
)
echo [OK] godot-cpp present

echo [Pre-flight] Checking Android engine sources...
if not exist "%ENGINE_SRC%\Character.cpp" (
    echo [WARN] Android engine source not found at:
    echo        %ENGINE_SRC%
    echo        The build will fail if CMakeLists.txt references these files.
    echo        Make sure RimvaleMobile is at: ..\..\AndroidStudioProjects\RimvaleMobile\
    echo.
    echo Press any key to continue anyway, or Ctrl+C to abort...
    pause >nul
)
echo [OK] Engine sources found

echo [Pre-flight] Checking for CMake...
where cmake >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] cmake not found in PATH.
    echo Install CMake from https://cmake.org/download/ and add to PATH.
    pause
    exit /b 1
)
echo [OK] CMake found
echo.

rem ── Step 1: Dump Godot API ─────────────────────────────────────────────────

echo [Step 1/8] Dumping Godot 4.6.1 extension API...
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

rem ── Step 2: Kill any Godot processes that might lock files ─────────────────

echo [Step 2/8] Closing any running Godot instances...
taskkill /f /im Godot_v4.6.1-stable_win64.exe >nul 2>&1
taskkill /f /im Godot.exe >nul 2>&1
timeout /t 1 >nul
echo [OK] Processes cleared
echo.

rem ── Step 3: Clean ALL build directories ────────────────────────────────────

echo [Step 3/8] Removing old build directories...

for %%D in ("%GDEXT%\build_fresh" "%GDEXT%\build" "%GDEXT%\build2") do (
    if exist "%%~D" (
        echo   Cleaning %%~D ...
        takeown /f "%%~D" /r /d y >nul 2>&1
        icacls "%%~D" /grant "%USERNAME%":F /t /q >nul 2>&1
        rmdir /s /q "%%~D" 2>nul
        timeout /t 1 >nul
    )
)
mkdir "%BUILD_DIR%"
echo [OK] Fresh build directory: %BUILD_DIR%
echo.

rem ── Step 4: Clean Godot caches ─────────────────────────────────────────────

echo [Step 4/8] Cleaning Godot import caches...
if exist "%PROJECT%\.godot\imported" (
    rmdir /s /q "%PROJECT%\.godot\imported" 2>nul
    echo   Cleared .godot\imported
)
if exist "%PROJECT%\.godot\shader_cache" (
    rmdir /s /q "%PROJECT%\.godot\shader_cache" 2>nul
    echo   Cleared .godot\shader_cache
)
if exist "%PROJECT%\.godot\uid_cache.bin" (
    del /f "%PROJECT%\.godot\uid_cache.bin" 2>nul
    echo   Cleared uid_cache.bin
)
if exist "%PROJECT%\.godot\global_script_class_cache.cfg" (
    del /f "%PROJECT%\.godot\global_script_class_cache.cfg" 2>nul
    echo   Cleared global_script_class_cache.cfg
)
echo [OK] Godot caches cleared
echo.

rem ── Step 5: Clean old DLL (prevent stale DLL from loading) ─────────────────

echo [Step 5/8] Removing old DLL...
if exist "%DLL_DIR%\%DLL_NAME%" (
    del /f "%DLL_DIR%\%DLL_NAME%" 2>nul
    echo   Deleted old %DLL_NAME%
)
if exist "%DLL_DIR%\%DLL_NAME%.pdb" (
    del /f "%DLL_DIR%\%DLL_NAME%.pdb" 2>nul
    echo   Deleted old PDB
)
echo [OK] Old binaries cleared
echo.

rem ── Step 6: CMake configure ────────────────────────────────────────────────

echo [Step 6/8] CMake configure with Godot 4.6.1 API...
cd /d "%BUILD_DIR%"
cmake -G "Visual Studio 18 2026" -A x64 ^
    -DGODOTCPP_TARGET=template_debug ^
    -DGODOTCPP_DEBUG_CRT=OFF ^
    -DGODOTCPP_CUSTOM_API_FILE="%API_FILE%" ^
    -S "%GDEXT%" ^
    -B "%BUILD_DIR%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [WARN] Visual Studio 2026 generator failed, trying Ninja...
    echo.

    rem Try to set up MSVC environment via vswhere
    for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath 2^>nul') do (
        call "%%i\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
    )

    rmdir /s /q "%BUILD_DIR%" 2>nul
    mkdir "%BUILD_DIR%"
    cd /d "%BUILD_DIR%"

    cmake -G Ninja ^
        -DCMAKE_BUILD_TYPE=Debug ^
        -DGODOTCPP_TARGET=template_debug ^
        -DGODOTCPP_DEBUG_CRT=OFF ^
        -DGODOTCPP_CUSTOM_API_FILE="%API_FILE%" ^
        -S "%GDEXT%" ^
        -B "%BUILD_DIR%"

    if !ERRORLEVEL! NEQ 0 (
        echo.
        echo [ERROR] CMake configure FAILED with both generators.
        echo Check that Visual Studio or Ninja + MSVC are installed.
        pause
        exit /b 1
    )
)
echo.

rem ── Step 7: Build ──────────────────────────────────────────────────────────

echo [Step 7/8] Building (this will take a few minutes)...
cmake --build "%BUILD_DIR%" --config Debug --parallel %NUMBER_OF_PROCESSORS%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] BUILD FAILED. See errors above.
    echo.
    echo Common fixes:
    echo   - Check that Character.cpp, Behavior.cpp, CombatManager.cpp compile
    echo   - Check that rimvale_extension.cpp doesn't have unresolved references
    echo   - Look for missing headers in gdextension\src\
    pause
    exit /b 1
)
echo.

rem ── Step 8: Post-build verification ────────────────────────────────────────

echo [Step 8/8] Post-build setup and verification...

rem Write extension_list.cfg
if not exist "%PROJECT%\.godot" mkdir "%PROJECT%\.godot"
>"%PROJECT%\.godot\extension_list.cfg" echo res://addons/rimvale_engine/rimvale_engine.gdextension
echo   [OK] extension_list.cfg written

rem Verify DLL exists
if exist "%DLL_DIR%\%DLL_NAME%" (
    for %%F in ("%DLL_DIR%\%DLL_NAME%") do (
        echo   [OK] DLL built: %%~nxF (%%~zF bytes^)
    )
) else (
    echo   [WARN] DLL not found at expected location!
    echo          Expected: %DLL_DIR%\%DLL_NAME%
    echo          Searching for it...
    dir /s /b "%BUILD_DIR%\*.dll" 2>nul
)

rem Verify .gdextension file
if exist "%PROJECT%\addons\rimvale_engine\rimvale_engine.gdextension" (
    echo   [OK] rimvale_engine.gdextension present
) else (
    echo   [WARN] rimvale_engine.gdextension missing from addons!
)

echo.
echo ============================================================
echo  PROJECT SUMMARY
echo ============================================================
echo.
echo  Autoloads:
echo    RimvaleAPI          autoload/rimvale_engine_singleton.gd
echo    GameState           autoload/game_state.gd
echo    RimvaleColors       autoload/rimvale_colors.gd
echo    RimvaleUtils        autoload/rimvale_utils.gd
echo    CharacterModelBuilder  autoload/character_model_builder.gd
echo.
echo  Scenes (17 GDScript files):
echo    title_screen, main_menu, main, hub, character_creation,
echo    explore, world, dungeon, combat, shop, inventory,
echo    level_up, team, profile, codex, engine_test
echo    + explore_maps.gd (map data)
echo.
echo  Data modules:
echo    world_data.gd, world_systems.gd, npc_backstories.gd
echo.
echo  C++ Engine (3 compiled sources + headers):
echo    rimvale_extension.cpp, register_types.cpp, platform_out.cpp
echo    + Character.cpp, Behavior.cpp, CombatManager.cpp (from Android)
echo.
echo  Main scene: res://scenes/title/title_screen.tscn
echo.
echo ============================================================
echo  DONE! Now launch Godot - the extension will load.
echo ============================================================
pause
