# Symbolic Byte Loader

Building on top of the Input Byte Loader, this program adds automatic label
and jump offset tracking. While x86-64 machine code still needs to be written
manually, now the most tedious part is automated. Of course, in order to do so,
we must once again write a program and calculate a bunch of jumps by hand
first. From a user perspective, this program operates the same as the Input
Byte Loader. Input is read from `stdin` and transformed output is written to
`stdout`.

## Files

| Name                              | Description                                                                          |
| --------------------------------- | ------------------------------------------------------------------------------------ |
| `symbolic-byte-loader.source.hex` | The fully commented source code for the program.                                     |
| `symbolic-byte-loader.hex`        | The generated output artifact from running the source through the Input Byte Loader. |

## Registers

| Name  | Description                                            |
| ----- | ------------------------------------------------------ |
| `r12` | Position of the start of the output in the buffer.     |
| `r13` | Cursor in the output buffer.                           |
| `r14` | Position of the start of the labels in the buffer.     |
| `r15` | Position of the start of the references in the buffer. |
| `rbp` | Total number of references found.                      |

## Memory

This program utilizes `mmap` to create a buffer in which it can prepare and
modify output before final emission. The structure of this buffer is described
below, where each row is a slice of this single buffer.

| Name       | Start        | End          | Description                                                                      |
| ---------- | ------------ | ------------ | -------------------------------------------------------------------------------- |
| Output     | `0x0`        | `0x01000000` | The buffered output string.                                                      |
| Labels     | `0x01000000` | `0x01001000` | Discovered labels with their name and position in the file.                      |
| References | `0x01001000` | `0x01081000` | Discovered references with their referenced label name and position in the file. |

## Usage

The Symbolic Byte Loader supports the following additional syntax in `.hex`
files. Note that all referenced labels expand to 32-bit displacements and
are therefore only compatible with jump instructions that accept such an
argument.

```
; Labels are declared with a prefix `:` at the start of a line, followed
; by two digits. The following declares the label `00` which will be
; referenced below.
:00    ; label 00

; ... Let's pretend there is some code in between ...

; Labels can be referenced using the `r` prefix, followed by the label
; that is being referenced. This is then expanded to a 32-bit
; displacement in the program's output.
e9 r00 ; jmp r00
```

Once your source code is prepared, it can be compiled using this program.

```shell
# Build the Symbolic Byte Loader
../0000-input-byte-loader/input-byte-loader.hex < ./symbolic-byte-loader.source.hex > ./symbolic-byte-loader.hex
chmod +x ./symbolic-byte-loader.hex

# Run the Symbolic Byte Loader on your source
./symbolic-byte-loader.hex < ./my.source.shex > my-byte-loader.hex

# Don't forget to mark your compiled file executable before trying to run it
chmod +x ./my-byte-loader.hex
```

## Exit Codes

The following exit codes can occur when running the program Symbolic Byte Loader.

| Code | Meaning                                                                                        |
| ---- | ---------------------------------------------------------------------------------------------- |
| `0`  | Success, no error occurred.                                                                    |
| `1`  | `mmap` failed.                                                                                 |
| `2`  | Reading `stdin` failed.                                                                        |
| `3`  | Output buffer overflow, the input is too big for this program to store.                        |
| `4`  | Found an invalid hexadecimal character while parsing.                                          |
| `5`  | The second character of a hexadecimal byte was `EOF`.                                          |
| `6`  | Expected a hexadecimal digit, but got `EOF`.                                                   |
| `7`  | A duplicate label definition was was found while parsing.                                      |
| `8`  | More references than the maximum amount (65,536) were used and this program cannot store them. |
| `9`  | A label was not defined.                                                                       |
| `10` | Writing to `stdout` failed.                                                                    |

## Layout

In order for the program to be able to jump to different locations,
displacements need to be calculated. To do so, the entire length and static
positions of code need to be known. After being written (with placeholder
`?? ?? ?? ??` values for jumps), these displacements can be calculated with
a bit of work.

### Sections

| File Offset | Label                       |
| ----------- | --------------------------- |
| `0xc9`      | `parse`                     |
| `0x123`     | `read_required_hex`         |
| `0x139`     | `read_required_hex_invalid` |
| `0x145`     | `read_hex`                  |
| `0x167`     | `read_hex_eof`              |
| `0x173`     | `decode_nibble`             |
| `0x193`     | `decode_nibble_invalid`     |
| `0x19f`     | `decode_nibble_digit`       |
| `0x1a2`     | `decode_nibble_char`        |
| `0x1a7`     | `read_label`                |
| `0x1cf`     | `read_reference`            |
| `0x20f`     | `read_character`            |
| `0x239`     | `read_character_success`    |
| `0x23d`     | `read_character_eof`        |
| `0x243`     | `read_comment`              |
| `0x260`     | `patch_references`          |
| `0x262`     | `patch_reference`           |
| `0x29b`     | `write_output`              |
| `0x2a9`     | `write_output_next`         |
| `0x2cd`     | `write_failure`             |
| `0x2d9`     | `write_output_success`      |
| `0x2e2`     | `mmap_failure`              |
| `0x2ee`     | `output_overflow`           |
| `0x2fa`     | `duplicate_label`           |
| `0x306`     | `reference_overflow`        |
| `0x312`     | `undefined_label`           |

