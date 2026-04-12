@echo off
setlocal

set OUT=%~dp0detect_log.txt

echo === RIMVALE BUILD DETECTION === > "%OUT%"
echo Date: %DATE% %TIME% >> "%OUT%"
echo. >> "%OUT%"

echo -- Visual Studio paths -- >> "%OUT%"
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\"       echo FOUND VS2022 Community >> "%OUT%"
if exist "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\"      echo FOUND VS2022 BuildTools >> "%OUT%"
if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\"    echo FOUND VS2022 Professional >> "%OUT%"
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\" echo FOUND VS2022 BuildTools x86 >> "%OUT%"
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\"  echo FOUND VS2022 Community x86 >> "%OUT%"
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\"  echo FOUND VS2019 Community >> "%OUT%"
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\" echo FOUND VS2019 BuildTools >> "%OUT%"
if exist "C:\Program Files\Microsoft Visual Studio\"                       echo FOUND VS root folder >> "%OUT%"
if exist "C:\Program Files (x86)\Microsoft Visual Studio\"                 echo FOUND VS root folder x86 >> "%OUT%"

echo. >> "%OUT%"
echo -- vswhere -- >> "%OUT%"
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" echo FOUND vswhere x86 >> "%OUT%"
if exist "%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe"      echo FOUND vswhere 64 >> "%OUT%"
if not exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" if not exist "%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe" echo NOT FOUND vswhere >> "%OUT%"

echo. >> "%OUT%"
echo -- Installer folder contents -- >> "%OUT%"
if exist "C:\Program Files (x86)\Microsoft Visual Studio\Installer\" (
    dir "C:\Program Files (x86)\Microsoft Visual Studio\Installer\" >> "%OUT%"
) else (
    echo Installer folder does not exist >> "%OUT%"
)

echo. >> "%OUT%"
echo -- VS root folder contents -- >> "%OUT%"
if exist "C:\Program Files\Microsoft Visual Studio\" (
    dir "C:\Program Files\Microsoft Visual Studio\" >> "%OUT%"
) else (
    echo VS root in Program Files does not exist >> "%OUT%"
)
if exist "C:\Program Files (x86)\Microsoft Visual Studio\" (
    dir "C:\Program Files (x86)\Microsoft Visual Studio\" >> "%OUT%"
) else (
    echo VS root in Program Files x86 does not exist >> "%OUT%"
)

echo. >> "%OUT%"
echo -- PATH -- >> "%OUT%"
echo %PATH% >> "%OUT%"

echo. >> "%OUT%"
echo === DONE === >> "%OUT%"

echo Detection complete! Upload detect_log.txt
type "%OUT%"
pause
