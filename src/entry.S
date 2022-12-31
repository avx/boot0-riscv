/*
 * Copyright 2022 (C) Alexander Vysokovskikh
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if __riscv_xlen == 32
# define store sw
# define load  lw
# define reg_size .word
#elif __riscv_xlen == 64
# define store sd
# define load  ld
# define reg_size .dword
#else
# error unsupported __riscv_xlen
#endif

	.section .text.startup
	.global entry, hang
entry:
	# choose the lucky one
	lla t0, hart_lottery
	li t1, 1
	amoadd.w t0, t1, (t0)
	bnez t0, wait_boot_hart

	# save a0, a1
	mv s0, a0
	mv s1, a1

	# zero bss
	lla t0, bss_start
	lla t1, bss_end
1:
	store zero, (t0)
	add t0, t0, __SIZEOF_POINTER__
	blt t0, t1, 1b

	# set up a stack for C
	lla sp, stack

	# jump to C, return next jump address (a0)
	call c_start

	# say other hart where to go
	lla t3, jump_addr
	store a0, 0(t3)
	fence

	mv t0, a0

	# restore boot values of a0 and a1
	mv a0, s0
	mv a1, s1

	# jump to firmware
	jr t0

.align 2
wait_boot_hart:
	lla t3, jump_addr
2:
	# reduce bus traffic
.rept 8
	nop
.endr
	load t0, 0(t3)
	beqz t0, 2b
	jr t0

.align 2
hang:
	wfi
	j hang

	.section .data
	.global hart_lottery, jump_addr
	.align 3
jump_addr:
	reg_size 0
hart_lottery:
	.word 0
