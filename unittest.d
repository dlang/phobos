// Written in the D programming language.

/**
 * This test program pulls in all the library modules in order to run the unit
 * tests on them.  Then, it prints out the arguments passed to main().
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
version(Win64) {}
else
{
public import std.base64;
public import std.compiler;
public import std.concurrency;
public import std.conv;
public import std.cpuid;
public import std.cstream;
public import std.ctype;
public import std.datetime;
public import std.demangle;
public import std.file;
public import std.format;
public import std.getopt;
public import std.math;
public import std.mathspecial;
public import std.md5;
public import std.metastrings;
public import std.mmfile;
public import std.outbuffer;
public import std.parallelism;
public import std.path;
public import std.perf;
public import std.process;
public import std.random;
public import std.regex;
public import std.signals;
//public import std.slist;
public import std.socket;
public import std.socketstream;
public import std.stdint;
public import std.stdio;
public import std.stream;
public import std.string;
public import std.syserror;
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
public import std.digest.digest;
public import std.digest.crc;
public import std.digest.sha;
public import std.digest.md;

}

int main(char[][] args)
{

version(Win64) {}
else
{
    // Bring in unit test for module by referencing function in it

    cmp("foo", "bar");                  // string
    filenameCharCmp('a', 'b');          // path
    isNaN(1.0);                         // math
    std.conv.to!double("1.0");          // std.conv
    OutBuffer b = new OutBuffer();      // outbuffer
    std.ctype.tolower('A');             // ctype
    auto r = regex("");                 // regex
    uint ranseed = std.random.unpredictableSeed;
    thisTid;
    int a[];
    a.reverse;                          // adi
    a.sort;                             // qsort
    Clock.currTime();                   // datetime
    Exception e = new ReadException(""); // stream
    din.eof();                           // cstream
    isValidDchar(cast(dchar)0);          // utf
    std.uri.ascii2hex(0);                // uri
    std.zlib.adler32(0,null);            // D.zlib
    auto t = task!cmp("foo", "bar");  // parallelism

    ubyte[16] buf;
    std.md5.sum(buf,"");

    creal c = 3.0 + 4.0i;
    c = sqrt(c);
    assert(c.re == 2);
    assert(c.im == 1);

    printf("args.length = %d\n", args.length);
    for (int i = 0; i < args.length; i++)
        printf("args[%d] = '%s'\n", i, cast(char *)args[i]);

    int[3] x;
    x[0] = 3;
    x[1] = 45;
    x[2] = -1;
    x.sort;
    assert(x[0] == -1);
    assert(x[1] == 3);
    assert(x[2] == 45);

    std.math.sin(3.0);
    std.mathspecial.gamma(6.2);

    std.demangle.demangle("hello");

    std.uni.isAlpha('A');

    std.file.exists("foo");

    foreach_reverse (dchar d; "hello"c) { }
    foreach_reverse (k, dchar d; "hello"c) { }

    std.signals.linkin();

    writefln(std.cpuid.toString());

    bool isEmail = std.net.isemail.isEmail("abc");
    auto http = std.net.curl.HTTP("dlang.org");
    auto uuid = randomUUID();

    auto md5 = md5Of("hello");
    auto sha1 = sha1Of("hello");
    auto crc = crc32Of("hello");
    auto string = toHexString(crc);
    puts("Success!");
}
    return 0;
}
