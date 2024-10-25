## Phobos 3 Package Map

### Open Questions

1. `std.container`: Does it belong in `sys` or it's own root? This likely hinges on the status of [DIP1000](https://github.com/dlang/DIPs/blob/master/DIPs/other/DIP1000.md) and whether or not it needs a ground up rewrite.
2. `std.concurrency`: It is possible that not all platforms support Concurrency mechanics. Should `std.concurrency` be required in the core roots or moved to a non-core root?
3. `std.parallelism`: It is possible that not all platforms support Task Parallelism mechanics. Should `std.parallelism` be required in the core roots or moved to a non-core root?
4. `std.digest`: Cryptography routines have unique requirements that would be best served by providing them in their own root. But in all cases providing bespoke implementations of cryptography routines is never recommended. Third-party trusted implementations should be used instead. This could be from OpenSSL/LibreSSL (POSIX), SChannel/BCrypt (Windows), or CryptoKit (MacOS/IOS). It is acceptable to provide implementations of Non-Cryptographic routines such as CRC and Murmur. This would entail removing all the digests except CRC and Murmur from this package and building a separate cryptography package.
5. Which, if any, modules should be removed? This could be either a permanent removal or pending replacement with ground-up rewrites.

### Proposed Package Structure (Existing Modules Only)

```
core.*
etc.*
std.*
phobos.sys
  | algorithm
    | comparison
    | iteration
    | mutation
    | searching
    | setops
    | sorting
  | array
  | bigint
  | bitmanip
  | checkedint
  | compiler
  | complex
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
  | getopt
  | int128
  | io
    | console (stdio)
    | file
    | mmfile
    | path
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
  | meta
  | numeric
  | outbuffer
  | process
  | random
  | range
  | signals
  | stdint
  | string
  | sumtype
  | system
  | traits
  | typecons
  | uuid
  | variant
phobos.data
  | base64
  | csv
  | json
  | zip
phobos.text
  | ascii
  | encoding
  | uni
  | utf
phobos.net
  | socket
  | uri
```