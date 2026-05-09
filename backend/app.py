import os
import time
import json
import sqlite3
import serial
import serial.tools.list_ports
import threading
from datetime import datetime, timedelta
from flask import Flask, jsonify, request
from flask_socketio import SocketIO, emit
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

# --- CONFIGURATION ---
PORT = os.getenv("ARDUINO_PORT", "COM3")
BAUD = int(os.getenv("BAUD_RATE", 9600))
DB_NAME = os.getenv("DB_PATH", "greenhouse.db")

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Shared State
latest_data = {}
arduino_connected = False
start_time = time.time()

# Demo mode state — allows scenario/actuator control without Arduino
demo_state = {
    "scenario": 0,
    "mode": "AUTO",   # AUTO | MANUEL
    "pompe": False,
    "vanne": False,
    "vent": False,
    "chauf": False,
    "ombre": False,
}

SCENARIO_NAMES = {
    0: "NORMAL",
    1: "CHALEUR",
    2: "SECHERESSE",
    3: "PLUIE",
    4: "RESERVOIR VIDE",
    5: "INCENDIE"
}

# --- DATABASE SETUP ---
def init_db():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS readings
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  timestamp TEXT, t REAL, h REAL, sol INTEGER, co2 INTEGER,
                  ldr INTEGER, res INTEGER, pluie INTEGER, flamme INTEGER,
                  pompe INTEGER, vanne INTEGER, vent INTEGER, chauf INTEGER,
                  ombre INTEGER, alarme INTEGER, mode TEXT, scenario TEXT)''')
    conn.commit()
    conn.close()

def save_reading(data):
    try:
        conn = sqlite3.connect(DB_NAME)
        c = conn.cursor()
        now = datetime.now().isoformat()
        c.execute('''INSERT INTO readings
                     (timestamp, t, h, sol, co2, ldr, res, pluie, flamme,
                      pompe, vanne, vent, chauf, ombre, alarme, mode, scenario)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
                  (now, data.get('t'), data.get('h'), data.get('sol'), data.get('co2'),
                   data.get('ldr'), data.get('res'), data.get('pluie'), data.get('flamme'),
                   data.get('pompe'), data.get('vanne'), data.get('vent'), data.get('chauf'),
                   data.get('ombre'), data.get('alarme'), data.get('mode'), data.get('scenario')))

        # Prune older than 24h
        day_ago = (datetime.now() - timedelta(hours=24)).isoformat()
        c.execute("DELETE FROM readings WHERE timestamp < ?", (day_ago,))

        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[{datetime.now().strftime('%H:%M:%S')}] DB ERROR: {e}")

def generate_demo_data():
    import random, math
    sc = demo_state["scenario"]

    # Scenario-based base values (matches firmware scenarios exactly)
    scenarios = {
        0: dict(t=25, h=60, sol=60, co2=40, ldr=50, res=80, pluie=1, flamme=1),
        1: dict(t=38, h=30, sol=30, co2=70, ldr=90, res=70, pluie=1, flamme=1),
        2: dict(t=33, h=25, sol=10, co2=55, ldr=85, res=20, pluie=1, flamme=1),
        3: dict(t=22, h=80, sol=70, co2=30, ldr=40, res=90, pluie=0, flamme=1),
        4: dict(t=28, h=50, sol=40, co2=45, ldr=60, res=5,  pluie=1, flamme=1),
        5: dict(t=45, h=15, sol=20, co2=95, ldr=100, res=60, pluie=1, flamme=0),
    }
    base = scenarios[sc]

    # Add gentle drift for NORMAL scenario to make charts interesting
    drift = random.uniform(-0.5, 0.5)
    t   = round(base["t"] + (math.sin(time.time() / 30) * 2 + drift if sc == 0 else drift * 0.2), 1)
    h   = round(base["h"] + (math.cos(time.time() / 45) * 3 + drift if sc == 0 else drift * 0.2), 1)
    sol = max(0, min(100, base["sol"] + (int(math.sin(time.time() / 60) * 5) if sc == 0 else 0)))
    co2 = max(0, min(100, base["co2"] + (int(abs(math.sin(time.time() / 20)) * 8) if sc == 0 else 0)))
    ldr = max(0, min(100, base["ldr"] + (int(math.sin(time.time() / 15) * 10) if sc == 0 else 0)))
    res = max(0, min(100, base["res"] + (int(math.cos(time.time() / 90) * 5) if sc == 0 else 0)))

    flamme = base["flamme"]
    pluie  = base["pluie"]

    current_mode = demo_state["mode"]

    if current_mode == "MANUEL":
        # In MANUEL mode: use dashboard overrides directly
        pompe = int(demo_state["pompe"])
        vanne = int(demo_state["vanne"])
        vent  = int(demo_state["vent"])
        chauf = int(demo_state["chauf"])
        ombre = int(demo_state["ombre"])
    else:
        # AUTO mode: actuator logic mirrors firmware
        irrigate = int(sol < 40 and pluie == 1)
        pompe  = irrigate
        vanne  = irrigate
        vent   = int(t > 28 or co2 > 70)
        chauf  = int(t < 12)
        ombre  = int(ldr > 70)

    # Fire override always takes priority
    if flamme == 0:
        pompe = 0; vanne = 0; chauf = 0; vent = 1

    alarme = int(res < 15 or t > 35 or sol < 20 or co2 > 80 or flamme == 0)
    mode_str = current_mode if sc == 0 else "SIM"

    return {
        "t": t, "h": h, "sol": sol, "co2": co2, "ldr": ldr, "res": res,
        "pluie": pluie, "flamme": flamme,
        "pompe": pompe, "vanne": vanne, "vent": vent, "chauf": chauf, "ombre": ombre,
        "alarme": alarme, "mode": mode_str,
        "scenario": SCENARIO_NAMES[sc]
    }

