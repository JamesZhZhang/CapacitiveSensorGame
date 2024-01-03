$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram
   
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Timer2_overflow: ds 2 ; 16-bit timer 2 overflow (to measure the period of very slow signals)

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

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Period/45.21ns: ', 0

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0b_0000_0000 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2
    ret

Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	push acc
	inc Timer2_overflow+0
	mov a, Timer2_overflow+0
	jnz Timer2_ISR_done
	inc Timer2_overflow+1
Timer2_ISR_done:
	pop acc
	reti

;Converts the hex number in high(Timer2_overflow)-low(Timer2_overflow)-TH2-TL2 to BCD in R4-R3-R2-R1-R0
hex2bcd:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #0
    mov R4, #0
    mov R5, #32 ;Loop counter.

hex2bcd_loop:
    mov a, TL2 ;Shift TH0-TL0 left through carry
    rlc a
    mov TL2, a
    
    mov a, TH2
    rlc a
    mov TH2, a

    mov a, Timer2_overflow+0
    rlc a
    mov Timer2_overflow+0, a
    
    mov a, Timer2_overflow+1
    rlc a
    mov Timer2_overflow+1, a
      
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
	
	mov a, R4
	addc a, R4
	da a
	mov R4, a
	
	djnz R5, hex2bcd_loop
	ret

; Dumps the 8-digit packed BCD number in R4-R3-R2-R1-R0 into the LCD
DisplayBCD_LCD:
	; 10th digit:
    mov a, R4
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 9th digit:
    mov a, R4
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 8th digit:
    mov a, R3
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 7th digit:
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
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
    setb EA
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    setb P0.0 ; Pin is used as input

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    
forever:
    ; Measure the period applied to pin P0.0
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov Timer2_overflow+0, #0
    mov Timer2_overflow+1, #0
    clr TF2
    jb P0.0, $
    jnb P0.0, $
    setb TR2 ; Start counter 0
    jb P0.0, $
    jnb P0.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period

	; Convert the result to BCD and display on LCD
	Set_Cursor(2, 1)
	lcall hex2bcd
    lcall DisplayBCD_LCD
    sjmp forever ; Repeat! 
end