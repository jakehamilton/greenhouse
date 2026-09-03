# Numeric Assembler

To step beyond writing raw machine code, for the most part, and to keep things
manageable despite the x86-64 architecture's many opcode variants, the next
step involves abstracting common operations and referencing registers by number
rather than explicit name. This keeps the complexity down in this program by
allowing us to perform math operations directly on the register index rather
than having to map a string to one. Operations in this simple assembler are
declared with a single ASCII character. Again, the purpose being to keep as
much complexity out of this program as possible.

## Files

| Name                            | Description                                                                             |
| ------------------------------- | --------------------------------------------------------------------------------------- |
| `numeric-assembler.source.shex` | The symbolic source code for the program.                                               |
| `numeric-assembler.hex`         | The generated output artifact from running the source through the Symbolic Byte Loader. |

## Usage

The numeric assembler must be built with the Symbolic Byte Loader due to its
use of labels and references rather than hardcoded jump displacements. Once
compiled, it can be used to build your own Numeric Assembly files. See the
[Operations](#operations) section for what instructions are available. All
other values are emitted verbatim. Due to this, the output of the Numeric
Assembler is expected to be passed to the Symbolic Byte Loader to produce
a usable binary.

```shell
# Build the Numeric Assembler
../0001-symbolic-byte-loader/symbolic-byte-loader.hex < ./numeric-assembler.source.shex > ./numeric-assembler.hex

# Run the Numeric Assembler on a source file, handing off to the Symbolic
# Byte Loader for final compilation into an executable binary.
./numeric-assembler.hex < ./my-program.na | ../0001-symbolic-byte-loader/symbolic-byte-loader.hex > ./my-program.hex
```

## Exit Codes

The following exit codes can occur when running the Numeric Assembler.

| Code | Meaning                        |
| ---- | ------------------------------ |
| `0`  | Success, no error occurred.    |
| `1`  | Reading `stdin` failed.        |
| `2`  | Writing `stdout` failed.       |
| `3`  | Received an invalid command.   |
| `4`  | Unexpected EOF.                |
| `5`  | Invalid operand value.         |
| `6`  | Invalid hexadecimal character. |

## Registers

The Numeric Assembler supports the first 8 registers of the CPU, addressing
them by index rather than name. The following table maps the register index
to the corresponding names.

| Index | 8-byte | 4-byte | 2-byte | 1-byte |
| ----- | ------ | ------ | ------ | ------ |
| `0`   | `rax`  | `eax`  | `ax`   | `al`   |
| `1`   | `rcx`  | `ecx`  | `cx`   | `cl`   |
| `2`   | `rdx`  | `edx`  | `dx`   | `dl`   |
| `3`   | `rbx`  | `ebx`  | `bx`   | `bl`   |
| `4`   | `rsp`  | `esp`  | `sp`   |        |
| `5`   | `rbp`  | `ebp`  | `bp`   |        |
| `6`   | `rsi`  | `esi`  | `si`   |        |
| `7`   | `rdi`  | `edi`  | `di`   |        |

## Immediates

The Numeric Assembler uses most-significant-first ordering for immediate
values. See the following for syntax examples.

| Width  | Value              | Parsed              |
| ------ | ------------------ | ------------------- |
| 1-byte | `01`               | `0x01`              |
| 4-byte | `01234567`         | `0x1234567`         |
| 8-byte | `0123456701234567` | `0x123456701234567` |

## Commands

The following assembly commands are recognized and usable.

| Name                 | Character | Arguments                                         | Description                                                 |
| -------------------- | --------- | ------------------------------------------------- | ----------------------------------------------------------- |
| Load                 | `L`       | `<byte-width> <destination-register> <base>`      | Load a value from memory into a register.                   |
| Store                | `S`       | `<byte-width> <base> <source-register>`           | Store a value from a register in memory.                    |
| Move Immediate       | `I`       | `<byte-width> <register> <immediate>`             | Move an immediate value into a register.                    |
| Move Register        | `M`       | `<byte-width> <destination> <source>`             | Move a value from one register into another.                |
| Immediate Arithmetic | `A`       | `<byte-width> <operation> <register> <immediate>` | Perform arithmetic on a register and an immediate value.    |
| Register Arithmetic  | `C`       | `<byte-width> <operation> <destination> <source>` | Perform arithmetic on two registers.                        |
| Shift/Rotate         | `H`       | `<byte-width> <operation> <register> <immediate>` | Shift the bits in a register by a given amount.             |
| Branch               | `B`       | `<condition>`                                     | Conditionally branch to another part of the code.           |
| Jump                 | `J`       | `<reference>` or `<raw>`                          | Jump to another part of the code.                           |
| Call                 | `F`       | `<reference>` or `<raw>`                          | Call a function.                                            |
| Return               | `R`       | none                                              | Return from a function call.                                |
| Syscall              | `X`       | none                                              | Perform a syscall.                                          |
| Raw                  | `.`       | `[...bytes]`                                      | Pass all proceeding text through until the end of the line. |

### Arithmetic Operations

The following operations are available for arithmetic.

| Name  | Value | Description                                 |
| ----- | ----- | ------------------------------------------- |
| `add` | `0`   | Add source to destination.                  |
| `or`  | `1`   | Bitwise OR.                                 |
| `adc` | `2`   | Add source plus the carry flag.             |
| `sbb` | `3`   | Subtract source plus the carry/borrow flag. |
| `and` | `4`   | Bitwise AND.                                |
| `sub` | `5`   | Subtract source from destination.           |
| `xor` | `6`   | Bitwise XOR.                                |
| `cmp` | `7`   | Compare by subtraction.                     |

### Shift/Rotate Operations

The following operations are available for shift/rotation.

| Name        | Value | Description                              |
| ----------- | ----- | ---------------------------------------- |
| `rol`       | `0`   | Rotate bits left.                        |
| `ror`       | `1`   | Rotate bites right.                      |
| `shl`/`sal` | `4`   | Shift left, padding with zero.           |
| `shr`       | `5`   | Shift right, padding with zero.          |
| `sar`       | `7`   | Arithmetic shift right, preserving sign. |

## Layout

The following label ranges are reserved for use by their respective region of
the program.

| Range   | Purpose   |
| ------- | --------- |
| `00-0f` | Main loop |
| `10-2f` | Input     |
| `30-4f` | Output    |
| `50-6f` | Helpers   |
| `70-cf` |           |
| `d0-ff` | Errors    |
