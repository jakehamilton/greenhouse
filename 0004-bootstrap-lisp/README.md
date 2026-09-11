# Bootstrap Lisp

Finally, a real programming language! Well, after this program is complete. The
goal is to write the last bit of Numeric Assembler and machine code needed to
create a usable Lisp interpreter. This interpreter reads from `stdin` and can
write to `stdout`. For this first step, memory is statically allocated in a
single large buffer and a bump allocator is used to slice it up for use.
Programs written in Bootstrap Lisp need to carefully consider memory usage and
stack usage, though several tail-call cases are optimized where possible.

## Files

The Bootstrap Lisp source is broken into multiple files in `./src` to keep
it manageable. These are intended to be concatenated in order before providing
the combined source to the Numeric Assembler and following compilation stages.

## Usage

The Bootstrap Lisp program is the first program in the repository to not check
its compiled artifact in to Git. Because of this, it must be built first. Once
the interpreter is compiled, your Bootstrap Lisp code can be piped into it for
evaluation.

```shell
# Build the Bootstrap Lisp interpreter
cat ./src/*.na \
    | ../0002-numeric-assembler/numeric-assembler.hex \
    | ../0001-symbolic-byte-loader/symbolic-byte-loader.hex \
    | ../0003-elf-prepender/elf-prepender.hex \
    > ./bootstrap-lisp

# Don't forget to make it executable
chmod +x ./bootstrap-lisp

# Pass your source code to the interpreter
./bootstrap-lisp < ./code.bl

# Typically you will want to prefix your code with the provided prelude
cat ./src/prelude.bl ./code.bl | ./bootstrap-lisp
```

## Builtins

Bootstrap Lisp provides a small set of builtin functions, accessed using `#`
followed by a two digit hexadecimal ID. A prelude in`./src/prelude.bl` is
provided for convenience, including bindings for builtins as well as common
functionality.

```lisp
; Call a builtin directly
(#00 0x1 0x2)

; Bind and then call
(let cons #00)
(cons 0x1 0x2)
```

The following bultins are available.

| ID    | Name                 | Arguments                 | Description                                             |
| ----- | -------------------- | ------------------------- | ------------------------------------------------------- |
| `#00` | `cons`               | `first`, `second`         | Creates a new pair holding both values.                 |
| `#01` | `car`                | `pair`                    | Gets the first item in a pair.                          |
| `#02` | `cdr`                | `pair`                    | Gets the second item in a pair                          |
| `#03` | `set/car`            | `pair`, `value`           | Sets the first item in a pair.                          |
| `#04` | `set/cdr`            | `pair`, `value`           | Sets the second item in a pair.                         |
| `#05` | `eq?`                | `a`, `b`                  | Checks whether the two values are the same.             |
| `#06` | `type-of`            | `value`                   | Gets the type ID of a value.                            |
| `#07` | `integer-op`         | `operation`, `a`, `b`     | Runs an operation with the provided arguments.          |
| `#08` | `create-byte-vector` | `length`, `fill-byte`     | Create a new byte vector.                               |
| `#09` | `byte-vector-length` | `vector`                  | Gets the length of a byte vector.                       |
| `#0a` | `byte-vector-at`     | `vector`, `index`         | Gets the byte at a specific index in a byte vector.     |
| `#0b` | `set/byte-vector`    | `vector`, `index`, `byte` | Set a byte in a byte vector.                            |
| `#0c` | `byte-vector=?`      | `a`, `b`                  | Checks whether two byte vectors have the same contents. |
| `#0d` | `intern`             | `name`                    | Returns a symbol for the given name.                    |
| `#0e` | `symbol-name`        | `symbol`                  | Gets the name of a symbol as a byte vector.             |
| `#0f` | `read-byte`          |                           | Gets the next byte from `stdin` (or EOF).               |
| `#10` | `write-byte`         | `file`, `byte`            | Writes a byte to the given file.                        |
| `#11` | `exit`               | `status`                  | Exit with a given status code.                          |
| `#12` | `eof`                |                           | Returns the `eof` value.                                |

### Types

The `type-of` builtin returns one of the following numeric IDs. These are
separate from the tags used to represent values in memory.

