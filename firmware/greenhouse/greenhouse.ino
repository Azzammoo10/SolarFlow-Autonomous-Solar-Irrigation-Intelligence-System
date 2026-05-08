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

#define FLAMME 16

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
#define CO2_SENS A1
#define LDR_SENS A2
#define RES_SENS A3

bool modeAuto = true;
int screen = 1;
bool lastBtnState = HIGH;

bool modeSimulation = false;
int scenario = 0;
bool lastScenarioBtn = HIGH;

// REMOTE OVERRIDES
bool remPompe = false, remVanne = false, remVent = false, remChauff = false, remOmbre = false;

// TIMING
unsigned long lastSend = 0;

// LCD MEMORY
String lastLine[4] = {"", "", "", ""};

// ===== PRINT =====
void printLine(int row, String text) {
  int col = (row >= 2) ? -4 : 0;

  if (lastLine[row] != text) {
    lcd.setCursor(col, row);
    lcd.print("                    ");
    lcd.setCursor(col, row);
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
  // SERIAL COMMANDS
  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd == "MODE_AUTO") modeAuto = true;
    else if (cmd == "MODE_MANUEL") modeAuto = false;
    else if (cmd == "MODE_SIM") modeSimulation = !modeSimulation;
    else if (cmd == "POMPE_ON") remPompe = true;
    else if (cmd == "POMPE_OFF") remPompe = false;
    else if (cmd == "VANNE_ON") remVanne = true;
    else if (cmd == "VANNE_OFF") remVanne = false;
    else if (cmd == "VENT_ON") remVent = true;
    else if (cmd == "VENT_OFF") remVent = false;
    else if (cmd == "CHAUFF_ON") remChauff = true;
    else if (cmd == "CHAUFF_OFF") remChauff = false;
    else if (cmd == "OMBRE_ON") remOmbre = true;
    else if (cmd == "OMBRE_OFF") remOmbre = false;
    else if (cmd.startsWith("SCENARIO_")) {
      scenario = cmd.substring(9).toInt();
      if (scenario > 5) scenario = 0;
    }
  }

  // PHYSICAL BUTTONS
  if (digitalRead(BTN_MODE) == LOW) modeAuto = true;
  // Note: if user wants to toggle, we could add state change, but sticking to original logic
  
  modeSimulation = (digitalRead(BTN_SIM) == LOW);

  // SCREEN BUTTON
  bool btnState = digitalRead(BTN_SCREEN);
  if (lastBtnState == HIGH && btnState == LOW) {
    screen++;
    if (screen > 3) screen = 1;
    for (int i = 0; i < 4; i++) lastLine[i] = "";
  }
  lastBtnState = btnState;

  // SCENARIO BUTTON
  bool btnSc = digitalRead(BTN_SCENARIO);
  if (lastScenarioBtn == HIGH && btnSc == LOW) {
    scenario++;
    if (scenario > 5) scenario = 0;
    for (int i = 0; i < 4; i++) lastLine[i] = "";
  }
  lastScenarioBtn = btnSc;

  // REAL SENSORS
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (isnan(t)) t = 0.0;
  if (isnan(h)) h = 0.0;

  int soil = map(analogRead(HUM_SOL), 0, 1023, 0, 100);
  int co2  = map(analogRead(CO2_SENS), 0, 1023, 0, 100);
  int ldr  = map(analogRead(LDR_SENS), 0, 1023, 0, 100);
  int res  = map(analogRead(RES_SENS), 0, 1023, 0, 100);

  int pluie = digitalRead(RAIN_DIG);
  int flamme = digitalRead(FLAMME);

  // SIMULATION OVERRIDE
  if (modeSimulation) {
    switch (scenario) {
      case 0: t=25; h=60; soil=60; co2=40; ldr=50; res=80; pluie=HIGH; flamme=HIGH; break;
      case 1: t=38; h=30; soil=30; co2=70; ldr=90; res=70; pluie=HIGH; flamme=HIGH; break;
      case 2: t=33; h=25; soil=10; co2=55; ldr=85; res=20; pluie=HIGH; flamme=HIGH; break;
      case 3: t=22; h=80; soil=70; co2=30; ldr=40; res=90; pluie=LOW;  flamme=HIGH; break;
      case 4: t=28; h=50; soil=40; co2=45; ldr=60; res=5;  pluie=HIGH; flamme=HIGH; break;
      case 5: t=45; h=15; soil=20; co2=95; ldr=100;res=60; pluie=HIGH; flamme=LOW; break;
    }
  }

  // AUTO / MANUAL CONTROL
  if (modeAuto) {
    digitalWrite(POMPE, soil < 40 && pluie == HIGH);
    digitalWrite(VANNE, digitalRead(POMPE));
    digitalWrite(VENTILATEUR, (t > 28) || (co2 > 70));
    digitalWrite(CHAUFFAGE, t < 12);
    digitalWrite(OMBRAGE, ldr > 70);
  } else {
    digitalWrite(POMPE, !digitalRead(SW_POMPE) || remPompe);
    digitalWrite(VANNE, !digitalRead(SW_VANNE) || remVanne);
    digitalWrite(VENTILATEUR, !digitalRead(SW_VENT) || remVent);
    digitalWrite(CHAUFFAGE, !digitalRead(SW_CHAUFF) || remChauff);
    digitalWrite(OMBRAGE, !digitalRead(SW_OMBRE) || remOmbre);
  }

  // FIRE SAFETY (CRITICAL)
  if (flamme == LOW) {
    digitalWrite(POMPE, LOW);
    digitalWrite(VANNE, LOW);
    digitalWrite(CHAUFFAGE, LOW);
    digitalWrite(VENTILATEUR, HIGH);
  }

  bool critique = (flamme == LOW);
  bool alarme = (res < 15 || t > 35 || soil < 20 || co2 > 80 || critique);
  
  digitalWrite(LED_ALARME, alarme);
  digitalWrite(BUZZER, alarme);

  // JSON OUTPUT EVERY 500MS
  if (millis() - lastSend >= 500) {
    lastSend = millis();
    Serial.print("{\"t\":"); Serial.print(t, 1);
    Serial.print(",\"h\":"); Serial.print(h, 1);
    Serial.print(",\"sol\":"); Serial.print(soil);
    Serial.print(",\"co2\":"); Serial.print(co2);
    Serial.print(",\"ldr\":"); Serial.print(ldr);
    Serial.print(",\"res\":"); Serial.print(res);
    Serial.print(",\"pluie\":"); Serial.print(pluie);
    Serial.print(",\"flamme\":"); Serial.print(flamme);
    Serial.print(",\"mode\":\""); Serial.print(modeAuto ? "AUTO" : "MANUEL");
    Serial.print("\",\"pompe\":"); Serial.print(digitalRead(POMPE));
    Serial.print(",\"vanne\":"); Serial.print(digitalRead(VANNE));
    Serial.print(",\"vent\":"); Serial.print(digitalRead(VENTILATEUR));
    Serial.print(",\"chauf\":"); Serial.print(digitalRead(CHAUFFAGE));
    Serial.print(",\"ombre\":"); Serial.print(digitalRead(OMBRAGE));
    Serial.print(",\"alarme\":"); Serial.print(alarme ? 1 : 0);
    Serial.print(",\"scenario\":\""); Serial.print(getScenarioName(scenario));
    Serial.println("\"}");
  }

  // LCD LOGIC
  if (critique && !modeSimulation) {
    printLine(0, "!!! URGENCE !!!");
    printLine(1, "FEU DETECTE");
    printLine(2, "VENTILATION ON");
    printLine(3, "ARRET SYSTEME");
  }
  else if (alarme && !modeSimulation) {
    printLine(0, "!!! ATTENTION !!!");
    printLine(1, "PROBLEME DETECTE");
    printLine(2, "Verifier Systeme");
    printLine(3, "Action requise");
  }
  else {
    if (modeSimulation) {
      printLine(0, "=== SIMULATION ===");
      printLine(1, getScenarioName(scenario));
      printLine(2, "T:" + String(t, 1) + "C S:" + String(soil));
      printLine(3, "CO2:" + String(co2) + " L:" + String(ldr));
    }
    else {
      if (screen == 1) {
        printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
        printLine(1, "Temp: " + String(t, 1));
        printLine(2, "Hum Air: " + String(h, 1));
        printLine(3, "Hum Sol: " + String(soil));
      }
      else if (screen == 2) {
        printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
        printLine(1, "CO2: " + String(co2));
        printLine(2, "Lum: " + String(ldr));
        printLine(3, "Reserv: " + String(res));
      }
      else if (screen == 3) {
        printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
        printLine(1, "Pompe: " + String(digitalRead(POMPE)));
        printLine(2, "Vanne: " + String(digitalRead(VANNE)));
        printLine(3, "Vent: " + String(digitalRead(VENTILATEUR)));
      }
    }
  }
}
