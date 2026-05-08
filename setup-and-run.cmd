@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: GREENHOUSE IOT SETUP & RUN SCRIPT
:: ============================================================================
:: Ensures Environment is ready, installs dependencies, and launches the system.

:: Ensure we are in the script directory
cd /d "%~dp0"

:: Create logs directory if not exists
if not exist logs mkdir logs

:: Define Log Files
set SETUP_LOG=logs\setup.log
set INSTALL_LOG=logs\install.log
set BACKEND_LOG=logs\backend.log
set ERRORS_LOG=logs\errors.log

:: Initial Log Entry
echo [%date% %time%] [INFO] --- Starting Setup Script --- >> %SETUP_LOG%

:: UI Elements (ANSI Codes for Colors - Works in Win10+)
for /F "delims=#" %%a in ('"prompt #$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "CYAN=%ESC%[96m"
set "WHITE=%ESC%[97m"
set "RESET=%ESC%[0m"

:: Print Header
echo %CYAN%================================================%RESET%
echo %CYAN% GREENHOUSE IOT — Solar Irrigation System v1.0 %RESET%
echo %CYAN% Autonomous Monitoring and Control Dashboard   %RESET%
echo %CYAN%================================================%RESET%
echo.

:: --- PHASE 1: ENVIRONMENT CHECK ---
echo %WHITE%[STEP 1/7] Checking environment...%RESET%

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERR] Python is not installed or not in PATH.%RESET%
    echo [%date% %time%] [ERR] Python not found >> %SETUP_LOG%
    echo [%date% %time%] [ERR] Python not found >> %ERRORS_LOG%
    start https://www.python.org/downloads/
    pause
    exit /b 1
)

:: Check Python Version (>= 3.8)
for /f "tokens=2" %%v in ('python --version') do set PY_VERSION=%%v
python -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)"
if %errorlevel% neq 0 (
    echo %YELLOW%[WARN] Python 3.8 or higher is required. Found: !PY_VERSION!%RESET%
    echo [%date% %time%] [WARN] Incompatible Python version: !PY_VERSION! >> %SETUP_LOG%
    pause
    exit /b 1
)
echo %GREEN%[OK] Python !PY_VERSION! detected.%RESET%
echo [%date% %time%] [OK] Python !PY_VERSION! detected >> %SETUP_LOG%

:: Check Pip
pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERR] Pip is not available.%RESET%
    echo [%date% %time%] [ERR] Pip not found >> %SETUP_LOG%
    pause
    exit /b 1
)
echo %GREEN%[OK] Pip detected.%RESET%

:: --- PHASE 2: DEPENDENCIES INSTALLATION ---
echo %WHITE%[STEP 2/7] Installing dependencies...%RESET%

:: Create Virtual Environment
if not exist .venv (
    echo %WHITE%[INFO] Creating virtual environment...%RESET%
    echo [%date% %time%] [INFO] Creating .venv >> %SETUP_LOG%
    python -m venv .venv
    if %errorlevel% neq 0 (
        echo %RED%[ERR] Failed to create virtual environment.%RESET%
        echo [%date% %time%] [ERR] Venv creation failed >> %ERRORS_LOG%
        pause
        exit /b 1
    )
) else (
    echo %GREEN%[OK] Virtual environment exists.%RESET%
)

:: Activate Virtual Environment
call .venv\Scripts\activate
if %errorlevel% neq 0 (
    echo %RED%[ERR] Failed to activate virtual environment.%RESET%
    pause
    exit /b 1
)

:: Upgrade Pip
echo %WHITE%[INFO] Upgrading pip...%RESET%
python -m pip install --upgrade pip >nul 2>&1

:: Install Requirements
echo %WHITE%[INFO] Installing packages from requirements.txt...%RESET%
echo [%date% %time%] [INFO] Running pip install >> %SETUP_LOG%
pip install -r backend\requirements.txt > %INSTALL_LOG% 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERR] Dependency installation failed. Check %INSTALL_LOG%%RESET%
    echo [%date% %time%] [ERR] Pip install failed >> %ERRORS_LOG%
    pause
    exit /b 1
)

