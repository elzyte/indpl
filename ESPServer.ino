#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include "freertos/semphr.h"

const char* ssid = "Wifi Em";
const char* password = "98765432";

AsyncWebServer server(80);

int counter = 10;
int lastSentCounter = 0;
int userCount = 0;
String UserId = "";
String users[10];


void handleNameRegister(AsyncWebServerRequest* request) {
  Serial.printf("New Connection from %s - Request: %s\n",
                request->client()->remoteIP().toString().c_str(),
                request->url().c_str());

  if (request->hasParam("name", true)) {
    String name = request->getParam("name", true)->value();
    Serial.println(name);

    // Check if user is already registered
    for (int i = 0; i < userCount; i++) {
      if (users[i] == name) {
        Serial.println("Is already taken");
        AsyncWebServerResponse* response = request->beginResponse(200, "text/plain", "Username is already taken");
        response->addHeader("Access-Control-Allow-Origin", "*");  // Allow CORS
        response->addHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
        response->addHeader("Access-Control-Allow-Headers", "Content-Type");
        request->send(response);
        return;
      }
    }

    if (userCount < 10) {
      users[userCount++] = name;
      AsyncWebServerResponse* response = request->beginResponse(200, "text/plain", "User registered successfully");
      response->addHeader("Access-Control-Allow-Origin", "*");  // Allow CORS
      response->addHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
      response->addHeader("Access-Control-Allow-Headers", "Content-Type");
      request->send(response);
      Serial.printf("New user registered: %s\n", name.c_str());
      Serial.println("There are currently " + String(userCount) + " users");
    } else {
      request->send(400, "text/plain", "User limit reached");
    }
  } else {
    request->send(400, "text/plain", "Missing name parameter");
  }
}

// Check if User Exists
void handleNameCheck(AsyncWebServerRequest* request) {
  Serial.printf("📡 New Connection from %s - Request: %s\n",
                request->client()->remoteIP().toString().c_str(),
                request->url().c_str());

  if (request->hasParam("name", true)) {
    String name = request->getParam("name", true)->value();

    for (int i = 0; i < userCount; i++) {
      if (users[i] == name) {
        UserId = name.c_str();
        AsyncWebServerResponse* response = request->beginResponse(200, "text/plain", "User identified");
        response->addHeader("Access-Control-Allow-Origin", "*");  // Allow CORS
        response->addHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
        response->addHeader("Access-Control-Allow-Headers", "Content-Type");
        request->send(response);
        Serial.printf("User identified: %s\n", name.c_str());
        return;
      }
    }
    request->send(404, "text/plain", "User not found");
  } else {
    request->send(400, "text/plain", "Missing name parameter");
  }
}

void handleFetchCounter(AsyncWebServerRequest* request) {
  Serial.printf("New Connection from %s - Request: %s\n",
                request->client()->remoteIP().toString().c_str(),
                request->url().c_str());

  if (counter != lastSentCounter) {
    lastSentCounter = counter;
    AsyncWebServerResponse* response = request->beginResponse(200, "text/plain", "true");
    response->addHeader("Access-Control-Allow-Origin", "*");  // Allow CORS
    response->addHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response->addHeader("Access-Control-Allow-Headers", "Content-Type");
    request->send(response);
  } else {
    AsyncWebServerResponse* response = request->beginResponse(200, "text/plain", "false");
    response->addHeader("Access-Control-Allow-Origin", "*");  // Allow CORS
    response->addHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response->addHeader("Access-Control-Allow-Headers", "Content-Type");
    request->send(response);
  }
}

void handleIncrement(AsyncWebServerRequest* request) {
  counter++;
  Serial.println("Received request on /increment");
  AsyncWebServerResponse* response = request->beginResponse(200, "text/plain", "Counter updated");
  response->addHeader("Access-Control-Allow-Origin", "*");
  response->addHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  response->addHeader("Access-Control-Allow-Headers", "Content-Type");
  request->send(response);
}

void handleFetchUsers(AsyncWebServerRequest* request) {
    Serial.println("Fetching user list...");

    DynamicJsonDocument doc(512); // Adjust size based on user count
    JsonArray usersArray = doc.createNestedArray("users");

    for (int i = 0; i < userCount; i++) {
        usersArray.add(users[i]); // Add each user to JSON array
    }

    String responseString;
    serializeJson(doc, responseString);

    AsyncWebServerResponse* response = request->beginResponse(200, "application/json", responseString);
    response->addHeader("Access-Control-Allow-Origin", "*");  // Allow CORS
    response->addHeader("Access-Control-Allow-Methods", "GET");
    response->addHeader("Access-Control-Allow-Headers", "Content-Type");
    request->send(response);
}

void setup() {
  Serial.begin(115200);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println(" Connecting to WiFi...");
  }
  Serial.println(WiFi.localIP());
  Serial.println("Connected to WiFi!");

  // Define API routes
  server.on("/nameregister", HTTP_POST, handleNameRegister);
  server.on("/namecheck", HTTP_POST, handleNameCheck);
  server.on("/fetchcounter", HTTP_GET, handleFetchCounter);
  server.on("/increment", HTTP_POST, handleIncrement);
  server.on("/getWheelItems", HTTP_GET,handleFetchUsers);
  server.begin();
  Serial.println("Server started");
}

void loop() {
}
