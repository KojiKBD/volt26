@echo off
setlocal
cd /d "%~dp0.."

echo ==========================================================
echo   VOLT26 - commit the notes radar work on its own branch
echo ==========================================================
echo.
echo Current branch:
git rev-parse --abbrev-ref HEAD
echo.
echo Working tree:
git status --short
echo.
echo This will create/reset the branch codex/notes-radar at the current
echo HEAD and make TWO commits, staging only these files:
echo.
echo   [radar]   Scripts/VOLT26_ChartRadar.lua
echo   [radar]   BGAnimations/ScreenSelectMusic overlay/VOLT26/Layout.lua
echo   [radar]   BGAnimations/ScreenSelectMusic overlay/VOLT26/PlayerChart.lua
echo   [radar]   CHANGELOG.md
echo   [preview] BGAnimations/ScreenSelectMusic overlay/VOLT26/ChartPreview.lua
echo   [preview] BGAnimations/ScreenSelectMusic overlay/VOLT26/PreviewBackdrop.lua
echo.
echo Nothing else in the working tree is staged or touched. The legacy
echo asset removal stays exactly where it is.
echo.
echo Press Ctrl+C to abort, or
pause

git checkout -B codex/notes-radar
if errorlevel 1 goto :fail

git add "Scripts/VOLT26_ChartRadar.lua"
if errorlevel 1 goto :fail
git add "BGAnimations/ScreenSelectMusic overlay/VOLT26/Layout.lua"
if errorlevel 1 goto :fail
git add "BGAnimations/ScreenSelectMusic overlay/VOLT26/PlayerChart.lua"
if errorlevel 1 goto :fail
git add "CHANGELOG.md"
if errorlevel 1 goto :fail

git commit -F "%~dp0commit-notes-radar.msg"
if errorlevel 1 goto :fail

git add "BGAnimations/ScreenSelectMusic overlay/VOLT26/ChartPreview.lua"
if errorlevel 1 goto :fail
git add "BGAnimations/ScreenSelectMusic overlay/VOLT26/PreviewBackdrop.lua"
if errorlevel 1 goto :fail

REM Deliberately plain: these two files were edited outside this session,
REM so the message states what changed and nothing more.  Amend it with
REM `git commit --amend` if you want the detail recorded.
git commit -m "Update Song Select chart preview panel"
if errorlevel 1 goto :fail

git push -u origin codex/notes-radar
if errorlevel 1 goto :fail

echo.
echo ==========================================================
echo   Done. Branch codex/notes-radar pushed.
echo ==========================================================
git log --oneline -2
echo.
pause
exit /b 0

:fail
echo.
echo ==========================================================
echo   A step above failed. Nothing was pushed.
echo   The branch and any commit already made are still local,
echo   so you can inspect with `git status` and `git log`.
echo ==========================================================
echo.
pause
exit /b 1
