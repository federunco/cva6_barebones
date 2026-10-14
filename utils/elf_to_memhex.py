# Copyright 2026 Federico Runco (federico.runco@gmail.com)
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# 
# Licensed under the Solderpad Hardware License v2.1 (the “License”); 
# you may not use this file except in compliance with the License, or, 
# at your option, the Apache License version 2.0. You may obtain a copy 
# of the License at https://solderpad.org/licenses/SHL-2.1/
# 
# Unless required by applicable law or agreed to in writing, any work 
# distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
# License for the specific language governing permissions and limitations 
# under the License.

import argparse

from elftools.elf.elffile import ELFFile

def parse_base(text):
    return None if text == "auto" else int(text, 0)


def main():
    p = argparse.ArgumentParser(description="ELF to $readmemh hex")
    p.add_argument("--elf", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--base", type=parse_base, default=0x8000_0000,
                   help="Physical address of mem[0], or 'auto' for the lowest "
                        "loaded address (default 0x80000000)")
    p.add_argument("--word-bytes", type=int, default=8,
                   help="Bytes per memory word (default 8 = 64-bit)")
    p.add_argument("--no-bss", action="store_true",
                   help="Do not extend the image to cover .bss (p_memsz > p_filesz)")
    args = p.parse_args()

    with open(args.elf, "rb") as f:
        elf = ELFFile(f)
        if elf["e_machine"] != "EM_RISCV" or not elf.little_endian:
            raise ValueError("Expected little-endian RISC-V ELF")
        entry = elf.header["e_entry"]
        segs = [(s["p_paddr"], s["p_filesz"], s["p_memsz"], s.data())
                for s in elf.iter_segments()
                if s["p_type"] == "PT_LOAD" and s["p_memsz"] > 0]

    if not segs:
        raise ValueError("No PT_LOAD segments found")

    wb = args.word_bytes
    low = min(pa for pa, _, _, _ in segs)
    end = max(pa + (fsz if args.no_bss else msz) for pa, fsz, msz, _ in segs)

    base = (low & ~(wb - 1)) if args.base is None else args.base
    if low < base:
        raise ValueError(f"Segment at 0x{low:x} is below --base 0x{base:x}")

    size = ((end - base + wb - 1) // wb) * wb
    image = bytearray(size)                      # zero-filled

    for pa, fsz, _, data in segs:
        off = pa - base
        image[off:off + fsz] = data

    with open(args.out, "w") as out:
        for i in range(0, size, wb):
            word = int.from_bytes(image[i:i + wb], "little")
            out.write(f"{word:0{wb * 2}x}\n")

if __name__ == "__main__":
    main()