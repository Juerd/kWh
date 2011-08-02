int ledstate = LOW;
unsigned long cycle = 0;

void setup () {
  Serial.begin(9600);
  pinMode(A1, INPUT);
  pinMode(13, OUTPUT);
}

unsigned long previous = 0; // timestamp
#define READINGS 50
unsigned short readings[READINGS];
byte cursor = 0;
boolean gotenough = false;

void loop () {
  delay(20);
  unsigned short sum = 0;
  for (byte i = 0; i < 20; i++) {
    sum += analogRead(1);
    delay(5);
  }
  
  readings[cursor++] = sum;
  if (cursor >= READINGS) {
    cursor = 0;
    gotenough = true;
  }
  
  if (!gotenough) {
    Serial.print("Averaging... ");
    Serial.print(cursor, DEC);
    Serial.print("/");
    Serial.println(READINGS);
    return;
  }
  
  
  unsigned long bigsum = 0;
  for (byte i = 0; i < READINGS; i++) bigsum += readings[i];
  unsigned short average = bigsum / READINGS;
  
 // Serial.println(sum);

  double ratio = (double) sum/average;
  boolean newledstate = ratio > 1.05;
// Serial.println(ratio, 2);
 
 
  if (newledstate == ledstate) return;
  
  digitalWrite(13, ledstate = newledstate);

  if (!ledstate) return;
  
  unsigned long now = millis();
  unsigned long time = now - previous;

  if (time < 1000) return;  // debounce, just in case

  previous = now;  
 
  if (!cycle++) {
    Serial.println("Discarding incomplete cycle.");
    return;
  }
  


  double W = (1000.0 * 3600000.0 / (double) time) / 375;
  Serial.print("Cycle ");
  Serial.print(cycle, DEC);
  Serial.print(", ");
  Serial.print(time, DEC);
  Serial.print(" ms, ");
  Serial.print(W, 4);
  Serial.println(" W");
  
  
}

