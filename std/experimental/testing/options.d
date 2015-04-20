/**
 * Command-line options for running unittests.
 */

module std.experimental.testing.options;

import std.getopt;
import std.stdio;
import std.random;
import std.exception;

/**
 * Options to the test-runner to be specified at run-time.
 */
struct Options
{
    bool multiThreaded;
    string[] testsToRun;
    bool debugOutput;
    bool list;
    bool exit;
    bool forceEscCodes;
    bool random;
    uint seed;
}

/**
 * Parses the command-line args.
 * Params:
 *   args = The arguments passed to main.
 * Returns: The options struct.
 */
Options getOptions(string[] args)
{
    bool single;
    bool debugOutput;
    bool list;
    bool forceEscCodes;
    bool random;
    uint seed = unpredictableSeed;

    auto helpInfo = getopt(
        args,
        "single|s", "Single-threaded execution.", &single, //single-threaded
        "debug|d", "Enable debug output.", &debugOutput, //print debug output
        "esccodes|e", "Force ANSI escape codes even for !isatty.", &forceEscCodes,
        "list|l", "List tests, don't run them.", &list,
        "random|r", "Run tests in random order using one thread.", &random,
        "seed", "Set the seed for the random order.", &seed,
    );

    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter("Usage: <progname> <options> <tests>...", helpInfo.options);
    }

    if (debugOutput)
    {
        if (!single)
        {
            writeln("-d implies -s, running in a single thread\n");
        }
        single = true;
    }

    if (random)
    {
        if (!single)
            writeln("-r implies -s, running in a single thread\n");
        single = true;
    }

    immutable exit = helpInfo.helpWanted || list;
    return Options(!single, args[1 .. $], debugOutput, list, exit, forceEscCodes, random,
        seed);
}
