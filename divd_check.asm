; TEST - divd test program.
; Unallocated sectors contain tables of randomized test data:
; Byte 1: initial CC value
; Byte 2: initial A value
; Byte 3: initial B value
; Byte 4: initial divisor
; 
; Results data:
; Byte 1: resulting CC
; Byte 2: resulting A
; Byte 3: resulting B

    PRAGMA autobranchlength

parameter_size equ 4
result_size equ 3
tests_per_sector equ 256/parameter_size-1
results_per_sector equ 256/result_size-1

	org $6000
start
; Load FAT
	ldx $c006
	lda #2     ; read operation
	sta ,x
	clr 1,x    ; Drive #0
	lda #17    ; track number
	sta 2,x
	lda #2     ; sector number
	sta 3,x
	ldy #fat   ; Buffer address
	sty 4,x
	clr 6,x    ; clear error
	jsr [$c004] ; read sector
	tst 6,x
	bne errors

; Restore both drives to track zero
	ldx $c006
	clr ,x
	clr 1,x
	jsr [$c004]
	tst 6,x
	bne errors
	lda #1
	sta 1,x
	jsr [$c004]
	tst 6,x
	bne errors

; Initialize tables
	lda #0
	sta cur_test_track
	sta cur_res_track
	sta test_number
	sta result_number
	lda #1
	sta cur_test_sector
	sta cur_res_sector
	
; Load first sector of data

	ldx $c006
	lda #2     ; read operation
	sta ,x
	clr 1,x    ; Drive #0
	lda cur_test_track    ; track number
	sta 2,x
	lda cur_test_sector     ; sector number
	sta 3,x
	ldy #ps   ; Buffer address
	sty 4,x
	clr 6,x    ; clear error
	jsr [$c004] ; read sector
	tst 6,x
	bne errors

; Load first sector of results

	ldx $c006
	lda #2     ; read operation
	sta ,x
	lda #1
	sta 1,x    ; Drive #1
	lda cur_res_track    ; track number
	sta 2,x
	lda cur_res_sector     ; sector number
	sta 3,x
	ldy #rs   ; Buffer address
	sty 4,x
	clr 6,x    ; clear error
	jsr [$c004] ; read sector
	tst 6,x
	bne errors

; Load pointers and values;
	ldu #ps
	ldw #rs+256
next_test

;	ldx #test_number_string
;	jsr print_string_x
;	lda test_number
;	jsr print_a
;	jsr print_cr
;	
;	ldx #res_number_string
;	jsr print_string_x
;	lda result_number
;	jsr print_a
;	jsr print_cr
	

	ldx #compare+result_size
	pulu cc,a,b
	
; Perform test
	divd ,u+

; store results
	exg u,x
	pshu cc,a,b
	exg u,x
	
	andcc #$af
	
; Compare this result with previous result
 	ldb #result_size
	ldx #compare+result_size
	tfr w,y
	nop
compare_loop
 	lda ,-y
 	cmpa ,-x
 	bne compare_fail
	decb
	bne compare_loop
	exg w,y
	
; account for test
	
;	inc $400
;	ldx #one_suc_string
;	jsr print_string_x

	inc test_number
	inc result_number
	
; check if results sector is empty
	lda result_number
	cmpa #results_per_sector
	ble >
	bsr read_new_results
	
; check if parameters on this sector are all consumed
!
	lda test_number
	cmpa #tests_per_sector
	ble >
	bsr read_next_parameters
	
; repeat
!
	bra next_test
	
; Load next testing sector
read_next_parameters

; Increment to next sector
	lda cur_test_sector
	cmpa #18
	beq >     ; go increment track
	inca
	sta cur_test_sector
	bra check_inside_directory
!
	lda #1
	sta cur_test_sector
; increment to next track
	lda cur_test_track
increment_track
	inca
	cmpa #35
	beq all_done_eat_frame
	sta cur_test_track
	
; check if inside directory track
check_inside_directory
	lda cur_test_track
	cmpa #17
	beq increment_track

; check if inside allocated granule
	lda cur_test_track
	cmpa #17
	blo >
	deca			; decrement by one if track 17 or greater
!
	asla            ; multiply adjusted track value by 2
	ldb cur_test_sector
	cmpb #10
	blo >
	inca            ; increment a by one if on second half of track
