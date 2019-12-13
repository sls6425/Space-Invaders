; Print.s
; Student names: change this to your names or look very silly
; Last modification date: change this to the last modification date or look very silly
; Runs on LM4F120 or TM4C123
; EE319K lab 7 device driver for any LCD
;
; As part of Lab 7, students need to implement these LCD_OutDec and LCD_OutFix
; This driver assumes two low-level LCD functions
; ST7735_OutChar   outputs a single 8-bit ASCII character
; ST7735_OutString outputs a null-terminated string 


first	EQU 0	; variable offset
second	EQU 4
third	EQU 8
fourth	EQU 12
fifth	EQU 16
sixth	EQU 20
seventh	EQU 24
eighth	EQU 28
ninth	EQU	32
tenth	EQU 36
	
    IMPORT   ST7735_OutChar
    IMPORT   ST7735_OutString
    EXPORT   LCD_OutDec
    EXPORT   LCD_OutFix
	PRESERVE8					
	
    AREA    |.text|, CODE, READONLY, ALIGN=2
    THUMB

;-----------------------LCD_OutDec-----------------------
; Output a 32-bit number in unsigned decimal format
; Input: R0 (call by value) 32-bit unsigned number
; Output: none
; Invariables: This function must not permanently modify registers R4 to R11
LCD_OutDec
	PUSH {R4 - R11} 			; save callee registers
	SUB SP, #40					; allocate bytes for local vars, max value in each byte is 9
	
	LDR R1, =1000000000			; divisor is 1x10^9 because ~4,200,000,000 is the greatest number you can create with a 32 bit input (2^32)
	UDIV R3, R0, R1				; divide by divisor
	ADD R2, R3, #0x30			; add 0x30 (#48) to value for ASCII code, #0 is ox3o in ASCII
    STRB R2, [SP, #first]		; store value in bound variable using offset
	MLS R0, R1, R3, R0			; modulus division, leaves mod in R0
								; R(1) is the destination register.
								; R(2), R(3) are registers holding the values to be multiplied.
								; R(4) is a register holding the value to be subtracted from.
	
	LDR R1, =100000000			; 100 millions place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #second]
	MLS R0, R1, R3, R0
	
	LDR R1, =10000000			; 10 millions place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #third]
	MLS R0, R1, R3, R0
	
	LDR R1, =1000000			; millions place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #fourth]
	MLS R0, R1, R3, R0
	
	LDR R1, =100000				; hundred thousands place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #fifth]
	MLS R0, R1, R3, R0
	
	LDR R1, =10000				; ten thousands place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #sixth]
	MLS R0, R1, R3, R0
	
	LDR R1, =1000				; thousands place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #seventh]
	MLS R0, R1, R3, R0
	
	LDR R1, =100				; hunderds place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #eighth]
	MLS R0, R1, R3, R0
	
	LDR R1, =10					; tens place
	UDIV R3, R0, R1
	ADD R2, R3, #0x30
	STRB R2, [SP, #ninth]
	MLS R0, R1, R3, R0
	
	ADD R0, R0, #0x30				; remaining modulus is ones place
	STRB R0, [SP, #tenth]
	
	LDRB R0, [SP, #first]			; check stack for first nonzero value 
	CMP R0, #0x30					; starting with 32'nd bit
	BNE start_here
	
	LDRB R0, [SP, #second]			
	CMP R0, #0x30
	BNE slide_to_the_right
	
	LDRB R0, [SP, #third]			
	CMP R0, #0x30
	BNE again1
	
	LDRB R0, [SP, #fourth]
	CMP R0, #0x30
	BNE again2
	
	LDRB R0, [SP, #fifth]
	CMP R0, #0x30
	BNE again3
	
	LDRB R0, [SP, #sixth]
	CMP R0, #0x30
	BNE again4
	
	LDRB R0, [SP, #seventh]
	CMP R0, #0x30
	BNE again5
	
	LDRB R0, [SP, #eighth]
	CMP R0, #0x30
	BNE again6
	
	LDRB R0, [SP, #ninth]
	CMP R0, #0x30
	BNE again7
	
	LDRB R0, [SP, #tenth]
	CMP R0, #0x30
	B last_time				; always prints last digit by default
						
; print value starting with first nonzero value
; R0 loaded with "first" variable by default

start_here 				; output char 
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP	{LR,R0}
	
slide_to_the_right			; output char 
	LDRB R0, [SP, #second]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
again1						; output char
	LDRB R0, [SP, #third]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
again2						; output char 
	LDRB R0, [SP, #fourth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
again3						; output char 
	LDRB R0, [SP, #fifth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
again4						; output char 
	LDRB R0, [SP, #sixth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
again5						; output char 
	LDRB R0, [SP, #seventh]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
again6						; output char 
	LDRB R0, [SP, #eighth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
again7						; output char 
	LDRB R0, [SP, #ninth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}

last_time					; output char 
	LDRB R0, [SP, #tenth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
	ADD SP, #40					; deallocate memory for local vars
	POP {R4 - R11}				; pop callee registers
    BX  LR
	
;* * * * * * * * End of LCD_OutDec * * * * * * * *

; -----------------------LCD _OutFix----------------------
; Output characters to LCD display in fixed-point format
; unsigned decimal, resolution 0.001, range 0.000 to 9.999
; Inputs:  R0 is an unsigned 32-bit number
; Outputs: none
; E.g., R0=0,    then output "0.000 "
;       R0=3,    then output "0.003 "
;       R0=89,   then output "0.089 "
;       R0=123,  then output "0.123 "
;       R0=9999, then output "9.999 "
;       R0>9999, then output "*.*** "
; Invariables: This function must not permanently modify registers R4 to R11
LCD_OutFix
	PUSH {R4 - R11} 			; save callee registers
	
	SUB SP, #20					; allocate bytes for local vars, max value in each byte is 9
	
	MOV R1, #42						; ASCII code for "*"
	MOV R2, #46						; ASCII code for "."
	
	
	
	; default output = " *.*** "
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	STRB R1, [SP, #first]			; # (number)
	STRB R2, [SP, #second]			; . (always decimal)
	STRB R1, [SP, #third]			; # (number)
	STRB R1, [SP, #fourth]			; # (number)
	STRB R1, [SP, #fifth]			; # (number)
	
	MOV R1, #9999				
	CMP R0, R1					; check if R0 > 9999, this is the greatest value that can be displayed
	BHI display
	
	MOV R1, #1000
	UDIV R2, R0, R1				; divide R0 by 1000
	MLS R0, R1, R2, R0			; modulus division, mod in R0
	ADD R2, #0x30
	STRB R2, [SP, #first]
	
	MOV R1, #100
	UDIV R2, R0, R1				; divide R0 by 100
	MLS R0, R1, R2, R0			; modulus division, mod in R0
	ADD R2, #0x30
	STRB R2, [SP, #third]
	
	MOV R1, #10
	UDIV R2, R0, R1				; divide R0 by 10
	MLS R0, R1, R2, R0			; modulus division, mod in R0
	ADD R2, #0x30
	STRB R2, [SP, #fourth]
	ADD R0, #0x30
	STRB R0, [SP, #fifth]			; remaining modulus is less than 10

display
	LDRB R0, [SP, #first]			; print variables
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}

	LDRB R0, [SP, #second]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
	LDRB R0, [SP, #third]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
	LDRB R0, [SP, #fourth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
	LDRB R0, [SP, #fifth]
	PUSH {LR,R0}
	BL ST7735_OutChar
	POP {LR,R0}
	
	ADD SP, #20					; deallocate local variables
	POP {R4 - R11}				; pop saved registers
    BX   LR
 
    ALIGN
;* * * * * * * * End of LCD_OutFix * * * * * * * *

    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file