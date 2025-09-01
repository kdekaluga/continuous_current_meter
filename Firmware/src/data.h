#pragma once

// 'var' should be defined to the empty string in one cpp unit to instantiate variables.
#ifndef var
#define var extern
#endif

#include <stdint.h>

// ADC interrupt internal variables
var uint16_t g_adcAccumulator;
var uint8_t g_adcSampleNumber;

// ADC result
var volatile uint16_t g_adcValue;
var volatile uint16_t g_adcValueMin;
var volatile uint16_t g_adcValueMax;

// Current tick (150 Hz)
var volatile uint16_t g_current150HzTick;

// Beep mode:
// 0: Off
// 1..63: Beep count left
// 64: Continuous beep
#define BEEP_OFF 0
#define BEEP_CONTINUOUS 64
var volatile uint8_t g_beepMode;
var uint8_t g_beepCounter;

// Overheat state:
// 0: Normal, no overheat
// 1..63 = n: (Warning temperature + n - 1) reached
// 64: Critical temperature reached
#define OVERHEAT_NONE 0
#define OVERHEAT_CRITICAL 64
var uint8_t g_overheatState;

// Packed 12 bit minimum and maximum values
struct SSample
{
    uint8_t minLsb;
    uint8_t maxLsb;
    // Bits 0-3: minimum MSB, bits 4-7: maximum MSB
    uint8_t minMaxMsb;
};

var SSample g_samples[128];
var uint16_t g_samplesMin;
var uint16_t g_samplesMax;

// Random generator shift register
var uint32_t g_rndGenState;

// Sleep
var uint8_t g_sleepTick;
var uint8_t g_sleepState;
var uint8_t g_sleepX;
var uint8_t g_sleepY;

var uint8_t g_buffer[8];
