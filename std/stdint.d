// Written in the D programming language.

/**
 *
    D constrains integral types to specific sizes. But efficiency
    of different sizes varies from machine to machine,
    pointer sizes vary, and the maximum integer size varies.
    <b>stdint</b> offers a portable way of trading off size
    vs efficiency, in a manner compatible with the <tt>stdint.h</tt>
    definitions in C.

    The exact aliases are types of exactly the specified number of bits.
    The at least aliases are at least the specified number of bits
    large, and can be larger.
    The fast aliases are the fastest integral type supported by the
    processor that is at least as wide as the specified number of bits.

    The aliases are:

    <table border=1 cellspacing=0 cellpadding=5>
    <th>Exact Alias
    <th>Description
    <th>At Least Alias
    <th>Description
    <th>Fast Alias
    <th>Description
    <tr>
    <td>int8_t
    <td>exactly 8 bits signed
    <td>int_least8_t
    <td>at least 8 bits signed
    <td>int_fast8_t
    <td>fast 8 bits signed
    <tr>
    <td>uint8_t
    <td>exactly 8 bits unsigned
    <td>uint_least8_t
    <td>at least 8 bits unsigned
    <td>uint_fast8_t
    <td>fast 8 bits unsigned

    <tr>
    <td>int16_t
    <td>exactly 16 bits signed
    <td>int_least16_t
    <td>at least 16 bits signed
    <td>int_fast16_t
    <td>fast 16 bits signed
    <tr>
    <td>uint16_t
    <td>exactly 16 bits unsigned
    <td>uint_least16_t
    <td>at least 16 bits unsigned
    <td>uint_fast16_t
    <td>fast 16 bits unsigned

    <tr>
    <td>int32_t
    <td>exactly 32 bits signed
    <td>int_least32_t
    <td>at least 32 bits signed
    <td>int_fast32_t
    <td>fast 32 bits signed
    <tr>
    <td>uint32_t
    <td>exactly 32 bits unsigned
    <td>uint_least32_t
    <td>at least 32 bits unsigned
    <td>uint_fast32_t
    <td>fast 32 bits unsigned

    <tr>
    <td>int64_t
    <td>exactly 64 bits signed
    <td>int_least64_t
    <td>at least 64 bits signed
    <td>int_fast64_t
    <td>fast 64 bits signed
    <tr>
    <td>uint64_t
    <td>exactly 64 bits unsigned
    <td>uint_least64_t
    <td>at least 64 bits unsigned
    <td>uint_fast64_t
    <td>fast 64 bits unsigned
    </table>

    The ptr aliases are integral types guaranteed to be large enough
    to hold a pointer without losing bits:

    <table border=1 cellspacing=0 cellpadding=5>
    <th>Alias
    <th>Description
    <tr>
    <td>intptr_t
    <td>signed integral type large enough to hold a pointer
    <tr>
    <td>uintptr_t
    <td>unsigned integral type large enough to hold a pointer
    </table>

    The max aliases are the largest integral types:

    <table border=1 cellspacing=0 cellpadding=5>
    <th>Alias
    <th>Description
    <tr>
    <td>intmax_t
    <td>the largest signed integral type
    <tr>
    <td>uintmax_t
    <td>the largest unsigned integral type
    </table>

 * Macros:
 *  WIKI=Phobos/StdStdint
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_stdint.d)
 */
/*          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.stdint;

public import core.stdc.stdint;
