# Input Byte Loader

To start from "scratch", we will need to write machine code by hand.
Unfortunately, this means the contents of the file can't also contain things
like comments. To keep things maintainable rather than staring at walls of
numbers, the first programs in the bootstrap are focused on stripping comments
to create raw binary files from ASCII input. This program does so by reading
from `stdin` and writing to `stdout`, omitting everything from `;` to the end
of a line when it appears.

## Files

| Name                           | Description                                                                              |
| ------------------------------ | ---------------------------------------------------------------------------------------- |
| `input-byte-loader.source.hex` | The fully commented source code for the program.                                         |
| `input-byte-loader.golden.hex` | The original handwritten binary output used for testing against newly generated outputs. |
| `input-byte-loader.hex`        | The generated output artifact from running the program on its source code.               |

## Exit Codes

It is possible for this program to fail due to an underlying file read error or
invalid data. In these cases, a specific exit code is supplied according to the
following table.

| Code | Meaning                                                                         |
| ---- | ------------------------------------------------------------------------------- |
| 0    | Success, no error occurred.                                                     |
| 1    | Reading `stdin` to get the high nibble of a byte failed.                        |
| 2    | The first character of a hexadecimal byte was not in the range `0-9` or `a-f`.  |
| 3    | Reading `stdin` to get the low nibble of a byte failed.                         |
| 4    | Reading `stdin` to get the low nibble of a byte resulted in `EOF`.              |
| 5    | The second character of a hexadecimal byte was not in the range `0-9` or `a-f`. |
| 6    | The second character of a hexadecimal byte was whitespace.                      |
| 7    | The second character of a hexadecimal byte was a semicolon.                     |
| 8    | Writing `stdout` failed.                                                        |
| 9    | Reading `stdin` to get comment contents failed.                                 |

## Layout

In order for the program to be able to jump to different locations,
displacements need to be calculated. To do so, the entire length and static
positions of code need to be known. After being written (with placeholder
`?? ?? ?? ??` values for jumps), these displacements can be calculated with
a bit of work.

### Sections

| File Offset | Label                |
| ----------- | -------------------- |
| `0x84`      | read_high_nibble     |
| `0xa2`      | high_read_failure    |
| `0xae`      | high_read_eof        |
| `0xba`      | high_read_success    |
| `0xfd`      | high_invalid         |
| `0x109`     | read_high_digit      |
| `0x110`     | read_high_char       |
| `0x114`     | store_high           |
| `0x116`     | read_low_nibble      |
| `0x134`     | low_read_failure     |
| `0x140`     | low_read_eof         |
| `0x14c`     | low_read_success     |
| `0x18f`     | low_invalid          |
| `0x19b`     | low_whitespace       |
| `0x1a7`     | low_comment          |
| `0x1b3`     | read_low_digit       |
| `0x1ba`     | read_low_char        |
| `0x1be`     | merge_and_write      |
| `0x1db`     | write_failure        |
| `0x1e7`     | read_comment         |
| `0x205`     | comment_read_failure |
| `0x211`     | comment_read_eof     |
| `0x21d`     | comment_read_success |

### Jumps

