#include "includes.h"

namespace utils {

uint16_t AdcToAmperesX100(uint16_t adc)
{
    uint32_t value = static_cast<uint32_t>(adc > ADC_OFFSET ? adc - ADC_OFFSET : 0)*ADC_MULT;
    uint16_t value16 = static_cast<uint16_t>(value >> 16);
    if (value16 < MIN_CURRENT_THRESHOLD)
        return 0;
        
    return value16 < MAX_ALLOWED_CURRENT ? value16 : MAX_ALLOWED_CURRENT;
}

} // namespace utils
