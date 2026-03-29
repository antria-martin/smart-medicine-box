//--------version 4 with taken logs with timestamps irrespective of schedules time--------//lcd gives realt time. //reminders and scheduels work

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <Wire.h>
#include "RTClib.h"   
#include <LiquidCrystal_I2C.h>
#include <time.h>

// ---------------- WIFI & FIREBASE ----------------
#define WIFI_SSID "Hotspot_name"
#define WIFI_PASSWORD "hotspot_pass"
#define API_KEY "api_key"
#define DATABASE_URL "database_url"
#define USER_UID "uid"

// -------------- PIN CONFIG ------------
#define BUTTON_PIN 23
#define TRIG1 32
#define ECHO1 4
#define TRIG2 25
#define ECHO2 26
#define TRIG3 27
#define ECHO3 14
#define LED1 19
#define LED2 18
#define LED3 13
#define BUZZER 33

// ------- Objects -------
LiquidCrystal_I2C lcd(0x27, 16, 2); 
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
RTC_DS3231 rtc;

// ------- State Variables -------
String basePath = "/users/" + String(USER_UID) + "/patients/dominic/";
unsigned long lastRealtimeUpdate = 0;
const unsigned long ultrasonicInterval = 5000; 

bool slotActive = false;
String activeSlot = "";
int scheduledTotalMinutes = 0;
int lastCheckedMinute = -1;
int currentFlag = 0;
bool pillTakenRecently = false;
unsigned long pillTakenMsgMillis = 0;

// 1 = Pill Present, 0 = Pill Removed
int lastMState = 1, lastNState = 1, lastEState = 1;

const long gmtOffset_sec = 19800; // IST: 5.5 hours * 3600 seconds
const int daylightOffset_sec = 0; // India does not use Daylight Savings

bool snoozePressed = false;
bool manualConfirmed = false;

unsigned long manualConfirmMillis = 0;
const unsigned long confirmRecheckDelay = 120000; // 2 minutes
bool pillStillPresentMessageShown = false;
// ---------------------------------------
// Helper: Beep Pattern
// ---------------------------------------
/*void beep(int count) {
  Serial.printf("[Buzzer] Beeping %d times\n", count);
  for (int i = 0; i < count; i++) {
    digitalWrite(BUZZER, HIGH);
    delay(200);
    digitalWrite(BUZZER, LOW);
    delay(200);
  }
}
*/

void beepPattern(int count, int onTime, int offTime) {
  Serial.printf("[Buzzer] Pattern: %d beeps (%dms ON / %dms OFF)\n", count, onTime, offTime);

  for (int i = 0; i < count; i++) {
    digitalWrite(BUZZER, HIGH);
    delay(onTime);
    digitalWrite(BUZZER, LOW);
    delay(offTime);
  }
}

void continuousBuzz(unsigned long durationMs) {
  unsigned long start = millis();

  while (millis() - start < durationMs) {

    // If button pressed → stop immediately
    if (digitalRead(BUTTON_PIN) == LOW) {
      Serial.println("[SNOOZE] Button pressed during buzz.");
      snoozePressed = true;
      digitalWrite(BUZZER, LOW);
      return;  // Exit immediately
    }

    digitalWrite(BUZZER, HIGH);
    delay(250);

    digitalWrite(BUZZER, LOW);
    delay(200);
  }
}

long readUltrasonic(int trig, int echo) {
  digitalWrite(trig, LOW);
  delayMicroseconds(2);
  digitalWrite(trig, HIGH);
  delayMicroseconds(10);
  digitalWrite(trig, LOW);
  long duration = pulseIn(echo, HIGH, 30000);
  return duration * 0.034 / 2;
}

void sendRealtimeStatus() {
  int mStatus = (readUltrasonic(TRIG1, ECHO1) > 3) ? 1 : 0;
  int nStatus = (readUltrasonic(TRIG2, ECHO2) > 3) ? 1 : 0;
  int eStatus = (readUltrasonic(TRIG3, ECHO3) > 3) ? 1 : 0;

// Get current time from RTC inside this function scope
  DateTime now = rtc.now();

  FirebaseJson json;
  json.set("Morning", mStatus);
  json.set("Noon", nStatus);
  json.set("Evening", eStatus);
// Sending as a 64-bit integer (long long) is better for Firebase 
  // than String concatenation to avoid parsing issues in Flutter
  long long timestampMs = (long long)now.unixtime() * 1000;
  json.set("lastUpdate", timestampMs);

  if (Firebase.RTDB.setJSON(&fbdo, basePath + "realtimeStatus", &json)) {
    Serial.println("[Firebase] Real-time inventory status synced.");
  } else {
    Serial.printf("[Firebase] Status Update Failed: %s\n", fbdo.errorReason().c_str());
  }
}

