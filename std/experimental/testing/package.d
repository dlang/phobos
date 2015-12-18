/**
Advanced unit-testing.

Copyright: Atila Neves
License: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors: Atila Neves

$(D D)'s $(D unittest) blocks are a built-in feature of the language that allows
for easy unit testing with no boilerplate. As a program grows it's usual to need
or want more advanced testing features, which are provided by this package.

The easiest way to run tests with the functionality provided is to have a $(D D)
module implementing a $(D main) function similar to this one:

-----
import std.experimental.testing;

int main(string[] args) {
     return runTests!("name.of.mymodule",
                      "name.of.other.module")(args);
}
-----

This will (by default) run all $(D unittest) blocks in the modules
passed in as compile-time parameters in multiple threads. Unit tests
can be named: to do so simply use the supplied $(D name)
$(LINK2 http://dlang.org/attribute.html#uda, UDA). There are other supplied
UDAs. Please consult the relevant documentation.

As an alternative to writing a program like the one above manually,
the included $(D gen_ut_main.d) file can be run as a script and will
generate such a file.  This can be run as part of the build system to
recreate the unit test main file.  $(D gen_ut_main.d) checks to see if
the file list has changed and will not regenerate the file if that's
not needed.

Examples:

-----

@name("testTimesTwo")
unittest
{
    int timesTwo(int i) { return i * 2; }

    2.timesTwo.shouldEqual(4);
    3.timesTwo.shouldEqual(6);
}

@name("testRange")
unittest
{
    import std.range: iota;
    iota(3).shouldEqual([0, 1, 2]);
    3.shouldBeIn(iota(5));
}

@name("testIn")
unittest
{
    auto ints = [1, 2, 3, 4];
    3.shouldBeIn(ints);
    1.shouldBeIn(ints);
    5.shouldNotBeIn(ints);
}

@name("testThrows")
unittest
{
    void throwRangeError()
    {
        ubyte[] bytes;
        bytes = bytes[1..$];
    }
    import core.exception: RangeError;
    throwRangeError.shouldThrow!RangeError;
}

//a test that is expected to fail
@name("testOops")
@shouldFail("Bug #1234")
unittest
{
    3.shouldEqual(5); //won't cause the suite to fail
}

//prevent data races
__gshared int i;

@name("sideEffect1")
@serial //all @serial tests in a module run in the same thread
unittest
{
    i++;
    i.shouldEqual(1);
}

@name("sideEffect2")
@serial //all @serial tests in a module run in the same thread
unittest
{
    i++;
    i.shouldEqual(2);
}


-----
 */

module std.experimental.testing;

public import std.experimental.testing.should;
public import std.experimental.testing.testcase;
public import std.experimental.testing.io;
public import std.experimental.testing.reflection;
public import std.experimental.testing.runner;
public import std.experimental.testing.gen_ut_main_mixin;
