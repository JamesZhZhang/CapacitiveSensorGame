$NOLIST
$MODLP51
$LIST

CLK            EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE0   EQU 2048     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD0 EQU ((65536-(CLK/TIMER0_RATE0)))

TIMER0_RATE1   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD1 EQU ((65536-(CLK/TIMER0_RATE1)))

SOUND_OUT   equ P1.1 ;speaker pin 1.1

TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))

org 0000H
   ljmp MyProgram
   
; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR


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
test_msg:		   db 'test',0
A_win:          db 'Player A Win',0
B_win:             db 'Player B Win',0

; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7  

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
; (tuned manually to get as close to 1s as possible)

;--------------------------------------------------------;
;             Code                                       ;
;--------------------------------------------------------;

Wait1s:
    mov R2, #176
X3: mov R1, #250
X2: mov R0, #166
X1: djnz R0, X1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, X2 ; 22.51519us*250=5.629ms
    djnz R2, X3 ; 5.629ms*176=1.0s (approximately)
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
;       Initialize Timer  2       ;
;---------------------------------;
InitTimer2:
	mov T2CON, #0b_0000_0000 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
    ret

;---------------------------------;
;    math functions               ;
;---------------------------------;

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

;--------------------------;
;   player1 score incement ;
;--------------------------;
inc_player_1: 
	mov a, Player_1_score
	jb HLbit, player_1_increment
	

  jz player1_da
  
  sjmp player_1_decrement

;decrement because HBit = 0
player_1_increment:
  add a, #0x01
  sjmp player1_da
  
player_1_decrement:
  add a,#0x99
  
player1_da:
  da a
  mov Player_1_score, a
  clr a
  clr mf
  setb Point_Awarded
  
   Set_Cursor(1, 14)
    Display_BCD(Player_1_Score)
    
    mov a, Player_1_Score
    mov b, #0x05
    	cjne a, b, conti_1
  clr a
	Set_Cursor(1,1)
	Send_Constant_String(#A_win)
    
    sjmp AWinSound
    
conti_1:
ljmp conti  
  	
AWinSound:
	;play beeps upon win
		setb TR0 ;Turn the speaker on
		Wait_Milli_Seconds(#250)
		clr TR0	;Turn the speaker off
		Wait_Milli_Seconds(#250)
		
		setb TR0 ;Turn the speaker on
		Wait_Milli_Seconds(#250)
		clr TR0	;Turn the speaker off
		Wait_Milli_Seconds(#250)
		
		setb TR0 ;Turn the speaker on
		Wait_Milli_Seconds(#250)
		clr TR0	;Turn the speaker off
		Wait_Milli_Seconds(#250)
    
    
	Wait_Milli_Seconds(#255)
	Wait_Milli_Seconds(#255)
		Wait_Milli_Seconds(#255)
			Wait_Milli_Seconds(#255)
    
    
	ljmp forever
	

;--------------------------;
;   player2 score incement ;
;--------------------------;
inc_player_2: 
	mov a, Player_2_score
	jb HLbit, player_2_increment
  
 
  jz player2_da
    
  sjmp player_2_decrement

;decrement because HBit = 0    
player_2_increment:
  add a, #0x01
  sjmp player2_da
  
player_2_decrement:
  add a,#0x99
  
player2_da:
  da a
  mov Player_2_score, a
  clr a
  clr mf
  setb Point_Awarded
   Set_Cursor(2, 14)
    Display_BCD(Player_2_score)
    mov a, Player_2_score
    mov b, #0x05
	cjne a, b, conti_2
  clr a
	Set_Cursor(2,1)
	Send_Constant_String(#B_win)

sjmp BWinSound 
 
  conti_2:
 	ljmp conti   	
	
BWinSound:
	;play beeps upon win
		setb TR0 ;Turn the speaker on
		Wait_Milli_Seconds(#250)
		clr TR0	;Turn the speaker off
		Wait_Milli_Seconds(#250)
		
		setb TR0 ;Turn the speaker on
		Wait_Milli_Seconds(#250)
		clr TR0	;Turn the speaker off
		Wait_Milli_Seconds(#250)
		
		setb TR0 ;Turn the speaker on
		Wait_Milli_Seconds(#250)
		clr TR0	;Turn the speaker off
		Wait_Milli_Seconds(#250)
    
    
    
	Wait_Milli_Seconds(#255)
		Wait_Milli_Seconds(#255)
		Wait_Milli_Seconds(#255)
			Wait_Milli_Seconds(#255)


						
;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
	ret
conti: 
	ljmp forever
;---------------------------------;
; Main program                    ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    
;-----------------------Two Tone RNG Initialization---------------;
    lcall InitTimer0
	lcall Seed_set
    clr TR0
	clr a
    mov TL0, a
    mov TH0, a
    setb EA
;------------------------------------------------------------------;
   
    ; Make sure the two input pins are configure for input
    setb P2.0 ; Pin is used as input
    setb P2.1 ; Pin is used as input

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#Initial_Message2)
    mov Player_1_score, #0x00
    mov Player_2_score, #0x00
    Set_Cursor(1, 14)
    Display_BCD(Player_1_score)
    Set_Cursor(2, 14)
    Display_BCD(Player_2_score)
    
   
;---------------------------------;
; Loop                            ;
;---------------------------------;
      
forever:

;------------Random Number Generation----------;
	clr HLbit
	lcall Random
    mov a, Seed+1
    mov c, acc.3	;Use an arbitrary bit of 32-bit seed 
    mov HLbit, c
	
	lcall Wait_Random
	
	clr TR0	;Before calling timer 0
	
;---------Deciding which tone to play-------------;
	jb HLbit, tone1
	
	mov RH0, #high(TIMER0_RELOAD0)
	mov RL0, #low(TIMER0_RELOAD0)
	
	ljmp Done_Tone
tone1:
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	
Done_Tone:
	
	setb TR0 ;Turn the speaker on
	
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	Wait_Milli_Seconds(#250)
	
	clr TR0	;Turn the speaker off

Keep_Checking:
clr Point_Awarded

;------------------------------Player 1  Capacitor-----------------------------------------;
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
  load_y(22500)
  lcall x_gt_y

	jb mf, inc1
  sjmp no_inc1
inc1: ljmp inc_player_1
no_inc1:

    
;------------------------------Player 2  Capacitor-----------------------------------------;
    
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
	load_y(12000)
    lcall x_gt_y

	jb mf, inc2
  sjmp no_inc2
inc2: ljmp inc_player_2
no_inc2:

    
    ;jnb HLbit, skip_label
    jb Point_Awarded, call_Forever
    ljmp Keep_Checking

 call_Forever:
    ljmp forever ; Repeat! 
end