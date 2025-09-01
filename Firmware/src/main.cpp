#include "includes.h"

void __attribute__((noinline)) Delay(uint16_t value)
{
    for (uint16_t i = value; i > 0; --i)
    {
        asm volatile("nop");
    }
}

void InitAdc()
{
    // Disable digital input on ADC2 and ADC3
    DIDR0 = BV(ADC2D) | BV(ADC3D);

    // Internal 2.56 V reference, disconnected from AREF,
    // Differential mode, (ADC2(PB4) - ADC3(PB3))*20
    ADMUX = BV(REFS2) | BV(REFS1) | BV(MUX2) | BV(MUX1) | BV(MUX0);

    // Set ADC clock to 16MHz/128 = 125 KHz, enable ADC and start conversion.
    // There will be ~9615 conversions per second
    ADCSRA = BV(ADEN) | BV(ADSC) | BV(ADATE) | BV(ADIE) | BV(ADPS2) | BV(ADPS1) | BV(ADPS0);
}

void InitSound()
{
    // Output frequency is 16M/(16*2*137) = 3649 Hz
    // Sound is enabled by settings the PB1 pin to output
    OCR1C = 137;
    OCR1A = 137/2;
    TCCR1 = BV(CTC1) | BV(COM1A0) | BV(CS12) | BV(CS10);
}

void ProcessTemperature(uint8_t temperature)
{
    if (temperature < TEMPERATURE_RELEASE)
    {
        g_overheatState = OVERHEAT_NONE;
        g_beepMode = BEEP_OFF;
    }
    else if (temperature >= TEMPERATURE_CRITICAL)
    {
        g_overheatState = OVERHEAT_CRITICAL;
        g_beepMode = BEEP_CONTINUOUS;
    }
    else if (temperature >= TEMPERATURE_WARNING)
    {
        uint8_t state = temperature - TEMPERATURE_WARNING + 1;
        if (state > g_overheatState)
        {
            g_overheatState = state;
            g_beepMode = state;
        }
    }
}

uint16_t RequestTemperature()
{
    // Read temperature from TMP100
    i2c::Start();
    i2c::Send3(i2c::address::TMP100 << 1, 0x01, 0x60);
    i2c::RepeatedStart();
    i2c::Send2(i2c::address::TMP100 << 1, 0x00);
    i2c::RepeatedStart();
    i2c::Send(i2c::address::TMP100 << 1 | 1);
    uint8_t temp8 = i2c::Recv(true);
    ProcessTemperature(temp8);
    uint16_t temperature = (static_cast<uint16_t>(temp8) << 8) | i2c::Recv(true);
    i2c::Stop();

    return static_cast<uint16_t>(static_cast<uint32_t>(temperature)*100 >> 8);
}

void OnSleep()
{
    if (++g_sleepTick < 10)
        return;

    g_sleepTick = 0;

    uint8_t state = g_sleepState++;

    // States 0..5 (6 states), none
    if (state < 6)
        return;

    // States 6..10 (5 states), rising star
    if (state < 11)
    {
        display::DrawGlyph(g_sleepX, g_sleepY, display::SYM_STAR1 + state - 6);
        return;
    }

    // States 11..14 (4 states), full star
    if (state < 15)
        return;

    // States 15..20 (6 states), fading star
    if (state < 21)
    {
        display::DrawGlyph(g_sleepX, g_sleepY, display::SYM_STAR0 + 20 - state);
        return;
    }

    g_sleepState = 0;

    // Acquire new star coordinates
    do
        g_sleepX = utils::Random() & 0x7F;
    while (g_sleepX > 124);
    do
        g_sleepY = utils::Random() & 0x07;
    while (g_sleepY > 6);
}

int main()
{
    // Set watchdog interval to 2 seconds
    WDTCR = BV(WDP3) | BV(WDE);

    i2c::Init();
    InitAdc();
    InitSound();

    Delay(4000);
    sei();

    // Beep once at start
    g_beepMode = 1;

    display::Init();
    display::DrawMainScreenBackground();

    uint8_t tick = *reinterpret_cast<volatile uint8_t*>(&g_current150HzTick);
    uint8_t lastValuesTick = tick + 128;
    int8_t drawState = 0;

    uint16_t rmsCurrent;
    uint16_t temperature;

    constexpr uint16_t minSleepCurrent = (static_cast<uint32_t>(MIN_SLEEP_CURRENT)*65536/ADC_MULT) + ADC_OFFSET;
    int16_t sleepCounter = 0;

    for (;;)
    {
        // Reset watchdog
        asm volatile ("WDR");

        uint8_t newTick = *reinterpret_cast<volatile uint8_t*>(&g_current150HzTick);
        uint8_t delta = newTick - tick;
        if (delta < 3)
            continue;

        // We are here ~50 times a second, thus we have about 320K cycles to do everything
        tick = newTick;

        cli();
        uint16_t adcValueMin = g_adcValueMin;
        uint16_t adcValueMax = g_adcValueMax;
        //uint16_t adcValue = g_adcValue;
        g_adcValueMin = 0xFFFF;
        g_adcValueMax = 0x0000;
        sei();

        // Are we in the sleep mode?
        if (sleepCounter < 0)
        {
            // Exit sleep mode
            if (adcValueMax >= minSleepCurrent)
            {
                display::DrawMainScreenBackground();
                sleepCounter = 0;
                lastValuesTick = tick + 128;
                drawState = 0;
                continue;
            }

            // Continue requesting temperature in the sleep mode, so we can properly control the beeper
            RequestTemperature();
            OnSleep();
            continue;
        }

        if (adcValueMax < minSleepCurrent)
        {
            // Enter sleep mode
            if (++sleepCounter >= SLEEP_TIMER*50)
            {
                display::Clear();
                sleepCounter = -1;
                g_sleepState = 0;
                g_sleepTick = 0;
                continue;
            }
        }
        else
        {
            sleepCounter = 0;
        }

        // UpdateDiagram is considered to take ~256K cycles, so we have ~64K cycles left
        display::UpdateDiagram(utils::AdcToAmperesX100(adcValueMin), utils::AdcToAmperesX100(adcValueMax));
        
        uint8_t valuesDelta = newTick - lastValuesTick;
        if (valuesDelta < 21)
            continue;

        switch (drawState++)
        {
        case 0:
            display::PrintCurrentX100(10, 0, g_samplesMax);
            break;

        case 1:
            display::PrintCurrentX100(10, 2, g_samplesMin);
            break;

        case 2:
            // I don't need the instantaneous current value because it's not informative for a
            // treadmill, so I print the RMS current value instead. This is done in two steps
            // to balance the CPU load.
            //display::PrintCurrentX100(74, 0, utils::AdcToAmperesX100(adcValue));
            rmsCurrent = utils::CalcRmsCurrent();
            break;

        case 3:
            display::PrintCurrentX100(74, 0, rmsCurrent);
            break;

        case 4:
            temperature = RequestTemperature();
            // Request a random number to keep random generator working so that
            // the result would be truly random when you really need it.
            utils::Random();
            break;

        case 5:
            display::PrintTemperatureX100(76, 2, temperature);
            
            drawState = 0;
            lastValuesTick = newTick;
            break;
        }

    } // for (;;)
}
