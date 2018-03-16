/*
    Regualar expressions package test suite.
*/
module std.regex.internal.tests.tests22;

package(std.regex):

import std.regex.internal.tests.common;

/* The test vectors in this file are altered from Henry Spencer's regexp
   test code. His copyright notice is:

        Copyright (c) 1986 by University of Toronto.
        Written by Henry Spencer.  Not derived from licensed software.

        Permission is granted to anyone to use this software for any
        purpose on any computer system, and to redistribute it freely,
        subject to the following restrictions:

        1. The author is not responsible for the consequences of use of
                this software, no matter how awful, even if they arise
                from defects in it.

        2. The origin of this software must not be misrepresented, either
                by explicit claim or by omission.

        3. Altered versions must be plainly marked as such, and must not
                be misrepresented as being the original software.
 */

@safe unittest
{
    static immutable TestVectors[] tv = [
        TestVectors(    `[\x00-\x7f]{4}`,        "\x00\x09ab",   "y", "$&", "\x00\x09ab"),
        TestVectors(    `[\cJ\cK\cA-\cD]{3}\cQ`, "\x01\x0B\x0A\x11", "y", "$&", "\x01\x0B\x0A\x11"),
        TestVectors(    `\r\n\v\t\f\\`,     "\r\n\v\t\f\\",   "y",   "$&", "\r\n\v\t\f\\"),
        TestVectors(    `[\u0003\u0001]{2}`,  "\u0001\u0003",         "y",   "$&", "\u0001\u0003"),
        TestVectors(    `^[\u0020-\u0080\u0001\n-\r]{8}`,  "abc\u0001\v\f\r\n",  "y",   "$&", "abc\u0001\v\f\r\n"),
        TestVectors(    `\w+\S\w+`, "ab7!44c",  "y", "$&", "ab7!44c"),
        TestVectors(    `\b\w+\b`,  " abde4 ",  "y", "$&", "abde4"),
        TestVectors(    `\b\w+\b`,  " abde4",   "y", "$&", "abde4"),
        TestVectors(    `\b\w+\b`,  "abde4 ",   "y", "$&", "abde4"),
        TestVectors(    `\pL\pS`,   "a\u02DA",  "y", "$&", "a\u02DA"),
    ];
    runTests!tv;
}
