@echo off
title Rimvale -- Upload to GitHub
echo ============================================
echo  Rimvale -- Upload All Changes to GitHub
echo ============================================
echo.

cd /d "%~dp0"

echo Checking git status...
git status --short
echo.

echo Staging all changes...
git add -A
if errorlevel 1 (
    echo ERROR: git add failed.
    pause
    exit /b 1
)

echo.
set /p COMMIT_MSG="Enter commit message (or press Enter for default): "
if "%COMMIT_MSG%"=="" set COMMIT_MSG=Implement all 24 PHB/WG/GMG features: death saves, grapple, mounts, quests, bounty, banking, siege, kaiju, procedural dungeons, legacy system, and more

echo.
echo Committing with message: %COMMIT_MSG%
git commit -m "%COMMIT_MSG%"
if errorlevel 1 (
    echo ERROR: git commit failed. Maybe there are no changes to commit?
    pause
    exit /b 1
)

echo.
echo Pushing to GitHub (origin/main)...
git push origin main
if errorlevel 1 (
    echo ERROR: git push failed. Check your credentials or network connection.
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Successfully uploaded to GitHub!
echo ============================================
echo.
pause
