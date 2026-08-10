@echo off
rem ==============================================================================
rem DURGA Safety App - Frontend Local Startup Script (Windows)
rem Multi-device runner for Android Emulator, iOS Simulator, and Physical Phones.
rem ==============================================================================

rem Change directory to repo root (parent of scripts\)
cd /d "%~dp0.."

rem ------------------------------------------------------------------------------
rem Step 0: Warn if the backend isn't reachable on :8000 yet
rem ------------------------------------------------------------------------------
curl -s -o nul -m 2 http://127.0.0.1:8000/health
if errorlevel 1 (
    echo [!] WARNING: backend not detected on http://127.0.0.1:8000 - start it first ^(run_local.bat^).
    echo.
)

rem ------------------------------------------------------------------------------
rem Step 1: Fetch Flutter Dependencies
rem ------------------------------------------------------------------------------
echo [+] Running flutter pub get...
call flutter pub get

rem ------------------------------------------------------------------------------
rem Step 2: List Available Devices
rem ------------------------------------------------------------------------------
echo.
echo [+] Available Flutter Devices:
echo --------------------------------------------------
call flutter devices
echo --------------------------------------------------
echo.

rem ------------------------------------------------------------------------------
rem Step 3: Prompt User for Target Device & Device Type Selection
rem ------------------------------------------------------------------------------
set DEVICE_ID=
set /p DEVICE_ID="Enter target device ID (or press Enter for default): "

echo.
echo Select target device environment:
echo   1) Android Emulator (Default: http://10.0.2.2:8000/api/v1)
echo   2) iOS Simulator / Local Desktop (Default: http://127.0.0.1:8000/api/v1)
echo   3) Physical Phone (Requires computer's LAN IP address)
set DEV_TYPE=1
set /p DEV_TYPE="Enter choice [1-3] (Default: 1): "

set EXTRA_ARGS=--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

if "%DEV_TYPE%"=="2" (
    set EXTRA_ARGS=--dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
    echo [+] Target environment: iOS Simulator / Desktop (http://127.0.0.1:8000/api/v1)
)
if "%DEV_TYPE%"=="3" (
    set /p LAN_IP="Enter your computer's LAN IP address (e.g., 192.168.1.100): "
    if not "%LAN_IP%"=="" (
        set EXTRA_ARGS=--dart-define=API_BASE_URL=http://%LAN_IP%:8000/api/v1
        echo [+] Target environment: Physical Phone (http://%LAN_IP%:8000/api/v1)
    ) else (
        echo [!] No IP provided. Falling back to Android Emulator URL.
    )
)

rem ------------------------------------------------------------------------------
rem Step 4: Launch Flutter Application
rem ------------------------------------------------------------------------------
echo.
if not "%DEVICE_ID%"=="" (
    echo [+] Executing: flutter run -d %DEVICE_ID% %EXTRA_ARGS%
    call flutter run -d %DEVICE_ID% %EXTRA_ARGS%
) else (
    echo [+] Executing: flutter run %EXTRA_ARGS%
    call flutter run %EXTRA_ARGS%
)
