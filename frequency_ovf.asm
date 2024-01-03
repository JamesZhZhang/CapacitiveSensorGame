$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram

; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

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

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Timer2_overflow: ds 1 ; 8-bit overflow to measure the frequency of fast signals (over 65535Hz)
;project 1
Timer0_overflow: ds 1
cseg
;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Frequency (Hz): ', 0
Initial_message2: db 'Frequency (Hz): ',0

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
; (tuned manually to get as close to 1s as possible)
Wait1s:
    mov R2, #176
X3: mov R1, #250
X2: mov R0, #166
X1: djnz R0, X1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, X2 ; 22.51519us*250=5.629ms
    djnz R2, X3 ; 5.629ms*176=1.0s (approximately)
    ret
    
    
;for initialize timer 0
Timer0_Init:
mov a, TMOD
anl a, #0xf0 ; Clear the bits for timer 0
orl a, #0x01 ; Configure timer 0 as 16-timer
mov TMOD, a
mov TH0, #high(TIMER0_RELOAD)
mov TL0, #low(TIMER0_RELOAD)
; Set autoreload value
mov RH0, #high(TIMER0_RELOAD)
mov RL0, #low(TIMER0_RELOAD)
; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
ret
;------

;Initializes timer/counter 2 as a 16-bit counter
InitTimer2:
	mov T2CON, #0b_0000_0010 ; Stop timer/counter.  Set as counter (clock input is pin T2).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
    setb P1.0 ; P1.0 is connected to T2.  Make sure it can be used as input.
    setb ET2
    ret

Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	inc Timer2_overflow
	reti

;Converts the hex number in Timer2_overflow-TH2-TL2 to BCD in R3-R2-R1-R0
hex2bcd:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #0
    mov R4, #24 ;Loop counter.

hex2bcd_loop:
    mov a, TL2 ;Shift TH0-TL0 left through carry
    rlc a
    mov TL2, a
    
    mov a, TH2
    rlc a
    mov TH2, a

    mov a, Timer2_overflow
    rlc a
    mov Timer2_overflow, a
      
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	mov a, R3
	addc a, R3
	da a
	mov R3, a
	
	djnz R4, hex2bcd_loop
	ret

; Dumps the 8-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD_LCD:
	; 8th digit:
    mov a, R3
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 6th digit:
    mov a, R3
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 6th digit:
    mov a, R2
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
	lcall Timer0_Init
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
    setb EA ; Enable interrrupts
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    
forever:
    ; Measure the frequency applied to pin T2
    clr TR2 ; Stop counter 2
    clr a
    mov TL2, a
    mov TH2, a
    mov Timer2_overflow, a
    clr TF2
    setb TR2 ; Start counter 2
    lcall Wait1s ; Wait one second
    clr TR2 ; Stop counter 2, TH2-TL2 has the frequency

	; Convert the result to BCD and display on LCD
	Set_Cursor(2, 1)
	lcall hex2bcd
    lcall DisplayBCD_LCD
    sjmp forever ; Repeat! 
end