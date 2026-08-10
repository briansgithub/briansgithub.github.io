---
title: "Ben Eater's 8-Bit Computer"
summary: "A hands-on build of Ben Eater's breadboard 8-bit computer, exploring fundamental computer architecture from the ground up."
status: complete
year: 2021
technologies:
  - Digital logic
  - Breadboard prototyping
  - 74-series ICs
tags:
  - electronics
  - digital-logic
featured: false
order: 2
draft: false
placeholder: false
---

## Problem

Software abstracts away almost everything below the instruction set, which is useful for getting things done and bad for actually understanding what a CPU is doing. I wanted to see a computer work at the level of individual clock pulses, registers, and control signals — no microcontroller, no compiled toolchain standing between me and the logic.

## Approach

Ben Eater's breadboard computer builds an 8-bit architecture from discrete 74-series logic ICs across a series of breadboards: a clock module, a register file, an ALU, RAM, a program counter, and a hand-wired control unit that sequences each instruction into its constituent microinstructions. Assembling it means wiring every bus and control line by hand and watching, LED by LED, as an instruction actually executes.

## Result

A working 8-bit computer capable of running small hand-assembled programs, with every stage of execution visible on the breadboard rather than hidden inside a chip package.

## Reflection

The value of this build isn't the computer itself — it's that concepts like "the control unit asserts a signal that gates a register onto the bus" stop being sentences in a textbook and become something you watched happen, one clock cycle at a time. That mental model carried directly into later embedded work.