| File Offset | Hex                 | Assembly                  | Target                 | Displacement Formula                 | Displacement Hex | Two's Complement |
| ----------- | ------------------- | ------------------------- | ---------------------- | ------------------------------------ | ---------------- | ---------------- |
| `0x93`      | `0f 84 ?? ?? ?? ??` | `je high_read_success`    | `high_read_success`    | `high_read_success - (0x93 + 6)`     | `0x21`           | `0x00000021`     |
| `0x9c`      | `0f 84 ?? ?? ?? ??` | `je high_read_eof`        | `high_read_eof`        | `high_read_eof - (0x9c + 6)`         | `0xc`            | `0x0000000c`     |
| `0xbf`      | `0f 84 ?? ?? ?? ??` | `je read_high_nibble`     | `read_high_nibble`     | `read_high_nibble - (0xbf + 6)`      | `-0x41`          | `0xffffffbf`     |
| `0xc7`      | `0f 84 ?? ?? ?? ??` | `je read_high_nibble`     | `read_high_nibble`     | `read_high_nibble - (0xc7 + 6)`      | `-0x49`          | `0xffffffb7`     |
| `0xcf`      | `0f 84 ?? ?? ?? ??` | `je read_high_nibble`     | `read_high_nibble`     | `read_high_nibble - (0xcf + 6)`      | `-0x51`          | `0xffffffaf`     |
| `0xd7`      | `0f 84 ?? ?? ?? ??` | `je read_comment`         | `read_comment`         | `read_comment - (0xd7 + 6)`          | `0x10a`          | `0x0000010a`     |
| `0xdf`      | `0f 82 ?? ?? ?? ??` | `jb high_invalid`         | `high_invalid`         | `high_invalid - (0xdf + 6)`          | `0x18`           | `0x00000018`     |
| `0xe7`      | `0f 86 ?? ?? ?? ??` | `jbe read_high_digit`     | `read_high_digit`      | `read_high_digit - (0xe7 + 6)`       | `0x1c`           | `0x0000001c`     |
| `0xef`      | `0f 82 ?? ?? ?? ??` | `jb high_invalid`         | `high_invalid`         | `high_invalid - (0xef + 6)`          | `0x8`            | `0x00000008`     |
| `0xf7`      | `0f 86 ?? ?? ?? ??` | `jbe read_high_char`      | `read_high_char`       | `read_high_char - (0xf7 + 6)`        | `0x13`           | `0x00000013`     |
| `0x10b`     | `e9 ?? ?? ?? ??`    | `jmp store_high`          | `store_high`           | `store_high - (0x10b + 5)`           | `0x4`            | `0x00000004`     |
| `0x125`     | `0f 84 ?? ?? ?? ??` | `je low_read_success`     | `low_read_success`     | `low_read_success - (0x125 + 6)`     | `0x21`           | `0x00000021`     |
| `0x12e`     | `0f 84 ?? ?? ?? ??` | `je low_read_eof`         | `low_read_eof`         | `low_read_eof - (0x12e + 6)`         | `0xc`            | `0x0000000c`     |
| `0x151`     | `0f 84 ?? ?? ?? ??` | `je low_whitespace`       | `low_whitespace`       | `low_whitespace - (0x151 + 6)`       | `0x44`           | `0x00000044`     |
| `0x159`     | `0f 84 ?? ?? ?? ??` | `je low_whitespace`       | `low_whitespace`       | `low_whitespace - (0x159 + 6)`       | `0x3c`           | `0x0000003c`     |
| `0x161`     | `0f 84 ?? ?? ?? ??` | `je low_whitespace`       | `low_whitespace`       | `low_whitespace - (0x161 + 6)`       | `0x34`           | `0x00000034`     |
| `0x169`     | `0f 84 ?? ?? ?? ??` | `je low_comment`          | `low_comment`          | `low_comment - (0x169 + 6)`          | `0x38`           | `0x00000038`     |
| `0x171`     | `0f 82 ?? ?? ?? ??` | `jb low_invalid`          | `low_invalid`          | `low_invalid - (0x171 + 6)`          | `0x18`           | `0x00000018`     |
| `0x179`     | `0f 86 ?? ?? ?? ??` | `jbe read_low_digit`      | `read_low_digit`       | `read_low_digit - (0x179 + 6)`       | `0x34`           | `0x00000034`     |
| `0x181`     | `0f 82 ?? ?? ?? ??` | `jb low_invalid`          | `low_invalid`          | `low_invalid - (0x181 + 6)`          | `0x8`            | `0x00000008`     |
| `0x189`     | `0f 86 ?? ?? ?? ??` | `jbe read_low_char`       | `read_low_char`        | `read_low_char - (0x189 + 6)`        | `0x2b`           | `0x0000002b`     |
| `0x1b5`     | `e9 ?? ?? ?? ??`    | `jmp merge_and_write`     | `merge_and_write`      | `merge_and_write - (0x1b5 + 5)`      | `0x4`            | `0x00000004`     |
| `0x1d5`     | `0f 84 ?? ?? ?? ??` | `je read_high_nibble`     | `read_high_nibble`     | `read_high_nibble - (0x1d5 + 6)`     | `-0x157`         | `0xfffffea9`     |
| `0x1f6`     | `0f 84 ?? ?? ?? ??` | `je comment_read_success` | `comment_read_success` | `comment_read_success - (0x1f6 + 6)` | `0x21`           | `0x00000021`     |
| `0x1ff`     | `0f 84 ?? ?? ?? ??` | `je comment_read_eof`     | `comment_read_eof`     | `comment_read_eof - (0x1ff + 6)`     | `0xc`            | `0x0000000c`     |
| `0x222`     | `0f 84 ?? ?? ?? ??` | `je read_high_nibble`     | `read_high_nibble`     | `read_high_nibble - (0x222 + 6)`     | `-0x1a4`         | `0xfffffe5c`     |
| `0x228`     | `e9 ?? ?? ?? ??`    | `jmp read_comment`        | `read_comment`         | `read_comment - (0x228 + 5)`         | `-0x46`          | `0xffffffba`     |
