

void setup () {
  Serial.begin(9600);
  pinMode(A1, INPUT);
  pinMode(13, OUTPUT);
  pinMode(2, INPUT);
  digitalWrite(2, HIGH);
}

int ledstate = LOW;
unsigned long cycle = 0;
unsigned long previous = 0; // timestamp
#define READINGS  250
#define THRESHOLD   1.08
unsigned short readings[READINGS];
unsigned short cursor = 0;
boolean gotenough = false;

int hits = 0;

void loop () {
  delay(10);
  
  boolean debug = (digitalRead(2) == LOW);
  
  unsigned short sum = 0;
  for (byte i = 0; i < 40; i++) {
    sum += analogRead(1);
  }

  unsigned long bigsum = 0;
  for (unsigned short i = 0; i < READINGS; i++) bigsum += readings[i];
  unsigned short average = bigsum / READINGS;
  
  double ratio = (double) sum/average;  
  boolean newledstate = ratio > THRESHOLD;
   
  if ((!gotenough) || (!newledstate)) {
    readings[cursor++] = sum;
    if (cursor >= READINGS) {
      cursor = 0;
      gotenough = true;
    }
  }
    
  if (debug && (newledstate || !(cursor % 20))) {
    Serial.print(ratio, 2);
    Serial.print(" ");
    Serial.println(sum);
  }

  if (!gotenough) {
    if (!(cursor % 10)) {
      Serial.print("Averaging... ");
      Serial.print(cursor, DEC);
      Serial.print("/");
      Serial.println(READINGS);
    }
    return;
  }
  
  if (newledstate) hits++;
 
  if (newledstate == ledstate) return;
  
  digitalWrite(13, ledstate = newledstate);

  if (!ledstate) {
    if (1 || debug) {
      Serial.print("Marker for cycle ");
      Serial.print(cycle, DEC);
      Serial.print(": ");
      Serial.print(millis() - previous);
      Serial.print(" ms (");
      Serial.print(hits, DEC);
      Serial.println(" readings)");
    }
    hits = 0;
    return;
  }
  
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
  Serial.print(": ");
  Serial.print(time, DEC);
  Serial.print(" ms, ");
  Serial.print(W, 2);
  Serial.println(" W");
  
  
}

