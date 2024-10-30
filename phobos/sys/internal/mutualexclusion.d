/*
Mutal exclusion, locks for thread consistency.

https://en.wikipedia.org/wiki/Eisenberg_%26_McGuire_algorithm
https://en.wikipedia.org/wiki/Szyma%C5%84ski%27s_algorithm

License: Boost
Authors: Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>
Copyright: 2022-2024 Richard Andrew Cattermole
*/
module phobos.sys.internal.mutualexclusion;
import core.atomic;
import core.thread;

export:

//
struct TestTestSetLockInline
{
    private shared(bool) state;

export @safe @nogc nothrow:

    // Non-pure will yield the thread lock
    void lock() scope @trusted
    {
        for (;;)
        {
            while (atomicLoad(state))
            {
                Thread.yield();
            }

            if (cas(&state, false, true))
                return;
        }
    }

pure:

    // A much more limited lock method, that is pure.
    void pureLock() scope
    {
        for (;;)
        {
            if (atomicLoad(state))
                atomicFence();

            if (cas(&state, false, true))
                return;
        }
    }

    //
    bool tryLock() scope
    {
        return cas(&state, false, true);
    }

    //
    void unlock() scope
    {
        atomicStore(state, false);
    }
}
