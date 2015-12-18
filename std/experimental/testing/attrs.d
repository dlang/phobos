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

/**
 * Run all unittests from the same module with this UDA in series.
 * This means they always execute in the same thread and always
 * in the order of declaration.
 */
enum serial;

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
