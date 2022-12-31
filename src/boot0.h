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

#ifndef __BOOT0_H__
#define __BOOT0_H__

#include <stddef.h>

#define PAGE_SIZE       4096
#define MAX(a,b)        ((a)>(b)?(a):(b))
#define ALIGN(x, a)     (((x) + (a) - 1) & ~((a) - 1))

typedef unsigned long ulong;
typedef unsigned int uint;
typedef unsigned char uchar;

/* boot0.ld, entry.S */
extern uchar boot0_start[], boot0_end[], hang[],
             bss_start[], hart_lottery[];

/* fw_pld.S */
extern const char fw_pld_start[], fw_pld_end[];

/* memcpy.c */
void *memmove(char *dst, const char * src, ulong sz);
void *memcpy(char *dst, const char * src, ulong sz);
void *memset(char *dst, int ch, ulong sz);

#ifdef FW_PAYLOAD_CRC32
/* crc32.c */
uint crc32(uchar *buf, uint len);
#endif

#endif