:: Check and Install Flask-CORS separately
python -c "import flask_cors" >nul 2>&1
if %errorlevel% neq 0 (
    echo %WHITE%[INFO] Installing flask-cors...%RESET%
    pip install flask-cors >> %INSTALL_LOG% 2>&1
    echo [%date% %time%] [FIX] Auto-installed flask-cors >> %ERRORS_LOG%
)

:: Critical Module Verification
for %%m in (flask flask_socketio flask_cors serial eventlet dotenv) do (
    python -c "import %%m" >nul 2>&1
    if !errorlevel! neq 0 (
        echo %YELLOW%[WARN] %%m missing, attempting auto-repair...%RESET%
        pip install %%m >> %INSTALL_LOG% 2>&1
        echo [%date% %time%] [FIX] Auto-repaired missing module: %%m >> %ERRORS_LOG%
    )
)
echo %GREEN%[OK] All dependencies ready.%RESET%
echo [%date% %time%] [OK] Dependencies ready >> %SETUP_LOG%

:: --- PHASE 3: ARDUINO PORT DETECTION ---
echo %WHITE%[STEP 3/7] Detecting Arduino...%RESET%

set ARDUINO_PORT=DEMO
set PORT_COUNT=0

:: Collect ports into a temporary list
for /f "tokens=*" %%p in ('python -c "import serial.tools.list_ports; [print(p.device) for p in serial.tools.list_ports.comports()]"') do (
    set /a PORT_COUNT+=1
    set "PORT_!PORT_COUNT!=%%p"
)

if %PORT_COUNT% equ 0 (
    echo %YELLOW%[WARN] Arduino not detected. Backend will start in demo mode.%RESET%
    echo [%date% %time%] [WARN] No Arduino found, switching to DEMO >> %SETUP_LOG%
) else if %PORT_COUNT% equ 1 (
    set ARDUINO_PORT=%PORT_1%
    echo %GREEN%[OK] Arduino detected on !ARDUINO_PORT!%RESET%
    echo [%date% %time%] [OK] Arduino detected on !ARDUINO_PORT! >> %SETUP_LOG%
) else (
    echo %WHITE%Multiple ports detected:%RESET%
    for /l %%i in (1,1,%PORT_COUNT%) do (
        echo   [%%i] !PORT_%%i!
    )
    set /p CHOICE="Enter the number of your Arduino port (1-%PORT_COUNT%): "
    for /l %%i in (1,1,%PORT_COUNT%) do (
        if "!CHOICE!"=="%%i" set ARDUINO_PORT=!PORT_%%i!
    )
    echo %GREEN%[OK] Selected port: !ARDUINO_PORT!%RESET%
    echo [%date% %time%] [INFO] User selected port !ARDUINO_PORT! >> %SETUP_LOG%
)

:: --- PHASE 4: CONFIGURATION ---
echo %WHITE%[STEP 4/7] Configuring backend...%RESET%
echo [%date% %time%] [INFO] Entering Phase 4 >> %SETUP_LOG%

if exist "backend\.env" goto :CONFIG_EXISTS

echo ARDUINO_PORT=!ARDUINO_PORT!> "backend\.env"
echo BAUD_RATE=9600>> "backend\.env"
echo HOST=127.0.0.1>> "backend\.env"
echo PORT=5000>> "backend\.env"
echo DB_PATH=backend/greenhouse.db>> "backend\.env"
echo LOG_PATH=logs/backend.log>> "backend\.env"

if not exist "backend\.env" (
    echo %RED%[ERR] Failed to create backend\.env!%RESET%
    echo [%date% %time%] [ERR] .env creation failed >> %ERRORS_LOG%
    pause
    exit /b 1
)

echo %GREEN%[OK] Configuration created in backend\.env%RESET%
echo [%date% %time%] [OK] Config created >> %SETUP_LOG%
goto :PHASE_5

:CONFIG_EXISTS
echo %WHITE%[INFO] Config already exists (.env)%RESET%
echo [%date% %time%] [INFO] Using existing config >> %SETUP_LOG%

