#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <DHT.h>

// LCD
LiquidCrystal_I2C lcd(0x27, 20, 4);

// DHT11
#define DHTPIN 2
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// INPUTS
#define RAIN_DIG 3
#define BTN_MODE 4
#define BTN_SCREEN 5

#define SW_POMPE 6
#define SW_VANNE 7
#define SW_VENT 8
#define SW_CHAUFF 9
#define SW_OMBRE 10

// BUG FIX: Pin 16 = Serial2 RX on Mega — moved to 30
#define FLAMME 30

// SIMULATION
#define BTN_SIM 19
#define BTN_SCENARIO 31

// OUTPUTS
#define POMPE 11
#define VANNE 12
#define VENTILATEUR 13
#define OMBRAGE 14
#define CHAUFFAGE 15

#define LED_ALARME 17
#define BUZZER 18

// ANALOG
#define HUM_SOL A0
#define CO2_PIN A1
#define LDR A2
#define RES A3

bool modeAuto = true;
int screen = 1;
bool lastBtnState = HIGH;

bool modeSimulation = false;
int scenario = 0;
bool lastScenarioBtn = HIGH;

// LCD MEMORY
String lastLine[4] = {"", "", "", ""};

// Serial JSON output timer
unsigned long lastSerialOut = 0;
#define SERIAL_INTERVAL 500

// Alarm state (track changes to avoid beep spam)
bool lastAlarme = false;

// ===== PRINT =====
void printLine(int row, String text) {
  // BUG FIX: col was (row >= 2) ? -4 : 0 — negative cursor is invalid
  if (lastLine[row] != text) {
    lcd.setCursor(0, row);
    lcd.print("                    ");
    lcd.setCursor(0, row);
    lcd.print(text);
    lastLine[row] = text;
  }
}

// ===== SCENARIO NAME =====
String getScenarioName(int s) {
  switch (s) {
    case 0: return "NORMAL";
    case 1: return "CHALEUR";
    case 2: return "SECHERESSE";
    case 3: return "PLUIE";
    case 4: return "RESERVOIR VIDE";
    case 5: return "INCENDIE";
    default: return "NORMAL";
  }
}

// ===== SERIAL COMMAND PARSER =====
// Handles commands from the web dashboard (manual mode)
bool webPompe = false, webVanne = false, webVent = false, webChauf = false, webOmbre = false;

void parseCmd(String cmd) {
  cmd.trim();
  if      (cmd == "POMPE_ON")   webPompe  = true;
  else if (cmd == "POMPE_OFF")  webPompe  = false;
  else if (cmd == "VANNE_ON")   webVanne  = true;
  else if (cmd == "VANNE_OFF")  webVanne  = false;
  else if (cmd == "VENT_ON")    webVent   = true;
  else if (cmd == "VENT_OFF")   webVent   = false;
  else if (cmd == "CHAUFF_ON")  webChauf  = true;
  else if (cmd == "CHAUFF_OFF") webChauf  = false;
  else if (cmd == "OMBRE_ON")   webOmbre  = true;
  else if (cmd == "OMBRE_OFF")  webOmbre  = false;
  else if (cmd.startsWith("SCENARIO_")) {
    scenario = cmd.substring(9).toInt();
    if (scenario < 0 || scenario > 5) scenario = 0;
    for (int i = 0; i < 4; i++) lastLine[i] = "";
  }
}

void setup() {
  Serial.begin(9600);
  lcd.init();
  lcd.backlight();
  dht.begin();

  pinMode(RAIN_DIG, INPUT);
  pinMode(FLAMME, INPUT);

  pinMode(BTN_MODE, INPUT_PULLUP);
  pinMode(BTN_SCREEN, INPUT_PULLUP);

  pinMode(BTN_SIM, INPUT_PULLUP);
  pinMode(BTN_SCENARIO, INPUT_PULLUP);

  pinMode(SW_POMPE, INPUT_PULLUP);
  pinMode(SW_VANNE, INPUT_PULLUP);
  pinMode(SW_VENT, INPUT_PULLUP);
  pinMode(SW_CHAUFF, INPUT_PULLUP);
  pinMode(SW_OMBRE, INPUT_PULLUP);

  pinMode(POMPE, OUTPUT);
  pinMode(VANNE, OUTPUT);
  pinMode(VENTILATEUR, OUTPUT);
  pinMode(OMBRAGE, OUTPUT);
  pinMode(CHAUFFAGE, OUTPUT);

  pinMode(LED_ALARME, OUTPUT);
  pinMode(BUZZER, OUTPUT);
}

