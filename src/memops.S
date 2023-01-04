/*
 * Copyright 2023 (C) Alexander Vysokovskikh
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

#define HAVE_RISCV_MEMCPY
#define HAVE_RISCV_MEMSET
#define HAVE_RISCV_MEMMOVE
//#define USE_HALF_WORD_OPS

#if __riscv_xlen == 32
# define REG_S sw
# define REG_L lw
# define SZREG 4
#elif __riscv_xlen == 64
# define REG_S sd
# define REG_L ld
# define SZREG 8
#else
# error unsupported __riscv_xlen
#endif

.section .text
    # we want to reduce the size of the code, so in order
    # to comply with the compressed ISA specification,
    # we will use preferably s0-s1, a0-a5 registers.

    # byte load/store operations only if size less than threshold
    .equ BOPS_THRESHOLD, 2*SZREG

#ifdef HAVE_RISCV_MEMCPY
.globl memcpy
    #
    # void *memcpy(void *dst, void *src, size_t sz)
    #
    # Copies sz bytes from memory area src to memory area dst.
    # The memory areas must not overlap. Uses load/stores of XLEN.
    # For mutual misaligned buffers does byte-by-byte coping.
memcpy:
    # save initial dst value
    mv t6, a0

    # threshold for byte-by-byte copying
    li a5, BOPS_THRESHOLD
    bltu a2, a5, .Lmemcpy_bops

    # the src and dst buffers must have the same
    # alignment for load/store operations
    and a4, a0, SZREG-1
    and a5, a1, SZREG-1
    bne a4, a5, .Lmemcpy_bops
    beqz a4, .Lmemcpy_main

    # handle head misalignments
    li a5, SZREG
    sub a4, a5, a4
    add a3, a0, a4
0:  lb a5, 0(a1)
    sb a5, 0(a0)
    addi a1, a1, 1
    addi a0, a0, 1
    blt a0, a3, 0b
    sub a2, a2, a4

    # copy 16/8/4/2/1*SZREG at one cycle iteration
.Lmemcpy_main:
    # according to convention
    # s0, s1 must be stored by callee
    mv t5, s0
    mv t4, s1

    li a7, 16*SZREG
    mv a3, a7
    j 6f
1:  REG_L a4, 8*SZREG(a1)
    REG_L a5, 9*SZREG(a1)
    REG_L s0, 10*SZREG(a1)
    REG_L s1, 11*SZREG(a1)
    REG_S a4, 8*SZREG(a0)
    REG_S a5, 9*SZREG(a0)
    REG_S s0, 10*SZREG(a0)
    REG_S s1, 11*SZREG(a0)
    REG_L a4, 12*SZREG(a1)
    REG_L a5, 13*SZREG(a1)
    REG_L s0, 14*SZREG(a1)
    REG_L s1, 15*SZREG(a1)
    REG_S a4, 12*SZREG(a0)
    REG_S a5, 13*SZREG(a0)
    REG_S s0, 14*SZREG(a0)
    REG_S s1, 15*SZREG(a0)
2:  REG_L a4, 4*SZREG(a1)
    REG_L a5, 5*SZREG(a1)
    REG_L s0, 6*SZREG(a1)
    REG_L s1, 7*SZREG(a1)
    REG_S a4, 4*SZREG(a0)
    REG_S a5, 5*SZREG(a0)
    REG_S s0, 6*SZREG(a0)
    REG_S s1, 7*SZREG(a0)
3:  REG_L a4, 2*SZREG(a1)
    REG_L a5, 3*SZREG(a1)
    REG_S a4, 2*SZREG(a0)
    REG_S a5, 3*SZREG(a0)
4:  REG_L s0, 1*SZREG(a1)
    REG_S s0, 1*SZREG(a0)
5:  REG_L s1, 0*SZREG(a1)
    REG_S s1, 0*SZREG(a0)
    add a0, a0, a3
    add a1, a1, a3
    sub a2, a2, a3
6:  bgeu a2, a7, 1b
    srli a3, a7, 1
    bgeu a2, a3, 2b
    srli a3, a3, 1
    bgeu a2, a3, 3b
    srli a3, a3, 1
    bgeu a2, a3, 4b
    srli a3, a3, 1
    bgeu a2, a3, 5b

    # restore s0, s1
    mv s1, t4
    mv s0, t5

.Lmemcpy_bops:
    # byte-by-byte coping
    beqz a2, 1f
    add a3, a0, a2
0:  lb a4, 0(a1)
    sb a4, 0(a0)
    addi a1, a1, 1
    addi a0, a0, 1
    bltu a0, a3, 0b

    # return initial dst
1:  mv a0, t6
    ret
#endif /* HAVE_RISCV_MEMCPY */

