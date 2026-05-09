@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

:: ============================================================================
::  ██████  ██████  ██       █████  ██████  ███████ ██       ██████  ██     ██
:: ██      ██    ██ ██      ██   ██ ██   ██ ██      ██      ██    ██ ██     ██
::  ██████ ██    ██ ██      ███████ ██████  █████   ██      ██    ██ ██  █  ██
::      ██ ██    ██ ██      ██   ██ ██   ██ ██      ██      ██    ██ ██ ███ ██
::  ██████  ██████  ███████ ██   ██ ██   ██ ██      ███████  ██████   ███ ███
::
::  SolarFlow — Autonomous Solar Irrigation Intelligence System
::  Portable Launcher v2.0 | Works on ANY PC
:: ============================================================================

:: ─── Self-locate: always work relative to this .cmd file ───────────────────
cd /d "%~dp0"
set "ROOT=%~dp0"
:: Remove trailing backslash
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

:: ─── Paths ──────────────────────────────────────────────────────────────────
set "VENV=%ROOT%\.venv"
set "BACKEND=%ROOT%\backend\app.py"
set "FRONTEND=%ROOT%\frontend\index.html"
set "REQUIREMENTS=%ROOT%\backend\requirements.txt"
set "LOGS_DIR=%ROOT%\logs"
set "ENV_FILE=%ROOT%\backend\.env"

:: ─── Log files ──────────────────────────────────────────────────────────────
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
set "LOG_SETUP=%LOGS_DIR%\setup.log"
set "LOG_BACKEND=%LOGS_DIR%\backend.log"
set "LOG_INSTALL=%LOGS_DIR%\install.log"
set "LOG_ERRORS=%LOGS_DIR%\errors.log"

