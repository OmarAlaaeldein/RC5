.equ t=18 .equ c=6 .equ b=12 .equ r=8
.equ ql=0x37 // magic q lower part
.equ qh=0x9e // magic q higher part
.equ ph=0xb7 // magic p higher part
.equ pl=0xe1 // magic p lower part
.equ b0=0x5678 // INPUT A0
.equ a0=0x1234 // INPUT B0
//ldi r16,24
//ldi r17,0x4a
//ldi r18,0x11
//sts 0x300,r16
call tableexpansion
call encrypt
call decrypt
stuck: RJMP stuck
.macro mod16 // to prevent useless rotates and performance improve
	andi @0,0b00001111
.endmacro

.macro initz // init z reg
	ldi r30,low(@0)
	ldi r31,high(@0)
.endmacro

.macro inity // init y reg
	ldi r28,low(@0)
	ldi r29,high(@0)
.endmacro

.macro word_postinc_z // uses r20 and r21 to word into consequtive addresses defined by intiz macro
	st Z+,r20
	st Z+,r21
.endmacro

.macro addq // 
	add @0,@2
	adc @1,@3
.endmacro

.macro subq
	sub @0,@2
	sbc @1,@3
.endmacro

.macro rotatelnocarry //rol w/o , param are lower part of A or B , @0 = number of rotates, @1= low , @2=high
	push r16
	lds r16,@0 // number of rotations required
	andi r16,0b00001111
	mov r1,r16
	pop r16
	mov r2,@2 ; high
	mov r3,@1; low
	ldi r28,0x00; just for comparison to work in cpse
	rcall justrotl
	mov @2,r2
	mov @1,r3
.endmacro
justrotl:
	rotl:  bst r2,7 ; store the msb in high 
		bld r5,7 ; store the msb in high in msb r18
		cpse r5,r28 ; compare and skip if equal r18 and r19 
		sec ; if msb in r18 is 1 then set carry
		rol r3 ; rotate low left with carry 
		rol r2; rotate high left with carry from low
		clc ; clear carry
		dec r1 ; decrement
		brne rotl ; if not rotated count times then repeat again
	ret
.macro rotaternocarry  ;ror w/o carry implementation for 8 bit register
	push r16
	lds r16,@0 // number of rotations required
	andi r16,0b00001111
	mov r1,r16
	pop r16
	mov r2,@2 ; high
	mov r3,@1; low
	ldi r28,0x00; just for comparison to work in cpse
	rcall justrotr
	mov @2,r2
	mov @1,r3
.endmacro
justrotr:
	rotr:  bst r2,0 ; store the lsb in high in t bit
		bld r5,0 ; store the lsb in high in msb r18
		cpse r5,r28 ; compare and skip if equal r18 and r19 
		sec ; if msb in r18 is 1 then set carry
		ror r3 ; rotate low right with carry 
		ror r2; rotate high right with carry from low
		clc ; clear carry
		dec r1 ; decrement
		brne rotr ; if not rotated count times then repeat again
	ret
