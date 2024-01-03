$NOLIST
$MODLP51
$LIST

CLK            EQU 22118400 ; Microcontroller system crystal frequency in Hz
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
Player_1_score: ds 1
Player_2_score: ds 1
T2ov: ds 2

$NOLIST
$include(math32.inc)
$LIST

bseg
HLbit:	dbit 1
mf:		dbit 1
Point_Awarded: dbit 1
WaitBit:	dbit 1

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
;Initial_Messag:  db 'BCD_counter: xx ', 0 ;just example 
  
Initial_Message:  db 'Player 1 :      ', 0
Initial_message2: db 'Player 2 :      ', 0
  

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
; TR0 Bit set to 0 in the Timer0_initilization subroutine so that the speaker would start OFF
; To start beeping, set the TR0 bit to 1 and also make it flash by turning it on and off

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

    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; RNG Code            						;
;---------------------------------;
; should emit random sound at end based on generated code

Random:
mov x+0, Seed+0
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
;   Waits a random time           ;
;---------------------------------;

Wait_Random:
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
	ret
;---------------------------------;
;  tone 2                         ;
;---------------------------------;
tone2:
mov RH0, #high(TIMER0_RELOAD_2)
mov RL0, #low(TIMER0_RELOAD_2)

setb SOUND_OUT
Wait_Milli_Seconds(#255)
Wait_Milli_Seconds(#255)
Wait_Milli_Seconds(#255)
Wait_Milli_Seconds(#255)
clr SOUND_OUT

ret

;---------------------------------;
;  tone 1             	     			;
;---------------------------------;
tone1:
mov RH0, #high(TIMER0_RELOAD_1)
mov RL0, #low(TIMER0_RELOAD_1)

setb SOUND_OUT
Wait_Milli_Seconds(#255)
Wait_Milli_Seconds(#255)
Wait_Milli_Seconds(#255)
Wait_Milli_Seconds(#255)
clr SOUND_OUT

ret 

;--Andrew
;-------------------------;
;  decide incrementation  ;
;-------------------------;
;note:
;in this case, assuming two period will be meassured in different timer 
;will change back to one but for a place holder now

player_1_period_and_Increment:
mov x+0, TL2
mov x+1, TH2
mov x+2, TL2ov+0
mov x+3, TH2ov+1
load_y(45)
  lcall mul32
;now, period is in x
;move in y a thershold value
load_y(300)
  ;compare x and y, if period is larger than threshold value the player 1 will increment
  ;if x larger, the mf will set to be 1
   lcall x_gt_y
   cjne mf,#0x01,inc_player_1
   ret
   
player_2_period_and_Increment
mov x+0, TL2
mov x+1, TH2
mov x+2, TL2ov+0
mov x+3, TH2ov+1
load_y(45)
  lcall mul32
;now, period is in x
;move in y a thershold value
load_y(300)
   lcall x_gt_y
   cjne mf,#0x01,inc_player_2
	ret


;--------------------------;
;   player1 score incement ;
;--------------------------;

inc_player_1 ;might need to use da? (decimal adjust)
	mov a, Player_1_score
  add a,0x01
  mov Player_1_score, a
  clr a
  clr mf
  setb Point_Awarded
	jmp return_back

inc_player_2
	mov a, Player_2_score
  add a,0x01
  mov Player_2_score, a
  clr a
  clr mf
	jmp return_back
  setb Point_Awarded
;--Andrew

;---------------------------------;
; Main Code                   	  ;
;---------------------------------;
; Initialize the hardware:
MyProgram:
    mov SP, #7FH
    lcall Timer0_Init
    clr TR0
    mov TL0, #0
    mov TH0, #0
    
    clr WaitBit		;For determining whether we need to call Wait_Random or not
    							;Not sure if we actually need this tho
    
    ;clearing the seed 
	mov Seed+0,#0x0
    mov Seed+1,#0x0
    mov Seed+2, #0x0
    mov Seed+3,#0x0
    
    lcall LCD_4BIT ;initialize lcd here
    Set_Cursor(1, 1)
		Send_Constant_String(#Initial_Message)
		Set_Cursor(2,1)
		Send_Constant_String(#Initial_Message2)
      
    mov Player_1_score, #0x00
		mov Player_2_score, #0x00

		;Initializing the seed
	  setb TR0	;start timer 0
    jb P4.5,$
    mov Seed+0,TH0
    mov Seed+1,#0x01
    mov Seed+2,#0x87
    mov Seed+3,TL0
    clr TR0 ;stop timer 0


forever:

;-------------------------------RNG Main Code------------------------------------;

	;choosing tone to play
    lcall Random
    mov a, Seed+1
    mov c, acc.3	;Use an arbitrary bit of 32-bit seed 
    mov HLbit, c


	ljmp Wait_Random

    jc call_tone2
    sjmp tone1
    sjmp Keep_Checking
    
call_tone2:
    ljmp tone2
;else jump tone 1 if HLbit is other


;-------------------------------------------------------------------------------------;
;                               Period Measuring Main Code                            ;
;-------------------------------------------------------------------------------------;
Keep_Checking:
;------------------------------P0.0 Capacitor-----------------------------------------;
		clr Point_Awarded ;Evertime we start this loop, we assume no point has been awarded yet
  
  ;Check period at P0.0
  	clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2
synch1:
	jb TF2, no_signal ; If the timer overflows, we assume there is no signal
    jb P0.0, synch1
synch2:    
	jb TF2, no_signal
    jnb P0.0, synch2
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	jb TF2, no_signal
    jb P0.0, measure1
measure2:    
	jb TF2, no_signal
    jnb P0.0, measure2
    clr TR2 ; Stop timer 2, 

;TL2 and TH2 have the period now!
ljmp player_1_period_and_Increment
;------------------------------P1.0 Capacitor-----------------------------------------;
  ;Check period at P1.0
  	clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2
synch1:
	jb TF2, no_signal ; If the timer overflows, we assume there is no signal
    jb P1.0, synch1
synch2:    
	jb TF2, no_signal
    jnb P1.0, synch2
    
    ; Measure the period of the signal applied to pin P1.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	jb TF2, no_signal
    jb P1.0, measure1
measure2:    
	jb TF2, no_signal
    jnb P1.0, measure2
    clr TR2 ; Stop timer 2, 

;TL2 and TH2 have the period now!
ljmp player_2_period_and_Increment

;--------------------------------Controlling the Loop------------------------------------;
jnb Keep_Checking, Point_Awarded	;Keep checking if no one has earned a point yet
  
	ljmp forever		;if a point has been awarded, jump back to the top of the loop!
END




