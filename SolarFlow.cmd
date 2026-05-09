@echo off
:: Se placer dans le dossier du script
cd /d "%~dp0"

echo [1/3] Activation de l'environnement venv...
call .venv\Scripts\activate.bat

echo [2/3] Ouverture du Dashboard...
start "" "frontend\index.html"

echo [3/3] Lancement du Backend...
python backend\app.py

pause
