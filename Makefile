RISCV_XLEN ?= 64

ifeq ($(RISCV_XLEN), 32)
RISCV_ABI = ilp32
RISCV_ISA = rv32imafdc_zicsr_zifencei
RISCV_CODE_MODEL = medany
else
RISCV_ABI = lp64
RISCV_ISA = rv64imafdc_zicsr_zifencei
RISCV_CODE_MODEL = medany
endif

build_dir = $(CURDIR)/build

ifneq ($(MAKECMDGOALS), clean)
ifeq ($(FW_PAYLOAD_PATH), )
$(error please specify FW_PAYLOAD_PATH)
endif

ifeq ($(FW_LOAD_ADDR), )
$(error please specify FW_LOAD_ADDR)
endif
endif

ifeq ($(FW_JUMP_ADDR), )
FW_JUMP_ADDR = $(FW_LOAD_ADDR)
endif

FW_PAYLOAD_CRC32 ?= 0

ifeq ($(FW_OUT_BIN), )
FW_OUT_BIN = $(build_dir)/boot0_`basename $(FW_PAYLOAD_PATH)`
endif

ifeq ($(CROSS_COMPILE), )
CROSS_COMPILE = riscv64-unknown-elf-
endif

HOSTCC = gcc
HOST_CFLAGS = -O2 -Wall -Werror -Isrc -Ihostapp

CC = $(CROSS_COMPILE)gcc
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
SIZE = $(CROSS_COMPILE)size

CFLAGS = -Wall -Werror -Os -fno-omit-frame-pointer -g3 -ggdb -gdwarf-2
CFLAGS += -mcmodel=$(RISCV_CODE_MODEL) -mabi=$(RISCV_ABI) -march=$(RISCV_ISA)
CFLAGS += -ffreestanding -fno-common -nostdlib -fno-builtin -mrelax -fstack-usage
CFLAGS += -fdata-sections -ffunction-sections -I$(build_dir) -Isrc
CFLAGS += -DFW_LOAD_ADDR=$(FW_LOAD_ADDR) -DFW_JUMP_ADDR=$(FW_JUMP_ADDR)
CFLAGS += --include=fw_pld.h --save-temps

LDFLAGS = --gc-sections --relax

COMPRESS_ALGO ?= lz4

ifeq ($(COMPRESS_ALGO), lz4)
CFLAGS += -DCOMPRESS_ALGO_LZ4
endif

ifeq ($(COMPRESS_ALGO), lzma)
CFLAGS += -DCOMPRESS_ALGO_LZMA
endif

ifeq ($(COMPRESS_ALGO), none)
CFLAGS += -DCOMPRESS_ALGO_NONE
endif

OBJS  = $(build_dir)/entry.o
OBJS += $(build_dir)/boot0.o
OBJS += $(build_dir)/memops.o
ifeq ($(FW_PAYLOAD_CRC32), 1)
OBJS += $(build_dir)/crc32.o
endif
ifeq ($(COMPRESS_ALGO), lzma)
OBJS += $(build_dir)/LzmaDec.o
endif
ifeq ($(COMPRESS_ALGO), lz4)
OBJS += $(build_dir)/lz4.o
endif
OBJS += $(build_dir)/fw_pld.o

LDSCRIPT = src/boot0.ld

$(FW_OUT_BIN): $(build_dir)/boot0 $(build_dir)/crc32
	@$(OBJDUMP) -St $(build_dir)/boot0 > $(build_dir)/boot0.dis
	@$(OBJCOPY) -O binary $(build_dir)/boot0 $(FW_OUT_BIN)
	@echo ""
	@$(SIZE) $(build_dir)/boot0
	@echo ""
ifeq ($(FW_PAYLOAD_CRC32), 1)
	@echo    "payload crc32      : 0x`$(build_dir)/crc32 $(FW_PAYLOAD_PATH)`"
