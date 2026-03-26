OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    BROM (rx)  : ORIGIN = 0x00010000, LENGTH = 64K
    SRAM (rwx) : ORIGIN = 0x80000000, LENGTH = 18M
}

SECTIONS
{
    . = ORIGIN(BROM);

    .text : {
        KEEP(*(.text.init))
        *(.text*)
    } > BROM

    .rodata : {
        *(.rodata*)
    } > BROM

    .data (NOLOAD) : {
        *(.data*)
    } > SRAM

    .bss (NOLOAD) : {
        *(.bss*)
        *(COMMON)
    } > SRAM

    . = ALIGN(16);
    PROVIDE(end = .);
    PROVIDE(_end = .);
    PROVIDE(__end = .);
    __stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}