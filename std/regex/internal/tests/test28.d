/*
    Regualar expressions package test suite.
*/
module std.regex.internal.tests.tests28;

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
//mixed lookaround
        TestVectors(   `a(?<=a(?=b))b`,    "ab", "y",      "$&", "ab"),
        TestVectors(   `a(?<=a(?!b))c`,    "ac", "y",      "$&", "ac"),
        TestVectors(   `a(?i)bc`,         "aBc", "y",      "$&", "aBc"),
        TestVectors(   `a(?i)bc`,         "Abc", "n",      "$&", "-"),
        TestVectors(   `(?i)a(?-i)bc`, "aBcAbc", "y",      "$&", "Abc"),
        TestVectors(   `(?s).(?-s).`, "\n\n\na", "y",      "$&", "\na"),
        TestVectors(   `(?m)^a(?-m)$`,  "\na",   "y",      "$&", "a")
    ];
    runTests!tv;
}