#ifdef HAVE_RISCV_MEMSET
.globl memset
    #
    # void *memset(void *dst, int ch, size_t sz)
    #
    # Function fills the first sz bytes of the memory
    # area pointed to by dst with the constant byte ch.
    # Uses stores operations of XLEN (register) size.
memset:
    # save return value
    mv t6, a0

    # threshold for byte-by-byte stores
    li a5, BOPS_THRESHOLD
    bltu a2, a5, .Lmemset_bops

    # propagate set value to whole register
    slli a5, a1, 8
    or a1, a1, a5
    slli a5, a1, 16
    or a1, a1, a5
#if __riscv_xlen == 64
    slli a5, a1, 32
    or a1, a1, a5
#endif

    # is dst aligned to register size
    and a4, a0, SZREG-1
    beqz a4, .Lmemset_main

    # handle head misalignment
    li a5, SZREG
    sub a4, a5, a4
    add a3, a0, a4
0:  sb a1, 0(a0)
    addi a0, a0, 1
    blt a0, a3, 0b
    sub a2, a2, a4

    # stores 16/8/4/2/1*SZREG at one cycle iteration
.Lmemset_main:
    li a5, 16*SZREG
    mv a3, a5
    j 6f
1:  REG_S a1, 8*SZREG(a0)
    REG_S a1, 9*SZREG(a0)
    REG_S a1, 10*SZREG(a0)
    REG_S a1, 11*SZREG(a0)
    REG_S a1, 12*SZREG(a0)
    REG_S a1, 13*SZREG(a0)
    REG_S a1, 14*SZREG(a0)
    REG_S a1, 15*SZREG(a0)
2:  REG_S a1, 4*SZREG(a0)
    REG_S a1, 5*SZREG(a0)
    REG_S a1, 6*SZREG(a0)
    REG_S a1, 7*SZREG(a0)
3:  REG_S a1, 2*SZREG(a0)
    REG_S a1, 3*SZREG(a0)
4:  REG_S a1, 1*SZREG(a0)
5:  REG_S a1, 0*SZREG(a0)
    add a0, a0, a3
    sub a2, a2, a3
6:  bgeu a2, a5, 1b
    srli a3, a5, 1
    bgeu a2, a3, 2b
    srli a3, a3, 1
    bgeu a2, a3, 3b
    srli a3, a3, 1
    bgeu a2, a3, 4b
    srli a3, a3, 1
    bgeu a2, a3, 5b

    # handle tail misalignment
.Lmemset_bops:
    beqz a2, 1f
    add a3, a0, a2
0:  sb a1, 0(a0)
    addi a0, a0, 1
    bltu a0, a3, 0b

    # return initial a0
1:  mv a0, t6
    ret
#endif /* HAVE_RISCV_MEMSET */

#ifdef HAVE_RISCV_MEMMOVE
.globl memmove
    #
    # void *memmove(void *dst, void *src, size_t sz)
    #
    # Function copies sz bytes from memory area src to memory area dst.
    # The memory areas may overlap. Copies using 8/4/2/1 bytes load/stores
memmove:
    # save a0, s1, s0
    mv t6, a0
    mv t4, s1

    # quit if src == dst
    beq a0, a1, .Lmemmove_end

    # threshold for byte operattions
    li s1, BOPS_THRESHOLD

    # copy from the end if dst > src
    bltu a1, a0, .Lmemmove_r

    # byte-by-byte copying if sz is less than threshold
    bltu a2, s1, .Lmemmove_1b

#if __riscv_xlen == 64
    # use 8-byte load/stores (ld/sd) if the buffers
    # are mutually aligned on an 8-byte boundary
    and a3, a0, 7
    and a4, a1, 7
    li s1, 8
    beq a3, a4, .Lmemmove_main
#endif
    # same for 4-bytes load/stores
1:  and a3, a0, 3
    and a4, a1, 3
    li s1, 4
    beq a3, a4, .Lmemmove_main
#ifdef USE_HALF_WORD_OPS
    # same for 2-bytes load/stores
1:  and a3, a0, 1
    and a4, a1, 1
    li s1, 2
    beq a3, a4, .Lmemmove_main
#endif

.Lmemmove_1b:
    # byte-by-byte copying
1:  beqz a2, .Lmemmove_end
    add a4, a0, a2
