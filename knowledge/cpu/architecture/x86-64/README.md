# x86-64 CPU Architecture

At the time of writing, x86-64 is the most common architecture for devices.
Due to its success and evolutionary nature over the course of its existence,
it has accrued a lot of baggage. Because of this, some features can seem
strange. Still, hopefully the documentation here helps!

::: note
This document does not contain information on all x86-64 features. Rather, it
is intended to contain the information needed for Greenhouse. If you want to
dig deeper, more information can be found elsewhere!
:::

## Registers

An x86-64 CPU has the following general purpose registers. Note that the same
64-bit register can be addressed as just the low 32, 16, or 8 bits depending
on what is by the program.

| Number | 64-bit | 32-bit | 16-bit | 8-bit  | Description                                       |
| ------ | ------ | ------ | ------ | ------ | ------------------------------------------------- |
| 0      | `rax`  | `eax`  | `ax`   | `al`   | Return value, syscall number, accumulator.        |
| 1      | `rbx`  | `ebx`  | `bx`   | `bl`   | Callee-saved general register.                    |
| 2      | `rcx`  | `ecx`  | `cx`   | `cl`   | Count, caller-saved, clobbered by syscall.        |
| 3      | `rdx`  | `edx`  | `dx`   | `dl`   | Data, high product/remainder, syscall argument 3. |
| 4      | `rsi`  | `esi`  | `si`   | `sil`  | Source pointer, syscall argument 2.               |
| 5      | `rdi`  | `edi`  | `di`   | `dil`  | Destination pointer, syscall argument 1.          |
| 6      | `rbp`  | `ebp`  | `bp`   | `bpl`  | Optional frame pointer, callee-saved.             |
| 7      | `rsp`  | `esp`  | `sp`   | `spl`  | Stack pointer.                                    |
| 8      | `r8`   | `r8d`  | `r8w`  | `r8b`  | Syscall argument 5.                               |
| 9      | `r9`   | `r9d`  | `r9w`  | `r9b`  | Syscall argument 6.                               |
| 10     | `r10`  | `r10d` | `r10w` | `r10b` | Syscall argument 4.                               |
| 11     | `r11`  | `r11d` | `r11w` | `r11b` | Caller-saved, clobbered by syscall.               |
| 12     | `r12`  | `r12d` | `r12w` | `r12b` | Callee-saved.                                     |
| 13     | `r13`  | `r13d` | `r13w` | `r13b` | Callee-saved.                                     |
| 14     | `r14`  | `r14d` | `r14w` | `r14b` | Callee-saved.                                     |
| 15     | `r15`  | `r15d` | `r15w` | `r15b` | Callee-saved.                                     |

When writing a 32-bit register, the upper 32 bits of the corresponding 64-bit
register are automatically zeroed. This does _not_ apply to 16-bit or 8-bit
registers, those leave the remaining data untouched when operated on.

### Special Registers

- `rip` is the instruction pointer, determining what is executed.
- `rflags` contains condition and control flags.
- `fs` and `gs` can be used to provide thread-local addressing.
- `xmm0` through `xmm15` are 128-bit registers for use with SIMD operations.

## Stack

The stack grows downwards, toward lower addresses. Pushing value from a register
to the stack effectively subtracts the data's size from the current stack
pointer, assigns that value to the stack pointer, and then writes the data.

## Addresses

The effective address is produced with the following formula where `scale` is
`1`, `2`, `4`, or `8`.

```
base + (index * scale) + displacement
```

Static data in position-independent code is typically fetched using
instruction pointer-relative addresses.

```asm
lea rsi, [rip + message]
```
