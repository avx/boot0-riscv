    .section .rodata
    .global fw_pld_start, fw_pld_end
fw_pld_start:
    .incbin FW_PLD_BIN
fw_pld_end:
