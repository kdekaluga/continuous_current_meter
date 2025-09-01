#include "../assembler_defines.inc"

.global UpdateDiagram

ud_dc_data:
    .byte   0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01

ud_init_data:
    .byte   0x3C*2, 0, 0x21, 0, 127, 0x22, 4, 7

; void UpdateDiagram(uint16_t newMinimum, uint16_t newMaximum)
UpdateDiagram:
    ; R25:R24 = newMinimum
    ; R23:R22 = newMaximum

    ; Pack and save new values to the end of the samples array
    sts     (g_samples + 127*3 + 0), R24
    sts     (g_samples + 127*3 + 1), R22
    mov     R18, R23
    swap    R18
    or      R18, R25
    sts     (g_samples + 127*3 + 2), R18

    ; Calculate minimum and maximum values and shift the data
    ldi     ZL, lo8(g_samples)
    ldi     ZH, hi8(g_samples)

    ; R25:R24 = min value
    ; R23:R22 = max value

ud_minmax:
    ; Check and copy minimum value
    ldd     R26, Z + 3
    std     Z + 0, R26
    ldd     R27, Z + 5
    std     Z + 2, R27
    andi    R27, 0x0F

    cp      R26, R24
    cpc     R27, R25
    brcc    ud_no_min
    movw    R24, R26

ud_no_min:
    ; Check and copy maximum value
    ldd     R26, Z + 4
    std     Z + 1, R26
    ldd     R27, Z + 5
    swap    R27
    andi    R27, 0x0F

    cp      R22, R26
    cpc     R23, R27
    brcc    ud_no_max
    movw    R22, R26

ud_no_max:
    adiw    Z, 3

    ; It's safe to check only ZL here
    cpi     ZL, lo8(g_samples + 127*3)
    brne    ud_minmax
    ; 30c per iteration, 30*128 = 3840c total

    sts     (g_samplesMin + 0), R24
    sts     (g_samplesMin + 1), R25
    sts     (g_samplesMax + 0), R22
    sts     (g_samplesMax + 1), R23

    movw    R20, R24
    movw    R26, R22
    sub     R26, R20
    sbc     R27, R21

    ; Minimum delta is 32
    cpi     R26, 32
    cpc     R27, R1
    brcc    ud_delta_big_enough
    ldi     R26, 32

ud_delta_big_enough:
    ; R21:R20 = min value
    ; R27:R26 = (max - min) = delta

    swap    R26
    swap    R27
    eor     R27, R26
    andi    R26, 0xF0
    eor     R27, R26
    ; R27:R26 = delta*16

    rcall   Start
    ldi     R24, lo8(ud_init_data)
    ldi     R25, hi8(ud_init_data)
    ldi     R22, 8
    rcall   SendPM

    rcall   RepeatedStart
    ldi     R24, 0x3C*2
    ldi     R22, 0x40
    rcall   Send2

    ; *** Draw diagram ***
    MPUSH   14, 17
    MPUSH   28, 29
    ldi     YL, lo8(g_samples)
    ldi     YH, hi8(g_samples)

ud_draw:
    ldd     R24, Y + 0
    ldd     R25, Y + 2
    andi    R25, 0x0F
    sub     R24, R20
    sbc     R25, R21
    ; R25:R24 = (v[i].min - minimum)

    rcall   ud_mul31_div_delta
    rcall   ud_draw_column
    movw    R14, R22
    movw    R16, R24

    ldd     R24, Y + 1
    ldd     R25, Y + 2
    swap    R25
    andi    R25, 0x0F
    sub     R24, R20
    sbc     R25, R21
    ; R25:R24 = (v[i].max - minimum)

    rcall   ud_mul31_div_delta
    inc     R24
    cpi     R24, 31
    brcc    ud_max_max
    rcall   ud_draw_column

    com     R22
    com     R23
    com     R24
    com     R25
    and     R14, R22
    and     R15, R23
    and     R16, R24
    and     R17, R25

ud_max_max:
    mov     R24, R17
    rcall   Send
    mov     R24, R16
    rcall   Send
    mov     R24, R15
    rcall   Send
    mov     R24, R14
    rcall   Send

    adiw    Y, 3
    cpi     YL, lo8(g_samples + 128*3)
    brne    ud_draw
    ; ~37c + 2*mul + 2*draw ~= 251c per iteration without data sending

    rcall   Stop

    MPOP    28, 29
    MPOP    14, 17
    ret

; Calculates value*31/delta
; Uses R18, R19, R22, R23, R24, R25
ud_mul31_div_delta:
    ; R25:R24 = 11-bit value (0 - 2047)
    ; R27:R26 = delta*16
    movw    R22, R24
    swap    R22
    swap    R23
    eor     R23, R22
    andi    R22, 0xF0
    eor     R23, R22
    lsl     R22
    rol     R23
    ; R23:R22 = R25:R24*32

    sub     R22, R24
    sbc     R23, R25
    ; R23:R22 = R25:R24*31, 10c

    ldi     R25, 5
    ldi     R24, 0xFF
    movw    R18, R26

ud_m31dd_1:
    sub     R22, R18
    sbc     R23, R19
    brcc    ud_m31dd_no_add

    add     R22, R18
    adc     R23, R19

ud_m31dd_no_add:    
    rol     R24

    lsr     R19
    ror     R18

    dec     R25
    brne    ud_m31dd_1

    com     R24
    ; R24 = value*31/delta, 55 + 3 + 10 = 68c

    ret

; Draws a column of pixels starting from Y = R24 up to Y = 31
; Returns result in R22-R25 where R22 represents the bottom byte and R25 the top one
; Uses R18, R30, R31
ud_draw_column:
    subi    R24, 1
    brmi    ud_dc_full

    mov     ZL, R24
    andi    ZL, 0x07
    clr     ZH
    subi    ZL, lo8(-(ud_dc_data))
    sbci    ZH, hi8(-(ud_dc_data))
    lpm     R18, Z

    mov     ZL, R24

    clr     R22
    clr     R23
    movw    R24, R22

    lsr     ZL
    lsr     ZL
    lsr     ZL
    subi    ZL, -22
    clr     ZH
    st      Z, R18

    subi    R25, 1
    sbci    R24, 0
    sbci    R23, 0
    sbci    R22, 0
    ; 25c

    ret

ud_dc_full:
    ldi     R22, 0xFF
    ldi     R23, 0xFF
    movw    R24, R22
    ret

