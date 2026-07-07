// -----------------------------------------------------------------------------
// config.example.h  →  copy to config.h and fill in your values.
//   cp src/config.example.h src/config.h
//
// config.h is git-ignored so your secrets never get committed.
// -----------------------------------------------------------------------------
#pragma once

// ---- WiFi -------------------------------------------------------------------
#define WIFI_SSID       "your-wifi-ssid"
#define WIFI_PASSWORD   "your-wifi-password"

// ---- ABAP REST endpoint -----------------------------------------------------
// Classic SICF example : https://host:44300/sap/ziot/ingest
// ABAP Cloud example   : https://<tenant>.abap.<region>.hana.ondemand.com/sap/bc/http/sap/ziot_ingest
#define IOT_ENDPOINT    "https://your-sap-host:44300/sap/ziot/ingest"

// Logical id for this device (becomes deviceId in the JSON payload)
#define DEVICE_ID       "esp32-coldroom-01"
// NOTE: the sensor model reported as "sensorType" is set by the build flag
// (-D SENSOR_DHT22 / SENSOR_SHT31 / SENSOR_DS18B20 in platformio.ini), not here.

// ---- Authentication ---------------------------------------------------------
// SICF services usually require Basic auth (a dedicated technical/service user).
// Leave user/pass empty for ABAP Cloud endpoints that authenticate differently.
#define BASIC_AUTH_USER "ESP32_USER"
#define BASIC_AUTH_PASS "change-me"

// Extra shared secret checked by the ABAP handler (X-API-Key header).
// Lets you rotate device credentials independently of the SAP user.
#define API_KEY         "change-me-too"

// ---- Sampling ---------------------------------------------------------------
#define SEND_INTERVAL_MS   60000UL   // one reading per minute

// ---- Sensor pins / address (set the one matching your build flag) -----------
#define DHT_PIN            4         // DHT22 data pin
#define DS18B20_PIN        4         // DS18B20 1-Wire data pin (4.7k pull-up to 3V3)
#define SHT31_ADDR         0x44      // SHT31 I2C address (0x44 default, 0x45 if ADDR->VCC)
                                     // SHT31 uses the ESP32 I2C bus: SDA=GPIO21, SCL=GPIO22

// ---- Alarm indicator --------------------------------------------------------
// The ABAP endpoint returns {"...","alarms":N}. When N>0 (a threshold was
// breached) this LED turns on. GPIO2 is the onboard LED on most ESP32 devkits;
// wire an external LED (or buzzer) here for a cold-room panel.
#define ALARM_LED_PIN      2

// ---- TLS --------------------------------------------------------------------
// For a first bring-up you can set INSECURE_TLS to 1 (skips cert validation).
// For anything beyond the lab, set it to 0 and paste your server's root CA in
// ROOT_CA_PEM below so the connection is actually authenticated.
#define INSECURE_TLS    1

static const char ROOT_CA_PEM[] = R"EOF(
-----BEGIN CERTIFICATE-----
... paste your SAP host's root CA here (PEM) ...
-----END CERTIFICATE-----
)EOF";
