@echo off
set LOG=%~dp0diagnose_log.txt
echo Diagnosing build environment... > "%LOG%"
echo Date: %DATE% %TIME% >> "%LOG%"
echo. >> "%LOG%"

echo ── cmake ──────────────────────────────── >> "%LOG%"
cmake --version >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ── cl.exe (MSVC compiler) ─────────────── >> "%LOG%"
where cl.exe >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ── vswhere ────────────────────────────── >> "%LOG%"
set VSWHERE1="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set VSWHERE2="%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist %VSWHERE1% (
    echo vswhere found at ProgramFiles x86 >> "%LOG%"
    %VSWHERE1% -all -products * -property installationPath >> "%LOG%" 2>&1
) else if exist %VSWHERE2% (
    echo vswhere found at ProgramFiles >> "%LOG%"
    %VSWHERE2% -all -products * -property installationPath >> "%LOG%" 2>&1
) else (
    echo vswhere NOT found >> "%LOG%"
)

echo. >> "%LOG%"
echo ── Searching Program Files for VS ─────── >> "%LOG%"
dir "C:\Program Files\Microsoft Visual Studio\" >> "%LOG%" 2>&1
dir "C:\Program Files (x86)\Microsoft Visual Studio\" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ── Searching for MSBuild ───────────────── >> "%LOG%"
where MSBuild.exe >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ── Searching for ninja ─────────────────── >> "%LOG%"
where ninja >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ── PATH ────────────────────────────────── >> "%LOG%"
echo %PATH% >> "%LOG%"

echo Done. See diagnose_log.txt
pause
