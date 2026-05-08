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
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# Shared State
latest_data = {}
arduino_connected = False
start_time = time.time()

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
    
    current_port = get_arduino_port()
    
    while True:
        try:
            print(f"[{datetime.now().strftime('%H:%M:%S')}] STATUS Attempting connection to {current_port}...")
            ser = serial.Serial(current_port, BAUD, timeout=1)
            arduino_connected = True
            print(f"[{datetime.now().strftime('%H:%M:%S')}] STATUS Connected to Arduino on {current_port}")
            
            while True:
                if ser.in_waiting > 0:
                    line = ser.readline().decode('utf-8').strip()
                    if line:
                        try:
                            data = json.loads(line)
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
            print(f"[{datetime.now().strftime('%H:%M:%S')}] ERROR Disconnected. Retrying in 3s... ({e})")
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
    
    # Sanitize sensor column name to prevent injection
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
    scenarios = [
        {"id": 0, "name": "NORMAL"},
        {"id": 1, "name": "CHALEUR"},
        {"id": 2, "name": "SECHERESSE"},
        {"id": 3, "name": "PLUIE"},
        {"id": 4, "name": "RESERVOIR VIDE"},
        {"id": 5, "name": "INCENDIE"}
    ]
    return jsonify(scenarios)

if __name__ == '__main__':
    init_db()
    # Start Serial thread
    t = threading.Thread(target=serial_worker, daemon=True)
    t.start()
    
    # Start Flask app
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
