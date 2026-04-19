@echo off
title Rimvale DLL Diagnostic
echo ============================================================
echo  Step 1: Try loading the DLL directly with PowerShell
echo ============================================================
echo.

set PROJECT=%~dp0
set PROJECT=%PROJECT:~0,-1%
set DLL_PATH=%PROJECT%\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll

echo DLL path: %DLL_PATH%
echo.

powershell -NoProfile -Command ^
    "try { ^
        $null = [System.Runtime.InteropServices.NativeLibrary]::Load('%DLL_PATH%'); ^
        Write-Host '[OK] DLL loaded successfully by Windows' -ForegroundColor Green ^
    } catch { ^
        Write-Host '[FAIL] Windows cannot load DLL:' -ForegroundColor Red; ^
        Write-Host $_.Exception.Message -ForegroundColor Red ^
    }"

echo.
echo ============================================================
echo  Step 2: Check DLL dependencies (what does it need?)
echo ============================================================
echo.

rem Try to find dumpbin via vswhere
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath 2^>nul') do set VSDIR=%%i
if defined VSDIR (
    for /f "tokens=*" %%d in ('dir /s /b "%VSDIR%\dumpbin.exe" 2^>nul ^| findstr "Hostx64\\x64"') do set DUMPBIN="%%d"
)
if defined DUMPBIN (
    %DUMPBIN% /dependents "%DLL_PATH%" 2>nul
) else (
    echo dumpbin not found, trying alternative...
    powershell -NoProfile -Command ^
        "$bytes = [System.IO.File]::ReadAllBytes('%DLL_PATH%'); Write-Host ('DLL size: ' + $bytes.Length + ' bytes')"
)

echo.
echo ============================================================
echo  Step 3: Find actual .godot folder Godot is using
echo ============================================================
echo.

echo Looking for extension_list.cfg...
dir /s /b "%PROJECT%\*extension_list.cfg" 2>nul
echo.
echo Looking for .godot folders:
dir /s /b /ad "%PROJECT%\.godot" 2>nul
echo.
echo Contents of .godot folder:
dir "%PROJECT%\.godot\" 2>nul

echo.
echo ============================================================
echo  Step 4: Check if Godot has a user data override
echo ============================================================
echo.
echo AppData Godot logs:
dir "%APPDATA%\Godot\" 2>nul

pause
