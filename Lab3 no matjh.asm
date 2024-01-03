;Fun fact about otters: They can reach swim speeds of up to 7 miles per hour.
;This pace is three times faster than the average human swimmer!
;Otters can hold their breath for 3-4 minutes, closing their nostrils and ears to keep out water.
;Powerful tails propel them through the water. 
;River otters have webbing between their toes to aid them as well!

$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram
   
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
cap: ds 5
period: ds 5
freq: ds 5
T2ov: ds 2 ; 16-bit timer 2 overflow (to measure the period of very slow signals)

BSEG
mf: dbit 1
pflag: dbit 1
fflag: dbit 1
cflag: dbit 1

$NOLIST
$include(math32.inc)
$LIST

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
Period_Message:  db 'Period (ns)     ', 0
No_Signal_Str:    db 'No signal       ', 0
Freq_Message:	  db 'Frequency (Hz)  ', 0
Cap_Message:	  db 'Capacitance (nF)', 0
Initial_Message:  db 'Whats popping!', 0

Display:		;Determine which quantity to display
	jb pflag, Display_10_digit_BCD_period
	jb fflag, Display_10_digit_BCD_freq
	jnb cflag, donedisplay
	ljmp Display_10_digit_BCD_cap
	
donedisplay:
	ret

Display_10_digit_BCD_period:
	Set_Cursor(1, 1)
    Send_Constant_String(#Period_Message)
	Set_Cursor(2, 1)
	Display_BCD(period+4)
	Display_BCD(period+3)
	Display_BCD(period+2)
	Display_BCD(period+1)
	Display_BCD(period+0)
	ret
	
Display_10_digit_BCD_freq:
	Set_Cursor(1, 1)
    Send_Constant_String(#Freq_Message)
	Set_Cursor(2, 1)
	Display_BCD(freq+4)
	Display_BCD(freq+3)
	Display_BCD(freq+2)
	Display_BCD(freq+1)
	Display_BCD(freq+0)
	ret
	
Display_10_digit_BCD_cap:
	Set_Cursor(1, 1)
    Send_Constant_String(#Cap_Message)
	Set_Cursor(2, 1)
	Display_BCD(cap+4)
	Display_BCD(cap+3)
	Display_BCD(cap+2)
	Display_BCD(cap+1)
	Display_BCD(cap+0)
	ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2
    ret

Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	push acc
	inc T2ov+0
	mov a, T2ov+0
	jnz Timer2_ISR_done
	inc T2ov+1
Timer2_ISR_done:
	pop acc
	reti

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

	clr pflag
	clr fflag
	clr cflag

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    
forever:
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2
synch1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal ; If the count is larger than 0x01ffffffff*45ns=1.16s, we assume there is no signal
    jb P0.0, synch1
synch2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P0.0, synch2
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal 
    jb P0.0, measure1
measure2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P0.0, measure2
    clr TR2 ; Stop timer 2, [T2ov+1, T2ov+0, TH2, TL2] * 45.21123ns is the period

	sjmp skip_this
no_signal:	
	Set_Cursor(2, 1)
    Send_Constant_String(#No_Signal_Str)
    ljmp forever ; Repeat! 
skip_this:

	; Make sure [T2ov+1, T2ov+2, TH2, TL2]!=0
	mov a, TL2
	orl a, TH2
	orl a, T2ov+0
	orl a, T2ov+1
	jz no_signal
	; Using integer math, convert the period to frequency:
	mov x+0, TL2
	mov x+1, TH2
	mov x+2, T2ov+0
	mov x+3, T2ov+1
	Load_y(45) ; One clock pulse is 1/22.1184MHz=45.21123ns
	lcall mul32
	
	;storing period
	lcall hex2bcd
	mov period+4, bcd+4
	mov period+3, bcd+3
	mov period+2, bcd+2
	mov period+1, bcd+1
	mov period+0, bcd+0
	
	;calculating capacitance
	Load_y(667)
	lcall div32
	
	;storing capacitance
	lcall hex2bcd
	mov cap+4, bcd+4
	mov cap+3, bcd+3
	mov cap+2, bcd+2
	mov cap+1, bcd+1
	mov cap+0, bcd+0

	;measuring frequency
	;putting period back in x
	mov x+0, TL2
	mov x+1, TH2
	mov x+2, T2ov+0
	mov x+3, T2ov+1
	Load_y(45) 
	lcall mul32
	
	lcall copy_xy	;copy x (period) to y
	Load_x(1000000000)
	lcall div32
	
	;storing frequency
	lcall hex2bcd
	mov freq+4, bcd+4
	mov freq+3, bcd+3
	mov freq+2, bcd+2
	mov freq+1, bcd+1
	mov freq+0, bcd+0

;buttons for choosing between period, frequency, and capacitance
Pbutton:
	jb P4.5, fbutton
	Wait_Milli_Seconds(#50)
	jb P4.5, fbutton
	jnb P4.5, $
	setb pflag
	clr fflag
	clr cflag
	
fbutton:
	jb P2.6, cbutton
	Wait_Milli_Seconds(#50)
	jb P2.6, cbutton
	jnb P2.6, $
	setb fflag
	clr pflag
	clr cflag
	
cbutton:
	jb P2.3, nobutton
	Wait_Milli_Seconds(#50)
	jb P2.3, nobutton
	jnb P2.3, $
	clr pflag
	clr fflag
	setb cflag
	
nobutton:	
	lcall Display
    ljmp forever ; Repeat! 
    

end