tableexpansion: // table expansion  L=[1111,2222,3333,4444,5555,6666], address begins at 0x0250, little indian, uses r20 and r21
	// 1st step
	initz 0x0250
	ldi r20,low(0x1111)
	ldi r21,high(0x1111)
	word_postinc_z
	ldi r20,low(0x2222)
	ldi r21,high(0x2222)
	word_postinc_z
	ldi r20,low(0x3333)
	ldi r21,high(0x3333)
	word_postinc_z
	ldi r20,low(0x4444)
	ldi r21,high(0x4444)
	word_postinc_z
	ldi r20,low(0x5555)
	ldi r21,high(0x5555)
	word_postinc_z
	ldi r20,low(0x6666)
	ldi r21,high(0x6666)
	word_postinc_z
	// 2nd step, S array start at 0x0300
	initz 0x0300
	ldi r20,pl
	ldi r21,ph
	ldi r22,ql
	ldi r23,qh
	word_postinc_z
	ldi r24 ,t-1
	s:  addq r20,r21,r22,r23
		word_postinc_z
		dec r24
		brne s
	// 3rd step , I will just call a function 3 times here
	.def al=r20
	.def ah=r21
	.def bl=r22
	.def bh=r23
	clr r20
	clr r21
	clr r22
	clr r23
	ldi r27,3
	clr r11 // for cpse later
	sts 0x0333,r27
	clr r27
	clr r25
	inity 0x0250 // init for L
	initz 0x0300 // init for S
	ldi r24,t // debug
	ldi r26,c
	first:
	    ld r16,Z+
		ld r17,Z+
		ld r18,Y+
		ld r19,Y+
		addq al,ah,r16,r17
		addq al,ah,bl,bh
		rotatelnocarry 0x333,al,ah
		ld r10,-Z
		ld r10,-Z // 2 wasted inst for decrementing z twice to put in place S[i]=S[i] +stuff 
		st Z+,al // to store in place, very hard and inconvinient
		st Z+,ah
		addq bl,bh,al,ah //jj
		sts 0x400,bl
		addq bl,bh,r18,r19
		rotatelnocarry 0x400,bl,bh
		ld r10,-Y
		ld r10,-Y
		st Y+,bl
		st Y+,bh
		dec r24
		dec r26
		tst r26
		breq resy
		tst r24
		brne first
		rjmp ok
	fin:
		tst r24
		breq resx
		
	resy:
		ldi r26,c
		inity 0x0250
		rjmp fin
	resx:
		ldi r26,c
		inity 0x0250
		rjmp first
	ok:
	ret
encrypt: // S starts from 0x0300
	initz 0x0300
	ldi r16,low(a0)
	ldi r17,high(a0)
	ldi r18,low(b0)
	ldi r19,high(b0)
	ldi r25,r
	ld r20,Z+
	ld r21,Z+
	ld r22,Z+
	ld r23,Z+
	addq r16,r17,r20,r21
	addq r18,r19,r22,r23
	a:	sts 0x500,r18// low b0
		eor r16,r18
		eor r17,r19
		rotatelnocarry 0x500,r16,r17
		ld r4,Z+
		ld r5,Z+
		addq r16,r17,r4,r5
		sts 0x501,r16// low a0
		eor r18,r16
		eor r19,r17
		rotatelnocarry 0x501,r18,r19
		ld r4,Z+
		ld r5,Z+
		addq r18,r19,r4,r5
		dec r25
		brne p
		sts 0x110,r16 // store after low a done
		sts 0x111,r17 // high a
		sts 0x112,r18 // low b
		sts 0x113,r19 // high b
		rjmp wn
		p: rjmp a
	wn:	ret
decrypt: // Start from 0x0322
	lds r16,0x110 // store after low a done
	lds r17,0x111 // high a
	lds r18,0x112 // low b
	lds r19,0x113 // high b
	ldi r29,r
	initz 0x0318
	final:
		sts 0x333,r16 // just to use ror macro
		ld r20,Z //low S
		ld r10,-Z // no post dec :(
		ld r21,Z // high S
		ld r10,-Z
		subq r18,r19,r20,r21
		rotaternocarry 0x333,r18,r19
		eor r18,r16
		eor r19,r17
		sts 0x334,r18
		ld r20,Z //low S
		ld r10,-Z
		ld r21,Z // high S
		ld r10,-Z
		subq r16,r17,r20,r21
		rotaternocarry 0x334,r16,r17
		eor r16,r18
		eor r17,r19
		dec r29
		brne ag
		rjmp done
		ag: rjmp final
	done:
		lds r25,0x0300 // low s[0]
		lds r26,0x0301 // high s[0]
		lds r27,0x0302 // low s[1]
		lds r28,0x0303 // high s[1]
		subq r18,r19,r27,r28
		subq r16,r17,r25,r26
		sts 0x110,r16 // store after low a done
		sts 0x111,r17 // high a
		sts 0x112,r18 // low b
		sts 0x113,r19 // high b
		ret