// Written in the D programming language

/**
 * Provides non-deterministic uniform random number generators, or more
 * precisely, sources of uniformly-distributed non-deterministic random
 * bits.
 *
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *
 * Source:    $(PHOBOSSRC std/random/_device.d)
 */
module std.random.device;

/**
A "good" seed for initializing random number engines. Initializing
with $(D_PARAM unpredictableSeed) makes engines generate different
random number sequences every run.

Returns:
A single unsigned integer seed value, different on each successive call

Example:

----
auto rnd = Random(unpredictableSeed);
auto n = rnd.front;
...
----
*/

@property uint unpredictableSeed() @trusted
{
    import core.thread : Thread, getpid, TickDuration;
    import std.random.engine : MinstdRand0;
    static bool seeded;
    static MinstdRand0 rand;
    if (!seeded)
    {
        uint threadID = cast(uint) cast(void*) Thread.getThis();
        rand.seed((getpid() + threadID) ^ cast(uint) TickDuration.currSystemTick.length);
        seeded = true;
    }
    rand.popFront();
    return cast(uint) (TickDuration.currSystemTick.length ^ rand.front);
}

@safe unittest
{
    // not much to test here
    auto a = unpredictableSeed;
    static assert(is(typeof(a) == uint));
}
