# SolarFlow — Greenhouse IoT Dashboard

## Project

Smart greenhouse monitoring system.
Arduino Mega R3 + Python Flask backend + Vanilla JS dashboard.

## Stack

- Firmware: Arduino C++ (firmware/PFA-2.ino)
- Backend: Python 3, Flask, Flask-SocketIO (threading mode), pyserial, SQLite
- Frontend: Vanilla HTML/CSS/JS, Chart.js, Socket.io client
- Design: Cyprus #0B3D36 + Sand #F0EDE5, DM Sans + IBM Plex Mono

## Current Bugs (fix these first)

1. Actionneurs bloc not responding in MANUAL mode
2. FLAMME pin 16 conflicts with Serial2 RX on Mega — move to pin 30
3. modeAuto always true if BTN_MODE not wired to GND
4. Missing closing braces in printLine() and getScenarioName()
5. async_mode='eventlet' fails — use threading

## Rules

- Always read DESIGN-THEME.md before any frontend work
- Never use placeholder comments — full implementation only
- Test every Serial command after modification
- Keep logs in logs/ directory
