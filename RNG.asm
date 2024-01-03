$NOLIST
$MODLP51
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE1   EQU 2048     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD_1 EQU ((65536-(CLK/TIMER0_RATE1)))

TIMER0_RATE2   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD_2 EQU ((65536-(CLK/TIMER0_RATE2)))

SOUND_OUT   equ P1.1 ;speaker pin 1.1

TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))

org 0000H
   ljmp MyProgram

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
Seed: ds 4

$NOLIST
$include(math32.inc)
$LIST

bseg
HLbit:	dbit 1
mf:		dbit 1
WaitBit: dbit 1

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7


$NOLIST

$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

testMessage:  db 'ye', 0
test2:			db 'ey', 0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
; TR0 Bit set to 0 in the Timer0_initilization subroutine so that the speaker would start OFF
; To start beeping, set the TR0 bit to 1 and also make it flash by turning it on and off

Timer0_Init:
	;mov TR0, #0    ;set TR0 to 0 so starts off 

mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD)
	mov RL0, #low(TIMER0_RELOAD)

    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; RNG Code            ;
;---------------------------------;
; should emit random sound at end based on generated code

Random:
mov x+0,Seed+0
mov x+1, Seed+1
mov x+2, Seed+2
mov x+3, Seed+3
Load_y(214013)
lcall mul32
Load_y(2531011)
mov Seed+0,x+0
mov Seed+1,x+1
    mov Seed+2, x+2
    mov Seed+3,x+3
    ret

;---------------------------------;
;   Waits a rando                 ;
;---------------------------------;

Wait_Random:
	Wait_Milli_Seconds(#50)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Set_Cursor(1, 1)
    Send_Constant_String(#testMessage)
	ret
;---------------------------------;
;  tone 2                           ;
;---------------------------------;
tone2:
ljmp Wait_Random

mov RH0, #high(TIMER0_RELOAD_2)
mov RL0, #low(TIMER0_RELOAD_2)

setb SOUND_OUT
;Wait_Milli_Seconds(#255)
;Wait_Milli_Seconds(#255)
;Wait_Milli_Seconds(#255)
;Wait_Milli_Seconds(#255)
clr SOUND_OUT

ret

;---------------------------------;
;  tone 1             	     ;
;---------------------------------;
tone1:

	Set_Cursor(1, 1)
    Send_Constant_String(#testMessage)
    Wait_Milli_Seconds(#250)
    Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)

ret 

Seed_set:
	setb TR0	;start timer 0
    jb P4.5,$
    mov Seed+0,TH0
    mov Seed+1,#0x01
    mov Seed+2, #0x87
    mov Seed+3,TL0
    clr TR0 ;stop timer 0
ret

;---------------------------------;
; Main Code                     ;
;---------------------------------;
; Initialize the hardware:
MyProgram:
    mov SP, #7FH
    lcall Timer0_Init
    lcall LCD_4BIT
    clr TR0
    mov TL0, #0
    mov TH0, #0
    
    clr WaitBit
    
    ;clearing the seed 
	mov Seed+0,#0x0
    mov Seed+1,#0x0
    mov Seed+2, #0x0
    mov Seed+3,#0x0
    
    lcall Seed_set
    

forever:

	Set_Cursor(2, 1)
    Send_Constant_String(#test2)

	;choosing tone to play
    lcall Random
    mov a, Seed+1
    mov c, acc.3	;Use an arbitrary bit of 32-bit seed 
    mov HLbit, c

	
    ;jc call_tone2
    ljmp tone1
    sjmp no_tone2
    
call_tone2:
    ljmp tone2
;else jump tone 1 if HLbit is other

no_tone2:
	ljmp forever
	
END




