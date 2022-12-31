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

#include <stddef.h>

#define LONG_SZ         sizeof(long)
#define MIN(a,b)        ((a)<(b)?(a):(b))
#define LA(x)           (((long)(x)) & (LONG_SZ-1))

void *memmove(void *dst, const void * src, size_t sz)
{
    char *d = dst;
    const char *s = src;
    int reverse = dst > src;
    int n, d_la;

    if (reverse) {
        d += sz;
        s += sz;
    }

    d_la = LA(d);

    /* longs usage threshold, both src/dst same aligment */
    if (sz < 2 * LONG_SZ || d_la != LA(s))
        goto _byte;
    else if (d_la > 0) {
        if (reverse) {
            n = MIN(sz, d_la);
            sz -= n;
            while(n--) *--d = *--s;
        }
        else {
            n = MIN(sz, LONG_SZ - d_la);
            sz -= n;
            while(n--) *d++ = *s++;
        }
    }
    if (sz > LONG_SZ) {
        long *ld = (long *)(d);
        long *ls = (long *)(s);

        n = sz / LONG_SZ;
        sz -= n * LONG_SZ;

        if (reverse)
            while(n--) *--ld = *--ls;
        else
            while(n--) *ld++ = *ls++;

        d = ((char *)ld);
        s = ((char *)ls);
    }
_byte:
    if (reverse)
        while(sz--) *--d = *--s;
    else
        while(sz--) *d++ = *s++;

    return d;
}

void *memset(void *dst, int ch, size_t sz)
{
    char *d = dst;
    int n, d_la = LA(d);

    /* longs usage threshold */
    if (sz < 3 * LONG_SZ)
        goto _byte;

    if (d_la > 0) {
        n = MIN(sz, LONG_SZ - d_la);
        sz -= n;

        while(n--)
            *d++ = (char)ch;
    }
    if (sz > LONG_SZ) {
        long pn = (char)ch;
        n = LONG_SZ - 1;
        while(n--)
            pn |= pn << 8;

        n = sz / LONG_SZ;
        sz -= n * LONG_SZ;

        while(n--) {
            *(long *)d = pn;
            d += LONG_SZ;
        }
    }
_byte:
    while(sz--)
        *d++ = (char)ch;

    return d;
}

void *memcpy(void *dst, const void * src, size_t sz)
{
    return memmove(dst, src, sz);
}
