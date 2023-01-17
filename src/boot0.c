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

/* 0-stage loader does relocation / decompression of payload */

#include "boot0.h"

#if defined(COMPRESS_ALGO_NONE)
# define fw_dec(in, in_size, out, max_size)     memcpy((void *)out, (void *)in, in_size)
#elif defined(COMPRESS_ALGO_LZ4)
# define LZ4_FREESTANDING       1
# define LZ4_memcpy             memcpy
# define LZ4_memset             memset
# define LZ4_memmove            memmove
# include <lz4.h>
# define fw_dec_size(in, sz)                    (FW_PAYLOAD_SIZE)
# define fw_dec(in, in_size, out, max_size)     LZ4_decompress_safe(in, out, in_size, max_size)
#elif defined(COMPRESS_ALGO_LZMA)
# include <Compiler.h>
# include <LzmaDec.h>
# define SZ_ALLOC_POOL_SIZE (16*1024)

static uchar sz_alloc_pool[SZ_ALLOC_POOL_SIZE];
static size_t sz_alloc_ated;

static void *SzAlloc(ISzAllocPtr p, size_t size)
{
    void *ret;
    (void)p;

    if (size + sz_alloc_ated > SZ_ALLOC_POOL_SIZE)
        return NULL;

    ret = &sz_alloc_pool[sz_alloc_ated];
    sz_alloc_ated += size;
    memset(ret, 0, size);

    return ret;
}

static void SzFree(ISzAllocPtr p, void *address)
{
    (void)address; (void)p;
}

size_t fw_dec_size(const char *inb, size_t sz)
{
    size_t out_sz = 0;
    int i;

    if (sz < (LZMA_PROPS_SIZE + 8))
        return 0;

    for (i = 0; i < 8; i++)
        out_sz += inb[LZMA_PROPS_SIZE + i] << (i * 8);

    return out_sz;
}

size_t fw_dec(const char *in, size_t in_size, char *out, size_t max_size)
{
    ISzAlloc g_Alloc = { SzAlloc, SzFree };
    size_t out_size = fw_dec_size(in, in_size);
    ELzmaStatus status;

    if (out_size > max_size)
        return 0;

    in_size -= LZMA_PROPS_SIZE + 8;
    if (LzmaDecode((void *)out, &out_size,
                   (const Byte *)&in[LZMA_PROPS_SIZE+8], &in_size,
                   (const Byte *)in, LZMA_PROPS_SIZE,
                   LZMA_FINISH_END, &status, (ISzAlloc *)&g_Alloc))
        return 0;

    return out_size;
}
#endif /* COMPRESS_ALGO_LZMA */

/* one hart does relocation and decompression,
   other harts wait for return value which is next jump address */
ulong c_start(ulong a0, ulong a1)
{
    ulong fw_size = FW_PAYLOAD_SIZE;
    ulong fw_pld_size = fw_pld_end - fw_pld_start;
    ulong fw_load = FW_LOAD_ADDR;
    ulong fw_jump = FW_JUMP_ADDR;

    /* sanity checks */
    if (!fw_size || !((fw_load <= fw_jump) && (fw_jump <= fw_load + fw_size)))
        return (ulong)hang;

    /* relocate itself if overlaps with target address and start again */
    if (!(((ulong)boot0_end < fw_load) || ((ulong)boot0_start >= (fw_load + fw_size)))) {
        fw_load = ALIGN(MAX(fw_load + fw_size, (ulong)boot0_end), PAGE_SIZE);
        memcpy((void *)fw_load, (void *)boot0_start, bss_start - boot0_start);
        /* reset hart lottery word for relocated data */
        *(uint *)(fw_load + (hart_lottery - boot0_start)) = 0;
        fw_jump = fw_load;
        return fw_jump;
    }

    if (!fw_dec(fw_pld_start, fw_pld_size, (void *)fw_load, fw_size))
        return (ulong)hang;

#ifdef FW_PAYLOAD_CRC32
    if (crc32((void *)fw_load, fw_size) != FW_PAYLOAD_CRC32)
        return (ulong)hang;
#endif

    return fw_jump;
}
