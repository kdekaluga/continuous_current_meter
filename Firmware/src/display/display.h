#pragma once

#include <stdint.h>

namespace display {

enum Symbols: uint8_t
{
    SYM_0 = 0,
    SYM_1,
    SYM_2,
    SYM_3,
    SYM_4,
    SYM_5,
    SYM_6,
    SYM_7,
    SYM_8,
    SYM_9,
    SYM_UPPER,
    SYM_LOWER,
    SYM_DOT,
    SYM_DEGREE,
    SYM_A,
    SYM_SPACE,
    SYM_STAR0,
    SYM_STAR1,
    SYM_STAR2,
    SYM_STAR3,
    SYM_STAR4,
    SYM_STAR5,
};

extern "C" {

void UpdateDiagram(uint16_t newMinimum, uint16_t newMaximum);

}

void Init();
void Clear();
void DrawMainScreenBackground();
uint8_t DrawGlyph(uint8_t x, uint8_t y, uint8_t glyph);
uint8_t PrintString(uint8_t x, uint8_t y, uint8_t* buffer, uint8_t length);
uint8_t PrintCurrentX100(uint8_t x, uint8_t y, uint16_t current);
uint8_t PrintTemperatureX100(uint8_t x, uint8_t y, uint16_t temperature);

} // namespace display
