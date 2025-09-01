#include "assembler_defines.inc"

.global ADC_vect

ADC_vect:
    ; ~9615 times per second
    push    R30
    in      R30, (SREG)
    push    R30
    push    R31

    lds     R30, (g_adcSampleNumber)
    subi    R30, (-4)
    sts     (g_adcSampleNumber), R30
    breq    adc_update_result

    in      R30, (ADCL)
    lds     R31, (g_adcAccumulator + 0)
    add     R30, R31
    sts     (g_adcAccumulator + 0), R30

    in      R30, (ADCH)
    lds     R31, (g_adcAccumulator + 1)
    adc     R30, R31
    sts     (g_adcAccumulator + 1), R30

adc_return:
    pop     R31
    pop     R30
    out     (SREG), R30
    pop     R30

    reti

adc_update_result:
    ; ~9615/64 = ~150.2 times per second
    lds     R30, (g_adcAccumulator + 0)
    lds     R31, (g_adcAccumulator + 1)
    sts     (g_adcValue + 0), R30
    sts     (g_adcValue + 1), R31

    ; Count minimum and maximum values
    push    R18

    lds     R18, (g_adcValueMin + 0)
    cp      R30, R18
    lds     R18, (g_adcValueMin + 1)
    cpc     R31, R18
    brcc    adc_not_less

    sts     (g_adcValueMin + 0), R30
    sts     (g_adcValueMin + 1), R31

adc_not_less:
    lds     R18, (g_adcValueMax + 0)
    cp      R18, R30
    lds     R18, (g_adcValueMax + 1)
    cpc     R18, R31
    brcc    adc_not_greater

    sts     (g_adcValueMax + 0), R30
    sts     (g_adcValueMax + 1), R31

adc_not_greater:

    ; Reset the ADC accumulator
    in      R30, (ADCL)
    in      R31, (ADCH)
    sts     (g_adcAccumulator + 0), R30
    sts     (g_adcAccumulator + 1), R31

    lds     R30, (g_current150HzTick + 0)
    lds     R31, (g_current150HzTick + 1)
    adiw    R30, 1
    sts     (g_current150HzTick + 0), R30
    sts     (g_current150HzTick + 1), R31

    ; *** Beep ***
    lds     R30, (g_beepCounter)
    dec     R30
    brpl    adc_beep_continue

    lds     R31, (g_beepMode)
    dec     R31
    brmi    adc_beep_off

    ; Reload beep counter
    ldi     R30, 0x3F

    ; Don't update g_beepMode if its value is 64, otherwise decrease it
    cpse    R31, R30
    sts     (g_beepMode), R31

adc_beep_continue:
    sts     (g_beepCounter), R30

    // Set PB1 output state according to the 5th bit of g_beepCounter
    bst     R30, 5
    in      R30, (DDRB)
    bld     R30, 1
    out     (DDRB), R30

adc_beep_off:
    pop     R18
    rjmp    adc_return