:PHASE_5
:: --- PHASE 5: LAUNCH BACKEND ---
echo %WHITE%[STEP 5/7] Launching Backend...%RESET%
echo [%date% %time%] [INFO] Entering Phase 5 >> %SETUP_LOG%

:: Check if port 5000 is in use
netstat -ano | findstr :5000 >nul 2>&1
if %errorlevel% equ 0 (
    echo %YELLOW%[WARN] Port 5000 is already in use. Attempting to start anyway...%RESET%
    echo [%date% %time%] [WARN] Port 5000 busy >> %SETUP_LOG%
)

:: Verify app.py exists
if not exist "backend\app.py" (
    echo %RED%[ERR] backend\app.py not found!%RESET%
    echo [%date% %time%] [ERR] app.py missing >> %ERRORS_LOG%
    pause
    exit /b 1
)
:: Start Backend in New Window
echo %WHITE%[INFO] Starting server process...%RESET%
start "GreenHouse Backend" cmd /c "title GreenHouse Backend && cd backend && ..\.venv\Scripts\python app.py >> ..\logs\backend.log 2>&1"

echo %WHITE%[INFO] Waiting 5s for initialization...%RESET%
ping 127.0.0.1 -n 6 >nul

:: Health Check
echo %WHITE%[INFO] Checking backend health...%RESET%
set RETRY=0
:HEALTH_CHECK
set /a RETRY+=1
python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/api/status')" >nul 2>&1
if %errorlevel% neq 0 (
    if !RETRY! lss 5 (
        echo %YELLOW%[INFO] Retry !RETRY!/5...%RESET%
        ping 127.0.0.1 -n 3 >nul
        goto HEALTH_CHECK
    )
    echo %RED%[ERR] Backend failed to start or is not responding.%RESET%
    echo [%date% %time%] [ERR] Backend Health Check Failed >> %ERRORS_LOG%
    
    if exist "logs\backend.log" (
        set /p OPEN_LOG="Open backend log to see error? (Y/N): "
        if /i "!OPEN_LOG!"=="Y" start notepad "logs\backend.log"
    ) else (
        echo %RED%[ERR] No backend log found. The process likely failed to even start.%RESET%
    )
    pause
    exit /b 1
)
echo %GREEN%[OK] Backend responding on http://127.0.0.1:5000%RESET%
echo [%date% %time%] [OK] Backend active >> %SETUP_LOG%

:: --- PHASE 6: LAUNCH DASHBOARD ---
echo %WHITE%[STEP 6/7] Launching Dashboard...%RESET%
echo [%date% %time%] [INFO] Entering Phase 6 >> %SETUP_LOG%
ping 127.0.0.1 -n 2 >nul

if exist "frontend\index.html" (
    start "" "frontend\index.html"
    echo %GREEN%[OK] Dashboard opened in browser.%RESET%
    echo [%date% %time%] [OK] Dashboard opened >> %SETUP_LOG%
) else (
    echo %RED%[ERR] frontend\index.html not found!%RESET%
    echo [%date% %time%] [ERR] Dashboard file missing >> %ERRORS_LOG%
)

:: --- PHASE 7: FINAL STATUS ---
echo [%date% %time%] [INFO] Entering Phase 7 >> %SETUP_LOG%
echo.
echo %CYAN%================================================%RESET%
echo %GREEN%   SUCCESS: System is now active!           %RESET%
echo %CYAN%================================================%RESET%
echo %WHITE%   Backend:    Running on http://127.0.0.1:5000 %RESET%
echo %WHITE%   Dashboard:  Opened in browser                %RESET%
echo %WHITE%   Arduino:    !ARDUINO_PORT! mode              %RESET%
echo %WHITE%   Logs:       %~dp0logs\                       %RESET%
echo %CYAN%================================================%RESET%
echo   %YELLOW%Press CTRL+C in the Backend window to stop.%RESET%
echo.

echo [%date% %time%] [OK] Final Launch Success >> %SETUP_LOG%

pause