0:  lb a3, 0(a1)
    sb a3, 0(a0)
    addi a1, a1, 1
    addi a0, a0, 1
    bltu a0, a4, 0b

.Lmemmove_end:
    # restore saved registers
    mv a0, t6
    mv s1, t4
    ret

.Lmemmove_main:
    # at this point:
    # s1 = 8/4/2
    # a4 = head misaligned bytes
    beqz a4, 1f

    # handle head misalignment by byte copying
    sub a4, s1, a4
    sub a2, a2, a4
    add a5, a0, a4
0:  lb a3, 0(a1)
    sb a3, 0(a0)
    addi a1, a1, 1
    addi a0, a0, 1
    bltu a0, a5, 0b

    # calculate last address and tail misaligned bytes
1:  div a4, a2, s1
    mul a4, a4, s1
    sub a2, a2, a4
    add a4, a0, a4

#if __riscv_xlen == 64
    li a5, 8
    bne s1, a5, 1f
0:  ld a3, 0(a1)
    sd a3, 0(a0)
    add a1, a1, s1
    add a0, a0, s1
    bltu a0, a4, 0b
    j .Lmemmove_1b
#endif
1:  li a5, 4
    bne s1, a5, 1f
0:  lw a3, 0(a1)
    sw a3, 0(a0)
    add a1, a1, s1
    add a0, a0, s1
    bltu a0, a4, 0b
    j .Lmemmove_1b
#ifdef USE_HALF_WORD_OPS
1:  li a5, 2
    bne s1, a5, 1f
0:  lh a3, 0(a1)
    sh a3, 0(a0)
    add a1, a1, s1
    add a0, a0, s1
    bltu a0, a4, 0b
#endif
1:  j .Lmemmove_1b

.Lmemmove_r:
    # start from the end: src += sz, dst += sz
    add a0, a0, a2
    add a1, a1, a2

    # s1 = threshold for byte-by-byte copying
    bltu a2, s1, .Lmemmove_r1b

#if __riscv_xlen == 64
    # use 8-byte load/stores (ld/sd) if the buffers
    # are mutually aligned on an 8-byte boundary and
    # the buffers do not overlap too much for such copy
    and a3, a0, 7
    and a4, a1, 7
    li s1, 8
    beq a3, a4, .Lmemmove_rmain
#endif
    # same for 4-bytes load/stores
1:  and a3, a0, 3
    and a4, a1, 3
    li s1, 4
    beq a3, a4, .Lmemmove_rmain
#ifdef USE_HALF_WORD_OPS
    # same for 2-bytes load/stores
1:  and a3, a0, 1
    and a4, a1, 1
    li s1, 2
    beq a3, a4, .Lmemmove_rmain
#endif

.Lmemmove_r1b:
    # byte-by-byte copying
1:  beqz a2, .Lmemmove_end
    sub a5, a0, a2
0:  addi a1, a1, -1
    addi a0, a0, -1
    lb a3, 0(a1)
    sb a3, 0(a0)
    bgtu a0, a5, 0b
    j .Lmemmove_end

.Lmemmove_rmain:
    # s1 = 8/4/2
    # a4 = head misaligned bytes
    beqz a4, 1f

    # handle head misalignment
    sub a2, a2, a4
    sub a5, a0, a4
0:  addi a1, a1, -1
    addi a0, a0, -1
    lb a3, 0(a1)
    sb a3, 0(a0)
    bgtu a0, a5, 0b

    # calculate last address and tail misaligned bytes
1:  div a4, a2, s1
    mul a4, a4, s1
    sub a2, a2, a4
    sub a4, a0, a4

    # 8/4/2-bytes at a time copying
#if __riscv_xlen == 64
    li a5, 8
    bne s1, a5, 1f
0:  sub a1, a1, s1
    sub a0, a0, s1
    ld a3, 0(a1)
    sd a3, 0(a0)
    bltu a4, a0, 0b
    j .Lmemmove_r1b
#endif
1:  li a5, 4
    bne s1, a5, 1f
0:  sub a1, a1, s1
    sub a0, a0, s1
    lw a3, 0(a1)
    sw a3, 0(a0)
    bltu a4, a0, 0b
    j .Lmemmove_r1b
#ifdef USE_HALF_WORD_OPS
1:  li a5, 2
    bne s1, a5, 1f
0:  sub a1, a1, s1
    sub a0, a0, s1
    lh a3, 0(a1)
    sh a3, 0(a0)
    bltu a4, a0, 0b
#endif
1:  j .Lmemmove_r1b

#endif /* HAVE_RISCV_MEMMOVE */