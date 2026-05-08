# SolarFlow — Autonomous Solar Irrigation Intelligence System

A smart greenhouse monitoring and control system powered by Arduino Mega R3 and a Python-based real-time dashboard.

## Project Structure

- **`/firmware`**: Firmware for the Arduino Mega R3.
- **`/backend`**: Python Flask server with Socket.io and SQLite integration.
- **`/frontend`**: Web-based IoT dashboard with real-time analytics.
- **`/docs`**: Hardware schematics, component lists, and design specifications.

## Quick Start

### Backend
1. Navigate to `/backend`.
2. Install dependencies: `pip install -r requirements.txt`.
3. Run the server: `python app.py`.

### Frontend
- Open `frontend/index.html` in a modern browser.

### Firmware
- Open `firmware/greenhouse/greenhouse.ino` in the Arduino IDE and upload to your Mega R3.

## Hardware Setup
- Detailed schematics are available in `docs/schematics/`.
- Component list is in `docs/components.md`.
