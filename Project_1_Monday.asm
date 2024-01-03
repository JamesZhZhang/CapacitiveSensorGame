$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram

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

DSEG at 0x30
Period_A: ds 2
Period_B: ds 2
;added Monday
Player_1_score: ds 1
Player_2_score: ds 1
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
Point_Awarded: dbit 1
  
CSEG
;                      1234567890123456    <- This helps determine the location of the counter
Initial_Message1:  db 'Player A:       ', 0
Initial_Message2:  db 'Player B:       ', 0

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

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0b_0000_0000 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
    ret

;Converts the hex number in TH2-TL2 to BCD in R2-R1-R0
hex2bcd6:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #16 ;Loop counter.

hex2bcd_loop:
    mov a, TL2 ;Shift TH0-TL0 left through carry
    rlc a
    mov TL2, a
    
    mov a, TH2
    rlc a
    mov TH2, a
      
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
	
	djnz R3, hex2bcd_loop
	ret

; Dumps the 5-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD_LCD:
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

;--------------------------;
;   player1 score incement ;
;--------------------------;
inc_player_1: 
	mov a, Player_1_score
	jb HLbit, player_1_increment
  
  ;decrement because HBit = 0
  jz player1_da

player_1_increment:
  add a, #0x99
  sjmp player1_da
  
  add a,#0x01
  
player1_da:
  da a
  mov Player_1_score, a
  clr a
  clr mf
  setb Point_Awarded
	ret

;--------------------------;
;   player2 score incement ;
;--------------------------;
inc_player_2: 
	mov a, Player_2_score
	jb HLbit, player_2_increment
  
  ;decrement because HBit = 0
  jz player2_da
    
player_2_increment:
  add a, #0x99
  sjmp player2_da
  
  add a,#0x01
  
player2_da:
  da a
  mov Player_2_score, a
  clr a
  clr mf
  setb Point_Awarded
	ret

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    ; Make sure the two input pins are configure for input
    setb P2.0 ; Pin is used as input
    setb P2.1 ; Pin is used as input

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#Initial_Message2)
    
forever:

Keep_Checking:
;------------------------------ Player 1  Capacitor -----------------------------------------;
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    mov R0, #100
    setb TR2 ; Start counter 0
meas_loop1:
    jb P2.0, $
    jnb P2.0, $
    djnz R0, meas_loop1 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov Period_A+0, TL2
    mov Period_A+1, TH2

	; Convert the result to BCD and display on LCD
	
  ;added Monday
  ;move TL2 and Th2 into x
  mov x+0, TL2
  mov x+1, Th2
	mov x+2, #0
  mov x+3, #0
  
  ;move threshold into y
  load_y(8000)
  lcall x_gt_y

	jb mf, inc1
  sjmp no_inc1
  
inc1: 

ljmp inc_player_1


no_inc1:
    
;------------------------------ Player 2  Capacitor-----------------------------------------;
    
    ; Measure the period applied to pin P2.1
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    mov R0, #100
    setb TR2 ; Start counter 0
meas_loop2:
    jb P2.1, $
    jnb P2.1, $
    djnz R0, meas_loop2 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the perioda
    ; save the period of P2.1 for later use
    mov Period_B+0, TL2
    mov Period_B+1, TH2
	
  ;added Monday
  ;move TL2 and TH2 into x
  
	mov x+0, TL2
  mov x+1, TH2
	mov x+2, #0
  mov x+3, #0
  
  ;move threshold into y
	load_y(16000)
    lcall x_gt_y

	jb mf, inc2
  sjmp no_inc2
inc2: ljmp inc_player_2
no_inc2:

jnb Keep_Checking, Point_Awarded
    
    ljmp forever ; Repeat! 
end