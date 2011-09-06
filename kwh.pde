#include "TM1638.h"

#define READINGS       250
#define LOWER_THRESHOLD  1.01
#define UPPER_THRESHOLD  1.05

#define VOLTAGE        235
#define MAX_AMPS        25
#define CYCLES_PER_KWH 375

#define MS_PER_HOUR    3.6e6
#define DEBOUNCE_TIME  (1000 * ((double) MS_PER_HOUR / ((long) CYCLES_PER_KWH * VOLTAGE * MAX_AMPS)))

TM1638 display(/*dio*/ 4, /*clk*/ 5, /*stb0*/ 3);

void setup () {
  Serial.begin(57600);
  pinMode(A1, INPUT);
  pinMode(13, OUTPUT);
  pinMode(2, INPUT);
  digitalWrite(2, HIGH);
  Serial.println(DEBOUNCE_TIME);
  display.setDisplayToString("----    ");
}

int ledstate = LOW;
unsigned long cycle = 0;
unsigned long previous = 0; // timestamp

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
  
  double ratio = (double) sum / (average+1);
  boolean newledstate = ledstate ? (ratio > LOWER_THRESHOLD) : (ratio >= UPPER_THRESHOLD);

  int numleds = ratio * 100 - 100;
  if (numleds < 0) numleds = 0;
  if (numleds > 8) numleds = 8;
  unsigned long ledmask = 0xff >> 8 - numleds;
  if (newledstate) ledmask <<= 8;
  display.setLEDs(ledmask);
   
  if ((!gotenough) || (!newledstate)) {
    readings[cursor++] = sum;
    if (cursor >= READINGS) {
      cursor = 0;
      gotenough = true;
    }
  }
    
  if (debug && ((newledstate && hits < 15) || !(cursor % 20))) {
    Serial.print(ratio, 2);
    Serial.print(" ");
    Serial.print(average);
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
  
  if (debug) Serial.println(newledstate ? "BEGIN" : "END");
  
  digitalWrite(13, ledstate = newledstate);

  if (!ledstate) {
    if (debug) {
      Serial.print("Marker: ");
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

  if (time < DEBOUNCE_TIME) return;

  previous = now;  
 
  if (!cycle++) {
    Serial.println("Discarding incomplete cycle.");
    display.setDisplayToString("====    ");
    return;
  }
  
  double W = 1000 * ((double) MS_PER_HOUR / time) / CYCLES_PER_KWH;
  Serial.print("Cycle ");
  Serial.print(cycle, DEC);
  Serial.print(": ");
  Serial.print(time, DEC);
  Serial.print(" ms, ");
  Serial.print(W, 2);
  Serial.println(" W");
  
  char numstr[9] = "";
  itoa(W, numstr, 10);
  char str[9] = "        ";
  int len = strlen(numstr);
  for (int i = 0; i < len; i++) str[(4 - len) + i] = numstr[i];
  display.setDisplayToString(str);
}

