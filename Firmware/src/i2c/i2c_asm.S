#include "../assembler_defines.inc"

.global i2c_delay_low, i2c_delay_high
.global Start, RepeatedStart, Stop, Send, Send2, Send3, SendPM

.altmacro

.macro .print3 t1, t2, t3
    .print "\t1\t2\t3"
.endm

.macro .print5 t1, t2, t3, t4, t5
    .print "\t1\t2\t3\t4\t5"
.endm

.print "*** I2C ***"

#ifndef I2C_MAX_SPEED

; I2C bit length
.set BIT_LEN_NS, (1000000/I2C_SPEED_KHZ)
.set BIT_LEN_LOW_NS, (BIT_LEN_NS*15/25)
.set BIT_LEN_HIGH_NS, (BIT_LEN_NS*10/25)

.set BIT_LEN_LOW_CYCLES, (BIT_LEN_LOW_NS*CPU_SPEED_KHZ/1000000)
.set BIT_LEN_HIGH_CYCLES, (BIT_LEN_HIGH_NS*CPU_SPEED_KHZ/1000000)

.print3 <Frequency:\040>, %(I2C_SPEED_KHZ), <\040KHz>
.print3 <Bit length:\040>, %(BIT_LEN_NS), <\040ns>

.print5 <\040\040low:\040>, %(BIT_LEN_LOW_NS), <\040ns\040(>, %(BIT_LEN_LOW_CYCLES), <\040CPU cycles)>

.set BIT_LEN_LOW_ITERS, ((BIT_LEN_LOW_CYCLES - 9)/3)
.if BIT_LEN_LOW_ITERS < 1
    .set BIT_LEN_LOW_ITERS, 1
    .print "  Warning, I2C low delay is too small"
.endif

.print5 <\040\040high:\040>, %(BIT_LEN_HIGH_NS), <\040ns\040(>, %(BIT_LEN_HIGH_CYCLES), <\040CPU cycles)>

.set BIT_LEN_HIGH_ITERS, ((BIT_LEN_HIGH_CYCLES - 7)/3)
.if BIT_LEN_HIGH_ITERS < 1
    .set BIT_LEN_HIGH_ITERS, 1
    .print "  Warning, I2C high delay is too small"
.endif

; void i2c_delay_low()
; 3 (rcall) + 3 (ldi, rjmp) + 4 (ret) + 2 (dec, brne) + 3*(n - 1) =
; = 9 + 3*n cycles
i2c_delay_low:
    ldi     R18, BIT_LEN_LOW_ITERS
    rjmp    i2c_dh1

; void i2c_delay_high()
; 3 (rcall) + 1 (ldi) + 4 (ret) + 2 (dec, brne) + 3*(n - 1) =
; = 7 + 3*n cycles
i2c_delay_high:
    ldi     R18, BIT_LEN_HIGH_ITERS
    
i2c_dh1:
    dec     R18
    brne    i2c_dh1

    ret

#else // not I2C_MAX_SPEED

.print "Maximum speed mode"

i2c_delay_low:
i2c_delay_high:
    ret

#endif // I2C_MAX_SPEED


; void RepeatedStart()
; Uses R18
RepeatedStart:
    sbi     (USIDR), 7
    rcall   i2c_delay_low

    ldi     R18, BV(USIWM1) | BV(USITC)
    out     (USICR), R18
    ; Fall through to Start

; void Start()
; Uses R18
Start:
    rcall   i2c_delay_low

    out     (USIDR), R1
    rcall   i2c_delay_high

    cbi     (PORTB), PIN_SCL
    sbi     (USISR), USISIF
    rcall   i2c_delay_low

    ret

; void Stop()
; Uses R18
Stop:
    out     (USIDR), R1
    rcall   i2c_delay_low

    sbi     (PORTB), PIN_SCL
    rcall   i2c_delay_high

    sbi     (USIDR), 7

    ret

; bool Send2(uint8_t data1, uint8_t data2);
Send2:
    ; R24 = data1
    ; R22 = data2
    rcall   Send
    breq    send_ret

    mov     R24, R22
    ; Fall through to Send

; bool Send(uint8_t data);
; Uses R18, R19, R24 and R25
Send:
    ; R24 = data
    out     (USIDR), R24

    ldi     R24, 8
    ldi     R19, BV(USIWM1) | BV(USITC)
    ldi     R25, BV(USIWM1) | BV(USICLK)
    ; R19 = SCL_TOGGLE value
    ; R25 = DATA_SHIFT value

    rjmp    send_start

send_loop:
    out     (USICR), R25

send_start:
    rcall   i2c_delay_low
    out     (USICR), R19
    rcall   i2c_delay_high
    out     (USICR), R19

    dec     R24
    brne    send_loop

    ldi     R24, 0xFF
    out     (USIDR), R24
    rcall   i2c_delay_low
    out     (USICR), R19
    rcall   i2c_delay_high
    out     (USICR), R25
    out     (USICR), R19

    in      R24, (USIDR)
    com     R24
    andi    R24, 1

send_ret:
    ret

; bool Send3(uint8_t data1, uint8_t data2, uint8_t data3);
Send3:
    ; R24 = data1
    ; R22 = data2
    ; R20 = data3
    rcall   Send2
    breq    send_ret

    mov     R24, R20
    rjmp    Send

; bool SendPM(const uint8_t* data, uint8_t length);
; Uses R18, R19, R22, R24, R25, R30, R31
SendPM:
    ; R25:R24 = data
    ; R22 = length
    movw    Z, R24

send_pm_1:
    subi    R22, 1
    brcs    send_pm_ok

    lpm     R24, Z+
    rcall   Send
    brne    send_pm_1

    ret

send_pm_ok:
    ldi     R24, 1
    ret