# --- SERIAL BRIDGE ---
ser = None

def get_arduino_port():
    ports = serial.tools.list_ports.comports()
    for p in ports:
        if "Arduino" in p.description or "CH340" in p.description:
            return p.device
    return PORT

def serial_worker():
    global arduino_connected, ser, latest_data

    current_port = os.getenv("ARDUINO_PORT", "DEMO")

    # --- DEMO MODE ---
    if current_port == "DEMO":
        print(f"[{datetime.now().strftime('%H:%M:%S')}] STATUS Mode DEMO active (no Arduino)")
        arduino_connected = True
        while True:
            data = generate_demo_data()
            latest_data = data
            socketio.emit('sensor_update', data)
            save_reading(data)
            time.sleep(0.5)
        return

    # --- REAL ARDUINO MODE ---
    while True:
        try:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] STATUS Connecting on {current_port}...")
            ser = serial.Serial(current_port, BAUD, timeout=1)
            arduino_connected = True
            print(f"[{datetime.now().strftime('%H:%M:%S')}] STATUS Connected on {current_port}")

            while True:
                if ser.in_waiting > 0:
                    line = ser.readline().decode('utf-8', errors='ignore').strip()
                    start_idx = line.find('{')
                    if start_idx != -1:
                        try:
                            json_str = line[start_idx:]
                            data = json.loads(json_str)
                            latest_data = data
                            socketio.emit('sensor_update', data)
                            save_reading(data)
                        except json.JSONDecodeError:
                            pass
                time.sleep(0.01)

        except (serial.SerialException, OSError) as e:
            arduino_connected = False
            if ser:
                ser.close()
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ERROR Disconnected. Retry in 3s... ({e})")
            time.sleep(3)
            current_port = get_arduino_port()

# --- REST API ---
@app.route('/api/data', methods=['GET'])
def get_data():
    return jsonify(latest_data)

@app.route('/api/history', methods=['GET'])
def get_history():
    sensor = request.args.get('sensor', 't')
    minutes = int(request.args.get('minutes', 60))

    allowed_sensors = ['t', 'h', 'sol', 'co2', 'ldr', 'res']
    if sensor not in allowed_sensors:
        return jsonify({"error": "Invalid sensor"}), 400

    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    since = (datetime.now() - timedelta(minutes=minutes)).isoformat()
    c.execute(f"SELECT timestamp, {sensor} FROM readings WHERE timestamp > ? ORDER BY timestamp ASC", (since,))
    rows = c.fetchall()
    conn.close()

    return jsonify([{"timestamp": r[0], "value": r[1]} for r in rows])

@app.route('/api/command/<cmd>', methods=['POST'])
def send_command(cmd):
    global ser

    is_demo = os.getenv("ARDUINO_PORT", "DEMO") == "DEMO"

    # Handle mode toggle commands — update demo_state AND forward to real Arduino
    if cmd in ("MODE_AUTO", "MODE_MANUEL"):
        demo_state["mode"] = "AUTO" if cmd == "MODE_AUTO" else "MANUEL"
        # Also send to real Arduino if connected
        if not is_demo and arduino_connected and ser:
            try:
                ser.write(f"{cmd}\n".encode())
            except Exception:
                pass
        return jsonify({"status": "ok", "mode": demo_state["mode"]})

    # Handle scenario commands in both demo and real mode
    if cmd.startswith("SCENARIO_"):
        try:
            sc_id = int(cmd.split("_")[1])
            if 0 <= sc_id <= 5:
                demo_state["scenario"] = sc_id
                return jsonify({"status": "ok", "scenario": SCENARIO_NAMES[sc_id]})
        except (IndexError, ValueError):
            pass
        return jsonify({"status": "error", "message": "Invalid scenario"}), 400

    # Handle actuator toggle commands in demo mode
    if is_demo:
        mapping = {
            "POMPE_ON": ("pompe", True),  "POMPE_OFF": ("pompe", False),
            "VANNE_ON": ("vanne", True),  "VANNE_OFF": ("vanne", False),
            "VENT_ON":  ("vent",  True),  "VENT_OFF":  ("vent",  False),
            "CHAUFF_ON":("chauf", True),  "CHAUFF_OFF":("chauf", False),
            "OMBRE_ON": ("ombre", True),  "OMBRE_OFF": ("ombre", False),
        }
        if cmd in mapping:
            key, val = mapping[cmd]
            demo_state[key] = val
            return jsonify({"status": "ok", "command": cmd})
        return jsonify({"status": "error", "message": "Unknown command"}), 400

    # Real Arduino — forward over serial
    if arduino_connected and ser:
        try:
            ser.write(f"{cmd}\n".encode())
            print(f"[{datetime.now().strftime('%H:%M:%S')}] CMD Sent: {cmd}")
            return jsonify({"status": "sent", "command": cmd})
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 500
    return jsonify({"status": "error", "message": "Arduino not connected"}), 503

@app.route('/api/status', methods=['GET'])
def get_status():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM readings")
    count = c.fetchone()[0]
    conn.close()

    return jsonify({
        "connected": arduino_connected,
        "port": PORT if not ser else ser.port,
        "uptime_seconds": int(time.time() - start_time),
        "db_records": count,
        "last_seen": datetime.now().isoformat() if arduino_connected else None
    })

@app.route('/api/scenarios', methods=['GET'])
def get_scenarios():
    scenarios = [{"id": k, "name": v} for k, v in SCENARIO_NAMES.items()]
    return jsonify(scenarios)

if __name__ == '__main__':
    init_db()
    t = threading.Thread(target=serial_worker, daemon=True)
    t.start()
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)
