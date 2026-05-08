# Greenhouse IoT Dashboard — Project Context

## Project

Smart greenhouse monitoring & control system.
Arduino Mega R3 + Python backend + Web dashboard.

## Hardware

- Arduino Mega R3 (USB Serial, 9600 baud)
- DHT11: pin 2 (temp + air humidity)
- Soil moisture: A0 (analog 0-1023 → 0-100%)
- CO2 sensor: A1 (analog 0-1023 → 0-100%)
- LDR light: A2 (analog 0-1023 → 0-100%)
- Reservoir level: A3 (analog 0-1023 → 0-100%)
- Rain sensor: D3 (digital, LOW = rain)
- Flame sensor: D16 (digital, LOW = fire)
- Actuators: Pump(11), Valve(12), Fan(13), Shading(14), Heating(15)
- Alarm LED: D17, Buzzer: D18

## Modes

- AUTO: threshold-based rules
- MANUAL: physical switches SW_POMPE(6) SW_VANNE(7) SW_VENT(8) SW_CHAUFF(9) SW_OMBRE(10)
- SIMULATION: 6 scenarios (NORMAL, CHALEUR, SECHERESSE, PLUIE, RESERVOIR VIDE, INCENDIE)

## Tech Stack

- Backend: Python 3, pyserial, Flask, Flask-SocketIO, SQLite
- Frontend: Vanilla HTML/CSS/JS, Chart.js, Socket.io client
- Serial: JSON format, 500ms interval, 9600 baud

## Thresholds

- Temp: normal<28, warning 28-35, critical>35 or <12 (°C)
- CO2: normal<50, warning 50-80, critical>80 (%)
- Soil: normal>40, warning 20-40, critical<20 (%)
- Reservoir: normal>30, warning 15-30, critical<15 (%)

## Design

- Dark theme dashboard
- Professional IoT aesthetic (not generic)
- Real-time charts with Chart.js
- Responsive (desktop + mobile)
- Language: French labels (MODE, CAPTEURS, ACTIONNEURS, ALARMES)