| ID    | Type                                   |
| ----- | -------------------------------------- |
| `0x0` | `false`, `nil`, `()`                   |
| `0x1` | `true`                                 |
| `0x2` | Number                                 |
| `0x3` | Builtin function                       |
| `0x4` | Pair                                   |
| `0x5` | Symbol                                 |
| `0x6` | Byte vector                            |
| `0x7` | Closure                                |
| `0x8` | Special value, such as `EOF` or `unit` |

### Integer Operations

Integer operations are abstracted with a helper function that performs
different actions based on the requested operation ID. The following
operations are available.

| ID    | Operation                 | Prelude Binding |
| ----- | ------------------------- | --------------- |
| `0x0` | Add                       | `+`             |
| `0x1` | Subtract                  | `-`             |
| `0x2` | Bitwise and               | `&`             |
| `0x3` | Bitwise or                | `\|`            |
| `0x4` | Bitwise xor               | `^`             |
| `0x5` | Shift left                | `<<`            |
| `0x6` | Logical shift right       | `>>>`           |
| `0x7` | Arithmetic shift right    | `>>`            |
| `0x8` | Numeric equality          | `=`             |
| `0x9` | Signed less than          | `<`             |
| `0xa` | Signed less than or equal | `<=`            |

For shifts, the second operand is the shift amount and must be between `0`
and `60`, inclusive. Logical right shift requires a non-negative first
operand. Arithmetic right shift preserves the sign. A left shift which
loses bits or a result which cannot fit in a number is an integer overflow
error.

### Byte Vectors and Symbols

Byte vector lengths must be non-negative numbers. Indices start at zero and
must be smaller than the vector's length. Bytes are numbers between `0x00`
and `0xff`, inclusive. The `set/byte-vector` builtin changes the existing
vector, just as the pair setters change an existing pair.

Strings are byte vectors, so they can be passed directly to `intern`. If a
symbol with the same name already exists, it is returned. Otherwise, a new
symbol is created with a copy of the name. The `symbol-name` builtin also
returns a copy, so changing either byte vector will not change the symbol's
name.

### Input and Output

The `read-byte` builtin takes no arguments and reads from the same `stdin`
stream as the reader. If the reader has already buffered a byte of lookahead,
that byte is returned first. At the end of the stream, it returns the `EOF`
value instead of a number.

The `eof` builtin takes no arguments and returns that same value without
consuming input. The prelude binds it as `EOF` for convenient use as a value.

The `write-byte` builtin accepts `0x1` for `stdout` or `0x2` for `stderr` as
its first argument. Its second argument must be a byte between `0x00` and
`0xff`.

The `exit` builtin takes a status code between `0x00` and `0xff`. It then
performs the exit syscall to stop the program.

## Exit Codes

The following exit codes can occur when this program is run. Errors stop the
interpreter immediately without printing a message. Reaching the end of the
input normally exits with `0`, while `exit` can supply any status if desired.

| Code | Meaning                                                    |
| ---- | ---------------------------------------------------------- |
| `0`  | Success, no error occurred.                                |
| `1`  | Failed to allocate memory with `mmap`.                     |
| `2`  | An allocation overflowed or exceeded the available heap.   |
| `3`  | Failed to read from `stdin`.                               |
| `4`  | Failed to write to `stdout` or `stderr`.                   |
| `5`  | The reader encountered invalid syntax.                     |
| `6`  | A numeric literal is invalid or too large.                 |
| `7`  | A symbol has no value in the environment or globals.       |
| `8`  | A special form or expression list is invalid.              |
| `9`  | A value cannot be called, or a builtin ID is unknown.      |
| `10` | The number of arguments does not match.                    |
| `11` | A builtin argument has the wrong type or an invalid value. |
| `12` | A byte vector index is negative or past the end.           |
| `13` | An integer result or shift is out of range.                |
| `14` | The token buffer is full.                                  |
| `15` | Internal failure, reserved for interpreter errors.         |

## Layout

This is the most complex program implemented so far and, owing to it being
written in such a low-level language, it requires significant planning. The
following sections detail memory usage and named regions of the code.

### Labels

Labels are reserved for the following use cases.

| Range   | Purpose           |
| ------- | ----------------- |
| `00-0f` | Startup           |
| `10-1f` | Memory allocation |
| `20-2f` | Input             |
| `30-5f` | Reader            |
| `60-6f` | Environments      |
| `70-8f` | Eval              |
| `90-cf` | Builtins          |
| `d0-df` |                   |
| `e0-ef` | Embedded data     |
| `f0-ff` | Errors            |

