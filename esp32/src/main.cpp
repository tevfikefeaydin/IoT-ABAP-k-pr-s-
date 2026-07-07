// -----------------------------------------------------------------------------
// ESP32 → ABAP REST IoT bridge — firmware
//
// Reads temperature/humidity from a sensor and POSTs a JSON reading to an ABAP
// REST endpoint (classic SICF handler or modern ABAP Cloud HTTP service).
//
// Sensor is selected at BUILD TIME via a flag in platformio.ini:
//     -D SENSOR_DHT22     (default)  temp + humidity, cheap
//     -D SENSOR_SHT31                temp + humidity, I2C, cold-room grade
//     -D SENSOR_DS18B20              temp only, waterproof probe
//
// Flow:  WiFi connect → NTP sync → loop{ read sensor → build JSON → HTTPS POST }
//
// Payload (camelCase so /ui2/cl_json pretty_mode=camel_case maps it 1:1):
//   { "deviceId", "sensorType", "temperature", "humidity"?, "recordedAt"? }
//   humidity is omitted for temperature-only sensors (DS18B20).
// -----------------------------------------------------------------------------
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include "config.h"

// ---- sensor selection ------------------------------------------------------
#if !defined(SENSOR_DHT22) && !defined(SENSOR_SHT31) && !defined(SENSOR_DS18B20)
  #define SENSOR_DHT22   // default when no build flag is set
#endif

#if defined(SENSOR_DHT22)
  #include <DHT.h>
  static DHT dht(DHT_PIN, DHT22);
  static const char* SENSOR_MODEL = "DHT22";
#elif defined(SENSOR_SHT31)
  #include <Wire.h>
  #include <Adafruit_SHT31.h>
  static Adafruit_SHT31 sht31 = Adafruit_SHT31();
  static const char* SENSOR_MODEL = "SHT31";
#elif defined(SENSOR_DS18B20)
  #include <OneWire.h>
  #include <DallasTemperature.h>
  static OneWire oneWire(DS18B20_PIN);
  static DallasTemperature ds18b20(&oneWire);
  static const char* SENSOR_MODEL = "DS18B20";
#endif

// ---- sensor abstraction ----------------------------------------------------

static void sensorSetup() {
#if defined(SENSOR_DHT22)
  dht.begin();
#elif defined(SENSOR_SHT31)
  Wire.begin();
  if (!sht31.begin(SHT31_ADDR)) {
    Serial.println("[sht31] not found — check I2C wiring / address");
  }
#elif defined(SENSOR_DS18B20)
  ds18b20.begin();
#endif
  Serial.printf("[sensor] model=%s\n", SENSOR_MODEL);
}

// Reads temperature (°C) and humidity (%). humidity is set to NAN for
// temperature-only sensors. Returns false on a failed read.
static bool sensorRead(float& temperature, float& humidity) {
#if defined(SENSOR_DHT22)
  temperature = dht.readTemperature();
  humidity    = dht.readHumidity();
  return !(isnan(temperature) || isnan(humidity));
#elif defined(SENSOR_SHT31)
  temperature = sht31.readTemperature();
  humidity    = sht31.readHumidity();
  return !(isnan(temperature) || isnan(humidity));
#elif defined(SENSOR_DS18B20)
  ds18b20.requestTemperatures();
  temperature = ds18b20.getTempCByIndex(0);   // -127 (DEVICE_DISCONNECTED_C) on error
  humidity    = NAN;
  return temperature > -100.0f;
#endif
}

// ---- helpers ---------------------------------------------------------------

static void connectWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.printf("[wifi] connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[wifi] connected, ip=%s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("[wifi] FAILED — will retry next cycle");
  }
}

// Sync clock via NTP so we can send a real ISO-8601 timestamp (recordedAt).
static void syncTime() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");  // UTC
  Serial.print("[time] waiting for NTP");
  time_t now = time(nullptr);
  uint32_t start = millis();
  while (now < 1700000000 && millis() - start < 15000) {  // ~2023-11 sanity floor
    delay(300);
    Serial.print('.');
    now = time(nullptr);
  }
  Serial.println();
}

// Returns "2026-07-07T10:20:30Z" (UTC). Empty string if the clock isn't set —
// in that case the ABAP side falls back to its own server timestamp.
static String isoTimestamp() {
  time_t now = time(nullptr);
  if (now < 1700000000) return String("");
  struct tm t;
  gmtime_r(&now, &t);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &t);
  return String(buf);
}

// Build the JSON body for one reading.
static String buildPayload(float temperature, float humidity) {
  JsonDocument doc;
  doc["deviceId"]    = DEVICE_ID;
  doc["sensorType"]  = SENSOR_MODEL;
  doc["temperature"] = serialized(String(temperature, 2));  // 2 decimals, no quotes
  if (!isnan(humidity)) {
    doc["humidity"] = serialized(String(humidity, 2));      // omit for temp-only sensors
  }
  String ts = isoTimestamp();
  if (ts.length()) doc["recordedAt"] = ts;
  String out;
  serializeJson(doc, out);
  return out;
}

// POST the payload. Returns the HTTP status code (<0 on transport error).
static int postReading(const String& payload) {
  WiFiClientSecure client;
#if INSECURE_TLS
  client.setInsecure();  // lab only — do NOT ship like this
#else
  client.setCACert(ROOT_CA_PEM);
#endif

  HTTPClient http;
  if (!http.begin(client, IOT_ENDPOINT)) {
    Serial.println("[http] begin() failed");
    return -1;
  }
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-API-Key", API_KEY);
  if (strlen(BASIC_AUTH_USER) > 0) {
    http.setAuthorization(BASIC_AUTH_USER, BASIC_AUTH_PASS);
  }
  http.setTimeout(10000);

  int code = http.POST(payload);
  if (code > 0) {
    String resp = http.getString();
    Serial.printf("[http] %d  resp=%s\n", code, resp.c_str());
    // Server reports breaches as {"...","alarms":N}. Light the LED when N>0.
    if (code == 201) {
      bool alarm = resp.indexOf("\"alarms\":") >= 0 &&
                   resp.indexOf("\"alarms\":0") < 0;
      digitalWrite(ALARM_LED_PIN, alarm ? HIGH : LOW);
      if (alarm) Serial.println("[alarm] threshold breached — LED on");
    }
  } else {
    Serial.printf("[http] transport error: %s\n", http.errorToString(code).c_str());
  }
  http.end();
  return code;
}

// ---- Arduino entry points --------------------------------------------------

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n[boot] ESP32 → ABAP IoT bridge");
  pinMode(ALARM_LED_PIN, OUTPUT);
  digitalWrite(ALARM_LED_PIN, LOW);
  sensorSetup();
  connectWifi();
  syncTime();
}

void loop() {
  connectWifi();  // reconnect if the link dropped

  float temperature = NAN, humidity = NAN;
  if (!sensorRead(temperature, humidity)) {
    Serial.println("[sensor] read failed — skipping this cycle");
  } else {
    String payload = buildPayload(temperature, humidity);
    Serial.printf("[send] %s\n", payload.c_str());
    postReading(payload);
  }

  delay(SEND_INTERVAL_MS);
}
