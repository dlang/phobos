//Written in the D programming language

/++
    Module containing Date/Time functionality.

    This module provides:
    $(UL
        $(LI Types to represent points in time: $(LREF SysTime), $(LREF Date),
             $(LREF TimeOfDay), and $(LREF2 .DateTime, DateTime).)
        $(LI Types to represent intervals of time.)
        $(LI Types to represent ranges over intervals of time.)
        $(LI Types to represent time zones (used by $(LREF SysTime)).)
        $(LI A platform-independent, high precision stopwatch type:
             $(LREF StopWatch))
        $(LI Benchmarking functions.)
        $(LI Various helper functions.)
    )

    Closely related to std.datetime is <a href="core_time.html">$(D core.time)</a>,
    and some of the time types used in std.datetime come from there - such as
    $(REF Duration, core,time), $(REF TickDuration, core,time), and
    $(REF FracSec, core,time).
    core.time is publically imported into std.datetime, it isn't necessary
    to import it separately.

    Three of the main concepts used in this module are time points, time
    durations, and time intervals.

    A time point is a specific point in time. e.g. January 5th, 2010
    or 5:00.

    A time duration is a length of time with units. e.g. 5 days or 231 seconds.

    A time interval indicates a period of time associated with a fixed point in
    time. It is either two time points associated with each other,
    indicating the time starting at the first point up to, but not including,
    the second point - e.g. [January 5th, 2010 - March 10th, 2010$(RPAREN) - or
    it is a time point and a time duration associated with one another. e.g.
    January 5th, 2010 and 5 days, indicating [January 5th, 2010 -
    January 10th, 2010$(RPAREN).

    Various arithmetic operations are supported between time points and
    durations (e.g. the difference between two time points is a time duration),
    and ranges can be gotten from time intervals, so range-based operations may
    be done on a series of time points.

    The types that the typical user is most likely to be interested in are
    $(LREF Date) (if they want dates but don't care about time), $(LREF DateTime)
    (if they want dates and times but don't care about time zones), $(LREF SysTime)
    (if they want the date and time from the OS and/or do care about time
    zones), and StopWatch (a platform-independent, high precision stop watch).
    $(LREF Date) and $(LREF DateTime) are optimized for calendar-based operations,
    while $(LREF SysTime) is designed for dealing with time from the OS. Check out
    their specific documentation for more details.

    To get the current time, use $(LREF2 .Clock.currTime, Clock.currTime).
    It will return the current
    time as a $(LREF SysTime). To print it, $(D toString) is
    sufficient, but if using $(D toISOString), $(D toISOExtString), or
    $(D toSimpleString), use the corresponding $(D fromISOString),
    $(D fromISOExtString), or $(D fromSimpleString) to create a
    $(LREF SysTime) from the string.

--------------------
auto currentTime = Clock.currTime();
auto timeString = currentTime.toISOExtString();
auto restoredTime = SysTime.fromISOExtString(timeString);
--------------------

    Various functions take a string (or strings) to represent a unit of time
    (e.g. $(D convert!("days", "hours")(numDays))). The valid strings to use
    with such functions are $(D "years"), $(D "months"), $(D "weeks"),
    $(D "days"), $(D "hours"), $(D "minutes"), $(D "seconds"),
    $(D "msecs") (milliseconds), $(D "usecs") (microseconds),
    $(D "hnsecs") (hecto-nanoseconds - i.e. 100 ns), or some subset thereof.
    There are a few functions in core.time which take $(D "nsecs"), but because
    nothing in std.datetime has precision greater than hnsecs, and very little
    in core.time does, no functions in std.datetime accept $(D "nsecs").
    To remember which units are abbreviated and which aren't,
    all units seconds and greater use their full names, and all
    sub-second units are abbreviated (since they'd be rather long if they
    weren't).

    Note:
        $(LREF DateTimeException) is an alias for $(REF TimeException, core,time),
        so you don't need to worry about core.time functions and std.datetime
        functions throwing different exception types (except in the rare case
        that they throw something other than $(REF TimeException, core,time) or
        $(LREF DateTimeException)).

    See_Also:
        $(DDLINK intro-to-_datetime, Introduction to std.datetime,
                 Introduction to std&#46;_datetime)<br>
        $(HTTP en.wikipedia.org/wiki/ISO_8601, ISO 8601)<br>
        $(HTTP en.wikipedia.org/wiki/Tz_database,
              Wikipedia entry on TZ Database)<br>
        $(HTTP en.wikipedia.org/wiki/List_of_tz_database_time_zones,
              List of Time Zones)<br>

    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis and Kato Shoichi
    Source:    $(PHOBOSSRC std/_datetime.d)
    Macros:
        LREF2=<a href="#$1">$(D $2)</a>
+/
module std.datetime;

public import core.time;
public import std.datetime.common;
public import std.datetime.date;
public import std.datetime.datetime;
public import std.datetime.interval;
public import std.datetime.systime;
public import std.datetime.timeofday;
public import std.datetime.timezone;


import core.exception; // AssertError

import std.typecons : Flag, Yes, No;
import std.exception; // assertThrown, enforce
import std.range.primitives; // back, ElementType, empty, front, hasLength,
    // hasSlicing, isRandomAccessRange, popFront
import std.traits; // isIntegral, isSafe, isSigned, isSomeString, Unqual
// FIXME
import std.functional; //: unaryFun;

version(Windows)
{
    import core.stdc.time; // time_t
    import core.sys.windows.windows;
    import core.sys.windows.winsock2;
    import std.windows.registry;

    // Uncomment and run unittests to print missing Windows TZ translations.
    // Please subscribe to Microsoft Daylight Saving Time & Time Zone Blog
    // (https://blogs.technet.microsoft.com/dst2007/) if you feel responsible
    // for updating the translations.
    // version = UpdateWindowsTZTranslations;
}
else version(Posix)
{
    import core.sys.posix.signal : timespec;
    import core.sys.posix.sys.types; // time_t
}

//Verify module example.
@safe unittest
{
    auto currentTime = Clock.currTime();
    auto timeString = currentTime.toISOExtString();
    auto restoredTime = SysTime.fromISOExtString(timeString);
}

//Verify Examples for core.time.Duration which couldn't be in core.time.
@safe unittest
{
    assert(std.datetime.Date(2010, 9, 7) + dur!"days"(5) ==
           std.datetime.Date(2010, 9, 12));

    assert(std.datetime.Date(2010, 9, 7) - std.datetime.Date(2010, 10, 3) ==
           dur!"days"(-26));
}


//==============================================================================
// Section with public enums and constants.
//==============================================================================

/++
   Used by StopWatch to indicate whether it should start immediately upon
   construction.

   If set to $(D AutoStart.no), then the stopwatch is not started when it is
   constructed.

   Otherwise, if set to $(D AutoStart.yes), then the stopwatch is started when
   it is constructed.
  +/
alias AutoStart = Flag!"autoStart";


//==============================================================================
// Section with StopWatch and Benchmark Code.
//==============================================================================

/++
   $(D StopWatch) measures time as precisely as possible.

   This class uses a high-performance counter. On Windows systems, it uses
   $(D QueryPerformanceCounter), and on Posix systems, it uses
   $(D clock_gettime) if available, and $(D gettimeofday) otherwise.

   But the precision of $(D StopWatch) differs from system to system. It is
   impossible to for it to be the same from system to system since the precision
   of the system clock varies from system to system, and other system-dependent
   and situation-dependent stuff (such as the overhead of a context switch
   between threads) can also affect $(D StopWatch)'s accuracy.
  +/
@safe struct StopWatch
{
public:

    /++
       Auto start with constructor.
      +/
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


    /++
       Resets the stop watch.
      +/
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

    ///
    @nogc @safe unittest
    {
        StopWatch sw;
        sw.start();
        sw.stop();
        sw.reset();
        assert(sw.peek().to!("seconds", real)() == 0);
    }


    /++
       Starts the stop watch.
      +/
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


    /++
       Stops the stop watch.
      +/
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


    /++
       Peek at the amount of time which has passed since the stop watch was
       started.
      +/
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


    /++
       Set the amount of time which has been measured since the stop watch was
       started.
      +/
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


    /++
       Confirm whether this stopwatch is measuring time.
      +/
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

///
@safe unittest
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


/++
    Benchmarks code for speed assessment and comparison.

    Params:
        fun = aliases of callable objects (e.g. function names). Each should
              take no arguments.
        n   = The number of times each function is to be executed.

    Returns:
        The amount of time (as a $(REF TickDuration, core,time)) that it took to
        call each function $(D n) times. The first value is the length of time
        that it took to call $(D fun[0]) $(D n) times. The second value is the
        length of time it took to call $(D fun[1]) $(D n) times. Etc.

    Note that casting the TickDurations to $(REF Duration, core,time)s will make
    the results easier to deal with (and it may change in the future that
    benchmark will return an array of Durations rather than TickDurations).

    See_Also:
        $(LREF measureTime)
  +/
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

///
@safe unittest
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

@safe unittest
{
    int a;
    void f0() {}
    //void f1() {auto b = to!(string)(a);}
    void f2() {auto b = (a);}
    auto r = benchmark!(f0, f2)(100);
}


/++
   Return value of benchmark with two functions comparing.
  +/
@safe struct ComparingBenchmarkResult
{
    /++
       Evaluation value

       This returns the evaluation value of performance as the ratio of
       baseFunc's time over targetFunc's time. If performance is high, this
       returns a high value.
      +/
    @property real point() const pure nothrow
    {
        return _baseTime.length / cast(const real)_targetTime.length;
    }


    /++
       The time required of the base function
      +/
    @property public TickDuration baseTime() const pure nothrow
    {
        return _baseTime;
    }


    /++
       The time required of the target function
      +/
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


/++
   Benchmark with two functions comparing.

   Params:
       baseFunc   = The function to become the base of the speed.
       targetFunc = The function that wants to measure speed.
       times      = The number of times each function is to be executed.
  +/
ComparingBenchmarkResult comparingBenchmark(alias baseFunc,
                                            alias targetFunc,
                                            int times = 0xfff)()
{
    auto t = benchmark!(baseFunc, targetFunc)(times);
    return ComparingBenchmarkResult(t[0], t[1]);
}

///
@safe unittest
{
    void f1x() {}
    void f2x() {}
    @safe void f1o() {}
    @safe void f2o() {}
    auto b1 = comparingBenchmark!(f1o, f2o, 1)(); // OK
    //writeln(b1.point);
}

//Bug# 8450
@system unittest
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


//==============================================================================
// Section with public helper functions and templates.
//==============================================================================


version(StdDdoc)
{
    version(Windows) {}
    else
    {
        alias SYSTEMTIME = void*;
        alias FILETIME = void*;
    }

    /++
        $(BLUE This function is Windows-Only.)

        Converts a $(D SYSTEMTIME) struct to a $(LREF SysTime).

        Params:
            st = The $(D SYSTEMTIME) struct to convert.
            tz = The time zone that the time in the $(D SYSTEMTIME) struct is
                 assumed to be (if the $(D SYSTEMTIME) was supplied by a Windows
                 system call, the $(D SYSTEMTIME) will either be in local time
                 or UTC, depending on the call).

        Throws:
            $(LREF DateTimeException) if the given $(D SYSTEMTIME) will not fit in
            a $(LREF SysTime), which is highly unlikely to happen given that
            $(D SysTime.max) is in 29,228 A.D. and the maximum $(D SYSTEMTIME)
            is in 30,827 A.D.
      +/
    SysTime SYSTEMTIMEToSysTime(const SYSTEMTIME* st, immutable TimeZone tz = LocalTime()) @safe;


    /++
        $(BLUE This function is Windows-Only.)

        Converts a $(LREF SysTime) to a $(D SYSTEMTIME) struct.

        The $(D SYSTEMTIME) which is returned will be set using the given
        $(LREF SysTime)'s time zone, so to get the $(D SYSTEMTIME) in
        UTC, set the $(LREF SysTime)'s time zone to UTC.

        Params:
            sysTime = The $(LREF SysTime) to convert.

        Throws:
            $(LREF DateTimeException) if the given $(LREF SysTime) will not fit in a
            $(D SYSTEMTIME). This will only happen if the $(LREF SysTime)'s date is
            prior to 1601 A.D.
      +/
    SYSTEMTIME SysTimeToSYSTEMTIME(in SysTime sysTime) @safe;


    /++
        $(BLUE This function is Windows-Only.)

        Converts a $(D FILETIME) struct to the number of hnsecs since midnight,
        January 1st, 1 A.D.

        Params:
            ft = The $(D FILETIME) struct to convert.

        Throws:
            $(LREF DateTimeException) if the given $(D FILETIME) cannot be
            represented as the return value.
      +/
    long FILETIMEToStdTime(scope const FILETIME* ft) @safe;


    /++
        $(BLUE This function is Windows-Only.)

        Converts a $(D FILETIME) struct to a $(LREF SysTime).

        Params:
            ft = The $(D FILETIME) struct to convert.
            tz = The time zone that the $(LREF SysTime) will be in ($(D FILETIME)s
                 are in UTC).

        Throws:
            $(LREF DateTimeException) if the given $(D FILETIME) will not fit in a
            $(LREF SysTime).
      +/
    SysTime FILETIMEToSysTime(scope const FILETIME* ft, immutable TimeZone tz = LocalTime()) @safe;


    /++
        $(BLUE This function is Windows-Only.)

        Converts a number of hnsecs since midnight, January 1st, 1 A.D. to a
        $(D FILETIME) struct.

        Params:
            stdTime = The number of hnsecs since midnight, January 1st, 1 A.D. UTC.

        Throws:
            $(LREF DateTimeException) if the given value will not fit in a
            $(D FILETIME).
      +/
    FILETIME stdTimeToFILETIME(long stdTime) @safe;


    /++
        $(BLUE This function is Windows-Only.)

        Converts a $(LREF SysTime) to a $(D FILETIME) struct.

        $(D FILETIME)s are always in UTC.

        Params:
            sysTime = The $(LREF SysTime) to convert.

        Throws:
            $(LREF DateTimeException) if the given $(LREF SysTime) will not fit in a
            $(D FILETIME).
      +/
    FILETIME SysTimeToFILETIME(SysTime sysTime) @safe;
}
else version(Windows)
{
    SysTime SYSTEMTIMEToSysTime(const SYSTEMTIME* st, immutable TimeZone tz = LocalTime()) @safe
    {
        const max = SysTime.max;

        static void throwLaterThanMax()
        {
            throw new DateTimeException("The given SYSTEMTIME is for a date greater than SysTime.max.");
        }

        if (st.wYear > max.year)
            throwLaterThanMax();
        else if (st.wYear == max.year)
        {
            if (st.wMonth > max.month)
                throwLaterThanMax();
            else if (st.wMonth == max.month)
            {
                if (st.wDay > max.day)
                    throwLaterThanMax();
                else if (st.wDay == max.day)
                {
                    if (st.wHour > max.hour)
                        throwLaterThanMax();
                    else if (st.wHour == max.hour)
                    {
                        if (st.wMinute > max.minute)
                            throwLaterThanMax();
                        else if (st.wMinute == max.minute)
                        {
                            if (st.wSecond > max.second)
                                throwLaterThanMax();
                            else if (st.wSecond == max.second)
                            {
                                if (st.wMilliseconds > max.fracSecs.total!"msecs")
                                    throwLaterThanMax();
                            }
                        }
                    }
                }
            }
        }

        auto dt = DateTime(st.wYear, st.wMonth, st.wDay,
                           st.wHour, st.wMinute, st.wSecond);

        return SysTime(dt, msecs(st.wMilliseconds), tz);
    }

    @system unittest
    {
        auto sysTime = Clock.currTime(UTC());
        SYSTEMTIME st = void;
        GetSystemTime(&st);
        auto converted = SYSTEMTIMEToSysTime(&st, UTC());

        assert(abs((converted - sysTime)) <= dur!"seconds"(2));
    }


    SYSTEMTIME SysTimeToSYSTEMTIME(in SysTime sysTime) @safe
    {
        immutable dt = cast(DateTime) sysTime;

        if (dt.year < 1601)
            throw new DateTimeException("SYSTEMTIME cannot hold dates prior to the year 1601.");

        SYSTEMTIME st;

        st.wYear = dt.year;
        st.wMonth = dt.month;
        st.wDayOfWeek = dt.dayOfWeek;
        st.wDay = dt.day;
        st.wHour = dt.hour;
        st.wMinute = dt.minute;
        st.wSecond = dt.second;
        st.wMilliseconds = cast(ushort) sysTime.fracSecs.total!"msecs";

        return st;
    }

    @system unittest
    {
        SYSTEMTIME st = void;
        GetSystemTime(&st);
        auto sysTime = SYSTEMTIMEToSysTime(&st, UTC());

        SYSTEMTIME result = SysTimeToSYSTEMTIME(sysTime);

        assert(st.wYear == result.wYear);
        assert(st.wMonth == result.wMonth);
        assert(st.wDayOfWeek == result.wDayOfWeek);
        assert(st.wDay == result.wDay);
        assert(st.wHour == result.wHour);
        assert(st.wMinute == result.wMinute);
        assert(st.wSecond == result.wSecond);
        assert(st.wMilliseconds == result.wMilliseconds);
    }

    private enum hnsecsFrom1601 = 504_911_232_000_000_000L;

    long FILETIMEToStdTime(scope const FILETIME* ft) @safe
    {
        ULARGE_INTEGER ul;
        ul.HighPart = ft.dwHighDateTime;
        ul.LowPart = ft.dwLowDateTime;
        ulong tempHNSecs = ul.QuadPart;

        if (tempHNSecs > long.max - hnsecsFrom1601)
            throw new DateTimeException("The given FILETIME cannot be represented as a stdTime value.");

        return cast(long) tempHNSecs + hnsecsFrom1601;
    }

    SysTime FILETIMEToSysTime(scope const FILETIME* ft, immutable TimeZone tz = LocalTime()) @safe
    {
        auto sysTime = SysTime(FILETIMEToStdTime(ft), UTC());
        sysTime.timezone = tz;

        return sysTime;
    }

    @system unittest
    {
        auto sysTime = Clock.currTime(UTC());
        SYSTEMTIME st = void;
        GetSystemTime(&st);

        FILETIME ft = void;
        SystemTimeToFileTime(&st, &ft);

        auto converted = FILETIMEToSysTime(&ft);

        assert(abs((converted - sysTime)) <= dur!"seconds"(2));
    }


    FILETIME stdTimeToFILETIME(long stdTime) @safe
    {
        if (stdTime < hnsecsFrom1601)
            throw new DateTimeException("The given stdTime value cannot be represented as a FILETIME.");

        ULARGE_INTEGER ul;
        ul.QuadPart = cast(ulong) stdTime - hnsecsFrom1601;

        FILETIME ft;
        ft.dwHighDateTime = ul.HighPart;
        ft.dwLowDateTime = ul.LowPart;

        return ft;
    }

    FILETIME SysTimeToFILETIME(SysTime sysTime) @safe
    {
        return stdTimeToFILETIME(sysTime.stdTime);
    }

    @system unittest
    {
        SYSTEMTIME st = void;
        GetSystemTime(&st);

        FILETIME ft = void;
        SystemTimeToFileTime(&st, &ft);
        auto sysTime = FILETIMEToSysTime(&ft, UTC());

        FILETIME result = SysTimeToFILETIME(sysTime);

        assert(ft.dwLowDateTime == result.dwLowDateTime);
        assert(ft.dwHighDateTime == result.dwHighDateTime);
    }
}


/++
    Type representing the DOS file date/time format.
  +/
alias DosFileTime = uint;

/++
    Converts from DOS file date/time to $(LREF SysTime).

    Params:
        dft = The DOS file time to convert.
        tz  = The time zone which the DOS file time is assumed to be in.

    Throws:
        $(LREF DateTimeException) if the $(D DosFileTime) is invalid.
  +/
SysTime DosFileTimeToSysTime(DosFileTime dft, immutable TimeZone tz = LocalTime()) @safe
{
    uint dt = cast(uint) dft;

    if (dt == 0)
        throw new DateTimeException("Invalid DosFileTime.");

    int year = ((dt >> 25) & 0x7F) + 1980;
    int month = ((dt >> 21) & 0x0F);       // 1 .. 12
    int dayOfMonth = ((dt >> 16) & 0x1F);  // 1 .. 31
    int hour = (dt >> 11) & 0x1F;          // 0 .. 23
    int minute = (dt >> 5) & 0x3F;         // 0 .. 59
    int second = (dt << 1) & 0x3E;         // 0 .. 58 (in 2 second increments)

    try
        return SysTime(DateTime(year, month, dayOfMonth, hour, minute, second), tz);
    catch (DateTimeException dte)
        throw new DateTimeException("Invalid DosFileTime", __FILE__, __LINE__, dte);
}

@safe unittest
{
    assert(DosFileTimeToSysTime(0b00000000001000010000000000000000) ==
                    SysTime(DateTime(1980, 1, 1, 0, 0, 0)));

    assert(DosFileTimeToSysTime(0b11111111100111111011111101111101) ==
                    SysTime(DateTime(2107, 12, 31, 23, 59, 58)));

    assert(DosFileTimeToSysTime(0x3E3F8456) ==
                    SysTime(DateTime(2011, 1, 31, 16, 34, 44)));
}


/++
    Converts from $(LREF SysTime) to DOS file date/time.

    Params:
        sysTime = The $(LREF SysTime) to convert.

    Throws:
        $(LREF DateTimeException) if the given $(LREF SysTime) cannot be converted to
        a $(D DosFileTime).
  +/
DosFileTime SysTimeToDosFileTime(SysTime sysTime) @safe
{
    auto dateTime = cast(DateTime) sysTime;

    if (dateTime.year < 1980)
        throw new DateTimeException("DOS File Times cannot hold dates prior to 1980.");

    if (dateTime.year > 2107)
        throw new DateTimeException("DOS File Times cannot hold dates past 2107.");

    uint retval = 0;
    retval = (dateTime.year - 1980) << 25;
    retval |= (dateTime.month & 0x0F) << 21;
    retval |= (dateTime.day & 0x1F) << 16;
    retval |= (dateTime.hour & 0x1F) << 11;
    retval |= (dateTime.minute & 0x3F) << 5;
    retval |= (dateTime.second >> 1) & 0x1F;

    return cast(DosFileTime) retval;
}

@safe unittest
{
    assert(SysTimeToDosFileTime(SysTime(DateTime(1980, 1, 1, 0, 0, 0))) ==
                    0b00000000001000010000000000000000);

    assert(SysTimeToDosFileTime(SysTime(DateTime(2107, 12, 31, 23, 59, 58))) ==
                    0b11111111100111111011111101111101);

    assert(SysTimeToDosFileTime(SysTime(DateTime(2011, 1, 31, 16, 34, 44))) ==
                    0x3E3F8456);
}


/++
    The given array of $(D char) or random-access range of $(D char) or
    $(D ubyte) is expected to be in the format specified in
    $(HTTP tools.ietf.org/html/rfc5322, RFC 5322) section 3.3 with the
    grammar rule $(I date-time). It is the date-time format commonly used in
    internet messages such as e-mail and HTTP. The corresponding
    $(LREF SysTime) will be returned.

    RFC 822 was the original spec (hence the function's name), whereas RFC 5322
    is the current spec.

    The day of the week is ignored beyond verifying that it's a valid day of the
    week, as the day of the week can be inferred from the date. It is not
    checked whether the given day of the week matches the actual day of the week
    of the given date (though it is technically invalid per the spec if the
    day of the week doesn't match the actual day of the week of the given date).

    If the time zone is $(D "-0000") (or considered to be equivalent to
    $(D "-0000") by section 4.3 of the spec), a $(LREF SimpleTimeZone) with a
    utc offset of $(D 0) is used rather than $(LREF UTC), whereas $(D "+0000")
    uses $(LREF UTC).

    Note that because $(LREF SysTime) does not currently support having a second
    value of 60 (as is sometimes done for leap seconds), if the date-time value
    does have a value of 60 for the seconds, it is treated as 59.

    The one area in which this function violates RFC 5322 is that it accepts
    $(D "\n") in folding whitespace in the place of $(D "\r\n"), because the
    HTTP spec requires it.

    Throws:
        $(LREF DateTimeException) if the given string doesn't follow the grammar
        for a date-time field or if the resulting $(LREF SysTime) is invalid.
  +/
SysTime parseRFC822DateTime()(in char[] value) @safe
{
    import std.string : representation;
    return parseRFC822DateTime(value.representation);
}

/++ Ditto +/
SysTime parseRFC822DateTime(R)(R value) @safe
if (isRandomAccessRange!R && hasSlicing!R && hasLength!R &&
    (is(Unqual!(ElementType!R) == char) || is(Unqual!(ElementType!R) == ubyte)))
{
    import std.algorithm.searching : find, all;
    import std.ascii : isDigit, isAlpha, isPrintable;
    import std.conv : to;
    import std.functional : not;
    import std.range.primitives : ElementEncodingType;
    import std.string : capitalize, format;
    import std.traits : EnumMembers, isArray;
    import std.typecons : Rebindable;

    void stripAndCheckLen(R valueBefore, size_t minLen, size_t line = __LINE__)
    {
        value = _stripCFWS(valueBefore);
        if (value.length < minLen)
            throw new DateTimeException("date-time value too short", __FILE__, line);
    }
    stripAndCheckLen(value, "7Dec1200:00A".length);

    static if (isArray!R && (is(ElementEncodingType!R == char) || is(ElementEncodingType!R == ubyte)))
    {
        static string sliceAsString(R str) @trusted
        {
            return cast(string) str;
        }
    }
    else
    {
        char[4] temp;
        char[] sliceAsString(R str) @trusted
        {
            size_t i = 0;
            foreach (c; str)
                temp[i++] = cast(char) c;
            return temp[0 .. str.length];
        }
    }

    // day-of-week
    if (isAlpha(value[0]))
    {
        auto dowStr = sliceAsString(value[0 .. 3]);
        switch (dowStr)
        {
            foreach (dow; EnumMembers!DayOfWeek)
            {
                enum dowC = capitalize(to!string(dow));
                case dowC:
                    goto afterDoW;
            }
            default: throw new DateTimeException(format("Invalid day-of-week: %s", dowStr));
        }
afterDoW: stripAndCheckLen(value[3 .. value.length], ",7Dec1200:00A".length);
        if (value[0] != ',')
            throw new DateTimeException("day-of-week missing comma");
        stripAndCheckLen(value[1 .. value.length], "7Dec1200:00A".length);
    }

    // day
    immutable digits = isDigit(value[1]) ? 2 : 1;
    immutable day = _convDigits!short(value[0 .. digits]);
    if (day == -1)
        throw new DateTimeException("Invalid day");
    stripAndCheckLen(value[digits .. value.length], "Dec1200:00A".length);

    // month
    Month month;
    {
        auto monStr = sliceAsString(value[0 .. 3]);
        switch (monStr)
        {
            foreach (mon; EnumMembers!Month)
            {
                enum monC = capitalize(to!string(mon));
                case monC:
                {
                    month = mon;
                    goto afterMon;
                }
            }
            default: throw new DateTimeException(format("Invalid month: %s", monStr));
        }
afterMon: stripAndCheckLen(value[3 .. value.length], "1200:00A".length);
    }

    // year
    auto found = value[2 .. value.length].find!(not!(std.ascii.isDigit))();
    size_t yearLen = value.length - found.length;
    if (found.length == 0)
        throw new DateTimeException("Invalid year");
    if (found[0] == ':')
        yearLen -= 2;
    auto year = _convDigits!short(value[0 .. yearLen]);
    if (year < 1900)
    {
        if (year == -1)
            throw new DateTimeException("Invalid year");
        if (yearLen < 4)
        {
            if (yearLen == 3)
                year += 1900;
            else if (yearLen == 2)
                year += year < 50 ? 2000 : 1900;
            else
                throw new DateTimeException("Invalid year. Too few digits.");
        }
        else
            throw new DateTimeException("Invalid year. Cannot be earlier than 1900.");
    }
    stripAndCheckLen(value[yearLen .. value.length], "00:00A".length);

    // hour
    immutable hour = _convDigits!short(value[0 .. 2]);
    stripAndCheckLen(value[2 .. value.length], ":00A".length);
    if (value[0] != ':')
        throw new DateTimeException("Invalid hour");
    stripAndCheckLen(value[1 .. value.length], "00A".length);

    // minute
    immutable minute = _convDigits!short(value[0 .. 2]);
    stripAndCheckLen(value[2 .. value.length], "A".length);

    // second
    short second;
    if (value[0] == ':')
    {
        stripAndCheckLen(value[1 .. value.length], "00A".length);
        second = _convDigits!short(value[0 .. 2]);
        // this is just if/until SysTime is sorted out to fully support leap seconds
        if (second == 60)
            second = 59;
        stripAndCheckLen(value[2 .. value.length], "A".length);
    }

    immutable(TimeZone) parseTZ(int sign)
    {
        if (value.length < 5)
            throw new DateTimeException("Invalid timezone");
        immutable zoneHours = _convDigits!short(value[1 .. 3]);
        immutable zoneMinutes = _convDigits!short(value[3 .. 5]);
        if (zoneHours == -1 || zoneMinutes == -1 || zoneMinutes > 59)
            throw new DateTimeException("Invalid timezone");
        value = value[5 .. value.length];
        immutable utcOffset = (dur!"hours"(zoneHours) + dur!"minutes"(zoneMinutes)) * sign;
        if (utcOffset == Duration.zero)
        {
            return sign == 1 ? cast(immutable(TimeZone))UTC()
                             : cast(immutable(TimeZone))new immutable SimpleTimeZone(Duration.zero);
        }
        return new immutable(SimpleTimeZone)(utcOffset);
    }

    // zone
    Rebindable!(immutable TimeZone) tz;
    if (value[0] == '-')
        tz = parseTZ(-1);
    else if (value[0] == '+')
        tz = parseTZ(1);
    else
    {
        // obs-zone
        immutable tzLen = value.length - find(value, ' ', '\t', '(')[0].length;
        switch (sliceAsString(value[0 .. tzLen <= 4 ? tzLen : 4]))
        {
            case "UT": case "GMT": tz = UTC(); break;
            case "EST": tz = new immutable SimpleTimeZone(dur!"hours"(-5)); break;
            case "EDT": tz = new immutable SimpleTimeZone(dur!"hours"(-4)); break;
            case "CST": tz = new immutable SimpleTimeZone(dur!"hours"(-6)); break;
            case "CDT": tz = new immutable SimpleTimeZone(dur!"hours"(-5)); break;
            case "MST": tz = new immutable SimpleTimeZone(dur!"hours"(-7)); break;
            case "MDT": tz = new immutable SimpleTimeZone(dur!"hours"(-6)); break;
            case "PST": tz = new immutable SimpleTimeZone(dur!"hours"(-8)); break;
            case "PDT": tz = new immutable SimpleTimeZone(dur!"hours"(-7)); break;
            case "J": case "j": throw new DateTimeException("Invalid timezone");
            default:
            {
                if (all!(std.ascii.isAlpha)(value[0 .. tzLen]))
                {
                    tz = new immutable SimpleTimeZone(Duration.zero);
                    break;
                }
                throw new DateTimeException("Invalid timezone");
            }
        }
        value = value[tzLen .. value.length];
    }

    // This is kind of arbitrary. Technically, nothing but CFWS is legal past
    // the end of the timezone, but we don't want to be picky about that in a
    // function that's just parsing rather than validating. So, the idea here is
    // that if the next character is printable (and not part of CFWS), then it
    // might be part of the timezone and thus affect what the timezone was
    // supposed to be, so we'll throw, but otherwise, we'll just ignore it.
    if (!value.empty && isPrintable(value[0]) && value[0] != ' ' && value[0] != '(')
        throw new DateTimeException("Invalid timezone");

    try
        return SysTime(DateTime(year, month, day, hour, minute, second), tz);
    catch (DateTimeException dte)
        throw new DateTimeException("date-time format is correct, but the resulting SysTime is invalid.", dte);
}

///
@safe unittest
{
    import std.exception : assertThrown;

    auto tz = new immutable SimpleTimeZone(hours(-8));
    assert(parseRFC822DateTime("Sat, 6 Jan 1990 12:14:19 -0800") ==
           SysTime(DateTime(1990, 1, 6, 12, 14, 19), tz));

    assert(parseRFC822DateTime("9 Jul 2002 13:11 +0000") ==
           SysTime(DateTime(2002, 7, 9, 13, 11, 0), UTC()));

    auto badStr = "29 Feb 2001 12:17:16 +0200";
    assertThrown!DateTimeException(parseRFC822DateTime(badStr));
}

version(unittest) void testParse822(alias cr)(string str, SysTime expected, size_t line = __LINE__)
{
    import std.format : format;
    auto value = cr(str);
    auto result = parseRFC822DateTime(value);
    if (result != expected)
        throw new AssertError(format("wrong result. expected [%s], actual[%s]", expected, result), __FILE__, line);
}

version(unittest) void testBadParse822(alias cr)(string str, size_t line = __LINE__)
{
    try
        parseRFC822DateTime(cr(str));
    catch (DateTimeException)
        return;
    throw new AssertError("No DateTimeException was thrown", __FILE__, line);
}

@system unittest
{
    import std.algorithm.iteration : filter, map;
    import std.algorithm.searching : canFind;
    import std.array : array;
    import std.ascii : letters;
    import std.format : format;
    import std.meta : AliasSeq;
    import std.range : chain, iota, take;
    import std.stdio : writefln, writeln;
    import std.string : representation;

    static struct Rand3Letters
    {
        enum empty = false;
        @property auto front() { return _mon; }
        void popFront()
        {
            import std.exception : assumeUnique;
            import std.random : rndGen;
            _mon = rndGen.map!(a => letters[a % letters.length])().take(3).array().assumeUnique();
        }
        string _mon;
        static auto start() { Rand3Letters retval; retval.popFront(); return retval; }
    }

    foreach (cr; AliasSeq!(function(string a){return cast(char[]) a;},
                          function(string a){return cast(ubyte[]) a;},
                          function(string a){return a;},
                          function(string a){return map!(b => cast(char) b)(a.representation);}))
    (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
        scope(failure) writeln(typeof(cr).stringof);
        alias test = testParse822!cr;
        alias testBad = testBadParse822!cr;

        immutable std1 = DateTime(2012, 12, 21, 13, 14, 15);
        immutable std2 = DateTime(2012, 12, 21, 13, 14, 0);
        immutable dst1 = DateTime(1976, 7, 4, 5, 4, 22);
        immutable dst2 = DateTime(1976, 7, 4, 5, 4, 0);

        test("21 Dec 2012 13:14:15 +0000", SysTime(std1, UTC()));
        test("21 Dec 2012 13:14 +0000", SysTime(std2, UTC()));
        test("Fri, 21 Dec 2012 13:14 +0000", SysTime(std2, UTC()));
        test("Fri, 21 Dec 2012 13:14:15 +0000", SysTime(std1, UTC()));

        test("04 Jul 1976 05:04:22 +0000", SysTime(dst1, UTC()));
        test("04 Jul 1976 05:04 +0000", SysTime(dst2, UTC()));
        test("Sun, 04 Jul 1976 05:04 +0000", SysTime(dst2, UTC()));
        test("Sun, 04 Jul 1976 05:04:22 +0000", SysTime(dst1, UTC()));

        test("4 Jul 1976 05:04:22 +0000", SysTime(dst1, UTC()));
        test("4 Jul 1976 05:04 +0000", SysTime(dst2, UTC()));
        test("Sun, 4 Jul 1976 05:04 +0000", SysTime(dst2, UTC()));
        test("Sun, 4 Jul 1976 05:04:22 +0000", SysTime(dst1, UTC()));

        auto badTZ = new immutable SimpleTimeZone(Duration.zero);
        test("21 Dec 2012 13:14:15 -0000", SysTime(std1, badTZ));
        test("21 Dec 2012 13:14 -0000", SysTime(std2, badTZ));
        test("Fri, 21 Dec 2012 13:14 -0000", SysTime(std2, badTZ));
        test("Fri, 21 Dec 2012 13:14:15 -0000", SysTime(std1, badTZ));

        test("04 Jul 1976 05:04:22 -0000", SysTime(dst1, badTZ));
        test("04 Jul 1976 05:04 -0000", SysTime(dst2, badTZ));
        test("Sun, 04 Jul 1976 05:04 -0000", SysTime(dst2, badTZ));
        test("Sun, 04 Jul 1976 05:04:22 -0000", SysTime(dst1, badTZ));

        test("4 Jul 1976 05:04:22 -0000", SysTime(dst1, badTZ));
        test("4 Jul 1976 05:04 -0000", SysTime(dst2, badTZ));
        test("Sun, 4 Jul 1976 05:04 -0000", SysTime(dst2, badTZ));
        test("Sun, 4 Jul 1976 05:04:22 -0000", SysTime(dst1, badTZ));

        auto pst = new immutable SimpleTimeZone(dur!"hours"(-8));
        auto pdt = new immutable SimpleTimeZone(dur!"hours"(-7));
        test("21 Dec 2012 13:14:15 -0800", SysTime(std1, pst));
        test("21 Dec 2012 13:14 -0800", SysTime(std2, pst));
        test("Fri, 21 Dec 2012 13:14 -0800", SysTime(std2, pst));
        test("Fri, 21 Dec 2012 13:14:15 -0800", SysTime(std1, pst));

        test("04 Jul 1976 05:04:22 -0700", SysTime(dst1, pdt));
        test("04 Jul 1976 05:04 -0700", SysTime(dst2, pdt));
        test("Sun, 04 Jul 1976 05:04 -0700", SysTime(dst2, pdt));
        test("Sun, 04 Jul 1976 05:04:22 -0700", SysTime(dst1, pdt));

        test("4 Jul 1976 05:04:22 -0700", SysTime(dst1, pdt));
        test("4 Jul 1976 05:04 -0700", SysTime(dst2, pdt));
        test("Sun, 4 Jul 1976 05:04 -0700", SysTime(dst2, pdt));
        test("Sun, 4 Jul 1976 05:04:22 -0700", SysTime(dst1, pdt));

        auto cet = new immutable SimpleTimeZone(dur!"hours"(1));
        auto cest = new immutable SimpleTimeZone(dur!"hours"(2));
        test("21 Dec 2012 13:14:15 +0100", SysTime(std1, cet));
        test("21 Dec 2012 13:14 +0100", SysTime(std2, cet));
        test("Fri, 21 Dec 2012 13:14 +0100", SysTime(std2, cet));
        test("Fri, 21 Dec 2012 13:14:15 +0100", SysTime(std1, cet));

        test("04 Jul 1976 05:04:22 +0200", SysTime(dst1, cest));
        test("04 Jul 1976 05:04 +0200", SysTime(dst2, cest));
        test("Sun, 04 Jul 1976 05:04 +0200", SysTime(dst2, cest));
        test("Sun, 04 Jul 1976 05:04:22 +0200", SysTime(dst1, cest));

        test("4 Jul 1976 05:04:22 +0200", SysTime(dst1, cest));
        test("4 Jul 1976 05:04 +0200", SysTime(dst2, cest));
        test("Sun, 4 Jul 1976 05:04 +0200", SysTime(dst2, cest));
        test("Sun, 4 Jul 1976 05:04:22 +0200", SysTime(dst1, cest));

        // dst and std times are switched in the Southern Hemisphere which is why the
        // time zone names and DateTime variables don't match.
        auto cstStd = new immutable SimpleTimeZone(dur!"hours"(9) + dur!"minutes"(30));
        auto cstDST = new immutable SimpleTimeZone(dur!"hours"(10) + dur!"minutes"(30));
        test("21 Dec 2012 13:14:15 +1030", SysTime(std1, cstDST));
        test("21 Dec 2012 13:14 +1030", SysTime(std2, cstDST));
        test("Fri, 21 Dec 2012 13:14 +1030", SysTime(std2, cstDST));
        test("Fri, 21 Dec 2012 13:14:15 +1030", SysTime(std1, cstDST));

        test("04 Jul 1976 05:04:22 +0930", SysTime(dst1, cstStd));
        test("04 Jul 1976 05:04 +0930", SysTime(dst2, cstStd));
        test("Sun, 04 Jul 1976 05:04 +0930", SysTime(dst2, cstStd));
        test("Sun, 04 Jul 1976 05:04:22 +0930", SysTime(dst1, cstStd));

        test("4 Jul 1976 05:04:22 +0930", SysTime(dst1, cstStd));
        test("4 Jul 1976 05:04 +0930", SysTime(dst2, cstStd));
        test("Sun, 4 Jul 1976 05:04 +0930", SysTime(dst2, cstStd));
        test("Sun, 4 Jul 1976 05:04:22 +0930", SysTime(dst1, cstStd));

        foreach (int i, mon; _monthNames)
        {
            test(format("17 %s 2012 00:05:02 +0000", mon), SysTime(DateTime(2012, i + 1, 17, 0, 5, 2), UTC()));
            test(format("17 %s 2012 00:05 +0000", mon), SysTime(DateTime(2012, i + 1, 17, 0, 5, 0), UTC()));
        }

        import std.uni : toLower, toUpper;
        foreach (mon; chain(_monthNames[].map!(a => toLower(a))(),
                           _monthNames[].map!(a => toUpper(a))(),
                           ["Jam", "Jen", "Fec", "Fdb", "Mas", "Mbr", "Aps", "Aqr", "Mai", "Miy",
                            "Jum", "Jbn", "Jup", "Jal", "Aur", "Apg", "Sem", "Sap", "Ocm", "Odt",
                            "Nom", "Nav", "Dem", "Dac"],
                           Rand3Letters.start().filter!(a => !_monthNames[].canFind(a)).take(20)))
        {
            scope(failure) writefln("Month: %s", mon);
            testBad(format("17 %s 2012 00:05:02 +0000", mon));
            testBad(format("17 %s 2012 00:05 +0000", mon));
        }

        immutable string[7] daysOfWeekNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

        {
            auto start = SysTime(DateTime(2012, 11, 11, 9, 42, 0), UTC());
            int day = 11;

            foreach (int i, dow; daysOfWeekNames)
            {
                auto curr = start + dur!"days"(i);
                test(format("%s, %s Nov 2012 09:42:00 +0000", dow, day), curr);
                test(format("%s, %s Nov 2012 09:42 +0000", dow, day++), curr);

                // Whether the day of the week matches the date is ignored.
                test(format("%s, 11 Nov 2012 09:42:00 +0000", dow), start);
                test(format("%s, 11 Nov 2012 09:42 +0000", dow), start);
            }
        }

        foreach (dow; chain(daysOfWeekNames[].map!(a => toLower(a))(),
                           daysOfWeekNames[].map!(a => toUpper(a))(),
                           ["Sum", "Spn", "Mom", "Man", "Tuf", "Tae", "Wem", "Wdd", "The", "Tur",
                            "Fro", "Fai", "San", "Sut"],
                           Rand3Letters.start().filter!(a => !daysOfWeekNames[].canFind(a)).take(20)))
        {
            scope(failure) writefln("Day of Week: %s", dow);
            testBad(format("%s, 11 Nov 2012 09:42:00 +0000", dow));
            testBad(format("%s, 11 Nov 2012 09:42 +0000", dow));
        }

        testBad("31 Dec 1899 23:59:59 +0000");
        test("01 Jan 1900 00:00:00 +0000", SysTime(Date(1900, 1, 1), UTC()));
        test("01 Jan 1900 00:00:00 -0000", SysTime(Date(1900, 1, 1),
                                                   new immutable SimpleTimeZone(Duration.zero)));
        test("01 Jan 1900 00:00:00 -0700", SysTime(Date(1900, 1, 1),
                                                   new immutable SimpleTimeZone(dur!"hours"(-7))));

        {
            auto st1 = SysTime(Date(1900, 1, 1), UTC());
            auto st2 = SysTime(Date(1900, 1, 1), new immutable SimpleTimeZone(dur!"hours"(-11)));
            foreach (i; 1900 .. 2102)
            {
                test(format("1 Jan %05d 00:00 +0000", i), st1);
                test(format("1 Jan %05d 00:00 -1100", i), st2);
                st1.add!"years"(1);
                st2.add!"years"(1);
            }
            st1.year = 9998;
            st2.year = 9998;
            foreach (i; 9998 .. 11_002)
            {
                test(format("1 Jan %05d 00:00 +0000", i), st1);
                test(format("1 Jan %05d 00:00 -1100", i), st2);
                st1.add!"years"(1);
                st2.add!"years"(1);
            }
        }

        testBad("12 Feb 1907 23:17:09 0000");
        testBad("12 Feb 1907 23:17:09 +000");
        testBad("12 Feb 1907 23:17:09 -000");
        testBad("12 Feb 1907 23:17:09 +00000");
        testBad("12 Feb 1907 23:17:09 -00000");
        testBad("12 Feb 1907 23:17:09 +A");
        testBad("12 Feb 1907 23:17:09 +PST");
        testBad("12 Feb 1907 23:17:09 -A");
        testBad("12 Feb 1907 23:17:09 -PST");

        // test trailing stuff that gets ignored
        {
            foreach (c; chain(iota(0, 33), ['('], iota(127, ubyte.max + 1)))
            {
                scope(failure) writefln("c: %d", c);
                test(format("21 Dec 2012 13:14:15 +0000%c", cast(char) c), SysTime(std1, UTC()));
                test(format("21 Dec 2012 13:14:15 +0000%c  ", cast(char) c), SysTime(std1, UTC()));
                test(format("21 Dec 2012 13:14:15 +0000%chello", cast(char) c), SysTime(std1, UTC()));
            }
        }

        // test trailing stuff that doesn't get ignored
        {
            foreach (c; chain(iota(33, '('), iota('(' + 1, 127)))
            {
                scope(failure) writefln("c: %d", c);
                testBad(format("21 Dec 2012 13:14:15 +0000%c", cast(char) c));
                testBad(format("21 Dec 2012 13:14:15 +0000%c   ", cast(char) c));
                testBad(format("21 Dec 2012 13:14:15 +0000%chello", cast(char) c));
            }
        }

        testBad("32 Jan 2012 12:13:14 -0800");
        testBad("31 Jan 2012 24:13:14 -0800");
        testBad("31 Jan 2012 12:60:14 -0800");
        testBad("31 Jan 2012 12:13:61 -0800");
        testBad("31 Jan 2012 12:13:14 -0860");
        test("31 Jan 2012 12:13:14 -0859",
             SysTime(DateTime(2012, 1, 31, 12, 13, 14),
                     new immutable SimpleTimeZone(dur!"hours"(-8) + dur!"minutes"(-59))));

        // leap-seconds
        test("21 Dec 2012 15:59:60 -0800", SysTime(DateTime(2012, 12, 21, 15, 59, 59), pst));

        // FWS
        test("Sun,4 Jul 1976 05:04 +0930", SysTime(dst2, cstStd));
        test("Sun,4 Jul 1976 05:04:22 +0930", SysTime(dst1, cstStd));
        test("Sun,4 Jul 1976 05:04 +0930 (foo)", SysTime(dst2, cstStd));
        test("Sun,4 Jul 1976 05:04:22 +0930 (foo)", SysTime(dst1, cstStd));
        test("Sun,4  \r\n  Jul  \r\n  1976  \r\n  05:04  \r\n  +0930  \r\n  (foo)", SysTime(dst2, cstStd));
        test("Sun,4  \r\n  Jul  \r\n  1976  \r\n  05:04:22  \r\n  +0930  \r\n  (foo)", SysTime(dst1, cstStd));

        auto str = "01 Jan 2012 12:13:14 -0800 ";
        test(str, SysTime(DateTime(2012, 1, 1, 12, 13, 14), new immutable SimpleTimeZone(hours(-8))));
        foreach (i; 0 .. str.length)
        {
            auto currStr = str.dup;
            currStr[i] = 'x';
            scope(failure) writefln("failed: %s", currStr);
            testBad(cast(string) currStr);
        }
        foreach (i; 2 .. str.length)
        {
            auto currStr = str[0 .. $ - i];
            scope(failure) writefln("failed: %s", currStr);
            testBad(cast(string) currStr);
            testBad((cast(string) currStr) ~ "                                    ");
        }
    }();
}

// Obsolete Format per section 4.3 of RFC 5322.
@system unittest
{
    import std.algorithm.iteration : filter, map;
    import std.ascii : letters;
    import std.exception : collectExceptionMsg;
    import std.format : format;
    import std.meta : AliasSeq;
    import std.range : chain, iota;
    import std.stdio : writefln, writeln;
    import std.string : representation;

    auto std1 = SysTime(DateTime(2012, 12, 21, 13, 14, 15), UTC());
    auto std2 = SysTime(DateTime(2012, 12, 21, 13, 14, 0), UTC());
    auto std3 = SysTime(DateTime(1912, 12, 21, 13, 14, 15), UTC());
    auto std4 = SysTime(DateTime(1912, 12, 21, 13, 14, 0), UTC());
    auto dst1 = SysTime(DateTime(1976, 7, 4, 5, 4, 22), UTC());
    auto dst2 = SysTime(DateTime(1976, 7, 4, 5, 4, 0), UTC());
    auto tooLate1 = SysTime(Date(10_000, 1, 1), UTC());
    auto tooLate2 = SysTime(DateTime(12_007, 12, 31, 12, 22, 19), UTC());

    foreach (cr; AliasSeq!(function(string a){return cast(char[]) a;},
                          function(string a){return cast(ubyte[]) a;},
                          function(string a){return a;},
                          function(string a){return map!(b => cast(char) b)(a.representation);}))
    (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
        scope(failure) writeln(typeof(cr).stringof);
        alias test = testParse822!cr;
        {
            auto list = ["", " ", " \r\n\t", "\t\r\n (hello world( frien(dog)) silly \r\n )  \t\t \r\n ()",
                         " \n ", "\t\n\t", " \n\t (foo) \n (bar) \r\n (baz) \n "];

            foreach (i, cfws; list)
            {
                scope(failure) writefln("i: %s", i);

                test(format("%1$s21%1$sDec%1$s2012%1$s13:14:15%1$s+0000%1$s", cfws), std1);
                test(format("%1$s21%1$sDec%1$s2012%1$s13:14%1$s+0000%1$s", cfws), std2);
                test(format("%1$sFri%1$s,%1$s21%1$sDec%1$s2012%1$s13:14%1$s+0000%1$s", cfws), std2);
                test(format("%1$sFri%1$s,%1$s21%1$sDec%1$s2012%1$s13:14:15%1$s+0000%1$s", cfws), std1);

                test(format("%1$s04%1$sJul%1$s1976%1$s05:04:22%1$s+0000%1$s", cfws), dst1);
                test(format("%1$s04%1$sJul%1$s1976%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s04%1$sJul%1$s1976%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s04%1$sJul%1$s1976%1$s05:04:22 +0000%1$s", cfws), dst1);

                test(format("%1$s4%1$sJul%1$s1976%1$s05:04:22%1$s+0000%1$s", cfws), dst1);
                test(format("%1$s4%1$sJul%1$s1976%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s4%1$sJul%1$s1976%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s4%1$sJul%1$s1976%1$s05:04:22%1$s+0000%1$s", cfws), dst1);

                test(format("%1$s21%1$sDec%1$s12%1$s13:14:15%1$s+0000%1$s", cfws), std1);
                test(format("%1$s21%1$sDec%1$s12%1$s13:14%1$s+0000%1$s", cfws), std2);
                test(format("%1$sFri%1$s,%1$s21%1$sDec%1$s12%1$s13:14%1$s+0000%1$s", cfws), std2);
                test(format("%1$sFri%1$s,%1$s21%1$sDec%1$s12%1$s13:14:15%1$s+0000%1$s", cfws), std1);

                test(format("%1$s04%1$sJul%1$s76%1$s05:04:22%1$s+0000%1$s", cfws), dst1);
                test(format("%1$s04%1$sJul%1$s76%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s04%1$sJul%1$s76%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s04%1$sJul%1$s76%1$s05:04:22%1$s+0000%1$s", cfws), dst1);

                test(format("%1$s4%1$sJul%1$s76 05:04:22%1$s+0000%1$s", cfws), dst1);
                test(format("%1$s4%1$sJul%1$s76 05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s4%1$sJul%1$s76%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s4%1$sJul%1$s76%1$s05:04:22%1$s+0000%1$s", cfws), dst1);

                test(format("%1$s21%1$sDec%1$s012%1$s13:14:15%1$s+0000%1$s", cfws), std3);
                test(format("%1$s21%1$sDec%1$s012%1$s13:14%1$s+0000%1$s", cfws), std4);
                test(format("%1$sFri%1$s,%1$s21%1$sDec%1$s012%1$s13:14%1$s+0000%1$s", cfws), std4);
                test(format("%1$sFri%1$s,%1$s21%1$sDec%1$s012%1$s13:14:15%1$s+0000%1$s", cfws), std3);

                test(format("%1$s04%1$sJul%1$s076%1$s05:04:22%1$s+0000%1$s", cfws), dst1);
                test(format("%1$s04%1$sJul%1$s076%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s04%1$sJul%1$s076%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s04%1$sJul%1$s076%1$s05:04:22%1$s+0000%1$s", cfws), dst1);

                test(format("%1$s4%1$sJul%1$s076%1$s05:04:22%1$s+0000%1$s", cfws), dst1);
                test(format("%1$s4%1$sJul%1$s076%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s4%1$sJul%1$s076%1$s05:04%1$s+0000%1$s", cfws), dst2);
                test(format("%1$sSun%1$s,%1$s4%1$sJul%1$s076%1$s05:04:22%1$s+0000%1$s", cfws), dst1);

                test(format("%1$s1%1$sJan%1$s10000%1$s00:00:00%1$s+0000%1$s", cfws), tooLate1);
                test(format("%1$s31%1$sDec%1$s12007%1$s12:22:19%1$s+0000%1$s", cfws), tooLate2);
                test(format("%1$sSat%1$s,%1$s1%1$sJan%1$s10000%1$s00:00:00%1$s+0000%1$s", cfws), tooLate1);
                test(format("%1$sSun%1$s,%1$s31%1$sDec%1$s12007%1$s12:22:19%1$s+0000%1$s", cfws), tooLate2);
            }
        }

        // test years of 1, 2, and 3 digits.
        {
            auto st1 = SysTime(Date(2000, 1, 1), UTC());
            auto st2 = SysTime(Date(2000, 1, 1), new immutable SimpleTimeZone(dur!"hours"(-12)));
            foreach (i; 0 .. 50)
            {
                test(format("1 Jan %02d 00:00 GMT", i), st1);
                test(format("1 Jan %02d 00:00 -1200", i), st2);
                st1.add!"years"(1);
                st2.add!"years"(1);
            }
        }

        {
            auto st1 = SysTime(Date(1950, 1, 1), UTC());
            auto st2 = SysTime(Date(1950, 1, 1), new immutable SimpleTimeZone(dur!"hours"(-12)));
            foreach (i; 50 .. 100)
            {
                test(format("1 Jan %02d 00:00 GMT", i), st1);
                test(format("1 Jan %02d 00:00 -1200", i), st2);
                st1.add!"years"(1);
                st2.add!"years"(1);
            }
        }

        {
            auto st1 = SysTime(Date(1900, 1, 1), UTC());
            auto st2 = SysTime(Date(1900, 1, 1), new immutable SimpleTimeZone(dur!"hours"(-11)));
            foreach (i; 0 .. 1000)
            {
                test(format("1 Jan %03d 00:00 GMT", i), st1);
                test(format("1 Jan %03d 00:00 -1100", i), st2);
                st1.add!"years"(1);
                st2.add!"years"(1);
            }
        }

        foreach (i; 0 .. 10)
        {
            auto str1 = cr(format("1 Jan %d 00:00 GMT", i));
            auto str2 = cr(format("1 Jan %d 00:00 -1200", i));
            assertThrown!DateTimeException(parseRFC822DateTime(str1));
            assertThrown!DateTimeException(parseRFC822DateTime(str1));
        }

        // test time zones
        {
            auto dt = DateTime(1982, 05, 03, 12, 22, 04);
            test("Wed, 03 May 1982 12:22:04 UT", SysTime(dt, UTC()));
            test("Wed, 03 May 1982 12:22:04 GMT", SysTime(dt, UTC()));
            test("Wed, 03 May 1982 12:22:04 EST", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-5))));
            test("Wed, 03 May 1982 12:22:04 EDT", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-4))));
            test("Wed, 03 May 1982 12:22:04 CST", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-6))));
            test("Wed, 03 May 1982 12:22:04 CDT", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-5))));
            test("Wed, 03 May 1982 12:22:04 MST", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-7))));
            test("Wed, 03 May 1982 12:22:04 MDT", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-6))));
            test("Wed, 03 May 1982 12:22:04 PST", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-8))));
            test("Wed, 03 May 1982 12:22:04 PDT", SysTime(dt, new immutable SimpleTimeZone(dur!"hours"(-7))));

            auto badTZ = new immutable SimpleTimeZone(Duration.zero);
            foreach (dchar c; filter!(a => a != 'j' && a != 'J')(letters))
            {
                scope(failure) writefln("c: %s", c);
                test(format("Wed, 03 May 1982 12:22:04 %s", c), SysTime(dt, badTZ));
                test(format("Wed, 03 May 1982 12:22:04%s", c), SysTime(dt, badTZ));
            }

            foreach (dchar c; ['j', 'J'])
            {
                scope(failure) writefln("c: %s", c);
                assertThrown!DateTimeException(parseRFC822DateTime(cr(format("Wed, 03 May 1982 12:22:04 %s", c))));
                assertThrown!DateTimeException(parseRFC822DateTime(cr(format("Wed, 03 May 1982 12:22:04%s", c))));
            }

            foreach (string s; ["AAA", "GQW", "DDT", "PDA", "GT", "GM"])
            {
                scope(failure) writefln("s: %s", s);
                test(format("Wed, 03 May 1982 12:22:04 %s", s), SysTime(dt, badTZ));
            }

            // test trailing stuff that gets ignored
            {
                foreach (c; chain(iota(0, 33), ['('], iota(127, ubyte.max + 1)))
                {
                    scope(failure) writefln("c: %d", c);
                    test(format("21Dec1213:14:15+0000%c", cast(char) c), std1);
                    test(format("21Dec1213:14:15+0000%c  ", cast(char) c), std1);
                    test(format("21Dec1213:14:15+0000%chello", cast(char) c), std1);
                }
            }

            // test trailing stuff that doesn't get ignored
            {
                foreach (c; chain(iota(33, '('), iota('(' + 1, 127)))
                {
                    scope(failure) writefln("c: %d", c);
                    assertThrown!DateTimeException(
                        parseRFC822DateTime(cr(format("21Dec1213:14:15+0000%c", cast(char) c))));
                    assertThrown!DateTimeException(
                        parseRFC822DateTime(cr(format("21Dec1213:14:15+0000%c  ", cast(char) c))));
                    assertThrown!DateTimeException(
                        parseRFC822DateTime(cr(format("21Dec1213:14:15+0000%chello", cast(char) c))));
                }
            }
        }

        // test that the checks for minimum length work correctly and avoid
        // any RangeErrors.
        test("7Dec1200:00A", SysTime(DateTime(2012, 12, 7, 00, 00, 00),
                                     new immutable SimpleTimeZone(Duration.zero)));
        test("Fri,7Dec1200:00A", SysTime(DateTime(2012, 12, 7, 00, 00, 00),
                                         new immutable SimpleTimeZone(Duration.zero)));
        test("7Dec1200:00:00A", SysTime(DateTime(2012, 12, 7, 00, 00, 00),
                                        new immutable SimpleTimeZone(Duration.zero)));
        test("Fri,7Dec1200:00:00A", SysTime(DateTime(2012, 12, 7, 00, 00, 00),
                                            new immutable SimpleTimeZone(Duration.zero)));

        auto tooShortMsg = collectExceptionMsg!DateTimeException(parseRFC822DateTime(""));
        foreach (str; ["Fri,7Dec1200:00:00", "7Dec1200:00:00"])
        {
            foreach (i; 0 .. str.length)
            {
                auto value = str[0 .. $ - i];
                scope(failure) writeln(value);
                assert(collectExceptionMsg!DateTimeException(parseRFC822DateTime(value)) == tooShortMsg);
            }
        }
    }();
}


