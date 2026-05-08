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
#define CO2 A1
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
  }
  return "";
}

void setup() {
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

  // SCENARIO BUTTON
  bool btnSc = digitalRead(BTN_SCENARIO);
  if (lastScenarioBtn == HIGH && btnSc == LOW) {
    scenario++;
    if (scenario > 5) scenario = 0;
    for (int i = 0; i < 4; i++) lastLine[i] = "";
  }
  lastScenarioBtn = btnSc;

  // REAL VALUES
  float t = dht.readTemperature();
  float h = dht.readHumidity();

  int soil = map(analogRead(A0), 0, 1023, 0, 100);
  int co2  = map(analogRead(A1), 0, 1023, 0, 100);
  int ldr  = map(analogRead(A2), 0, 1023, 0, 100);
  int res  = map(analogRead(A3), 0, 1023, 0, 100);

  int pluie = digitalRead(RAIN_DIG);
  int flamme = digitalRead(FLAMME);

  // SIMULATION OVERRIDE
  if (modeSimulation) {
    switch (scenario) {
      case 0: t=25; h=60; soil=60; co2=40; ldr=50; res=80; pluie=HIGH; flamme=HIGH; break;
      case 1: t=38; h=30; soil=30; co2=70; ldr=90; res=70; pluie=HIGH; flamme=HIGH; break;
      case 2: t=33; h=25; soil=10; co2=55; ldr=85; res=20; pluie=HIGH; flamme=HIGH; break;
      case 3: t=22; h=80; soil=70; co2=30; ldr=40; res=90; pluie=LOW; flamme=HIGH; break;
      case 4: t=28; h=50; soil=40; co2=45; ldr=60; res=5;  pluie=HIGH; flamme=HIGH; break;
      case 5: t=45; h=15; soil=20; co2=95; ldr=100; res=60; pluie=HIGH; flamme=LOW; break;
    }
  }

  // AUTO
  if (modeAuto) {
    digitalWrite(POMPE, soil < 40 && pluie == HIGH);
    digitalWrite(VANNE, digitalRead(POMPE));
    digitalWrite(VENTILATEUR, (t > 28) || (co2 > 70));
    digitalWrite(CHAUFFAGE, t < 12);
    digitalWrite(OMBRAGE, ldr > 70);
  } else {
    digitalWrite(POMPE, !digitalRead(SW_POMPE));
    digitalWrite(VANNE, !digitalRead(SW_VANNE));
    digitalWrite(VENTILATEUR, !digitalRead(SW_VENT));
    digitalWrite(CHAUFFAGE, !digitalRead(SW_CHAUFF));
    digitalWrite(OMBRAGE, !digitalRead(SW_OMBRE));
  }

  // FIRE
  if (flamme == LOW) {
    digitalWrite(POMPE, LOW);
    digitalWrite(VANNE, LOW);
    digitalWrite(CHAUFFAGE, LOW);
    digitalWrite(VENTILATEUR, HIGH);
  }

  bool critique = (flamme == LOW);
  bool alarme = (res < 15 || t > 35 || soil < 20 || co2 > 80 || critique);

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
      printLine(2, "T:" + String(t) + "C S:" + String(soil));
      printLine(3, "CO2:" + String(co2) + " L:" + String(ldr));
    }

    else {

      if (screen == 1) {
        printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
        printLine(1, "Temp: " + String(t));
        printLine(2, "Hum Air: " + String(h));
        printLine(3, "Hum Sol: " + String(soil));
      }

      if (screen == 2) {
        printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
        printLine(1, "CO2: " + String(co2));
        printLine(2, "Lum: " + String(ldr));
        printLine(3, "Reserv: " + String(res));
      }

      if (screen == 3) {
        printLine(0, modeAuto ? "MODE: AUTO" : "MODE: MANUEL");
        printLine(1, "Pompe: " + String(digitalRead(POMPE)));
        printLine(2, "Vanne: " + String(digitalRead(VANNE)));
        printLine(3, "Vent: " + String(digitalRead(VENTILATEUR)));
      }
    }
  }
}