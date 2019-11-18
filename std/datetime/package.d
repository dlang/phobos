// Written in the D programming language

/++
    $(SCRIPT inhibitQuickIndex = 1;)

    Phobos provides the following functionality for time:

    $(DIVC quickindex,
    $(BOOKTABLE ,
    $(TR $(TH Functionality) $(TH Symbols)
    )
    $(TR
        $(TD Points in Time)
        $(TD
            $(REF_ALTTEXT Date, Date, std, datetime, date)$(NBSP)
            $(REF_ALTTEXT TimeOfDay, TimeOfDay, std, datetime, date)$(NBSP)
            $(REF_ALTTEXT DateTime, DateTime, std, datetime, date)$(NBSP)
            $(REF_ALTTEXT SysTime, SysTime, std, datetime, systime)$(NBSP)
        )
    )
    $(TR
        $(TD Timezones)
        $(TD
            $(REF_ALTTEXT TimeZone, TimeZone, std, datetime, timezone)$(NBSP)
            $(REF_ALTTEXT UTC, UTC, std, datetime, timezone)$(NBSP)
            $(REF_ALTTEXT LocalTime, LocalTime, std, datetime, timezone)$(NBSP)
            $(REF_ALTTEXT PosixTimeZone, PosixTimeZone, std, datetime, timezone)$(NBSP)
            $(REF_ALTTEXT WindowsTimeZone, WindowsTimeZone, std, datetime, timezone)$(NBSP)
            $(REF_ALTTEXT SimpleTimeZone, SimpleTimeZone, std, datetime, timezone)$(NBSP)
        )
    )
    $(TR
        $(TD Intervals and Ranges of Time)
        $(TD
            $(REF_ALTTEXT Interval, Interval, std, datetime, interval)$(NBSP)
            $(REF_ALTTEXT PosInfInterval, PosInfInterval, std, datetime, interval)$(NBSP)
            $(REF_ALTTEXT NegInfInterval, NegInfInterval, std, datetime, interval)$(NBSP)
        )
    )
    $(TR
        $(TD Durations of Time)
        $(TD
            $(REF_ALTTEXT Duration, Duration, core, time)$(NBSP)
            $(REF_ALTTEXT weeks, weeks, core, time)$(NBSP)
            $(REF_ALTTEXT days, days, core, time)$(NBSP)
            $(REF_ALTTEXT hours, hours, core, time)$(NBSP)
            $(REF_ALTTEXT minutes, minutes, core, time)$(NBSP)
            $(REF_ALTTEXT seconds, seconds, core, time)$(NBSP)
            $(REF_ALTTEXT msecs, msecs, core, time)$(NBSP)
            $(REF_ALTTEXT usecs, usecs, core, time)$(NBSP)
            $(REF_ALTTEXT hnsecs, hnsecs, core, time)$(NBSP)
            $(REF_ALTTEXT nsecs, nsecs, core, time)$(NBSP)
        )
    )
    $(TR
        $(TD Time Measurement and Benchmarking)
        $(TD
            $(REF_ALTTEXT MonoTime, MonoTime, core, time)$(NBSP)
            $(REF_ALTTEXT StopWatch, StopWatch, std, datetime, stopwatch)$(NBSP)
            $(REF_ALTTEXT benchmark, benchmark, std, datetime, stopwatch)$(NBSP)
        )
    )
    ))

    This functionality is separated into the following modules

    $(UL
        $(LI $(MREF std, datetime, date) for points in time without timezones.)
        $(LI $(MREF std, datetime, timezone) for classes which represent timezones.)
        $(LI $(MREF std, datetime, systime) for a point in time with a timezone.)
        $(LI $(MREF std, datetime, interval) for types which represent series of points in time.)
        $(LI $(MREF std, datetime, stopwatch) for measuring time.)
    )

    See_Also:
        $(DDLINK intro-to-datetime, Introduction to std.datetime,
                 Introduction to std&#46;datetime)<br>
        $(HTTP en.wikipedia.org/wiki/ISO_8601, ISO 8601)<br>
        $(HTTP en.wikipedia.org/wiki/Tz_database,
              Wikipedia entry on TZ Database)<br>
        $(HTTP en.wikipedia.org/wiki/List_of_tz_database_time_zones,
              List of Time Zones)<br>

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(HTTP jmdavisprog.com, Jonathan M Davis) and Kato Shoichi
    Source:    $(PHOBOSSRC std/datetime/package.d)
+/
module std.datetime;

/// Get the current time from the system clock
@safe unittest
{
    import std.datetime.systime : SysTime, Clock;

    SysTime currentTime = Clock.currTime();
}

/**
Construct a specific point in time without timezone information
and get its ISO string.
 */
@safe unittest
{
    import std.datetime.date : DateTime;

    auto dt = DateTime(2018, 1, 1, 12, 30, 10);
    assert(dt.toISOString() == "20180101T123010");
    assert(dt.toISOExtString() == "2018-01-01T12:30:10");
}

/**
Construct a specific point in time in the UTC timezone and
add two days.
 */
@safe unittest
{
    import std.datetime.systime : SysTime;
    import std.datetime.timezone : UTC;
    import core.time : days;

    auto st = SysTime(DateTime(2018, 1, 1, 12, 30, 10), UTC());
    assert(st.toISOExtString() == "2018-01-01T12:30:10Z");
    st += 2.days;
    assert(st.toISOExtString() == "2018-01-03T12:30:10Z");
}

public import core.time;
public import std.datetime.date;
public import std.datetime.interval;
public import std.datetime.systime;
public import std.datetime.timezone;

import core.exception : AssertError;
import std.functional : unaryFun;
import std.traits;
import std.typecons : Flag, Yes, No;


// Verify module example.
@safe unittest
{
    auto currentTime = Clock.currTime();
    auto timeString = currentTime.toISOExtString();
    auto restoredTime = SysTime.fromISOExtString(timeString);
}

// Verify Examples for core.time.Duration which couldn't be in core.time.
@safe unittest
{
    assert(std.datetime.Date(2010, 9, 7) + dur!"days"(5) ==
           std.datetime.Date(2010, 9, 12));

    assert(std.datetime.Date(2010, 9, 7) - std.datetime.Date(2010, 10, 3) ==
           dur!"days"(-26));
}

@safe unittest
{
    import std.traits : hasUnsharedAliasing;
    /* Issue 6642 */
    static assert(!hasUnsharedAliasing!Date);
    static assert(!hasUnsharedAliasing!TimeOfDay);
    static assert(!hasUnsharedAliasing!DateTime);
    static assert(!hasUnsharedAliasing!SysTime);
}

// @@@DEPRECATED_2018-10@@@
/*
    $(RED The old benchmarking functionality in std.datetime (which uses
          $(REF TickDuration,core,time)) has been deprecated. Use what's in
          std.datetime.stopwatch instead. It uses $(REF MonoTime,core,time) and
          $(REF Duration,core,time). See
          $(REF AutoStart,std,datetime,stopwatch). This symbol will be removed
          from the documentation in October 2018 and fully removed from Phobos
          in October 2019.)

    Used by StopWatch to indicate whether it should start immediately upon
    construction.

    If set to `AutoStart.no`, then the stopwatch is not started when it is
    constructed.

    Otherwise, if set to `AutoStart.yes`, then the stopwatch is started when
    it is constructed.
  */
deprecated("To be removed after 2.094. Use std.datetime.stopwatch.AutoStart instead.")
alias AutoStart = Flag!"autoStart";


// @@@DEPRECATED_2018-10@@@
/*
    $(RED The old benchmarking functionality in std.datetime (which uses
          $(REF TickDuration,core,time)) has been deprecated. Use what's in
          std.datetime.stopwatch instead. It uses $(REF MonoTime,core,time) and
          $(REF Duration,core,time). See
          $(REF _StopWatch,std,datetime,stopwatch). This symbol will be removed
          from the documentation in October 2018 and fully removed from Phobos
          in October 2019.)

    `StopWatch` measures time as precisely as possible.

    This class uses a high-performance counter. On Windows systems, it uses
    `QueryPerformanceCounter`, and on Posix systems, it uses
    `clock_gettime` if available, and `gettimeofday` otherwise.

    But the precision of `StopWatch` differs from system to system. It is
    impossible to for it to be the same from system to system since the precision
    of the system clock varies from system to system, and other system-dependent
    and situation-dependent stuff (such as the overhead of a context switch
    between threads) can also affect `StopWatch`'s accuracy.
  */
deprecated("To be removed after 2.094. Use std.datetime.stopwatch.StopWatch instead.")
@safe struct StopWatch
{
public:

    /*
       Auto start with constructor.
      */
    this(AutoStart autostart) @nogc
    {
        if (autostart)
            start();
    }

    @nogc @safe unittest
    {
        auto sw = StopWatch(Yes.autoStart);
        sw.stop();
    }


    ///
    bool opEquals(const StopWatch rhs) const pure nothrow @nogc
    {
        return opEquals(rhs);
    }

    /// ditto
    bool opEquals(const ref StopWatch rhs) const pure nothrow @nogc
    {
        return _timeStart == rhs._timeStart &&
               _timeMeasured == rhs._timeMeasured;
    }


    /*
       Resets the stop watch.
      */
    void reset() @nogc
    {
        if (_flagStarted)
        {
            // Set current system time if StopWatch is measuring.
            _timeStart = TickDuration.currSystemTick;
        }
        else
        {
            // Set zero if StopWatch is not measuring.
            _timeStart.length = 0;
        }

        _timeMeasured.length = 0;
    }

    @nogc @safe unittest
    {
        StopWatch sw;
        sw.start();
        sw.stop();
        sw.reset();
        assert(sw.peek().to!("seconds", real)() == 0);
    }


    /*
       Starts the stop watch.
      */
    void start() @nogc
    {
        assert(!_flagStarted);
        _flagStarted = true;
        _timeStart = TickDuration.currSystemTick;
    }

    @nogc @system unittest
    {
        StopWatch sw;
        sw.start();
        auto t1 = sw.peek();
        bool doublestart = true;
        try
            sw.start();
        catch (AssertError e)
            doublestart = false;
        assert(!doublestart);
        sw.stop();
        assert((t1 - sw.peek()).to!("seconds", real)() <= 0);
    }


    /*
       Stops the stop watch.
      */
    void stop() @nogc
    {
        assert(_flagStarted);
        _flagStarted = false;
        _timeMeasured += TickDuration.currSystemTick - _timeStart;
    }

    @nogc @system unittest
    {
        StopWatch sw;
        sw.start();
        sw.stop();
        auto t1 = sw.peek();
        bool doublestop = true;
        try
            sw.stop();
        catch (AssertError e)
            doublestop = false;
        assert(!doublestop);
        assert((t1 - sw.peek()).to!("seconds", real)() == 0);
    }


    /*
       Peek at the amount of time which has passed since the stop watch was
       started.
      */
    TickDuration peek() const @nogc
    {
        if (_flagStarted)
            return TickDuration.currSystemTick - _timeStart + _timeMeasured;

        return _timeMeasured;
    }

    @nogc @safe unittest
    {
        StopWatch sw;
        sw.start();
        auto t1 = sw.peek();
        sw.stop();
        auto t2 = sw.peek();
        auto t3 = sw.peek();
        assert(t1 <= t2);
        assert(t2 == t3);
    }


    /*
       Set the amount of time which has been measured since the stop watch was
       started.
      */
    void setMeasured(TickDuration d) @nogc
    {
        reset();
        _timeMeasured = d;
    }

    @nogc @safe unittest
    {
        StopWatch sw;
        TickDuration t0;
        t0.length = 100;
        sw.setMeasured(t0);
        auto t1 = sw.peek();
        assert(t0 == t1);
    }


    /*
       Confirm whether this stopwatch is measuring time.
      */
    bool running() @property const pure nothrow @nogc
    {
        return _flagStarted;
    }

    @nogc @safe unittest
    {
        StopWatch sw1;
        assert(!sw1.running);
        sw1.start();
        assert(sw1.running);
        sw1.stop();
        assert(!sw1.running);
        StopWatch sw2 = Yes.autoStart;
        assert(sw2.running);
        sw2.stop();
        assert(!sw2.running);
        sw2.start();
        assert(sw2.running);
    }




private:

    // true if observing.
    bool _flagStarted = false;

    // TickDuration at the time of StopWatch starting measurement.
    TickDuration _timeStart;

    // Total time that StopWatch ran.
    TickDuration _timeMeasured;
}

deprecated @safe unittest
{
    void writeln(S...)(S args){}
    static void bar() {}

    StopWatch sw;
    enum n = 100;
    TickDuration[n] times;
    TickDuration last = TickDuration.from!"seconds"(0);
    foreach (i; 0 .. n)
    {
       sw.start(); //start/resume mesuring.
       foreach (unused; 0 .. 1_000_000)
           bar();
       sw.stop();  //stop/pause measuring.
       //Return value of peek() after having stopped are the always same.
       writeln((i + 1) * 1_000_000, " times done, lap time: ",
               sw.peek().msecs, "[ms]");
       times[i] = sw.peek() - last;
       last = sw.peek();
    }
    real sum = 0;
    // To get the number of seconds,
    // use properties of TickDuration.
    // (seconds, msecs, usecs, hnsecs)
    foreach (t; times)
       sum += t.hnsecs;
    writeln("Average time: ", sum/n, " hnsecs");
}


// @@@DEPRECATED_2018-10@@@
/*
    $(RED The old benchmarking functionality in std.datetime (which uses
          $(REF TickDuration,core,time)) has been deprecated. Use what's in
          std.datetime.stopwatch instead. It uses $(REF MonoTime,core,time) and
          $(REF Duration,core,time). See
          $(REF benchmark,std,datetime,stopwatch). This symbol will be removed
          from the documentation in October 2018 and fully removed from Phobos
          in October 2019.)

    Benchmarks code for speed assessment and comparison.

    Params:
        fun = aliases of callable objects (e.g. function names). Each should
              take no arguments.
        n   = The number of times each function is to be executed.

    Returns:
        The amount of time (as a $(REF TickDuration, core,time)) that it took to
        call each function `n` times. The first value is the length of time
        that it took to call `fun[0]` `n` times. The second value is the
        length of time it took to call `fun[1]` `n` times. Etc.

    Note that casting the TickDurations to $(REF Duration, core,time)s will make
    the results easier to deal with (and it may change in the future that
    benchmark will return an array of Durations rather than TickDurations).

    See_Also:
        $(LREF measureTime)
  */
deprecated("To be removed after 2.094. Use std.datetime.stopwatch.benchmark instead.")
TickDuration[fun.length] benchmark(fun...)(uint n)
{
    TickDuration[fun.length] result;
    StopWatch sw;
    sw.start();

    foreach (i, unused; fun)
    {
        sw.reset();
        foreach (j; 0 .. n)
            fun[i]();
        result[i] = sw.peek();
    }

    return result;
}

deprecated @safe unittest
{
    import std.conv : to;
    int a;
    void f0() {}
    void f1() {auto b = a;}
    void f2() {auto b = to!string(a);}
    auto r = benchmark!(f0, f1, f2)(10_000);
    auto f0Result = to!Duration(r[0]); // time f0 took to run 10,000 times
    auto f1Result = to!Duration(r[1]); // time f1 took to run 10,000 times
    auto f2Result = to!Duration(r[2]); // time f2 took to run 10,000 times
}

deprecated @safe unittest
{
    int a;
    void f0() {}
    //void f1() {auto b = to!(string)(a);}
    void f2() {auto b = (a);}
    auto r = benchmark!(f0, f2)(100);
}


// @@@DEPRECATED_2018-10@@@
/*
    $(RED The old benchmarking functionality in std.datetime (which uses
          $(REF TickDuration,core,time)) has been deprecated. Use what's in
          std.datetime.stopwatch instead. It uses $(REF MonoTime,core,time) and
          $(REF Duration,core,time). Note that comparingBenchmark has
          not been ported over, because it's a trivial wrapper around benchmark.
          See $(REF benchmark,std,datetime,stopwatch). This symbol will be
          removed from the documentation in October 2018 and fully removed from
          Phobos in October 2019.)

    Benchmark with two functions comparing.

    Params:
        baseFunc   = The function to become the base of the speed.
        targetFunc = The function that wants to measure speed.
        times      = The number of times each function is to be executed.
  */
deprecated("To be removed after 2.094. Use std.datetime.stopwatch.benchmark instead.")
@safe struct ComparingBenchmarkResult
{
    /*
       Evaluation value

       This returns the evaluation value of performance as the ratio of
       baseFunc's time over targetFunc's time. If performance is high, this
       returns a high value.
      */
    @property real point() const pure nothrow
    {
        return _baseTime.length / cast(const real)_targetTime.length;
    }


    /*
       The time required of the base function
      */
    @property public TickDuration baseTime() const pure nothrow
    {
        return _baseTime;
    }


    /*
       The time required of the target function
      */
    @property public TickDuration targetTime() const pure nothrow
    {
        return _targetTime;
    }

private:

    this(TickDuration baseTime, TickDuration targetTime) pure nothrow
    {
        _baseTime = baseTime;
        _targetTime = targetTime;
    }

    TickDuration _baseTime;
    TickDuration _targetTime;
}


// @@@DEPRECATED_2018-10@@@
// ditto
deprecated("To be removed after 2.094. Use std.datetime.stopwatch.benchmark instead.")
ComparingBenchmarkResult comparingBenchmark(alias baseFunc,
                                            alias targetFunc,
                                            int times = 0xfff)()
{
    auto t = benchmark!(baseFunc, targetFunc)(times);
    return ComparingBenchmarkResult(t[0], t[1]);
}

//
deprecated @safe unittest
{
    void f1x() {}
    void f2x() {}
    @safe void f1o() {}
    @safe void f2o() {}
    auto b1 = comparingBenchmark!(f1o, f2o, 1)(); // OK
    //writeln(b1.point);
}

//Bug# 8450
deprecated @system unittest
{
    @safe    void safeFunc() {}
    @trusted void trustFunc() {}
    @system  void sysFunc() {}
    auto safeResult  = comparingBenchmark!((){safeFunc();}, (){safeFunc();})();
    auto trustResult = comparingBenchmark!((){trustFunc();}, (){trustFunc();})();
    auto sysResult   = comparingBenchmark!((){sysFunc();}, (){sysFunc();})();
    auto mixedResult1  = comparingBenchmark!((){safeFunc();}, (){trustFunc();})();
    auto mixedResult2  = comparingBenchmark!((){trustFunc();}, (){sysFunc();})();
    auto mixedResult3  = comparingBenchmark!((){safeFunc();}, (){sysFunc();})();
}


// @@@DEPRECATED_2018-10@@@
/*
    $(RED The old benchmarking functionality in std.datetime (which uses
          $(REF TickDuration,core,time)) has been deprecated. Use what's in
          std.datetime.stopwatch instead. It uses $(REF MonoTime,core,time) and
          $(REF Duration,core,time). Note that measureTime has not been ported
          over, because it's a trivial wrapper around StopWatch. See
          $(REF StopWatch,std,datetime,stopwatch). This symbol will be removed
          from the documentation in October 2018 and fully removed from Phobos
          in October 2019.)

    Function for starting to a stop watch time when the function is called
    and stopping it when its return value goes out of scope and is destroyed.

    When the value that is returned by this function is destroyed,
    `func` will run. `func` is a unary function that takes a
    $(REF TickDuration, core,time).

    See_Also:
        $(LREF benchmark)
*/
deprecated("To be removed after 2.094. Use std.datetime.stopwatch.StopWatch instead.")
@safe auto measureTime(alias func)()
if (isSafe!((){StopWatch sw; unaryFun!func(sw.peek());}))
{
    struct Result
    {
        private StopWatch _sw = void;
        this(AutoStart as)
        {
            _sw = StopWatch(as);
        }
        ~this()
        {
            unaryFun!(func)(_sw.peek());
        }
    }
    return Result(Yes.autoStart);
}

// Ditto
deprecated("To be removed after 2.094. Use std.datetime.stopwatch.StopWatch instead.")
auto measureTime(alias func)()
if (!isSafe!((){StopWatch sw; unaryFun!func(sw.peek());}))
{
    struct Result
    {
        private StopWatch _sw = void;
        this(AutoStart as)
        {
            _sw = StopWatch(as);
        }
        ~this()
        {
            unaryFun!(func)(_sw.peek());
        }
    }
    return Result(Yes.autoStart);
}

//
deprecated @safe unittest
{
    {
        auto mt = measureTime!((TickDuration a)
            { /+ do something when the scope is exited +/ });
        // do something that needs to be timed
    }

    // functionally equivalent to the above
    {
        auto sw = StopWatch(Yes.autoStart);
        scope(exit)
        {
            TickDuration a = sw.peek();
            /+ do something when the scope is exited +/
        }
        // do something that needs to be timed
    }
}

deprecated @safe unittest
{
    import std.math : isNaN;

    @safe static void func(TickDuration td)
    {
        assert(!td.to!("seconds", real)().isNaN());
    }

    auto mt = measureTime!(func)();

    /+
    with (measureTime!((a){assert(a.seconds);}))
    {
        // doSomething();
        // @@@BUG@@@ doesn't work yet.
    }
    +/
}

deprecated @safe unittest
{
    import std.math : isNaN;

    static void func(TickDuration td)
    {
        assert(!td.to!("seconds", real)().isNaN());
    }

    auto mt = measureTime!(func)();

    /+
    with (measureTime!((a){assert(a.seconds);}))
    {
        // doSomething();
        // @@@BUG@@@ doesn't work yet.
    }
    +/
}

//Bug# 8450
deprecated @system unittest
{
    @safe    void safeFunc() {}
    @trusted void trustFunc() {}
    @system  void sysFunc() {}
    auto safeResult  = measureTime!((a){safeFunc();})();
    auto trustResult = measureTime!((a){trustFunc();})();
    auto sysResult   = measureTime!((a){sysFunc();})();
}
