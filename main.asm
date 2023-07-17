;------------------------------------------------------------------------
; 
;  KTRIDER utility
;
;  main.asm 
;
;  Copyright (c)2021 Kevin Boone, GPL v3.0
;
;------------------------------------------------------------------------

	.Z80
	
	ASEG
	ORG    0100H

	include conio.inc
	include clargs.inc
	include intmath.inc
	include string.inc
	include mem.inc

	.request conio
	.request clargs
	.request intmath
	.request string
	.request mem


; Output port -- defaults to 0 for RC2014 front panel LEDS
PORT	EQU	0

; Number of LED patterns -- see 'patrn' in the data definitions at end 
PATS	EQU     27	

; NUmber of LEDs -- always 8
NLED 	EQU	8

; Number of loops of the PWM routine after which to adjust the display
;   pattern. Typically 5 for 18MHz, 1 or 2 for 4MHz 
NLOOP	EQU     5 

	JP	main	; Go to start

;------------------------------------------------------------------------
;  prthelp 
;  Print the help message
;------------------------------------------------------------------------
prthelp:
	PUSH	HL
	LD 	HL, us_msg
	CALL	puts
	LD 	HL, hlpmsg
	CALL	puts
	POP	HL
	RET

;------------------------------------------------------------------------
;  prtversion
;  Print the version message
;------------------------------------------------------------------------
prtversion:
	PUSH	HL
	LD 	HL, ver_msg
	CALL	puts
	POP	HL
	RET

;------------------------------------------------------------------------
;  abrtmsg: 
;  Prints the message indicated by HL, then exits. This function
;    does not return
;------------------------------------------------------------------------
abrtmsg:
	CALL	puts
	CALL	newline
	CALL	exit

;------------------------------------------------------------------------
;  abrtusmsg: 
;  Prints the message indicated by HL, then the usage message, then exits.
;  This function does not return
;------------------------------------------------------------------------
abrtusmsg:
	CALL	puts
	CALL	newline
	JP	abrtusage

;-------------------------------------------------------------------------
; abrtusage
; print usage message and exit
;-------------------------------------------------------------------------
abrtusage:
	LD	HL, us_msg
	CALL	abrtmsg

;-------------------------------------------------------------------------
; badswitch
; print "Bad option" message and exit. 
;-------------------------------------------------------------------------
.badswitch:
	LD	HL, bs_msg
	CALL	puts
	CALL	newline
	LD	HL, us_msg
	CALL	puts
	CALL	newline
	JP	.done


;------------------------------------------------------------------------
;  setled 
;  Turn on the LED whose number is in A. Range 0-7.
;  All registers preserved except AF
;------------------------------------------------------------------------
setled:
	PUSH	BC
	LD	B, 1
.setled0:
        OR	A
	JR	Z, .setled1
	SLA	B
	DEC	A
	JR	.setled0
.setled1:
        LD	A, (leds)
	OR	B
	LD	(leds), A
	POP	BC
	RET

;------------------------------------------------------------------------
;  resled 
;  Turn off the LED whose number is in A. Range 0-7.
;  All registers preserved except AF
;------------------------------------------------------------------------
resled:
	PUSH	BC
	LD	B, 1
.resled0:
        OR	A
	JR	Z, .resled1
	SLA	B
	DEC	A
	JR	.resled0
.resled1:
	LD	A, B
	XOR	0FEh
	LD	B, A
        LD	A, (leds)
	AND	B

	LD	(leds), A
	POP	BC
	RET

;------------------------------------------------------------------------
;  setbrtns 
;  Copy a specific brightness pattern from ptrn to brtness. ptrn 
;    consists of a number of 8-bit patterns.
;  On entry, A is the pattern number, 0-PATS
;  All registers preserved
;------------------------------------------------------------------------
setbrtns:
	PUSH	HL
	PUSH	DE	
	PUSH	BC
	PUSH	AF

        LD	L, A
	LD	H, 0
	LD	DE, NLED 
	CALL	mul16
	LD	D, H
	LD	E, L
	LD	HL, ptrn
	ADD	HL, DE	; HL now points to offset in pattern table

	LD	DE, brtness ; Copy pattern to brtness
	LD	B, 0 
	LD	C, NLED 
	CALL	memcpy

	POP	AF
	POP	BC
	POP	DE
	POP	HL	
	RET

;------------------------------------------------------------------------
;  Start here 
;------------------------------------------------------------------------
main:
	; Initialize the command-line parser
	CALL	clinit
	LD	B, 0	; Arg count

	; Loop until all CL arguments have been seen
.nextarg:
	CALL	clnext
	JR	Z, .argsdone

	OR	A
	JR	Z, .notsw
	; A is non-zero, so this is a switch character 
	; The only switches we handle are /h, /v, and /s at present
	CP	'H'
	JR	NZ, .no_h
	CALL	prthelp
	JP	.done
.no_h:
	CP	'V'
	JR	NZ, .no_v
	CALL	prtversion
	JP	.done	
