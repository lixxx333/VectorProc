;
; Test all opcodes for A format opcodes.  We only use scalar operations here.
;
si1 = si9 | si11		
si2 = si9 & si11	
si3 = si9 &~ si11	
si4 = si9 ^ si11		
si5 = ~ si11
si6 = si9 + si11
si7 = si9 - si11
si8 = si9 / si11
si9 = si9 * si11
si10 = si9 >>> si11
si11 = si9 >> si11
si12 = si9 << si11
si13 = clz(si11)
si14 = si9 == si11
si15 = si9 <> si11
si16 = si9 > si11
si17 = si9 >= si11
si18 = si9 < si11
si19 = si9 <= si11
sf20 = sf9 + sf11
sf21 = sf9 - sf11
sf22 = sf9 * sf11
sf23 = sf9 / sf11
si24 = sftoi(sf9, si10)
sf25 = sitof(si9, si10)
sf26 = floor(sf10)
sf27 = frac(sf10)
sf28 = reciprocal(sf10)
sf29 = abs(sf10)
si30 = sf9 > sf11
si0 = sf9 >= sf11
si1 = sf9 < sf11
si2 = sf9 <= sf11

; Same thing for all applicable type B opcodes, only with scalars
si1 = si9 | 123
si2 = si9 & 47
si3 = si9 &~ 19
si4 = si9 ^ 27
si6 = si9 + 39
si7 = si9 - 11
si8 = si9 / 277
si9 = si9 * 317
si10 = si9 >>> 221
si11 = si9 >> 41
si12 = si9 << 13
si14 = si9 == 99
si15 = si9 <> 87
si16 = si9 > 42
si17 = si9 >= 41
si18 = si9 < 32
si19 = si9 <= 12
si24 = sftoi(sf9, 255)
sf25 = sitof(si9, 19)

si7 = si8
vi13 = vi14
vi13{si1} = vi14
vi13{~si2} = vi14

;
; Test vector operations for A form opcodes
; We don't test all opcodes, but do want to hit all format field values
; The operations here are chosen arbitrarily.
;
vi2 = vi9 & si11			; format 1: vector/scalar, no mask
vi7{si7} = vi9 - si11		; format 2: vector/scalar, masked
vi9{~si12} = vi17 - si18	; format 3: vector/scalar, inverted mask
vi1 = vi9 | vi11			; format 4: vector/vector, no mask
vi3{si4} = vi9 &~ vi11		; format 5: vector/vector, masked
vi6{~si6} = vi9 + vi11		; format 6: vector/vector, inverted mask

vi8 = ~ vi11				; Test single operand operation with vector args
vi8{si11} = ~ vi11
vi8{~si11} = ~ vi11
vi8 = ~ si11				; It's also legal to have a scalar operand for 
vi8{si11} = ~ si11			; a single operand, which all of the following
vi8{~si11} = ~ si11			; cases validate
vf26 = floor(sf10)
vf27 = frac(sf10)
vf28 = reciprocal(sf10)
vf29 = abs(sf10)
vi13 = clz(si11)




;
; Vector floating point vector arguments
;
vf21 = vf9 - sf11					; format 1
vf20 = vf9 + vf11					; format 2
vi24 = sftoi(vf9, si10)				; use functional style with vector (2 args)
vf26 = floor(vf10)					; single function argument (1 arg)
vi24{si11} = sftoi(vf9, si10)		; sftoi is special
vi24{~si12} = sftoi(vf9, si10)		; ditto

;
; Memory accesses
;
s1 = mem_b[si2]						; op 0 load
mem_b[si2] = s30					;   store
s3 = mem_b[si3 + 12]				;   load with offset
mem_b[si3 + 12] = s29				;   store with offset
s4 = mem_bx[si6]					; op 1 load
s5 = mem_bx[si7 + 17]				;   load with offset
s8 = mem_s[si9]						; op 2 load 
mem_s[si11] = s27					;   store
s10 = mem_s[si11 + 19]				;   load with offset
mem_s[si11 + 19] = s27				;   store with offset
s14 = mem_sx[si16]					; op 3 load
s15 = mem_sx[si17 + 27]				;   load with offset
s18 = mem_l[si19]					; op 4 load
mem_l[si19] = s26					;   store
s21 = mem_l[si20 + 37]				;   load with offset
mem_l[si20 + 37] = s25				;   store with offset
s22 = mem_linked[si23]				; op 5 load
s24 = mem_linked[si25 + 39]			;   load with offset
mem_linked[si23] = s24				;   store
mem_linked[si25 + 39] = s23			;   store with offset
v2 = mem_l[si1]						; op6-8 load
mem_l[si1] = v2						;   store
v2 = mem_l[si1 + 17]				;   load with offset
mem_l[si1 + 19] = v2				;   store with offset
v4{si3} = mem_l[si2 + 17]	 		;	load with mask
mem_l[si2 + 17]{si3} = v4			;	store with mask
v4{~si3} = mem_l[si2 + 17] 			;	load with inverted mask
mem_l[si2 + 17]{~si3} = v4			;	store with inverted mask
v2 = mem_l[si1, 17]					; op9-11 load 
mem_l[si1, 19] = v2					;   store
v4{si3} = mem_l[si2, 17]	 		;	load with mask
mem_l[si2, 17]{si3} = v4			;	store with mask
v4{~si3} = mem_l[si2, 17] 			;	load with inverted mask
mem_l[si2, 17]{~si3} = v4			;	store with inverted mask
v2 = mem_l[vi1]						; op12-14 load
mem_l[vi1] = v2						;   store
v2 = mem_l[vi1 + 17]				;   load with offset
mem_l[vi1 + 19] = v2				;   store with offset
v4{si3} = mem_l[vi2 + 17]	 		;	load with mask
mem_l[vi2 + 17]{si3} = v4			;	store with mask
v4{~si3} = mem_l[vi2 + 17] 			;	load with inverted mask
mem_l[vi2 + 17]{~si3} = v4			;	store with inverted mask

_start