labels have been mapped to their implementation in the following table.

| Label | Name                                     | Source              |
| ----- | ---------------------------------------- | ------------------- |
| `00`  | `startup`                                | `00-startup.na`     |
| `01`  | `main`                                   | `00-startup.na`     |
| `02`  | `main_exit`                              | `00-startup.na`     |
| `03`  | `init_embedded_symbols`                  | `00-startup.na`     |
| `10`  | `allocate`                               | `01-memory.na`      |
| `11`  | `create_pair`                            | `02-data.na`        |
| `12`  | `create_byte_vector`                     | `02-data.na`        |
| `13`  | `create_byte_vector_fill`                | `02-data.na`        |
| `14`  | `create_byte_vector_fill_done`           | `02-data.na`        |
| `15`  | `create_byte_vector_from_bytes`          | `02-data.na`        |
| `16`  | `copy_vector_bytes_loop`                 | `02-data.na`        |
| `17`  | `copy_vector_bytes_done`                 | `02-data.na`        |
| `18`  | `create_closure`                         | `02-data.na`        |
| `19`  | `create_environment`                     | `02-data.na`        |
| `1a`  | `byte_vectors_equal`                     | `02-data.na`        |
| `1b`  | `byte_vectors_equal_loop`                | `02-data.na`        |
| `1c`  | `byte_vectors_equal_true`                | `02-data.na`        |
| `1d`  | `byte_vectors_equal_false`               | `02-data.na`        |
| `20`  | `read_input_byte`                        | `03-input.na`       |
| `21`  | `read_input_byte_success`                | `03-input.na`       |
| `22`  | `read_input_byte_eof`                    | `03-input.na`       |
| `23`  | `peek_byte`                              | `03-input.na`       |
| `24`  | `peek_byte_return`                       | `03-input.na`       |
| `25`  | `consume_byte`                           | `03-input.na`       |
| `26`  | `skip_whitespace_and_comments`           | `03-input.na`       |
| `27`  | `skip_comment`                           | `03-input.na`       |
| `28`  | `skip_done`                              | `03-input.na`       |
| `29`  | `skip_char`                              | `03-input.na`       |
| `30`  | `token_reset`                            | `04-reader.na`      |
| `31`  | `token_append`                           | `04-reader.na`      |
| `32`  | `read_form`                              | `04-reader.na`      |
| `33`  | `read_form_list`                         | `04-reader.na`      |
| `34`  | `read_form_string`                       | `04-reader.na`      |
| `35`  | `read_form_quote`                        | `04-reader.na`      |
| `36`  | `read_form_return`                       | `04-reader.na`      |
| `37`  | `read_list`                              | `04-reader.na`      |
| `38`  | `read_list_empty`                        | `04-reader.na`      |
| `39`  | `read_quote`                             | `04-reader.na`      |
| `3a`  | `read_string`                            | `04-reader.na`      |
| `3b`  | `read_string_loop`                       | `04-reader.na`      |
| `3c`  | `read_string_escape`                     | `04-reader.na`      |
| `3d`  | `read_string_escape_literal`             | `04-reader.na`      |
| `3e`  | `read_string_escape_n`                   | `04-reader.na`      |
| `3f`  | `read_string_escape_r`                   | `04-reader.na`      |
| `40`  | `read_string_escape_t`                   | `04-reader.na`      |
| `41`  | `read_string_done`                       | `04-reader.na`      |
| `42`  | `read_token`                             | `04-reader.na`      |
| `43`  | `read_token_loop`                        | `04-reader.na`      |
| `44`  | `read_token_done`                        | `04-reader.na`      |
| `45`  | `classify_token`                         | `04-reader.na`      |
| `46`  | `classify_boolean`                       | `04-reader.na`      |
| `47`  | `classify_true`                          | `04-reader.na`      |
| `48`  | `classify_builtin`                       | `04-reader.na`      |
| `49`  | `classify_positive_number`               | `04-reader.na`      |
| `4a`  | `classify_negative_number`               | `04-reader.na`      |
| `4b`  | `classify_symbol`                        | `04-reader.na`      |
| `4c`  | `parse_hex_number`                       | `04-reader.na`      |
| `4d`  | `parse_hex_number_loop`                  | `04-reader.na`      |
| `4e`  | `parse_hex_number_done`                  | `04-reader.na`      |
| `4f`  | `decode_hex_nibble`                      | `04-reader.na`      |
| `50`  | `decode_hex_digit`                       | `04-reader.na`      |
| `51`  | `intern_bytes`                           | `05-symbols.na`     |
| `52`  | `intern_scan`                            | `05-symbols.na`     |
| `53`  | `intern_compare_name`                    | `05-symbols.na`     |
| `54`  | `intern_found`                           | `05-symbols.na`     |
| `55`  | `intern_create`                          | `05-symbols.na`     |
| `56`  | `intern_next`                            | `05-symbols.na`     |
| `57`  | `classify_return`                        | `04-reader.na`      |
| `60`  | `look_up_symbol`                         | `06-environment.na` |
| `61`  | `look_up_environment_loop`               | `06-environment.na` |
| `62`  | `look_up_binding_loop`                   | `06-environment.na` |
| `63`  | `look_up_global`                         | `06-environment.na` |
| `64`  | `validate_parameter_arity`               | `06-environment.na` |
| `65`  | `validate_parameter_arity_loop`          | `06-environment.na` |
| `66`  | `validate_parameter_arity_success`       | `06-environment.na` |
| `67`  | `look_up_variadic`                       | `06-environment.na` |
| `68`  | `look_up_next_environment`               | `06-environment.na` |
| `69`  | `look_up_found`                          | `06-environment.na` |
| `6a`  | `validate_parameter_arity_params_done`   | `06-environment.na` |
| `70`  | `eval`                                   | `07-evaluator.na`   |
| `71`  | `eval_loop`                              | `07-evaluator.na`   |
| `72`  | `eval_immediate`                         | `07-evaluator.na`   |
| `73`  | `eval_symbol`                            | `07-evaluator.na`   |
| `74`  | `eval_pair`                              | `07-evaluator.na`   |
| `75`  | `eval_quote`                             | `07-evaluator.na`   |
| `76`  | `eval_if`                                | `07-evaluator.na`   |
| `77`  | `eval_fn`                                | `07-evaluator.na`   |
| `78`  | `eval_let`                               | `07-evaluator.na`   |
| `79`  | `eval_do`                                | `07-evaluator.na`   |
| `7a`  | `eval_application`                       | `07-evaluator.na`   |
| `7b`  | `eval_sequence_tail`                     | `07-evaluator.na`   |
| `7c`  | `eval_sequence_loop`                     | `07-evaluator.na`   |
| `7d`  | `eval_return_expression`                 | `07-evaluator.na`   |
| `7e`  | `eval_return`                            | `07-evaluator.na`   |
| `7f`  | `eval_if_false`                          | `07-evaluator.na`   |
| `80`  | `eval_arguments`                         | `08-application.na` |
| `81`  | `eval_arguments_empty`                   | `08-application.na` |
| `82`  | `apply_builtin_value`                    | `07-evaluator.na`   |
| `83`  | `apply_closure`                          | `07-evaluator.na`   |
| `84`  | `eval_empty_sequence`                    | `07-evaluator.na`   |
| `87`  | `eval_arguments_return`                  | `08-application.na` |
| `90`  | `builtin_dispatch`                       | `09-builtins.na`    |
| `91`  | `builtin_cons`                           | `09-builtins.na`    |
| `92`  | `builtin_car`                            | `09-builtins.na`    |
| `93`  | `builtin_cdr`                            | `09-builtins.na`    |
| `94`  | `builtin_set_car`                        | `09-builtins.na`    |
| `95`  | `builtin_set_cdr`                        | `09-builtins.na`    |
| `96`  | `builtin_eq`                             | `09-builtins.na`    |
| `97`  | `builtin_type_of`                        | `09-builtins.na`    |
| `98`  | `builtin_integer_op`                     | `09-builtins.na`    |
| `99`  | `builtin_create_byte_vector`             | `09-builtins.na`    |
| `9a`  | `builtin_byte_vector_length`             | `09-builtins.na`    |
| `9b`  | `builtin_byte_vector_ref`                | `09-builtins.na`    |
| `9c`  | `builtin_set_byte_vector`                | `09-builtins.na`    |
| `9d`  | `builtin_byte_vector_eq`                 | `09-builtins.na`    |
| `9e`  | `builtin_intern`                         | `09-builtins.na`    |
| `9f`  | `builtin_symbol_name`                    | `09-builtins.na`    |
| `a0`  | `builtin_read_byte`                      | `09-builtins.na`    |
| `a1`  | `builtin_write_byte`                     | `09-builtins.na`    |
| `a2`  | `builtin_exit`                           | `09-builtins.na`    |
| `a3`  | `builtin_integer_add`                    | `09-builtins.na`    |
| `a4`  | `builtin_integer_subtract`               | `09-builtins.na`    |
| `a5`  | `builtin_integer_and`                    | `09-builtins.na`    |
| `a6`  | `builtin_integer_or`                     | `09-builtins.na`    |
| `a7`  | `builtin_integer_xor`                    | `09-builtins.na`    |
| `a8`  | `builtin_integer_shift_left`             | `09-builtins.na`    |
| `a9`  | `builtin_integer_shift_right_logical`    | `09-builtins.na`    |
| `aa`  | `builtin_integer_shift_right_arithmetic` | `09-builtins.na`    |
| `ab`  | `builtin_integer_equal`                  | `09-builtins.na`    |
| `ac`  | `builtin_integer_less`                   | `09-builtins.na`    |
| `ad`  | `builtin_integer_less_equal`             | `09-builtins.na`    |
| `ae`  | `builtin_boolean_true`                   | `09-builtins.na`    |
| `af`  | `builtin_boolean_false`                  | `09-builtins.na`    |
| `b0`  | `require_exact_arity`                    | `09-builtins.na`    |
| `b1`  | `require_pair`                           | `09-builtins.na`    |
| `b2`  | `require_number`                         | `09-builtins.na`    |
| `b3`  | `require_byte_vector`                    | `09-builtins.na`    |
| `b4`  | `require_symbol`                         | `09-builtins.na`    |
| `b5`  | `list_argument_1`                        | `09-builtins.na`    |
| `b6`  | `list_argument_2`                        | `09-builtins.na`    |
| `b7`  | `list_argument_3`                        | `09-builtins.na`    |
| `b8`  | `require_exact_arity_loop`               | `09-builtins.na`    |
| `b9`  | `require_exact_arity_done`               | `09-builtins.na`    |
| `ba`  | `encode_checked_number`                  | `09-builtins.na`    |
| `bb`  | `integer_encode_done`                    | `09-builtins.na`    |
| `bd`  | `integer_true`                           | `09-builtins.na`    |
| `be`  | `integer_false`                          | `09-builtins.na`    |
| `bf`  | `builtin_return`                         | `09-builtins.na`    |
| `c0`  | `type_nil`                               | `09-builtins.na`    |
| `c1`  | `type_true`                              | `09-builtins.na`    |
| `c2`  | `type_number`                            | `09-builtins.na`    |
| `c3`  | `type_builtin`                           | `09-builtins.na`    |
| `c4`  | `type_special`                           | `09-builtins.na`    |
| `c5`  | `builtin_read_byte_eof`                  | `09-builtins.na`    |
| `c6`  | `builtin_write_byte_fd_valid`            | `09-builtins.na`    |
| `c7`  | `builtin_eof_value`                      | `09-builtins.na`    |
| `e0`  | `embedded_quote`                         | `10-embedded.na`    |
| `e1`  | `embedded_if`                            | `10-embedded.na`    |
| `e2`  | `embedded_fn`                            | `10-embedded.na`    |
| `e3`  | `embedded_let`                           | `10-embedded.na`    |
| `e4`  | `embedded_do`                            | `10-embedded.na`    |
| `f0`  | `mmap_failure`                           | `11-errors.na`      |
| `f1`  | `out_of_memory`                          | `11-errors.na`      |
| `f2`  | `input_failure`                          | `11-errors.na`      |
| `f3`  | `output_failure`                         | `11-errors.na`      |
| `f4`  | `reader_syntax_error`                    | `11-errors.na`      |
| `f5`  | `numeric_literal_error`                  | `11-errors.na`      |
| `f6`  | `unbound_symbol`                         | `11-errors.na`      |
| `f7`  | `invalid_special_form`                   | `11-errors.na`      |
| `f8`  | `not_callable`                           | `11-errors.na`      |
| `f9`  | `wrong_arity`                            | `11-errors.na`      |
| `fa`  | `builtin_type_error`                     | `11-errors.na`      |
| `fb`  | `index_out_of_bounds`                    | `11-errors.na`      |
| `fc`  | `integer_overflow`                       | `11-errors.na`      |
| `fd`  | `token_overflow`                         | `11-errors.na`      |
| `fe`  | `internal_failure`                       | `11-errors.na`      |
| `ff`  | `fatal_exit`                             | `11-errors.na`      |

