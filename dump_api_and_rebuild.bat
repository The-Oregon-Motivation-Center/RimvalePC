@echo off
title Rimvale - Dump API + Rebuild
set GODOT=C:\Users\Acata\Documents\Lumen movies\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe
set PROJECT=C:\Users\Acata\RimvaleGodot
set GDEXT=%PROJECT%\gdextension
set API_OUT=%GDEXT%\extension_api_461.json

echo ============================================================
echo  Step 1: Dumping Godot 4.6.1 extension API...
echo ============================================================
cd /d "%PROJECT%"
"%GODOT%" --headless --dump-extension-api 2>&1
rem The file lands in the working directory as extension_api.json
if exist "%PROJECT%\extension_api.json" (
    copy /y "%PROJECT%\extension_api.json" "%API_OUT%"
    del "%PROJECT%\extension_api.json"
    echo [OK] API dumped to: %API_OUT%
) else (
    echo [WARN] extension_api.json not found in project dir, checking CWD...
    if exist "extension_api.json" copy /y "extension_api.json" "%API_OUT%"
)
echo.

echo ============================================================
echo  Step 2: Replacing godot-cpp extension_api.json with 4.6.1
echo ============================================================
if exist "%API_OUT%" (
    copy /y "%API_OUT%" "%GDEXT%\godot-cpp\gdextension\extension_api.json"
    echo [OK] godot-cpp extension_api.json updated to 4.6.1
) else (
    echo [SKIP] Could not find dumped API, skipping update.
)
echo.

echo ============================================================
echo  Step 3: Fixing build directory permissions + rebuilding
echo ============================================================
echo Taking ownership of build directory...
takeown /f "%GDEXT%\build" /r /d y >nul 2>&1
icacls "%GDEXT%\build" /grant "%USERNAME%":F /t /q >nul 2>&1

echo Deleting old tlog directories...
for /d /r "%GDEXT%\build" %%d in (*.tlog) do (
    takeown /f "%%d" /r /d y >nul 2>&1
    icacls "%%d" /grant "%USERNAME%":F /t /q >nul 2>&1
    rmdir /s /q "%%d" 2>nul
)
for /d /r "%GDEXT%\build" %%d in (*.dir) do (
    takeown /f "%%d" /r /d y >nul 2>&1
    icacls "%%d" /grant "%USERNAME%":F /t /q >nul 2>&1
)

echo.
echo Running cmake build...
cd /d "%GDEXT%\build"
"C:\Program Files\CMake\bin\cmake.exe" --build . --config Debug

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================================================
    echo  Build FAILED. Trying clean rebuild in new directory...
    echo ============================================================
    set NEWBUILD=%GDEXT%\build2
    if exist "%NEWBUILD%" rmdir /s /q "%NEWBUILD%" 2>nul
    mkdir "%NEWBUILD%"
    cd /d "%NEWBUILD%"

    rem Set up MSVC environment
    call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1

    "C:\Program Files\CMake\bin\cmake.exe" -G Ninja ^
        -DCMAKE_BUILD_TYPE=Debug ^
        -DGODOTCPP_TARGET=template_debug ^
        -DGODOTCPP_DEBUG_CRT=OFF ^
        -S "%GDEXT%" ^
        -B "%NEWBUILD%"

    if %ERRORLEVEL% NEQ 0 (
        echo CMake configure FAILED.
        pause
        exit /b 1
    )

    "C:\Program Files\CMake\bin\cmake.exe" --build "%NEWBUILD%"
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo BUILD FAILED. See errors above.
        pause
        exit /b 1
    )
)

echo.
echo ============================================================
echo  Done! DLL rebuilt with Godot 4.6.1 API bindings.
echo  Now launch Godot normally - the extension should load.
echo ============================================================
pause
