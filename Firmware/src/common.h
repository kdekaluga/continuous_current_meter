#pragma once

#include <avr/io.h>
#include <avr/interrupt.h>

// Bit value
#define BV(n) (1 << n)

// Pins
#define PIN_SDA 0
#define PIN_SCL 2

// CPU speed in kilohertz
#define CPU_SPEED_KHZ 16000

// I2C speed in kilohertz
#define I2C_SPEED_KHZ 400
//#define I2C_MAX_SPEED

// Calibration
#define MAX_ALLOWED_CURRENT 2047
#define MIN_CURRENT_THRESHOLD 0
#define ADC_OFFSET 775
#define ADC_MULT 2402

#define MIN_SLEEP_CURRENT 50
#define SLEEP_TIMER 60

// Temperature
#define TEMPERATURE_CRITICAL 70
#define TEMPERATURE_WARNING 65
#define TEMPERATURE_RELEASE 60
