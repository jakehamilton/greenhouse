# ELF Prepender

The programs coming after this one will require many orders of magnitude more
testing and iteration. That will be difficult enough at such a low level, but
we would normally also be required to constantly update the ELF headers to
match the program's file size. Rather than doing that manually for the
foreseeable future, this program will be responsible for reading a fully
compiled program (without an ELF section), buffering it into memory,
calculating its size, and outputting the full valid ELF with the program.

## Files

| Name                | Description                            |
| ------------------- | -------------------------------------- |
| `elf-prepender.na`  | The source code for the Elf Prepender. |
| `elf-prepender.hex` | The generated output artifact.         |

## Usage

This program requires a full binary input. This means that only compiled
programs can be given to the ELF Prepender, normal source files will not
work. Perform your normal compilation on a program _without_ an ELF header,
then hand that compiled artifact off to the ELF Prepender to produce the
final executable.

```shell
# Build the ELF Prepender
../0002-numeric-assembler/numeric-assembler.hex < ./elf-prepender.na \
    | ../0001/symbolic-byte-loader/symbolic-byte-loader.hex \
    > ./elf-prepender.hex

# Do your normal compilation, then hand off to the ELF Prepender
cat ./src/*.na \
    | ../0002-numeric-assembler/numeric-assembler.hex \
    | ../0001/symbolic-byte-loader/symbolic-byte-loader.hex \
    | ./elf-prepender.hex
    > ./my-program
```

## Exit Codes

The following exit codes can occur when this program is run.

| Code | Meaning                                       |
| ---- | --------------------------------------------- |
| `0`  | Success, no error occurred.                   |
| `1`  | Failed to allocate memory with `mmap`.        |
| `2`  | Failed to read from `stdin`.                  |
| `3`  | Failed to write to `stdout`.                  |
| `4`  | Input is larger than this program can handle. |