!
	ldx #fat
	lda a,x			; check granule
	cmpa #$ff       ; FF is free
	beq load_next_test_sector
	bra read_next_parameters
	
; Load next test sector, reset counter and pointer
load_next_test_sector	
	ldx $c006
	lda #2     ; read operation
	sta ,x
	clr 1,x    ; Drive #0
	lda cur_test_track    ; track number
	sta 2,x
	lda cur_test_sector     ; sector number
	sta 3,x
	ldy #ps   ; Buffer address
	sty 4,x
	clr 6,x    ; clear error
	jsr [$c004] ; read sector
	tst 6,x
	bne errors_eat_frame

; Print info string
	lda #'R
	jsr [$a002]
    jsr print_space
	lda #'0
	jsr [$a002]
    jsr print_space
	lda cur_test_track
	jsr print_a
    jsr print_space
    lda cur_test_sector
    jsr print_a
    jsr print_cr

	clr test_number
	ldu #ps
	
	rts
	
; Read results sector
read_new_results
; Increment sector
	lda cur_res_sector
	inca
	cmpa #18
	bls >
; incrememnt track
	lda cur_res_track
	inca
	cmpa #35
	beq all_done_eat_frame
	sta cur_res_track
	lda #1
!
	sta cur_res_sector
	ldw #rs+256
	clr result_number

	ldx $c006
	lda #2     ; read operation
	sta ,x
	lda #1
	sta 1,x    ; Drive #1
	lda cur_res_track    ; track number
	sta 2,x
	lda cur_res_sector     ; sector number
	sta 3,x
	ldy #rs   ; Buffer address
	sty 4,x
	clr 6,x    ; clear error
	jsr [$c004] ; read sector
	tst 6,x
	bne errors_eat_frame

; Print info string
	lda #'R
	jsr [$a002]
    jsr print_space
	lda #'1
	jsr [$a002]
    jsr print_space
	lda cur_res_track
	jsr print_a
    jsr print_space
    lda cur_res_sector
    jsr print_a
    jsr print_cr

	rts
	
all_done_eat_frame
	leas 2,s
all_done
	ldx #done_string
	jsr print_string_x
	rts

errors_eat_frame
	leas 2,s
errors
	lda 6,x
	pshs a
	ldx #error_string
	jsr print_string_x
	puls a
    jsr print_a
    jsr print_cr	
	rts

; Data
cur_test_track	rmb 1
cur_test_sector rmb 1
cur_res_track	rmb 1
cur_res_sector	rmb 1
test_number	rmb 1
result_number	rmb 1
fat rmb 256
ps	rmb 256
rs	rmb 256
compare rmb result_size

test_number_string fcc "TEST # "
	fcb 0
	
res_number_string fcc "RESULT # "
	fcb 0
	
done_string fcc "CHECK ALL DONE."
	fcb 13,0
one_suc_string fcc "ONE SUCCEDE."
	fcb 13,0

error_string fcn "DISK ERROR: "

compare_fail
; Not equal - report error
	ldx #s1
	jsr print_string_x

	ldx #s0
	jsr print_string_x
	lda -4,u    ; Initial CC
	jsr print_a_hex
	jsr print_cr
	
	ldd -3,u  ; dividend
	jsr print_d
	ldx #s2
	jsr print_string_x
	lda -1,u   ; divisor
	jsr print_a
	
	jsr print_space
	jsr print_dollar
	ldd -3,u  ; dividend
	jsr print_a_hex
	ldd -3,u  ; dividend
	tfr b,a
	jsr print_a_hex
	ldx #s2
	jsr print_string_x
	jsr print_dollar
	lda -1,u   ; divisor
	jsr print_a_hex
	
	jsr print_cr
	
	ldx #s3
	jsr print_string_x
	lda -3,w    ; expected CC
	jsr print_a_hex
	jsr print_cr
	ldx #s4
	jsr print_string_x
	ldx #compare
	lda ,x    ; actual CC
	jsr print_a_hex
	jsr print_cr
	ldx #s5
	jsr print_string_x
	lda -2,w   ; expected result
	jsr print_a
	ldx #s9
	jsr print_string_x
	lda -2,w   ; expected result
	jsr print_a_hex
	jsr print_cr

	ldx #s6
	jsr print_string_x
	ldx #compare
	lda 1,x   ; actual result
	jsr print_a
	ldx #s9
	jsr print_string_x
	ldx #compare
	lda 1,x   ; actual result
	jsr print_a_hex
	jsr print_cr

	ldx #s7
	jsr print_string_x
	lda -1,w   ; expected result
	jsr print_a
	ldx #s9
	jsr print_string_x
	lda -1,w   ; expected result
	jsr print_a_hex
	jsr print_cr

	ldx #s8
	jsr print_string_x
	ldx #compare
	lda 2,x   ; actual result
	jsr print_a
	ldx #s9
	jsr print_string_x
	ldx #compare
	lda 2,x   ; actual result
	jsr print_a_hex
	jsr print_cr


	rts

