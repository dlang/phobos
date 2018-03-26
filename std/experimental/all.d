/++
Convenience file that allows to import entire Phobos in one command.
+/
module std.experimental.all;

///
@safe unittest
{
    import std.experimental.all;

    int len;
    const r = 6.iota
              .filter!(a => a % 2) // 1 3 5
              .map!(a => a * 2) // 2 6 10
              .tee!(_ => len++)
              .sum
              .reverseArgs!format("Sum: %d");

    assert(len == 3);
    assert(r == "Sum: 18");
}

///
@safe unittest
{
    import std.experimental.all;
    assert(10.iota.map!(partial!(pow, 2)).sum == 1023);
}

public import std.algorithm;
public import std.array;
public import std.ascii;
public import std.base64;
public import std.bigint;
public import std.bitmanip;
public import std.compiler;
public import std.complex;
public import std.concurrency;
public import std.container;
public import std.conv;
public import std.csv;
public import std.datetime;
public import std.demangle;
public import std.digest;
public import std.encoding;
public import std.exception;
public import std.file;
public import std.format;
public import std.functional;
public import std.getopt;
public import std.json;
public import std.math;
public import std.mathspecial;
public import std.meta;
public import std.mmfile;
public import std.net.curl;
public import std.numeric;
public import std.outbuffer;
public import std.parallelism;
public import std.path;
public import std.process;
public import std.random;
public import std.range;
public import std.regex;
public import std.signals;
public import std.socket;
public import std.stdint;
public import std.stdio;
public import std.string;
public import std.system;
public import std.traits;
public import std.typecons;
//public import std.typetuple; // this module is undocumented and about to be deprecated
public import std.uni;
public import std.uri;
public import std.utf;
public import std.uuid;
public import std.variant;
public import std.xml;
public import std.zip;
public import std.zlib;
