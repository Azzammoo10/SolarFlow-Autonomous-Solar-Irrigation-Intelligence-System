@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  SolarFlow - Autonomous Solar Irrigation Intelligence System
::  Portable Launcher v3.0 | Compatible with ANY Windows PC
:: ============================================================

:: Always work from the script's own directory
cd /d "%~dp0"
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

:: Paths
set "VENV=%ROOT%\.venv"
set "BACKEND=%ROOT%\backend\app.py"
set "FRONTEND=%ROOT%\frontend\index.html"
set "REQUIREMENTS=%ROOT%\backend\requirements.txt"
set "ENV_FILE=%ROOT%\backend\.env"
set "LOGS_DIR=%ROOT%\logs"

:: Log files
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
set "LOG_SETUP=%LOGS_DIR%\setup.log"
set "LOG_INSTALL=%LOGS_DIR%\install.log"
set "LOG_BACKEND=%LOGS_DIR%\backend.log"
set "LOG_ERRORS=%LOGS_DIR%\errors.log"

cls
echo.
echo ============================================================
echo   SolarFlow - Autonomous Solar Irrigation System
echo   Portable Launcher v3.0
echo ============================================================
echo.
echo   Root: %ROOT%
echo.

echo [%date% %time%] === SolarFlow Launcher Started === >> "%LOG_SETUP%"

:: ============================================================
::  STEP 1 - Check Python
:: ============================================================
echo [STEP 1/5] Checking Python...

where python >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Python is not installed or not in PATH.
    echo         Please install Python 3.10+ from https://www.python.org/downloads/
    echo         Make sure to check "Add Python to PATH" during installation.
    echo.
    echo [%date% %time%] [ERR] Python not found >> "%LOG_ERRORS%"
    start https://www.python.org/downloads/
    goto :FATAL
)

for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
python -c "import sys; exit(0 if sys.version_info >= (3,8) else 1)" >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python 3.8 or higher is required. Found: %PY_VER%
    echo [%date% %time%] [ERR] Python version too old: %PY_VER% >> "%LOG_ERRORS%"
    goto :FATAL
)
echo [OK] Python %PY_VER% detected.
echo [%date% %time%] [OK] Python %PY_VER% >> "%LOG_SETUP%"

:: ============================================================
::  STEP 2 - Virtual Environment
:: ============================================================
echo.
echo [STEP 2/5] Setting up virtual environment...

if not exist "%VENV%\Scripts\activate.bat" (
    echo [INFO] Creating .venv for the first time (this may take a moment)...
    python -m venv "%VENV%"
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to create virtual environment.
        echo [%date% %time%] [ERR] venv creation failed >> "%LOG_ERRORS%"
        goto :FATAL
    )
    echo [OK] Virtual environment created.
    echo [%date% %time%] [OK] venv created >> "%LOG_SETUP%"
) else (
    echo [OK] Virtual environment found.
)

call "%VENV%\Scripts\activate.bat"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to activate virtual environment.
    echo [%date% %time%] [ERR] venv activation failed >> "%LOG_ERRORS%"
    goto :FATAL
)
echo [OK] Virtual environment activated.

:: ============================================================
::  STEP 3 - Dependencies
:: ============================================================
echo.
echo [STEP 3/5] Checking dependencies...

python -c "import flask" >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Installing packages (first-time setup, please wait)...
    python -m pip install --upgrade pip --quiet >nul 2>&1
    pip install -r "%REQUIREMENTS%" > "%LOG_INSTALL%" 2>&1
    if !errorlevel! neq 0 (
        echo [ERROR] Dependency installation failed!
        echo         Check the log: %LOG_INSTALL%
        echo [%date% %time%] [ERR] pip install failed >> "%LOG_ERRORS%"
        goto :FATAL
    )
    echo [OK] All packages installed.
    echo [%date% %time%] [OK] pip install success >> "%LOG_SETUP%"
) else (
    echo [OK] Dependencies already satisfied.
)

:: Auto-repair critical modules if missing
for %%m in (flask flask_socketio flask_cors serial eventlet) do (
    python -c "import %%m" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [FIX] Auto-installing missing module: %%m
        pip install %%m --quiet >> "%LOG_INSTALL%" 2>&1
        echo [%date% %time%] [FIX] Auto-installed %%m >> "%LOG_ERRORS%"
    )
)

:: ============================================================
::  STEP 4 - Detect Arduino and Configure
:: ============================================================
echo.
echo [STEP 4/5] Detecting Arduino hardware...

set "ARDUINO_PORT=DEMO"
set "PORT_COUNT=0"

for /f "tokens=*" %%p in ('python -c "import serial.tools.list_ports; [print(p.device) for p in serial.tools.list_ports.comports()]" 2^>nul') do (
    set /a PORT_COUNT+=1
    set "PORT_!PORT_COUNT!=%%p"
)

