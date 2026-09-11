---
title: "Ben Eater's 8-Bit Computer"
summary: "A breadboard 8-bit computer from Ben Eater's design: clock, registers, ALU, 16 bytes of RAM, program counter, decimal display, and EEPROM microcode, with every bus transfer visible on LEDs."
status: complete
year: 2021
technologies:
  - Digital logic
  - Breadboard prototyping
  - 74-series ICs
  - EEPROM microcode
tags:
  - electronics
  - digital-logic
featured: false
order: 2
links:
  Design: 'https://eater.net/8bit'
  Playlist: 'https://www.youtube.com/playlist?list=PLowKtXNTBypGqImE405J2565dvjafglHU'
draft: false
placeholder: false
---

## Problem

A laptop CPU is a black box. You type a program, and answers appear. I wanted to see the same ideas at the level of clock pulses, registers, and control signals, with no microcontroller and no compiler in the way. If a light turns on, that bit is a 1. If it stays off, that bit is a 0.

## Overview

This is a build of [Ben Eater's breadboard 8-bit computer](https://eater.net/8bit), from his [playlist](https://www.youtube.com/playlist?list=PLowKtXNTBypGqImE405J2565dvjafglHU). It is made of ordinary 74LS logic chips on breadboards, not a hidden processor chip. Modules share one 8-bit bus (eight wires that carry one byte at a time) and one clock (the heartbeat that says "now"). Almost every signal has an LED, so you can watch a number move from one chip to another.

Think of the machine as a few labeled boxes that pass a slip of paper:

- **Clock:** free-run, single-step, or halt. This is the drumbeat.
- **Registers A, B, and IR:** small memories that hold one value each.
- **ALU:** the adder and subtractor, plus carry and zero flags.
- **MAR and RAM:** a 4-bit address and 16 bytes of storage for both code and data.
- **Program counter:** which RAM address to fetch next.
- **Output register and a 4-digit decimal display:** the number you can read without decoding binary by eye.
- **Control logic:** turns each instruction into a short list of on/off signals.

## Clock

A computer does not "think" continuously. It takes one tiny step on each tick of a clock.

Three 555 timer chips keep this board in step. An astable 555 free-runs from under 1 Hz (slow enough to watch) to a few hundred Hz. A monostable 555 turns the step button into exactly one pulse, so you can walk through a program the way a debugger steps one line. A bistable 555 holds the choice between run and step. Logic gates mix those sources with a halt signal (HLT). When halt is on, the clock stops.

Single-step is the teaching mode: one rising edge, then the LEDs freeze so you can read the bus and every register.

## Registers

A register is a latch: it remembers an 8-bit number until you tell it to change. A, B, and the instruction register (IR) each use two 74LS173 chips (four bits each) and a 74LS245 bus transceiver.

Two control lines decide what happens on a clock tick:

- **In:** copy whatever is on the bus into the register.
- **Out:** copy the register onto the bus.

If neither line is active, the register holds its value and stays disconnected (tri-state). That matters because eight wires are shared. Only one module may drive the bus at a time. Two drivers at once fight each other.

- **A** is the accumulator (signals AI and AO). Most answers are written back here.
- **B** only loads from the bus (BI). The ALU reads B on its own wires, so B does not need to shout onto the shared bus during math.
- **IR** loads a full instruction byte (II). When it outputs (IO), it puts only the low four bits (the address or small constant) on the bus. The high four bits are the opcode: the name of the instruction.

LED rows under each register show the live binary value.

## Arithmetic logic unit

The ALU (arithmetic logic unit) is the calculator. Here it only adds or subtracts the numbers in A and B.

Two 74LS283 adder chips sum A and B all the time. You do not "turn adding on." You decide whether the sum is allowed onto the bus. Subtracting uses a standard two's-complement trick: XOR gates flip every bit of B, and the adder gets a carry-in of 1, which is the same as computing A + (−B). The SU (subtract) line chooses that path.

EO (enable output) gates the result onto the bus. Until EO is on, the adders still run and their LEDs still show the sum. You can watch A+B before the machine decides to keep it.

Flags are two extra bits that latch when FI (flag in) is on, usually at the same moment A is written:

- **Carry:** the high adder produced a carry-out. In unsigned math that means the sum did not fit in 8 bits. Conditional jumps can use it.
- **Zero:** all eight result bits are low, so the answer is 0.

JC and JZ (jump if carry, jump if zero) read those flags. The ALU itself does not jump. It only reports what happened.

## Memory address register and RAM

This computer has 16 bytes of RAM. That is tiny, but it is enough to hold a short program and a few numbers. Four address bits choose one of those 16 slots (2⁴ = 16). Code and data share the same 16 locations.

The **memory address register (MAR)** is a 74LS173. On MI (memory address in) it loads a 4-bit address from the bus. That address points at one RAM cell.

Two 74LS189 chips hold the bytes. Their outputs are inverted, so extra inverters restore the original 0s and 1s. A 74LS245 handles RAM out (RO) and RAM in (RI). Writes happen on a clock edge, same as the registers.

74LS157 multiplexers choose who is allowed to talk to RAM:

- **Run:** the MAR and the bus, under program control.
- **Program:** DIP switches and a write button on the front of the board.

Those switches are the assembler. You set an address and an 8-bit value by hand, press write, and that byte is now in RAM.

## Program counter

The program counter (PC) is "which line of the program are we on?" A 74LS161 counter plus a 74LS245 hold a 4-bit address: the next RAM slot to fetch.

- **CO** (counter out): put the current address on the bus, usually so the MAR can copy it.
- **CE** (count enable): add one after an instruction byte is read, so the next fetch is the next address.
- **J** (jump): load the PC from the bus. JMP, JC, and JZ use this to skip or repeat.

Reset clears the PC to `0000`, so a new run always starts at the first address. Four bits are enough, because there are only 16 addresses.

## Output register

Humans do not read binary rows quickly. The output register gives the machine a place to show a result.

A 74LS273 loads a byte from the bus when OI (output in) is on. The OUT instruction copies A here.

A 28C16 EEPROM (a small read-only lookup table you can program once) maps that stored byte, plus which digit is being drawn, onto seven-segment patterns. A 555 timer and a 74LS139 switch among four digits fast enough that the eye sees one stable number. The table can show unsigned values 0 to 255 or signed values −128 to 127. An Arduino programmer writes this EEPROM, and later the control-store chips.

## Bus

The bus is eight copper tracks, pull resistors, and a row of LEDs. It has no intelligence. Correctness is simply: which 74LS245 is enabled right now?

- Two drivers at once is a short (contention): dim LEDs, warm chips.
- No driver: the resistors pull the wires to a default idle level.
- One driver: the LEDs show that module's number.

On a fetch you see the program-counter address, then the instruction byte from RAM. On ADD you see the operand, then the ALU result. The lights are the lesson.

## Control logic

An instruction such as ADD is not one action. It is a short recipe: put the PC on the bus, copy it into the MAR, read RAM into the instruction register, bump the PC, load B, add, write A, update flags.

A 74LS161 counts those recipe steps (T-states). A 74LS138 decodes the step number. The current opcode, the step, and the flags become the address into two or three 28C16 EEPROMs. Each address outputs one **control word**: a bundle of bits named HLT, MI, RI, RO, IO, II, AI, AO, EO, SU, BI, OI, CE, CO, J, FI, and later extras. Those bits are the puppet strings. They are stored active-low; a row of LEDs shows which strings are pulled on this tick.

A typical instruction takes five or six microsteps: PC to MAR, RAM to IR and increment the PC, an optional idle step, then the execute steps. LDA sends the address stored in the IR to the MAR and loads A from that RAM cell. ADD first loads B from RAM, then EO, AI, and FI write A+B into A and refresh the flags. HLT asserts the halt line and the clock stops.

That EEPROM table is the microcode. Adding STA, LDI, JMP, JC, and JZ meant programming new rows, not wiring a new board. Jumps make loops possible. Reset clears both the PC and the step counter so the next run starts at address zero in a fetch.

## Instruction set

Each instruction is one byte. The high nibble (four bits) is the opcode. The low nibble is a RAM address or a 4-bit immediate value (a tiny constant baked into the instruction).

| Opcode | Name | Effect                                           |
| ------ | ---- | ------------------------------------------------ |
| `0000` | NOP  | Fetch only. Do nothing else.                     |
| `0001` | LDA  | Load A from RAM at the operand address.          |
| `0010` | ADD  | Load B from RAM, then A = A+B, and update flags. |
| `0011` | SUB  | Load B from RAM, then A = A-B, and update flags. |
| `0100` | STA  | Store A at the operand address.                  |
| `0101` | LDI  | Load A with the 4-bit immediate.                 |
| `0110` | JMP  | Set the PC to the operand address.               |
| `0111` | JC   | Jump if the carry flag is set.                   |
| `1000` | JZ   | Jump if the zero flag is set.                    |
| `1110` | OUT  | Copy A to the output register.                   |
| `1111` | HLT  | Stop the clock.                                  |

Programs and data share the 16 RAM locations. You key both in on the DIP switches.

## Result

A working 8-bit computer that runs those opcodes on the breadboard. Fetch and execute stay visible on LEDs, so you can follow one instruction across the bus instead of trusting a simulator.

## Reflection

The value is not the machine. It is watching a control line gate a register onto the bus, one clock at a time. That model carried into later embedded work.

## Sources

- [Build an 8-bit computer](https://eater.net/8bit), including the [module schematics](https://eater.net/8bit/schematics).
- [Building an 8-bit breadboard computer](https://www.youtube.com/playlist?list=PLowKtXNTBypGqImE405J2565dvjafglHU), Ben Eater's playlist.