.no_v:
	JP	.badswitch


	JR	.nextarg

.notsw:
.argsdone:

	; The main part of the program starts here. The .outer loop
	;   runs forever. The .inner0 loops runs 254 times for each 
	;   iteration of .outer. This inner loops does the PWM control.
	;  For each run of .inner we turn on the LED when the C register
        ;   counts down to to the stored value in the brightness 
	;   (brtness) array. So if the stored value is 255, we turn on
	;   immediately. If 0, never. 
	; At the end of each PWM loop, we check whether to change the
	;   brightness pattern.

.outer:
	LD	A, 0h 
        OUT	(PORT), A	; Start with LEDs off
	LD	(leds), A

        LD	C, 255		; C counts down 255->0 
.inner0:

	LD 	B, NLED		; Repeat the PWN loop for each LED 
.inner1:
	DEC	B
 	LD	HL, brtness	
	LD	D, 0
	LD	E, B
	ADD	HL, DE		; Find the appropriate position in brtness
	LD	A, (HL)
	CP	C		; See if we need to turn on
	JR	C, .noset
	LD	A, B 
	CALL	setled		; If so, call setled mark LED on
.noset:

	LD	A, B
	CP	1
	JR	NC, .inner1

	LD	A, (leds)	; When all the PWM loops done, switch LEDs
	OUT	(PORT), A

	LD	A, C	
	CP	2
	JR	C, .scndone
	DEC	C
	JR	.inner0

.scndone:
	; End of PWM loop. Work out whether we need to chagne pattern
	LD 	HL, loops
	DEC	(HL)
	JR	NZ, .nochange
	LD	HL, NLOOP 
	LD	(loops), HL

	LD	A, (focus)
	CALL	setbrtns
	INC	A
	CP	PATS	
	JR	C, .nores
	LD	A, 0
.nores:
	LD	(focus), A
.nochange:

	JP	.outer
.done:
	; ...and exit cleanly
	CALL	exit

;------------------------------------------------------------------------
; Data 
;------------------------------------------------------------------------
; Focus is the number of the LED pattern we are currently showing
focus:
	db 0

brtness: 
	; Current LED brightness values
	; Note -- Array is 'back to front' with respect to the typical
	;   wiring of RC2014 front panel LEDs. But this isn't obvious
	;   because the pattern is symmetrical
	db 0, 0, 0, 0, 0, 0, 0, 0 

; Array of brightness patterns. Each is 8 bytes long. The number of
;   entries in this array is defined in PATS
ptrn:   
	db 0,   0,   0,   0,   0,   0,   0,   3 
	db 0,   0,   0,   0,   0,   0,   3,  20 
	db 0,   0,   0,   0,   0,   3,  20,  64 
	db 0,   0,   0,   0,   3,  20,  64, 255 
	db 0,   0,   0,   3,  20,  64, 255,  64 
	db 0,   0,   3,  20,  64, 255,  64,  20 
	db 0,   3,  20,  64, 255,  64,  20,   3
	db 3,  20,  64, 255,  64,  20,   3,   0
	db 20, 64, 255,  64,  20,   3,   0,   0 
	db 64, 255, 64,  20,   3,   0,   0,   0 
	db 255, 64, 20,   3,   0,   0,   0,   0 
	db 64,  20,  3,   0,   0,   0,   0,   0 
	db 20,  3,   0,   0,   0,   0,   0,   0 
	db 3,   0,   0,   0,   0,   0,   0,   0 
	db 20,  3,   0,   0,   0,   0,   0,   0 
	db 64,  20,  3,   0,   0,   0,   0,   0 
	db 255, 64, 20,   3,   0,   0,   0,   0 
	db 64, 255, 64,  20,   3,   0,   0,   0 
	db 20, 64, 255,  64,  20,   3,   0,   0 
	db 3,  20,  64, 255,  64,  20,   3,   0
	db 0,   3,  20,  64, 255,  64,  20,   3
	db 0,   0,   3,  20,  64, 255,  64,  20 
	db 0,   0,   0,   3,  20,  64, 255,  64 
	db 0,   0,   0,   0,   3,  20,  64, 255 
	db 0,   0,   0,   0,   0,   3,  20,  64 
	db 0,   0,   0,   0,   0,   0,   3,  20 
	db 0,   0,   0,   0,   0,   0,   0,   3 

; Number of PWM loops since the last pattern change
loops:
	dw NLOOP

; Aggregate values of the LED on/off status -- written to the port
;   after all the PWM calculations
leds:
	db 0

blank:
	db "   "
	db 0

hlpmsg: 	
	db "/h show help text"
        db 13, 10
	db "/v show version"
        db 13, 10
	db 0

; Scratch area for converting integers to strings
numbuff:
	db "12345678"
	db 0

us_msg:
	db "Usage: ktrider [/hv]" 
        db 13, 10, 0

ver_msg:
	db "ktrider 0.1a, copyright (c)2023 Kevin Boone, GPL v3.0"
        db 13, 10, 0

bs_msg:
	db "Bad option.", 0 

end 

