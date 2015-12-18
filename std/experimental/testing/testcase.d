/**
 * Implementations of $(D TestCase) child classes.
 */

module std.experimental.testing.testcase;

import std.experimental.testing.should;
import std.experimental.testing.io : addToOutput, utWrite;
import std.experimental.testing.reflection : TestData, TestFunction;

import std.exception;
import std.algorithm;

/**
 * Class from which other test cases derive
 */
class TestCase
{
    /**
     * The name of the test case.
     */
    string name() @safe const pure nothrow
    {
        return this.classinfo.name;
    }

    /**
     * Executes the test.
     * Returns: An array of failures
     */
    string[] opCall()
    {
        utWrite(collectOutput());
        return _failed ? [name] : [];
    }

    /**
     * Collect this test's output so as to not interleave with output from
     * other tests.
     * Returns: the output of running this test.
     */
    final string collectOutput()
    {
        print(name ~ ":\n");
        try
        {
            test();
        }
        catch (UnitTestException ex)
        {
            fail(ex.toString());
        }
        catch (Throwable t)
        {
            fail("\n    " ~ t.toString() ~ "\n");
        }

        if (_failed)
            print("\n\n");
        return _output;
    }

    /**
     * Run the test case.
     */
    abstract void test();

    /**
     * The number of tests to run.
     */
    ulong numTestsRun() @property @safe const pure nothrow
    {
        return 1;
    }

private:
    bool _failed;
    string _output;

    void fail(in string msg) @safe
    {
        _failed = true;
        print(msg);
    }

    void print(in string msg) @safe
    {
        addToOutput(_output, msg);
    }
}

/**
 * A test case that is a simple function.
 */
class FunctionTestCase : TestCase
{
    this(immutable TestData data) @safe pure nothrow
    {
        _name = data.name;
        _func = data.testFunction;
    }

    override void test()
    {
        _func();
    }

    override string name() @safe const pure nothrow
    {
        return _name;
    }

    private string _name;
    private TestFunction _func;
}

/**
 * A test case that should fail.
 */
class ShouldFailTestCase : TestCase
{
    this(TestCase testCase) @safe pure nothrow
    {
        this.testCase = testCase;
    }

    override string name() @safe const pure nothrow
    {
        return this.testCase.name;
    }

    override void test()
    {
        const ex = collectException!Exception(testCase.test());
        if (ex is null)
        {
            throw new Exception("Test " ~ testCase.name ~ " was expected to fail but did not");
        }
    }

private:

    TestCase testCase;
}

/**
 * A test case that contains other test cases.
 */
class CompositeTestCase : TestCase
{
    void add(TestCase t) @safe nothrow
    {
        _tests ~= t;
    }

    void opOpAssign(string op : "~")(TestCase t) @safe nothrow
    {
        add(t);
    }

    override string[] opCall()
    {
        return _tests.map!(a => a()).reduce!((a, b) => a ~ b);
    }

    override void test()
    {
        assert(false, "CompositeTestCase.test should never be called");
    }

    override ulong numTestsRun() @safe const pure nothrow
    {
        return _tests.length;
    }

private:

    TestCase[] _tests;
}
