## Phobos 3 Package Map

`based` modules duplicated in `phobos` will contain a mix of wrapped `based` functions, new fuctions, and public imports of `based` symbols, depending on what ends up being the most effective solution.

Packages/Modules with an asterisk are new.

### Open Questions

1. `std.container`: Does it belong in `sys` or it's own root? This likely hinges on the status of [DIP1000](https://github.com/dlang/DIPs/blob/master/DIPs/other/DIP1000.md) and whether or not it needs a ground up rewrite.
2. `std.concurrency`: It is possible that not all platforms support Concurrency mechanics. Should `std.concurrency` be required in the core roots or moved to a non-core root?
3. `std.parallelism`: It is possible that not all platforms support Task Parallelism mechanics. Should `std.parallelism` be required in the core roots or moved to a non-core root?
4.  Which, if any, modules should be removed? This could be either a permanent removal or pending replacement with ground-up rewrites.

### Closed Questions
1. `std.digest`: Only non-cryptographic digests will be kept. SHA2/3 will be available in `phobos.sys.hash` using the system provided API.
2. Removed modules:
    1. `std.json` (Replaced with [JSONIOPipe](https://github.com/schveiguy/jsoniopipe))
    2. `std.getopt`
    3. `std.logger`
    4. `std.experimental`
    5. `std.digest` (only: `hmac`/`md`/`ripemd`/`sha`)
3. `std.typecons` will be split into distinct modules.

### Proposed Package Structure

***This map is not final!***

```
core.*
etc.*
std.*
platform
  | freebsd
  | linux
  | macos
  | stdc
  | win
based
  | bigint
  | bitmanip
  | checkedint (core.checkedint)
  | complex
  | compiler
  | console (std.stdio)
  | demangle (core.demangle)
  | file
  | int128
  | math
    | algebraic
    | constants
    | exponential
    | hardware
    | operations
    | remainder
    | rounding
    | traits
    | trigonometry
    | special
    | numeric
  | meta
  | optional* (std.typecons)
  | stdint
  | sumtype
  | system
  | time (core.time)
  | traits
phobos.sys
  | algorithm
    | comparison
    | iteration
    | mutation
    | searching
    | setops
    | sorting
  | array
  | checkedint
  | conv
  | datetime
    | date
    | interval
    | stopwatch
    | systime
    | timezone
  | demangle
  | exception
  | functional
  | meta
  | outbuffer
  | process
  | random
  | range
  | signals
  | traits
  | uuid
  | variant
phobos.data
  | base64
  | csv
  | json*
  | toml*
  | sdl*
  | zip
phobos.crypto
  | digest
    | crc
    | murmurhash
  | ecc*
  | hash*
    | sha*
    | hmac*
  | kdf*
  | random*
  | rsa*
  | symmetric*
phobos.io
  | console (std.stdio)
  | stream* (iopipe)
  | mmfile
  | path
phobos.text
  | ascii
  | encoding
  | format
  | string
  | uni
  | utf
phobos.net
  | http*
  | socket
  | tls*
  | uri
```