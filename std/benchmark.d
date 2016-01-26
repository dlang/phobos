//Written in the D programming language

/++
    Module containing benchmarking and timing functionality.

    For convenience, this module publicly imports core.time.

    Copyright: Copyright 2010 - 2015
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis and Kato Shoichi
    Source:    $(PHOBOSSRC std/_benchmark.d)
    Macros:
        LREF2=<a href="#$1">$(D $2)</a>
  +/
module std.benchmark;

public import core.time;


/++
   Used by StopWatch to indicate whether it should start immediately upon
   construction.
  +/
enum AutoStart
{
    /// No, don't start the StopWatch when it is constructed.
    no,

    /// Yes, do start the StopWatch when it is constructed.
    yes
}


/++
   StopWatch is used to measure time just like one would do with a physical
   stopwatch, including stopping, restarting, and/or resetting it.

   $(CXREF MonoTime) is used to hold the time, and it uses the system's
   monotonic clock, which is high precision and never counts backwards (unlike
   the wall clock time, which $(I can) count backwards, which is why
   $(XREF datetime, SysTime) should not be used for timing).

   Note that the precision of StopWatch differs from system to system. It is
   impossible for it to be the same for all systems, since the precision of the
   system clock and other system-dependent and situation-dependent factors
   (such as the overhead of a context switch between threads) varies from system
   to system and can affect StopWatch's accuracy.
  +/
struct StopWatch
{
public:

    ///
    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        auto sw = StopWatch(AutoStart.yes);

        Duration t1 = sw.peek();
        Thread.sleep(usecs(1));
        Duration t2 = sw.peek();
        assert(t2 > t1);

        Thread.sleep(usecs(1));
        sw.stop();

        Duration t3 = sw.peek();
        assert(t3 > t2);
        Duration t4 = sw.peek();
        assert(t3 == t4);

        sw.start();
        Thread.sleep(usecs(1));

        Duration t5 = sw.peek();
        assert(t5 > t4);

        // If stopping or resetting the StopWatch is not required, then
        // MonoTime can easily be used by itself without StopWatch.
        auto before = MonoTime.currTime;
        // do stuff...
        auto timeElapsed = MonoTime.currTime - before;
    }

    /++
        Constructs a StopWatch. Whether it starts immediately depends on the
        $(LREF AutoStart) argument.

        If $(D StopWatch.init) is used, then the constructed StopWatch isn't
        running (and can't be, since no constructor ran).
      +/
    this(AutoStart autostart) @safe nothrow @nogc
    {
        if(autostart)
            start();
    }

    ///
    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        {
            auto sw = StopWatch(AutoStart.yes);
            assert(sw.running);
            Thread.sleep(usecs(1));
            assert(sw.peek() > Duration.zero);
        }
        {
            auto sw = StopWatch(AutoStart.no);
            assert(!sw.running);
            Thread.sleep(usecs(1));
            assert(sw.peek() == Duration.zero);
        }
        {
            StopWatch sw;
            assert(!sw.running);
            Thread.sleep(usecs(1));
            assert(sw.peek() == Duration.zero);
        }

        assert(StopWatch.init == StopWatch(AutoStart.no));
        assert(StopWatch.init != StopWatch(AutoStart.yes));
    }


    /++
       Resets the StopWatch.

       The StopWatch can be reset while it's running, and resetting it while
       it's running will not cause it to stop.
      +/
    void reset() @safe nothrow @nogc
    {
        if(_running)
            _timeStarted = MonoTime.currTime;
        _ticksElapsed = 0;
    }

    ///
    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        auto sw = StopWatch(AutoStart.yes);
        Thread.sleep(usecs(1));
        sw.stop();
        assert(sw.peek() > Duration.zero);
        sw.reset();
        assert(sw.peek() == Duration.zero);
    }

    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        auto sw = StopWatch(AutoStart.yes);
        Thread.sleep(msecs(1));
        assert(sw.peek() > msecs(1));
        immutable before = MonoTime.currTime;

        // Just in case the system clock is slow enough or the system is fast
        // enough for the call to MonoTime.currTime inside of reset to get
        // the same that we just got by calling MonoTime.currTime.
        Thread.sleep(usecs(1));

        sw.reset();
        assert(sw.peek() < msecs(1));
        assert(sw._timeStarted > before);
        assert(sw._timeStarted < MonoTime.currTime);
    }


    /++
       Starts the StopWatch.

       start should not be called if the StopWatch is already running.
      +/
    void start() @safe nothrow @nogc
    in { assert(!running); }
    body
    {
        _running = true;
        _timeStarted = MonoTime.currTime;
    }

    ///
    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        StopWatch sw;
        assert(!sw.running);
        assert(sw.peek() == Duration.zero);
        sw.start();
        assert(sw.running);
        Thread.sleep(usecs(1));
        assert(sw.peek() > Duration.zero);
    }


    /++
       Stops the StopWatch.

       stop should not be called if the StopWatch is not running.
      +/
    void stop() @safe nothrow @nogc
    in { assert(_running); }
    body
    {
        _running = false;
        _ticksElapsed += MonoTime.currTime.ticks - _timeStarted.ticks;
    }

    ///
    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        auto sw = StopWatch(AutoStart.yes);
        assert(sw.running);
        Thread.sleep(usecs(1));
        immutable t1 = sw.peek();
        assert(t1 > Duration.zero);

        sw.stop();
        assert(!sw.running);
        immutable t2 = sw.peek();
        assert(t2 > t1);
        immutable t3 = sw.peek();
        assert(t2 == t3);
    }


    /++
       Peek at the amount of time that the the StopWatch has been running.

       This does not include any time during which the StopWatch was stopped but
       does include $(I all) of the time that it was running and not just the
       time since it was started last.

       Calling reset will reset this to $(D Duration.zero).
      +/
    Duration peek() @safe const nothrow @nogc
    {
        enum hnsecsPerSecond = convert!("seconds", "hnsecs")(1);
        immutable hnsecsMeasured = convClockFreq(_ticksElapsed, MonoTime.ticksPerSecond, hnsecsPerSecond);
        return _running ? MonoTime.currTime - _timeStarted + hnsecs(hnsecsMeasured)
                        : hnsecs(hnsecsMeasured);
    }

    ///
    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        auto sw = StopWatch(AutoStart.no);
        assert(sw.peek() == Duration.zero);
        sw.start();

        Thread.sleep(usecs(1));
        assert(sw.peek() >= usecs(1));

        Thread.sleep(usecs(1));
        assert(sw.peek() >= usecs(2));

        sw.stop();
        immutable stopped = sw.peek();
        Thread.sleep(usecs(1));
        assert(sw.peek() == stopped);

        sw.start();
        Thread.sleep(usecs(1));
        assert(sw.peek() > stopped);
    }

    @safe nothrow @nogc unittest
    {
        assert(StopWatch.init.peek() == Duration.zero);
    }


    /++
       Sets the total time which the StopWatch has been running (i.e. what peek
       returns).

       The StopWatch does not have to be stopped for setTimeElapsed to be
       called, nor will calling it cause the StopWatch to stop.
      +/
    void setTimeElapsed(Duration timeElapsed) @safe nothrow @nogc
    {
        enum hnsecsPerSecond = convert!("seconds", "hnsecs")(1);
        _ticksElapsed = convClockFreq(timeElapsed.total!"hnsecs", hnsecsPerSecond, MonoTime.ticksPerSecond);
        _timeStarted = MonoTime.currTime;
    }

    ///
    @trusted nothrow unittest // Thread.sleep is @system for some reason (and not @nogc)
    {
        import core.thread;
        StopWatch sw;
        sw.setTimeElapsed(hours(1));

        // As discussed in MonoTime's documentation, converting between
        // Duration and ticks is not exact, though it will be close.
        // How exact it is depends on the frequency/resolution of the
        // system's monotonic clock.
        assert(abs(sw.peek() - hours(1)) < usecs(1));

        sw.start();
        Thread.sleep(usecs(1));
        assert(sw.peek() > hours(1) + usecs(1));
    }


    /++
       Returns whether this StopWatch is currently running.
      +/
    @property bool running() @safe const pure nothrow @nogc
    {
        return _running;
    }

    ///
    @safe nothrow @nogc unittest
    {
        StopWatch sw;
        assert(!sw.running);
        sw.start();
        assert(sw.running);
        sw.stop();
        assert(!sw.running);
    }


