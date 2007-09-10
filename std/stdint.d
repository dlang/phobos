
/* Written by Walter Bright
 * www.digitalmars.com
 * Placed into Public Domain
 */

module std.stdint;

/* Exact sizes */

alias  byte   int8_t;
alias ubyte  uint8_t;
alias  short  int16_t;
alias ushort uint16_t;
alias  int    int32_t;
alias uint   uint32_t;
alias  long   int64_t;
alias ulong  uint64_t;

/* At least sizes */

alias  byte   int_least8_t;
alias ubyte  uint_least8_t;
alias  short  int_least16_t;
alias ushort uint_least16_t;
alias  int    int_least32_t;
alias uint   uint_least32_t;
alias  long   int_least64_t;
alias ulong  uint_least64_t;

/* Fastest minimum width sizes */

alias  byte  int_fast8_t;
alias ubyte uint_fast8_t;
alias  int   int_fast16_t;
alias uint  uint_fast16_t;
alias  int   int_fast32_t;
alias uint  uint_fast32_t;
alias  long  int_fast64_t;
alias ulong uint_fast64_t;

/* Integer pointer holders */

alias int   intptr_t;
alias uint uintptr_t;

/* Greatest width integer types */

alias  long  intmax_t;
alias ulong uintmax_t;

