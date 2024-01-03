$NOLIST
$MODLP51
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE0  EQU ((2048*2)+100)
TIMER0_RATE1  EQU ((2048*2)-100)
TIMER0_RELOAD0 EQU ((65536-(CLK/TIMER0_RATE0)))
TIMER0_RELOAD1 EQU ((65536-(CLK/TIMER0_RATE1)))

SOUND_OUT EQU P1.1

org 0000H
   ljmp Startup

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

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

test1:  db 'ye', 0
test2:	db 'ey', 0

;---------------------------------;
;            Random               ;
;---------------------------------;
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
;   Waits Random Time             ;
;---------------------------------;
Wait_Random:
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
	ret

;---------------------------------;
;   Sets the Seed                 ;
;---------------------------------;
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
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
InitTimer0:
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD1)
	mov TL0, #low(TIMER0_RELOAD1)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.                ;
; Determines which tone to play   ;
; and plays it                    ;
;---------------------------------;
Timer0_ISR:
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti

;---------------------------------;
; Hardware and variable           ;
; initialization                  ;
;---------------------------------;
Startup:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall InitTimer0
	lcall LCD_4BIT
	lcall Seed_set
    clr TR0
	clr a
    mov TL0, a
    mov TH0, a
    setb EA
    
;---------------------------------;
; Main program loop               ;
;---------------------------------;  
forever:
	lcall Random
    mov a, Seed+1
    mov c, acc.3	;Use an arbitrary bit of 32-bit seed 
    mov HLbit, c
	
	lcall Wait_Random
	
	clr TR0	;Before calling timer 0
	
	jb HLbit, tone1
	
	mov RH0, #high(TIMER0_RELOAD0)
	mov RL0, #low(TIMER0_RELOAD0)
	
	;FOR TESTING
	Set_Cursor(2, 1)
    Send_Constant_String(#test2)
	;FOR TESTING
	
	ljmp Done_Tone
tone1:
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	
	;FOR TESTING
	Set_Cursor(2, 1)
    Send_Constant_String(#test1)
	;FOR TESTING
	
Done_Tone:
	
	setb TR0 ;Turn the speaker on
	
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	
	clr TR0	;Turn the speaker off
	
    ljmp forever ; Repeat! 

end