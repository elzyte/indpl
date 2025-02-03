int photo1readPin = 3;
int photo2readPin = 2;
int button1Pin = 12;
int button2Pin = 13;
int hbridge1Pin = 7;
int hbridge2Pin = 4;
int basePin = A0;
int emitterPin = A1;
int baseValue = 0;
int counter = 0;
int speed = 0;
int motorPin = 5;
int countWanted = 0;
volatile int state = 0; // Volatile for ISR communication
volatile int stateLast = 0;
volatile bool stateChanged = false; // Flag to track state changes
volatile bool countChanged = false; // Flag to track state changes


bool lastButtonReading1 = HIGH;    // if using INPUT_PULLUP
bool lastButtonReading2 = HIGH;
unsigned long lastDebounceTime1 = 0;
unsigned long lastDebounceTime2 = 0;

const unsigned long debounceDelay = 50;  // or whatever is appropriate


int motortestPin = 12;
void setup() {
   Serial.begin(1000);
   pinMode(photo1readPin, INPUT);
   pinMode(basePin, INPUT);
  pinMode(emitterPin, INPUT);
   pinMode(hbridge1Pin, OUTPUT);
   pinMode(hbridge2Pin, OUTPUT);
   pinMode(motorPin, OUTPUT);
   pinMode(photo2readPin, INPUT);
  pinMode(button1Pin, INPUT_PULLUP);
  pinMode(button2Pin, INPUT_PULLUP);

   // Attach interrupts
   attachInterrupt(digitalPinToInterrupt(photo1readPin), light, CHANGE);
   attachInterrupt(digitalPinToInterrupt(photo2readPin), light, CHANGE);
}

void loop() {
  int emitterValue = analogRead(emitterPin);
  
  //Button presses
  button1Press(lastButtonReading1, lastDebounceTime1, debounceDelay, countWanted);
  button2Press(lastButtonReading2, lastDebounceTime2, debounceDelay, countWanted);
  
      
   // Print state if it has changed
   if (stateChanged) {
       stateChanged = false; // Reset the flag
		Serial.println(emitterValue);
       // Print state message
       switch (state) {
           case 1:
               Serial.println("State is ONE");
               break;
           case 2:
               Serial.println("State is TWO");
               break;
           case 3:
               Serial.println("State is THREE");
               break;
           case 4:
               Serial.println("State is FOUR");
               Serial.print("Counter: ");
               Serial.println(counter);
               break;
       }
   }
	/*
   // Read and print other values for debugging
   int photo1Value = digitalRead(photo1readPin);
   int photo2Value = digitalRead(photo2readPin);
   baseValue = analogRead(basePin);

   Serial.println("_____");
   Serial.println(photo1Value);
   Serial.println(photo2Value);
   Serial.println(baseValue);
   */
  
  analogWrite(motorPin, speed);
  int hbridge1Value = digitalRead(hbridge1Pin);
  int speed = 0;
	if (counter < countWanted)
    {
      if (counter)
    	digitalWrite(hbridge1Pin, HIGH);
  		digitalWrite(hbridge2Pin, LOW);
  		analogWrite(motorPin, 50);
    }
  	else if(counter > countWanted)
    {
      if (counter)
      	digitalWrite(hbridge1Pin, LOW);
  		digitalWrite(hbridge2Pin, HIGH);
  		analogWrite(motorPin, 50);
    }
    else 
    {
      	digitalWrite(hbridge1Pin, LOW);
  		digitalWrite(hbridge2Pin, LOW);
      	analogWrite(motorPin, 0);
    }
   delay(1); // Small delay for serial communication
}

void light() {
   // Read pin states
   int photo1Value = digitalRead(photo1readPin);
   int photo2Value = digitalRead(photo2readPin);

   // Update state based on input pin states
   if (photo1Value == LOW && photo2Value == LOW) {
       state = 1;
   } else if (photo1Value == HIGH && photo2Value == LOW) {
       state = 2;
   } else if (photo1Value == HIGH && photo2Value == HIGH) {
       state = 3;
   } else {
       state = 4;
      if (stateLast == 1)
        counter--;
      else 
        counter++;
   }
   stateLast = state;

   // Set the flag to indicate state change
   stateChanged = true;
}

void button1Press(bool& lastButtonReading1,unsigned long& lastDebounceTime1,const unsigned long debounceDelay, int& countWanted)
{
   
  bool currentReading1 = digitalRead(button1Pin);
  // If the reading changes at all, reset the debounce timer
  if (currentReading1 != lastButtonReading1) {
    lastDebounceTime1 = millis();
  }

  // If it’s been stable longer than the debounce delay, treat it as the actual state
  if ((millis() - lastDebounceTime1) > debounceDelay) {
    static bool buttonState1 = HIGH; // tracks the "stable" button state

    // Check if we have a new stable button state
    if (currentReading1 != buttonState1) {
      buttonState1 = currentReading1;

      // Detect a rising edge: old state = LOW, new state = HIGH
      if (buttonState1 == HIGH) {
        // The button just went from pressed (LOW) to not pressed (HIGH)
        // => "RISING EDGE" detected
        countWanted += 1;
        Serial.print("Rising Edge Detected: countWanted = ");
        Serial.println(countWanted);
      }
    }
  }
  lastButtonReading1 = currentReading1;
}

void button2Press(bool& lastButtonReading2,unsigned long& lastDebounceTime2,const unsigned long debounceDelay, int& countWanted)
{
   
  bool currentReading2 = digitalRead(button2Pin);
  // If the reading changes at all, reset the debounce timer
  if (currentReading2 != lastButtonReading2) {
    lastDebounceTime2 = millis();
  }

  // If it’s been stable longer than the debounce delay, treat it as the actual state
  if ((millis() - lastDebounceTime2) > debounceDelay) {
    static bool buttonState2 = HIGH; // tracks the "stable" button state

    // Check if we have a new stable button state
    if (currentReading2 != buttonState2) {
      buttonState2 = currentReading2;

      // Detect a rising edge: old state = LOW, new state = HIGH
      if (buttonState2 == HIGH) {
        // The button just went from pressed (LOW) to not pressed (HIGH)
        // => "RISING EDGE" detected
        countWanted -= 1;
        Serial.print("Rising Edge Detected: countWanted = ");
        Serial.println(countWanted);
      }
    }
  }
  lastButtonReading2 = currentReading2;
}