void updateCommandNode(int flag, int late, String slot) {
  FirebaseJson json;
  json.set("flagLevel", flag);
  json.set("minutesLate", late);
  json.set("slot", slot);
  json.set("ringBuzzer", false);
  
  if (Firebase.RTDB.setJSON(&fbdo, basePath + "commands", &json)) {
    Serial.printf("[Firebase] Command Updated: Flag %d, %d min late\n", flag, late);
  }
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n--- System Booting ---");

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(TRIG1, OUTPUT); pinMode(ECHO1, INPUT);
  pinMode(TRIG2, OUTPUT); pinMode(ECHO2, INPUT);
  pinMode(TRIG3, OUTPUT); pinMode(ECHO3, INPUT);
  pinMode(LED1, OUTPUT); pinMode(LED2, OUTPUT); pinMode(LED3, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcd.print("Smart MedBox");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");

  if (!rtc.begin()) { 
    Serial.println("[Error] RTC Module NOT found!"); 
    while(1); 
  }
  Serial.println("[RTC] Connected successfully.");

  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) { 
    delay(500); 
    Serial.print(".");
  }
  Serial.println("\n[WiFi] Connected!");

  // --- START NTP SYNC BLOCK ---
  Serial.println("[NTP] Syncing time...");
  configTime(gmtOffset_sec, daylightOffset_sec, "pool.ntp.org", "time.nist.gov");

  struct tm timeinfo;
  int retry = 0;
  const int maxRetries = 20; // Increased slightly for better reliability
  
  while (!getLocalTime(&timeinfo) && retry < maxRetries) {
    Serial.print(".");
    delay(500);
    retry++;
  }

  if (retry < maxRetries) {
    // Save IST time to the physical RTC hardware
    rtc.adjust(DateTime(timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday, 
                        timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec));
    Serial.println("\n[RTC] Time synchronized with NTP.");
  } else {
    Serial.println("\n[Error] NTP sync failed. Keeping previous RTC time.");
  }
  // --- END NTP SYNC BLOCK ---

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = "caregiver@demo.com";
  auth.user.password = "123456";
  
  Serial.println("[Firebase] Initializing connection...");
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  lcd.clear();
  Serial.println("--- System Ready ---");
}

unsigned long lastBuzzerCheck = 0;
const unsigned long buzzerInterval = 2000; 

