OUTPUT_ARCH( "riscv" )
ENTRY( entry )

SECTIONS
{
  . = 0x80000000;

  .text : {
    PROVIDE(boot0_start = .);
    PROVIDE(stext = .);
    *(.text.startup)
    *(.text .text.*)
    . = ALIGN(8);
    *(.srodata .srodata.*)
    . = ALIGN(8);
    *(.rodata .rodata.*)
    PROVIDE(etext = .);
  }

  .data : {
    . = ALIGN(8);
    *(.sdata .sdata.*)
    . = ALIGN(8);
    *(.data .data.*)
    . = ALIGN(8);
  }

  .bss : {
    . = ALIGN(8);
    PROVIDE(bss_start = .);
    *(.sbss .sbss.*)
    . = ALIGN(8);
    *(.bss .bss.*)
    . = ALIGN(8);
    PROVIDE(bss_end = .);
    . = . + 8*1024;
    PROVIDE(stack = .);
    PROVIDE(boot0_end = .);
  }
}