endif
	@stat -c "payload            : %s bytes" $(FW_PAYLOAD_PATH)
	@stat -c "compressed payload : %s bytes" $(build_dir)/fw_pld.bin
	@stat -c "boot0+comp.payload : %s bytes" $(FW_OUT_BIN)
	@echo ""
	@echo "Output ELF file    : $(build_dir)/boot0"
	@echo "Output binary file : $(FW_OUT_BIN)"
	@echo ""

$(build_dir)/boot0: $(build_dir)/fw_pld.h $(OBJS) $(LDSCRIPT)
#	@$(LD) $(LDFLAGS) -T $(LDSCRIPT) -Map=$(build_dir)/boot0.map -static --gc-sections -o $@ $(OBJS)
	@echo "ld boot0..."
	@$(CC) $(CFLAGS) -Wl,-T $(LDSCRIPT) -Wl,-Map=$(build_dir)/boot0.map -Wl,--gc-sections -o $@ $(OBJS)

$(build_dir)/%.o: src/%.c
	@mkdir -p $(build_dir)
	@echo "cc `basename $^`..."
	@$(CC) $(CFLAGS) $^ -c -o $@

$(build_dir)/%.o: src/%.S
	@mkdir -p $(build_dir)
	@echo "as `basename $^`..."
	@$(CC) $(CFLAGS) $^ -c -o $@

$(build_dir)/fw_pld.o: $(build_dir)/fw_pld.bin src/fw_pld.S
	@mkdir -p $(build_dir)
	@echo "as `basename $^`..."
	@$(CC) $(CFLAGS) -DFW_PLD_BIN=\"$(build_dir)/fw_pld.bin\" src/fw_pld.S -c -o $@

$(build_dir)/fw_pld.h: $(build_dir)/fw_pld.bin $(build_dir)/crc32
	@echo "#define FW_PAYLOAD_SIZE (`stat -c '%s' $(FW_PAYLOAD_PATH)`UL)" > $(build_dir)/fw_pld.h
ifeq ($(FW_PAYLOAD_CRC32), 1)
	@echo "#define FW_PAYLOAD_CRC32 0x`$(build_dir)/crc32 $(FW_PAYLOAD_PATH)`" >> $(build_dir)/fw_pld.h
endif

$(build_dir)/fw_pld.bin: $(FW_PAYLOAD_PATH) $(build_dir)/lz4c
	@mkdir -p $(build_dir)
ifeq ($(COMPRESS_ALGO), lzma)
	lzma -z -k -c $(FW_PAYLOAD_PATH) > $(build_dir)/fw_pld.bin
endif
ifeq ($(COMPRESS_ALGO), lz4)
	$(build_dir)/lz4c $(FW_PAYLOAD_PATH) $(build_dir)/fw_pld.bin
endif
ifeq ($(COMPRESS_ALGO), none)
	@cp $(FW_PAYLOAD_PATH) $(build_dir)/fw_pld.bin
endif

$(build_dir)/crc32: hostapp/crc32.c src/crc32.c
ifeq ($(FW_PAYLOAD_CRC32), 1)
	@echo "hostcc crc32.c..."
	@$(HOSTCC) $(HOST_CFLAGS) $^ -o $@
else
	@touch $@
endif

$(build_dir)/lz4c: hostapp/lz4c.c src/lz4.c src/lz4hc.c
	@mkdir -p $(build_dir)
ifeq ($(COMPRESS_ALGO), lz4)
	@echo "hostcc lz4c.c..."
	@$(HOSTCC) $(HOST_CFLAGS) $^ -o $@
else
	@touch $@
endif

clean:
	rm -rf $(build_dir)

qemuM:
	qemu-system-riscv$(RISCV_XLEN) -M virt -nographic -smp 4 -bios $(FW_OUT_BIN) -s --accel tcg,thread=single -d in_asm -D qemu.log

qemuS:
	qemu-system-riscv$(RISCV_XLEN) -M virt -nographic -smp 4 -kernel $(FW_OUT_BIN) -s --accel tcg,thread=single -d in_asm -D qemu.log

.PHONY: clean qemu