void loop() {

Serial.print("M: ");
Serial.print(readUltrasonic(TRIG1, ECHO1));

Serial.print(" | N: ");
Serial.print(readUltrasonic(TRIG2, ECHO2));

Serial.print(" | E: ");
Serial.println(readUltrasonic(TRIG3, ECHO3));

delay(500);


  //DateTime now = rtc.now();


// Create an IST version for LCD and Schedule Triggering
  // UTC + 5 hours, 30 minutes
 // DateTime ist = now + TimeSpan(0, 5, 30, 0);

  DateTime ist = rtc.now();

  int currentTotalMinutesIST = ist.hour() * 60 + ist.minute();
    
// 1. Display Time (12-hour format with AM/PM)
  lcd.setCursor(0, 0);
  char timeBuf[16];
  
  int hour12 = ist.hour();
  String ampm = (hour12 >= 12) ? "PM" : "AM";
  
  hour12 = hour12 % 12;
  if (hour12 == 0) hour12 = 12; // Handle Midnight (0) and Noon (12) correctly

  sprintf(timeBuf, "Time: %02d:%02d %s", hour12, ist.minute(), ampm.c_str());
  lcd.print(timeBuf);

  // 2. Periodic Firebase Updates (Real-time Inventory)
  if (millis() - lastRealtimeUpdate > ultrasonicInterval) {
    sendRealtimeStatus();
    lastRealtimeUpdate = millis();
  }

  // 3. Periodic Remote Command Check
  if (millis() - lastBuzzerCheck > buzzerInterval) {
    checkRemoteBuzzer();
    lastBuzzerCheck = millis();
  }

  // 4. Constant Pill Monitoring (Works even without schedule)
  // This detects the "Edge" (moment pill is removed)
  checkSlotRemoval("Morning", TRIG1, ECHO1, LED1, lastMState);
  checkSlotRemoval("Noon",    TRIG2, ECHO2, LED2, lastNState);
  checkSlotRemoval("Evening", TRIG3, ECHO3, LED3, lastEState);

  // 5. Minute-based Schedule Triggering
  if (ist.minute() != lastCheckedMinute) {
    checkAndTriggerSchedule("Morning", LED1, currentTotalMinutesIST);
    checkAndTriggerSchedule("Noon", LED2, currentTotalMinutesIST);
    checkAndTriggerSchedule("Evening", LED3, currentTotalMinutesIST);
    lastCheckedMinute = ist.minute();
  }

  // 6. Active Alert & Escalation Logic
  //if (slotActive) {
  if (slotActive && !manualConfirmed) {
    int late = currentTotalMinutesIST - scheduledTotalMinutes;
    int targetLed = (activeSlot == "Morning") ? LED1 : (activeSlot == "Noon" ? LED2 : LED3);

    // Keep LED on for the active slot
    digitalWrite(targetLed, HIGH); 

    // Escalation Stages
    if (late >= 1 && late < 2 && currentFlag < 1) {
      currentFlag = 1;
      updateCommandNode(1, late, activeSlot);
      lcd.setCursor(0, 1); lcd.print("Reminder One   ");
      //beep(2); 
      continuousBuzz(3000);
    } else if (late >= 2 && late < 3 && currentFlag < 2) {
      currentFlag = 2;
      updateCommandNode(2, late, activeSlot);
      lcd.setCursor(0, 1); lcd.print("Reminder Two   ");
      //beep(3);
      continuousBuzz(3000);  // 3 seconds of pulsing
    } else if (late >= 3 && currentFlag < 3) {
      currentFlag = 3;
      updateCommandNode(3, late, activeSlot);
      lcd.setCursor(0, 1); lcd.print("Reminder Three ");
      //beep(3); 
      continuousBuzz(5000);  // 5 seconds of pulsing
    }

    if (late >= 5) { // If 10 minutes have passed without the pill being removed
    logDoseMissed(activeSlot);
}

  }

// ---- Manual Confirmation Safety Check ----
if (slotActive && manualConfirmed) {

  unsigned long elapsed = millis() - manualConfirmMillis;

  // 🔹 1-Minute Warning
  if (elapsed >= 60000 && !pillStillPresentMessageShown) {

    int currentState;

    if (activeSlot == "Morning")
      currentState = (readUltrasonic(TRIG1, ECHO1) > 3) ? 1 : 0;
    else if (activeSlot == "Noon")
      currentState = (readUltrasonic(TRIG2, ECHO2) > 3) ? 1 : 0;
    else
      currentState = (readUltrasonic(TRIG3, ECHO3) > 3) ? 1 : 0;

    if (currentState == 1) {
      lcd.setCursor(0, 1);
      lcd.print("Pill Not Taken ");
      delay(3000);

      lcd.setCursor(0, 1);
      lcd.print("                "); // clear line
      Serial.println("[LCD] Pill still present after 1 min.");
    }

    pillStillPresentMessageShown = true;
  }

  // 🔹 2-Minute Final Check
  if (elapsed >= 120000) {

    Serial.println("[Safety Check] Rechecking pill presence...");

    int currentState;

    if (activeSlot == "Morning")
      currentState = (readUltrasonic(TRIG1, ECHO1) > 3) ? 1 : 0;
    else if (activeSlot == "Noon")
      currentState = (readUltrasonic(TRIG2, ECHO2) > 3) ? 1 : 0;
    else
      currentState = (readUltrasonic(TRIG3, ECHO3) > 3) ? 1 : 0;

    if (currentState == 0) {
      Serial.println("[Safety Check] Pill removed. Logging taken.");
      logDoseTaken(activeSlot, 0);
    } /*else {
      Serial.println("[Safety Alert] Pill still detected! Restarting alarm.");
      manualConfirmed = false;
      currentFlag = 0;
      pillStillPresentMessageShown = false;
      continuousBuzz(5000);
    }*/
    else {
  Serial.println("[Safety Alert] Pill still detected! Restarting alarm.");

  manualConfirmed = false;
  pillStillPresentMessageShown = false;

  // 🔁 Properly restart escalation from Stage 1
  currentFlag = 1;  // We are now in Reminder One stage again

  int targetLed = (activeSlot == "Morning") ? LED1 :
                  (activeSlot == "Noon") ? LED2 : LED3;

  digitalWrite(targetLed, HIGH);

  lcd.setCursor(0, 1);
  lcd.print("Reminder One   ");

  updateCommandNode(1, 0, activeSlot);

  continuousBuzz(5000);
}
  }
}

  // 7. Physical Button Override
/*  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("[Input] Physical Reset Button Pressed.");
    digitalWrite(BUZZER, LOW);
    digitalWrite(LED1, LOW); digitalWrite(LED2, LOW); digitalWrite(LED3, LOW);
    
    // If the button is pressed while an alarm is active, we treat it as "Taken" 
    // but note that the ultrasonic sensors will still log a 0 if the pill remains.
    if (slotActive) logDoseTaken(activeSlot, 0); 
    delay(500); 
  }*/
if (digitalRead(BUTTON_PIN) == LOW) {

  Serial.println("[Input] Manual Confirmation Button Pressed");

  digitalWrite(BUZZER, LOW);
  digitalWrite(LED1, LOW);
  digitalWrite(LED2, LOW);
  digitalWrite(LED3, LOW);

  if (slotActive) {

    manualConfirmed = true;
    manualConfirmMillis = millis();
    pillStillPresentMessageShown = false;

    lcd.setCursor(0, 1);
    lcd.print("Confirming...   ");
    delay(3000);

    lcd.setCursor(0, 1);
    lcd.print("                "); // clear line
  }

  delay(500);
}

  // 8. LCD Feedback Handling
  if (pillTakenRecently) {
    lcd.setCursor(0, 1);
    lcd.print("Pill Taken!     ");
    if (millis() - pillTakenMsgMillis > 3000) pillTakenRecently = false;
  } else if (!slotActive) {
    lcd.setCursor(0, 1);
    lcd.print("System Ready    ");
  }

  delay(200);
}