:: ─── ANSI Colors (Windows 10+ Virtual Terminal) ─────────────────────────────
for /F "delims=#" %%a in ('"prompt #$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%a"
set "C0=%ESC%[0m"
set "BOLD=%ESC%[1m"
set "DIM=%ESC%[2m"
set "CYAN=%ESC%[96m"
set "BLUE=%ESC%[94m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "WHITE=%ESC%[97m"
set "MAGENTA=%ESC%[95m"
set "BG_DARK=%ESC%[40m"

:: ─── Clear screen & Print Banner ────────────────────────────────────────────
cls
echo.
echo %CYAN%%BOLD%  ╔══════════════════════════════════════════════════════════╗%C0%
echo %CYAN%%BOLD%  ║  %MAGENTA%☀  SOLARFLOW  %CYAN%— Autonomous Irrigation Intelligence    %CYAN%║%C0%
echo %CYAN%%BOLD%  ║  %DIM%Portable Launcher v2.0 · github.com/Azzammoo10       %CYAN%║%C0%
echo %CYAN%%BOLD%  ╚══════════════════════════════════════════════════════════╝%C0%
echo.
echo %DIM%  Root: %ROOT%%C0%
echo.

echo [%date% %time%] === SolarFlow Launcher Started === >> "%LOG_SETUP%"

:: ═══════════════════════════════════════════════════════════════════════════
::  STEP 1 — PYTHON CHECK
:: ═══════════════════════════════════════════════════════════════════════════
call :PRINT_STEP "1" "5" "Verifying Python installation"

where python >nul 2>&1
if %errorlevel% neq 0 (
    call :PRINT_ERROR "Python not found in PATH!"
    echo.
    echo %YELLOW%  → Opening Python download page...%C0%
    echo %WHITE%  → Install Python 3.10+ and check "Add to PATH"%C0%
    echo [%date% %time%] [ERR] Python not found >> "%LOG_ERRORS%"
    start https://www.python.org/downloads/
    goto :FATAL
)

for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
python -c "import sys; exit(0 if sys.version_info >= (3,8) else 1)" >nul 2>&1
if %errorlevel% neq 0 (
    call :PRINT_ERROR "Python 3.8+ required. Found: !PY_VER!"
    goto :FATAL
)
call :PRINT_OK "Python !PY_VER! detected"
echo [%date% %time%] [OK] Python !PY_VER! >> "%LOG_SETUP%"

:: ═══════════════════════════════════════════════════════════════════════════
::  STEP 2 — VIRTUAL ENVIRONMENT
:: ═══════════════════════════════════════════════════════════════════════════
call :PRINT_STEP "2" "5" "Setting up virtual environment"

if not exist "%VENV%\Scripts\activate.bat" (
    call :PRINT_INFO "Creating .venv for the first time..."
    python -m venv "%VENV%" >nul 2>&1
    if !errorlevel! neq 0 (
        call :PRINT_ERROR "Failed to create virtual environment"
        echo [%date% %time%] [ERR] venv creation failed >> "%LOG_ERRORS%"
        goto :FATAL
    )
    call :PRINT_OK "Virtual environment created"
    echo [%date% %time%] [OK] venv created at %VENV% >> "%LOG_SETUP%"
) else (
    call :PRINT_OK "Virtual environment found"
)

:: Activate venv
call "%VENV%\Scripts\activate.bat"
if %errorlevel% neq 0 (
    call :PRINT_ERROR "Failed to activate virtual environment"
    goto :FATAL
)
call :PRINT_OK "Virtual environment activated"

:: ═══════════════════════════════════════════════════════════════════════════
::  STEP 3 — DEPENDENCIES
:: ═══════════════════════════════════════════════════════════════════════════
call :PRINT_STEP "3" "5" "Installing / verifying dependencies"

:: Quick check: if flask is already installed, skip heavy install
python -c "import flask" >nul 2>&1
if %errorlevel% neq 0 (
    call :PRINT_INFO "Installing packages from requirements.txt..."
    python -m pip install --upgrade pip --quiet >nul 2>&1
    pip install -r "%REQUIREMENTS%" > "%LOG_INSTALL%" 2>&1
    if !errorlevel! neq 0 (
        call :PRINT_ERROR "Dependency install failed! See logs\install.log"
        echo [%date% %time%] [ERR] pip install failed >> "%LOG_ERRORS%"
        goto :FATAL
    )
    call :PRINT_OK "All packages installed"
    echo [%date% %time%] [OK] pip install success >> "%LOG_SETUP%"
) else (
    call :PRINT_OK "Dependencies already satisfied"
)

:: Auto-repair critical modules
for %%m in (flask flask_socketio flask_cors serial eventlet) do (
    python -c "import %%m" >nul 2>&1
    if !errorlevel! neq 0 (
        call :PRINT_INFO "Auto-installing missing module: %%m"
        pip install %%m --quiet >> "%LOG_INSTALL%" 2>&1
        echo [%date% %time%] [FIX] Auto-installed %%m >> "%LOG_ERRORS%"
    )
)

:: ═══════════════════════════════════════════════════════════════════════════
::  STEP 4 — ARDUINO / CONFIG
:: ═══════════════════════════════════════════════════════════════════════════
call :PRINT_STEP "4" "5" "Detecting hardware & configuring"

set "ARDUINO_PORT=DEMO"
set "PORT_COUNT=0"

for /f "tokens=*" %%p in ('python -c "import serial.tools.list_ports; [print(p.device) for p in serial.tools.list_ports.comports()]" 2^>nul') do (
    set /a PORT_COUNT+=1
    set "PORT_!PORT_COUNT!=%%p"
)

if %PORT_COUNT% equ 0 (
    call :PRINT_WARN "No Arduino detected — running in DEMO mode"
    echo [%date% %time%] [WARN] No COM port, using DEMO >> "%LOG_SETUP%"
) else if %PORT_COUNT% equ 1 (
    set "ARDUINO_PORT=!PORT_1!"
    call :PRINT_OK "Arduino found on !ARDUINO_PORT!"
    echo [%date% %time%] [OK] Arduino on !ARDUINO_PORT! >> "%LOG_SETUP%"
) else (
    echo.
    echo %YELLOW%  Multiple serial ports detected:%C0%
    for /l %%i in (1,1,%PORT_COUNT%) do (
        echo     %CYAN%[%%i]%C0% !PORT_%%i!
    )
    echo.
    set /p "CHOICE=  %WHITE%Select port number (1-%PORT_COUNT%): %C0%"
    for /l %%i in (1,1,%PORT_COUNT%) do (
        if "!CHOICE!"=="%%i" set "ARDUINO_PORT=!PORT_%%i!"
    )
    call :PRINT_OK "Using port: !ARDUINO_PORT!"
)

:: Write .env only if missing
if not exist "%ENV_FILE%" (
    (
        echo ARDUINO_PORT=!ARDUINO_PORT!
        echo BAUD_RATE=9600
        echo HOST=127.0.0.1
        echo PORT=5000
        echo DB_PATH=backend/greenhouse.db
        echo LOG_PATH=logs/backend.log
    ) > "%ENV_FILE%"
    call :PRINT_OK ".env configuration created"
) else (
    :: Update port in existing .env silently
    powershell -Command "(Get-Content '%ENV_FILE%') -replace '^ARDUINO_PORT=.*','ARDUINO_PORT=!ARDUINO_PORT!' | Set-Content '%ENV_FILE%'" >nul 2>&1
    call :PRINT_OK ".env configuration updated"
)

:: ═══════════════════════════════════════════════════════════════════════════
::  STEP 5 — LAUNCH BACKEND
:: ═══════════════════════════════════════════════════════════════════════════
call :PRINT_STEP "5" "5" "Launching Flask backend server"

:: Check if already running
netstat -ano 2>nul | findstr ":5000 " >nul 2>&1
if %errorlevel% equ 0 (
    call :PRINT_WARN "Port 5000 already in use — backend may already be running"
    goto :OPEN_BROWSER
)

if not exist "%BACKEND%" (
    call :PRINT_ERROR "backend\app.py not found!"
    echo [%date% %time%] [ERR] app.py missing >> "%LOG_ERRORS%"
    goto :FATAL
)

:: Launch backend in a styled window
start "☀ SolarFlow Backend" cmd /k "title ☀ SolarFlow Backend Server && color 0A && echo. && echo  SolarFlow Backend — http://127.0.0.1:5000 && echo  Press Ctrl+C to stop the server && echo ============================================ && cd /d "%ROOT%\backend" && "%VENV%\Scripts\python.exe" app.py 2>> "%LOG_BACKEND%""

call :PRINT_INFO "Waiting for server to initialize..."

:: Progressive health check with spinner
set "RETRY=0"
set "MAX_RETRIES=10"
:HEALTH_LOOP
set /a RETRY+=1
set /a DOTS=!RETRY! %% 4

:: Quick wait (2 sec)
ping 127.0.0.1 -n 3 >nul

python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/api/status', timeout=3)" >nul 2>&1
if %errorlevel% equ 0 goto :BACKEND_OK

if !RETRY! lss !MAX_RETRIES! (
    set /a PERC=!RETRY! * 100 / !MAX_RETRIES!
    call :PRINT_INFO "Health check !RETRY!/!MAX_RETRIES! — waiting..."
    goto :HEALTH_LOOP
)

call :PRINT_ERROR "Backend did not respond after !MAX_RETRIES! attempts"
echo [%date% %time%] [ERR] Backend health check failed >> "%LOG_ERRORS%"
set /p "OPNLOG=  Open backend log? (Y/N): "
if /i "!OPNLOG!"=="Y" start notepad "%LOG_BACKEND%"
goto :FATAL

:BACKEND_OK
call :PRINT_OK "Backend responding at http://127.0.0.1:5000"
echo [%date% %time%] [OK] Backend active >> "%LOG_SETUP%"

:OPEN_BROWSER
:: ─── Open Dashboard ─────────────────────────────────────────────────────────
echo.
echo %CYAN%  ──────────────────────────────────────────────────────────%C0%
if exist "%FRONTEND%" (
    call :PRINT_INFO "Opening dashboard in default browser..."
    ping 127.0.0.1 -n 2 >nul
    start "" "%FRONTEND%"
    call :PRINT_OK "Dashboard opened!"
    echo [%date% %time%] [OK] Dashboard opened >> "%LOG_SETUP%"
) else (
    call :PRINT_ERROR "frontend\index.html not found!"
    echo [%date% %time%] [ERR] index.html missing >> "%LOG_ERRORS%"
)

:: ─── Success Banner ──────────────────────────────────────────────────────────
echo.
echo %GREEN%%BOLD%  ╔══════════════════════════════════════════════════════════╗%C0%
echo %GREEN%%BOLD%  ║      ✅  SolarFlow is RUNNING successfully!              ║%C0%
echo %GREEN%%BOLD%  ╠══════════════════════════════════════════════════════════╣%C0%
echo %GREEN%  ║  %WHITE%Backend   :%C0% %CYAN%http://127.0.0.1:5000%C0%                         %GREEN%║%C0%
echo %GREEN%  ║  %WHITE%Dashboard :%C0% %CYAN%frontend\index.html (in browser)%C0%             %GREEN%║%C0%
echo %GREEN%  ║  %WHITE%Arduino   :%C0% %YELLOW%!ARDUINO_PORT!%C0%                                    %GREEN%║%C0%
echo %GREEN%  ║  %WHITE%Logs      :%C0% %DIM%%ROOT%\logs\%C0%     %GREEN%║%C0%
echo %GREEN%%BOLD%  ╚══════════════════════════════════════════════════════════╝%C0%
echo.
echo %DIM%  Close the "SolarFlow Backend" window to stop the server.%C0%
echo %DIM%  This launcher window will close in 10 seconds...%C0%
echo.

echo [%date% %time%] [OK] === Launch Complete === >> "%LOG_SETUP%"

:: Auto-close launcher after 10s (backend window stays open)
ping 127.0.0.1 -n 11 >nul
exit /b 0

:: ═══════════════════════════════════════════════════════════════════════════
::  FATAL ERROR
:: ═══════════════════════════════════════════════════════════════════════════
:FATAL
echo.
echo %RED%%BOLD%  ╔══════════════════════════════════════════════════════════╗%C0%
echo %RED%%BOLD%  ║      ❌  Launch Failed — see logs for details            ║%C0%
echo %RED%%BOLD%  ╚══════════════════════════════════════════════════════════╝%C0%
echo.
echo %WHITE%  Log files:%C0%
echo %DIM%    %LOGS_DIR%\errors.log%C0%
echo %DIM%    %LOGS_DIR%\setup.log%C0%
echo.
pause
exit /b 1

:: ═══════════════════════════════════════════════════════════════════════════
::  HELPER SUBROUTINES
:: ═══════════════════════════════════════════════════════════════════════════
:PRINT_STEP
echo.
echo %CYAN%%BOLD%  ┌─ STEP %~1/%~2 ─────────────────────────────────────────────┐%C0%
echo %CYAN%%BOLD%  │  %WHITE%%~3%CYAN%%BOLD%
echo %CYAN%%BOLD%  └──────────────────────────────────────────────────────────%C0%
exit /b 0

:PRINT_OK
echo %GREEN%  ✓  %~1%C0%
exit /b 0

:PRINT_INFO
echo %BLUE%  →  %~1%C0%
exit /b 0

:PRINT_WARN
echo %YELLOW%  ⚠  %~1%C0%
exit /b 0

:PRINT_ERROR
echo %RED%  ✗  %~1%C0%
exit /b 0
