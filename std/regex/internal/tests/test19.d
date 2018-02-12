/*
    Regualar expressions package test suite.
*/
module std.regex.internal.tests.tests19;

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
        TestVectors(  "[abc[pq]xyz[rs]]{4}",         "cqxr",      "y",   "$&",     "cqxr"),
        TestVectors(  "[abcdf--[ab&&[bcd]][acd]]",   "abcdefgh",  "y",   "$&",     "f"),
        TestVectors(  "[a-c||d-f]+",    "abcdef", "y", "$&", "abcdef"),
        TestVectors(  "[a-f--a-c]+",    "abcdef", "y", "$&", "def"),
        TestVectors(  "[a-c&&b-f]+",    "abcdef", "y", "$&", "bc"),
        TestVectors(  "[a-c~~b-f]+",    "abcdef", "y", "$&", "a"),
//unicode blocks & properties:
        TestVectors(  `\P{Inlatin1suppl ement}`, "\u00c2!", "y", "$&", "!"),
        TestVectors(  `\p{InLatin-1 Supplement}\p{in-mathematical-operators}\P{Inlatin1suppl ement}`,
            "\u00c2\u2200\u00c3\u2203.", "y", "$&", "\u00c3\u2203."),
    ];
    runTests!tv;
}