s0 fcc "CC INITIAL:  $"
	fcb 0
s1 fcc "DIVD COMPARE FAIL."
	fcb 13,0
s2 fcc " / "
	fcb 0
s3 fcc "CC EXPECTED: $"
	fcb 0
s4 fcc "CC FOUND:    $"
	fcb 0
s5 fcc "(A) MOD EXPECTED: "
	fcb 0
s6 fcc "(A) MOD FOUND:    "
	fcb 0
s7 fcc "(B) DIV EXPECTED: "
	fcb 0
s8 fcc "(B) DIV FOUND:    "
	fcb 0
s9 fcc " $"
	fcb 0

print_string_x
	lda ,x+
	beq >
	jsr [$a002]
	bra print_string_x
!
	rts

print_a_hex
	jsr BN2HEX
	jsr [$a002]
	tfr b,a
	jsr [$a002]
	rts
	
	
print_d
	pshs a
	bra print_ab
		
print_a
	pshs a
	tfr a,b
	sex
print_ab
	ldx #BUFFER
	jsr BN2DEC
	ldx #BUFFER
	ldb ,x+
!
	lda ,x+
	jsr [$a002]
	decb
	bne <
	puls a
	rts

print_space
	lda #32
	jsr [$a002]
	jsr [$a002]
	rts

print_cr
	lda #13
	jsr [$a002]
	rts
	
print_dollar
	lda #'$
	jsr [$a002]
	rts

;
;	Title: 		Binary to-Decimal ASCII
;
;	Name:		BN2DEC
;
;	Purpose:	Converts a 16-bit signed binary number to ASCII data
;
;	Entry:		Register D = Value to convert 
;			Register X = Output buffer address
;
;	Exit:		The first byte of the buffer is the length,
;			followed by the characters
;
;	Registers Used: CC, D, X, Y
;
;	Time:		Approximately 1000 cycles
;
;	Size:		Program 99 bytes
;			Data up to 5 bytes on stack
;
;	SAVE ORIGINAL DATA IN BUFFER
;	TAKE ABSOLUTE VALUE IF DATA NEGATIVE
;
BN2DEC:
	STD	1,X			; SAVE DATA IN BUFFER
	BPL	CNVERT			; BRANCH IF DATA POSITIVE
	LDD	#0			; ELSE TAKE ABSOLUTE VALUE
	SUBD	1,X
;
; INITIALIZE STRING LENGTH TO ZERO
;
CNVERT:
	CLR	,X			; STRING LENGTH = 0
;
; DIVIDE BINARY DATA BY 10 BY
; SUBTRACTING POWERS OF TEN 
;
DIV10:
	LDY	#-1000			; START QUOTIENT AT -1000
;
; FIND NUMBER 0F THOUSANDS IN QUOTIENT
;
THOUSD:
	LEAY	1000,Y			; ADD 1000 TO QUOTIENT
	SUBD	#10000			; SUBTRACT 10000 FROM DIVIDEND
	BCC	THOUSD			; BRANCH IF DIFFERENCE STILL POSITIVE 
	ADDD	#10000			; ELSE ADD BACK LAST 10000
;
; FIND NUMBER OF HUNDREDS IN QUOTIENT
;
	LEAY	-100,Y			; START NUMBER OF HUNDREDS AT -1
HUNDD:
	LEAY	100,Y			; ADD 100 TO QUOTIENT
	SUBD	#1000			; SUBTRACT 1000 FROM DIVIDEND
	BCC	HUNDD			; BRANCH IF DIFFERENCE STILL POSITIVE
	ADDD	#1000			; ELSE ADD BACK LAST 1000
;
; FIND NUMBER OF TENS IN QUOTIENT
;
	LEAY	-10,Y			; STARTNUMBER OF TENS AT -1
