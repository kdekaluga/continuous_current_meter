#pragma once

#define LOBYTE(n) ((n) & 0xFF)
#define HIBYTE(n) ((n) >> 8)
#define COUNTOF(n) (sizeof(n)/sizeof(n[0]))

#include <stdint.h>
#include <avr/pgmspace.h>

#include "common.h"
#include "utils.h"
#include "data.h"
#include "i2c/i2c.h"
#include "display/display.h"
