// Written in the D programming language.

/**
 * This test program pulls in all the library modules in order to run the unit
 * tests on them.  Then, it prints out the arguments passed to main().
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   $(HTTP digitalmars.com, Walter Bright)
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

public import std.base64;
public import std.compiler;
public import std.concurrency;
public import std.conv;
public import std.container;
public import std.datetime;
public import std.demangle;
public import std.file;
public import std.format;
public import std.getopt;
public import std.math;
public import std.mathspecial;
public import std.mmfile;
public import std.outbuffer;
public import std.parallelism;
public import std.path;
public import std.process;
public import std.random;
public import std.regex;
public import std.signals;
//public import std.slist;
public import std.socket;
public import std.stdint;
public import std.stdio;
public import std.string;
public import std.system;
public import std.traits;
public import std.typetuple;
public import std.uni;
public import std.uri;
public import std.utf;
public import std.uuid;
public import std.variant;
public import std.zip;
public import std.zlib;
public import std.net.isemail;
public import std.net.curl;
public import std.digest;
public import std.digest.crc;
public import std.digest.sha;
public import std.digest.md;
public import std.digest.hmac;

int main(string[] args)
{
    // Bring in unit test for module by referencing function in it

    cast(void) cmp("foo", "bar");                  // string
    cast(void) filenameCharCmp('a', 'b');          // path
    cast(void) isNaN(1.0);                         // math
    std.conv.to!double("1.0");          // std.conv
    OutBuffer b = new OutBuffer();      // outbuffer
    auto r = regex("");                 // regex
    uint ranseed = std.random.unpredictableSeed;
    thisTid;
    int[] a;
    import std.algorithm.sorting : sort;
    import std.algorithm.mutation : reverse;
    reverse(a);                         // adi
    sort(a);                            // qsort
    Clock.currTime();                   // datetime
    cast(void) isValidDchar(cast(dchar) 0);          // utf
    string s1 = "http://www.digitalmars.com/~fred/fredsRX.html#foo end!";
    assert(uriLength(s1) == 49);
    std.zlib.adler32(0,null);            // D.zlib
    auto t = task!cmp("foo", "bar");  // parallelism

    printf("args.length = %d\n", cast(int)args.length);
    for (int i = 0; i < args.length; i++)
        printf("args[%d] = '%.*s'\n", i, cast(int)args[i].length, args[i].ptr);

    int[3] x;
    x[0] = 3;
    x[1] = 45;
    x[2] = -1;
    sort(x[]);
    assert(x[0] == -1);
    assert(x[1] == 3);
    assert(x[2] == 45);

    cast(void) std.math.sin(3.0);
    cast(void) std.mathspecial.gamma(6.2);

    cast(void) std.demangle.demangle("hello");

    cast(void) std.uni.isAlpha('A');

    std.file.exists("foo");

    foreach_reverse (dchar d; "hello"c) { }
    foreach_reverse (k, dchar d; "hello"c) { }

    std.signals.linkin();

    bool isEmail = std.net.isemail.isEmail("abc");
    auto http = std.net.curl.HTTP("dlang.org");
    auto uuid = randomUUID();

    auto md5 = md5Of("hello");
    auto sha1 = sha1Of("hello");
    auto crc = crc32Of("hello");
    auto string = toHexString(crc);
    puts("Success!");
    return 0;
}
