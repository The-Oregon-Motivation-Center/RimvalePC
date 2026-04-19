@echo off
title Rimvale DLL Diagnostic
echo ============================================================
echo  Rimvale DLL Load Diagnostic
echo ============================================================
echo.
setlocal

set PROJECT=%~dp0
set PROJECT=%PROJECT:~0,-1%
set DLL=%PROJECT%\addons\rimvale_engine\bin\Debug\librimvale_engine.windows.debug.x86_64.dll

rem Try to find dumpbin via vswhere
set DUMPBIN=
for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath 2^>nul') do (
    for /f "tokens=*" %%d in ('dir /s /b "%%i\dumpbin.exe" 2^>nul ^| findstr "Hostx64\\x64"') do set DUMPBIN="%%d"
)

echo [1] Checking DLL exists...
if exist "%DLL%" (
    echo     FOUND: %DLL%
) else (
    echo     NOT FOUND: %DLL%
    pause
    exit /b 1
)
echo.

echo [2] DLL Dependencies (dumpbin):
if defined DUMPBIN (
    %DUMPBIN% /dependents "%DLL%" 2>nul
) else (
    echo     dumpbin not available, trying PowerShell...
    powershell -Command "& { $bytes = [System.IO.File]::ReadAllBytes('%DLL%'); Write-Host 'DLL size:' $bytes.Length 'bytes' }"
)
echo.

echo [3] Attempting LoadLibrary via PowerShell...
powershell -NoProfile -Command ^
"Add-Type -TypeDefinition @'" ^
"using System; using System.Runtime.InteropServices;" ^
"public class DllTest {" ^
"    [DllImport(\"\"\"kernel32.dll\"\"\", SetLastError=true)] public static extern IntPtr LoadLibrary(string p);" ^
"    [DllImport(\"\"\"kernel32.dll\"\"\")] public static extern uint GetLastError();" ^
"}" ^
"'@; " ^
"$h = [DllTest]::LoadLibrary('%DLL%'); " ^
"if ($h -ne [IntPtr]::Zero) { Write-Host 'SUCCESS: DLL loaded OK (handle' $h ')' } " ^
"else { $e = [DllTest]::GetLastError(); Write-Host 'FAILED: Windows error code' $e; " ^
"switch($e) { 2 { Write-Host '  = ERROR_FILE_NOT_FOUND' } 126 { Write-Host '  = ERROR_MOD_NOT_FOUND (missing dependency DLL)' } 193 { Write-Host '  = ERROR_BAD_EXE_FORMAT (wrong architecture)' } 5 { Write-Host '  = ERROR_ACCESS_DENIED' } default { Write-Host '  = unknown error' } } }"

echo.
echo [4] Checking common CRT DLLs in System32...
for %%f in (MSVCP140.dll VCRUNTIME140.dll VCRUNTIME140_1.dll VCRUNTIME140_2.dll MSVCP140_1.dll MSVCP140_2.dll) do (
    if exist "C:\Windows\System32\%%f" (
        echo     FOUND:   %%f
    ) else (
        echo     MISSING: %%f  ^<-- THIS IS THE PROBLEM
    )
)

echo.
echo ============================================================
echo  Done. Read the output above to find the missing dependency.
echo ============================================================
pause