/++
    Function for starting to a stop watch time when the function is called
    and stopping it when its return value goes out of scope and is destroyed.

    When the value that is returned by this function is destroyed,
    $(D func) will run. $(D func) is a unary function that takes a
    $(REF TickDuration, core,time).

    Example:
--------------------
{
    auto mt = measureTime!((TickDuration a)
        { /+ do something when the scope is exited +/ });
    // do something that needs to be timed
}
--------------------

    which is functionally equivalent to

--------------------
{
    auto sw = StopWatch(Yes.autoStart);
    scope(exit)
    {
        TickDuration a = sw.peek();
        /+ do something when the scope is exited +/
    }
    // do something that needs to be timed
}
--------------------

    See_Also:
        $(LREF benchmark)
+/
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

// Verify Example.
@safe unittest
{
    {
        auto mt = measureTime!((TickDuration a)
            { /+ do something when the scope is exited +/ });
        // do something that needs to be timed
    }

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

@safe unittest
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

@safe unittest
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
@system unittest
{
    @safe    void safeFunc() {}
    @trusted void trustFunc() {}
    @system  void sysFunc() {}
    auto safeResult  = measureTime!((a){safeFunc();})();
    auto trustResult = measureTime!((a){trustFunc();})();
    auto sysResult   = measureTime!((a){sysFunc();})();
}

//==============================================================================
// Private Section.
//==============================================================================
private:

//==============================================================================
// Section with private helper functions and templates.
//==============================================================================

/+
    Template to help with converting between time units.
 +/
template hnsecsPer(string units)
if (CmpTimeUnits!(units, "months") < 0)
{
    static if (units == "hnsecs")
        enum hnsecsPer = 1L;
    else static if (units == "usecs")
        enum hnsecsPer = 10L;
    else static if (units == "msecs")
        enum hnsecsPer = 1000 * hnsecsPer!"usecs";
    else static if (units == "seconds")
        enum hnsecsPer = 1000 * hnsecsPer!"msecs";
    else static if (units == "minutes")
        enum hnsecsPer = 60 * hnsecsPer!"seconds";
    else static if (units == "hours")
        enum hnsecsPer = 60 * hnsecsPer!"minutes";
    else static if (units == "days")
        enum hnsecsPer = 24 * hnsecsPer!"hours";
    else static if (units == "weeks")
        enum hnsecsPer = 7 * hnsecsPer!"days";
}


/+
    The time units which are one step smaller than the given units.
  +/
template nextSmallerTimeUnits(string units)
if (validTimeUnits(units) &&
    timeStrings.front != units)
{
    import std.algorithm.searching : countUntil;
    enum nextSmallerTimeUnits = timeStrings[countUntil(timeStrings, units) - 1];
}

@safe unittest
{
    assert(nextSmallerTimeUnits!"years" == "months");
    assert(nextSmallerTimeUnits!"months" == "weeks");
    assert(nextSmallerTimeUnits!"weeks" == "days");
    assert(nextSmallerTimeUnits!"days" == "hours");
    assert(nextSmallerTimeUnits!"hours" == "minutes");
    assert(nextSmallerTimeUnits!"minutes" == "seconds");
    assert(nextSmallerTimeUnits!"seconds" == "msecs");
    assert(nextSmallerTimeUnits!"msecs" == "usecs");
    assert(nextSmallerTimeUnits!"usecs" == "hnsecs");
    static assert(!__traits(compiles, nextSmallerTimeUnits!"hnsecs"));
}


/+
    The time units which are one step larger than the given units.
  +/
template nextLargerTimeUnits(string units)
if (validTimeUnits(units) &&
    timeStrings.back != units)
{
    import std.algorithm.searching : countUntil;
    enum nextLargerTimeUnits = timeStrings[countUntil(timeStrings, units) + 1];
}

@safe unittest
{
    assert(nextLargerTimeUnits!"hnsecs" == "usecs");
    assert(nextLargerTimeUnits!"usecs" == "msecs");
    assert(nextLargerTimeUnits!"msecs" == "seconds");
    assert(nextLargerTimeUnits!"seconds" == "minutes");
    assert(nextLargerTimeUnits!"minutes" == "hours");
    assert(nextLargerTimeUnits!"hours" == "days");
    assert(nextLargerTimeUnits!"days" == "weeks");
    assert(nextLargerTimeUnits!"weeks" == "months");
    assert(nextLargerTimeUnits!"months" == "years");
    static assert(!__traits(compiles, nextLargerTimeUnits!"years"));
}


/+
    Strips what RFC 5322, section 3.2.2 refers to as CFWS from the left-hand
    side of the given range (it strips comments delimited by $(D '(') and
    $(D ')') as well as folding whitespace).

    It is assumed that the given range contains the value of a header field and
    no terminating CRLF for the line (though the CRLF for folding whitespace is
    of course expected and stripped) and thus that the only case of CR or LF is
    in folding whitespace.

    If a comment does not terminate correctly (e.g. mismatched parens) or if the
    the FWS is malformed, then the range will be empty when stripCWFS is done.
    However, only minimal validation of the content is done (e.g. quoted pairs
    within a comment aren't validated beyond \$LPAREN or \$RPAREN, because
    they're inside a comment, and thus their value doesn't matter anyway). It's
    only when the content does not conform to the grammar rules for FWS and thus
    literally cannot be parsed that content is considered invalid, and an empty
    range is returned.

    Note that _stripCFWS is eager, not lazy. It does not create a new range.
    Rather, it pops off the CFWS from the range and returns it.
  +/
R _stripCFWS(R)(R range)
if (isRandomAccessRange!R && hasSlicing!R && hasLength!R &&
    (is(Unqual!(ElementType!R) == char) || is(Unqual!(ElementType!R) == ubyte)))
{
    immutable e = range.length;
    outer: for (size_t i = 0; i < e; )
    {
        switch (range[i])
        {
            case ' ': case '\t':
            {
                ++i;
                break;
            }
            case '\r':
            {
                if (i + 2 < e && range[i + 1] == '\n' && (range[i + 2] == ' ' || range[i + 2] == '\t'))
                {
                    i += 3;
                    break;
                }
                break outer;
            }
            case '\n':
            {
                if (i + 1 < e && (range[i + 1] == ' ' || range[i + 1] == '\t'))
                {
                    i += 2;
                    break;
                }
                break outer;
            }
            case '(':
            {
                ++i;
                size_t commentLevel = 1;
                while (i < e)
                {
                    if (range[i] == '(')
                        ++commentLevel;
                    else if (range[i] == ')')
                    {
                        ++i;
                        if (--commentLevel == 0)
                            continue outer;
                        continue;
                    }
                    else if (range[i] == '\\')
                    {
                        if (++i == e)
                            break outer;
                    }
                    ++i;
                }
                break outer;
            }
            default: return range[i .. e];
        }
    }
    return range[e .. e];
}

@system unittest
{
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : map;
    import std.meta : AliasSeq;
    import std.stdio : writeln;
    import std.string : representation;

    foreach (cr; AliasSeq!(function(string a){return cast(ubyte[]) a;},
                          function(string a){return map!(b => cast(char) b)(a.representation);}))
    (){ // avoid slow optimizations for large functions @@@BUG@@@ 2396
        scope(failure) writeln(typeof(cr).stringof);

        assert(_stripCFWS(cr("")).empty);
        assert(_stripCFWS(cr("\r")).empty);
        assert(_stripCFWS(cr("\r\n")).empty);
        assert(_stripCFWS(cr("\r\n ")).empty);
        assert(_stripCFWS(cr(" \t\r\n")).empty);
        assert(equal(_stripCFWS(cr(" \t\r\n hello")), cr("hello")));
        assert(_stripCFWS(cr(" \t\r\nhello")).empty);
        assert(_stripCFWS(cr(" \t\r\n\v")).empty);
        assert(equal(_stripCFWS(cr("\v \t\r\n\v")), cr("\v \t\r\n\v")));
        assert(_stripCFWS(cr("()")).empty);
        assert(_stripCFWS(cr("(hello world)")).empty);
        assert(_stripCFWS(cr("(hello world)(hello world)")).empty);
        assert(_stripCFWS(cr("(hello world\r\n foo\r where's\nwaldo)")).empty);
        assert(_stripCFWS(cr(" \t (hello \tworld\r\n foo\r where's\nwaldo)\t\t ")).empty);
        assert(_stripCFWS(cr("      ")).empty);
        assert(_stripCFWS(cr("\t\t\t")).empty);
        assert(_stripCFWS(cr("\t \r\n\r \n")).empty);
        assert(_stripCFWS(cr("(hello world) (can't find waldo) (he's lost)")).empty);
        assert(_stripCFWS(cr("(hello\\) world) (can't \\(find waldo) (he's \\(\\)lost)")).empty);
        assert(_stripCFWS(cr("(((((")).empty);
        assert(_stripCFWS(cr("(((()))")).empty);
        assert(_stripCFWS(cr("(((())))")).empty);
        assert(equal(_stripCFWS(cr("(((()))))")), cr(")")));
        assert(equal(_stripCFWS(cr(")))))")), cr(")))))")));
        assert(equal(_stripCFWS(cr("()))))")), cr("))))")));
        assert(equal(_stripCFWS(cr(" hello hello ")), cr("hello hello ")));
        assert(equal(_stripCFWS(cr("\thello (world)")), cr("hello (world)")));
        assert(equal(_stripCFWS(cr(" \r\n \\((\\))  foo")), cr("\\((\\))  foo")));
        assert(equal(_stripCFWS(cr(" \r\n (\\((\\)))  foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" \r\n (\\(()))  foo")), cr(")  foo")));
        assert(_stripCFWS(cr(" \r\n (((\\)))  foo")).empty);

        assert(_stripCFWS(cr("(hello)(hello)")).empty);
        assert(_stripCFWS(cr(" \r\n (hello)\r\n (hello)")).empty);
        assert(_stripCFWS(cr(" \r\n (hello) \r\n (hello) \r\n ")).empty);
        assert(_stripCFWS(cr("\t\t\t\t(hello)\t\t\t\t(hello)\t\t\t\t")).empty);
        assert(equal(_stripCFWS(cr(" \r\n (hello)\r\n (hello) \r\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \r\n (hello) \r\n (hello) \r\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr("\t\r\n\t(hello)\r\n\t(hello)\t\r\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr("\t\r\n\t(hello)\t\r\n\t(hello)\t\r\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \r\n (hello) \r\n \r\n (hello) \r\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \r\n (hello) \r\n (hello) \r\n \r\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \r\n \r\n (hello)\t\r\n (hello) \r\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \r\n\t\r\n\t(hello)\t\r\n (hello) \r\n hello")), cr("hello")));

        assert(equal(_stripCFWS(cr(" (\r\n ( \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\t\r\n ( \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\r\n\t( \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n (\t\r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n (\r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n (\r\n\t) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n )\t\r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n )\r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n ) \r\n) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n ) \r\n\t) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n ) \r\n ) \r\n foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n ) \r\n )\t\r\n foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n ( \r\n ) \r\n )\r\n foo")), cr("foo")));

        assert(equal(_stripCFWS(cr(" ( \r\n \r\n ( \r\n \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n \r\n ( \r\n \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\t\r\n \r\n ( \r\n \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\r\n \r\n\t( \r\n \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\r\n \r\n( \r\n \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\r\n \r\n ( \r\n \r\n\t) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\r\n \r\n ( \r\n \r\n )\t\r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" (\r\n \r\n ( \r\n \r\n )\r\n ) foo")), cr("foo")));

        assert(equal(_stripCFWS(cr(" ( \r\n bar \r\n ( \r\n bar \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n () \r\n ( \r\n () \r\n ) \r\n ) foo")), cr("foo")));
        assert(equal(_stripCFWS(cr(" ( \r\n \\\\ \r\n ( \r\n \\\\ \r\n ) \r\n ) foo")), cr("foo")));

        assert(_stripCFWS(cr("(hello)(hello)")).empty);
        assert(_stripCFWS(cr(" \n (hello)\n (hello) \n ")).empty);
        assert(_stripCFWS(cr(" \n (hello) \n (hello) \n ")).empty);
        assert(equal(_stripCFWS(cr(" \n (hello)\n (hello) \n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \n (hello) \n (hello) \n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr("\t\n\t(hello)\n\t(hello)\t\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr("\t\n\t(hello)\t\n\t(hello)\t\n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \n (hello) \n \n (hello) \n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \n (hello) \n (hello) \n \n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \n \n (hello)\t\n (hello) \n hello")), cr("hello")));
        assert(equal(_stripCFWS(cr(" \n\t\n\t(hello)\t\n (hello) \n hello")), cr("hello")));
    }();
}

// This is so that we don't have to worry about std.conv.to throwing. It also
// doesn't have to worry about quite as many cases as std.conv.to, since it
// doesn't have to worry about a sign on the value or about whether it fits.
T _convDigits(T, R)(R str)
if (isIntegral!T && isSigned!T) // The constraints on R were already covered by parseRFC822DateTime.
{
    import std.ascii : isDigit;

    assert(!str.empty);
    T num = 0;
    foreach (i; 0 .. str.length)
    {
        if (i != 0)
            num *= 10;
        if (!isDigit(str[i]))
            return -1;
        num += str[i] - '0';
    }
    return num;
}

@safe unittest
{
    import std.conv : to;
    import std.range : chain, iota;
    import std.stdio : writeln;
    foreach (i; chain(iota(0, 101), [250, 999, 1000, 1001, 2345, 9999]))
    {
        scope(failure) writeln(i);
        assert(_convDigits!int(to!string(i)) == i);
    }
    foreach (str; ["-42", "+42", "1a", "1 ", " ", " 42 "])
    {
        scope(failure) writeln(str);
        assert(_convDigits!int(str) == -1);
    }
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
