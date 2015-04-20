/**
 * This module implements functions to run the unittests with
 * command-line options.
 */

module std.experimental.testing.runner;

import std.experimental.testing.testsuite;
import std.experimental.testing.options;
import std.experimental.testing.io : enableDebugOutput, forceEscCodes;
import std.experimental.testing.testcase : TestData;
import std.experimental.testing.reflection : allTestData;

import std.conv : text;
import std.algorithm : map, filter, count;

/**
 * Runs all tests in passed-in modules. Modules can be symbols or
 * strings. Generates a main function and substitutes the default D
 * runtime unittest runner. This mixin should be used instead of
 * $(D runTests) if Phobos is linked as a shared library.
 */
mixin template runTestsMixin(MODULES...)
{

    shared static this()
    {
        import std.experimental.testing.testsuite : replaceModuleUnitTester;

        replaceModuleUnitTester;
    }

    int main(string[] args)
    {
        return runTests!MODULES(args);
    }
}

/**
 * Runs all tests in passed-in modules. Modules can be symbols
 * or strings. Arguments are taken from the command-line.
 * -s Can be passed to run in single-threaded mode. The rest
 * of argv is considered to be test names to be run.
 * Params:
 *   args = Arguments passed to main.
 * Returns: An integer suitable for the program's return code.
 */
int runTests(MODULES...)(string[] args)
{
    return runTests(args, allTestData!MODULES);
}

/**
 * Runs all tests in passed-in testData. Arguments are taken from the
 * command-line. `-s` Can be passed to run in single-threaded mode. The
 * rest of argv is considered to be test names to be run.
 * Params:
 *   args = Arguments passed to main.
 *   testData = Data about the tests to run.
 * Returns: An integer suitable for the program's return code.
 */
int runTests(string[] args, in TestData[] testData)
{
    const options = getOptions(args);
    handleCmdLineOptions(options, testData);
    if (options.exit)
        return 0;

    auto suite = TestSuite(options, testData);
    return suite.run ? 0 : 1;
}

private void handleCmdLineOptions(in Options options, in TestData[] testData)
{
    if (options.list)
    {
        import std.stdio;

        writeln("Listing tests:");
        foreach (test; testData.map!(a => a.name))
        {
            writeln(test);
        }
    }

    if (options.debugOutput)
        enableDebugOutput();
    if (options.forceEscCodes)
        forceEscCodes();
}
