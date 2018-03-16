/*
    Regualar expressions package test suite.
*/
module std.regex.internal.tests.tests12;

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
        TestVectors(  "(bc+d$|ef*g.|h?i(j|k))",    "ij",   "y",    "$&-$1-$2",    "ij-ij-j" ),
        TestVectors(  "(bc+d$|ef*g.|h?i(j|k))",    "effg", "n",    "-",    "-" ),
        TestVectors(  "(bc+d$|ef*g.|h?i(j|k))",    "bcdd", "n",    "-",    "-" ),
        TestVectors(  "(bc+d$|ef*g.|h?i(j|k))",    "reffgz",       "y",    "$&-$1-$2",    "effgz-effgz-" ),
        TestVectors(  "(((((((((a)))))))))",       "a",    "y",    "$&",    "a" ),
        TestVectors(  "multiple words of text",    "uh-uh",        "n",    "-",    "-" ),
        TestVectors(  "multiple words",    "multiple words, yeah", "y",    "$&",    "multiple words" ),
        TestVectors(  "(.*)c(.*)", "abcde",                "y",    "$&-$1-$2",    "abcde-ab-de" ),
        TestVectors(  "\\((.*), (.*)\\)",  "(a, b)",       "y",    "($2, $1)",   "(b, a)" ),
        TestVectors(  "abcd",      "abcd",                   "y",    "$&-&-$$$&",  "abcd-&-$abcd" ),
    ];
    runTests!tv;
}