if %PORT_COUNT% equ 0 (
    echo [WARN] No Arduino detected. Running in DEMO mode.
    echo [%date% %time%] [WARN] No COM port found, using DEMO >> "%LOG_SETUP%"
) else if %PORT_COUNT% equ 1 (
    set "ARDUINO_PORT=!PORT_1!"
    echo [OK] Arduino detected on !ARDUINO_PORT!
    echo [%date% %time%] [OK] Arduino on !ARDUINO_PORT! >> "%LOG_SETUP%"
) else (
    echo.
    echo Multiple serial ports detected:
    for /l %%i in (1,1,%PORT_COUNT%) do (
        echo   [%%i] !PORT_%%i!
    )
    echo.
    set /p "CHOICE=Select your Arduino port number (1-%PORT_COUNT%): "
    for /l %%i in (1,1,%PORT_COUNT%) do (
        if "!CHOICE!"=="%%i" set "ARDUINO_PORT=!PORT_%%i!"
    )
    echo [OK] Using port: !ARDUINO_PORT!
)

:: Write or update .env
if not exist "%ENV_FILE%" (
    (
        echo ARDUINO_PORT=!ARDUINO_PORT!
        echo BAUD_RATE=9600
        echo HOST=127.0.0.1
        echo PORT=5000
        echo DB_PATH=backend/greenhouse.db
        echo LOG_PATH=logs/backend.log
    ) > "%ENV_FILE%"
    echo [OK] Configuration file created: backend\.env
) else (
    powershell -Command "(Get-Content '%ENV_FILE%') -replace '^ARDUINO_PORT=.*','ARDUINO_PORT=!ARDUINO_PORT!' | Set-Content '%ENV_FILE%'" >nul 2>&1
    echo [OK] Configuration file updated.
)

:: ============================================================
::  STEP 5 - Launch Backend
:: ============================================================
echo.
echo [STEP 5/5] Launching backend server...

:: Check if port 5000 already in use
netstat -ano 2>nul | findstr ":5000 " >nul 2>&1
if %errorlevel% equ 0 (
    echo [WARN] Port 5000 is already in use. Backend may already be running.
    goto :OPEN_BROWSER
)

if not exist "%BACKEND%" (
    echo [ERROR] backend\app.py not found!
    echo [%date% %time%] [ERR] app.py missing >> "%LOG_ERRORS%"
    goto :FATAL
)

:: Launch backend in a separate window
start "SolarFlow Backend" cmd /k "title SolarFlow Backend && color 0A && echo. && echo  SolarFlow Backend running on http://127.0.0.1:5000 && echo  Press Ctrl+C to stop. && echo ------------------------------------------------ && cd /d "%ROOT%\backend" && "%VENV%\Scripts\python.exe" app.py"

echo [INFO] Waiting for server to start...

set "RETRY=0"
:HEALTH_LOOP
set /a RETRY+=1
ping 127.0.0.1 -n 3 >nul

python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/api/status', timeout=3)" >nul 2>&1
if %errorlevel% equ 0 goto :BACKEND_OK

if !RETRY! lss 10 (
    echo [INFO] Health check !RETRY!/10 - waiting...
    goto :HEALTH_LOOP
)

echo.
echo [ERROR] Backend did not respond after 10 attempts.
echo         Opening backend log for diagnostics...
echo [%date% %time%] [ERR] Backend health check failed >> "%LOG_ERRORS%"
if exist "%LOG_BACKEND%" start notepad "%LOG_BACKEND%"
goto :FATAL

:BACKEND_OK
echo [OK] Backend is running at http://127.0.0.1:5000
echo [%date% %time%] [OK] Backend active >> "%LOG_SETUP%"

:OPEN_BROWSER
echo.
if exist "%FRONTEND%" (
    echo [INFO] Opening dashboard in browser...
    ping 127.0.0.1 -n 2 >nul
    start "" "%FRONTEND%"
    echo [OK] Dashboard opened.
    echo [%date% %time%] [OK] Dashboard opened >> "%LOG_SETUP%"
) else (
    echo [ERROR] frontend\index.html not found!
    echo [%date% %time%] [ERR] index.html missing >> "%LOG_ERRORS%"
)

:: ============================================================
::  SUCCESS
:: ============================================================
echo.
echo ============================================================
echo   SUCCESS - SolarFlow is now running!
echo ============================================================
echo   Backend   : http://127.0.0.1:5000
echo   Dashboard : Open in browser
echo   Arduino   : !ARDUINO_PORT!
echo   Logs      : %LOGS_DIR%\
echo ============================================================
echo.
echo   To stop: close the "SolarFlow Backend" window.
echo.

echo [%date% %time%] [OK] === Launch Complete === >> "%LOG_SETUP%"
pause
exit /b 0

:: ============================================================
::  FATAL ERROR
:: ============================================================
:FATAL
echo.
echo ============================================================
echo   LAUNCH FAILED - Check the error messages above
echo ============================================================
echo   Error log : %LOGS_DIR%\errors.log
echo   Setup log : %LOGS_DIR%\setup.log
echo ============================================================
echo.
pause
exit /b 1