### Jumps

| File Offset | Hex                 | Assembly                       | Target                      | Displacement Formula                      | Displacement Hex | Two's Complement |
| ----------- | ------------------- | ------------------------------ | --------------------------- | ----------------------------------------- | ---------------- | ---------------- |
| `0xa1`      | `0f 83 ?? ?? ?? ??` | `jae mmap_failure`             | `mmap_failure`              | `mmap_failure - (0xa1 + 6)`               | `0x23b`          | `0x0000023b`     |
| `0xc9`      | `e8 ?? ?? ?? ??`    | `call read_character`          | `read_character`            | `read_character - (0xc9 + 5)`             | `0x141`          | `0x00000141`     |
| `0xd3`      | `0f 84 ?? ?? ?? ??` | `je patch_references`          | `patch_references`          | `patch_references - (0xd3 + 6)`           | `0x187`          | `0x00000187`     |
| `0xdb`      | `0f 84 ?? ?? ?? ??` | `je parse`                     | `parse`                     | `parse - (0xdb + 6)`                      | `-0x18`          | `0xffffffe8`     |
| `0xe3`      | `0f 84 ?? ?? ?? ??` | `je parse`                     | `parse`                     | `parse - (0xe3 + 6)`                      | `-0x20`          | `0xffffffe0`     |
| `0xeb`      | `0f 84 ?? ?? ?? ??` | `je parse`                     | `parse`                     | `parse - (0xeb + 6)`                      | `-0x28`          | `0xffffffd8`     |
| `0xf3`      | `0f 84 ?? ?? ?? ??` | `je read_comment`              | `read_comment`              | `read_comment - (0xf3 + 6)`               | `0x14a`          | `0x0000014a`     |
| `0xfb`      | `0f 84 ?? ?? ?? ??` | `je read_label`                | `read_label`                | `read_label - (0xfb + 6)`                 | `0xa6`           | `0x000000a6`     |
| `0x103`     | `0f 84 ?? ?? ?? ??` | `je read_reference`            | `read_reference`            | `read_reference - (0x103 + 6)`            | `0xc6`           | `0x000000c6`     |
| `0x109`     | `e8 ?? ?? ?? ??`    | `call read_hex`                | `read_hex`                  | `read_hex - (0x109 + 5)`                  | `0x37`           | `0x00000037`     |
| `0x111`     | `0f 83 ?? ?? ?? ??` | `jae output_overflow`          | `output_overflow`           | `output_overflow - (0x111 + 6)`           | `0x1d7`          | `0x000001d7`     |
| `0x11e`     | `e9 ?? ?? ?? ??`    | `jmp parse`                    | `parse`                     | `parse - (0x11e + 5)`                     | `-0x5a`          | `0xffffffa6`     |
| `0x123`     | `e8 ?? ?? ?? ??`    | `call read_character`          | `read_character`            | `read_character - (0x123 + 5)`            | `0xe7`           | `0x000000e7`     |
| `0x12d`     | `0f 84 ?? ?? ?? ??` | `je read_required_hex_invalid` | `read_required_hex_invalid` | `read_required_hex_invalid - (0x12d + 6)` | `0x6`            | `0x00000006`     |
| `0x133`     | `e8 ?? ?? ?? ??`    | `call read_hex`                | `read_hex`                  | `read_hex - (0x133 + 5)`                  | `0xd`            | `0x0000000d`     |
| `0x145`     | `e8 ?? ?? ?? ??`    | `call decode_nibble`           | `decode_nibble`             | `decode_nibble - (0x145 + 5)`             | `0x29`           | `0x00000029`     |
| `0x14c`     | `e8 ?? ?? ?? ??`    | `call read_character`          | `read_character`            | `read_character - (0x14c + 5)`            | `0xbe`           | `0x000000be`     |
| `0x156`     | `0f 84 ?? ?? ?? ??` | `je read_hex_eof`              | `read_hex_eof`              | `read_hex_eof - (0x156 + 6)`              | `0xb`            | `0x0000000b`     |
| `0x15c`     | `e8 ?? ?? ?? ??`    | `call decode_nibble`           | `decode_nibble`             | `decode_nibble - (0x15c + 5)`             | `0x12`           | `0x00000012`     |
| `0x175`     | `0f 82 ?? ?? ?? ??` | `jb decode_nibble_invalid`     | `decode_nibble_invalid`     | `decode_nibble_invalid - (0x175 + 6)`     | `0x18`           | `0x00000018`     |
| `0x17d`     | `0f 86 ?? ?? ?? ??` | `jbe decode_nibble_digit`      | `decode_nibble_digit`       | `decode_nibble_digit - (0x17d + 6)`       | `0x1c`           | `0x0000001c`     |
| `0x185`     | `0f 82 ?? ?? ?? ??` | `jb decode_nibble_invalid`     | `decode_nibble_invalid`     | `decode_nibble_invalid - (0x185 + 6)`     | `0x8`            | `0x00000008`     |
| `0x18d`     | `0f 86 ?? ?? ?? ??` | `jbe decode_nibble_char`       | `decode_nibble_char`        | `decode_nibble_char - (0x18d + 6)`        | `0xf`            | `0x0000000f`     |
| `0x1a7`     | `e8 ?? ?? ?? ??`    | `call read_required_hex`       | `read_required_hex`         | `read_required_hex - (0x1a7 + 5)`         | `-0x89`          | `0xffffff77`     |
| `0x1b8`     | `0f 85 ?? ?? ?? ??` | `jne duplicate_label`          | `duplicate_label`           | `duplicate_label - (0x1b8 + 6)`           | `0x13c`          | `0x0000013c`     |
| `0x1ca`     | `e9 ?? ?? ?? ??`    | `jmp parse`                    | `parse`                     | `parse - (0x1ca + 5)`                     | `-0x106`         | `0xfffffefa`     |
| `0x1cf`     | `e8 ?? ?? ?? ??`    | `call read_required_hex`       | `read_required_hex`         | `read_required_hex - (0x1cf + 5)`         | `-0xb1`          | `0xffffff4f`     |
| `0x1da`     | `0f 83 ?? ?? ?? ??` | `jae reference_overflow`       | `reference_overflow`        | `reference_overflow - (0x1da + 6)`        | `0x126`          | `0x00000126`     |
| `0x1e7`     | `0f 87 ?? ?? ?? ??` | `ja output_overflow`           | `output_overflow`           | `output_overflow - (0x1e7 + 6)`           | `0x101`          | `0x00000101`     |
| `0x20a`     | `e9 ?? ?? ?? ??`    | `jmp parse`                    | `parse`                     | `parse - (0x20a + 5)`                     | `-0x146`         | `0xfffffeba`     |
| `0x21e`     | `0f 84 ?? ?? ?? ??` | `je read_character_success`    | `read_character_success`    | `read_character_success - (0x21e + 6)`    | `0x15`           | `0x00000015`     |
| `0x227`     | `0f 84 ?? ?? ?? ??` | `je read_character_eof`        | `read_character_eof`        | `read_character_eof - (0x227 + 6)`        | `0x10`           | `0x00000010`     |
| `0x243`     | `e8 ?? ?? ?? ??`    | `call read_character`          | `read_character`            | `read_character - (0x243 + 5)`            | `-0x39`          | `0xffffffc7`     |
| `0x24d`     | `0f 84 ?? ?? ?? ??` | `je patch_references`          | `patch_references`          | `patch_references - (0x24d + 6)`          | `0xd`            | `0x0000000d`     |
| `0x255`     | `0f 84 ?? ?? ?? ??` | `je parse`                     | `parse`                     | `parse - (0x255 + 6)`                     | `-0x192`         | `0xfffffe6e`     |
| `0x25b`     | `e9 ?? ?? ?? ??`    | `jmp read_comment`             | `read_comment`              | `read_comment - (0x25b + 5)`              | `-0x1d`          | `0xffffffe3`     |
| `0x264`     | `0f 83 ?? ?? ?? ??` | `jae write_output`             | `write_output`              | `write_output - (0x264 + 6)`              | `0x31`           | `0x00000031`     |
| `0x280`     | `0f 84 ?? ?? ?? ??` | `je undefined_label`           | `undefined_label`           | `undefined_label - (0x280 + 6)`           | `0x8c`           | `0x0000008c`     |
| `0x296`     | `e9 ?? ?? ?? ??`    | `jmp patch_reference`          | `patch_reference`           | `patch_reference - (0x296 + 5)`           | `-0x39`          | `0xffffffc7`     |
| `0x2ac`     | `0f 84 ?? ?? ?? ??` | `je write_output_success`      | `write_output_success`      | `write_output_success - (0x2ac + 6)`      | `0x27`           | `0x00000027`     |
| `0x2bc`     | `0f 8e ?? ?? ?? ??` | `jle write_failure`            | `write_failure`             | `write_failure - (0x2bc + 6)`             | `0xb`            | `0x0000000b`     |
| `0x2c8`     | `e9 ?? ?? ?? ??`    | `jmp write_output_next`        | `write_output_next`         | `write_output_next - (0x2c8 + 5)`         | `-0x24`          | `0xffffffdc`     |