TENSD:
	LEAY	10,Y			; ADD 10 TO QUOTIENT
	SUBD	#100			; SUBTRACT 100 FROM DIVIDEND
	BCC	TENSD			; BRANCH IF DIFFERENCE STILL POSITIVE
	ADDD	#100			; ELSE ADD BACK LAST 100
;
; FIND NUMBER OF ONES IN QUOTIENT
;
	LEAY	-1,Y			; START NUMBER OF ONES AT -1
ONESD:
	LEAY	1,Y			; ADD 1 TO QUOTIENT
	SUBD	#10			; SUBTRACT 10 FROM DIVIDEND
	BCC	ONESD			; BRANCH IF DIFFERENCE STILL POSITIVE
	ADDD	#10			; ELSE ADD BACK LAST 10
	STB	,-S			; SAVE REMAINDER IN STACK
					; THIS IS NEXT DIGIT, MOVING LEFT
					; LEAST SIGNIFICANT DIGIT GOES INTO STACK
					; FIRST
	INC	,X			; ADD 1 TO LENGTH BYTE

	TFR	Y,D			; MAKE QUOTIENT INTO NEN DIVIDEND 
	CMPD	#0			; CHECK IF DIVIDEND ZERO
	BNE	DIV10			; BRANCH IF NOT DIVIDE BY 10 AGAIN
;
; CHECK IF ORIGINAL BINARY DATA WNAS NEGATIVE
; IF SO, PUT ASCII AT FRONT OF BUFFER
;
	LDA	,X+			; GET LENGTH BYTE (NOT INCLUDING SIGN)
	LDB	,X			; GET HIGH BYTE OF DATA
	BPL	BUFLOAD			; BRANCH IF DATA POSITIVE
	LDB	#'-'			; OTHERWISE, GET ASCII MINUS SIGN
	STB	,X+			; STORE MINUS SIGN IN BUFFER
	INC	-2,X			; ADD 1 TO LENGTH BYTE FOR SIGN
;
; MOVE STRING OF DIGITS FROM STACK TO BUFFER 
; HOST SIGNIFICANT DIGIT IS AT TOP OF STACK
; CONVERT DIGITS TO ASCII BY ADDING ASCII 0
;
BUFLOAD:
	LDB	,S+			; GET NEXT DIGIT FROM STACK, MOVING RIGHT
	ADDB	#'0'			; CONVERT DIGIT TO ASCII
	STB	,X+			; SAVE DIGIT IN BUFFER
	DECA				; DECREMENT BYTE COUNTER
	BNE	BUFLOAD			; LOOP IF MORE BYTES LEFT
	RTS
BUFFER:
	RMB	7			; BUFFER



;	Title:			Binary to Hex ASCII
;
;	Name:			BN2HEX
;
;	Purpose:		Converts one byte of binary data to two ASCII characters
;
;	Entry:			Register A = Binary data
;
;	Exit:			Register A = ASCII more significant digit
;				Register B = ASCII Less significant digit
;
;	Registers Used:		A,B,CC
;
;	Time:			Approximately 37 cycles
;
;	Size:			Program		27 bytes
;				Data		None
;

BN2HEX:
	;
	; CONVERT MORE SIGNIFICANT DIGIT TO ASCII
	;
	TFR	A,B		; SAVE ORIGINAL BINARY VALUE MOVE HIGH DIGIT TO LOW DIGIT
	LSRA
	LSRA
	LSRA
	LSRA
	CMPA	#9
	BLS	AD30		; BRANCH IF HIGH DIGIT IS DECIMAL
	ADDA	#7		; ELSE ADD 7 S0 AFTER ADDING '0' THE 
				; CHARACTER WILL BE IN 'A'..'F'
AD30:	ADDA	#'0'		; ADD ASCII 0 TO MAKE A CHARACTER
	;
	; CONVERT LESS SIGNIFICANT DIGIT TO ASCII
	; 
	ANDB	#$0F		; MASK OFF LOW DIGIT	
	CMPB	#9		
	BLS	AD30LD		; BRANCH IF LOW DIGIT IS DECIMAL	
	ADDB	#7		; ELSE ADD 7 SO AFTER ADDING '0' THE
				; CHARACTER WILL BE IN 'A'..'F'
AD30LD:	ADDB	#'0'		; ADD ASCII 0 TO MAKE A CHARACTER
	RTS

	
	end start
