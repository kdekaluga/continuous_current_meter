#pragma once

#include <stdint.h>

namespace utils {

extern "C" {

void I16ToString(uint16_t value, uint8_t *buffer, uint8_t maxLeadingSpaces);
uint16_t CalcRmsCurrent();
uint8_t Random();

} // extern "C"

uint16_t AdcToAmperesX100(uint16_t adc);

} // namespace utils
