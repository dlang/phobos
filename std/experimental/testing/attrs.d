/**
 * This module defines UDAs to be used on unit tests.
 */

module std.experimental.testing.attrs;

/**
 * Associate a name with a unittest block.
 */
struct name
{
    string value;
}

enum singleThreaded; ///run all unittests in the module in one thread

/**
 * The suite fails if the test passes.
 */
struct shouldFail
{
    string reason;
}

/**
 * Hide test. Not run by default but can be run by specifying its name
 * on the command-line.
 */
struct hiddenTest
{
    string reason;
}