void loop() {

  // Read incoming serial commands from web dashboard
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    parseCmd(cmd);
  }

  modeAuto = digitalRead(BTN_MODE) == LOW;
  modeSimulation = digitalRead(BTN_SIM) == LOW;

  // SCREEN BUTTON
  bool btnState = digitalRead(BTN_SCREEN);
  if (lastBtnState == HIGH && btnState == LOW) {
    screen++;
    if (screen > 3) screen = 1;
    for (int i = 0; i < 4; i++) lastLine[i] = "";
  }
  lastBtnState = btnState;

  // SCENARIO BUTTON (physical)
  bool btnSc = digitalRead(BTN_SCENARIO);
  if (lastScenarioBtn == HIGH && btnSc == LOW) {
    scenario++;
    if (scenario > 5) scenario = 0;
    for (int i = 0; i < 4; i++) lastLine[i] = "";
  }
  lastScenarioBtn = btnSc;

  // READ REAL SENSORS
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (isnan(t)) t = 0.0;
  if (isnan(h)) h = 0.0;

  int soil = map(analogRead(HUM_SOL), 0, 1023, 0, 100);
  int co2  = map(analogRead(CO2_PIN), 0, 1023, 0, 100);
  int ldr  = map(analogRead(LDR),     0, 1023, 0, 100);
  int res  = map(analogRead(RES),     0, 1023, 0, 100);

  int pluie  = digitalRead(RAIN_DIG);
  int flamme = digitalRead(FLAMME);

  // SIMULATION OVERRIDE
  if (modeSimulation) {
    switch (scenario) {
      case 0: t=25; h=60; soil=60; co2=40; ldr=50; res=80; pluie=HIGH; flamme=HIGH; break;
      case 1: t=38; h=30; soil=30; co2=70; ldr=90; res=70; pluie=HIGH; flamme=HIGH; break;
      case 2: t=33; h=25; soil=10; co2=55; ldr=85; res=20; pluie=HIGH; flamme=HIGH; break;
      case 3: t=22; h=80; soil=70; co2=30; ldr=40; res=90; pluie=LOW;  flamme=HIGH; break;
      case 4: t=28; h=50; soil=40; co2=45; ldr=60; res=5;  pluie=HIGH; flamme=HIGH; break;
      case 5: t=45; h=15; soil=20; co2=95; ldr=100; res=60; pluie=HIGH; flamme=LOW; break;
    }
  }

  // ACTUATOR LOGIC
  if (modeAuto) {
    // BUG FIX: VANNE used digitalRead(POMPE) — now uses same irrigate condition
    bool irrigate = (soil < 40 && pluie == HIGH);
    digitalWrite(POMPE, irrigate);
    digitalWrite(VANNE, irrigate);
    digitalWrite(VENTILATEUR, (t > 28) || (co2 > 70));
    digitalWrite(CHAUFFAGE, t < 12);
    digitalWrite(OMBRAGE, ldr > 70);
  } else {
    // Manual: web commands take priority, fall back to physical switches
    digitalWrite(POMPE,       webPompe  ? HIGH : !digitalRead(SW_POMPE));
    digitalWrite(VANNE,       webVanne  ? HIGH : !digitalRead(SW_VANNE));
    digitalWrite(VENTILATEUR, webVent   ? HIGH : !digitalRead(SW_VENT));
    digitalWrite(CHAUFFAGE,   webChauf  ? HIGH : !digitalRead(SW_CHAUFF));
    digitalWrite(OMBRAGE,     webOmbre  ? HIGH : !digitalRead(SW_OMBRE));
  }

  // FIRE EMERGENCY — overrides everything
  if (flamme == LOW) {
    digitalWrite(POMPE,       LOW);
    digitalWrite(VANNE,       LOW);
    digitalWrite(CHAUFFAGE,   LOW);
    digitalWrite(VENTILATEUR, HIGH);
  }

  bool critique = (flamme == LOW);
  bool alarme   = (res < 15 || t > 35 || soil < 20 || co2 > 80 || critique);

  // ALARM OUTPUTS
  digitalWrite(LED_ALARME, alarme ? HIGH : LOW);
  if (critique) {
    tone(BUZZER, 880);
  } else if (alarme) {
    tone(BUZZER, 440);
  } else {
    noTone(BUZZER);
  }

  // LCD DISPLAY
  if (critique && !modeSimulation) {
    printLine(0, "!!! URGENCE !!!");
    printLine(1, "FEU DETECTE");
    printLine(2, "VENTILATION ON");
    printLine(3, "ARRET SYSTEME");
  } else if (alarme && !modeSimulation) {
    printLine(0, "!!! ATTENTION !!!");
    printLine(1, "PROBLEME DETECTE");
    printLine(2, "Verifier Systeme");
    printLine(3, "Action requise");
  } else if (modeSimulation) {
    printLine(0, "=== SIMULATION ===");
    printLine(1, getScenarioName(scenario));
    printLine(2, "T:" + String(t, 0) + "C S:" + String(soil));
    printLine(3, "CO2:" + String(co2) + " L:" + String(ldr));
  } else {
    if (screen == 1) {
      printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
      printLine(1, "Temp: " + String(t, 1) + " C");
      printLine(2, "Hum Air: " + String(h, 1) + "%");
      printLine(3, "Hum Sol: " + String(soil) + "%");
    }
    if (screen == 2) {
      printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
      printLine(1, "CO2: " + String(co2) + "%");
      printLine(2, "Lum: " + String(ldr) + "%");
      printLine(3, "Reserv: " + String(res) + "%");
    }
    if (screen == 3) {
      printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
      printLine(1, "Pompe: " + String(digitalRead(POMPE)));
      printLine(2, "Vanne: " + String(digitalRead(VANNE)));
      printLine(3, "Vent: " + String(digitalRead(VENTILATEUR)));
    }
  }

  // SERIAL JSON OUTPUT — sent every 500ms to Flask backend
  unsigned long now = millis();
  if (now - lastSerialOut >= SERIAL_INTERVAL) {
    lastSerialOut = now;

    String modeStr = modeSimulation ? "SIM" : (modeAuto ? "AUTO" : "MANUEL");

    Serial.print("{");
    Serial.print("\"t\":");       Serial.print(t, 1);                  Serial.print(",");
    Serial.print("\"h\":");       Serial.print(h, 1);                  Serial.print(",");
    Serial.print("\"sol\":");     Serial.print(soil);                  Serial.print(",");
    Serial.print("\"co2\":");     Serial.print(co2);                   Serial.print(",");
    Serial.print("\"ldr\":");     Serial.print(ldr);                   Serial.print(",");
    Serial.print("\"res\":");     Serial.print(res);                   Serial.print(",");
    Serial.print("\"pluie\":");   Serial.print(pluie);                 Serial.print(",");
    Serial.print("\"flamme\":"); Serial.print(flamme);                 Serial.print(",");
    Serial.print("\"pompe\":");   Serial.print(digitalRead(POMPE));    Serial.print(",");
    Serial.print("\"vanne\":");   Serial.print(digitalRead(VANNE));    Serial.print(",");
    Serial.print("\"vent\":");    Serial.print(digitalRead(VENTILATEUR)); Serial.print(",");
    Serial.print("\"chauf\":");   Serial.print(digitalRead(CHAUFFAGE)); Serial.print(",");
    Serial.print("\"ombre\":");   Serial.print(digitalRead(OMBRAGE));  Serial.print(",");
    Serial.print("\"alarme\":"); Serial.print(alarme ? 1 : 0);        Serial.print(",");
    Serial.print("\"mode\":\"");  Serial.print(modeStr);               Serial.print("\",");
    Serial.print("\"scenario\":\""); Serial.print(getScenarioName(scenario)); Serial.print("\"");
    Serial.println("}");
  }
}
