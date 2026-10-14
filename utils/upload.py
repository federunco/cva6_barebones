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
import struct
import sys
import time
from pathlib import Path

import serial
from elftools.elf.elffile import ELFFile
from serial.tools.miniterm import Miniterm
from tqdm import tqdm

MAGIC = 0xB007BABE
CHUNK = 1024

def main():
    parser = argparse.ArgumentParser(description="CVA6 Barebones ELF uploader")
    parser.add_argument("--elf", required=True, help="Input ELF file")
    parser.add_argument("--port", required=True, help="Device serial port (e.g. /dev/ttyUSB0 or ./uart0)")
    parser.add_argument("--baud", type=int, default=115200, help="Baudrate used for program upload")
    parser.add_argument("--timeout", type=float, default=5.0, help="Handshake timeout in seconds")
    parser.add_argument("--prg-timeout", type=float, default=5.0, help="Seconds to keep reading UART after JMP until idle")
    parser.add_argument("-i", "--interactive", action="store_true", help="Drop into interactive serial console after JMP")
    args = parser.parse_args()

    elf_path = Path(args.elf)
    if not elf_path.exists():
        raise FileNotFoundError(f"ELF file not found: {elf_path}")

    entry, segments, is_64 = load_elf(elf_path)
    ptr_fmt = "Q" if is_64 else "I"
    hdr_fmt = f"<{ptr_fmt}II"

    print(f"Detected entrypoint: 0x{entry:08x},  segments: {len(segments)}")

    with serial.Serial(args.port, args.baud, timeout=0.1) as ser:
        print("Waiting for BootROM (rst core to trigger)...")
        wait_for_string(ser, "BOOTRDY", args.timeout)

        print("Sending handshake...")
        handshake = struct.pack(f"<I{ptr_fmt}I", MAGIC, entry, len(segments))
        ser.write(handshake)
        ser.flush()

        print("Waiting for response...")
        wait_for_string(ser, "UPLDRDY", args.timeout)

        print("Upload started...")
        total_bytes = len(handshake)

        # Segment headers + segment data (what the progress bar counts)
        payload_total = sum(struct.calcsize(hdr_fmt) + seg["filesz"] for seg in segments)

        with tqdm(
            total=payload_total,
            unit="B",
            unit_scale=True,
            unit_divisor=1024,
            desc="Upload",
            dynamic_ncols=True,
        ) as bar:
            for i, seg in enumerate(segments):
                bar.set_postfix_str(f"seg {i + 1}/{len(segments)}")

                hdr = struct.pack(hdr_fmt, seg["paddr"], seg["filesz"], seg["memsz"])
                ser.write(hdr)
                bar.update(len(hdr))

                data = seg["data"]
                for off in range(0, len(data), CHUNK):
                    part = data[off:off + CHUNK]
                    ser.write(part)
                    bar.update(len(part))
                ser.flush()

                total_bytes += len(hdr) + seg["filesz"]

                # Wait for BootROM to finish copying + zeroing .bss for this segment
                bar.set_postfix_str(f"seg {i + 1}/{len(segments)}, BootROM copying")
                wait_for_string(ser, ".", args.timeout)
                bar.set_postfix_str("")
                tqdm.write(f"  -> Segment {i} loaded ({seg['filesz']} bytes sent)")

        print(f"Upload complete, {total_bytes} bytes sent.")
        print("Waiting for core to jump to RAM...")
        wait_for_string(ser, "JMP", args.timeout)

        if args.interactive:
            print("Interactive Serial Console (Press Ctrl+] to exit)")
            print("-" * 50)
            ser.timeout = None
            miniterm = Miniterm(ser, echo=False, eol="lf")
            miniterm.exit_character = "\x1d"  # Ctrl+]
            miniterm.set_rx_encoding("utf-8")
            miniterm.set_tx_encoding("utf-8")
            miniterm.start()
            try:
                miniterm.join(True)
            except KeyboardInterrupt:
                pass
            finally:
                miniterm.stop()
                print("\n" + "-" * 50)
        else:
            print("Program output:")
            print("-" * 40)
            stream_output(ser, args.prg_timeout)
            print("\n" + "-" * 40)


def load_elf(elf_path: Path):
    with elf_path.open("rb") as f:
        elf = ELFFile(f)

        if elf["e_machine"] != "EM_RISCV":
            raise ValueError(f"Expected EM_RISCV ELF, got {elf['e_machine']}")
        if not elf.little_endian:
            raise ValueError("Expected little-endian RISC-V ELF")

        is_64 = (elf.elfclass == 64)
        entry = elf.header["e_entry"]

        segments = []
        for seg in elf.iter_segments():
            if seg["p_type"] == "PT_LOAD" and seg["p_memsz"] > 0:
                segments.append({
                    "paddr": seg["p_paddr"],
                    "filesz": seg["p_filesz"],
                    "memsz": seg["p_memsz"],
                    "data": seg.data(),
                })

        if not segments:
            raise ValueError("No non-empty PT_LOAD segments found in ELF")

        return entry, segments, is_64


def wait_for_string(port, token, timeout):
    deadline = time.monotonic() + timeout
    binary_token = token.encode("ascii")
    buffer = bytearray()

    while time.monotonic() < deadline:
        chunk = port.read(1)
        if chunk:
            buffer.extend(chunk)
            if binary_token in buffer:
                return

    raise TimeoutError(f"Timeout waiting for token '{token}' (received: {bytes(buffer)!r})")


def stream_output(port, timeout):
    deadline = time.monotonic() + timeout
    while True:
        chunk = port.read(1)
        if chunk:
            sys.stdout.write(chunk.decode("utf-8", errors="replace"))
            sys.stdout.flush()

            # Drain the rest of the available bytes quickly
            if port.in_waiting > 0:
                extra = port.read(port.in_waiting)
                sys.stdout.write(extra.decode("utf-8", errors="replace"))
                sys.stdout.flush()

            deadline = time.monotonic() + timeout
        elif time.monotonic() >= deadline:
            break


if __name__ == "__main__":
    main()