// New Helper Function to detect the moment a pill is removed
void checkSlotRemoval(String slot, int trig, int echo, int led, int &lastState) {
  int currentState = (readUltrasonic(trig, echo) > 3) ? 1 : 0; //<=2

  // If it was present (1) and now it's gone (0)
  if (lastState == 1 && currentState == 0) {
    logDoseTaken(slot, led);
  }
  lastState = currentState;
}

void checkAndTriggerSchedule(String slot, int ledPin, int currentTotal) {
  if (Firebase.RTDB.getString(&fbdo, basePath + "schedule/" + slot + "/time")) {
    String sTime = fbdo.stringData();
    int sMin = sTime.substring(0,2).toInt() * 60 + sTime.substring(3,5).toInt();
    
    if (currentTotal == sMin) {
      Serial.printf("[Schedule] Triggered for %s at %s\n", slot.c_str(), sTime.c_str());
      slotActive = true;
      activeSlot = slot;
      scheduledTotalMinutes = sMin;
      currentFlag = 0;
      digitalWrite(ledPin, HIGH);
      /*digitalWrite(BUZZER, HIGH);
      delay(1000);
      digitalWrite(BUZZER, LOW);*/
      continuousBuzz(5000);  // 5 seconds of pulsing 
    }
  }
}

void checkRemoteBuzzer() {
  if (Firebase.RTDB.getBool(&fbdo, basePath + "commands/ringBuzzer")) {
    if (fbdo.dataType() == "boolean") {
      bool shouldRing = fbdo.boolData();
      if (shouldRing) {
        Serial.println("[Firebase] Remote Buzz Command: ON");
        digitalWrite(BUZZER, HIGH);
      } else {
        if (!slotActive) digitalWrite(BUZZER, LOW);
      }
    }
  }
}

void logDoseTaken(String slot, int ledPin) {

  Serial.printf("[System] Logging 'Taken' for: %s\n", slot.c_str());
  if (ledPin != 0) digitalWrite(ledPin, LOW);
  
  DateTime now = rtc.now(); // UTC for the database
  char dateBuf[12];
  sprintf(dateBuf, "%04d-%02d-%02d", now.year(), now.month(), now.day());
  
  FirebaseJson log;
  log.set("status", "Taken");
  
  // Clean UTC Milliseconds
  long long timestampMs = (long long)now.unixtime() * 1000;
  log.set("timestamp", timestampMs);

  Firebase.RTDB.setJSON(&fbdo, basePath + "logs/" + String(dateBuf) + "/" + slot, &log);

  if (slotActive && activeSlot == slot) {
    digitalWrite(BUZZER, LOW);
    updateCommandNode(0, 0, ""); 
    manualConfirmed = false;
    slotActive = false;
    pillTakenRecently = true;
    pillTakenMsgMillis = millis();
  }
}

void logDoseMissed(String slot) {
  Serial.printf("[System] Logging 'Missed' for: %s\n", slot.c_str());
  
  DateTime now = rtc.now();
  char dateBuf[12];
  sprintf(dateBuf, "%04d-%02d-%02d", now.year(), now.month(), now.day());
  
  FirebaseJson log;
  log.set("status", "Missed"); // This is what your Flutter app is looking for
  log.set("timestamp", (long long)now.unixtime() * 1000);

  Firebase.RTDB.setJSON(&fbdo, basePath + "logs/" + String(dateBuf) + "/" + slot, &log);

  // Reset system
  slotActive = false;
  digitalWrite(BUZZER, LOW);
  digitalWrite(LED1, LOW); digitalWrite(LED2, LOW); digitalWrite(LED3, LOW);
  updateCommandNode(0, 0, ""); 
}
