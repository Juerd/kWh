#include "TM1638.h"
#include "EEPROM.h"
#include "AnythingEEPROM.h"
#include <inttypes.h>

#define READINGS       250
#define EEPROM_OFFSET  100
#define MS_PER_HOUR    3.6e6

#define KEY_CYCLES     1 << 0
#define KEY_LOWER      1 << 1
#define KEY_UPPER      1 << 2
#define KEY_MAXWATT    1 << 3
#define KEY_RAW        1 << 4
#define KEY_RATIO      1 << 5
#define KEY_DECR       1 << 6
#define KEY_INCR       1 << 7

struct SettingsStruct {
  unsigned short cycles_per_kwh;
  unsigned char  lower_threshold;
  unsigned char  upper_threshold;
  unsigned short max_watt;
} settings;

unsigned long debounce_time;

void calc_debounce() {
  debounce_time = (1000 * ((double) MS_PER_HOUR / ((long) settings.cycles_per_kwh * settings.max_watt)));
  Serial.print("Debounce time (ms): ");
  Serial.println(debounce_time);
}

void read_settings() {
  EEPROM_readAnything(EEPROM_OFFSET, settings);
  if (settings.lower_threshold == 0xff) settings.lower_threshold = 101;
  if (settings.upper_threshold == 0xff) settings.upper_threshold = 105;
  if (settings.cycles_per_kwh == 0xffff) settings.cycles_per_kwh = 375;
  if (settings.max_watt == 0xffff) settings.max_watt = 6000;
  Serial.println("Settings: ");
  Serial.println(settings.cycles_per_kwh, DEC);
  Serial.println(settings.lower_threshold, DEC);
  Serial.println(settings.upper_threshold, DEC);
  Serial.println(settings.max_watt, DEC);
  calc_debounce();
}

void save_settings() {
  EEPROM_writeAnything(EEPROM_OFFSET, settings);
  calc_debounce();
}

TM1638 display(/*dio*/ 4, /*clk*/ 5, /*stb0*/ 3);

char idletext[9] = "--------";

void display_text (char* text, boolean keep = true) {
  display.setDisplayToString(text);
  if (keep) strcpy(idletext, text);
}

void display_numtext (unsigned short num, char* text, boolean keep = true) {
  char numstr[9] = "";
  itoa(num, numstr, 10);
  char str[9] = "        ";
  byte width = strlen(text) < 4 && settings.max_watt > 9999 ? 5 : 4;
  strcpy(&str[width - strlen(numstr)], numstr);
  strcpy(&str[width], "    ");
  strcpy(&str[8 - strlen(text)], text);
  display_text(str, keep);
}

void restore_display () {
  display_text(idletext, false);
}

void setup () {
  display_text("____    ");
  Serial.begin(57600);
  pinMode(A1, INPUT);
  pinMode(13, OUTPUT);
  pinMode(2, INPUT);
  digitalWrite(2, HIGH);
  read_settings();
}

boolean ledstate = LOW;
unsigned long cycle = 0;
unsigned long previous = 0; // timestamp

unsigned short readings[READINGS];
unsigned short cursor = 0;
boolean gotenough = false;

unsigned short hits = 0;

unsigned long restore_time = 0;
boolean settingschanged = false;
unsigned long key_debounce = 0;
  
void loop () {
//  delay(10);
  
  byte keys = display.getButtons();

  unsigned short sum = 0;
  for (byte i = 0; i < 40; i++) {
    sum += analogRead(1);
  }

  unsigned long bigsum = 0;
  for (unsigned short i = 0; i < READINGS; i++) bigsum += readings[i];
  unsigned short average = bigsum / READINGS;
  
  unsigned short ratio = (double) sum / (average+1) * 100;
  
  if (keys) {
    restore_time = millis() + 2000;
    if (!key_debounce) {
      if (keys == (KEY_CYCLES  | KEY_DECR)) --settings.cycles_per_kwh;
      if (keys == (KEY_CYCLES  | KEY_INCR)) ++settings.cycles_per_kwh;
      if (keys == (KEY_LOWER   | KEY_DECR)) --settings.lower_threshold;
      if (keys == (KEY_LOWER   | KEY_INCR)) ++settings.lower_threshold;
      if (keys == (KEY_UPPER   | KEY_DECR)) --settings.upper_threshold;
      if (keys == (KEY_UPPER   | KEY_INCR)) ++settings.upper_threshold;
      if (keys == (KEY_MAXWATT | KEY_DECR)) settings.max_watt -= 100;
      if (keys == (KEY_MAXWATT | KEY_INCR)) settings.max_watt += 100;
      if (keys & KEY_INCR || keys & KEY_DECR) {
        key_debounce = millis() + 200;
        settingschanged = true;
      }
    } else if (millis() >= key_debounce ) {
      key_debounce = 0;
    }
    if (keys & KEY_CYCLES)  display_numtext(settings.cycles_per_kwh, "CYCL", false);
    if (keys & KEY_LOWER)   display_numtext(settings.lower_threshold, " LO ", false);
    if (keys & KEY_UPPER)   display_numtext(settings.upper_threshold, " HI ", false);
    if (keys & KEY_MAXWATT) display_numtext(settings.max_watt, "TOP", false);
    if (keys & KEY_RAW)   { display.setDisplayToDecNumber(sum, 0); delay(100); }
    if (keys & KEY_RATIO) { display.setDisplayToDecNumber(ratio, 0); delay(50); }
  }
  if (restore_time && millis() >= restore_time) {
    restore_time = 0;
    if (settingschanged) {
      Serial.println("Saving settings");
      save_settings();
      settingschanged = false;
    }
    restore_display();
  }

  unsigned short lo = settings.lower_threshold;
  unsigned short hi = settings.upper_threshold;

  if (hi == 254) {
      lo = 400;
      hi = 1000;
  }

  boolean newledstate = ledstate 
    ? (ratio >  lo)
    : (ratio >= hi);

  int numleds = ratio - lo;
  if (numleds < 0) numleds = 0;
  if (numleds > 8) numleds = 8;
  unsigned long ledmask = 0xff >> 8 - numleds;
  if (newledstate) ledmask <<= 8;
  display.setLEDs(ledmask);
   
  if ((!gotenough) || (!newledstate)) {
    readings[cursor++] = sum;
    if (cursor >= READINGS) {
      cursor = 0;
      if (!gotenough) {
        gotenough = true;
        Serial.println("Done averaging");
        display_text("====    ");
      }
    }
  }

  
  if (newledstate) hits++;
 
  if (newledstate == ledstate) return;
  
  digitalWrite(13, ledstate = newledstate);

  if (!ledstate) {
    Serial.print("Marker: ");
    Serial.print(millis() - previous);
    Serial.print(" ms (");
    Serial.print(hits, DEC);
    Serial.println(" readings)");
    hits = 0;
    return;
  }
  
  unsigned long now = millis();
  unsigned long time = now - previous;

  if (time < debounce_time) return;

  previous = now;  
 
  if (!cycle++) {
    Serial.println("Discarding incomplete cycle.");
    display_text("****    ");
    return;
  }
  
  double W = 1000 * ((double) MS_PER_HOUR / time) / settings.cycles_per_kwh;
  Serial.print("Cycle ");
  Serial.print(cycle, DEC);
  Serial.print(": ");
  Serial.print(time, DEC);
  Serial.print(" ms, ");
  Serial.print(W, 2);
  Serial.println(" W");
  
  display_numtext(W, "");
}

