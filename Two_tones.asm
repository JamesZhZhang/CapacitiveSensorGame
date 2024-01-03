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
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P1.1 ;
;---------------------------------;
Timer0_ISR:
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
WaitHalfSec:
    mov R2, #89
L3: mov R1, #250
L2: mov R0, #166
L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L2 ; 22.51519us*250=5.629ms
    djnz R2, L3 ; 5.629ms*89=0.5s (approximately)
    ret

;---------------------------------;
; Hardware and variable           ;
; initialization                  ;
;---------------------------------;
Startup:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall InitTimer0
    setb EA
    
;---------------------------------;
; Main program loop               ;
;---------------------------------;  
forever:
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOAD0)
	mov RL0, #low(TIMER0_RELOAD0)
	setb TR0
	
    ljmp forever ; Repeat! 

end