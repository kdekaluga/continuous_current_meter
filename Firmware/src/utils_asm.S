#include "assembler_defines.inc"

.global I16ToString, CalcRmsCurrent, Random

; void I16ToString(uint16_t value, uint8_t *buffer, uint8_t maxLeadingSpaces);
I16ToString:
	; R25:R24 = value
	; R23:R22 = buffer
	; R20 = maxLeadingSpaces

	movw	Z, R22

	ldi		R22, lo8(10000)
	ldi		R23, hi8(10000)
	rcall	dtsCount

	ldi		R22, lo8(1000)
	ldi		R23, hi8(1000)
	rcall	dtsCount

	ldi		R22, lo8(100)
	ldi		R23, hi8(100)
	rcall	dtsCount

	ldi		R22, lo8(10)
	ldi		R23, hi8(10)
	rcall	dtsCount

	st		Z, R24
	ret

dtsCount:
	; R23:R22 = value to subtract
	clr     R21

	sub		R24, R22
	sbc		R25, R23
	brcs	dtsZero

dtsCountLoop:
	inc		R21
	sub		R24, R22
	sbc		R25, R23
	brcc	dtsCountLoop

	add		R24, R22
	adc		R25, R23

	st		Z+, R21
	
	; Prevent using spaces for any successive zero digits
	clr		R20
	ret

dtsZero:
	add		R24, R22
	adc		R25, R23

	dec     R20
    brmi    dtsNoSpace
	ldi		R21, 15 // display::SYM_SPACE

dtsNoSpace:
	st		Z+, R21
	ret

; ***
; uint16_t CalcRmsCurrent();
CalcRmsCurrent:
	MPUSH	14, 17

	clr		R14
	clr		R15
	movw	R16, R14

    ldi     ZL, lo8(g_samples)
    ldi     ZH, hi8(g_samples)

calc_rms_loop:
	ldd		R24, Z + 1
	ldd		R25, Z + 2
	swap	R25
	andi	R25, 0x0F
	movw	R22, R24

	rcall	Mul12x12
	; R20:R19:R18 = (v[i].max)^2

	add		R14, R18
	adc		R15, R19
	adc		R16, R20
	adc		R17, R1

	adiw	Z, 3
    cpi     ZL, lo8(g_samples + 128*3)
    brne    calc_rms_loop
	; R17:R16:R15:R14 = sum(v[i].max^2)
	; 19584c

	lsl		R14
	rol		R15
	rol		R16
	rol		R17
	; R17:R16:R15 = sum(v[i].max^2)/128

	clr		R26
	clr		R27
	; R27:R26 will be sqrt(n)

	ldi		ZL, 0x00
	ldi		ZH, 0x08

calc_rms_square:
	movw	R24, R26
	or		R24, R30
	or		R25, R31
	movw	R22, R24
	rcall	Mul12x12

	cp		R15, R18
	cpc		R16, R19
	cpc		R17, R20
	brcs	calc_rms_square_no_add

	or		R26, R30
	or		R27, R31

calc_rms_square_no_add:
	lsr		ZH
	ror		ZL
	brcc	calc_rms_square
	; R27:R26 = sqrt(sum(v[i].max^2)/128)

	movw	R24, R26

	MPOP	14, 17
	ret


Mul12x12:
	; Multiplicates 12-bit values in R25:R24 by R23:R22
	; 24-bit result is returned in R20:R19:R18
	; Uses R18, R19, R20, R21, R22, R23, R24, R25
	clr		R18
	clr		R19
	movw	R20, R18

	; Op1 = R25:R24
	; Op2 = R21:R23:R22
	rjmp	mul12x12_shift_right

mul12x12_add:
	add		R18, R22
	adc		R19, R23
	adc		R20, R21

mul12x12_shift_left:
	lsl		R22
	rol		R23
	rol		R21

mul12x12_shift_right:
	lsr		R25
	ror		R24
	brcs	mul12x12_add
	; 10c per iteration in the worst case

	sbci	R25, 0
	brne	mul12x12_shift_left
	; 130c in the worst case

	ret

; ***
; Get pseudo-random byte
; uint8_t Random();
Random:
	ldi		R23, 8

random_loop:
	rcall	GetRandomBit
	dec		R23
	brne	random_loop

	ret

; Generates one bit of a pseudo-random sequence using the 31-bit shift
; register and XNOR feedback from bits 30 and 27. Using XNOR allows
; the algorithm to start from the all-zeros state.
; Returns one rnd bit in R24:0 (actually, in any bit of R24)
; Uses R25
GetRandomBit:
	lds		R24, (g_rndGenState + 0)
	lsl		R24

	lds		R25, (g_rndGenState + 1)
	rol		R25
	sts		(g_rndGenState + 1), R25
	lds		R25, (g_rndGenState + 2)
	rol		R25
	sts		(g_rndGenState + 2), R25
	lds		R25, (g_rndGenState + 3)
	rol		R25
	sts		(g_rndGenState + 3), R25

	// We need to XNOR bits 3 and 6 from R25
	bst		R25, 3
	bld		R24, 0
	bst		R25, 6
	bld		R25, 0
	com		R25
	andi	R25, 0x01
	eor		R24, R25

	sts		(g_rndGenState + 0), R24

	ret
