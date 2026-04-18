@echo off
title Rimvale DLL Diagnostic
echo ============================================================
echo  Step 1: Try loading the DLL directly with PowerShell
echo ============================================================
echo.

set DLL_PATH=C:\Users\Acata\RimvaleGodot\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll

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

powershell -NoProfile -Command ^
    "& 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe' /dependents '%DLL_PATH%' 2>$null | Select-String 'dll' | ForEach-Object { $_.Line.Trim() }" 2>nul

if %ERRORLEVEL% NEQ 0 (
    echo dumpbin not found, trying alternative...
    powershell -NoProfile -Command ^
        "$bytes = [System.IO.File]::ReadAllBytes('%DLL_PATH%'); Write-Host ('DLL size: ' + $bytes.Length + ' bytes')"
)

echo.
echo ============================================================
echo  Step 3: Find actual .godot folder Godot is using
echo ============================================================
echo.

echo Looking for extension_list.cfg in all possible locations...
dir /s /b "C:\Users\Acata\*extension_list.cfg" 2>nul
echo.
echo Looking for .godot folders:
dir /s /b /ad "C:\Users\Acata\RimvaleGodot\.godot" 2>nul
echo.
echo Contents of .godot folder:
dir "C:\Users\Acata\RimvaleGodot\.godot\" 2>nul

echo.
echo ============================================================
echo  Step 4: Check if Godot has a user data override
echo ============================================================
echo.
echo AppData Godot logs:
dir "C:\Users\Acata\AppData\Roaming\Godot\" 2>nul

pause
