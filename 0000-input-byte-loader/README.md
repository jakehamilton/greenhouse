# Input Byte Loader

To start from "scratch", we will need to write machine code by hand.
Unfortunately, this means the contents of the file can't also contain things
like comments. To keep things maintainable rather than staring at walls of
numbers, the first programs in the bootstrap are focused on stripping comments
to create raw binary files from ASCII input. This program does so by reading
from `stdin` and writing to `stdout`, omitting everything from `;` to the end
of a line when it appears.

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

| Label                | File Offset |
| -------------------- | ----------- |
| read_high_nibble     | 0x84        |
| high_read_failure    |             |
| high_read_success    |             |
| high_read_eof        |             |
| read_high_digit      |             |
| read_high_char       |             |
| high_invalid         |             |
| store_high           |             |
| read_low_nibble      |             |
| low_read_failure     |             |
| low_read_success     |             |
| low_read_eof         |             |
| low_invalid          |             |
| low_whitespace       |             |
| low_comment          |             |
| read_low_digit       |             |
| read_low_char        |             |
| merge_and_write      |             |
| write_failure        |             |
| read_comment         |             |
| comment_read_failure |             |
| comment_read_success |             |
| comment_read_eof     |             |
