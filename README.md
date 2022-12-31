# boot0-riscv

0-stage loader with relocation and lzma/lz4 decompression of payload.
Does not access any CSRs and does not use priviledge instructions.
Works in any priviledge mode. The one hart selected by lottery does
relocation and decompression. The rest harts jump to payload after boot
hart has finished his work.

## Getting started

$ make \
  CROSS_COMPILE=/opt/riscv-gcc/bin/riscv64-unknown-elf- \
  COMPRESS_ALGO="lz4" \
  RISCV_XLEN=64 \
  FW_PAYLOAD_PATH=/home/avx/xv6-riscv/kernel/kernel.bin \
  FW_PAYLOAD_CRC32=0 \
  FW_LOAD_ADDR=0x80200000 \
  FW_START_ADDR=0x80200000 \
  FW_OUT_BIN=./z_kernel.bin

## Build parameters

- FW_LOAD_ADDR : address where the payload should be loaded in memory
- FW_START_ADDR : address of entry point of payload.
  Equal to FW_LOAD_ADDR if not specified explicitly.
- FW_PAYLOAD_CRC32=1 for runtime crc32 check of decompressed payload
- COMPRESS_ALGO="lzma" : lzma algorithm (better compression)
- COMPRESS_ALGO="lz4"  : lz4 algorithm (fast decompress)
- COMPRESS_ALGO="none" : no compression is used, just relocation of payload

## QEMU

qemu-system-riscv64 ... -smp 4 --accel tcg,thread=single

## IMPORTANT

lzma from lzma packages is required, not xz-lzma

$ lzma -h

lzma 9.22 Copyright (C) 2006 Ville Koskinen
Based on LZMA SDK 9.22 Copyright (C) 1999-2011 Igor Pavlov
