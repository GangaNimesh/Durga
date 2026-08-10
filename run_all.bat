@echo off
rem ==============================================================================
rem DURGA Safety App - Start backend + frontend together.
rem For people not using VS Code / Android Studio's IDE run configs.
rem Opens the backend in its own window and the frontend in this one.
rem ==============================================================================

cd /d "%~dp0"

echo [+] Starting backend in a new window...
start "DURGA Backend" cmd /k "backend\run_local.bat"

echo [+] Waiting for backend to come up on :8000...
set /a COUNT=0
:waitloop
curl -s -o nul -m 1 http://127.0.0.1:8000/health
if not errorlevel 1 goto backendup
set /a COUNT+=1
if %COUNT% GEQ 30 goto backendup
timeout /t 1 /nobreak >nul
goto waitloop
:backendup

echo [+] Backend is live!
echo [+] Starting frontend...
call scripts\run_frontend.bat