private:

    // We track the ticks for the elapsed time rather than a Duration so that we
    // don't lose any precision.

    bool _running = false; // Whether the StopWatch is currently running
    MonoTime _timeStarted; // The time the StopWatch started measuring (i.e. when it was started or reset).
    long _ticksElapsed;    // Total time that the StopWatch ran before it was stopped last.
}


/++
    Benchmarks code for speed assessment and comparison.

    Params:
        fun = aliases of callable objects (e.g. function names). Each callable
              object should take no arguments.
        n   = The number of times each function is to be executed.

    Returns:
        The amount of time (as a $(CXREF time, Duration)) that it took to call
        each function $(D n) times. The first value is the length of time that
        it took to call $(D fun[0]) $(D n) times. The second value is the length
        of time it took to call $(D fun[1]) $(D n) times. Etc.
  +/
Duration[fun.length] benchmark(fun...)(uint n)
{
    Duration[fun.length] result;
    auto sw = StopWatch(AutoStart.yes);

    foreach(i, unused; fun)
    {
        sw.reset();
        foreach(j; 0 .. n)
            fun[i]();
        result[i] = sw.peek();
    }

    return result;
}

///
@safe unittest
{
    import core.time, std.conv;
    int a;
    void f0() {}
    void f1() { auto b = a; }
    void f2() { auto b = to!string(a); }
    auto r = benchmark!(f0, f1, f2)(10_000);
    Duration f0Result = r[0]; // time f0 took to run 10,000 times
    Duration f1Result = r[1]; // time f1 took to run 10,000 times
    Duration f2Result = r[2]; // time f2 took to run 10,000 times
}

@safe nothrow unittest
{
    import std.conv;
    int a;
    void f0() nothrow {}
    void f1() nothrow { auto b = to!string(a); }
    auto r = benchmark!(f0, f1)(1000);
    assert(r[0] > Duration.zero);
    assert(r[1] > Duration.zero);
    assert(r[1] > r[0]);
    assert(r[0] < seconds(1));
    assert(r[1] < seconds(1));
}

@safe nothrow @nogc unittest
{
    int f0Count;
    int f1Count;
    int f2Count;
    void f0() nothrow @nogc { ++f0Count; }
    void f1() nothrow @nogc { ++f1Count; }
    void f2() nothrow @nogc { ++f2Count; }
    auto r = benchmark!(f0, f1, f2)(552);
    assert(f0Count == 552);
    assert(f1Count == 552);
    assert(f2Count == 552);
}
