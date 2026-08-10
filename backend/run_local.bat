@echo off
rem ==============================================================================
rem DURGA Safety App - Backend Local Startup Script (Windows)
rem Runs virtual environment setup, migrations, and FastAPI uvicorn server.
rem ==============================================================================

rem Change directory to backend folder (where this batch file resides)
cd /d "%~dp0"

rem Set PYTHONPATH so alembic and app modules resolve correctly
set PYTHONPATH=.

rem ------------------------------------------------------------------------------
rem Step 1: Virtual Environment Setup (Idempotent)
rem Check if .venv exists. If missing, create it and install requirements.txt.
rem ------------------------------------------------------------------------------
if exist ".venv\Scripts\activate.bat" (
    echo [+] Virtual environment found. Activating...
    call .venv\Scripts\activate.bat
) else (
    echo [+] Virtual environment not found. Creating .venv...
    python -m venv .venv
    if errorlevel 1 (
        echo [!] ERROR: Failed to create virtual environment using 'python'.
        echo [!] Please verify Python is installed and added to PATH.
        exit /b 1
    )
    echo [+] Activating virtual environment...
    call .venv\Scripts\activate.bat
    echo [+] Installing backend dependencies from requirements.txt...
    pip install -r requirements.txt
)

rem Ensure uvicorn is installed in the active venv
where uvicorn >nul 2>nul
if errorlevel 1 (
    echo [+] Installing/refreshing backend requirements...
    pip install -r requirements.txt
)

rem ------------------------------------------------------------------------------
rem Step 2: Environment Configuration (.env Check)
rem FIX: this used to exit with an error if .env was missing. Auto-create it
rem from .env.example instead - the app boots with dev defaults either way.
rem ------------------------------------------------------------------------------
if not exist ".env" (
    if exist ".env.example" (
        copy /y ".env.example" ".env" >nul
        echo [+] backend\.env created from .env.example.
    ) else (
        echo [!] No .env or .env.example found - continuing with built-in dev defaults.
    )
) else (
    echo [+] backend\.env verified.
)

rem ------------------------------------------------------------------------------
rem Step 3: Apply schema
rem Postgres: Alembic is the source of truth. SQLite: the app itself creates
rem tables on startup, so Alembic is skipped there to keep a fresh clone
rem friction-free. Detect via DATABASE_URL in .env.
rem ------------------------------------------------------------------------------
set DB_URL=
if exist ".env" (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        if "%%A"=="DATABASE_URL" set DB_URL=%%B
    )
)
if "%DB_URL%"=="" set DB_URL=sqlite:///./durga.db (built-in default)
echo [+] DATABASE_URL: %DB_URL%

echo %DB_URL% | findstr /i "postgres" >nul
if %errorlevel%==0 (
    echo [+] Postgres detected - running Alembic migrations ^(alembic upgrade head^)...
    alembic upgrade head
    if errorlevel 1 (
        echo.
        echo [!] ERROR: Database migration / connection failed.
        echo [!] If you don't have PostgreSQL running locally, set
        echo [!] DATABASE_URL=sqlite:///./durga.db in backend\.env instead.
        echo.
        exit /b 1
    )
) else (
    echo [+] SQLite detected - tables are created automatically on startup, skipping Alembic.
)

rem ------------------------------------------------------------------------------
rem Step 4: Start FastAPI Backend Server
rem Launch uvicorn with hot-reloading on port 8000.
rem ------------------------------------------------------------------------------
echo [+] Starting FastAPI server on http://0.0.0.0:8000 ...
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