### Memory

A single 512MiB chunk of memory is reserved on startup for use. The interpreter
breaks it into these concrete regions.

| Range                   | Size    | Purpose     |
| ----------------------- | ------- | ----------- |
| `0x00000000-0x00001000` | 4KiB    | Context     |
| `0x00001000-0x00011000` | 64KiB   | Byte buffer |
| `0x00011000-0x20001000` | ~500MiB | Heap        |

#### Values

All values are 64 bits, where the low bits represent what kind of value it is.

| Tag   | Description      |
| ----- | ---------------- |
| `000` | Heap Pointer     |
| `001` | Number (Signed)  |
| `010` | Builtin Function |
| `011` | Builtin Value    |

##### Builtin Function

The builtin ID is stored above the three tag bits. To encode a builtin,
shift its ID left by 3 and set the tag to `010`. For example, `#00` is stored
as `0x02` and `#11` is stored as `0x8a`. The IDs and their functions are
listed in [Builtins](#builtins).

##### Builtin Value

The following builtin values exist.

| ID     | Description          |
| ------ | -------------------- |
| `0x03` | `false`, `()`, `nil` |
| `0x0b` | `true`               |
| `0x13` | `EOF`                |
| `0x1b` | `unit` (no result)   |
| `0x23` | Uninitialized        |

#### Pair

A pair contains two values.

| Offset | Description  |
| ------ | ------------ |
| `0x00` | Type tag `1` |
| `0x08` | First value  |
| `0x10` | Second value |

#### Symbol

A symbol contains its name, global value, and pointer to the next symbol.

| Offset | Description      |
| ------ | ---------------- |
| `0x00` | Type tag `2`     |
| `0x08` | Name byte vector |
| `0x10` | Global value     |
| `0x18` | Next symbol      |

#### Byte Vector

A byte vector contains its length and raw bytes.

| Offset | Description  |
| ------ | ------------ |
| `0x00` | Type tag `3` |
| `0x08` | Length       |
| `0x10` | Raw bytes    |

#### Closure

A closure contains parameters, a body, and captured environment.

| Offset | Description  |
| ------ | ------------ |
| `0x00` | Type tag `4` |
| `0x08` | Parameters   |
| `0x10` | Body         |
| `0x18` | Environment  |

#### Environment

An environment uses the existing pair data structure, but is fundamental to
implementation so it is documented here. Environments are nested to create a
usable hierarchy.

```
let environment (parent (parameters arguments))
```

#### Context

Information needed for runtime is stored at the following offsets within the
memory buffer.

| Offset | Description               |
| ------ | ------------------------- |
| `0x00` | Heap cursor               |
| `0x08` | Heap end                  |
| `0x10` | Input buffer              |
| `0x18` | Token start               |
| `0x20` | Token cursor              |
| `0x28` | Token end                 |
| `0x30` | Interned symbol list head |
| `0x38` | Lookahead                 |
| `0x40` | `quote` symbol            |
| `0x48` | `if` symbol               |
| `0x50` | `fn` symbol               |
| `0x58` | `let` symbol              |
| `0x60` | `do` symbol               |

##### Context Lookahead

The lookahead state holds a buffered byte, EOF, or an empty state meaning that
the next byte has not yet been read.

| Value   | Meaning                    |
| ------- | -------------------------- |
| `0-255` | ASCII byte                 |
| `256`   | EOF                        |
| `257`   | Byte has not been read yet |

#### Byte Buffer

The byte buffer is broken into two chunks, one for syscalls and the other for
tokens.

| Range                   | Purpose |
| ----------------------- | ------- |
| `0x00001000-0x00001008` | Syscall |
| `0x00001008-0x00011000` | Tokens  |

### Registers

To keep things as manageable as possible, the following conventions are used
throughout this program.

| Register | Purpose               |
| -------- | --------------------- |
| `rax`    | Return value, general |
| `rdi`    | Argument 1            |
| `rsi`    | Argument 2            |
| `rdx`    | Argument 3            |
| `rcx`    | Argument 4, general   |
| `rbx`    | Runtime context       |
| `rbp`    | Preserved temporary   |

Note that `rsp` is 16-byte aligned before each function call.

## Prelude Functions

The prelude in `src/prelude.bl` provides the following functions in addition to
the bindings described in [Builtins](#builtins),
[Integer Operations](#integer-operations), and
[Prelude Division](#prelude-division). Arguments in the tables are listed in
call order. Except for `list`, these functions take a fixed number of
arguments.

The prelude also binds constants for ease of use.

| Name    | Value      |
| ------- | ---------- |
| `true`  | `#t`       |
| `false` | `#f`       |
| `nil`   | `#f`       |
| `unit`  | Unit value |
| `EOF`   | EOF value  |

### Booleans and Predicates

| Function       | Arguments | Result                                                       |
| -------------- | --------- | ------------------------------------------------------------ |
| `not`          | `a`       | True when `a` is false.                                      |
| `and`          | `a`, `b`  | True when both values are truthy.                            |
| `or`           | `a`, `b`  | True when either value is truthy.                            |
| `false?`       | `a`       | True when `a` is `#f` or the empty list.                     |
| `nil?`         | `a`       | Alias of `false?`.                                           |
| `true?`        | `a`       | True only when `a` is `#t`.                                  |
| `bool?`        | `a`       | True when `a` is `#t` or `#f`.                               |
| `number?`      | `a`       | True when `a` is a number.                                   |
| `builtin?`     | `a`       | True when `a` is a builtin function value.                   |
| `pair?`        | `a`       | True when `a` is a pair.                                     |
| `symbol?`      | `a`       | True when `a` is a symbol.                                   |
| `byte-vector?` | `a`       | True when `a` is a byte vector, including a string.          |
| `closure?`     | `a`       | True when `a` is a closure.                                  |
| `special?`     | `a`       | True when `a` has type ID `0x8`, including `eof` and `unit`. |
| `eof?`         | `a`       | True when `a` is the end-of-input value.                     |

Note: `and` and `or` are normal functions so their arguments are evaluated
before the function runs. Use `if` when evaluation of a later expression must
depend on an earlier one.

### Numeric Functions

| Function    | Arguments | Result                                                             |
| ----------- | --------- | ------------------------------------------------------------------ |
| `increment` | `a`       | Adds one.                                                          |
| `decrement` | `a`       | Subtracts one.                                                     |
| `>`         | `a`, `b`  | True when `a` is greater than `b`.                                 |
| `>=`        | `a`, `b`  | True when `a` is greater than or equal to `b`.                     |
| `positive?` | `a`       | True when `a` is greater than zero.                                |
| `negative?` | `a`       | True when `a` is less than zero.                                   |
| `sign`      | `a`       | `-0x1` for a negative number, `0x1` for zero or a positive number. |
| `sign/flip` | `a`       | Negates `a`.                                                       |
| `abs`       | `a`       | Non-negative magnitude of `a`.                                     |
| `abs/neg`   | `a`       | Non-positive magnitude of `a`.                                     |
| `odd?`      | `a`       | True when `a` is odd.                                              |
| `even?`     | `a`       | True when `a` is even.                                             |
| `*`         | `a`, `b`  | Product of the two numbers.                                        |
| `/`         | `a`, `b`  | A pair whose values are the quotient and remainder.                |
| `//`        | `a`, `b`  | The quotient resulting from division.                              |
| `%`         | `a`, `b`  | The remainder resulting from division.                             |

`abs` and `sign/flip` overflow on `-0x1000000000000000`. You have been warned.

Arithmetic overflow exits with code `13`.

### Lists and Structural Equality

| Function    | Arguments               | Result                                                                                                        |
| ----------- | ----------------------- | ------------------------------------------------------------------------------------------------------------- |
| `list`      | Zero or more values     | A list containing the arguments.                                                                              |
| `caar`      | `items`                 | Shorthand for `(car (car items))`.                                                                            |
| `cdar`      | `items`                 | Shorthand for `(cdr (car items))`.                                                                            |
| `length`    | `items`                 | Number of outer list elements.                                                                                |
| `reverse`   | `items`                 | A new list with the items in reversed order.                                                                  |
| `append`    | `xs`, `ys`              | A new list where `xs` is followed by `ys`.                                                                    |
| `map`       | `f`, `items`            | A new list of results from calling `f` with each item.                                                        |
| `fold-left` | `f`, `initial`, `items` | Starting with `initial`, call `f` with each item and the latest accumulated value to produce the final value. |
| `each`      | `f`, `items`            | Calls `f` once per item.                                                                                      |
| `equal?`    | `a`, `b`                | Structural equality of values, returning a boolean.                                                           |

```lisp
(length '(a (b c))) ; 0x2
(reverse '(a b c)) ; (c b a)
(map increment '(0x1 0x2)) ; (0x2 0x3)
(fold-left - 0xa '(0x1 0x2)) ; 0x7
(equal? (cons 'a "b") (cons 'a "b")) ; #t
```

### Searching Lists and Maps

A map is a list of entries constructed where each entry is `(cons key value)`.
Other Lisps call these Association Lists or similar, but this is my language so
I get to make the rules! Haha!

| Function                  | Arguments          | Result                                       |
| ------------------------- | ------------------ | -------------------------------------------- |
| `map/find-by-key`         | `key`, `entries`   | Finds the entry whose key is `equal?`.       |
| `map/find-by-exact-key`   | `key`, `entries`   | Finds the entry whose key is `eq?`.          |
| `map/find-by-value`       | `value`, `entries` | Finds the entry whose value is `equal?`.     |
| `map/find-by-exact-value` | `value`, `entries` | Finds the entry whose value is `eq?`.        |
| `list/find`               | `value`, `items`   | Finds the tail whose first item is `equal?`. |
| `list/find-exact`         | `value`, `items`   | Finds the tail whose first item is `eq?`.    |

```lisp
(let settings (list (cons 'volume 0xff)))

(car (map/find-by-key 'volume settings)) ; volume
(cdr (map/find-by-key 'volume settings)) ; 0xff
(map/find-by-key 'missing settings) ; #f
(list/find-exact #f '(a #f b)) ; (#f b)
```

### Byte-Vector Conversion and Copying

| Function             | Arguments                | Result                                                                           |
| -------------------- | ------------------------ | -------------------------------------------------------------------------------- |
| `list->byte-vector`  | `items`                  | A new byte vector from the contents of a list.                                   |
| `byte-vector->list`  | `vector`                 | A new list from the contents of a byte vector.                                   |
| `byte-vector-copy`   | `vector`                 | A new vector with contents copied from the provided source.                      |
| `byte-vector-concat` | `a`, `b`                 | A new vector containing all bytes of `a`, then all bytes of `b`.                 |
| `byte-vector-slice`  | `vector`, `start`, `end` | A new vector containing content from the source vector in the range `start-end`. |

```lisp
(list->byte-vector '(0x41 0x42)) ; "AB"
(byte-vector->list "AB") ; (0x41 0x42)
(byte-vector-concat "AB" "CD") ; "ABCD"
(byte-vector-slice "ABCDE" 0x1 0x4) ; "BCD"
```

### Number and String Conversion

| Function         | Arguments         | Result                                            |
| ---------------- | ----------------- | ------------------------------------------------- |
| `number->string` | `number`, `radix` | A new byte vector containing the number as ASCII. |
| `string->number` | `vector`, `radix` | A number parsed from the string.                  |

Radix can be `0x2` through `0x10`.

```lisp
(number->string -0x2a 0xa) ; "-42"
(number->string 0x2a 0x10) ; "2a"
(string->number "-42" 0xa) ; -0x2a
(string->number "101" 0x2) ; 0x5
```

### Prelude Input, Output, and Errors

| Function            | Arguments         | Description                              |
| ------------------- | ----------------- | ---------------------------------------- |
| `stdin/read-byte`   |                   | Reads a byte or EOF from `stdin`.        |
| `stdout/write-byte` | `a`               | Writes a single byte to `stdout`.        |
| `stderr/write-byte` | `a`               | Writes a single byte to `stderr`.        |
| `stdout/write`      | `text`            | Writes a string to `stdout`.             |
| `stderr/write`      | `text`            | Writes a string to `stderr`.             |
| `error`             | `code`, `message` | Exits the program with an error message. |
