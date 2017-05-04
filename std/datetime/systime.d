// Written in the D programming language

/++
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis
    Source:    $(PHOBOSSRC std/_datetime.d)
    Macros:
        LREF2=<a href="#$1">$(D $2)</a>
+/
module std.datetime.systime;

import core.time;
import std.datetime.common;
import std.datetime.date;
import std.datetime.datetime;
import std.datetime.timeofday;
import std.datetime.timezone;
import std.format : format;
import std.exception : enforce;
import std.traits : isSomeString, Unqual;

version(Windows)
{
    import core.stdc.time : time_t;
    import core.sys.windows.windows;
    import core.sys.windows.winsock2;
}
else version(Posix)
{
    import core.sys.posix.signal : timespec;
    import core.sys.posix.sys.types : time_t;
}

version(unittest)
{
    import core.exception : AssertError;
    import std.exception : assertThrown;
}


@safe unittest
{
    initializeTests();
}


/++
    $(D SysTime) is the type used to get the current time from the
    system or doing anything that involves time zones. Unlike
    $(LREF DateTime), the time zone is an integral part of $(D SysTime) (though for
    local time applications, time zones can be ignored and
    it will work, since it defaults to using the local time zone). It holds its
    internal time in std time (hnsecs since midnight, January 1st, 1 A.D. UTC),
    so it interfaces well with the system time. However, that means that, unlike
    $(LREF DateTime), it is not optimized for calendar-based operations, and
    getting individual units from it such as years or days is going to involve
    conversions and be less efficient.

    For calendar-based operations that don't
    care about time zones, then $(LREF DateTime) would be the type to
    use. For system time, use $(D SysTime).

    $(LREF2 .Clock.currTime, Clock.currTime) will return the current time as a $(D SysTime).
    To convert a $(D SysTime) to a $(LREF Date) or $(LREF DateTime), simply cast
    it. To convert a $(LREF Date) or $(LREF DateTime) to a
    $(D SysTime), use $(D SysTime)'s constructor, and pass in the
    intended time zone with it (or don't pass in a $(LREF2 .TimeZone, TimeZone), and the local
    time zone will be used). Be aware, however, that converting from a
    $(LREF DateTime) to a $(D SysTime) will not necessarily be 100% accurate due to
    DST (one hour of the year doesn't exist and another occurs twice).
    To not risk any conversion errors, keep times as
    $(D SysTime)s. Aside from DST though, there shouldn't be any conversion
    problems.

    For using time zones other than local time or UTC, use
    $(LREF PosixTimeZone) on Posix systems (or on Windows, if providing the TZ
    Database files), and use $(LREF WindowsTimeZone) on Windows systems.
    The time in $(D SysTime) is kept internally in hnsecs from midnight,
    January 1st, 1 A.D. UTC. Conversion error cannot happen when changing
    the time zone of a $(D SysTime). $(LREF LocalTime) is the $(LREF2 .TimeZone, TimeZone) class
    which represents the local time, and $(D UTC) is the $(LREF2 .TimeZone, TimeZone) class
    which represents UTC. $(D SysTime) uses $(LREF LocalTime) if no $(LREF2 .TimeZone, TimeZone)
    is provided. For more details on time zones, see the documentation for
    $(LREF2 .TimeZone, TimeZone), $(LREF PosixTimeZone), and $(LREF WindowsTimeZone).

    $(D SysTime)'s range is from approximately 29,000 B.C. to approximately
    29,000 A.D.
  +/
struct SysTime
{
    import core.stdc.time : tm;
    version(Posix) import core.sys.posix.sys.time : timeval;
    import std.typecons : Rebindable;

public:

    /++
        Params:
            dateTime = The $(LREF DateTime) to use to set this $(LREF SysTime)'s
                       internal std time. As $(LREF DateTime) has no concept of
                       time zone, tz is used as its time zone.
            tz       = The $(LREF2 .TimeZone, TimeZone) to use for this $(LREF SysTime). If null,
                       $(LREF LocalTime) will be used. The given $(LREF DateTime) is
                       assumed to be in the given time zone.
      +/
    this(in DateTime dateTime, immutable TimeZone tz = null) @safe nothrow
    {
        try
            this(dateTime, Duration.zero, tz);
        catch (Exception e)
            assert(0, "SysTime's constructor threw when it shouldn't have.");
    }

    @safe unittest
    {
        static void test(DateTime dt, immutable TimeZone tz, long expected)
        {
            auto sysTime = SysTime(dt, tz);
            assert(sysTime._stdTime == expected);
            assert(sysTime._timezone is (tz is null ? LocalTime() : tz), format("Given DateTime: %s", dt));
        }

        test(DateTime.init, UTC(), 0);
        test(DateTime(1, 1, 1, 12, 30, 33), UTC(), 450_330_000_000L);
        test(DateTime(0, 12, 31, 12, 30, 33), UTC(), -413_670_000_000L);
        test(DateTime(1, 1, 1, 0, 0, 0), UTC(), 0);
        test(DateTime(1, 1, 1, 0, 0, 1), UTC(), 10_000_000L);
        test(DateTime(0, 12, 31, 23, 59, 59), UTC(), -10_000_000L);

        test(DateTime(1, 1, 1, 0, 0, 0), new immutable SimpleTimeZone(dur!"minutes"(-60)), 36_000_000_000L);
        test(DateTime(1, 1, 1, 0, 0, 0), new immutable SimpleTimeZone(Duration.zero), 0);
        test(DateTime(1, 1, 1, 0, 0, 0), new immutable SimpleTimeZone(dur!"minutes"(60)), -36_000_000_000L);
    }

    /++
        Params:
            dateTime = The $(LREF DateTime) to use to set this $(LREF SysTime)'s
                       internal std time. As $(LREF DateTime) has no concept of
                       time zone, tz is used as its time zone.
            fracSecs = The fractional seconds portion of the time.
            tz       = The $(LREF2 .TimeZone, TimeZone) to use for this $(LREF SysTime). If null,
                       $(LREF LocalTime) will be used. The given $(LREF DateTime) is
                       assumed to be in the given time zone.

        Throws:
            $(LREF DateTimeException) if $(D fracSecs) is negative or if it's
            greater than or equal to one second.
      +/
    this(in DateTime dateTime, in Duration fracSecs, immutable TimeZone tz = null) @safe
    {
        enforce(fracSecs >= Duration.zero, new DateTimeException("A SysTime cannot have negative fractional seconds."));
        enforce(fracSecs < seconds(1), new DateTimeException("Fractional seconds must be less than one second."));
        auto nonNullTZ = tz is null ? LocalTime() : tz;

        immutable dateDiff = dateTime.date - Date.init;
        immutable todDiff = dateTime.timeOfDay - TimeOfDay.init;

        immutable adjustedTime = dateDiff + todDiff + fracSecs;
        immutable standardTime = nonNullTZ.tzToUTC(adjustedTime.total!"hnsecs");

        this(standardTime, nonNullTZ);
    }

    @safe unittest
    {
        static void test(DateTime dt, Duration fracSecs, immutable TimeZone tz, long expected)
        {
            auto sysTime = SysTime(dt, fracSecs, tz);
            assert(sysTime._stdTime == expected);
            assert(sysTime._timezone is (tz is null ? LocalTime() : tz),
                   format("Given DateTime: %s, Given Duration: %s", dt, fracSecs));
        }

        test(DateTime.init, Duration.zero, UTC(), 0);
        test(DateTime(1, 1, 1, 12, 30, 33), Duration.zero, UTC(), 450_330_000_000L);
        test(DateTime(0, 12, 31, 12, 30, 33), Duration.zero, UTC(), -413_670_000_000L);
        test(DateTime(1, 1, 1, 0, 0, 0), msecs(1), UTC(), 10_000L);
        test(DateTime(0, 12, 31, 23, 59, 59), msecs(999), UTC(), -10_000L);

        test(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC(), -1);
        test(DateTime(0, 12, 31, 23, 59, 59), hnsecs(1), UTC(), -9_999_999);
        test(DateTime(0, 12, 31, 23, 59, 59), Duration.zero, UTC(), -10_000_000);

        assertThrown!DateTimeException(SysTime(DateTime.init, hnsecs(-1), UTC()));
        assertThrown!DateTimeException(SysTime(DateTime.init, seconds(1), UTC()));
    }

    // Explicitly undocumented. It will be removed in August 2017. @@@DEPRECATED_2017-08@@@
    deprecated("Please use the overload which takes a Duration instead of a FracSec.")
    this(in DateTime dateTime, in FracSec fracSec, immutable TimeZone tz = null) @safe
    {
        immutable fracHNSecs = fracSec.hnsecs;
        enforce(fracHNSecs >= 0, new DateTimeException("A SysTime cannot have negative fractional seconds."));
        _timezone = tz is null ? LocalTime() : tz;

        try
        {
            immutable dateDiff = (dateTime.date - Date(1, 1, 1)).total!"hnsecs";
            immutable todDiff = (dateTime.timeOfDay - TimeOfDay(0, 0, 0)).total!"hnsecs";

            immutable adjustedTime = dateDiff + todDiff + fracHNSecs;
            immutable standardTime = _timezone.tzToUTC(adjustedTime);

            this(standardTime, _timezone);
        }
        catch (Exception e)
            assert(0, "Date, TimeOfDay, or DateTime's constructor threw when it shouldn't have.");
    }

    deprecated @safe unittest
    {
        static void test(DateTime dt, FracSec fracSec, immutable TimeZone tz, long expected)
        {
            auto sysTime = SysTime(dt, fracSec, tz);
            assert(sysTime._stdTime == expected);
            assert(sysTime._timezone is (tz is null ? LocalTime() : tz),
                   format("Given DateTime: %s, Given FracSec: %s", dt, fracSec));
        }

        test(DateTime.init, FracSec.init, UTC(), 0);
        test(DateTime(1, 1, 1, 12, 30, 33), FracSec.init, UTC(), 450_330_000_000L);
        test(DateTime(0, 12, 31, 12, 30, 33), FracSec.init, UTC(), -413_670_000_000L);
        test(DateTime(1, 1, 1, 0, 0, 0), FracSec.from!"msecs"(1), UTC(), 10_000L);
        test(DateTime(0, 12, 31, 23, 59, 59), FracSec.from!"msecs"(999), UTC(), -10_000L);

        test(DateTime(0, 12, 31, 23, 59, 59), FracSec.from!"hnsecs"(9_999_999), UTC(), -1);
        test(DateTime(0, 12, 31, 23, 59, 59), FracSec.from!"hnsecs"(1), UTC(), -9_999_999);
        test(DateTime(0, 12, 31, 23, 59, 59), FracSec.from!"hnsecs"(0), UTC(), -10_000_000);

        assertThrown!DateTimeException(SysTime(DateTime.init, FracSec.from!"hnsecs"(-1), UTC()));
    }

    /++
        Params:
            date = The $(LREF Date) to use to set this $(LREF SysTime)'s internal std
                   time. As $(LREF Date) has no concept of time zone, tz is used as
                   its time zone.
            tz   = The $(LREF2 .TimeZone, TimeZone) to use for this $(LREF SysTime). If null,
                   $(LREF LocalTime) will be used. The given $(LREF Date) is assumed
                   to be in the given time zone.
      +/
    this(in Date date, immutable TimeZone tz = null) @safe nothrow
    {
        _timezone = tz is null ? LocalTime() : tz;

        try
        {
            immutable adjustedTime = (date - Date(1, 1, 1)).total!"hnsecs";
            immutable standardTime = _timezone.tzToUTC(adjustedTime);

            this(standardTime, _timezone);
        }
        catch (Exception e)
            assert(0, "Date's constructor through when it shouldn't have.");
    }

    @safe unittest
    {
        static void test(Date d, immutable TimeZone tz, long expected)
        {
            auto sysTime = SysTime(d, tz);
            assert(sysTime._stdTime == expected);
            assert(sysTime._timezone is (tz is null ? LocalTime() : tz), format("Given Date: %s", d));
        }

        test(Date.init, UTC(), 0);
        test(Date(1, 1, 1), UTC(), 0);
        test(Date(1, 1, 2), UTC(), 864000000000);
        test(Date(0, 12, 31), UTC(), -864000000000);
    }

    /++
        Note:
            Whereas the other constructors take in the given date/time, assume
            that it's in the given time zone, and convert it to hnsecs in UTC
            since midnight, January 1st, 1 A.D. UTC - i.e. std time - this
            constructor takes a std time, which is specifically already in UTC,
            so no conversion takes place. Of course, the various getter
            properties and functions will use the given time zone's conversion
            function to convert the results to that time zone, but no conversion
            of the arguments to this constructor takes place.

        Params:
            stdTime = The number of hnsecs since midnight, January 1st, 1 A.D. UTC.
            tz      = The $(LREF2 .TimeZone, TimeZone) to use for this $(LREF SysTime). If null,
                      $(LREF LocalTime) will be used.
      +/
    this(long stdTime, immutable TimeZone tz = null) @safe pure nothrow
    {
        _stdTime = stdTime;
        _timezone = tz is null ? LocalTime() : tz;
    }

    @safe unittest
    {
        static void test(long stdTime, immutable TimeZone tz)
        {
            auto sysTime = SysTime(stdTime, tz);
            assert(sysTime._stdTime == stdTime);
            assert(sysTime._timezone is (tz is null ? LocalTime() : tz), format("Given stdTime: %s", stdTime));
        }

        foreach (stdTime; [-1234567890L, -250, 0, 250, 1235657390L])
        {
            foreach (tz; testTZs)
                test(stdTime, tz);
        }
    }

    /++
        Params:
            rhs = The $(LREF SysTime) to assign to this one.
      +/
    ref SysTime opAssign(const ref SysTime rhs) return @safe pure nothrow
    {
        _stdTime = rhs._stdTime;
        _timezone = rhs._timezone;
        return this;
    }

    /++
        Params:
            rhs = The $(LREF SysTime) to assign to this one.
      +/
    ref SysTime opAssign(SysTime rhs) scope return @safe pure nothrow
    {
        _stdTime = rhs._stdTime;
        _timezone = rhs._timezone;
        return this;
    }

    /++
        Checks for equality between this $(LREF SysTime) and the given
        $(LREF SysTime).

        Note that the time zone is ignored. Only the internal
        std times (which are in UTC) are compared.
     +/
    bool opEquals(const SysTime rhs) @safe const pure nothrow
    {
        return opEquals(rhs);
    }

    /// ditto
    bool opEquals(const ref SysTime rhs) @safe const pure nothrow
    {
        return _stdTime == rhs._stdTime;
    }

    @safe unittest
    {
        import std.range : chain;

        assert(SysTime(DateTime.init, UTC()) == SysTime(0, UTC()));
        assert(SysTime(DateTime.init, UTC()) == SysTime(0));
        assert(SysTime(Date.init, UTC()) == SysTime(0));
        assert(SysTime(0) == SysTime(0));

        static void test(DateTime dt, immutable TimeZone tz1, immutable TimeZone tz2)
        {
            auto st1 = SysTime(dt);
            st1.timezone = tz1;

            auto st2 = SysTime(dt);
            st2.timezone = tz2;

            assert(st1 == st2);
        }

        foreach (tz1; testTZs)
        {
            foreach (tz2; testTZs)
            {
                foreach (dt; chain(testDateTimesBC, testDateTimesAD))
                    test(dt, tz1, tz2);
            }
        }

        auto st = SysTime(DateTime(1999, 7, 6, 12, 33, 30));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 33, 30));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 33, 30));
        assert(st == st);
        assert(st == cst);
        //assert(st == ist);
        assert(cst == st);
        assert(cst == cst);
        //assert(cst == ist);
        //assert(ist == st);
        //assert(ist == cst);
        //assert(ist == ist);
    }

    /++
        Compares this $(LREF SysTime) with the given $(LREF SysTime).

        Time zone is irrelevant when comparing $(LREF SysTime)s.

        Returns:
            $(BOOKTABLE,
            $(TR $(TD this &lt; rhs) $(TD &lt; 0))
            $(TR $(TD this == rhs) $(TD 0))
            $(TR $(TD this &gt; rhs) $(TD &gt; 0))
            )
     +/
    int opCmp(in SysTime rhs) @safe const pure nothrow
    {
        if (_stdTime < rhs._stdTime)
            return -1;
        if (_stdTime > rhs._stdTime)
            return 1;
        return 0;
    }

    @safe unittest
    {
        import std.algorithm.iteration : map;
        import std.array : array;
        import std.range : chain;

        assert(SysTime(DateTime.init, UTC()).opCmp(SysTime(0, UTC())) == 0);
        assert(SysTime(DateTime.init, UTC()).opCmp(SysTime(0)) == 0);
        assert(SysTime(Date.init, UTC()).opCmp(SysTime(0)) == 0);
        assert(SysTime(0).opCmp(SysTime(0)) == 0);

        static void testEqual(SysTime st, immutable TimeZone tz1, immutable TimeZone tz2)
        {
            auto st1 = st;
            st1.timezone = tz1;

            auto st2 = st;
            st2.timezone = tz2;

            assert(st1.opCmp(st2) == 0);
        }

        auto sts = array(map!SysTime(chain(testDateTimesBC, testDateTimesAD)));

        foreach (st; sts)
        {
            foreach (tz1; testTZs)
            {
                foreach (tz2; testTZs)
                    testEqual(st, tz1, tz2);
            }
        }

        static void testCmp(SysTime st1, immutable TimeZone tz1, SysTime st2, immutable TimeZone tz2)
        {
            st1.timezone = tz1;
            st2.timezone = tz2;
            assert(st1.opCmp(st2) < 0);
            assert(st2.opCmp(st1) > 0);
        }

        foreach (si, st1; sts)
        {
            foreach (st2; sts[si + 1 .. $])
            {
                foreach (tz1; testTZs)
                {
                    foreach (tz2; testTZs)
                        testCmp(st1, tz1, st2, tz2);
                }
            }
        }

        auto st = SysTime(DateTime(1999, 7, 6, 12, 33, 30));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 33, 30));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 33, 30));
        assert(st.opCmp(st) == 0);
        assert(st.opCmp(cst) == 0);
        //assert(st.opCmp(ist) == 0);
        assert(cst.opCmp(st) == 0);
        assert(cst.opCmp(cst) == 0);
        //assert(cst.opCmp(ist) == 0);
        //assert(ist.opCmp(st) == 0);
        //assert(ist.opCmp(cst) == 0);
        //assert(ist.opCmp(ist) == 0);
    }

    /**
     * Returns: A hash of the $(LREF SysTime)
     */
    size_t toHash() const @nogc pure nothrow @safe
    {
        static if (is(size_t == ulong))
            return _stdTime;
        else
        {
            // MurmurHash2
            enum ulong m = 0xc6a4a7935bd1e995UL;
            enum ulong n = m * 16;
            enum uint r = 47;

            ulong k = _stdTime;
            k *= m;
            k ^= k >> r;
            k *= m;

            ulong h = n;
            h ^= k;
            h *= m;

            return cast(size_t) h;
        }
    }

    @safe unittest
    {
        assert(SysTime(0).toHash == SysTime(0).toHash);
        assert(SysTime(DateTime(2000, 1, 1)).toHash == SysTime(DateTime(2000, 1, 1)).toHash);
        assert(SysTime(DateTime(2000, 1, 1)).toHash != SysTime(DateTime(2000, 1, 2)).toHash);

        // test that timezones aren't taken into account
        assert(SysTime(0, LocalTime()).toHash == SysTime(0, LocalTime()).toHash);
        assert(SysTime(0, LocalTime()).toHash == SysTime(0, UTC()).toHash);
        assert(SysTime(DateTime(2000, 1, 1), LocalTime()).toHash == SysTime(DateTime(2000, 1, 1), LocalTime()).toHash);
        immutable zone = new SimpleTimeZone(dur!"minutes"(60));
        assert(SysTime(DateTime(2000, 1, 1, 1), zone).toHash == SysTime(DateTime(2000, 1, 1), UTC()).toHash);
        assert(SysTime(DateTime(2000, 1, 1), zone).toHash != SysTime(DateTime(2000, 1, 1), UTC()).toHash);
    }

    /++
        Year of the Gregorian Calendar. Positive numbers are A.D. Non-positive
        are B.C.
     +/
    @property short year() @safe const nothrow
    {
        return (cast(Date) this).year;
    }

    @safe unittest
    {
        import std.range : chain;
        static void test(SysTime sysTime, long expected)
        {
            assert(sysTime.year == expected, format("Value given: %s", sysTime));
        }

        test(SysTime(0, UTC()), 1);
        test(SysTime(1, UTC()), 1);
        test(SysTime(-1, UTC()), 0);

        foreach (year; chain(testYearsBC, testYearsAD))
        {
            foreach (md; testMonthDays)
            {
                foreach (tod; testTODs)
                {
                    auto dt = DateTime(Date(year, md.month, md.day), tod);
                    foreach (tz; testTZs)
                    {
                        foreach (fs; testFracSecs)
                            test(SysTime(dt, fs, tz), year);
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.year == 1999);
        //assert(ist.year == 1999);
    }

    /++
        Year of the Gregorian Calendar. Positive numbers are A.D. Non-positive
        are B.C.

        Params:
            year = The year to set this $(LREF SysTime)'s year to.

        Throws:
            $(LREF DateTimeException) if the new year is not a leap year and the
            resulting date would be on February 29th.
     +/
    @property void year(int year) @safe
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        auto date = Date(cast(int) days);
        date.year = year;

        immutable newDaysHNSecs = convert!("days", "hnsecs")(date.dayOfGregorianCal - 1);
        adjTime = newDaysHNSecs + hnsecs;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1999, 7, 6, 9, 7, 5)).year == 1999);
        assert(SysTime(DateTime(2010, 10, 4, 0, 0, 30)).year == 2010);
        assert(SysTime(DateTime(-7, 4, 5, 7, 45, 2)).year == -7);
    }

    @safe unittest
    {
        import std.range : chain;

        static void test(SysTime st, int year, in SysTime expected)
        {
            st.year = year;
            assert(st == expected);
        }

        foreach (st; chain(testSysTimesBC, testSysTimesAD))
        {
            auto dt = cast(DateTime) st;

            foreach (year; chain(testYearsBC, testYearsAD))
            {
                auto e = SysTime(DateTime(year, dt.month, dt.day, dt.hour, dt.minute, dt.second),
                                 st.fracSecs,
                                 st.timezone);
                test(st, year, e);
            }
        }

        foreach (fs; testFracSecs)
        {
            foreach (tz; testTZs)
            {
                foreach (tod; testTODs)
                {
                    test(SysTime(DateTime(Date(1999, 2, 28), tod), fs, tz), 2000,
                         SysTime(DateTime(Date(2000, 2, 28), tod), fs, tz));
                    test(SysTime(DateTime(Date(2000, 2, 28), tod), fs, tz), 1999,
                         SysTime(DateTime(Date(1999, 2, 28), tod), fs, tz));
                }

                foreach (tod; testTODsThrown)
                {
                    auto st = SysTime(DateTime(Date(2000, 2, 29), tod), fs, tz);
                    assertThrown!DateTimeException(st.year = 1999);
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.year = 7));
        //static assert(!__traits(compiles, ist.year = 7));
    }

    /++
        Year B.C. of the Gregorian Calendar counting year 0 as 1 B.C.

        Throws:
            $(LREF DateTimeException) if $(D isAD) is true.
     +/
    @property ushort yearBC() @safe const
    {
        return (cast(Date) this).yearBC;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(0, 1, 1, 12, 30, 33)).yearBC == 1);
        assert(SysTime(DateTime(-1, 1, 1, 10, 7, 2)).yearBC == 2);
        assert(SysTime(DateTime(-100, 1, 1, 4, 59, 0)).yearBC == 101);
    }

    @safe unittest
    {
        import std.exception : assertNotThrown;
        foreach (st; testSysTimesBC)
        {
            auto msg = format("SysTime: %s", st);
            assertNotThrown!DateTimeException(st.yearBC, msg);
            assert(st.yearBC == (st.year * -1) + 1, msg);
        }

        foreach (st; [testSysTimesAD[0], testSysTimesAD[$/2], testSysTimesAD[$-1]])
            assertThrown!DateTimeException(st.yearBC, format("SysTime: %s", st));

        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        st.year = 12;
        assert(st.year == 12);
        static assert(!__traits(compiles, cst.year = 12));
        //static assert(!__traits(compiles, ist.year = 12));
    }


    /++
        Year B.C. of the Gregorian Calendar counting year 0 as 1 B.C.

        Params:
            year = The year B.C. to set this $(LREF SysTime)'s year to.

        Throws:
            $(LREF DateTimeException) if a non-positive value is given.
     +/
    @property void yearBC(int year) @safe
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        auto date = Date(cast(int) days);
        date.yearBC = year;

        immutable newDaysHNSecs = convert!("days", "hnsecs")(date.dayOfGregorianCal - 1);
        adjTime = newDaysHNSecs + hnsecs;
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(2010, 1, 1, 7, 30, 0));
        st.yearBC = 1;
        assert(st == SysTime(DateTime(0, 1, 1, 7, 30, 0)));

        st.yearBC = 10;
        assert(st == SysTime(DateTime(-9, 1, 1, 7, 30, 0)));
    }

    @safe unittest
    {
        import std.range : chain;
        static void test(SysTime st, int year, in SysTime expected)
        {
            st.yearBC = year;
            assert(st == expected, format("SysTime: %s", st));
        }

        foreach (st; chain(testSysTimesBC, testSysTimesAD))
        {
            auto dt = cast(DateTime) st;

            foreach (year; testYearsBC)
            {
                auto e = SysTime(DateTime(year, dt.month, dt.day, dt.hour, dt.minute, dt.second),
                                 st.fracSecs,
                                 st.timezone);
                test(st, (year * -1) + 1, e);
            }
        }

        foreach (st; [testSysTimesBC[0], testSysTimesBC[$ - 1], testSysTimesAD[0], testSysTimesAD[$ - 1]])
        {
            foreach (year; testYearsBC)
                assertThrown!DateTimeException(st.yearBC = year);
        }

        foreach (fs; testFracSecs)
        {
            foreach (tz; testTZs)
            {
                foreach (tod; testTODs)
                {
                    test(SysTime(DateTime(Date(-1999, 2, 28), tod), fs, tz), 2001,
                         SysTime(DateTime(Date(-2000, 2, 28), tod), fs, tz));
                    test(SysTime(DateTime(Date(-2000, 2, 28), tod), fs, tz), 2000,
                         SysTime(DateTime(Date(-1999, 2, 28), tod), fs, tz));
                }

                foreach (tod; testTODsThrown)
                {
                    auto st = SysTime(DateTime(Date(-2000, 2, 29), tod), fs, tz);
                    assertThrown!DateTimeException(st.year = -1999);
                }
            }
        }

        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        st.yearBC = 12;
        assert(st.yearBC == 12);
        static assert(!__traits(compiles, cst.yearBC = 12));
        //static assert(!__traits(compiles, ist.yearBC = 12));
    }

    /++
        Month of a Gregorian Year.
     +/
    @property Month month() @safe const nothrow
    {
        return (cast(Date) this).month;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1999, 7, 6, 9, 7, 5)).month == 7);
        assert(SysTime(DateTime(2010, 10, 4, 0, 0, 30)).month == 10);
        assert(SysTime(DateTime(-7, 4, 5, 7, 45, 2)).month == 4);
    }

    @safe unittest
    {
        import std.range : chain;

        static void test(SysTime sysTime, Month expected)
        {
            assert(sysTime.month == expected, format("Value given: %s", sysTime));
        }

        test(SysTime(0, UTC()), Month.jan);
        test(SysTime(1, UTC()), Month.jan);
        test(SysTime(-1, UTC()), Month.dec);

        foreach (year; chain(testYearsBC, testYearsAD))
        {
            foreach (md; testMonthDays)
            {
                foreach (tod; testTODs)
                {
                    auto dt = DateTime(Date(year, md.month, md.day), tod);
                    foreach (fs; testFracSecs)
                    {
                        foreach (tz; testTZs)
                            test(SysTime(dt, fs, tz), md.month);
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.month == 7);
        //assert(ist.month == 7);
    }


    /++
        Month of a Gregorian Year.

        Params:
            month = The month to set this $(LREF SysTime)'s month to.

        Throws:
            $(LREF DateTimeException) if the given month is not a valid month.
     +/
    @property void month(Month month) @safe
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        auto date = Date(cast(int) days);
        date.month = month;

        immutable newDaysHNSecs = convert!("days", "hnsecs")(date.dayOfGregorianCal - 1);
        adjTime = newDaysHNSecs + hnsecs;
    }

    @safe unittest
    {
        import std.algorithm.iteration : filter;
        import std.range : chain;

        static void test(SysTime st, Month month, in SysTime expected)
        {
            st.month = cast(Month) month;
            assert(st == expected);
        }

        foreach (st; chain(testSysTimesBC, testSysTimesAD))
        {
            auto dt = cast(DateTime) st;

            foreach (md; testMonthDays)
            {
                if (st.day > maxDay(dt.year, md.month))
                    continue;
                auto e = SysTime(DateTime(dt.year, md.month, dt.day, dt.hour, dt.minute, dt.second),
                                 st.fracSecs,
                                 st.timezone);
                test(st, md.month, e);
            }
        }

        foreach (fs; testFracSecs)
        {
            foreach (tz; testTZs)
            {
                foreach (tod; testTODs)
                {
                    foreach (year; filter!((a){return yearIsLeapYear(a);}) (chain(testYearsBC, testYearsAD)))
                    {
                        test(SysTime(DateTime(Date(year, 1, 29), tod), fs, tz),
                             Month.feb,
                             SysTime(DateTime(Date(year, 2, 29), tod), fs, tz));
                    }

                    foreach (year; chain(testYearsBC, testYearsAD))
                    {
                        test(SysTime(DateTime(Date(year, 1, 28), tod), fs, tz),
                             Month.feb,
                             SysTime(DateTime(Date(year, 2, 28), tod), fs, tz));
                        test(SysTime(DateTime(Date(year, 7, 30), tod), fs, tz),
                             Month.jun,
                             SysTime(DateTime(Date(year, 6, 30), tod), fs, tz));
                    }
                }
            }
        }

        foreach (fs; [testFracSecs[0], testFracSecs[$-1]])
        {
            foreach (tz; testTZs)
            {
                foreach (tod; testTODsThrown)
                {
                    foreach (year; [testYearsBC[$-3], testYearsBC[$-2],
                                    testYearsBC[$-2], testYearsAD[0],
                                    testYearsAD[$-2], testYearsAD[$-1]])
                    {
                        auto day = yearIsLeapYear(year) ? 30 : 29;
                        auto st1 = SysTime(DateTime(Date(year, 1, day), tod), fs, tz);
                        assertThrown!DateTimeException(st1.month = Month.feb);

                        auto st2 = SysTime(DateTime(Date(year, 7, 31), tod), fs, tz);
                        assertThrown!DateTimeException(st2.month = Month.jun);
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.month = 12));
        //static assert(!__traits(compiles, ist.month = 12));
    }

    /++
        Day of a Gregorian Month.
     +/
    @property ubyte day() @safe const nothrow
    {
        return (cast(Date) this).day;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1999, 7, 6, 9, 7, 5)).day == 6);
        assert(SysTime(DateTime(2010, 10, 4, 0, 0, 30)).day == 4);
        assert(SysTime(DateTime(-7, 4, 5, 7, 45, 2)).day == 5);
    }

    @safe unittest
    {
        import std.range : chain;

        static void test(SysTime sysTime, int expected)
        {
            assert(sysTime.day == expected, format("Value given: %s", sysTime));
        }

        test(SysTime(0, UTC()), 1);
        test(SysTime(1, UTC()), 1);
        test(SysTime(-1, UTC()), 31);

        foreach (year; chain(testYearsBC, testYearsAD))
        {
            foreach (md; testMonthDays)
            {
                foreach (tod; testTODs)
                {
                    auto dt = DateTime(Date(year, md.month, md.day), tod);

                    foreach (tz; testTZs)
                    {
                        foreach (fs; testFracSecs)
                            test(SysTime(dt, fs, tz), md.day);
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
         assert(cst.day == 6);
        //assert(ist.day == 6);
    }


    /++
        Day of a Gregorian Month.

        Params:
            day = The day of the month to set this $(LREF SysTime)'s day to.

        Throws:
            $(LREF DateTimeException) if the given day is not a valid day of the
            current month.
     +/
    @property void day(int day) @safe
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        auto date = Date(cast(int) days);
        date.day = day;

        immutable newDaysHNSecs = convert!("days", "hnsecs")(date.dayOfGregorianCal - 1);
        adjTime = newDaysHNSecs + hnsecs;
    }

    @safe unittest
    {
        import std.range : chain;
        import std.traits : EnumMembers;

        foreach (day; chain(testDays))
        {
            foreach (st; chain(testSysTimesBC, testSysTimesAD))
            {
                auto dt = cast(DateTime) st;

                if (day > maxDay(dt.year, dt.month))
                    continue;
                auto expected = SysTime(DateTime(dt.year, dt.month, day, dt.hour, dt.minute, dt.second),
                                        st.fracSecs,
                                        st.timezone);
                st.day = day;
                assert(st == expected, format("[%s] [%s]", st, expected));
            }
        }

        foreach (tz; testTZs)
        {
            foreach (tod; testTODs)
            {
                foreach (fs; testFracSecs)
                {
                    foreach (year; chain(testYearsBC, testYearsAD))
                    {
                        foreach (month; EnumMembers!Month)
                        {
                            auto st = SysTime(DateTime(Date(year, month, 1), tod), fs, tz);
                            immutable max = maxDay(year, month);
                            auto expected = SysTime(DateTime(Date(year, month, max), tod), fs, tz);

                            st.day = max;
                            assert(st == expected, format("[%s] [%s]", st, expected));
                        }
                    }
                }
            }
        }

        foreach (tz; testTZs)
        {
            foreach (tod; testTODsThrown)
            {
                foreach (fs; [testFracSecs[0], testFracSecs[$-1]])
                {
                    foreach (year; [testYearsBC[$-3], testYearsBC[$-2],
                                    testYearsBC[$-2], testYearsAD[0],
                                    testYearsAD[$-2], testYearsAD[$-1]])
                    {
                        foreach (month; EnumMembers!Month)
                        {
                            auto st = SysTime(DateTime(Date(year, month, 1), tod), fs, tz);
                            immutable max = maxDay(year, month);

                            assertThrown!DateTimeException(st.day = max + 1);
                        }
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.day = 27));
        //static assert(!__traits(compiles, ist.day = 27));
    }


    /++
        Hours past midnight.
     +/
    @property ubyte hour() @safe const nothrow
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        return cast(ubyte) getUnitsFromHNSecs!"hours"(hnsecs);
    }

    @safe unittest
    {
        import std.range : chain;

        static void test(SysTime sysTime, int expected)
        {
            assert(sysTime.hour == expected, format("Value given: %s", sysTime));
        }

        test(SysTime(0, UTC()), 0);
        test(SysTime(1, UTC()), 0);
        test(SysTime(-1, UTC()), 23);

        foreach (tz; testTZs)
        {
            foreach (year; chain(testYearsBC, testYearsAD))
            {
                foreach (md; testMonthDays)
                {
                    foreach (hour; testHours)
                    {
                        foreach (minute; testMinSecs)
                        {
                            foreach (second; testMinSecs)
                            {
                                auto dt = DateTime(Date(year, md.month, md.day), TimeOfDay(hour, minute, second));
                                foreach (fs; testFracSecs)
                                    test(SysTime(dt, fs, tz), hour);
                            }
                        }
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.hour == 12);
        //assert(ist.hour == 12);
    }


    /++
        Hours past midnight.

        Params:
            hour = The hours to set this $(LREF SysTime)'s hour to.

        Throws:
            $(LREF DateTimeException) if the given hour are not a valid hour of
            the day.
     +/
    @property void hour(int hour) @safe
    {
        enforceValid!"hours"(hour);

        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs);
        immutable daysHNSecs = convert!("days", "hnsecs")(days);
        immutable negative = hnsecs < 0;

        if (negative)
            hnsecs += convert!("hours", "hnsecs")(24);

        hnsecs = removeUnitsFromHNSecs!"hours"(hnsecs);
        hnsecs += convert!("hours", "hnsecs")(hour);

        if (negative)
            hnsecs -= convert!("hours", "hnsecs")(24);

        adjTime = daysHNSecs + hnsecs;
    }

    @safe unittest
    {
        import std.range : chain;

        foreach (hour; chain(testHours))
        {
            foreach (st; chain(testSysTimesBC, testSysTimesAD))
            {
                auto dt = cast(DateTime) st;
                auto expected = SysTime(DateTime(dt.year, dt.month, dt.day, hour, dt.minute, dt.second),
                                        st.fracSecs,
                                        st.timezone);
                st.hour = hour;
                assert(st == expected, format("[%s] [%s]", st, expected));
            }
        }

        auto st = testSysTimesAD[0];
        assertThrown!DateTimeException(st.hour = -1);
        assertThrown!DateTimeException(st.hour = 60);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.hour = 27));
        //static assert(!__traits(compiles, ist.hour = 27));
    }


    /++
        Minutes past the current hour.
     +/
    @property ubyte minute() @safe const nothrow
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        hnsecs = removeUnitsFromHNSecs!"hours"(hnsecs);

        return cast(ubyte) getUnitsFromHNSecs!"minutes"(hnsecs);
    }

    @safe unittest
    {
        import std.range : chain;

        static void test(SysTime sysTime, int expected)
        {
            assert(sysTime.minute == expected, format("Value given: %s", sysTime));
        }

        test(SysTime(0, UTC()), 0);
        test(SysTime(1, UTC()), 0);
        test(SysTime(-1, UTC()), 59);

        foreach (tz; testTZs)
        {
            foreach (year; chain(testYearsBC, testYearsAD))
            {
                foreach (md; testMonthDays)
                {
                    foreach (hour; testHours)
                    {
                        foreach (minute; testMinSecs)
                        {
                            foreach (second; testMinSecs)
                            {
                                auto dt = DateTime(Date(year, md.month, md.day), TimeOfDay(hour, minute, second));
                                foreach (fs; testFracSecs)
                                    test(SysTime(dt, fs, tz), minute);
                            }
                        }
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.minute == 30);
        //assert(ist.minute == 30);
    }


    /++
        Minutes past the current hour.

        Params:
            minute = The minute to set this $(LREF SysTime)'s minute to.

        Throws:
            $(LREF DateTimeException) if the given minute are not a valid minute
            of an hour.
     +/
    @property void minute(int minute) @safe
    {
        enforceValid!"minutes"(minute);

        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs);
        immutable daysHNSecs = convert!("days", "hnsecs")(days);
        immutable negative = hnsecs < 0;

        if (negative)
            hnsecs += convert!("hours", "hnsecs")(24);

        immutable hour = splitUnitsFromHNSecs!"hours"(hnsecs);
        hnsecs = removeUnitsFromHNSecs!"minutes"(hnsecs);

        hnsecs += convert!("hours", "hnsecs")(hour);
        hnsecs += convert!("minutes", "hnsecs")(minute);

        if (negative)
            hnsecs -= convert!("hours", "hnsecs")(24);

        adjTime = daysHNSecs + hnsecs;
    }

    @safe unittest
    {
        import std.range : chain;

        foreach (minute; testMinSecs)
        {
            foreach (st; chain(testSysTimesBC, testSysTimesAD))
            {
                auto dt = cast(DateTime) st;
                auto expected = SysTime(DateTime(dt.year, dt.month, dt.day, dt.hour, minute, dt.second),
                                        st.fracSecs,
                                        st.timezone);
                st.minute = minute;
                assert(st == expected, format("[%s] [%s]", st, expected));
            }
        }

        auto st = testSysTimesAD[0];
        assertThrown!DateTimeException(st.minute = -1);
        assertThrown!DateTimeException(st.minute = 60);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.minute = 27));
        //static assert(!__traits(compiles, ist.minute = 27));
    }


    /++
        Seconds past the current minute.
     +/
    @property ubyte second() @safe const nothrow
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        hnsecs = removeUnitsFromHNSecs!"hours"(hnsecs);
        hnsecs = removeUnitsFromHNSecs!"minutes"(hnsecs);

        return cast(ubyte) getUnitsFromHNSecs!"seconds"(hnsecs);
    }

    @safe unittest
    {
        import std.range : chain;

        static void test(SysTime sysTime, int expected)
        {
            assert(sysTime.second == expected, format("Value given: %s", sysTime));
        }

        test(SysTime(0, UTC()), 0);
        test(SysTime(1, UTC()), 0);
        test(SysTime(-1, UTC()), 59);

        foreach (tz; testTZs)
        {
            foreach (year; chain(testYearsBC, testYearsAD))
            {
                foreach (md; testMonthDays)
                {
                    foreach (hour; testHours)
                    {
                        foreach (minute; testMinSecs)
                        {
                            foreach (second; testMinSecs)
                            {
                                auto dt = DateTime(Date(year, md.month, md.day), TimeOfDay(hour, minute, second));
                                foreach (fs; testFracSecs)
                                    test(SysTime(dt, fs, tz), second);
                            }
                        }
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.second == 33);
        //assert(ist.second == 33);
    }


    /++
        Seconds past the current minute.

        Params:
            second = The second to set this $(LREF SysTime)'s second to.

        Throws:
            $(LREF DateTimeException) if the given second are not a valid second
            of a minute.
     +/
    @property void second(int second) @safe
    {
        enforceValid!"seconds"(second);

        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs);
        immutable daysHNSecs = convert!("days", "hnsecs")(days);
        immutable negative = hnsecs < 0;

        if (negative)
            hnsecs += convert!("hours", "hnsecs")(24);

        immutable hour = splitUnitsFromHNSecs!"hours"(hnsecs);
        immutable minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
        hnsecs = removeUnitsFromHNSecs!"seconds"(hnsecs);

        hnsecs += convert!("hours", "hnsecs")(hour);
        hnsecs += convert!("minutes", "hnsecs")(minute);
        hnsecs += convert!("seconds", "hnsecs")(second);

        if (negative)
            hnsecs -= convert!("hours", "hnsecs")(24);

        adjTime = daysHNSecs + hnsecs;
    }

    @safe unittest
    {
        import std.range : chain;

        foreach (second; testMinSecs)
        {
            foreach (st; chain(testSysTimesBC, testSysTimesAD))
            {
                auto dt = cast(DateTime) st;
                auto expected = SysTime(DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, second),
                                        st.fracSecs,
                                        st.timezone);
                st.second = second;
                assert(st == expected, format("[%s] [%s]", st, expected));
            }
        }

        auto st = testSysTimesAD[0];
        assertThrown!DateTimeException(st.second = -1);
        assertThrown!DateTimeException(st.second = 60);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.seconds = 27));
        //static assert(!__traits(compiles, ist.seconds = 27));
    }


    /++
        Fractional seconds past the second (i.e. the portion of a
        $(LREF SysTime) which is less than a second).
     +/
    @property Duration fracSecs() @safe const nothrow
    {
        auto hnsecs = removeUnitsFromHNSecs!"days"(adjTime);

        if (hnsecs < 0)
            hnsecs += convert!("hours", "hnsecs")(24);

        return dur!"hnsecs"(removeUnitsFromHNSecs!"seconds"(hnsecs));
    }

    ///
    @safe unittest
    {
        auto dt = DateTime(1982, 4, 1, 20, 59, 22);
        assert(SysTime(dt, msecs(213)).fracSecs == msecs(213));
        assert(SysTime(dt, usecs(5202)).fracSecs == usecs(5202));
        assert(SysTime(dt, hnsecs(1234567)).fracSecs == hnsecs(1234567));

        // SysTime and Duration both have a precision of hnsecs (100 ns),
        // so nsecs are going to be truncated.
        assert(SysTime(dt, nsecs(123456789)).fracSecs == nsecs(123456700));
    }

    @safe unittest
    {
        import std.range : chain;

        assert(SysTime(0, UTC()).fracSecs == Duration.zero);
        assert(SysTime(1, UTC()).fracSecs == hnsecs(1));
        assert(SysTime(-1, UTC()).fracSecs == hnsecs(9_999_999));

        foreach (tz; testTZs)
        {
            foreach (year; chain(testYearsBC, testYearsAD))
            {
                foreach (md; testMonthDays)
                {
                    foreach (hour; testHours)
                    {
                        foreach (minute; testMinSecs)
                        {
                            foreach (second; testMinSecs)
                            {
                                auto dt = DateTime(Date(year, md.month, md.day), TimeOfDay(hour, minute, second));
                                foreach (fs; testFracSecs)
                                    assert(SysTime(dt, fs, tz).fracSecs == fs);
                            }
                        }
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.fracSecs == Duration.zero);
        //assert(ist.fracSecs == Duration.zero);
    }


    /++
        Fractional seconds past the second (i.e. the portion of a
        $(LREF SysTime) which is less than a second).

        Params:
            fracSecs = The duration to set this $(LREF SysTime)'s fractional
                       seconds to.

        Throws:
            $(LREF DateTimeException) if the given duration is negative or if
            it's greater than or equal to one second.
     +/
    @property void fracSecs(Duration fracSecs) @safe
    {
        enforce(fracSecs >= Duration.zero, new DateTimeException("A SysTime cannot have negative fractional seconds."));
        enforce(fracSecs < seconds(1), new DateTimeException("Fractional seconds must be less than one second."));

        auto oldHNSecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(oldHNSecs);
        immutable daysHNSecs = convert!("days", "hnsecs")(days);
        immutable negative = oldHNSecs < 0;

        if (negative)
            oldHNSecs += convert!("hours", "hnsecs")(24);

        immutable seconds = splitUnitsFromHNSecs!"seconds"(oldHNSecs);
        immutable secondsHNSecs = convert!("seconds", "hnsecs")(seconds);
        auto newHNSecs = fracSecs.total!"hnsecs" + secondsHNSecs;

        if (negative)
            newHNSecs -= convert!("hours", "hnsecs")(24);

        adjTime = daysHNSecs + newHNSecs;
    }

    ///
    @safe unittest
    {
        auto st = SysTime(DateTime(1982, 4, 1, 20, 59, 22));
        assert(st.fracSecs == Duration.zero);

        st.fracSecs = msecs(213);
        assert(st.fracSecs == msecs(213));

        st.fracSecs = hnsecs(1234567);
        assert(st.fracSecs == hnsecs(1234567));

        // SysTime has a precision of hnsecs (100 ns), so nsecs are
        // going to be truncated.
        st.fracSecs = nsecs(123456789);
        assert(st.fracSecs == hnsecs(1234567));
    }

    @safe unittest
    {
        import std.range : chain;

        foreach (fracSec; testFracSecs)
        {
            foreach (st; chain(testSysTimesBC, testSysTimesAD))
            {
                auto dt = cast(DateTime) st;
                auto expected = SysTime(dt, fracSec, st.timezone);
                st.fracSecs = fracSec;
                assert(st == expected, format("[%s] [%s]", st, expected));
            }
        }

        auto st = testSysTimesAD[0];
        assertThrown!DateTimeException(st.fracSecs = hnsecs(-1));
        assertThrown!DateTimeException(st.fracSecs = seconds(1));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.fracSecs = msecs(7)));
        //static assert(!__traits(compiles, ist.fracSecs = msecs(7)));
    }


    // Explicitly undocumented. It will be removed in August 2017. @@@DEPRECATED_2017-08@@@
    deprecated("Please use fracSecs (with an s) rather than fracSec (without an s). " ~
               "It returns a Duration instead of a FracSec, as FracSec is being deprecated.")
    @property FracSec fracSec() @safe const nothrow
    {
        try
        {
            auto hnsecs = removeUnitsFromHNSecs!"days"(adjTime);

            if (hnsecs < 0)
                hnsecs += convert!("hours", "hnsecs")(24);

            hnsecs = removeUnitsFromHNSecs!"seconds"(hnsecs);

            return FracSec.from!"hnsecs"(cast(int) hnsecs);
        }
        catch (Exception e)
            assert(0, "FracSec.from!\"hnsecs\"() threw.");
    }

    deprecated @safe unittest
    {
        import std.range;

        static void test(SysTime sysTime, FracSec expected, size_t line = __LINE__)
        {
            if (sysTime.fracSec != expected)
                throw new AssertError(format("Value given: %s", sysTime.fracSec), __FILE__, line);
        }

        test(SysTime(0, UTC()), FracSec.from!"hnsecs"(0));
        test(SysTime(1, UTC()), FracSec.from!"hnsecs"(1));
        test(SysTime(-1, UTC()), FracSec.from!"hnsecs"(9_999_999));

        foreach (tz; testTZs)
        {
            foreach (year; chain(testYearsBC, testYearsAD))
            {
                foreach (md; testMonthDays)
                {
                    foreach (hour; testHours)
                    {
                        foreach (minute; testMinSecs)
                        {
                            foreach (second; testMinSecs)
                            {
                                auto dt = DateTime(Date(year, md.month, md.day), TimeOfDay(hour, minute, second));
                                foreach (fs; testFracSecs)
                                    test(SysTime(dt, fs, tz), FracSec.from!"hnsecs"(fs.total!"hnsecs"));
                            }
                        }
                    }
                }
            }
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.fracSec == FracSec.zero);
        //assert(ist.fracSec == FracSec.zero);
    }


    // Explicitly undocumented. It will be removed in August 2017. @@@DEPRECATED_2017-08@@@
    deprecated("Please use fracSecs (with an s) rather than fracSec (without an s). " ~
               "It takes a Duration instead of a FracSec, as FracSec is being deprecated.")
    @property void fracSec(FracSec fracSec) @safe
    {
        immutable fracHNSecs = fracSec.hnsecs;
        enforce(fracHNSecs >= 0, new DateTimeException("A SysTime cannot have negative fractional seconds."));

        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs);
        immutable daysHNSecs = convert!("days", "hnsecs")(days);
        immutable negative = hnsecs < 0;

        if (negative)
            hnsecs += convert!("hours", "hnsecs")(24);

        immutable hour = splitUnitsFromHNSecs!"hours"(hnsecs);
        immutable minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
        immutable second = getUnitsFromHNSecs!"seconds"(hnsecs);

        hnsecs = fracHNSecs;
        hnsecs += convert!("hours", "hnsecs")(hour);
        hnsecs += convert!("minutes", "hnsecs")(minute);
        hnsecs += convert!("seconds", "hnsecs")(second);

        if (negative)
            hnsecs -= convert!("hours", "hnsecs")(24);

        adjTime = daysHNSecs + hnsecs;
    }

    deprecated @safe unittest
    {
        import std.range;

        foreach (fracSec; testFracSecs)
        {
            foreach (st; chain(testSysTimesBC, testSysTimesAD))
            {
                auto dt = cast(DateTime) st;
                auto expected = SysTime(dt, fracSec, st.timezone);
                st.fracSec = FracSec.from!"hnsecs"(fracSec.total!"hnsecs");
                assert(st == expected, format("[%s] [%s]", st, expected));
            }
        }

        auto st = testSysTimesAD[0];
        assertThrown!DateTimeException(st.fracSec = FracSec.from!"hnsecs"(-1));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.fracSec = FracSec.from!"msecs"(7)));
        //static assert(!__traits(compiles, ist.fracSec = FracSec.from!"msecs"(7)));
    }


    /++
        The total hnsecs from midnight, January 1st, 1 A.D. UTC. This is the
        internal representation of $(LREF SysTime).
     +/
    @property long stdTime() @safe const pure nothrow
    {
        return _stdTime;
    }

    @safe unittest
    {
        assert(SysTime(0).stdTime == 0);
        assert(SysTime(1).stdTime == 1);
        assert(SysTime(-1).stdTime == -1);
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 33), hnsecs(502), UTC()).stdTime == 330_000_502L);
        assert(SysTime(DateTime(1970, 1, 1, 0, 0, 0), UTC()).stdTime == 621_355_968_000_000_000L);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.stdTime > 0);
        //assert(ist.stdTime > 0);
    }


    /++
        The total hnsecs from midnight, January 1st, 1 A.D. UTC. This is the
        internal representation of $(LREF SysTime).

        Params:
            stdTime = The number of hnsecs since January 1st, 1 A.D. UTC.
     +/
    @property void stdTime(long stdTime) @safe pure nothrow
    {
        _stdTime = stdTime;
    }

    @safe unittest
    {
        static void test(long stdTime, in SysTime expected, size_t line = __LINE__)
        {
            auto st = SysTime(0, UTC());
            st.stdTime = stdTime;
            assert(st == expected);
        }

        test(0, SysTime(Date(1, 1, 1), UTC()));
        test(1, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1), UTC()));
        test(-1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC()));
        test(330_000_502L, SysTime(DateTime(1, 1, 1, 0, 0, 33), hnsecs(502), UTC()));
        test(621_355_968_000_000_000L, SysTime(DateTime(1970, 1, 1, 0, 0, 0), UTC()));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.stdTime = 27));
        //static assert(!__traits(compiles, ist.stdTime = 27));
    }


    /++
        The current time zone of this $(LREF SysTime). Its internal time is always
        kept in UTC, so there are no conversion issues between time zones due to
        DST. Functions which return all or part of the time - such as hours -
        adjust the time to this $(LREF SysTime)'s time zone before returning.
      +/
    @property immutable(TimeZone) timezone() @safe const pure nothrow
    {
        return _timezone;
    }


    /++
        The current time zone of this $(LREF SysTime). It's internal time is always
        kept in UTC, so there are no conversion issues between time zones due to
        DST. Functions which return all or part of the time - such as hours -
        adjust the time to this $(LREF SysTime)'s time zone before returning.

        Params:
            timezone = The $(LREF2 .TimeZone, TimeZone) to set this $(LREF SysTime)'s time zone to.
      +/
    @property void timezone(immutable TimeZone timezone) @safe pure nothrow
    {
        if (timezone is null)
            _timezone = LocalTime();
        else
            _timezone = timezone;
    }


    /++
        Returns whether DST is in effect for this $(LREF SysTime).
      +/
    @property bool dstInEffect() @safe const nothrow
    {
        return _timezone.dstInEffect(_stdTime);
        // This function's unit testing is done in the time zone classes.
    }


    /++
        Returns what the offset from UTC is for this $(LREF SysTime).
        It includes the DST offset in effect at that time (if any).
      +/
    @property Duration utcOffset() @safe const nothrow
    {
        return _timezone.utcOffsetAt(_stdTime);
    }


    /++
        Returns a $(LREF SysTime) with the same std time as this one, but with
        $(LREF LocalTime) as its time zone.
      +/
    SysTime toLocalTime() @safe const pure nothrow
    {
        return SysTime(_stdTime, LocalTime());
    }

    @safe unittest
    {
        {
            auto sysTime = SysTime(DateTime(1982, 1, 4, 8, 59, 7), hnsecs(27));
            assert(sysTime == sysTime.toLocalTime());
            assert(sysTime._stdTime == sysTime.toLocalTime()._stdTime);
            assert(sysTime.toLocalTime().timezone is LocalTime());
            assert(sysTime.toLocalTime().timezone is sysTime.timezone);
            assert(sysTime.toLocalTime().timezone !is UTC());
        }

        {
            auto stz = new immutable SimpleTimeZone(dur!"minutes"(-3 * 60));
            auto sysTime = SysTime(DateTime(1982, 1, 4, 8, 59, 7), hnsecs(27), stz);
            assert(sysTime == sysTime.toLocalTime());
            assert(sysTime._stdTime == sysTime.toLocalTime()._stdTime);
            assert(sysTime.toLocalTime().timezone is LocalTime());
            assert(sysTime.toLocalTime().timezone !is UTC());
            assert(sysTime.toLocalTime().timezone !is stz);
        }
    }


    /++
        Returns a $(LREF SysTime) with the same std time as this one, but with
        $(D UTC) as its time zone.
      +/
    SysTime toUTC() @safe const pure nothrow
    {
        return SysTime(_stdTime, UTC());
    }

    @safe unittest
    {
        auto sysTime = SysTime(DateTime(1982, 1, 4, 8, 59, 7), hnsecs(27));
        assert(sysTime == sysTime.toUTC());
        assert(sysTime._stdTime == sysTime.toUTC()._stdTime);
        assert(sysTime.toUTC().timezone is UTC());
        assert(sysTime.toUTC().timezone !is LocalTime());
        assert(sysTime.toUTC().timezone !is sysTime.timezone);
    }


    /++
        Returns a $(LREF SysTime) with the same std time as this one, but with
        given time zone as its time zone.
      +/
    SysTime toOtherTZ(immutable TimeZone tz) @safe const pure nothrow
    {
        if (tz is null)
            return SysTime(_stdTime, LocalTime());
        else
            return SysTime(_stdTime, tz);
    }

    @safe unittest
    {
        auto stz = new immutable SimpleTimeZone(dur!"minutes"(11 * 60));
        auto sysTime = SysTime(DateTime(1982, 1, 4, 8, 59, 7), hnsecs(27));
        assert(sysTime == sysTime.toOtherTZ(stz));
        assert(sysTime._stdTime == sysTime.toOtherTZ(stz)._stdTime);
        assert(sysTime.toOtherTZ(stz).timezone is stz);
        assert(sysTime.toOtherTZ(stz).timezone !is LocalTime());
        assert(sysTime.toOtherTZ(stz).timezone !is UTC());
    }


    /++
        Converts this $(LREF SysTime) to unix time (i.e. seconds from midnight,
        January 1st, 1970 in UTC).

        The C standard does not specify the representation of time_t, so it is
        implementation defined. On POSIX systems, unix time is equivalent to
        time_t, but that's not necessarily true on other systems (e.g. it is
        not true for the Digital Mars C runtime). So, be careful when using unix
        time with C functions on non-POSIX systems.

        By default, the return type is time_t (which is normally an alias for
        int on 32-bit systems and long on 64-bit systems), but if a different
        size is required than either int or long can be passed as a template
        argument to get the desired size.

        If the return type is int, and the result can't fit in an int, then the
        closest value that can be held in 32 bits will be used (so $(D int.max)
        if it goes over and $(D int.min) if it goes under). However, no attempt
        is made to deal with integer overflow if the return type is long.

        Params:
            T = The return type (int or long). It defaults to time_t, which is
                normally 32 bits on a 32-bit system and 64 bits on a 64-bit
                system.

        Returns:
            A signed integer representing the unix time which is equivalent to
            this SysTime.
      +/
    T toUnixTime(T = time_t)() @safe const pure nothrow
        if (is(T == int) || is(T == long))
    {
        return stdTimeToUnixTime!T(_stdTime);
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1970, 1, 1), UTC()).toUnixTime() == 0);

        auto pst = new immutable SimpleTimeZone(hours(-8));
        assert(SysTime(DateTime(1970, 1, 1), pst).toUnixTime() == 28800);

        auto utc = SysTime(DateTime(2007, 12, 22, 8, 14, 45), UTC());
        assert(utc.toUnixTime() == 1_198_311_285);

        auto ca = SysTime(DateTime(2007, 12, 22, 8, 14, 45), pst);
        assert(ca.toUnixTime() == 1_198_340_085);
    }

    @safe unittest
    {
        import std.meta : AliasSeq;
        assert(SysTime(DateTime(1970, 1, 1), UTC()).toUnixTime() == 0);
        foreach (units; AliasSeq!("hnsecs", "usecs", "msecs"))
            assert(SysTime(DateTime(1970, 1, 1, 0, 0, 0), dur!units(1), UTC()).toUnixTime() == 0);
        assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), UTC()).toUnixTime() == 1);
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC()).toUnixTime() == 0);
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), usecs(999_999), UTC()).toUnixTime() == 0);
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), msecs(999), UTC()).toUnixTime() == 0);
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), UTC()).toUnixTime() == -1);
    }


    /++
        Converts from unix time (i.e. seconds from midnight, January 1st, 1970
        in UTC) to a $(LREF SysTime).

        The C standard does not specify the representation of time_t, so it is
        implementation defined. On POSIX systems, unix time is equivalent to
        time_t, but that's not necessarily true on other systems (e.g. it is
        not true for the Digital Mars C runtime). So, be careful when using unix
        time with C functions on non-POSIX systems.

        Params:
            unixTime = Seconds from midnight, January 1st, 1970 in UTC.
            tz = The time zone for the SysTime that's returned.
      +/
    static SysTime fromUnixTime(long unixTime, immutable TimeZone tz = LocalTime()) @safe pure nothrow
    {
        return SysTime(unixTimeToStdTime(unixTime), tz);
    }

    ///
    @safe unittest
    {
        assert(SysTime.fromUnixTime(0) ==
               SysTime(DateTime(1970, 1, 1), UTC()));

        auto pst = new immutable SimpleTimeZone(hours(-8));
        assert(SysTime.fromUnixTime(28800) ==
               SysTime(DateTime(1970, 1, 1), pst));

        auto st1 = SysTime.fromUnixTime(1_198_311_285, UTC());
        assert(st1 == SysTime(DateTime(2007, 12, 22, 8, 14, 45), UTC()));
        assert(st1.timezone is UTC());
        assert(st1 == SysTime(DateTime(2007, 12, 22, 0, 14, 45), pst));

        auto st2 = SysTime.fromUnixTime(1_198_311_285, pst);
        assert(st2 == SysTime(DateTime(2007, 12, 22, 8, 14, 45), UTC()));
        assert(st2.timezone is pst);
        assert(st2 == SysTime(DateTime(2007, 12, 22, 0, 14, 45), pst));
    }

    @safe unittest
    {
        assert(SysTime.fromUnixTime(0) == SysTime(DateTime(1970, 1, 1), UTC()));
        assert(SysTime.fromUnixTime(1) == SysTime(DateTime(1970, 1, 1, 0, 0, 1), UTC()));
        assert(SysTime.fromUnixTime(-1) == SysTime(DateTime(1969, 12, 31, 23, 59, 59), UTC()));

        auto st = SysTime.fromUnixTime(0);
        auto dt = cast(DateTime) st;
        assert(dt <= DateTime(1970, 2, 1) && dt >= DateTime(1969, 12, 31));
        assert(st.timezone is LocalTime());

        auto aest = new immutable SimpleTimeZone(hours(10));
        assert(SysTime.fromUnixTime(-36000) == SysTime(DateTime(1970, 1, 1), aest));
    }


    /++
        Returns a $(D timeval) which represents this $(LREF SysTime).

        Note that like all conversions in std.datetime, this is a truncating
        conversion.

        If $(D timeval.tv_sec) is int, and the result can't fit in an int, then
        the closest value that can be held in 32 bits will be used for
        $(D tv_sec). (so $(D int.max) if it goes over and $(D int.min) if it
        goes under).
      +/
    timeval toTimeVal() @safe const pure nothrow
    {
        immutable tv_sec = toUnixTime!(typeof(timeval.tv_sec))();
        immutable fracHNSecs = removeUnitsFromHNSecs!"seconds"(_stdTime - 621_355_968_000_000_000L);
        immutable tv_usec = cast(typeof(timeval.tv_usec))convert!("hnsecs", "usecs")(fracHNSecs);
        return timeval(tv_sec, tv_usec);
    }

    @safe unittest
    {
        assert(SysTime(DateTime(1970, 1, 1), UTC()).toTimeVal() == timeval(0, 0));
        assert(SysTime(DateTime(1970, 1, 1), hnsecs(9), UTC()).toTimeVal() == timeval(0, 0));
        assert(SysTime(DateTime(1970, 1, 1), hnsecs(10), UTC()).toTimeVal() == timeval(0, 1));
        assert(SysTime(DateTime(1970, 1, 1), usecs(7), UTC()).toTimeVal() == timeval(0, 7));

        assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), UTC()).toTimeVal() == timeval(1, 0));
        assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), hnsecs(9), UTC()).toTimeVal() == timeval(1, 0));
        assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), hnsecs(10), UTC()).toTimeVal() == timeval(1, 1));
        assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), usecs(7), UTC()).toTimeVal() == timeval(1, 7));

        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC()).toTimeVal() == timeval(0, 0));
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), hnsecs(9_999_990), UTC()).toTimeVal() == timeval(0, -1));

        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), usecs(999_999), UTC()).toTimeVal() == timeval(0, -1));
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), usecs(999), UTC()).toTimeVal() == timeval(0, -999_001));
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), msecs(999), UTC()).toTimeVal() == timeval(0, -1000));
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), UTC()).toTimeVal() == timeval(-1, 0));
        assert(SysTime(DateTime(1969, 12, 31, 23, 59, 58), usecs(17), UTC()).toTimeVal() == timeval(-1, -999_983));
    }


    version(StdDdoc)
    {
        private struct timespec {}
        /++
            Returns a $(D timespec) which represents this $(LREF SysTime).

            $(BLUE This function is Posix-Only.)
          +/
        timespec toTimeSpec() @safe const pure nothrow;
    }
    else version(Posix)
    {
        timespec toTimeSpec() @safe const pure nothrow
        {
            immutable tv_sec = toUnixTime!(typeof(timespec.tv_sec))();
            immutable fracHNSecs = removeUnitsFromHNSecs!"seconds"(_stdTime - 621_355_968_000_000_000L);
            immutable tv_nsec = cast(typeof(timespec.tv_nsec))convert!("hnsecs", "nsecs")(fracHNSecs);
            return timespec(tv_sec, tv_nsec);
        }

        @safe unittest
        {
            assert(SysTime(DateTime(1970, 1, 1), UTC()).toTimeSpec() == timespec(0, 0));
            assert(SysTime(DateTime(1970, 1, 1), hnsecs(9), UTC()).toTimeSpec() == timespec(0, 900));
            assert(SysTime(DateTime(1970, 1, 1), hnsecs(10), UTC()).toTimeSpec() == timespec(0, 1000));
            assert(SysTime(DateTime(1970, 1, 1), usecs(7), UTC()).toTimeSpec() == timespec(0, 7000));

            assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), UTC()).toTimeSpec() == timespec(1, 0));
            assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), hnsecs(9), UTC()).toTimeSpec() == timespec(1, 900));
            assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), hnsecs(10), UTC()).toTimeSpec() == timespec(1, 1000));
            assert(SysTime(DateTime(1970, 1, 1, 0, 0, 1), usecs(7), UTC()).toTimeSpec() == timespec(1, 7000));

            assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC()).toTimeSpec() ==
                   timespec(0, -100));
            assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), hnsecs(9_999_990), UTC()).toTimeSpec() ==
                   timespec(0, -1000));

            assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), usecs(999_999), UTC()).toTimeSpec() ==
                   timespec(0, -1_000));
            assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), usecs(999), UTC()).toTimeSpec() ==
                   timespec(0, -999_001_000));
            assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), msecs(999), UTC()).toTimeSpec() ==
                   timespec(0, -1_000_000));
            assert(SysTime(DateTime(1969, 12, 31, 23, 59, 59), UTC()).toTimeSpec() ==
                   timespec(-1, 0));
            assert(SysTime(DateTime(1969, 12, 31, 23, 59, 58), usecs(17), UTC()).toTimeSpec() ==
                   timespec(-1, -999_983_000));
        }
    }

    /++
        Returns a $(D tm) which represents this $(LREF SysTime).
      +/
    tm toTM() @safe const nothrow
    {
        auto dateTime = cast(DateTime) this;
        tm timeInfo;

        timeInfo.tm_sec = dateTime.second;
        timeInfo.tm_min = dateTime.minute;
        timeInfo.tm_hour = dateTime.hour;
        timeInfo.tm_mday = dateTime.day;
        timeInfo.tm_mon = dateTime.month - 1;
        timeInfo.tm_year = dateTime.year - 1900;
        timeInfo.tm_wday = dateTime.dayOfWeek;
        timeInfo.tm_yday = dateTime.dayOfYear - 1;
        timeInfo.tm_isdst = _timezone.dstInEffect(_stdTime);

        version(Posix)
        {
            import std.utf : toUTFz;
            timeInfo.tm_gmtoff = cast(int) convert!("hnsecs", "seconds")(adjTime - _stdTime);
            auto zone = (timeInfo.tm_isdst ? _timezone.dstName : _timezone.stdName);
            timeInfo.tm_zone = zone.toUTFz!(char*)();
        }

        return timeInfo;
    }

    @system unittest
    {
        import std.conv : to;

        version(Posix)
        {
            scope(exit) clearTZEnvVar();
            setTZEnvVar("America/Los_Angeles");
        }

        {
            auto timeInfo = SysTime(DateTime(1970, 1, 1)).toTM();

            assert(timeInfo.tm_sec == 0);
            assert(timeInfo.tm_min == 0);
            assert(timeInfo.tm_hour == 0);
            assert(timeInfo.tm_mday == 1);
            assert(timeInfo.tm_mon == 0);
            assert(timeInfo.tm_year == 70);
            assert(timeInfo.tm_wday == 4);
            assert(timeInfo.tm_yday == 0);

            version(Posix)
                assert(timeInfo.tm_isdst == 0);
            else version(Windows)
                assert(timeInfo.tm_isdst == 0 || timeInfo.tm_isdst == 1);

            version(Posix)
            {
                assert(timeInfo.tm_gmtoff == -8 * 60 * 60);
                assert(to!string(timeInfo.tm_zone) == "PST");
            }
        }

        {
            auto timeInfo = SysTime(DateTime(2010, 7, 4, 12, 15, 7), hnsecs(15)).toTM();

            assert(timeInfo.tm_sec == 7);
            assert(timeInfo.tm_min == 15);
            assert(timeInfo.tm_hour == 12);
            assert(timeInfo.tm_mday == 4);
            assert(timeInfo.tm_mon == 6);
            assert(timeInfo.tm_year == 110);
            assert(timeInfo.tm_wday == 0);
            assert(timeInfo.tm_yday == 184);

            version(Posix)
                assert(timeInfo.tm_isdst == 1);
            else version(Windows)
                assert(timeInfo.tm_isdst == 0 || timeInfo.tm_isdst == 1);

            version(Posix)
            {
                assert(timeInfo.tm_gmtoff == -7 * 60 * 60);
                assert(to!string(timeInfo.tm_zone) == "PDT");
            }
        }
    }


    /++
        Adds the given number of years or months to this $(LREF SysTime). A
        negative number will subtract.

        Note that if day overflow is allowed, and the date with the adjusted
        year/month overflows the number of days in the new month, then the month
        will be incremented by one, and the day set to the number of days
        overflowed. (e.g. if the day were 31 and the new month were June, then
        the month would be incremented to July, and the new day would be 1). If
        day overflow is not allowed, then the day will be set to the last valid
        day in the month (e.g. June 31st would become June 30th).

        Params:
            units         = The type of units to add ("years" or "months").
            value         = The number of months or years to add to this
                            $(LREF SysTime).
            allowOverflow = Whether the days should be allowed to overflow,
                            causing the month to increment.
      +/
    ref SysTime add(string units)(long value, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe nothrow
        if (units == "years" || units == "months")
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        auto date = Date(cast(int) days);
        date.add!units(value, allowOverflow);
        days = date.dayOfGregorianCal - 1;

        if (days < 0)
        {
            hnsecs -= convert!("hours", "hnsecs")(24);
            ++days;
        }

        immutable newDaysHNSecs = convert!("days", "hnsecs")(days);

        adjTime = newDaysHNSecs + hnsecs;

        return this;
    }

    @safe unittest
    {
        auto st1 = SysTime(DateTime(2010, 1, 1, 12, 30, 33));
        st1.add!"months"(11);
        assert(st1 == SysTime(DateTime(2010, 12, 1, 12, 30, 33)));

        auto st2 = SysTime(DateTime(2010, 1, 1, 12, 30, 33));
        st2.add!"months"(-11);
        assert(st2 == SysTime(DateTime(2009, 2, 1, 12, 30, 33)));

        auto st3 = SysTime(DateTime(2000, 2, 29, 12, 30, 33));
        st3.add!"years"(1);
        assert(st3 == SysTime(DateTime(2001, 3, 1, 12, 30, 33)));

        auto st4 = SysTime(DateTime(2000, 2, 29, 12, 30, 33));
        st4.add!"years"(1, AllowDayOverflow.no);
        assert(st4 == SysTime(DateTime(2001, 2, 28, 12, 30, 33)));
    }

    // Test add!"years"() with AllowDayOverflow.yes
    @safe unittest
    {
        // Test A.D.
        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"years"(7);
            assert(sysTime == SysTime(Date(2006, 7, 6)));
            sysTime.add!"years"(-9);
            assert(sysTime == SysTime(Date(1997, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 2, 28));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(Date(2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(2000, 2, 29));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(Date(1999, 3, 1)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 7, 6, 12, 7, 3), msecs(234));
            sysTime.add!"years"(7);
            assert(sysTime == SysTime(DateTime(2006, 7, 6, 12, 7, 3), msecs(234)));
            sysTime.add!"years"(-9);
            assert(sysTime == SysTime(DateTime(1997, 7, 6, 12, 7, 3), msecs(234)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 2, 28, 0, 7, 2), usecs(1207));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(DateTime(2000, 2, 28, 0, 7, 2), usecs(1207)));
        }

        {
            auto sysTime = SysTime(DateTime(2000, 2, 29, 0, 7, 2), usecs(1207));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(DateTime(1999, 3, 1, 0, 7, 2), usecs(1207)));
        }

        // Test B.C.
        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"years"(-7);
            assert(sysTime == SysTime(Date(-2006, 7, 6)));
            sysTime.add!"years"(9);
            assert(sysTime == SysTime(Date(-1997, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 2, 28));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(Date(-2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2000, 2, 29));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(Date(-1999, 3, 1)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 7, 6, 12, 7, 3), msecs(234));
            sysTime.add!"years"(-7);
            assert(sysTime == SysTime(DateTime(-2006, 7, 6, 12, 7, 3), msecs(234)));
            sysTime.add!"years"(9);
            assert(sysTime == SysTime(DateTime(-1997, 7, 6, 12, 7, 3), msecs(234)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 2, 28, 3, 3, 3), hnsecs(3));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(DateTime(-2000, 2, 28, 3, 3, 3), hnsecs(3)));
        }

        {
            auto sysTime = SysTime(DateTime(-2000, 2, 29, 3, 3, 3), hnsecs(3));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(DateTime(-1999, 3, 1, 3, 3, 3), hnsecs(3)));
        }

        // Test Both
        {
            auto sysTime = SysTime(Date(4, 7, 6));
            sysTime.add!"years"(-5);
            assert(sysTime == SysTime(Date(-1, 7, 6)));
            sysTime.add!"years"(5);
            assert(sysTime == SysTime(Date(4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-4, 7, 6));
            sysTime.add!"years"(5);
            assert(sysTime == SysTime(Date(1, 7, 6)));
            sysTime.add!"years"(-5);
            assert(sysTime == SysTime(Date(-4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(4, 7, 6));
            sysTime.add!"years"(-8);
            assert(sysTime == SysTime(Date(-4, 7, 6)));
            sysTime.add!"years"(8);
            assert(sysTime == SysTime(Date(4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-4, 7, 6));
            sysTime.add!"years"(8);
            assert(sysTime == SysTime(Date(4, 7, 6)));
            sysTime.add!"years"(-8);
            assert(sysTime == SysTime(Date(-4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-4, 2, 29));
            sysTime.add!"years"(5);
            assert(sysTime == SysTime(Date(1, 3, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 2, 29));
            sysTime.add!"years"(-5);
            assert(sysTime == SysTime(Date(-1, 3, 1)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 0, 0, 0)));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 1, 1, 0, 0, 0));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"years"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"years"(-1);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 7, 6, 14, 7, 1), usecs(54329));
            sysTime.add!"years"(-5);
            assert(sysTime == SysTime(DateTime(-1, 7, 6, 14, 7, 1), usecs(54329)));
            sysTime.add!"years"(5);
            assert(sysTime == SysTime(DateTime(4, 7, 6, 14, 7, 1), usecs(54329)));
        }

        {
            auto sysTime = SysTime(DateTime(-4, 7, 6, 14, 7, 1), usecs(54329));
            sysTime.add!"years"(5);
            assert(sysTime == SysTime(DateTime(1, 7, 6, 14, 7, 1), usecs(54329)));
            sysTime.add!"years"(-5);
            assert(sysTime == SysTime(DateTime(-4, 7, 6, 14, 7, 1), usecs(54329)));
        }

        {
            auto sysTime = SysTime(DateTime(-4, 2, 29, 5, 5, 5), msecs(555));
            sysTime.add!"years"(5);
            assert(sysTime == SysTime(DateTime(1, 3, 1, 5, 5, 5), msecs(555)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 2, 29, 5, 5, 5), msecs(555));
            sysTime.add!"years"(-5);
            assert(sysTime == SysTime(DateTime(-1, 3, 1, 5, 5, 5), msecs(555)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 2, 29, 5, 5, 5), msecs(555));
            sysTime.add!"years"(-5).add!"years"(7);
            assert(sysTime == SysTime(DateTime(6, 3, 1, 5, 5, 5), msecs(555)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.add!"years"(4)));
        //static assert(!__traits(compiles, ist.add!"years"(4)));
    }

    // Test add!"years"() with AllowDayOverflow.no
    @safe unittest
    {
        // Test A.D.
        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"years"(7, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2006, 7, 6)));
            sysTime.add!"years"(-9, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1997, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 2, 28));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(2000, 2, 29));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 7, 6, 12, 7, 3), msecs(234));
            sysTime.add!"years"(7, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(2006, 7, 6, 12, 7, 3), msecs(234)));
            sysTime.add!"years"(-9, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1997, 7, 6, 12, 7, 3), msecs(234)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 2, 28, 0, 7, 2), usecs(1207));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(2000, 2, 28, 0, 7, 2), usecs(1207)));
        }

        {
            auto sysTime = SysTime(DateTime(2000, 2, 29, 0, 7, 2), usecs(1207));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 2, 28, 0, 7, 2), usecs(1207)));
        }

        // Test B.C.
        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"years"(-7, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2006, 7, 6)));
            sysTime.add!"years"(9, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 2, 28));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2000, 2, 29));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 7, 6, 12, 7, 3), msecs(234));
            sysTime.add!"years"(-7, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2006, 7, 6, 12, 7, 3), msecs(234)));
            sysTime.add!"years"(9, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1997, 7, 6, 12, 7, 3), msecs(234)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 2, 28, 3, 3, 3), hnsecs(3));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2000, 2, 28, 3, 3, 3), hnsecs(3)));
        }

        {
            auto sysTime = SysTime(DateTime(-2000, 2, 29, 3, 3, 3), hnsecs(3));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1999, 2, 28, 3, 3, 3), hnsecs(3)));
        }

        // Test Both
        {
            auto sysTime = SysTime(Date(4, 7, 6));
            sysTime.add!"years"(-5, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1, 7, 6)));
            sysTime.add!"years"(5, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-4, 7, 6));
            sysTime.add!"years"(5, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1, 7, 6)));
            sysTime.add!"years"(-5, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(4, 7, 6));
            sysTime.add!"years"(-8, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 7, 6)));
            sysTime.add!"years"(8, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-4, 7, 6));
            sysTime.add!"years"(8, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 7, 6)));
            sysTime.add!"years"(-8, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-4, 2, 29));
            sysTime.add!"years"(5, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(4, 2, 29));
            sysTime.add!"years"(-5, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1, 2, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 0, 0, 0)));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 1, 1, 0, 0, 0));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"years"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"years"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 7, 6, 14, 7, 1), usecs(54329));
            sysTime.add!"years"(-5);
            assert(sysTime == SysTime(DateTime(-1, 7, 6, 14, 7, 1), usecs(54329)));
            sysTime.add!"years"(5);
            assert(sysTime == SysTime(DateTime(4, 7, 6, 14, 7, 1), usecs(54329)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 7, 6, 14, 7, 1), usecs(54329));
            sysTime.add!"years"(-5, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1, 7, 6, 14, 7, 1), usecs(54329)));
            sysTime.add!"years"(5, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(4, 7, 6, 14, 7, 1), usecs(54329)));
        }

        {
            auto sysTime = SysTime(DateTime(-4, 7, 6, 14, 7, 1), usecs(54329));
            sysTime.add!"years"(5, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 7, 6, 14, 7, 1), usecs(54329)));
            sysTime.add!"years"(-5, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-4, 7, 6, 14, 7, 1), usecs(54329)));
        }

        {
            auto sysTime = SysTime(DateTime(-4, 2, 29, 5, 5, 5), msecs(555));
            sysTime.add!"years"(5, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 2, 28, 5, 5, 5), msecs(555)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 2, 29, 5, 5, 5), msecs(555));
            sysTime.add!"years"(-5, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1, 2, 28, 5, 5, 5), msecs(555)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 2, 29, 5, 5, 5), msecs(555));
            sysTime.add!"years"(-5, AllowDayOverflow.no).add!"years"(7, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(6, 2, 28, 5, 5, 5), msecs(555)));
        }
    }

    // Test add!"months"() with AllowDayOverflow.yes
    @safe unittest
    {
        // Test A.D.
        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"months"(3);
            assert(sysTime == SysTime(Date(1999, 10, 6)));
            sysTime.add!"months"(-4);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"months"(6);
            assert(sysTime == SysTime(Date(2000, 1, 6)));
            sysTime.add!"months"(-6);
            assert(sysTime == SysTime(Date(1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"months"(27);
            assert(sysTime == SysTime(Date(2001, 10, 6)));
            sysTime.add!"months"(-28);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(Date(1999, 7, 1)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(Date(1999, 5, 1)));
        }

        {
            auto sysTime = SysTime(Date(1999, 2, 28));
            sysTime.add!"months"(12);
            assert(sysTime == SysTime(Date(2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(2000, 2, 29));
            sysTime.add!"months"(12);
            assert(sysTime == SysTime(Date(2001, 3, 1)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 31));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(Date(1999, 8, 31)));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(Date(1999, 10, 1)));
        }

        {
            auto sysTime = SysTime(Date(1998, 8, 31));
            sysTime.add!"months"(13);
            assert(sysTime == SysTime(Date(1999, 10, 1)));
            sysTime.add!"months"(-13);
            assert(sysTime == SysTime(Date(1998, 9, 1)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.add!"months"(13);
            assert(sysTime == SysTime(Date(1999, 1, 31)));
            sysTime.add!"months"(-13);
            assert(sysTime == SysTime(Date(1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(Date(1999, 3, 3)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(Date(1998, 1, 3)));
        }

        {
            auto sysTime = SysTime(Date(1998, 12, 31));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(Date(2000, 3, 2)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(Date(1999, 1, 2)));
        }

        {
            auto sysTime = SysTime(Date(1999, 12, 31));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(Date(2001, 3, 3)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(Date(2000, 1, 3)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 7, 6, 12, 2, 7), usecs(5007));
            sysTime.add!"months"(3);
            assert(sysTime == SysTime(DateTime(1999, 10, 6, 12, 2, 7), usecs(5007)));
            sysTime.add!"months"(-4);
            assert(sysTime == SysTime(DateTime(1999, 6, 6, 12, 2, 7), usecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(1998, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(DateTime(2000, 3, 2, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(DateTime(1999, 1, 2, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(DateTime(2001, 3, 3, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(DateTime(2000, 1, 3, 7, 7, 7), hnsecs(422202)));
        }

        // Test B.C.
        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"months"(3);
            assert(sysTime == SysTime(Date(-1999, 10, 6)));
            sysTime.add!"months"(-4);
            assert(sysTime == SysTime(Date(-1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"months"(6);
            assert(sysTime == SysTime(Date(-1998, 1, 6)));
            sysTime.add!"months"(-6);
            assert(sysTime == SysTime(Date(-1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"months"(-27);
            assert(sysTime == SysTime(Date(-2001, 4, 6)));
            sysTime.add!"months"(28);
            assert(sysTime == SysTime(Date(-1999, 8, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(Date(-1999, 7, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(Date(-1999, 5, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 2, 28));
            sysTime.add!"months"(-12);
            assert(sysTime == SysTime(Date(-2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2000, 2, 29));
            sysTime.add!"months"(-12);
            assert(sysTime == SysTime(Date(-2001, 3, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 31));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(Date(-1999, 8, 31)));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(Date(-1999, 10, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1998, 8, 31));
            sysTime.add!"months"(13);
            assert(sysTime == SysTime(Date(-1997, 10, 1)));
            sysTime.add!"months"(-13);
            assert(sysTime == SysTime(Date(-1998, 9, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.add!"months"(13);
            assert(sysTime == SysTime(Date(-1995, 1, 31)));
            sysTime.add!"months"(-13);
            assert(sysTime == SysTime(Date(-1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(Date(-1995, 3, 3)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(Date(-1996, 1, 3)));
        }

        {
            auto sysTime = SysTime(Date(-2002, 12, 31));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(Date(-2000, 3, 2)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(Date(-2001, 1, 2)));
        }

        {
            auto sysTime = SysTime(Date(-2001, 12, 31));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(Date(-1999, 3, 3)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(Date(-2000, 1, 3)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 7, 6, 12, 2, 7), usecs(5007));
            sysTime.add!"months"(3);
            assert(sysTime == SysTime(DateTime(-1999, 10, 6, 12, 2, 7), usecs(5007)));
            sysTime.add!"months"(-4);
            assert(sysTime == SysTime(DateTime(-1999, 6, 6, 12, 2, 7), usecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(-2002, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(DateTime(-2000, 3, 2, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(DateTime(-2001, 1, 2, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(-2001, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14);
            assert(sysTime == SysTime(DateTime(-1999, 3, 3, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14);
            assert(sysTime == SysTime(DateTime(-2000, 1, 3, 7, 7, 7), hnsecs(422202)));
        }

        // Test Both
        {
            auto sysTime = SysTime(Date(1, 1, 1));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(Date(0, 12, 1)));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(Date(1, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 1, 1));
            sysTime.add!"months"(-48);
            assert(sysTime == SysTime(Date(0, 1, 1)));
            sysTime.add!"months"(48);
            assert(sysTime == SysTime(Date(4, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.add!"months"(-49);
            assert(sysTime == SysTime(Date(0, 3, 2)));
            sysTime.add!"months"(49);
            assert(sysTime == SysTime(Date(4, 4, 2)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.add!"months"(-85);
            assert(sysTime == SysTime(Date(-3, 3, 3)));
            sysTime.add!"months"(85);
            assert(sysTime == SysTime(Date(4, 4, 3)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 0, 0)));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 0, 0, 0));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17));
            sysTime.add!"months"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 7, 9), hnsecs(17)));
            sysTime.add!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 3, 31, 12, 11, 10), msecs(9));
            sysTime.add!"months"(-85);
            assert(sysTime == SysTime(DateTime(-3, 3, 3, 12, 11, 10), msecs(9)));
            sysTime.add!"months"(85);
            assert(sysTime == SysTime(DateTime(4, 4, 3, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.add!"months"(85);
            assert(sysTime == SysTime(DateTime(4, 5, 1, 12, 11, 10), msecs(9)));
            sysTime.add!"months"(-85);
            assert(sysTime == SysTime(DateTime(-3, 4, 1, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.add!"months"(85).add!"months"(-83);
            assert(sysTime == SysTime(DateTime(-3, 6, 1, 12, 11, 10), msecs(9)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.add!"months"(4)));
        //static assert(!__traits(compiles, ist.add!"months"(4)));
    }

    // Test add!"months"() with AllowDayOverflow.no
    @safe unittest
    {
        // Test A.D.
        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 10, 6)));
            sysTime.add!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"months"(6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2000, 1, 6)));
            sysTime.add!"months"(-6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.add!"months"(27, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2001, 10, 6)));
            sysTime.add!"months"(-28, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 6, 30)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 4, 30)));
        }

        {
            auto sysTime = SysTime(Date(1999, 2, 28));
            sysTime.add!"months"(12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(2000, 2, 29));
            sysTime.add!"months"(12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2001, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 31));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 8, 31)));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 9, 30)));
        }

        {
            auto sysTime = SysTime(Date(1998, 8, 31));
            sysTime.add!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 9, 30)));
            sysTime.add!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1998, 8, 30)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.add!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 1, 31)));
            sysTime.add!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 2, 28)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1997, 12, 28)));
        }

        {
            auto sysTime = SysTime(Date(1998, 12, 31));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2000, 2, 29)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1998, 12, 29)));
        }

        {
            auto sysTime = SysTime(Date(1999, 12, 31));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2001, 2, 28)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 12, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 7, 6, 12, 2, 7), usecs(5007));
            sysTime.add!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 10, 6, 12, 2, 7), usecs(5007)));
            sysTime.add!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 6, 6, 12, 2, 7), usecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(1998, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(2000, 2, 29, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1998, 12, 29, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(2001, 2, 28, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 12, 28, 7, 7, 7), hnsecs(422202)));
        }

        // Test B.C.
        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 10, 6)));
            sysTime.add!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"months"(6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1998, 1, 6)));
            sysTime.add!"months"(-6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.add!"months"(-27, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2001, 4, 6)));
            sysTime.add!"months"(28, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 8, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 6, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 4, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 2, 28));
            sysTime.add!"months"(-12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2000, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2000, 2, 29));
            sysTime.add!"months"(-12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2001, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 31));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 8, 31)));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 9, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1998, 8, 31));
            sysTime.add!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 9, 30)));
            sysTime.add!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1998, 8, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.add!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1995, 1, 31)));
            sysTime.add!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1995, 2, 28)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 12, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2002, 12, 31));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2000, 2, 29)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2002, 12, 29)));
        }

        {
            auto sysTime = SysTime(Date(-2001, 12, 31));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 2, 28)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2001, 12, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 7, 6, 12, 2, 7), usecs(5007));
            sysTime.add!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1999, 10, 6, 12, 2, 7), usecs(5007)));
            sysTime.add!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1999, 6, 6, 12, 2, 7), usecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(-2002, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2000, 2, 29, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2002, 12, 29, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(-2001, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.add!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1999, 2, 28, 7, 7, 7), hnsecs(422202)));
            sysTime.add!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2001, 12, 28, 7, 7, 7), hnsecs(422202)));
        }

        // Test Both
        {
            auto sysTime = SysTime(Date(1, 1, 1));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(0, 12, 1)));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 1, 1));
            sysTime.add!"months"(-48, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(0, 1, 1)));
            sysTime.add!"months"(48, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.add!"months"(-49, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(0, 2, 29)));
            sysTime.add!"months"(49, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 3, 29)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.add!"months"(-85, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-3, 2, 28)));
            sysTime.add!"months"(85, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 3, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 0, 0)));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 0, 0, 0));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17));
            sysTime.add!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 7, 9), hnsecs(17)));
            sysTime.add!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 3, 31, 12, 11, 10), msecs(9));
            sysTime.add!"months"(-85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-3, 2, 28, 12, 11, 10), msecs(9)));
            sysTime.add!"months"(85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(4, 3, 28, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.add!"months"(85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(4, 4, 30, 12, 11, 10), msecs(9)));
            sysTime.add!"months"(-85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-3, 3, 30, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.add!"months"(85, AllowDayOverflow.no).add!"months"(-83, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-3, 5, 30, 12, 11, 10), msecs(9)));
        }
    }


    /++
        Adds the given number of years or months to this $(LREF SysTime). A
        negative number will subtract.

        The difference between rolling and adding is that rolling does not
        affect larger units. Rolling a $(LREF SysTime) 12 months
        gets the exact same $(LREF SysTime). However, the days can still be affected
        due to the differing number of days in each month.

        Because there are no units larger than years, there is no difference
        between adding and rolling years.

        Params:
            units         = The type of units to add ("years" or "months").
            value         = The number of months or years to add to this
                            $(LREF SysTime).
            allowOverflow = Whether the days should be allowed to overflow,
                            causing the month to increment.
      +/
    ref SysTime roll(string units)(long value, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe nothrow
        if (units == "years")
    {
        return add!"years"(value, allowOverflow);
    }

    ///
    @safe unittest
    {
        auto st1 = SysTime(DateTime(2010, 1, 1, 12, 33, 33));
        st1.roll!"months"(1);
        assert(st1 == SysTime(DateTime(2010, 2, 1, 12, 33, 33)));

        auto st2 = SysTime(DateTime(2010, 1, 1, 12, 33, 33));
        st2.roll!"months"(-1);
        assert(st2 == SysTime(DateTime(2010, 12, 1, 12, 33, 33)));

        auto st3 = SysTime(DateTime(1999, 1, 29, 12, 33, 33));
        st3.roll!"months"(1);
        assert(st3 == SysTime(DateTime(1999, 3, 1, 12, 33, 33)));

        auto st4 = SysTime(DateTime(1999, 1, 29, 12, 33, 33));
        st4.roll!"months"(1, AllowDayOverflow.no);
        assert(st4 == SysTime(DateTime(1999, 2, 28, 12, 33, 33)));

        auto st5 = SysTime(DateTime(2000, 2, 29, 12, 30, 33));
        st5.roll!"years"(1);
        assert(st5 == SysTime(DateTime(2001, 3, 1, 12, 30, 33)));

        auto st6 = SysTime(DateTime(2000, 2, 29, 12, 30, 33));
        st6.roll!"years"(1, AllowDayOverflow.no);
        assert(st6 == SysTime(DateTime(2001, 2, 28, 12, 30, 33)));
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        st.roll!"years"(4);
        static assert(!__traits(compiles, cst.roll!"years"(4)));
        //static assert(!__traits(compiles, ist.roll!"years"(4)));
    }


    // Shares documentation with "years" overload.
    ref SysTime roll(string units)(long value, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe nothrow
        if (units == "months")
    {
        auto hnsecs = adjTime;
        auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --days;
        }

        auto date = Date(cast(int) days);
        date.roll!"months"(value, allowOverflow);
        days = date.dayOfGregorianCal - 1;

        if (days < 0)
        {
            hnsecs -= convert!("hours", "hnsecs")(24);
            ++days;
        }

        immutable newDaysHNSecs = convert!("days", "hnsecs")(days);
        adjTime = newDaysHNSecs + hnsecs;
        return this;
    }

    // Test roll!"months"() with AllowDayOverflow.yes
    @safe unittest
    {
        // Test A.D.
        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"months"(3);
            assert(sysTime == SysTime(Date(1999, 10, 6)));
            sysTime.roll!"months"(-4);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"months"(6);
            assert(sysTime == SysTime(Date(1999, 1, 6)));
            sysTime.roll!"months"(-6);
            assert(sysTime == SysTime(Date(1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"months"(27);
            assert(sysTime == SysTime(Date(1999, 10, 6)));
            sysTime.roll!"months"(-28);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(1999, 7, 1)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(Date(1999, 5, 1)));
        }

        {
            auto sysTime = SysTime(Date(1999, 2, 28));
            sysTime.roll!"months"(12);
            assert(sysTime == SysTime(Date(1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(2000, 2, 29));
            sysTime.roll!"months"(12);
            assert(sysTime == SysTime(Date(2000, 2, 29)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 31));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(1999, 8, 31)));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(1999, 10, 1)));
        }

        {
            auto sysTime = SysTime(Date(1998, 8, 31));
            sysTime.roll!"months"(13);
            assert(sysTime == SysTime(Date(1998, 10, 1)));
            sysTime.roll!"months"(-13);
            assert(sysTime == SysTime(Date(1998, 9, 1)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.roll!"months"(13);
            assert(sysTime == SysTime(Date(1997, 1, 31)));
            sysTime.roll!"months"(-13);
            assert(sysTime == SysTime(Date(1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(Date(1997, 3, 3)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(Date(1997, 1, 3)));
        }

        {
            auto sysTime = SysTime(Date(1998, 12, 31));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(Date(1998, 3, 3)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(Date(1998, 1, 3)));
        }

        {
            auto sysTime = SysTime(Date(1999, 12, 31));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(Date(1999, 3, 3)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(Date(1999, 1, 3)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 7, 6, 12, 2, 7), usecs(5007));
            sysTime.roll!"months"(3);
            assert(sysTime == SysTime(DateTime(1999, 10, 6, 12, 2, 7), usecs(5007)));
            sysTime.roll!"months"(-4);
            assert(sysTime == SysTime(DateTime(1999, 6, 6, 12, 2, 7), usecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(1998, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(DateTime(1998, 3, 3, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(DateTime(1998, 1, 3, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(DateTime(1999, 3, 3, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(DateTime(1999, 1, 3, 7, 7, 7), hnsecs(422202)));
        }

        // Test B.C.
        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"months"(3);
            assert(sysTime == SysTime(Date(-1999, 10, 6)));
            sysTime.roll!"months"(-4);
            assert(sysTime == SysTime(Date(-1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"months"(6);
            assert(sysTime == SysTime(Date(-1999, 1, 6)));
            sysTime.roll!"months"(-6);
            assert(sysTime == SysTime(Date(-1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"months"(-27);
            assert(sysTime == SysTime(Date(-1999, 4, 6)));
            sysTime.roll!"months"(28);
            assert(sysTime == SysTime(Date(-1999, 8, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(-1999, 7, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(Date(-1999, 5, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 2, 28));
            sysTime.roll!"months"(-12);
            assert(sysTime == SysTime(Date(-1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2000, 2, 29));
            sysTime.roll!"months"(-12);
            assert(sysTime == SysTime(Date(-2000, 2, 29)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 31));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(-1999, 8, 31)));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(-1999, 10, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1998, 8, 31));
            sysTime.roll!"months"(13);
            assert(sysTime == SysTime(Date(-1998, 10, 1)));
            sysTime.roll!"months"(-13);
            assert(sysTime == SysTime(Date(-1998, 9, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.roll!"months"(13);
            assert(sysTime == SysTime(Date(-1997, 1, 31)));
            sysTime.roll!"months"(-13);
            assert(sysTime == SysTime(Date(-1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(Date(-1997, 3, 3)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(Date(-1997, 1, 3)));
        }

        {
            auto sysTime = SysTime(Date(-2002, 12, 31));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(Date(-2002, 3, 3)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(Date(-2002, 1, 3)));
        }

        {
            auto sysTime = SysTime(Date(-2001, 12, 31));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(Date(-2001, 3, 3)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(Date(-2001, 1, 3)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(DateTime(1, 12, 1, 0, 0, 0)));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(DateTime(1, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 0, 0, 0));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 0, 0, 0)));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 7, 6, 12, 2, 7), hnsecs(5007));
            sysTime.roll!"months"(3);
            assert(sysTime == SysTime(DateTime(-1999, 10, 6, 12, 2, 7), hnsecs(5007)));
            sysTime.roll!"months"(-4);
            assert(sysTime == SysTime(DateTime(-1999, 6, 6, 12, 2, 7), hnsecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(-2002, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(DateTime(-2002, 3, 3, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(DateTime(-2002, 1, 3, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(-2001, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14);
            assert(sysTime == SysTime(DateTime(-2001, 3, 3, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14);
            assert(sysTime == SysTime(DateTime(-2001, 1, 3, 7, 7, 7), hnsecs(422202)));
        }

        // Test Both
        {
            auto sysTime = SysTime(Date(1, 1, 1));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(Date(1, 12, 1)));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(1, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 1, 1));
            sysTime.roll!"months"(-48);
            assert(sysTime == SysTime(Date(4, 1, 1)));
            sysTime.roll!"months"(48);
            assert(sysTime == SysTime(Date(4, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.roll!"months"(-49);
            assert(sysTime == SysTime(Date(4, 3, 2)));
            sysTime.roll!"months"(49);
            assert(sysTime == SysTime(Date(4, 4, 2)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.roll!"months"(-85);
            assert(sysTime == SysTime(Date(4, 3, 2)));
            sysTime.roll!"months"(85);
            assert(sysTime == SysTime(Date(4, 4, 2)));
        }

        {
            auto sysTime = SysTime(Date(-1, 1, 1));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(Date(-1, 12, 1)));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(Date(-1, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(-4, 1, 1));
            sysTime.roll!"months"(-48);
            assert(sysTime == SysTime(Date(-4, 1, 1)));
            sysTime.roll!"months"(48);
            assert(sysTime == SysTime(Date(-4, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(-4, 3, 31));
            sysTime.roll!"months"(-49);
            assert(sysTime == SysTime(Date(-4, 3, 2)));
            sysTime.roll!"months"(49);
            assert(sysTime == SysTime(Date(-4, 4, 2)));
        }

        {
            auto sysTime = SysTime(Date(-4, 3, 31));
            sysTime.roll!"months"(-85);
            assert(sysTime == SysTime(Date(-4, 3, 2)));
            sysTime.roll!"months"(85);
            assert(sysTime == SysTime(Date(-4, 4, 2)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17));
            sysTime.roll!"months"(-1);
            assert(sysTime == SysTime(DateTime(1, 12, 1, 0, 7, 9), hnsecs(17)));
            sysTime.roll!"months"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 3, 31, 12, 11, 10), msecs(9));
            sysTime.roll!"months"(-85);
            assert(sysTime == SysTime(DateTime(4, 3, 2, 12, 11, 10), msecs(9)));
            sysTime.roll!"months"(85);
            assert(sysTime == SysTime(DateTime(4, 4, 2, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.roll!"months"(85);
            assert(sysTime == SysTime(DateTime(-3, 5, 1, 12, 11, 10), msecs(9)));
            sysTime.roll!"months"(-85);
            assert(sysTime == SysTime(DateTime(-3, 4, 1, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.roll!"months"(85).roll!"months"(-83);
            assert(sysTime == SysTime(DateTime(-3, 6, 1, 12, 11, 10), msecs(9)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.roll!"months"(4)));
        //static assert(!__traits(compiles, ist.roll!"months"(4)));
    }

    // Test roll!"months"() with AllowDayOverflow.no
    @safe unittest
    {
        // Test A.D.
        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 10, 6)));
            sysTime.roll!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"months"(6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 1, 6)));
            sysTime.roll!"months"(-6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"months"(27, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 10, 6)));
            sysTime.roll!"months"(-28, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 6, 30)));
        }

        {
            auto sysTime = SysTime(Date(1999, 5, 31));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 4, 30)));
        }

        {
            auto sysTime = SysTime(Date(1999, 2, 28));
            sysTime.roll!"months"(12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(2000, 2, 29));
            sysTime.roll!"months"(12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(2000, 2, 29)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 31));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 8, 31)));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 9, 30)));
        }

        {
            auto sysTime = SysTime(Date(1998, 8, 31));
            sysTime.roll!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1998, 9, 30)));
            sysTime.roll!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1998, 8, 30)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.roll!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1997, 1, 31)));
            sysTime.roll!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(1997, 12, 31));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1997, 2, 28)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1997, 12, 28)));
        }

        {
            auto sysTime = SysTime(Date(1998, 12, 31));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1998, 2, 28)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1998, 12, 28)));
        }

        {
            auto sysTime = SysTime(Date(1999, 12, 31));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 2, 28)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1999, 12, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 7, 6, 12, 2, 7), usecs(5007));
            sysTime.roll!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 10, 6, 12, 2, 7), usecs(5007)));
            sysTime.roll!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 6, 6, 12, 2, 7), usecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(1998, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1998, 2, 28, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1998, 12, 28, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 2, 28, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1999, 12, 28, 7, 7, 7), hnsecs(422202)));
        }

        // Test B.C.
        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 10, 6)));
            sysTime.roll!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 6, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"months"(6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 1, 6)));
            sysTime.roll!"months"(-6, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"months"(-27, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 4, 6)));
            sysTime.roll!"months"(28, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 8, 6)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 6, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 5, 31));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 4, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 2, 28));
            sysTime.roll!"months"(-12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2000, 2, 29));
            sysTime.roll!"months"(-12, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2000, 2, 29)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 31));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 8, 31)));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1999, 9, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1998, 8, 31));
            sysTime.roll!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1998, 9, 30)));
            sysTime.roll!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1998, 8, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.roll!"months"(13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 1, 31)));
            sysTime.roll!"months"(-13, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 12, 31)));
        }

        {
            auto sysTime = SysTime(Date(-1997, 12, 31));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 2, 28)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1997, 12, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2002, 12, 31));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2002, 2, 28)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2002, 12, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2001, 12, 31));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2001, 2, 28)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-2001, 12, 28)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 7, 6, 12, 2, 7), usecs(5007));
            sysTime.roll!"months"(3, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1999, 10, 6, 12, 2, 7), usecs(5007)));
            sysTime.roll!"months"(-4, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-1999, 6, 6, 12, 2, 7), usecs(5007)));
        }

        {
            auto sysTime = SysTime(DateTime(-2002, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2002, 2, 28, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2002, 12, 28, 7, 7, 7), hnsecs(422202)));
        }

        {
            auto sysTime = SysTime(DateTime(-2001, 12, 31, 7, 7, 7), hnsecs(422202));
            sysTime.roll!"months"(14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2001, 2, 28, 7, 7, 7), hnsecs(422202)));
            sysTime.roll!"months"(-14, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-2001, 12, 28, 7, 7, 7), hnsecs(422202)));
        }

        // Test Both
        {
            auto sysTime = SysTime(Date(1, 1, 1));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1, 12, 1)));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(1, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 1, 1));
            sysTime.roll!"months"(-48, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 1, 1)));
            sysTime.roll!"months"(48, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.roll!"months"(-49, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 2, 29)));
            sysTime.roll!"months"(49, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 3, 29)));
        }

        {
            auto sysTime = SysTime(Date(4, 3, 31));
            sysTime.roll!"months"(-85, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 2, 29)));
            sysTime.roll!"months"(85, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(4, 3, 29)));
        }

        {
            auto sysTime = SysTime(Date(-1, 1, 1));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1, 12, 1)));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-1, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(-4, 1, 1));
            sysTime.roll!"months"(-48, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 1, 1)));
            sysTime.roll!"months"(48, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(-4, 3, 31));
            sysTime.roll!"months"(-49, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 2, 29)));
            sysTime.roll!"months"(49, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 3, 29)));
        }

        {
            auto sysTime = SysTime(Date(-4, 3, 31));
            sysTime.roll!"months"(-85, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 2, 29)));
            sysTime.roll!"months"(85, AllowDayOverflow.no);
            assert(sysTime == SysTime(Date(-4, 3, 29)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 12, 1, 0, 0, 0)));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 0, 0, 0));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 0, 0, 0)));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17));
            sysTime.roll!"months"(-1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 12, 1, 0, 7, 9), hnsecs(17)));
            sysTime.roll!"months"(1, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 7, 9), hnsecs(17)));
        }

        {
            auto sysTime = SysTime(DateTime(4, 3, 31, 12, 11, 10), msecs(9));
            sysTime.roll!"months"(-85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(4, 2, 29, 12, 11, 10), msecs(9)));
            sysTime.roll!"months"(85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(4, 3, 29, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.roll!"months"(85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-3, 4, 30, 12, 11, 10), msecs(9)));
            sysTime.roll!"months"(-85, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-3, 3, 30, 12, 11, 10), msecs(9)));
        }

        {
            auto sysTime = SysTime(DateTime(-3, 3, 31, 12, 11, 10), msecs(9));
            sysTime.roll!"months"(85, AllowDayOverflow.no).roll!"months"(-83, AllowDayOverflow.no);
            assert(sysTime == SysTime(DateTime(-3, 5, 30, 12, 11, 10), msecs(9)));
        }
    }


    /++
        Adds the given number of units to this $(LREF SysTime). A negative number
        will subtract.

        The difference between rolling and adding is that rolling does not
        affect larger units. For instance, rolling a $(LREF SysTime) one
        year's worth of days gets the exact same $(LREF SysTime).

        Accepted units are $(D "days"), $(D "minutes"), $(D "hours"),
        $(D "minutes"), $(D "seconds"), $(D "msecs"), $(D "usecs"), and
        $(D "hnsecs").

        Note that when rolling msecs, usecs or hnsecs, they all add up to a
        second. So, for example, rolling 1000 msecs is exactly the same as
        rolling 100,000 usecs.

        Params:
            units = The units to add.
            value = The number of $(D_PARAM units) to add to this $(LREF SysTime).
      +/
    ref SysTime roll(string units)(long value) @safe nothrow
        if (units == "days")
    {
        auto hnsecs = adjTime;
        auto gdays = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

        if (hnsecs < 0)
        {
            hnsecs += convert!("hours", "hnsecs")(24);
            --gdays;
        }

        auto date = Date(cast(int) gdays);
        date.roll!"days"(value);
        gdays = date.dayOfGregorianCal - 1;

        if (gdays < 0)
        {
            hnsecs -= convert!("hours", "hnsecs")(24);
            ++gdays;
        }

        immutable newDaysHNSecs = convert!("days", "hnsecs")(gdays);
        adjTime = newDaysHNSecs + hnsecs;
        return  this;
    }

    ///
    @safe unittest
    {
        auto st1 = SysTime(DateTime(2010, 1, 1, 11, 23, 12));
        st1.roll!"days"(1);
        assert(st1 == SysTime(DateTime(2010, 1, 2, 11, 23, 12)));
        st1.roll!"days"(365);
        assert(st1 == SysTime(DateTime(2010, 1, 26, 11, 23, 12)));
        st1.roll!"days"(-32);
        assert(st1 == SysTime(DateTime(2010, 1, 25, 11, 23, 12)));

        auto st2 = SysTime(DateTime(2010, 7, 4, 12, 0, 0));
        st2.roll!"hours"(1);
        assert(st2 == SysTime(DateTime(2010, 7, 4, 13, 0, 0)));

        auto st3 = SysTime(DateTime(2010, 2, 12, 12, 0, 0));
        st3.roll!"hours"(-1);
        assert(st3 == SysTime(DateTime(2010, 2, 12, 11, 0, 0)));

        auto st4 = SysTime(DateTime(2009, 12, 31, 0, 0, 0));
        st4.roll!"minutes"(1);
        assert(st4 == SysTime(DateTime(2009, 12, 31, 0, 1, 0)));

        auto st5 = SysTime(DateTime(2010, 1, 1, 0, 0, 0));
        st5.roll!"minutes"(-1);
        assert(st5 == SysTime(DateTime(2010, 1, 1, 0, 59, 0)));

        auto st6 = SysTime(DateTime(2009, 12, 31, 0, 0, 0));
        st6.roll!"seconds"(1);
        assert(st6 == SysTime(DateTime(2009, 12, 31, 0, 0, 1)));

        auto st7 = SysTime(DateTime(2010, 1, 1, 0, 0, 0));
        st7.roll!"seconds"(-1);
        assert(st7 == SysTime(DateTime(2010, 1, 1, 0, 0, 59)));

        auto dt = DateTime(2010, 1, 1, 0, 0, 0);
        auto st8 = SysTime(dt);
        st8.roll!"msecs"(1);
        assert(st8 == SysTime(dt, msecs(1)));

        auto st9 = SysTime(dt);
        st9.roll!"msecs"(-1);
        assert(st9 == SysTime(dt, msecs(999)));

        auto st10 = SysTime(dt);
        st10.roll!"hnsecs"(1);
        assert(st10 == SysTime(dt, hnsecs(1)));

        auto st11 = SysTime(dt);
        st11.roll!"hnsecs"(-1);
        assert(st11 == SysTime(dt, hnsecs(9_999_999)));
    }

    @safe unittest
    {
        // Test A.D.
        {
            auto sysTime = SysTime(Date(1999, 2, 28));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(1999, 2, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(2000, 2, 28));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(2000, 2, 29)));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(2000, 2, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(2000, 2, 29)));
        }

        {
            auto sysTime = SysTime(Date(1999, 6, 30));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(1999, 6, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(1999, 6, 30)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 31));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(1999, 7, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(1999, 7, 31)));
        }

        {
            auto sysTime = SysTime(Date(1999, 1, 1));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(1999, 1, 31)));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(1999, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"days"(9);
            assert(sysTime == SysTime(Date(1999, 7, 15)));
            sysTime.roll!"days"(-11);
            assert(sysTime == SysTime(Date(1999, 7, 4)));
            sysTime.roll!"days"(30);
            assert(sysTime == SysTime(Date(1999, 7, 3)));
            sysTime.roll!"days"(-3);
            assert(sysTime == SysTime(Date(1999, 7, 31)));
        }

        {
            auto sysTime = SysTime(Date(1999, 7, 6));
            sysTime.roll!"days"(365);
            assert(sysTime == SysTime(Date(1999, 7, 30)));
            sysTime.roll!"days"(-365);
            assert(sysTime == SysTime(Date(1999, 7, 6)));
            sysTime.roll!"days"(366);
            assert(sysTime == SysTime(Date(1999, 7, 31)));
            sysTime.roll!"days"(730);
            assert(sysTime == SysTime(Date(1999, 7, 17)));
            sysTime.roll!"days"(-1096);
            assert(sysTime == SysTime(Date(1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(Date(1999, 2, 6));
            sysTime.roll!"days"(365);
            assert(sysTime == SysTime(Date(1999, 2, 7)));
            sysTime.roll!"days"(-365);
            assert(sysTime == SysTime(Date(1999, 2, 6)));
            sysTime.roll!"days"(366);
            assert(sysTime == SysTime(Date(1999, 2, 8)));
            sysTime.roll!"days"(730);
            assert(sysTime == SysTime(Date(1999, 2, 10)));
            sysTime.roll!"days"(-1096);
            assert(sysTime == SysTime(Date(1999, 2, 6)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 2, 28, 7, 9, 2), usecs(234578));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(DateTime(1999, 2, 1, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(DateTime(1999, 2, 28, 7, 9, 2), usecs(234578)));
        }

        {
            auto sysTime = SysTime(DateTime(1999, 7, 6, 7, 9, 2), usecs(234578));
            sysTime.roll!"days"(9);
            assert(sysTime == SysTime(DateTime(1999, 7, 15, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(-11);
            assert(sysTime == SysTime(DateTime(1999, 7, 4, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(30);
            assert(sysTime == SysTime(DateTime(1999, 7, 3, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(-3);
            assert(sysTime == SysTime(DateTime(1999, 7, 31, 7, 9, 2), usecs(234578)));
        }

        // Test B.C.
        {
            auto sysTime = SysTime(Date(-1999, 2, 28));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(-1999, 2, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(-1999, 2, 28)));
        }

        {
            auto sysTime = SysTime(Date(-2000, 2, 28));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(-2000, 2, 29)));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(-2000, 2, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(-2000, 2, 29)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 6, 30));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(-1999, 6, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(-1999, 6, 30)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 31));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(-1999, 7, 1)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(-1999, 7, 31)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 1, 1));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(Date(-1999, 1, 31)));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(Date(-1999, 1, 1)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"days"(9);
            assert(sysTime == SysTime(Date(-1999, 7, 15)));
            sysTime.roll!"days"(-11);
            assert(sysTime == SysTime(Date(-1999, 7, 4)));
            sysTime.roll!"days"(30);
            assert(sysTime == SysTime(Date(-1999, 7, 3)));
            sysTime.roll!"days"(-3);
            assert(sysTime == SysTime(Date(-1999, 7, 31)));
        }

        {
            auto sysTime = SysTime(Date(-1999, 7, 6));
            sysTime.roll!"days"(365);
            assert(sysTime == SysTime(Date(-1999, 7, 30)));
            sysTime.roll!"days"(-365);
            assert(sysTime == SysTime(Date(-1999, 7, 6)));
            sysTime.roll!"days"(366);
            assert(sysTime == SysTime(Date(-1999, 7, 31)));
            sysTime.roll!"days"(730);
            assert(sysTime == SysTime(Date(-1999, 7, 17)));
            sysTime.roll!"days"(-1096);
            assert(sysTime == SysTime(Date(-1999, 7, 6)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 2, 28, 7, 9, 2), usecs(234578));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(DateTime(-1999, 2, 1, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(DateTime(-1999, 2, 28, 7, 9, 2), usecs(234578)));
        }

        {
            auto sysTime = SysTime(DateTime(-1999, 7, 6, 7, 9, 2), usecs(234578));
            sysTime.roll!"days"(9);
            assert(sysTime == SysTime(DateTime(-1999, 7, 15, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(-11);
            assert(sysTime == SysTime(DateTime(-1999, 7, 4, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(30);
            assert(sysTime == SysTime(DateTime(-1999, 7, 3, 7, 9, 2), usecs(234578)));
            sysTime.roll!"days"(-3);
        }

        // Test Both
        {
            auto sysTime = SysTime(Date(1, 7, 6));
            sysTime.roll!"days"(-365);
            assert(sysTime == SysTime(Date(1, 7, 13)));
            sysTime.roll!"days"(365);
            assert(sysTime == SysTime(Date(1, 7, 6)));
            sysTime.roll!"days"(-731);
            assert(sysTime == SysTime(Date(1, 7, 19)));
            sysTime.roll!"days"(730);
            assert(sysTime == SysTime(Date(1, 7, 5)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 31, 0, 0, 0)));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 31, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 0, 0, 0));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 0, 0, 0)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"days"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"days"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 7, 6, 13, 13, 9), msecs(22));
            sysTime.roll!"days"(-365);
            assert(sysTime == SysTime(DateTime(1, 7, 13, 13, 13, 9), msecs(22)));
            sysTime.roll!"days"(365);
            assert(sysTime == SysTime(DateTime(1, 7, 6, 13, 13, 9), msecs(22)));
            sysTime.roll!"days"(-731);
            assert(sysTime == SysTime(DateTime(1, 7, 19, 13, 13, 9), msecs(22)));
            sysTime.roll!"days"(730);
            assert(sysTime == SysTime(DateTime(1, 7, 5, 13, 13, 9), msecs(22)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 7, 6, 13, 13, 9), msecs(22));
            sysTime.roll!"days"(-365);
            assert(sysTime == SysTime(DateTime(0, 7, 13, 13, 13, 9), msecs(22)));
            sysTime.roll!"days"(365);
            assert(sysTime == SysTime(DateTime(0, 7, 6, 13, 13, 9), msecs(22)));
            sysTime.roll!"days"(-731);
            assert(sysTime == SysTime(DateTime(0, 7, 19, 13, 13, 9), msecs(22)));
            sysTime.roll!"days"(730);
            assert(sysTime == SysTime(DateTime(0, 7, 5, 13, 13, 9), msecs(22)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 7, 6, 13, 13, 9), msecs(22));
            sysTime.roll!"days"(-365).roll!"days"(362).roll!"days"(-12).roll!"days"(730);
            assert(sysTime == SysTime(DateTime(0, 7, 8, 13, 13, 9), msecs(22)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.roll!"days"(4)));
        //static assert(!__traits(compiles, ist.roll!"days"(4)));
    }


    // Shares documentation with "days" version.
    ref SysTime roll(string units)(long value) @safe nothrow
        if (units == "hours" || units == "minutes" || units == "seconds")
    {
        try
        {
            auto hnsecs = adjTime;
            auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

            if (hnsecs < 0)
            {
                hnsecs += convert!("hours", "hnsecs")(24);
                --days;
            }

            immutable hour = splitUnitsFromHNSecs!"hours"(hnsecs);
            immutable minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
            immutable second = splitUnitsFromHNSecs!"seconds"(hnsecs);

            auto dateTime = DateTime(Date(cast(int) days), TimeOfDay(cast(int) hour,
                                          cast(int) minute, cast(int) second));
            dateTime.roll!units(value);
            --days;

            hnsecs += convert!("hours", "hnsecs")(dateTime.hour);
            hnsecs += convert!("minutes", "hnsecs")(dateTime.minute);
            hnsecs += convert!("seconds", "hnsecs")(dateTime.second);

            if (days < 0)
            {
                hnsecs -= convert!("hours", "hnsecs")(24);
                ++days;
            }

            immutable newDaysHNSecs = convert!("days", "hnsecs")(days);
            adjTime = newDaysHNSecs + hnsecs;
            return this;
        }
        catch (Exception e)
            assert(0, "Either DateTime's constructor or TimeOfDay's constructor threw.");
    }

    // Test roll!"hours"().
    @safe unittest
    {
        static void testST(SysTime orig, int hours, in SysTime expected, size_t line = __LINE__)
        {
            orig.roll!"hours"(hours);
            if (orig != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
        }

        // Test A.D.
        immutable d = msecs(45);
        auto beforeAD = SysTime(DateTime(1999, 7, 6, 12, 30, 33), d);
        testST(beforeAD, 0, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 1, SysTime(DateTime(1999, 7, 6, 13, 30, 33), d));
        testST(beforeAD, 2, SysTime(DateTime(1999, 7, 6, 14, 30, 33), d));
        testST(beforeAD, 3, SysTime(DateTime(1999, 7, 6, 15, 30, 33), d));
        testST(beforeAD, 4, SysTime(DateTime(1999, 7, 6, 16, 30, 33), d));
        testST(beforeAD, 5, SysTime(DateTime(1999, 7, 6, 17, 30, 33), d));
        testST(beforeAD, 6, SysTime(DateTime(1999, 7, 6, 18, 30, 33), d));
        testST(beforeAD, 7, SysTime(DateTime(1999, 7, 6, 19, 30, 33), d));
        testST(beforeAD, 8, SysTime(DateTime(1999, 7, 6, 20, 30, 33), d));
        testST(beforeAD, 9, SysTime(DateTime(1999, 7, 6, 21, 30, 33), d));
        testST(beforeAD, 10, SysTime(DateTime(1999, 7, 6, 22, 30, 33), d));
        testST(beforeAD, 11, SysTime(DateTime(1999, 7, 6, 23, 30, 33), d));
        testST(beforeAD, 12, SysTime(DateTime(1999, 7, 6, 0, 30, 33), d));
        testST(beforeAD, 13, SysTime(DateTime(1999, 7, 6, 1, 30, 33), d));
        testST(beforeAD, 14, SysTime(DateTime(1999, 7, 6, 2, 30, 33), d));
        testST(beforeAD, 15, SysTime(DateTime(1999, 7, 6, 3, 30, 33), d));
        testST(beforeAD, 16, SysTime(DateTime(1999, 7, 6, 4, 30, 33), d));
        testST(beforeAD, 17, SysTime(DateTime(1999, 7, 6, 5, 30, 33), d));
        testST(beforeAD, 18, SysTime(DateTime(1999, 7, 6, 6, 30, 33), d));
        testST(beforeAD, 19, SysTime(DateTime(1999, 7, 6, 7, 30, 33), d));
        testST(beforeAD, 20, SysTime(DateTime(1999, 7, 6, 8, 30, 33), d));
        testST(beforeAD, 21, SysTime(DateTime(1999, 7, 6, 9, 30, 33), d));
        testST(beforeAD, 22, SysTime(DateTime(1999, 7, 6, 10, 30, 33), d));
        testST(beforeAD, 23, SysTime(DateTime(1999, 7, 6, 11, 30, 33), d));
        testST(beforeAD, 24, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 25, SysTime(DateTime(1999, 7, 6, 13, 30, 33), d));
        testST(beforeAD, 50, SysTime(DateTime(1999, 7, 6, 14, 30, 33), d));
        testST(beforeAD, 10_000, SysTime(DateTime(1999, 7, 6, 4, 30, 33), d));

        testST(beforeAD, -1, SysTime(DateTime(1999, 7, 6, 11, 30, 33), d));
        testST(beforeAD, -2, SysTime(DateTime(1999, 7, 6, 10, 30, 33), d));
        testST(beforeAD, -3, SysTime(DateTime(1999, 7, 6, 9, 30, 33), d));
        testST(beforeAD, -4, SysTime(DateTime(1999, 7, 6, 8, 30, 33), d));
        testST(beforeAD, -5, SysTime(DateTime(1999, 7, 6, 7, 30, 33), d));
        testST(beforeAD, -6, SysTime(DateTime(1999, 7, 6, 6, 30, 33), d));
        testST(beforeAD, -7, SysTime(DateTime(1999, 7, 6, 5, 30, 33), d));
        testST(beforeAD, -8, SysTime(DateTime(1999, 7, 6, 4, 30, 33), d));
        testST(beforeAD, -9, SysTime(DateTime(1999, 7, 6, 3, 30, 33), d));
        testST(beforeAD, -10, SysTime(DateTime(1999, 7, 6, 2, 30, 33), d));
        testST(beforeAD, -11, SysTime(DateTime(1999, 7, 6, 1, 30, 33), d));
        testST(beforeAD, -12, SysTime(DateTime(1999, 7, 6, 0, 30, 33), d));
        testST(beforeAD, -13, SysTime(DateTime(1999, 7, 6, 23, 30, 33), d));
        testST(beforeAD, -14, SysTime(DateTime(1999, 7, 6, 22, 30, 33), d));
        testST(beforeAD, -15, SysTime(DateTime(1999, 7, 6, 21, 30, 33), d));
        testST(beforeAD, -16, SysTime(DateTime(1999, 7, 6, 20, 30, 33), d));
        testST(beforeAD, -17, SysTime(DateTime(1999, 7, 6, 19, 30, 33), d));
        testST(beforeAD, -18, SysTime(DateTime(1999, 7, 6, 18, 30, 33), d));
        testST(beforeAD, -19, SysTime(DateTime(1999, 7, 6, 17, 30, 33), d));
        testST(beforeAD, -20, SysTime(DateTime(1999, 7, 6, 16, 30, 33), d));
        testST(beforeAD, -21, SysTime(DateTime(1999, 7, 6, 15, 30, 33), d));
        testST(beforeAD, -22, SysTime(DateTime(1999, 7, 6, 14, 30, 33), d));
        testST(beforeAD, -23, SysTime(DateTime(1999, 7, 6, 13, 30, 33), d));
        testST(beforeAD, -24, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, -25, SysTime(DateTime(1999, 7, 6, 11, 30, 33), d));
        testST(beforeAD, -50, SysTime(DateTime(1999, 7, 6, 10, 30, 33), d));
        testST(beforeAD, -10_000, SysTime(DateTime(1999, 7, 6, 20, 30, 33), d));

        testST(SysTime(DateTime(1999, 7, 6, 0, 30, 33), d), 1, SysTime(DateTime(1999, 7, 6, 1, 30, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 0, 30, 33), d), 0, SysTime(DateTime(1999, 7, 6, 0, 30, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 0, 30, 33), d), -1, SysTime(DateTime(1999, 7, 6, 23, 30, 33), d));

        testST(SysTime(DateTime(1999, 7, 6, 23, 30, 33), d), 1, SysTime(DateTime(1999, 7, 6, 0, 30, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 23, 30, 33), d), 0, SysTime(DateTime(1999, 7, 6, 23, 30, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 23, 30, 33), d), -1, SysTime(DateTime(1999, 7, 6, 22, 30, 33), d));

        testST(SysTime(DateTime(1999, 7, 31, 23, 30, 33), d), 1, SysTime(DateTime(1999, 7, 31, 0, 30, 33), d));
        testST(SysTime(DateTime(1999, 8, 1, 0, 30, 33), d), -1, SysTime(DateTime(1999, 8, 1, 23, 30, 33), d));

        testST(SysTime(DateTime(1999, 12, 31, 23, 30, 33), d), 1, SysTime(DateTime(1999, 12, 31, 0, 30, 33), d));
        testST(SysTime(DateTime(2000, 1, 1, 0, 30, 33), d), -1, SysTime(DateTime(2000, 1, 1, 23, 30, 33), d));

        testST(SysTime(DateTime(1999, 2, 28, 23, 30, 33), d), 25, SysTime(DateTime(1999, 2, 28, 0, 30, 33), d));
        testST(SysTime(DateTime(1999, 3, 2, 0, 30, 33), d), -25, SysTime(DateTime(1999, 3, 2, 23, 30, 33), d));

        testST(SysTime(DateTime(2000, 2, 28, 23, 30, 33), d), 25, SysTime(DateTime(2000, 2, 28, 0, 30, 33), d));
        testST(SysTime(DateTime(2000, 3, 1, 0, 30, 33), d), -25, SysTime(DateTime(2000, 3, 1, 23, 30, 33), d));

        // Test B.C.
        auto beforeBC = SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d);
        testST(beforeBC, 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 1, SysTime(DateTime(-1999, 7, 6, 13, 30, 33), d));
        testST(beforeBC, 2, SysTime(DateTime(-1999, 7, 6, 14, 30, 33), d));
        testST(beforeBC, 3, SysTime(DateTime(-1999, 7, 6, 15, 30, 33), d));
        testST(beforeBC, 4, SysTime(DateTime(-1999, 7, 6, 16, 30, 33), d));
        testST(beforeBC, 5, SysTime(DateTime(-1999, 7, 6, 17, 30, 33), d));
        testST(beforeBC, 6, SysTime(DateTime(-1999, 7, 6, 18, 30, 33), d));
        testST(beforeBC, 7, SysTime(DateTime(-1999, 7, 6, 19, 30, 33), d));
        testST(beforeBC, 8, SysTime(DateTime(-1999, 7, 6, 20, 30, 33), d));
        testST(beforeBC, 9, SysTime(DateTime(-1999, 7, 6, 21, 30, 33), d));
        testST(beforeBC, 10, SysTime(DateTime(-1999, 7, 6, 22, 30, 33), d));
        testST(beforeBC, 11, SysTime(DateTime(-1999, 7, 6, 23, 30, 33), d));
        testST(beforeBC, 12, SysTime(DateTime(-1999, 7, 6, 0, 30, 33), d));
        testST(beforeBC, 13, SysTime(DateTime(-1999, 7, 6, 1, 30, 33), d));
        testST(beforeBC, 14, SysTime(DateTime(-1999, 7, 6, 2, 30, 33), d));
        testST(beforeBC, 15, SysTime(DateTime(-1999, 7, 6, 3, 30, 33), d));
        testST(beforeBC, 16, SysTime(DateTime(-1999, 7, 6, 4, 30, 33), d));
        testST(beforeBC, 17, SysTime(DateTime(-1999, 7, 6, 5, 30, 33), d));
        testST(beforeBC, 18, SysTime(DateTime(-1999, 7, 6, 6, 30, 33), d));
        testST(beforeBC, 19, SysTime(DateTime(-1999, 7, 6, 7, 30, 33), d));
        testST(beforeBC, 20, SysTime(DateTime(-1999, 7, 6, 8, 30, 33), d));
        testST(beforeBC, 21, SysTime(DateTime(-1999, 7, 6, 9, 30, 33), d));
        testST(beforeBC, 22, SysTime(DateTime(-1999, 7, 6, 10, 30, 33), d));
        testST(beforeBC, 23, SysTime(DateTime(-1999, 7, 6, 11, 30, 33), d));
        testST(beforeBC, 24, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 25, SysTime(DateTime(-1999, 7, 6, 13, 30, 33), d));
        testST(beforeBC, 50, SysTime(DateTime(-1999, 7, 6, 14, 30, 33), d));
        testST(beforeBC, 10_000, SysTime(DateTime(-1999, 7, 6, 4, 30, 33), d));

        testST(beforeBC, -1, SysTime(DateTime(-1999, 7, 6, 11, 30, 33), d));
        testST(beforeBC, -2, SysTime(DateTime(-1999, 7, 6, 10, 30, 33), d));
        testST(beforeBC, -3, SysTime(DateTime(-1999, 7, 6, 9, 30, 33), d));
        testST(beforeBC, -4, SysTime(DateTime(-1999, 7, 6, 8, 30, 33), d));
        testST(beforeBC, -5, SysTime(DateTime(-1999, 7, 6, 7, 30, 33), d));
        testST(beforeBC, -6, SysTime(DateTime(-1999, 7, 6, 6, 30, 33), d));
        testST(beforeBC, -7, SysTime(DateTime(-1999, 7, 6, 5, 30, 33), d));
        testST(beforeBC, -8, SysTime(DateTime(-1999, 7, 6, 4, 30, 33), d));
        testST(beforeBC, -9, SysTime(DateTime(-1999, 7, 6, 3, 30, 33), d));
        testST(beforeBC, -10, SysTime(DateTime(-1999, 7, 6, 2, 30, 33), d));
        testST(beforeBC, -11, SysTime(DateTime(-1999, 7, 6, 1, 30, 33), d));
        testST(beforeBC, -12, SysTime(DateTime(-1999, 7, 6, 0, 30, 33), d));
        testST(beforeBC, -13, SysTime(DateTime(-1999, 7, 6, 23, 30, 33), d));
        testST(beforeBC, -14, SysTime(DateTime(-1999, 7, 6, 22, 30, 33), d));
        testST(beforeBC, -15, SysTime(DateTime(-1999, 7, 6, 21, 30, 33), d));
        testST(beforeBC, -16, SysTime(DateTime(-1999, 7, 6, 20, 30, 33), d));
        testST(beforeBC, -17, SysTime(DateTime(-1999, 7, 6, 19, 30, 33), d));
        testST(beforeBC, -18, SysTime(DateTime(-1999, 7, 6, 18, 30, 33), d));
        testST(beforeBC, -19, SysTime(DateTime(-1999, 7, 6, 17, 30, 33), d));
        testST(beforeBC, -20, SysTime(DateTime(-1999, 7, 6, 16, 30, 33), d));
        testST(beforeBC, -21, SysTime(DateTime(-1999, 7, 6, 15, 30, 33), d));
        testST(beforeBC, -22, SysTime(DateTime(-1999, 7, 6, 14, 30, 33), d));
        testST(beforeBC, -23, SysTime(DateTime(-1999, 7, 6, 13, 30, 33), d));
        testST(beforeBC, -24, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, -25, SysTime(DateTime(-1999, 7, 6, 11, 30, 33), d));
        testST(beforeBC, -50, SysTime(DateTime(-1999, 7, 6, 10, 30, 33), d));
        testST(beforeBC, -10_000, SysTime(DateTime(-1999, 7, 6, 20, 30, 33), d));

        testST(SysTime(DateTime(-1999, 7, 6, 0, 30, 33), d), 1, SysTime(DateTime(-1999, 7, 6, 1, 30, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 0, 30, 33), d), 0, SysTime(DateTime(-1999, 7, 6, 0, 30, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 0, 30, 33), d), -1, SysTime(DateTime(-1999, 7, 6, 23, 30, 33), d));

        testST(SysTime(DateTime(-1999, 7, 6, 23, 30, 33), d), 1, SysTime(DateTime(-1999, 7, 6, 0, 30, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 23, 30, 33), d), 0, SysTime(DateTime(-1999, 7, 6, 23, 30, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 23, 30, 33), d), -1, SysTime(DateTime(-1999, 7, 6, 22, 30, 33), d));

        testST(SysTime(DateTime(-1999, 7, 31, 23, 30, 33), d), 1, SysTime(DateTime(-1999, 7, 31, 0, 30, 33), d));
        testST(SysTime(DateTime(-1999, 8, 1, 0, 30, 33), d), -1, SysTime(DateTime(-1999, 8, 1, 23, 30, 33), d));

        testST(SysTime(DateTime(-2001, 12, 31, 23, 30, 33), d), 1, SysTime(DateTime(-2001, 12, 31, 0, 30, 33), d));
        testST(SysTime(DateTime(-2000, 1, 1, 0, 30, 33), d), -1, SysTime(DateTime(-2000, 1, 1, 23, 30, 33), d));

        testST(SysTime(DateTime(-2001, 2, 28, 23, 30, 33), d), 25, SysTime(DateTime(-2001, 2, 28, 0, 30, 33), d));
        testST(SysTime(DateTime(-2001, 3, 2, 0, 30, 33), d), -25, SysTime(DateTime(-2001, 3, 2, 23, 30, 33), d));

        testST(SysTime(DateTime(-2000, 2, 28, 23, 30, 33), d), 25, SysTime(DateTime(-2000, 2, 28, 0, 30, 33), d));
        testST(SysTime(DateTime(-2000, 3, 1, 0, 30, 33), d), -25, SysTime(DateTime(-2000, 3, 1, 23, 30, 33), d));

        // Test Both
        testST(SysTime(DateTime(-1, 1, 1, 11, 30, 33), d), 17_546, SysTime(DateTime(-1, 1, 1, 13, 30, 33), d));
        testST(SysTime(DateTime(1, 1, 1, 13, 30, 33), d), -17_546, SysTime(DateTime(1, 1, 1, 11, 30, 33), d));

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.roll!"hours"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 0, 0)));
            sysTime.roll!"hours"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"hours"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"hours"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 0, 0));
            sysTime.roll!"hours"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 0, 0, 0)));
            sysTime.roll!"hours"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"hours"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 0, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"hours"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"hours"(1).roll!"hours"(-67);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 5, 59, 59), hnsecs(9_999_999)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.roll!"hours"(4)));
        //static assert(!__traits(compiles, ist.roll!"hours"(4)));
    }

    // Test roll!"minutes"().
    @safe unittest
    {
        static void testST(SysTime orig, int minutes, in SysTime expected, size_t line = __LINE__)
        {
            orig.roll!"minutes"(minutes);
            if (orig != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
        }

        // Test A.D.
        immutable d = usecs(7203);
        auto beforeAD = SysTime(DateTime(1999, 7, 6, 12, 30, 33), d);
        testST(beforeAD, 0, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 1, SysTime(DateTime(1999, 7, 6, 12, 31, 33), d));
        testST(beforeAD, 2, SysTime(DateTime(1999, 7, 6, 12, 32, 33), d));
        testST(beforeAD, 3, SysTime(DateTime(1999, 7, 6, 12, 33, 33), d));
        testST(beforeAD, 4, SysTime(DateTime(1999, 7, 6, 12, 34, 33), d));
        testST(beforeAD, 5, SysTime(DateTime(1999, 7, 6, 12, 35, 33), d));
        testST(beforeAD, 10, SysTime(DateTime(1999, 7, 6, 12, 40, 33), d));
        testST(beforeAD, 15, SysTime(DateTime(1999, 7, 6, 12, 45, 33), d));
        testST(beforeAD, 29, SysTime(DateTime(1999, 7, 6, 12, 59, 33), d));
        testST(beforeAD, 30, SysTime(DateTime(1999, 7, 6, 12, 0, 33), d));
        testST(beforeAD, 45, SysTime(DateTime(1999, 7, 6, 12, 15, 33), d));
        testST(beforeAD, 60, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 75, SysTime(DateTime(1999, 7, 6, 12, 45, 33), d));
        testST(beforeAD, 90, SysTime(DateTime(1999, 7, 6, 12, 0, 33), d));
        testST(beforeAD, 100, SysTime(DateTime(1999, 7, 6, 12, 10, 33), d));

        testST(beforeAD, 689, SysTime(DateTime(1999, 7, 6, 12, 59, 33), d));
        testST(beforeAD, 690, SysTime(DateTime(1999, 7, 6, 12, 0, 33), d));
        testST(beforeAD, 691, SysTime(DateTime(1999, 7, 6, 12, 1, 33), d));
        testST(beforeAD, 960, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 1439, SysTime(DateTime(1999, 7, 6, 12, 29, 33), d));
        testST(beforeAD, 1440, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 1441, SysTime(DateTime(1999, 7, 6, 12, 31, 33), d));
        testST(beforeAD, 2880, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));

        testST(beforeAD, -1, SysTime(DateTime(1999, 7, 6, 12, 29, 33), d));
        testST(beforeAD, -2, SysTime(DateTime(1999, 7, 6, 12, 28, 33), d));
        testST(beforeAD, -3, SysTime(DateTime(1999, 7, 6, 12, 27, 33), d));
        testST(beforeAD, -4, SysTime(DateTime(1999, 7, 6, 12, 26, 33), d));
        testST(beforeAD, -5, SysTime(DateTime(1999, 7, 6, 12, 25, 33), d));
        testST(beforeAD, -10, SysTime(DateTime(1999, 7, 6, 12, 20, 33), d));
        testST(beforeAD, -15, SysTime(DateTime(1999, 7, 6, 12, 15, 33), d));
        testST(beforeAD, -29, SysTime(DateTime(1999, 7, 6, 12, 1, 33), d));
        testST(beforeAD, -30, SysTime(DateTime(1999, 7, 6, 12, 0, 33), d));
        testST(beforeAD, -45, SysTime(DateTime(1999, 7, 6, 12, 45, 33), d));
        testST(beforeAD, -60, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, -75, SysTime(DateTime(1999, 7, 6, 12, 15, 33), d));
        testST(beforeAD, -90, SysTime(DateTime(1999, 7, 6, 12, 0, 33), d));
        testST(beforeAD, -100, SysTime(DateTime(1999, 7, 6, 12, 50, 33), d));

        testST(beforeAD, -749, SysTime(DateTime(1999, 7, 6, 12, 1, 33), d));
        testST(beforeAD, -750, SysTime(DateTime(1999, 7, 6, 12, 0, 33), d));
        testST(beforeAD, -751, SysTime(DateTime(1999, 7, 6, 12, 59, 33), d));
        testST(beforeAD, -960, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, -1439, SysTime(DateTime(1999, 7, 6, 12, 31, 33), d));
        testST(beforeAD, -1440, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, -1441, SysTime(DateTime(1999, 7, 6, 12, 29, 33), d));
        testST(beforeAD, -2880, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));

        testST(SysTime(DateTime(1999, 7, 6, 12, 0, 33), d), 1, SysTime(DateTime(1999, 7, 6, 12, 1, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 12, 0, 33), d), 0, SysTime(DateTime(1999, 7, 6, 12, 0, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 12, 0, 33), d), -1, SysTime(DateTime(1999, 7, 6, 12, 59, 33), d));

        testST(SysTime(DateTime(1999, 7, 6, 11, 59, 33), d), 1, SysTime(DateTime(1999, 7, 6, 11, 0, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 11, 59, 33), d), 0, SysTime(DateTime(1999, 7, 6, 11, 59, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 11, 59, 33), d), -1, SysTime(DateTime(1999, 7, 6, 11, 58, 33), d));

        testST(SysTime(DateTime(1999, 7, 6, 0, 0, 33), d), 1, SysTime(DateTime(1999, 7, 6, 0, 1, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 0, 0, 33), d), 0, SysTime(DateTime(1999, 7, 6, 0, 0, 33), d));
        testST(SysTime(DateTime(1999, 7, 6, 0, 0, 33), d), -1, SysTime(DateTime(1999, 7, 6, 0, 59, 33), d));

        testST(SysTime(DateTime(1999, 7, 5, 23, 59, 33), d), 1, SysTime(DateTime(1999, 7, 5, 23, 0, 33), d));
        testST(SysTime(DateTime(1999, 7, 5, 23, 59, 33), d), 0, SysTime(DateTime(1999, 7, 5, 23, 59, 33), d));
        testST(SysTime(DateTime(1999, 7, 5, 23, 59, 33), d), -1, SysTime(DateTime(1999, 7, 5, 23, 58, 33), d));

        testST(SysTime(DateTime(1998, 12, 31, 23, 59, 33), d), 1, SysTime(DateTime(1998, 12, 31, 23, 0, 33), d));
        testST(SysTime(DateTime(1998, 12, 31, 23, 59, 33), d), 0, SysTime(DateTime(1998, 12, 31, 23, 59, 33), d));
        testST(SysTime(DateTime(1998, 12, 31, 23, 59, 33), d), -1, SysTime(DateTime(1998, 12, 31, 23, 58, 33), d));

        // Test B.C.
        auto beforeBC = SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d);
        testST(beforeBC, 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 1, SysTime(DateTime(-1999, 7, 6, 12, 31, 33), d));
        testST(beforeBC, 2, SysTime(DateTime(-1999, 7, 6, 12, 32, 33), d));
        testST(beforeBC, 3, SysTime(DateTime(-1999, 7, 6, 12, 33, 33), d));
        testST(beforeBC, 4, SysTime(DateTime(-1999, 7, 6, 12, 34, 33), d));
        testST(beforeBC, 5, SysTime(DateTime(-1999, 7, 6, 12, 35, 33), d));
        testST(beforeBC, 10, SysTime(DateTime(-1999, 7, 6, 12, 40, 33), d));
        testST(beforeBC, 15, SysTime(DateTime(-1999, 7, 6, 12, 45, 33), d));
        testST(beforeBC, 29, SysTime(DateTime(-1999, 7, 6, 12, 59, 33), d));
        testST(beforeBC, 30, SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d));
        testST(beforeBC, 45, SysTime(DateTime(-1999, 7, 6, 12, 15, 33), d));
        testST(beforeBC, 60, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 75, SysTime(DateTime(-1999, 7, 6, 12, 45, 33), d));
        testST(beforeBC, 90, SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d));
        testST(beforeBC, 100, SysTime(DateTime(-1999, 7, 6, 12, 10, 33), d));

        testST(beforeBC, 689, SysTime(DateTime(-1999, 7, 6, 12, 59, 33), d));
        testST(beforeBC, 690, SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d));
        testST(beforeBC, 691, SysTime(DateTime(-1999, 7, 6, 12, 1, 33), d));
        testST(beforeBC, 960, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 1439, SysTime(DateTime(-1999, 7, 6, 12, 29, 33), d));
        testST(beforeBC, 1440, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 1441, SysTime(DateTime(-1999, 7, 6, 12, 31, 33), d));
        testST(beforeBC, 2880, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));

        testST(beforeBC, -1, SysTime(DateTime(-1999, 7, 6, 12, 29, 33), d));
        testST(beforeBC, -2, SysTime(DateTime(-1999, 7, 6, 12, 28, 33), d));
        testST(beforeBC, -3, SysTime(DateTime(-1999, 7, 6, 12, 27, 33), d));
        testST(beforeBC, -4, SysTime(DateTime(-1999, 7, 6, 12, 26, 33), d));
        testST(beforeBC, -5, SysTime(DateTime(-1999, 7, 6, 12, 25, 33), d));
        testST(beforeBC, -10, SysTime(DateTime(-1999, 7, 6, 12, 20, 33), d));
        testST(beforeBC, -15, SysTime(DateTime(-1999, 7, 6, 12, 15, 33), d));
        testST(beforeBC, -29, SysTime(DateTime(-1999, 7, 6, 12, 1, 33), d));
        testST(beforeBC, -30, SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d));
        testST(beforeBC, -45, SysTime(DateTime(-1999, 7, 6, 12, 45, 33), d));
        testST(beforeBC, -60, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, -75, SysTime(DateTime(-1999, 7, 6, 12, 15, 33), d));
        testST(beforeBC, -90, SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d));
        testST(beforeBC, -100, SysTime(DateTime(-1999, 7, 6, 12, 50, 33), d));

        testST(beforeBC, -749, SysTime(DateTime(-1999, 7, 6, 12, 1, 33), d));
        testST(beforeBC, -750, SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d));
        testST(beforeBC, -751, SysTime(DateTime(-1999, 7, 6, 12, 59, 33), d));
        testST(beforeBC, -960, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, -1439, SysTime(DateTime(-1999, 7, 6, 12, 31, 33), d));
        testST(beforeBC, -1440, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, -1441, SysTime(DateTime(-1999, 7, 6, 12, 29, 33), d));
        testST(beforeBC, -2880, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));

        testST(SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d), 1, SysTime(DateTime(-1999, 7, 6, 12, 1, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d), 0, SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 12, 0, 33), d), -1, SysTime(DateTime(-1999, 7, 6, 12, 59, 33), d));

        testST(SysTime(DateTime(-1999, 7, 6, 11, 59, 33), d), 1, SysTime(DateTime(-1999, 7, 6, 11, 0, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 11, 59, 33), d), 0, SysTime(DateTime(-1999, 7, 6, 11, 59, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 11, 59, 33), d), -1, SysTime(DateTime(-1999, 7, 6, 11, 58, 33), d));

        testST(SysTime(DateTime(-1999, 7, 6, 0, 0, 33), d), 1, SysTime(DateTime(-1999, 7, 6, 0, 1, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 0, 0, 33), d), 0, SysTime(DateTime(-1999, 7, 6, 0, 0, 33), d));
        testST(SysTime(DateTime(-1999, 7, 6, 0, 0, 33), d), -1, SysTime(DateTime(-1999, 7, 6, 0, 59, 33), d));

        testST(SysTime(DateTime(-1999, 7, 5, 23, 59, 33), d), 1, SysTime(DateTime(-1999, 7, 5, 23, 0, 33), d));
        testST(SysTime(DateTime(-1999, 7, 5, 23, 59, 33), d), 0, SysTime(DateTime(-1999, 7, 5, 23, 59, 33), d));
        testST(SysTime(DateTime(-1999, 7, 5, 23, 59, 33), d), -1, SysTime(DateTime(-1999, 7, 5, 23, 58, 33), d));

        testST(SysTime(DateTime(-2000, 12, 31, 23, 59, 33), d), 1, SysTime(DateTime(-2000, 12, 31, 23, 0, 33), d));
        testST(SysTime(DateTime(-2000, 12, 31, 23, 59, 33), d), 0, SysTime(DateTime(-2000, 12, 31, 23, 59, 33), d));
        testST(SysTime(DateTime(-2000, 12, 31, 23, 59, 33), d), -1, SysTime(DateTime(-2000, 12, 31, 23, 58, 33), d));

        // Test Both
        testST(SysTime(DateTime(1, 1, 1, 0, 0, 0)), -1, SysTime(DateTime(1, 1, 1, 0, 59, 0)));
        testST(SysTime(DateTime(0, 12, 31, 23, 59, 0)), 1, SysTime(DateTime(0, 12, 31, 23, 0, 0)));

        testST(SysTime(DateTime(0, 1, 1, 0, 0, 0)), -1, SysTime(DateTime(0, 1, 1, 0, 59, 0)));
        testST(SysTime(DateTime(-1, 12, 31, 23, 59, 0)), 1, SysTime(DateTime(-1, 12, 31, 23, 0, 0)));

        testST(SysTime(DateTime(-1, 1, 1, 11, 30, 33), d), 1_052_760, SysTime(DateTime(-1, 1, 1, 11, 30, 33), d));
        testST(SysTime(DateTime(1, 1, 1, 13, 30, 33), d), -1_052_760, SysTime(DateTime(1, 1, 1, 13, 30, 33), d));

        testST(SysTime(DateTime(-1, 1, 1, 11, 30, 33), d), 1_052_782, SysTime(DateTime(-1, 1, 1, 11, 52, 33), d));
        testST(SysTime(DateTime(1, 1, 1, 13, 52, 33), d), -1_052_782, SysTime(DateTime(1, 1, 1, 13, 30, 33), d));

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.roll!"minutes"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 59, 0)));
            sysTime.roll!"minutes"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 59), hnsecs(9_999_999));
            sysTime.roll!"minutes"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 59, 59), hnsecs(9_999_999)));
            sysTime.roll!"minutes"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 0));
            sysTime.roll!"minutes"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 0, 0)));
            sysTime.roll!"minutes"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"minutes"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 0, 59), hnsecs(9_999_999)));
            sysTime.roll!"minutes"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"minutes"(1).roll!"minutes"(-79);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 41, 59), hnsecs(9_999_999)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.roll!"minutes"(4)));
        //static assert(!__traits(compiles, ist.roll!"minutes"(4)));
    }

    // Test roll!"seconds"().
    @safe unittest
    {
        static void testST(SysTime orig, int seconds, in SysTime expected, size_t line = __LINE__)
        {
            orig.roll!"seconds"(seconds);
            if (orig != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
        }

        // Test A.D.
        immutable d = msecs(274);
        auto beforeAD = SysTime(DateTime(1999, 7, 6, 12, 30, 33), d);
        testST(beforeAD, 0, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 1, SysTime(DateTime(1999, 7, 6, 12, 30, 34), d));
        testST(beforeAD, 2, SysTime(DateTime(1999, 7, 6, 12, 30, 35), d));
        testST(beforeAD, 3, SysTime(DateTime(1999, 7, 6, 12, 30, 36), d));
        testST(beforeAD, 4, SysTime(DateTime(1999, 7, 6, 12, 30, 37), d));
        testST(beforeAD, 5, SysTime(DateTime(1999, 7, 6, 12, 30, 38), d));
        testST(beforeAD, 10, SysTime(DateTime(1999, 7, 6, 12, 30, 43), d));
        testST(beforeAD, 15, SysTime(DateTime(1999, 7, 6, 12, 30, 48), d));
        testST(beforeAD, 26, SysTime(DateTime(1999, 7, 6, 12, 30, 59), d));
        testST(beforeAD, 27, SysTime(DateTime(1999, 7, 6, 12, 30, 0), d));
        testST(beforeAD, 30, SysTime(DateTime(1999, 7, 6, 12, 30, 3), d));
        testST(beforeAD, 59, SysTime(DateTime(1999, 7, 6, 12, 30, 32), d));
        testST(beforeAD, 60, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 61, SysTime(DateTime(1999, 7, 6, 12, 30, 34), d));

        testST(beforeAD, 1766, SysTime(DateTime(1999, 7, 6, 12, 30, 59), d));
        testST(beforeAD, 1767, SysTime(DateTime(1999, 7, 6, 12, 30, 0), d));
        testST(beforeAD, 1768, SysTime(DateTime(1999, 7, 6, 12, 30, 1), d));
        testST(beforeAD, 2007, SysTime(DateTime(1999, 7, 6, 12, 30, 0), d));
        testST(beforeAD, 3599, SysTime(DateTime(1999, 7, 6, 12, 30, 32), d));
        testST(beforeAD, 3600, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, 3601, SysTime(DateTime(1999, 7, 6, 12, 30, 34), d));
        testST(beforeAD, 7200, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));

        testST(beforeAD, -1, SysTime(DateTime(1999, 7, 6, 12, 30, 32), d));
        testST(beforeAD, -2, SysTime(DateTime(1999, 7, 6, 12, 30, 31), d));
        testST(beforeAD, -3, SysTime(DateTime(1999, 7, 6, 12, 30, 30), d));
        testST(beforeAD, -4, SysTime(DateTime(1999, 7, 6, 12, 30, 29), d));
        testST(beforeAD, -5, SysTime(DateTime(1999, 7, 6, 12, 30, 28), d));
        testST(beforeAD, -10, SysTime(DateTime(1999, 7, 6, 12, 30, 23), d));
        testST(beforeAD, -15, SysTime(DateTime(1999, 7, 6, 12, 30, 18), d));
        testST(beforeAD, -33, SysTime(DateTime(1999, 7, 6, 12, 30, 0), d));
        testST(beforeAD, -34, SysTime(DateTime(1999, 7, 6, 12, 30, 59), d));
        testST(beforeAD, -35, SysTime(DateTime(1999, 7, 6, 12, 30, 58), d));
        testST(beforeAD, -59, SysTime(DateTime(1999, 7, 6, 12, 30, 34), d));
        testST(beforeAD, -60, SysTime(DateTime(1999, 7, 6, 12, 30, 33), d));
        testST(beforeAD, -61, SysTime(DateTime(1999, 7, 6, 12, 30, 32), d));

        testST(SysTime(DateTime(1999, 7, 6, 12, 30, 0), d), 1, SysTime(DateTime(1999, 7, 6, 12, 30, 1), d));
        testST(SysTime(DateTime(1999, 7, 6, 12, 30, 0), d), 0, SysTime(DateTime(1999, 7, 6, 12, 30, 0), d));
        testST(SysTime(DateTime(1999, 7, 6, 12, 30, 0), d), -1, SysTime(DateTime(1999, 7, 6, 12, 30, 59), d));

        testST(SysTime(DateTime(1999, 7, 6, 12, 0, 0), d), 1, SysTime(DateTime(1999, 7, 6, 12, 0, 1), d));
        testST(SysTime(DateTime(1999, 7, 6, 12, 0, 0), d), 0, SysTime(DateTime(1999, 7, 6, 12, 0, 0), d));
        testST(SysTime(DateTime(1999, 7, 6, 12, 0, 0), d), -1, SysTime(DateTime(1999, 7, 6, 12, 0, 59), d));

        testST(SysTime(DateTime(1999, 7, 6, 0, 0, 0), d), 1, SysTime(DateTime(1999, 7, 6, 0, 0, 1), d));
        testST(SysTime(DateTime(1999, 7, 6, 0, 0, 0), d), 0, SysTime(DateTime(1999, 7, 6, 0, 0, 0), d));
        testST(SysTime(DateTime(1999, 7, 6, 0, 0, 0), d), -1, SysTime(DateTime(1999, 7, 6, 0, 0, 59), d));

        testST(SysTime(DateTime(1999, 7, 5, 23, 59, 59), d), 1, SysTime(DateTime(1999, 7, 5, 23, 59, 0), d));
        testST(SysTime(DateTime(1999, 7, 5, 23, 59, 59), d), 0, SysTime(DateTime(1999, 7, 5, 23, 59, 59), d));
        testST(SysTime(DateTime(1999, 7, 5, 23, 59, 59), d), -1, SysTime(DateTime(1999, 7, 5, 23, 59, 58), d));

        testST(SysTime(DateTime(1998, 12, 31, 23, 59, 59), d), 1, SysTime(DateTime(1998, 12, 31, 23, 59, 0), d));
        testST(SysTime(DateTime(1998, 12, 31, 23, 59, 59), d), 0, SysTime(DateTime(1998, 12, 31, 23, 59, 59), d));
        testST(SysTime(DateTime(1998, 12, 31, 23, 59, 59), d), -1, SysTime(DateTime(1998, 12, 31, 23, 59, 58), d));

        // Test B.C.
        auto beforeBC = SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d);
        testST(beforeBC, 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 1, SysTime(DateTime(-1999, 7, 6, 12, 30, 34), d));
        testST(beforeBC, 2, SysTime(DateTime(-1999, 7, 6, 12, 30, 35), d));
        testST(beforeBC, 3, SysTime(DateTime(-1999, 7, 6, 12, 30, 36), d));
        testST(beforeBC, 4, SysTime(DateTime(-1999, 7, 6, 12, 30, 37), d));
        testST(beforeBC, 5, SysTime(DateTime(-1999, 7, 6, 12, 30, 38), d));
        testST(beforeBC, 10, SysTime(DateTime(-1999, 7, 6, 12, 30, 43), d));
        testST(beforeBC, 15, SysTime(DateTime(-1999, 7, 6, 12, 30, 48), d));
        testST(beforeBC, 26, SysTime(DateTime(-1999, 7, 6, 12, 30, 59), d));
        testST(beforeBC, 27, SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d));
        testST(beforeBC, 30, SysTime(DateTime(-1999, 7, 6, 12, 30, 3), d));
        testST(beforeBC, 59, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), d));
        testST(beforeBC, 60, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 61, SysTime(DateTime(-1999, 7, 6, 12, 30, 34), d));

        testST(beforeBC, 1766, SysTime(DateTime(-1999, 7, 6, 12, 30, 59), d));
        testST(beforeBC, 1767, SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d));
        testST(beforeBC, 1768, SysTime(DateTime(-1999, 7, 6, 12, 30, 1), d));
        testST(beforeBC, 2007, SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d));
        testST(beforeBC, 3599, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), d));
        testST(beforeBC, 3600, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, 3601, SysTime(DateTime(-1999, 7, 6, 12, 30, 34), d));
        testST(beforeBC, 7200, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));

        testST(beforeBC, -1, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), d));
        testST(beforeBC, -2, SysTime(DateTime(-1999, 7, 6, 12, 30, 31), d));
        testST(beforeBC, -3, SysTime(DateTime(-1999, 7, 6, 12, 30, 30), d));
        testST(beforeBC, -4, SysTime(DateTime(-1999, 7, 6, 12, 30, 29), d));
        testST(beforeBC, -5, SysTime(DateTime(-1999, 7, 6, 12, 30, 28), d));
        testST(beforeBC, -10, SysTime(DateTime(-1999, 7, 6, 12, 30, 23), d));
        testST(beforeBC, -15, SysTime(DateTime(-1999, 7, 6, 12, 30, 18), d));
        testST(beforeBC, -33, SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d));
        testST(beforeBC, -34, SysTime(DateTime(-1999, 7, 6, 12, 30, 59), d));
        testST(beforeBC, -35, SysTime(DateTime(-1999, 7, 6, 12, 30, 58), d));
        testST(beforeBC, -59, SysTime(DateTime(-1999, 7, 6, 12, 30, 34), d));
        testST(beforeBC, -60, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), d));
        testST(beforeBC, -61, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), d));

        testST(SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d), 1, SysTime(DateTime(-1999, 7, 6, 12, 30, 1), d));
        testST(SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d), 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d));
        testST(SysTime(DateTime(-1999, 7, 6, 12, 30, 0), d), -1, SysTime(DateTime(-1999, 7, 6, 12, 30, 59), d));

        testST(SysTime(DateTime(-1999, 7, 6, 12, 0, 0), d), 1, SysTime(DateTime(-1999, 7, 6, 12, 0, 1), d));
        testST(SysTime(DateTime(-1999, 7, 6, 12, 0, 0), d), 0, SysTime(DateTime(-1999, 7, 6, 12, 0, 0), d));
        testST(SysTime(DateTime(-1999, 7, 6, 12, 0, 0), d), -1, SysTime(DateTime(-1999, 7, 6, 12, 0, 59), d));

        testST(SysTime(DateTime(-1999, 7, 6, 0, 0, 0), d), 1, SysTime(DateTime(-1999, 7, 6, 0, 0, 1), d));
        testST(SysTime(DateTime(-1999, 7, 6, 0, 0, 0), d), 0, SysTime(DateTime(-1999, 7, 6, 0, 0, 0), d));
        testST(SysTime(DateTime(-1999, 7, 6, 0, 0, 0), d), -1, SysTime(DateTime(-1999, 7, 6, 0, 0, 59), d));

        testST(SysTime(DateTime(-1999, 7, 5, 23, 59, 59), d), 1, SysTime(DateTime(-1999, 7, 5, 23, 59, 0), d));
        testST(SysTime(DateTime(-1999, 7, 5, 23, 59, 59), d), 0, SysTime(DateTime(-1999, 7, 5, 23, 59, 59), d));
        testST(SysTime(DateTime(-1999, 7, 5, 23, 59, 59), d), -1, SysTime(DateTime(-1999, 7, 5, 23, 59, 58), d));

        testST(SysTime(DateTime(-2000, 12, 31, 23, 59, 59), d), 1, SysTime(DateTime(-2000, 12, 31, 23, 59, 0), d));
        testST(SysTime(DateTime(-2000, 12, 31, 23, 59, 59), d), 0, SysTime(DateTime(-2000, 12, 31, 23, 59, 59), d));
        testST(SysTime(DateTime(-2000, 12, 31, 23, 59, 59), d), -1, SysTime(DateTime(-2000, 12, 31, 23, 59, 58), d));

        // Test Both
        testST(SysTime(DateTime(1, 1, 1, 0, 0, 0), d), -1, SysTime(DateTime(1, 1, 1, 0, 0, 59), d));
        testST(SysTime(DateTime(0, 12, 31, 23, 59, 59), d), 1, SysTime(DateTime(0, 12, 31, 23, 59, 0), d));

        testST(SysTime(DateTime(0, 1, 1, 0, 0, 0), d), -1, SysTime(DateTime(0, 1, 1, 0, 0, 59), d));
        testST(SysTime(DateTime(-1, 12, 31, 23, 59, 59), d), 1, SysTime(DateTime(-1, 12, 31, 23, 59, 0), d));

        testST(SysTime(DateTime(-1, 1, 1, 11, 30, 33), d), 63_165_600L, SysTime(DateTime(-1, 1, 1, 11, 30, 33), d));
        testST(SysTime(DateTime(1, 1, 1, 13, 30, 33), d), -63_165_600L, SysTime(DateTime(1, 1, 1, 13, 30, 33), d));

        testST(SysTime(DateTime(-1, 1, 1, 11, 30, 33), d), 63_165_617L, SysTime(DateTime(-1, 1, 1, 11, 30, 50), d));
        testST(SysTime(DateTime(1, 1, 1, 13, 30, 50), d), -63_165_617L, SysTime(DateTime(1, 1, 1, 13, 30, 33), d));

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0));
            sysTime.roll!"seconds"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 59)));
            sysTime.roll!"seconds"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        }

        {
            auto sysTime = SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(9_999_999));
            sysTime.roll!"seconds"(-1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 59), hnsecs(9_999_999)));
            sysTime.roll!"seconds"(1);
            assert(sysTime == SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59));
            sysTime.roll!"seconds"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 0)));
            sysTime.roll!"seconds"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 59)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"seconds"(1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 0), hnsecs(9_999_999)));
            sysTime.roll!"seconds"(-1);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        }

        {
            auto sysTime = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            sysTime.roll!"seconds"(1).roll!"seconds"(-102);
            assert(sysTime == SysTime(DateTime(0, 12, 31, 23, 59, 18), hnsecs(9_999_999)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.roll!"seconds"(4)));
        //static assert(!__traits(compiles, ist.roll!"seconds"(4)));
    }


    // Shares documentation with "days" version.
    ref SysTime roll(string units)(long value) @safe nothrow
        if (units == "msecs" || units == "usecs" || units == "hnsecs")
    {
        auto hnsecs = adjTime;
        immutable days = splitUnitsFromHNSecs!"days"(hnsecs);
        immutable negative = hnsecs < 0;

        if (negative)
            hnsecs += convert!("hours", "hnsecs")(24);

        immutable seconds = splitUnitsFromHNSecs!"seconds"(hnsecs);
        hnsecs += convert!(units, "hnsecs")(value);
        hnsecs %= convert!("seconds", "hnsecs")(1);

        if (hnsecs < 0)
            hnsecs += convert!("seconds", "hnsecs")(1);
        hnsecs += convert!("seconds", "hnsecs")(seconds);

        if (negative)
            hnsecs -= convert!("hours", "hnsecs")(24);

        immutable newDaysHNSecs = convert!("days", "hnsecs")(days);
        adjTime = newDaysHNSecs + hnsecs;
        return this;
    }


    // Test roll!"msecs"().
    @safe unittest
    {
        static void testST(SysTime orig, int milliseconds, in SysTime expected, size_t line = __LINE__)
        {
            orig.roll!"msecs"(milliseconds);
            if (orig != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
        }

        // Test A.D.
        auto beforeAD = SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(274));
        testST(beforeAD, 0, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeAD, 1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(275)));
        testST(beforeAD, 2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(276)));
        testST(beforeAD, 10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(284)));
        testST(beforeAD, 100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(374)));
        testST(beforeAD, 725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeAD, 726, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, 1000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeAD, 1001, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(275)));
        testST(beforeAD, 2000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeAD, 26_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeAD, 26_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, 26_727, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(1)));
        testST(beforeAD, 1_766_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeAD, 1_766_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));

        testST(beforeAD, -1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(273)));
        testST(beforeAD, -2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(272)));
        testST(beforeAD, -10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(264)));
        testST(beforeAD, -100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(174)));
        testST(beforeAD, -274, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, -275, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeAD, -1000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeAD, -1001, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(273)));
        testST(beforeAD, -2000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeAD, -33_274, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, -33_275, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeAD, -1_833_274, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, -1_833_275, SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(999)));

        // Test B.C.
        auto beforeBC = SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(274));
        testST(beforeBC, 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeBC, 1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(275)));
        testST(beforeBC, 2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(276)));
        testST(beforeBC, 10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(284)));
        testST(beforeBC, 100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(374)));
        testST(beforeBC, 725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeBC, 726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, 1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeBC, 1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(275)));
        testST(beforeBC, 2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeBC, 26_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeBC, 26_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, 26_727, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(1)));
        testST(beforeBC, 1_766_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeBC, 1_766_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));

        testST(beforeBC, -1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(273)));
        testST(beforeBC, -2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(272)));
        testST(beforeBC, -10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(264)));
        testST(beforeBC, -100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(174)));
        testST(beforeBC, -274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, -275, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeBC, -1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeBC, -1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(273)));
        testST(beforeBC, -2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(274)));
        testST(beforeBC, -33_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, -33_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(999)));
        testST(beforeBC, -1_833_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, -1_833_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), msecs(999)));

        // Test Both
        auto beforeBoth1 = SysTime(DateTime(1, 1, 1, 0, 0, 0));
        testST(beforeBoth1, 1, SysTime(DateTime(1, 1, 1, 0, 0, 0), msecs(1)));
        testST(beforeBoth1, 0, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -1, SysTime(DateTime(1, 1, 1, 0, 0, 0), msecs(999)));
        testST(beforeBoth1, -2, SysTime(DateTime(1, 1, 1, 0, 0, 0), msecs(998)));
        testST(beforeBoth1, -1000, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -2000, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -2555, SysTime(DateTime(1, 1, 1, 0, 0, 0), msecs(445)));

        auto beforeBoth2 = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
        testST(beforeBoth2, -1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_989_999)));
        testST(beforeBoth2, 0, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9999)));
        testST(beforeBoth2, 2, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(19_999)));
        testST(beforeBoth2, 1000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 2000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 2555, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(5_549_999)));

        {
            auto st = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            st.roll!"msecs"(1202).roll!"msecs"(-703);
            assert(st == SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(4_989_999)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.addMSecs(4)));
        //static assert(!__traits(compiles, ist.addMSecs(4)));
    }

    // Test roll!"usecs"().
    @safe unittest
    {
        static void testST(SysTime orig, long microseconds, in SysTime expected, size_t line = __LINE__)
        {
            orig.roll!"usecs"(microseconds);
            if (orig != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
        }

        // Test A.D.
        auto beforeAD = SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274));
        testST(beforeAD, 0, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeAD, 1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(275)));
        testST(beforeAD, 2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(276)));
        testST(beforeAD, 10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(284)));
        testST(beforeAD, 100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(374)));
        testST(beforeAD, 725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(999)));
        testST(beforeAD, 726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(1000)));
        testST(beforeAD, 1000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(1274)));
        testST(beforeAD, 1001, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(1275)));
        testST(beforeAD, 2000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(2274)));
        testST(beforeAD, 26_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(26_999)));
        testST(beforeAD, 26_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(27_000)));
        testST(beforeAD, 26_727, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(27_001)));
        testST(beforeAD, 1_766_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(766_999)));
        testST(beforeAD, 1_766_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(767_000)));
        testST(beforeAD, 1_000_000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeAD, 60_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeAD, 3_600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274)));

        testST(beforeAD, -1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(273)));
        testST(beforeAD, -2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(272)));
        testST(beforeAD, -10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(264)));
        testST(beforeAD, -100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(174)));
        testST(beforeAD, -274, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, -275, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(999_999)));
        testST(beforeAD, -1000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(999_274)));
        testST(beforeAD, -1001, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(999_273)));
        testST(beforeAD, -2000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(998_274)));
        testST(beforeAD, -33_274, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(967_000)));
        testST(beforeAD, -33_275, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(966_999)));
        testST(beforeAD, -1_833_274, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(167_000)));
        testST(beforeAD, -1_833_275, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(166_999)));
        testST(beforeAD, -1_000_000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeAD, -60_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeAD, -3_600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(274)));

        // Test B.C.
        auto beforeBC = SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274));
        testST(beforeBC, 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeBC, 1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(275)));
        testST(beforeBC, 2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(276)));
        testST(beforeBC, 10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(284)));
        testST(beforeBC, 100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(374)));
        testST(beforeBC, 725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(999)));
        testST(beforeBC, 726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(1000)));
        testST(beforeBC, 1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(1274)));
        testST(beforeBC, 1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(1275)));
        testST(beforeBC, 2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(2274)));
        testST(beforeBC, 26_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(26_999)));
        testST(beforeBC, 26_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(27_000)));
        testST(beforeBC, 26_727, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(27_001)));
        testST(beforeBC, 1_766_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(766_999)));
        testST(beforeBC, 1_766_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(767_000)));
        testST(beforeBC, 1_000_000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeBC, 60_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeBC, 3_600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274)));

        testST(beforeBC, -1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(273)));
        testST(beforeBC, -2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(272)));
        testST(beforeBC, -10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(264)));
        testST(beforeBC, -100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(174)));
        testST(beforeBC, -274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, -275, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(999_999)));
        testST(beforeBC, -1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(999_274)));
        testST(beforeBC, -1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(999_273)));
        testST(beforeBC, -2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(998_274)));
        testST(beforeBC, -33_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(967_000)));
        testST(beforeBC, -33_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(966_999)));
        testST(beforeBC, -1_833_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(167_000)));
        testST(beforeBC, -1_833_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(166_999)));
        testST(beforeBC, -1_000_000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeBC, -60_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274)));
        testST(beforeBC, -3_600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), usecs(274)));

        // Test Both
        auto beforeBoth1 = SysTime(DateTime(1, 1, 1, 0, 0, 0));
        testST(beforeBoth1, 1, SysTime(DateTime(1, 1, 1, 0, 0, 0), usecs(1)));
        testST(beforeBoth1, 0, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -1, SysTime(DateTime(1, 1, 1, 0, 0, 0), usecs(999_999)));
        testST(beforeBoth1, -2, SysTime(DateTime(1, 1, 1, 0, 0, 0), usecs(999_998)));
        testST(beforeBoth1, -1000, SysTime(DateTime(1, 1, 1, 0, 0, 0), usecs(999_000)));
        testST(beforeBoth1, -2000, SysTime(DateTime(1, 1, 1, 0, 0, 0), usecs(998_000)));
        testST(beforeBoth1, -2555, SysTime(DateTime(1, 1, 1, 0, 0, 0), usecs(997_445)));
        testST(beforeBoth1, -1_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -2_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -2_333_333, SysTime(DateTime(1, 1, 1, 0, 0, 0), usecs(666_667)));

        auto beforeBoth2 = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
        testST(beforeBoth2, -1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_989)));
        testST(beforeBoth2, 0, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9)));
        testST(beforeBoth2, 2, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(19)));
        testST(beforeBoth2, 1000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9999)));
        testST(beforeBoth2, 2000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(19_999)));
        testST(beforeBoth2, 2555, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(25_549)));
        testST(beforeBoth2, 1_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 2_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 2_333_333, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(3_333_329)));

        {
            auto st = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            st.roll!"usecs"(9_020_027);
            assert(st == SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(200_269)));
        }

        {
            auto st = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            st.roll!"usecs"(9_020_027).roll!"usecs"(-70_034);
            assert(st == SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_499_929)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.roll!"usecs"(4)));
        //static assert(!__traits(compiles, ist.roll!"usecs"(4)));
    }

    // Test roll!"hnsecs"().
    @safe unittest
    {
        static void testST(SysTime orig, long hnsecs, in SysTime expected, size_t line = __LINE__)
        {
            orig.roll!"hnsecs"(hnsecs);
            if (orig != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
        }

        // Test A.D.
        auto dtAD = DateTime(1999, 7, 6, 12, 30, 33);
        auto beforeAD = SysTime(dtAD, hnsecs(274));
        testST(beforeAD, 0, SysTime(dtAD, hnsecs(274)));
        testST(beforeAD, 1, SysTime(dtAD, hnsecs(275)));
        testST(beforeAD, 2, SysTime(dtAD, hnsecs(276)));
        testST(beforeAD, 10, SysTime(dtAD, hnsecs(284)));
        testST(beforeAD, 100, SysTime(dtAD, hnsecs(374)));
        testST(beforeAD, 725, SysTime(dtAD, hnsecs(999)));
        testST(beforeAD, 726, SysTime(dtAD, hnsecs(1000)));
        testST(beforeAD, 1000, SysTime(dtAD, hnsecs(1274)));
        testST(beforeAD, 1001, SysTime(dtAD, hnsecs(1275)));
        testST(beforeAD, 2000, SysTime(dtAD, hnsecs(2274)));
        testST(beforeAD, 26_725, SysTime(dtAD, hnsecs(26_999)));
        testST(beforeAD, 26_726, SysTime(dtAD, hnsecs(27_000)));
        testST(beforeAD, 26_727, SysTime(dtAD, hnsecs(27_001)));
        testST(beforeAD, 1_766_725, SysTime(dtAD, hnsecs(1_766_999)));
        testST(beforeAD, 1_766_726, SysTime(dtAD, hnsecs(1_767_000)));
        testST(beforeAD, 1_000_000, SysTime(dtAD, hnsecs(1_000_274)));
        testST(beforeAD, 60_000_000L, SysTime(dtAD, hnsecs(274)));
        testST(beforeAD, 3_600_000_000L, SysTime(dtAD, hnsecs(274)));
        testST(beforeAD, 600_000_000L, SysTime(dtAD, hnsecs(274)));
        testST(beforeAD, 36_000_000_000L, SysTime(dtAD, hnsecs(274)));

        testST(beforeAD, -1, SysTime(dtAD, hnsecs(273)));
        testST(beforeAD, -2, SysTime(dtAD, hnsecs(272)));
        testST(beforeAD, -10, SysTime(dtAD, hnsecs(264)));
        testST(beforeAD, -100, SysTime(dtAD, hnsecs(174)));
        testST(beforeAD, -274, SysTime(dtAD));
        testST(beforeAD, -275, SysTime(dtAD, hnsecs(9_999_999)));
        testST(beforeAD, -1000, SysTime(dtAD, hnsecs(9_999_274)));
        testST(beforeAD, -1001, SysTime(dtAD, hnsecs(9_999_273)));
        testST(beforeAD, -2000, SysTime(dtAD, hnsecs(9_998_274)));
        testST(beforeAD, -33_274, SysTime(dtAD, hnsecs(9_967_000)));
        testST(beforeAD, -33_275, SysTime(dtAD, hnsecs(9_966_999)));
        testST(beforeAD, -1_833_274, SysTime(dtAD, hnsecs(8_167_000)));
        testST(beforeAD, -1_833_275, SysTime(dtAD, hnsecs(8_166_999)));
        testST(beforeAD, -1_000_000, SysTime(dtAD, hnsecs(9_000_274)));
        testST(beforeAD, -60_000_000L, SysTime(dtAD, hnsecs(274)));
        testST(beforeAD, -3_600_000_000L, SysTime(dtAD, hnsecs(274)));
        testST(beforeAD, -600_000_000L, SysTime(dtAD, hnsecs(274)));
        testST(beforeAD, -36_000_000_000L, SysTime(dtAD, hnsecs(274)));

        // Test B.C.
        auto dtBC = DateTime(-1999, 7, 6, 12, 30, 33);
        auto beforeBC = SysTime(dtBC, hnsecs(274));
        testST(beforeBC, 0, SysTime(dtBC, hnsecs(274)));
        testST(beforeBC, 1, SysTime(dtBC, hnsecs(275)));
        testST(beforeBC, 2, SysTime(dtBC, hnsecs(276)));
        testST(beforeBC, 10, SysTime(dtBC, hnsecs(284)));
        testST(beforeBC, 100, SysTime(dtBC, hnsecs(374)));
        testST(beforeBC, 725, SysTime(dtBC, hnsecs(999)));
        testST(beforeBC, 726, SysTime(dtBC, hnsecs(1000)));
        testST(beforeBC, 1000, SysTime(dtBC, hnsecs(1274)));
        testST(beforeBC, 1001, SysTime(dtBC, hnsecs(1275)));
        testST(beforeBC, 2000, SysTime(dtBC, hnsecs(2274)));
        testST(beforeBC, 26_725, SysTime(dtBC, hnsecs(26_999)));
        testST(beforeBC, 26_726, SysTime(dtBC, hnsecs(27_000)));
        testST(beforeBC, 26_727, SysTime(dtBC, hnsecs(27_001)));
        testST(beforeBC, 1_766_725, SysTime(dtBC, hnsecs(1_766_999)));
        testST(beforeBC, 1_766_726, SysTime(dtBC, hnsecs(1_767_000)));
        testST(beforeBC, 1_000_000, SysTime(dtBC, hnsecs(1_000_274)));
        testST(beforeBC, 60_000_000L, SysTime(dtBC, hnsecs(274)));
        testST(beforeBC, 3_600_000_000L, SysTime(dtBC, hnsecs(274)));
        testST(beforeBC, 600_000_000L, SysTime(dtBC, hnsecs(274)));
        testST(beforeBC, 36_000_000_000L, SysTime(dtBC, hnsecs(274)));

        testST(beforeBC, -1, SysTime(dtBC, hnsecs(273)));
        testST(beforeBC, -2, SysTime(dtBC, hnsecs(272)));
        testST(beforeBC, -10, SysTime(dtBC, hnsecs(264)));
        testST(beforeBC, -100, SysTime(dtBC, hnsecs(174)));
        testST(beforeBC, -274, SysTime(dtBC));
        testST(beforeBC, -275, SysTime(dtBC, hnsecs(9_999_999)));
        testST(beforeBC, -1000, SysTime(dtBC, hnsecs(9_999_274)));
        testST(beforeBC, -1001, SysTime(dtBC, hnsecs(9_999_273)));
        testST(beforeBC, -2000, SysTime(dtBC, hnsecs(9_998_274)));
        testST(beforeBC, -33_274, SysTime(dtBC, hnsecs(9_967_000)));
        testST(beforeBC, -33_275, SysTime(dtBC, hnsecs(9_966_999)));
        testST(beforeBC, -1_833_274, SysTime(dtBC, hnsecs(8_167_000)));
        testST(beforeBC, -1_833_275, SysTime(dtBC, hnsecs(8_166_999)));
        testST(beforeBC, -1_000_000, SysTime(dtBC, hnsecs(9_000_274)));
        testST(beforeBC, -60_000_000L, SysTime(dtBC, hnsecs(274)));
        testST(beforeBC, -3_600_000_000L, SysTime(dtBC, hnsecs(274)));
        testST(beforeBC, -600_000_000L, SysTime(dtBC, hnsecs(274)));
        testST(beforeBC, -36_000_000_000L, SysTime(dtBC, hnsecs(274)));

        // Test Both
        auto dtBoth1 = DateTime(1, 1, 1, 0, 0, 0);
        auto beforeBoth1 = SysTime(dtBoth1);
        testST(beforeBoth1, 1, SysTime(dtBoth1, hnsecs(1)));
        testST(beforeBoth1, 0, SysTime(dtBoth1));
        testST(beforeBoth1, -1, SysTime(dtBoth1, hnsecs(9_999_999)));
        testST(beforeBoth1, -2, SysTime(dtBoth1, hnsecs(9_999_998)));
        testST(beforeBoth1, -1000, SysTime(dtBoth1, hnsecs(9_999_000)));
        testST(beforeBoth1, -2000, SysTime(dtBoth1, hnsecs(9_998_000)));
        testST(beforeBoth1, -2555, SysTime(dtBoth1, hnsecs(9_997_445)));
        testST(beforeBoth1, -1_000_000, SysTime(dtBoth1, hnsecs(9_000_000)));
        testST(beforeBoth1, -2_000_000, SysTime(dtBoth1, hnsecs(8_000_000)));
        testST(beforeBoth1, -2_333_333, SysTime(dtBoth1, hnsecs(7_666_667)));
        testST(beforeBoth1, -10_000_000, SysTime(dtBoth1));
        testST(beforeBoth1, -20_000_000, SysTime(dtBoth1));
        testST(beforeBoth1, -20_888_888, SysTime(dtBoth1, hnsecs(9_111_112)));

        auto dtBoth2 = DateTime(0, 12, 31, 23, 59, 59);
        auto beforeBoth2 = SysTime(dtBoth2, hnsecs(9_999_999));
        testST(beforeBoth2, -1, SysTime(dtBoth2, hnsecs(9_999_998)));
        testST(beforeBoth2, 0, SysTime(dtBoth2, hnsecs(9_999_999)));
        testST(beforeBoth2, 1, SysTime(dtBoth2));
        testST(beforeBoth2, 2, SysTime(dtBoth2, hnsecs(1)));
        testST(beforeBoth2, 1000, SysTime(dtBoth2, hnsecs(999)));
        testST(beforeBoth2, 2000, SysTime(dtBoth2, hnsecs(1999)));
        testST(beforeBoth2, 2555, SysTime(dtBoth2, hnsecs(2554)));
        testST(beforeBoth2, 1_000_000, SysTime(dtBoth2, hnsecs(999_999)));
        testST(beforeBoth2, 2_000_000, SysTime(dtBoth2, hnsecs(1_999_999)));
        testST(beforeBoth2, 2_333_333, SysTime(dtBoth2, hnsecs(2_333_332)));
        testST(beforeBoth2, 10_000_000, SysTime(dtBoth2, hnsecs(9_999_999)));
        testST(beforeBoth2, 20_000_000, SysTime(dtBoth2, hnsecs(9_999_999)));
        testST(beforeBoth2, 20_888_888, SysTime(dtBoth2, hnsecs(888_887)));

        {
            auto st = SysTime(dtBoth2, hnsecs(9_999_999));
            st.roll!"hnsecs"(70_777_222).roll!"hnsecs"(-222_555_292);
            assert(st == SysTime(dtBoth2, hnsecs(8_221_929)));
        }

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.roll!"hnsecs"(4)));
        //static assert(!__traits(compiles, ist.roll!"hnsecs"(4)));
    }


    /++
        Gives the result of adding or subtracting a $(REF Duration, core,time) from
        this $(LREF SysTime).

        The legal types of arithmetic for $(LREF SysTime) using this operator
        are

        $(BOOKTABLE,
        $(TR $(TD SysTime) $(TD +) $(TD Duration) $(TD -->) $(TD SysTime))
        $(TR $(TD SysTime) $(TD -) $(TD Duration) $(TD -->) $(TD SysTime))
        )

        Params:
            duration = The $(REF Duration, core,time) to add to or subtract from
                       this $(LREF SysTime).
      +/
    SysTime opBinary(string op)(Duration duration) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        SysTime retval = SysTime(this._stdTime, this._timezone);
        immutable hnsecs = duration.total!"hnsecs";
        mixin("retval._stdTime " ~ op ~ "= hnsecs;");
        return retval;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(2015, 12, 31, 23, 59, 59)) + seconds(1) ==
               SysTime(DateTime(2016, 1, 1, 0, 0, 0)));

        assert(SysTime(DateTime(2015, 12, 31, 23, 59, 59)) + hours(1) ==
               SysTime(DateTime(2016, 1, 1, 0, 59, 59)));

        assert(SysTime(DateTime(2016, 1, 1, 0, 0, 0)) - seconds(1) ==
               SysTime(DateTime(2015, 12, 31, 23, 59, 59)));

        assert(SysTime(DateTime(2016, 1, 1, 0, 59, 59)) - hours(1) ==
               SysTime(DateTime(2015, 12, 31, 23, 59, 59)));
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_678));

        assert(st + dur!"weeks"(7) == SysTime(DateTime(1999, 8, 24, 12, 30, 33), hnsecs(2_345_678)));
        assert(st + dur!"weeks"(-7) == SysTime(DateTime(1999, 5, 18, 12, 30, 33), hnsecs(2_345_678)));
        assert(st + dur!"days"(7) == SysTime(DateTime(1999, 7, 13, 12, 30, 33), hnsecs(2_345_678)));
        assert(st + dur!"days"(-7) == SysTime(DateTime(1999, 6, 29, 12, 30, 33), hnsecs(2_345_678)));
        assert(st + dur!"hours"(7) == SysTime(DateTime(1999, 7, 6, 19, 30, 33), hnsecs(2_345_678)));
        assert(st + dur!"hours"(-7) == SysTime(DateTime(1999, 7, 6, 5, 30, 33), hnsecs(2_345_678)));
        assert(st + dur!"minutes"(7) == SysTime(DateTime(1999, 7, 6, 12, 37, 33), hnsecs(2_345_678)));
        assert(st + dur!"minutes"(-7) == SysTime(DateTime(1999, 7, 6, 12, 23, 33), hnsecs(2_345_678)));
        assert(st + dur!"seconds"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 40), hnsecs(2_345_678)));
        assert(st + dur!"seconds"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 26), hnsecs(2_345_678)));
        assert(st + dur!"msecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_415_678)));
        assert(st + dur!"msecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_275_678)));
        assert(st + dur!"usecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_748)));
        assert(st + dur!"usecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_608)));
        assert(st + dur!"hnsecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_685)));
        assert(st + dur!"hnsecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_671)));

        assert(st - dur!"weeks"(-7) == SysTime(DateTime(1999, 8, 24, 12, 30, 33), hnsecs(2_345_678)));
        assert(st - dur!"weeks"(7) == SysTime(DateTime(1999, 5, 18, 12, 30, 33), hnsecs(2_345_678)));
        assert(st - dur!"days"(-7) == SysTime(DateTime(1999, 7, 13, 12, 30, 33), hnsecs(2_345_678)));
        assert(st - dur!"days"(7) == SysTime(DateTime(1999, 6, 29, 12, 30, 33), hnsecs(2_345_678)));
        assert(st - dur!"hours"(-7) == SysTime(DateTime(1999, 7, 6, 19, 30, 33), hnsecs(2_345_678)));
        assert(st - dur!"hours"(7) == SysTime(DateTime(1999, 7, 6, 5, 30, 33), hnsecs(2_345_678)));
        assert(st - dur!"minutes"(-7) == SysTime(DateTime(1999, 7, 6, 12, 37, 33), hnsecs(2_345_678)));
        assert(st - dur!"minutes"(7) == SysTime(DateTime(1999, 7, 6, 12, 23, 33), hnsecs(2_345_678)));
        assert(st - dur!"seconds"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 40), hnsecs(2_345_678)));
        assert(st - dur!"seconds"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 26), hnsecs(2_345_678)));
        assert(st - dur!"msecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_415_678)));
        assert(st - dur!"msecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_275_678)));
        assert(st - dur!"usecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_748)));
        assert(st - dur!"usecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_608)));
        assert(st - dur!"hnsecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_685)));
        assert(st - dur!"hnsecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_671)));

        static void testST(in SysTime orig, long hnsecs, in SysTime expected, size_t line = __LINE__)
        {
            auto result = orig + dur!"hnsecs"(hnsecs);
            if (result != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", result, expected), __FILE__, line);
        }

        // Test A.D.
        auto beforeAD = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(274));
        testST(beforeAD, 0, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(274)));
        testST(beforeAD, 1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(275)));
        testST(beforeAD, 2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(276)));
        testST(beforeAD, 10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(284)));
        testST(beforeAD, 100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(374)));
        testST(beforeAD, 725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(999)));
        testST(beforeAD, 726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1000)));
        testST(beforeAD, 1000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1274)));
        testST(beforeAD, 1001, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1275)));
        testST(beforeAD, 2000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2274)));
        testST(beforeAD, 26_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(26_999)));
        testST(beforeAD, 26_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(27_000)));
        testST(beforeAD, 26_727, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(27_001)));
        testST(beforeAD, 1_766_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1_766_999)));
        testST(beforeAD, 1_766_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1_767_000)));
        testST(beforeAD, 1_000_000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1_000_274)));
        testST(beforeAD, 60_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 39), hnsecs(274)));
        testST(beforeAD, 3_600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 36, 33), hnsecs(274)));
        testST(beforeAD, 600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 31, 33), hnsecs(274)));
        testST(beforeAD, 36_000_000_000L, SysTime(DateTime(1999, 7, 6, 13, 30, 33), hnsecs(274)));

        testST(beforeAD, -1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(273)));
        testST(beforeAD, -2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(272)));
        testST(beforeAD, -10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(264)));
        testST(beforeAD, -100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(174)));
        testST(beforeAD, -274, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, -275, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_999)));
        testST(beforeAD, -1000, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_274)));
        testST(beforeAD, -1001, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_273)));
        testST(beforeAD, -2000, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_998_274)));
        testST(beforeAD, -33_274, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_967_000)));
        testST(beforeAD, -33_275, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_966_999)));
        testST(beforeAD, -1_833_274, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(8_167_000)));
        testST(beforeAD, -1_833_275, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(8_166_999)));
        testST(beforeAD, -1_000_000, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_000_274)));
        testST(beforeAD, -60_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 27), hnsecs(274)));
        testST(beforeAD, -3_600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 24, 33), hnsecs(274)));
        testST(beforeAD, -600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 29, 33), hnsecs(274)));
        testST(beforeAD, -36_000_000_000L, SysTime(DateTime(1999, 7, 6, 11, 30, 33), hnsecs(274)));

        // Test B.C.
        auto beforeBC = SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(274));
        testST(beforeBC, 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(274)));
        testST(beforeBC, 1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(275)));
        testST(beforeBC, 2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(276)));
        testST(beforeBC, 10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(284)));
        testST(beforeBC, 100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(374)));
        testST(beforeBC, 725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(999)));
        testST(beforeBC, 726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1000)));
        testST(beforeBC, 1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1274)));
        testST(beforeBC, 1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1275)));
        testST(beforeBC, 2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(2274)));
        testST(beforeBC, 26_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(26_999)));
        testST(beforeBC, 26_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(27_000)));
        testST(beforeBC, 26_727, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(27_001)));
        testST(beforeBC, 1_766_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1_766_999)));
        testST(beforeBC, 1_766_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1_767_000)));
        testST(beforeBC, 1_000_000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1_000_274)));
        testST(beforeBC, 60_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 39), hnsecs(274)));
        testST(beforeBC, 3_600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 36, 33), hnsecs(274)));
        testST(beforeBC, 600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 31, 33), hnsecs(274)));
        testST(beforeBC, 36_000_000_000L, SysTime(DateTime(-1999, 7, 6, 13, 30, 33), hnsecs(274)));

        testST(beforeBC, -1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(273)));
        testST(beforeBC, -2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(272)));
        testST(beforeBC, -10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(264)));
        testST(beforeBC, -100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(174)));
        testST(beforeBC, -274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, -275, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_999_999)));
        testST(beforeBC, -1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_999_274)));
        testST(beforeBC, -1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_999_273)));
        testST(beforeBC, -2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_998_274)));
        testST(beforeBC, -33_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_967_000)));
        testST(beforeBC, -33_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_966_999)));
        testST(beforeBC, -1_833_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(8_167_000)));
        testST(beforeBC, -1_833_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(8_166_999)));
        testST(beforeBC, -1_000_000, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_000_274)));
        testST(beforeBC, -60_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 27), hnsecs(274)));
        testST(beforeBC, -3_600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 24, 33), hnsecs(274)));
        testST(beforeBC, -600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 29, 33), hnsecs(274)));
        testST(beforeBC, -36_000_000_000L, SysTime(DateTime(-1999, 7, 6, 11, 30, 33), hnsecs(274)));

        // Test Both
        auto beforeBoth1 = SysTime(DateTime(1, 1, 1, 0, 0, 0));
        testST(beforeBoth1, 1, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)));
        testST(beforeBoth1, 0, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth1, -2, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_998)));
        testST(beforeBoth1, -1000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_000)));
        testST(beforeBoth1, -2000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_998_000)));
        testST(beforeBoth1, -2555, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_997_445)));
        testST(beforeBoth1, -1_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_000_000)));
        testST(beforeBoth1, -2_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(8_000_000)));
        testST(beforeBoth1, -2_333_333, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(7_666_667)));
        testST(beforeBoth1, -10_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59)));
        testST(beforeBoth1, -20_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 58)));
        testST(beforeBoth1, -20_888_888, SysTime(DateTime(0, 12, 31, 23, 59, 57), hnsecs(9_111_112)));

        auto beforeBoth2 = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
        testST(beforeBoth2, -1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_998)));
        testST(beforeBoth2, 0, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 1, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth2, 2, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)));
        testST(beforeBoth2, 1000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(999)));
        testST(beforeBoth2, 2000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1999)));
        testST(beforeBoth2, 2555, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(2554)));
        testST(beforeBoth2, 1_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(999_999)));
        testST(beforeBoth2, 2_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1_999_999)));
        testST(beforeBoth2, 2_333_333, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(2_333_332)));
        testST(beforeBoth2, 10_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        testST(beforeBoth2, 20_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 1), hnsecs(9_999_999)));
        testST(beforeBoth2, 20_888_888, SysTime(DateTime(1, 1, 1, 0, 0, 2), hnsecs(888_887)));

        auto duration = dur!"seconds"(12);
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst + duration == SysTime(DateTime(1999, 7, 6, 12, 30, 45)));
        //assert(ist + duration == SysTime(DateTime(1999, 7, 6, 12, 30, 45)));
        assert(cst - duration == SysTime(DateTime(1999, 7, 6, 12, 30, 21)));
        //assert(ist - duration == SysTime(DateTime(1999, 7, 6, 12, 30, 21)));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    SysTime opBinary(string op)(TickDuration td) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        SysTime retval = SysTime(this._stdTime, this._timezone);
        immutable hnsecs = td.hnsecs;
        mixin("retval._stdTime " ~ op ~ "= hnsecs;");
        return retval;
    }

    deprecated @safe unittest
    {
        // This probably only runs in cases where gettimeofday() is used, but it's
        // hard to do this test correctly with variable ticksPerSec.
        if (TickDuration.ticksPerSec == 1_000_000)
        {
            auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_678));

            assert(st + TickDuration.from!"usecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_748)));
            assert(st + TickDuration.from!"usecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_608)));

            assert(st - TickDuration.from!"usecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_748)));
            assert(st - TickDuration.from!"usecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_608)));
        }
    }


    /++
        Gives the result of adding or subtracting a $(REF Duration, core,time) from
        this $(LREF SysTime), as well as assigning the result to this
        $(LREF SysTime).

        The legal types of arithmetic for $(LREF SysTime) using this operator are

        $(BOOKTABLE,
        $(TR $(TD SysTime) $(TD +) $(TD Duration) $(TD -->) $(TD SysTime))
        $(TR $(TD SysTime) $(TD -) $(TD Duration) $(TD -->) $(TD SysTime))
        )

        Params:
            duration = The $(REF Duration, core,time) to add to or subtract from
                       this $(LREF SysTime).
      +/
    ref SysTime opOpAssign(string op)(Duration duration) @safe pure nothrow
        if (op == "+" || op == "-")
    {
        immutable hnsecs = duration.total!"hnsecs";
        mixin("_stdTime " ~ op ~ "= hnsecs;");
        return this;
    }

    @safe unittest
    {
        auto before = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(before + dur!"weeks"(7) == SysTime(DateTime(1999, 8, 24, 12, 30, 33)));
        assert(before + dur!"weeks"(-7) == SysTime(DateTime(1999, 5, 18, 12, 30, 33)));
        assert(before + dur!"days"(7) == SysTime(DateTime(1999, 7, 13, 12, 30, 33)));
        assert(before + dur!"days"(-7) == SysTime(DateTime(1999, 6, 29, 12, 30, 33)));

        assert(before + dur!"hours"(7) == SysTime(DateTime(1999, 7, 6, 19, 30, 33)));
        assert(before + dur!"hours"(-7) == SysTime(DateTime(1999, 7, 6, 5, 30, 33)));
        assert(before + dur!"minutes"(7) == SysTime(DateTime(1999, 7, 6, 12, 37, 33)));
        assert(before + dur!"minutes"(-7) == SysTime(DateTime(1999, 7, 6, 12, 23, 33)));
        assert(before + dur!"seconds"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 40)));
        assert(before + dur!"seconds"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 26)));
        assert(before + dur!"msecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(7)));
        assert(before + dur!"msecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 32), msecs(993)));
        assert(before + dur!"usecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(7)));
        assert(before + dur!"usecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 32), usecs(999_993)));
        assert(before + dur!"hnsecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(7)));
        assert(before + dur!"hnsecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_993)));

        assert(before - dur!"weeks"(-7) == SysTime(DateTime(1999, 8, 24, 12, 30, 33)));
        assert(before - dur!"weeks"(7) == SysTime(DateTime(1999, 5, 18, 12, 30, 33)));
        assert(before - dur!"days"(-7) == SysTime(DateTime(1999, 7, 13, 12, 30, 33)));
        assert(before - dur!"days"(7) == SysTime(DateTime(1999, 6, 29, 12, 30, 33)));

        assert(before - dur!"hours"(-7) == SysTime(DateTime(1999, 7, 6, 19, 30, 33)));
        assert(before - dur!"hours"(7) == SysTime(DateTime(1999, 7, 6, 5, 30, 33)));
        assert(before - dur!"minutes"(-7) == SysTime(DateTime(1999, 7, 6, 12, 37, 33)));
        assert(before - dur!"minutes"(7) == SysTime(DateTime(1999, 7, 6, 12, 23, 33)));
        assert(before - dur!"seconds"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 40)));
        assert(before - dur!"seconds"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 26)));
        assert(before - dur!"msecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), msecs(7)));
        assert(before - dur!"msecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 32), msecs(993)));
        assert(before - dur!"usecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), usecs(7)));
        assert(before - dur!"usecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 32), usecs(999_993)));
        assert(before - dur!"hnsecs"(-7) == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(7)));
        assert(before - dur!"hnsecs"(7) == SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_993)));

        static void testST(SysTime orig, long hnsecs, in SysTime expected, size_t line = __LINE__)
        {
            auto r = orig += dur!"hnsecs"(hnsecs);
            if (orig != expected)
                throw new AssertError(format("Failed 1. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
            if (r != expected)
                throw new AssertError(format("Failed 2. actual [%s] != expected [%s]", r, expected), __FILE__, line);
        }

        // Test A.D.
        auto beforeAD = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(274));
        testST(beforeAD, 0, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(274)));
        testST(beforeAD, 1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(275)));
        testST(beforeAD, 2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(276)));
        testST(beforeAD, 10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(284)));
        testST(beforeAD, 100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(374)));
        testST(beforeAD, 725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(999)));
        testST(beforeAD, 726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1000)));
        testST(beforeAD, 1000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1274)));
        testST(beforeAD, 1001, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1275)));
        testST(beforeAD, 2000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2274)));
        testST(beforeAD, 26_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(26_999)));
        testST(beforeAD, 26_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(27_000)));
        testST(beforeAD, 26_727, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(27_001)));
        testST(beforeAD, 1_766_725, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1_766_999)));
        testST(beforeAD, 1_766_726, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1_767_000)));
        testST(beforeAD, 1_000_000, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(1_000_274)));
        testST(beforeAD, 60_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 39), hnsecs(274)));
        testST(beforeAD, 3_600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 36, 33), hnsecs(274)));
        testST(beforeAD, 600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 31, 33), hnsecs(274)));
        testST(beforeAD, 36_000_000_000L, SysTime(DateTime(1999, 7, 6, 13, 30, 33), hnsecs(274)));

        testST(beforeAD, -1, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(273)));
        testST(beforeAD, -2, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(272)));
        testST(beforeAD, -10, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(264)));
        testST(beforeAD, -100, SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(174)));
        testST(beforeAD, -274, SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        testST(beforeAD, -275, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_999)));
        testST(beforeAD, -1000, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_274)));
        testST(beforeAD, -1001, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_999_273)));
        testST(beforeAD, -2000, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_998_274)));
        testST(beforeAD, -33_274, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_967_000)));
        testST(beforeAD, -33_275, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_966_999)));
        testST(beforeAD, -1_833_274, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(8_167_000)));
        testST(beforeAD, -1_833_275, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(8_166_999)));
        testST(beforeAD, -1_000_000, SysTime(DateTime(1999, 7, 6, 12, 30, 32), hnsecs(9_000_274)));
        testST(beforeAD, -60_000_000L, SysTime(DateTime(1999, 7, 6, 12, 30, 27), hnsecs(274)));
        testST(beforeAD, -3_600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 24, 33), hnsecs(274)));
        testST(beforeAD, -600_000_000L, SysTime(DateTime(1999, 7, 6, 12, 29, 33), hnsecs(274)));
        testST(beforeAD, -36_000_000_000L, SysTime(DateTime(1999, 7, 6, 11, 30, 33), hnsecs(274)));

        // Test B.C.
        auto beforeBC = SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(274));
        testST(beforeBC, 0, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(274)));
        testST(beforeBC, 1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(275)));
        testST(beforeBC, 2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(276)));
        testST(beforeBC, 10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(284)));
        testST(beforeBC, 100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(374)));
        testST(beforeBC, 725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(999)));
        testST(beforeBC, 726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1000)));
        testST(beforeBC, 1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1274)));
        testST(beforeBC, 1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1275)));
        testST(beforeBC, 2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(2274)));
        testST(beforeBC, 26_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(26_999)));
        testST(beforeBC, 26_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(27_000)));
        testST(beforeBC, 26_727, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(27_001)));
        testST(beforeBC, 1_766_725, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1_766_999)));
        testST(beforeBC, 1_766_726, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1_767_000)));
        testST(beforeBC, 1_000_000, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(1_000_274)));
        testST(beforeBC, 60_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 39), hnsecs(274)));
        testST(beforeBC, 3_600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 36, 33), hnsecs(274)));
        testST(beforeBC, 600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 31, 33), hnsecs(274)));
        testST(beforeBC, 36_000_000_000L, SysTime(DateTime(-1999, 7, 6, 13, 30, 33), hnsecs(274)));

        testST(beforeBC, -1, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(273)));
        testST(beforeBC, -2, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(272)));
        testST(beforeBC, -10, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(264)));
        testST(beforeBC, -100, SysTime(DateTime(-1999, 7, 6, 12, 30, 33), hnsecs(174)));
        testST(beforeBC, -274, SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        testST(beforeBC, -275, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_999_999)));
        testST(beforeBC, -1000, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_999_274)));
        testST(beforeBC, -1001, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_999_273)));
        testST(beforeBC, -2000, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_998_274)));
        testST(beforeBC, -33_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_967_000)));
        testST(beforeBC, -33_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_966_999)));
        testST(beforeBC, -1_833_274, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(8_167_000)));
        testST(beforeBC, -1_833_275, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(8_166_999)));
        testST(beforeBC, -1_000_000, SysTime(DateTime(-1999, 7, 6, 12, 30, 32), hnsecs(9_000_274)));
        testST(beforeBC, -60_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 30, 27), hnsecs(274)));
        testST(beforeBC, -3_600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 24, 33), hnsecs(274)));
        testST(beforeBC, -600_000_000L, SysTime(DateTime(-1999, 7, 6, 12, 29, 33), hnsecs(274)));
        testST(beforeBC, -36_000_000_000L, SysTime(DateTime(-1999, 7, 6, 11, 30, 33), hnsecs(274)));

        // Test Both
        auto beforeBoth1 = SysTime(DateTime(1, 1, 1, 0, 0, 0));
        testST(beforeBoth1, 1, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)));
        testST(beforeBoth1, 0, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth1, -1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth1, -2, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_998)));
        testST(beforeBoth1, -1000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_000)));
        testST(beforeBoth1, -2000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_998_000)));
        testST(beforeBoth1, -2555, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_997_445)));
        testST(beforeBoth1, -1_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_000_000)));
        testST(beforeBoth1, -2_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(8_000_000)));
        testST(beforeBoth1, -2_333_333, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(7_666_667)));
        testST(beforeBoth1, -10_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 59)));
        testST(beforeBoth1, -20_000_000, SysTime(DateTime(0, 12, 31, 23, 59, 58)));
        testST(beforeBoth1, -20_888_888, SysTime(DateTime(0, 12, 31, 23, 59, 57), hnsecs(9_111_112)));

        auto beforeBoth2 = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
        testST(beforeBoth2, -1, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_998)));
        testST(beforeBoth2, 0, SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(beforeBoth2, 1, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(beforeBoth2, 2, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)));
        testST(beforeBoth2, 1000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(999)));
        testST(beforeBoth2, 2000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1999)));
        testST(beforeBoth2, 2555, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(2554)));
        testST(beforeBoth2, 1_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(999_999)));
        testST(beforeBoth2, 2_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1_999_999)));
        testST(beforeBoth2, 2_333_333, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(2_333_332)));
        testST(beforeBoth2, 10_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        testST(beforeBoth2, 20_000_000, SysTime(DateTime(1, 1, 1, 0, 0, 1), hnsecs(9_999_999)));
        testST(beforeBoth2, 20_888_888, SysTime(DateTime(1, 1, 1, 0, 0, 2), hnsecs(888_887)));

        {
            auto st = SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999));
            (st += dur!"hnsecs"(52)) += dur!"seconds"(-907);
            assert(st == SysTime(DateTime(0, 12, 31, 23, 44, 53), hnsecs(51)));
        }

        auto duration = dur!"seconds"(12);
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst += duration));
        //static assert(!__traits(compiles, ist += duration));
        static assert(!__traits(compiles, cst -= duration));
        //static assert(!__traits(compiles, ist -= duration));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    ref SysTime opOpAssign(string op)(TickDuration td) @safe pure nothrow
        if (op == "+" || op == "-")
    {
        immutable hnsecs = td.hnsecs;
        mixin("_stdTime " ~ op ~ "= hnsecs;");
        return this;
    }

    deprecated @safe unittest
    {
        // This probably only runs in cases where gettimeofday() is used, but it's
        // hard to do this test correctly with variable ticksPerSec.
        if (TickDuration.ticksPerSec == 1_000_000)
        {
            {
                auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_678));
                st += TickDuration.from!"usecs"(7);
                assert(st == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_748)));
            }
            {
                auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_678));
                st += TickDuration.from!"usecs"(-7);
                assert(st == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_608)));
            }

            {
                auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_678));
                st -= TickDuration.from!"usecs"(-7);
                assert(st == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_748)));
            }
            {
                auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_678));
                st -= TickDuration.from!"usecs"(7);
                assert(st == SysTime(DateTime(1999, 7, 6, 12, 30, 33), hnsecs(2_345_608)));
            }
        }
    }


    /++
        Gives the difference between two $(LREF SysTime)s.

        The legal types of arithmetic for $(LREF SysTime) using this operator are

        $(BOOKTABLE,
        $(TR $(TD SysTime) $(TD -) $(TD SysTime) $(TD -->) $(TD duration))
        )
      +/
    Duration opBinary(string op)(in SysTime rhs) @safe const pure nothrow
        if (op == "-")
    {
        return dur!"hnsecs"(_stdTime - rhs._stdTime);
    }

    @safe unittest
    {
        assert(SysTime(DateTime(1999, 7, 6, 12, 30, 33)) - SysTime(DateTime(1998, 7, 6, 12, 30, 33)) ==
               dur!"seconds"(31_536_000));
        assert(SysTime(DateTime(1998, 7, 6, 12, 30, 33)) - SysTime(DateTime(1999, 7, 6, 12, 30, 33)) ==
               dur!"seconds"(-31_536_000));

        assert(SysTime(DateTime(1999, 8, 6, 12, 30, 33)) - SysTime(DateTime(1999, 7, 6, 12, 30, 33)) ==
               dur!"seconds"(26_78_400));
        assert(SysTime(DateTime(1999, 7, 6, 12, 30, 33)) - SysTime(DateTime(1999, 8, 6, 12, 30, 33)) ==
               dur!"seconds"(-26_78_400));

        assert(SysTime(DateTime(1999, 7, 6, 12, 30, 33)) - SysTime(DateTime(1999, 7, 5, 12, 30, 33)) ==
               dur!"seconds"(86_400));
        assert(SysTime(DateTime(1999, 7, 5, 12, 30, 33)) - SysTime(DateTime(1999, 7, 6, 12, 30, 33)) ==
               dur!"seconds"(-86_400));

        assert(SysTime(DateTime(1999, 7, 6, 12, 30, 33)) - SysTime(DateTime(1999, 7, 6, 11, 30, 33)) ==
               dur!"seconds"(3600));
        assert(SysTime(DateTime(1999, 7, 6, 11, 30, 33)) - SysTime(DateTime(1999, 7, 6, 12, 30, 33)) ==
               dur!"seconds"(-3600));

        assert(SysTime(DateTime(1999, 7, 6, 12, 31, 33)) - SysTime(DateTime(1999, 7, 6, 12, 30, 33)) ==
               dur!"seconds"(60));
        assert(SysTime(DateTime(1999, 7, 6, 12, 30, 33)) - SysTime(DateTime(1999, 7, 6, 12, 31, 33)) ==
               dur!"seconds"(-60));

        assert(SysTime(DateTime(1999, 7, 6, 12, 30, 34)) - SysTime(DateTime(1999, 7, 6, 12, 30, 33)) ==
               dur!"seconds"(1));
        assert(SysTime(DateTime(1999, 7, 6, 12, 30, 33)) - SysTime(DateTime(1999, 7, 6, 12, 30, 34)) ==
               dur!"seconds"(-1));

        {
            auto dt = DateTime(1999, 7, 6, 12, 30, 33);
            assert(SysTime(dt, msecs(532)) - SysTime(dt) == msecs(532));
            assert(SysTime(dt) - SysTime(dt, msecs(532)) == msecs(-532));

            assert(SysTime(dt, usecs(333_347)) - SysTime(dt) == usecs(333_347));
            assert(SysTime(dt) - SysTime(dt, usecs(333_347)) == usecs(-333_347));

            assert(SysTime(dt, hnsecs(1_234_567)) - SysTime(dt) == hnsecs(1_234_567));
            assert(SysTime(dt) - SysTime(dt, hnsecs(1_234_567)) == hnsecs(-1_234_567));
        }

        assert(SysTime(DateTime(1, 1, 1, 12, 30, 33)) - SysTime(DateTime(1, 1, 1, 0, 0, 0)) == dur!"seconds"(45033));
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0)) - SysTime(DateTime(1, 1, 1, 12, 30, 33)) == dur!"seconds"(-45033));
        assert(SysTime(DateTime(0, 12, 31, 12, 30, 33)) - SysTime(DateTime(1, 1, 1, 0, 0, 0)) == dur!"seconds"(-41367));
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0)) - SysTime(DateTime(0, 12, 31, 12, 30, 33)) == dur!"seconds"(41367));

        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0)) - SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)) ==
               dur!"hnsecs"(1));
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)) - SysTime(DateTime(1, 1, 1, 0, 0, 0)) ==
               dur!"hnsecs"(-1));

        version(Posix)
            immutable tz = PosixTimeZone.getTimeZone("America/Los_Angeles");
        else version(Windows)
            immutable tz = WindowsTimeZone.getTimeZone("Pacific Standard Time");

        {
            auto dt = DateTime(2011, 1, 13, 8, 17, 2);
            auto d = msecs(296);
            assert(SysTime(dt, d, tz) - SysTime(dt, d, tz) == Duration.zero);
            assert(SysTime(dt, d, tz) - SysTime(dt, d, UTC()) == hours(8));
            assert(SysTime(dt, d, UTC()) - SysTime(dt, d, tz) == hours(-8));
        }

        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(st - st == Duration.zero);
        assert(cst - st == Duration.zero);
        //assert(ist - st == Duration.zero);

        assert(st - cst == Duration.zero);
        assert(cst - cst == Duration.zero);
        //assert(ist - cst == Duration.zero);

        //assert(st - ist == Duration.zero);
        //assert(cst - ist == Duration.zero);
        //assert(ist - ist == Duration.zero);
    }


    /++
        Returns the difference between the two $(LREF SysTime)s in months.

        To get the difference in years, subtract the year property
        of two $(LREF SysTime)s. To get the difference in days or weeks,
        subtract the $(LREF SysTime)s themselves and use the $(REF Duration, core,time)
        that results. Because converting between months and smaller
        units requires a specific date (which $(REF Duration, core,time)s don't have),
        getting the difference in months requires some math using both
        the year and month properties, so this is a convenience function for
        getting the difference in months.

        Note that the number of days in the months or how far into the month
        either date is is irrelevant. It is the difference in the month property
        combined with the difference in years * 12. So, for instance,
        December 31st and January 1st are one month apart just as December 1st
        and January 31st are one month apart.

        Params:
            rhs = The $(LREF SysTime) to subtract from this one.
      +/
    int diffMonths(in SysTime rhs) @safe const nothrow
    {
        return (cast(Date) this).diffMonths(cast(Date) rhs);
    }

    ///
    @safe unittest
    {
        assert(SysTime(Date(1999, 2, 1)).diffMonths(
                   SysTime(Date(1999, 1, 31))) == 1);

        assert(SysTime(Date(1999, 1, 31)).diffMonths(
                   SysTime(Date(1999, 2, 1))) == -1);

        assert(SysTime(Date(1999, 3, 1)).diffMonths(
                   SysTime(Date(1999, 1, 1))) == 2);

        assert(SysTime(Date(1999, 1, 1)).diffMonths(
                   SysTime(Date(1999, 3, 31))) == -2);
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(st.diffMonths(st) == 0);
        assert(cst.diffMonths(st) == 0);
        //assert(ist.diffMonths(st) == 0);

        assert(st.diffMonths(cst) == 0);
        assert(cst.diffMonths(cst) == 0);
        //assert(ist.diffMonths(cst) == 0);

        //assert(st.diffMonths(ist) == 0);
        //assert(cst.diffMonths(ist) == 0);
        //assert(ist.diffMonths(ist) == 0);
    }


    /++
        Whether this $(LREF SysTime) is in a leap year.
     +/
    @property bool isLeapYear() @safe const nothrow
    {
        return (cast(Date) this).isLeapYear;
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(!st.isLeapYear);
        assert(!cst.isLeapYear);
        //assert(!ist.isLeapYear);
    }


    /++
        Day of the week this $(LREF SysTime) is on.
      +/
    @property DayOfWeek dayOfWeek() @safe const nothrow
    {
        return getDayOfWeek(dayOfGregorianCal);
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(st.dayOfWeek == DayOfWeek.tue);
        assert(cst.dayOfWeek == DayOfWeek.tue);
        //assert(ist.dayOfWeek == DayOfWeek.tue);
    }


    /++
        Day of the year this $(LREF SysTime) is on.
      +/
    @property ushort dayOfYear() @safe const nothrow
    {
        return (cast(Date) this).dayOfYear;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1999, 1, 1, 12, 22, 7)).dayOfYear == 1);
        assert(SysTime(DateTime(1999, 12, 31, 7, 2, 59)).dayOfYear == 365);
        assert(SysTime(DateTime(2000, 12, 31, 21, 20, 0)).dayOfYear == 366);
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(st.dayOfYear == 187);
        assert(cst.dayOfYear == 187);
        //assert(ist.dayOfYear == 187);
    }


    /++
        Day of the year.

        Params:
            day = The day of the year to set which day of the year this
                  $(LREF SysTime) is on.
      +/
    @property void dayOfYear(int day) @safe
    {
        immutable hnsecs = adjTime;
        immutable days = convert!("hnsecs", "days")(hnsecs);
        immutable theRest = hnsecs - convert!("days", "hnsecs")(days);

        auto date = Date(cast(int) days);
        date.dayOfYear = day;

        immutable newDaysHNSecs = convert!("days", "hnsecs")(date.dayOfGregorianCal - 1);

        adjTime = newDaysHNSecs + theRest;
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        st.dayOfYear = 12;
        assert(st.dayOfYear == 12);
        static assert(!__traits(compiles, cst.dayOfYear = 12));
        //static assert(!__traits(compiles, ist.dayOfYear = 12));
    }


    /++
        The Xth day of the Gregorian Calendar that this $(LREF SysTime) is on.
     +/
    @property int dayOfGregorianCal() @safe const nothrow
    {
        immutable adjustedTime = adjTime;

        // We have to add one because 0 would be midnight, January 1st, 1 A.D.,
        // which would be the 1st day of the Gregorian Calendar, not the 0th. So,
        // simply casting to days is one day off.
        if (adjustedTime > 0)
            return cast(int) getUnitsFromHNSecs!"days"(adjustedTime) + 1;

        long hnsecs = adjustedTime;
        immutable days = cast(int) splitUnitsFromHNSecs!"days"(hnsecs);

        return hnsecs == 0 ? days + 1 : days;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0)).dayOfGregorianCal == 1);
        assert(SysTime(DateTime(1, 12, 31, 23, 59, 59)).dayOfGregorianCal == 365);
        assert(SysTime(DateTime(2, 1, 1, 2, 2, 2)).dayOfGregorianCal == 366);

        assert(SysTime(DateTime(0, 12, 31, 7, 7, 7)).dayOfGregorianCal == 0);
        assert(SysTime(DateTime(0, 1, 1, 19, 30, 0)).dayOfGregorianCal == -365);
        assert(SysTime(DateTime(-1, 12, 31, 4, 7, 0)).dayOfGregorianCal == -366);

        assert(SysTime(DateTime(2000, 1, 1, 9, 30, 20)).dayOfGregorianCal == 730_120);
        assert(SysTime(DateTime(2010, 12, 31, 15, 45, 50)).dayOfGregorianCal == 734_137);
    }

    @safe unittest
    {
        // Test A.D.
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0)).dayOfGregorianCal == 1);
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)).dayOfGregorianCal == 1);
        assert(SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)).dayOfGregorianCal == 1);

        assert(SysTime(DateTime(1, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 1);
        assert(SysTime(DateTime(1, 1, 2, 12, 2, 9), msecs(212)).dayOfGregorianCal == 2);
        assert(SysTime(DateTime(1, 2, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 32);
        assert(SysTime(DateTime(2, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 366);
        assert(SysTime(DateTime(3, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 731);
        assert(SysTime(DateTime(4, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 1096);
        assert(SysTime(DateTime(5, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 1462);
        assert(SysTime(DateTime(50, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 17_898);
        assert(SysTime(DateTime(97, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 35_065);
        assert(SysTime(DateTime(100, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 36_160);
        assert(SysTime(DateTime(101, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 36_525);
        assert(SysTime(DateTime(105, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 37_986);
        assert(SysTime(DateTime(200, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 72_684);
        assert(SysTime(DateTime(201, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 73_049);
        assert(SysTime(DateTime(300, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 109_208);
        assert(SysTime(DateTime(301, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 109_573);
        assert(SysTime(DateTime(400, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 145_732);
        assert(SysTime(DateTime(401, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 146_098);
        assert(SysTime(DateTime(500, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 182_257);
        assert(SysTime(DateTime(501, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 182_622);
        assert(SysTime(DateTime(1000, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 364_878);
        assert(SysTime(DateTime(1001, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 365_243);
        assert(SysTime(DateTime(1600, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 584_023);
        assert(SysTime(DateTime(1601, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 584_389);
        assert(SysTime(DateTime(1900, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 693_596);
        assert(SysTime(DateTime(1901, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 693_961);
        assert(SysTime(DateTime(1945, 11, 12, 12, 2, 9), msecs(212)).dayOfGregorianCal == 710_347);
        assert(SysTime(DateTime(1999, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 729_755);
        assert(SysTime(DateTime(2000, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 730_120);
        assert(SysTime(DateTime(2001, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == 730_486);

        assert(SysTime(DateTime(2010, 1, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_773);
        assert(SysTime(DateTime(2010, 1, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_803);
        assert(SysTime(DateTime(2010, 2, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_804);
        assert(SysTime(DateTime(2010, 2, 28, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_831);
        assert(SysTime(DateTime(2010, 3, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_832);
        assert(SysTime(DateTime(2010, 3, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_862);
        assert(SysTime(DateTime(2010, 4, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_863);
        assert(SysTime(DateTime(2010, 4, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_892);
        assert(SysTime(DateTime(2010, 5, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_893);
        assert(SysTime(DateTime(2010, 5, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_923);
        assert(SysTime(DateTime(2010, 6, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_924);
        assert(SysTime(DateTime(2010, 6, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_953);
        assert(SysTime(DateTime(2010, 7, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_954);
        assert(SysTime(DateTime(2010, 7, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_984);
        assert(SysTime(DateTime(2010, 8, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 733_985);
        assert(SysTime(DateTime(2010, 8, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_015);
        assert(SysTime(DateTime(2010, 9, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_016);
        assert(SysTime(DateTime(2010, 9, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_045);
        assert(SysTime(DateTime(2010, 10, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_046);
        assert(SysTime(DateTime(2010, 10, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_076);
        assert(SysTime(DateTime(2010, 11, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_077);
        assert(SysTime(DateTime(2010, 11, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_106);
        assert(SysTime(DateTime(2010, 12, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_107);
        assert(SysTime(DateTime(2010, 12, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == 734_137);

        assert(SysTime(DateTime(2012, 2, 1, 0, 0, 0)).dayOfGregorianCal == 734_534);
        assert(SysTime(DateTime(2012, 2, 28, 0, 0, 0)).dayOfGregorianCal == 734_561);
        assert(SysTime(DateTime(2012, 2, 29, 0, 0, 0)).dayOfGregorianCal == 734_562);
        assert(SysTime(DateTime(2012, 3, 1, 0, 0, 0)).dayOfGregorianCal == 734_563);

        // Test B.C.
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)).dayOfGregorianCal == 0);
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_998)).dayOfGregorianCal == 0);
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59)).dayOfGregorianCal == 0);
        assert(SysTime(DateTime(0, 12, 31, 0, 0, 0), hnsecs(1)).dayOfGregorianCal == 0);
        assert(SysTime(DateTime(0, 12, 31, 0, 0, 0)).dayOfGregorianCal == 0);

        assert(SysTime(DateTime(-1, 12, 31, 23, 59, 59), hnsecs(9_999_999)).dayOfGregorianCal == -366);
        assert(SysTime(DateTime(-1, 12, 31, 23, 59, 59), hnsecs(9_999_998)).dayOfGregorianCal == -366);
        assert(SysTime(DateTime(-1, 12, 31, 23, 59, 59)).dayOfGregorianCal == -366);
        assert(SysTime(DateTime(-1, 12, 31, 0, 0, 0)).dayOfGregorianCal == -366);

        assert(SysTime(DateTime(0, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == 0);
        assert(SysTime(DateTime(0, 12, 30, 12, 2, 9), msecs(212)).dayOfGregorianCal == -1);
        assert(SysTime(DateTime(0, 12, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -30);
        assert(SysTime(DateTime(0, 11, 30, 12, 2, 9), msecs(212)).dayOfGregorianCal == -31);

        assert(SysTime(DateTime(-1, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -366);
        assert(SysTime(DateTime(-1, 12, 30, 12, 2, 9), msecs(212)).dayOfGregorianCal == -367);
        assert(SysTime(DateTime(-1, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -730);
        assert(SysTime(DateTime(-2, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -731);
        assert(SysTime(DateTime(-2, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -1095);
        assert(SysTime(DateTime(-3, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -1096);
        assert(SysTime(DateTime(-3, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -1460);
        assert(SysTime(DateTime(-4, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -1461);
        assert(SysTime(DateTime(-4, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -1826);
        assert(SysTime(DateTime(-5, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -1827);
        assert(SysTime(DateTime(-5, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -2191);
        assert(SysTime(DateTime(-9, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -3652);

        assert(SysTime(DateTime(-49, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -18_262);
        assert(SysTime(DateTime(-50, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -18_627);
        assert(SysTime(DateTime(-97, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -35_794);
        assert(SysTime(DateTime(-99, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -36_160);
        assert(SysTime(DateTime(-99, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -36_524);
        assert(SysTime(DateTime(-100, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -36_889);
        assert(SysTime(DateTime(-101, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -37_254);
        assert(SysTime(DateTime(-105, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -38_715);
        assert(SysTime(DateTime(-200, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -73_413);
        assert(SysTime(DateTime(-201, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -73_778);
        assert(SysTime(DateTime(-300, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -109_937);
        assert(SysTime(DateTime(-301, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -110_302);
        assert(SysTime(DateTime(-400, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -146_097);
        assert(SysTime(DateTime(-400, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -146_462);
        assert(SysTime(DateTime(-401, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -146_827);
        assert(SysTime(DateTime(-499, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -182_621);
        assert(SysTime(DateTime(-500, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -182_986);
        assert(SysTime(DateTime(-501, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -183_351);
        assert(SysTime(DateTime(-1000, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -365_607);
        assert(SysTime(DateTime(-1001, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -365_972);
        assert(SysTime(DateTime(-1599, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -584_387);
        assert(SysTime(DateTime(-1600, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -584_388);
        assert(SysTime(DateTime(-1600, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -584_753);
        assert(SysTime(DateTime(-1601, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -585_118);
        assert(SysTime(DateTime(-1900, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -694_325);
        assert(SysTime(DateTime(-1901, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -694_690);
        assert(SysTime(DateTime(-1999, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -730_484);
        assert(SysTime(DateTime(-2000, 12, 31, 12, 2, 9), msecs(212)).dayOfGregorianCal == -730_485);
        assert(SysTime(DateTime(-2000, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -730_850);
        assert(SysTime(DateTime(-2001, 1, 1, 12, 2, 9), msecs(212)).dayOfGregorianCal == -731_215);

        assert(SysTime(DateTime(-2010, 1, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_502);
        assert(SysTime(DateTime(-2010, 1, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_472);
        assert(SysTime(DateTime(-2010, 2, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_471);
        assert(SysTime(DateTime(-2010, 2, 28, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_444);
        assert(SysTime(DateTime(-2010, 3, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_443);
        assert(SysTime(DateTime(-2010, 3, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_413);
        assert(SysTime(DateTime(-2010, 4, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_412);
        assert(SysTime(DateTime(-2010, 4, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_383);
        assert(SysTime(DateTime(-2010, 5, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_382);
        assert(SysTime(DateTime(-2010, 5, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_352);
        assert(SysTime(DateTime(-2010, 6, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_351);
        assert(SysTime(DateTime(-2010, 6, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_322);
        assert(SysTime(DateTime(-2010, 7, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_321);
        assert(SysTime(DateTime(-2010, 7, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_291);
        assert(SysTime(DateTime(-2010, 8, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_290);
        assert(SysTime(DateTime(-2010, 8, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_260);
        assert(SysTime(DateTime(-2010, 9, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_259);
        assert(SysTime(DateTime(-2010, 9, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_230);
        assert(SysTime(DateTime(-2010, 10, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_229);
        assert(SysTime(DateTime(-2010, 10, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_199);
        assert(SysTime(DateTime(-2010, 11, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_198);
        assert(SysTime(DateTime(-2010, 11, 30, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_169);
        assert(SysTime(DateTime(-2010, 12, 1, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_168);
        assert(SysTime(DateTime(-2010, 12, 31, 23, 59, 59), msecs(999)).dayOfGregorianCal == -734_138);

        assert(SysTime(DateTime(-2012, 2, 1, 0, 0, 0)).dayOfGregorianCal == -735_202);
        assert(SysTime(DateTime(-2012, 2, 28, 0, 0, 0)).dayOfGregorianCal == -735_175);
        assert(SysTime(DateTime(-2012, 2, 29, 0, 0, 0)).dayOfGregorianCal == -735_174);
        assert(SysTime(DateTime(-2012, 3, 1, 0, 0, 0)).dayOfGregorianCal == -735_173);

        // Start of Hebrew Calendar
        assert(SysTime(DateTime(-3760, 9, 7, 0, 0, 0)).dayOfGregorianCal == -1_373_427);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.dayOfGregorianCal == 729_941);
        //assert(ist.dayOfGregorianCal == 729_941);
    }


    // Test that the logic for the day of the Gregorian Calendar is consistent
    // between Date and SysTime.
    @safe unittest
    {
        void test(Date date, SysTime st, size_t line = __LINE__)
        {
            if (date.dayOfGregorianCal != st.dayOfGregorianCal)
            {
                throw new AssertError(format("Date [%s] SysTime [%s]", date.dayOfGregorianCal, st.dayOfGregorianCal),
                                      __FILE__, line);
            }
        }

        // Test A.D.
        test(Date(1, 1, 1), SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        test(Date(1, 1, 2), SysTime(DateTime(1, 1, 2, 0, 0, 0), hnsecs(500)));
        test(Date(1, 2, 1), SysTime(DateTime(1, 2, 1, 0, 0, 0), hnsecs(50_000)));
        test(Date(2, 1, 1), SysTime(DateTime(2, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(3, 1, 1), SysTime(DateTime(3, 1, 1, 12, 13, 14)));
        test(Date(4, 1, 1), SysTime(DateTime(4, 1, 1, 12, 13, 14), hnsecs(500)));
        test(Date(5, 1, 1), SysTime(DateTime(5, 1, 1, 12, 13, 14), hnsecs(50_000)));
        test(Date(50, 1, 1), SysTime(DateTime(50, 1, 1, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(97, 1, 1), SysTime(DateTime(97, 1, 1, 23, 59, 59)));
        test(Date(100, 1, 1), SysTime(DateTime(100, 1, 1, 23, 59, 59), hnsecs(500)));
        test(Date(101, 1, 1), SysTime(DateTime(101, 1, 1, 23, 59, 59), hnsecs(50_000)));
        test(Date(105, 1, 1), SysTime(DateTime(105, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(200, 1, 1), SysTime(DateTime(200, 1, 1, 0, 0, 0)));
        test(Date(201, 1, 1), SysTime(DateTime(201, 1, 1, 0, 0, 0), hnsecs(500)));
        test(Date(300, 1, 1), SysTime(DateTime(300, 1, 1, 0, 0, 0), hnsecs(50_000)));
        test(Date(301, 1, 1), SysTime(DateTime(301, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(400, 1, 1), SysTime(DateTime(400, 1, 1, 12, 13, 14)));
        test(Date(401, 1, 1), SysTime(DateTime(401, 1, 1, 12, 13, 14), hnsecs(500)));
        test(Date(500, 1, 1), SysTime(DateTime(500, 1, 1, 12, 13, 14), hnsecs(50_000)));
        test(Date(501, 1, 1), SysTime(DateTime(501, 1, 1, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(1000, 1, 1), SysTime(DateTime(1000, 1, 1, 23, 59, 59)));
        test(Date(1001, 1, 1), SysTime(DateTime(1001, 1, 1, 23, 59, 59), hnsecs(500)));
        test(Date(1600, 1, 1), SysTime(DateTime(1600, 1, 1, 23, 59, 59), hnsecs(50_000)));
        test(Date(1601, 1, 1), SysTime(DateTime(1601, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(1900, 1, 1), SysTime(DateTime(1900, 1, 1, 0, 0, 0)));
        test(Date(1901, 1, 1), SysTime(DateTime(1901, 1, 1, 0, 0, 0), hnsecs(500)));
        test(Date(1945, 11, 12), SysTime(DateTime(1945, 11, 12, 0, 0, 0), hnsecs(50_000)));
        test(Date(1999, 1, 1), SysTime(DateTime(1999, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(1999, 7, 6), SysTime(DateTime(1999, 7, 6, 12, 13, 14)));
        test(Date(2000, 1, 1), SysTime(DateTime(2000, 1, 1, 12, 13, 14), hnsecs(500)));
        test(Date(2001, 1, 1), SysTime(DateTime(2001, 1, 1, 12, 13, 14), hnsecs(50_000)));

        test(Date(2010, 1, 1), SysTime(DateTime(2010, 1, 1, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(2010, 1, 31), SysTime(DateTime(2010, 1, 31, 23, 0, 0)));
        test(Date(2010, 2, 1), SysTime(DateTime(2010, 2, 1, 23, 59, 59), hnsecs(500)));
        test(Date(2010, 2, 28), SysTime(DateTime(2010, 2, 28, 23, 59, 59), hnsecs(50_000)));
        test(Date(2010, 3, 1), SysTime(DateTime(2010, 3, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(2010, 3, 31), SysTime(DateTime(2010, 3, 31, 0, 0, 0)));
        test(Date(2010, 4, 1), SysTime(DateTime(2010, 4, 1, 0, 0, 0), hnsecs(500)));
        test(Date(2010, 4, 30), SysTime(DateTime(2010, 4, 30, 0, 0, 0), hnsecs(50_000)));
        test(Date(2010, 5, 1), SysTime(DateTime(2010, 5, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(2010, 5, 31), SysTime(DateTime(2010, 5, 31, 12, 13, 14)));
        test(Date(2010, 6, 1), SysTime(DateTime(2010, 6, 1, 12, 13, 14), hnsecs(500)));
        test(Date(2010, 6, 30), SysTime(DateTime(2010, 6, 30, 12, 13, 14), hnsecs(50_000)));
        test(Date(2010, 7, 1), SysTime(DateTime(2010, 7, 1, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(2010, 7, 31), SysTime(DateTime(2010, 7, 31, 23, 59, 59)));
        test(Date(2010, 8, 1), SysTime(DateTime(2010, 8, 1, 23, 59, 59), hnsecs(500)));
        test(Date(2010, 8, 31), SysTime(DateTime(2010, 8, 31, 23, 59, 59), hnsecs(50_000)));
        test(Date(2010, 9, 1), SysTime(DateTime(2010, 9, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(2010, 9, 30), SysTime(DateTime(2010, 9, 30, 12, 0, 0)));
        test(Date(2010, 10, 1), SysTime(DateTime(2010, 10, 1, 0, 12, 0), hnsecs(500)));
        test(Date(2010, 10, 31), SysTime(DateTime(2010, 10, 31, 0, 0, 12), hnsecs(50_000)));
        test(Date(2010, 11, 1), SysTime(DateTime(2010, 11, 1, 23, 0, 0), hnsecs(9_999_999)));
        test(Date(2010, 11, 30), SysTime(DateTime(2010, 11, 30, 0, 59, 0)));
        test(Date(2010, 12, 1), SysTime(DateTime(2010, 12, 1, 0, 0, 59), hnsecs(500)));
        test(Date(2010, 12, 31), SysTime(DateTime(2010, 12, 31, 0, 59, 59), hnsecs(50_000)));

        test(Date(2012, 2, 1), SysTime(DateTime(2012, 2, 1, 23, 0, 59), hnsecs(9_999_999)));
        test(Date(2012, 2, 28), SysTime(DateTime(2012, 2, 28, 23, 59, 0)));
        test(Date(2012, 2, 29), SysTime(DateTime(2012, 2, 29, 7, 7, 7), hnsecs(7)));
        test(Date(2012, 3, 1), SysTime(DateTime(2012, 3, 1, 7, 7, 7), hnsecs(7)));

        // Test B.C.
        test(Date(0, 12, 31), SysTime(DateTime(0, 12, 31, 0, 0, 0)));
        test(Date(0, 12, 30), SysTime(DateTime(0, 12, 30, 0, 0, 0), hnsecs(500)));
        test(Date(0, 12, 1), SysTime(DateTime(0, 12, 1, 0, 0, 0), hnsecs(50_000)));
        test(Date(0, 11, 30), SysTime(DateTime(0, 11, 30, 0, 0, 0), hnsecs(9_999_999)));

        test(Date(-1, 12, 31), SysTime(DateTime(-1, 12, 31, 12, 13, 14)));
        test(Date(-1, 12, 30), SysTime(DateTime(-1, 12, 30, 12, 13, 14), hnsecs(500)));
        test(Date(-1, 1, 1), SysTime(DateTime(-1, 1, 1, 12, 13, 14), hnsecs(50_000)));
        test(Date(-2, 12, 31), SysTime(DateTime(-2, 12, 31, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(-2, 1, 1), SysTime(DateTime(-2, 1, 1, 23, 59, 59)));
        test(Date(-3, 12, 31), SysTime(DateTime(-3, 12, 31, 23, 59, 59), hnsecs(500)));
        test(Date(-3, 1, 1), SysTime(DateTime(-3, 1, 1, 23, 59, 59), hnsecs(50_000)));
        test(Date(-4, 12, 31), SysTime(DateTime(-4, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(-4, 1, 1), SysTime(DateTime(-4, 1, 1, 0, 0, 0)));
        test(Date(-5, 12, 31), SysTime(DateTime(-5, 12, 31, 0, 0, 0), hnsecs(500)));
        test(Date(-5, 1, 1), SysTime(DateTime(-5, 1, 1, 0, 0, 0), hnsecs(50_000)));
        test(Date(-9, 1, 1), SysTime(DateTime(-9, 1, 1, 0, 0, 0), hnsecs(9_999_999)));

        test(Date(-49, 1, 1), SysTime(DateTime(-49, 1, 1, 12, 13, 14)));
        test(Date(-50, 1, 1), SysTime(DateTime(-50, 1, 1, 12, 13, 14), hnsecs(500)));
        test(Date(-97, 1, 1), SysTime(DateTime(-97, 1, 1, 12, 13, 14), hnsecs(50_000)));
        test(Date(-99, 12, 31), SysTime(DateTime(-99, 12, 31, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(-99, 1, 1), SysTime(DateTime(-99, 1, 1, 23, 59, 59)));
        test(Date(-100, 1, 1), SysTime(DateTime(-100, 1, 1, 23, 59, 59), hnsecs(500)));
        test(Date(-101, 1, 1), SysTime(DateTime(-101, 1, 1, 23, 59, 59), hnsecs(50_000)));
        test(Date(-105, 1, 1), SysTime(DateTime(-105, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(-200, 1, 1), SysTime(DateTime(-200, 1, 1, 0, 0, 0)));
        test(Date(-201, 1, 1), SysTime(DateTime(-201, 1, 1, 0, 0, 0), hnsecs(500)));
        test(Date(-300, 1, 1), SysTime(DateTime(-300, 1, 1, 0, 0, 0), hnsecs(50_000)));
        test(Date(-301, 1, 1), SysTime(DateTime(-301, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(-400, 12, 31), SysTime(DateTime(-400, 12, 31, 12, 13, 14)));
        test(Date(-400, 1, 1), SysTime(DateTime(-400, 1, 1, 12, 13, 14), hnsecs(500)));
        test(Date(-401, 1, 1), SysTime(DateTime(-401, 1, 1, 12, 13, 14), hnsecs(50_000)));
        test(Date(-499, 1, 1), SysTime(DateTime(-499, 1, 1, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(-500, 1, 1), SysTime(DateTime(-500, 1, 1, 23, 59, 59)));
        test(Date(-501, 1, 1), SysTime(DateTime(-501, 1, 1, 23, 59, 59), hnsecs(500)));
        test(Date(-1000, 1, 1), SysTime(DateTime(-1000, 1, 1, 23, 59, 59), hnsecs(50_000)));
        test(Date(-1001, 1, 1), SysTime(DateTime(-1001, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(-1599, 1, 1), SysTime(DateTime(-1599, 1, 1, 0, 0, 0)));
        test(Date(-1600, 12, 31), SysTime(DateTime(-1600, 12, 31, 0, 0, 0), hnsecs(500)));
        test(Date(-1600, 1, 1), SysTime(DateTime(-1600, 1, 1, 0, 0, 0), hnsecs(50_000)));
        test(Date(-1601, 1, 1), SysTime(DateTime(-1601, 1, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(-1900, 1, 1), SysTime(DateTime(-1900, 1, 1, 12, 13, 14)));
        test(Date(-1901, 1, 1), SysTime(DateTime(-1901, 1, 1, 12, 13, 14), hnsecs(500)));
        test(Date(-1999, 1, 1), SysTime(DateTime(-1999, 1, 1, 12, 13, 14), hnsecs(50_000)));
        test(Date(-1999, 7, 6), SysTime(DateTime(-1999, 7, 6, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(-2000, 12, 31), SysTime(DateTime(-2000, 12, 31, 23, 59, 59)));
        test(Date(-2000, 1, 1), SysTime(DateTime(-2000, 1, 1, 23, 59, 59), hnsecs(500)));
        test(Date(-2001, 1, 1), SysTime(DateTime(-2001, 1, 1, 23, 59, 59), hnsecs(50_000)));

        test(Date(-2010, 1, 1), SysTime(DateTime(-2010, 1, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(-2010, 1, 31), SysTime(DateTime(-2010, 1, 31, 0, 0, 0)));
        test(Date(-2010, 2, 1), SysTime(DateTime(-2010, 2, 1, 0, 0, 0), hnsecs(500)));
        test(Date(-2010, 2, 28), SysTime(DateTime(-2010, 2, 28, 0, 0, 0), hnsecs(50_000)));
        test(Date(-2010, 3, 1), SysTime(DateTime(-2010, 3, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(-2010, 3, 31), SysTime(DateTime(-2010, 3, 31, 12, 13, 14)));
        test(Date(-2010, 4, 1), SysTime(DateTime(-2010, 4, 1, 12, 13, 14), hnsecs(500)));
        test(Date(-2010, 4, 30), SysTime(DateTime(-2010, 4, 30, 12, 13, 14), hnsecs(50_000)));
        test(Date(-2010, 5, 1), SysTime(DateTime(-2010, 5, 1, 12, 13, 14), hnsecs(9_999_999)));
        test(Date(-2010, 5, 31), SysTime(DateTime(-2010, 5, 31, 23, 59, 59)));
        test(Date(-2010, 6, 1), SysTime(DateTime(-2010, 6, 1, 23, 59, 59), hnsecs(500)));
        test(Date(-2010, 6, 30), SysTime(DateTime(-2010, 6, 30, 23, 59, 59), hnsecs(50_000)));
        test(Date(-2010, 7, 1), SysTime(DateTime(-2010, 7, 1, 23, 59, 59), hnsecs(9_999_999)));
        test(Date(-2010, 7, 31), SysTime(DateTime(-2010, 7, 31, 0, 0, 0)));
        test(Date(-2010, 8, 1), SysTime(DateTime(-2010, 8, 1, 0, 0, 0), hnsecs(500)));
        test(Date(-2010, 8, 31), SysTime(DateTime(-2010, 8, 31, 0, 0, 0), hnsecs(50_000)));
        test(Date(-2010, 9, 1), SysTime(DateTime(-2010, 9, 1, 0, 0, 0), hnsecs(9_999_999)));
        test(Date(-2010, 9, 30), SysTime(DateTime(-2010, 9, 30, 12, 0, 0)));
        test(Date(-2010, 10, 1), SysTime(DateTime(-2010, 10, 1, 0, 12, 0), hnsecs(500)));
        test(Date(-2010, 10, 31), SysTime(DateTime(-2010, 10, 31, 0, 0, 12), hnsecs(50_000)));
        test(Date(-2010, 11, 1), SysTime(DateTime(-2010, 11, 1, 23, 0, 0), hnsecs(9_999_999)));
        test(Date(-2010, 11, 30), SysTime(DateTime(-2010, 11, 30, 0, 59, 0)));
        test(Date(-2010, 12, 1), SysTime(DateTime(-2010, 12, 1, 0, 0, 59), hnsecs(500)));
        test(Date(-2010, 12, 31), SysTime(DateTime(-2010, 12, 31, 0, 59, 59), hnsecs(50_000)));

        test(Date(-2012, 2, 1), SysTime(DateTime(-2012, 2, 1, 23, 0, 59), hnsecs(9_999_999)));
        test(Date(-2012, 2, 28), SysTime(DateTime(-2012, 2, 28, 23, 59, 0)));
        test(Date(-2012, 2, 29), SysTime(DateTime(-2012, 2, 29, 7, 7, 7), hnsecs(7)));
        test(Date(-2012, 3, 1), SysTime(DateTime(-2012, 3, 1, 7, 7, 7), hnsecs(7)));

        test(Date(-3760, 9, 7), SysTime(DateTime(-3760, 9, 7, 0, 0, 0)));
    }


    /++
        The Xth day of the Gregorian Calendar that this $(LREF SysTime) is on.
        Setting this property does not affect the time portion of $(LREF SysTime).

        Params:
            days = The day of the Gregorian Calendar to set this $(LREF SysTime)
                   to.
     +/
    @property void dayOfGregorianCal(int days) @safe nothrow
    {
        auto hnsecs = adjTime;
        hnsecs = removeUnitsFromHNSecs!"days"(hnsecs);

        if (hnsecs < 0)
            hnsecs += convert!("hours", "hnsecs")(24);

        if (--days < 0)
        {
            hnsecs -= convert!("hours", "hnsecs")(24);
            ++days;
        }

        immutable newDaysHNSecs = convert!("days", "hnsecs")(days);

        adjTime = newDaysHNSecs + hnsecs;
    }

    ///
    @safe unittest
    {
        auto st = SysTime(DateTime(0, 1, 1, 12, 0, 0));
        st.dayOfGregorianCal = 1;
        assert(st == SysTime(DateTime(1, 1, 1, 12, 0, 0)));

        st.dayOfGregorianCal = 365;
        assert(st == SysTime(DateTime(1, 12, 31, 12, 0, 0)));

        st.dayOfGregorianCal = 366;
        assert(st == SysTime(DateTime(2, 1, 1, 12, 0, 0)));

        st.dayOfGregorianCal = 0;
        assert(st == SysTime(DateTime(0, 12, 31, 12, 0, 0)));

        st.dayOfGregorianCal = -365;
        assert(st == SysTime(DateTime(-0, 1, 1, 12, 0, 0)));

        st.dayOfGregorianCal = -366;
        assert(st == SysTime(DateTime(-1, 12, 31, 12, 0, 0)));

        st.dayOfGregorianCal = 730_120;
        assert(st == SysTime(DateTime(2000, 1, 1, 12, 0, 0)));

        st.dayOfGregorianCal = 734_137;
        assert(st == SysTime(DateTime(2010, 12, 31, 12, 0, 0)));
    }

    @safe unittest
    {
        void testST(SysTime orig, int day, in SysTime expected, size_t line = __LINE__)
        {
            orig.dayOfGregorianCal = day;
            if (orig != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", orig, expected), __FILE__, line);
        }

        // Test A.D.
        testST(SysTime(DateTime(1, 1, 1, 0, 0, 0)), 1, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)), 1, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)));
        testST(SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)), 1,
               SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));

        // Test B.C.
        testST(SysTime(DateTime(0, 1, 1, 0, 0, 0)), 0, SysTime(DateTime(0, 12, 31, 0, 0, 0)));
        testST(SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(9_999_999)), 0,
               SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(SysTime(DateTime(0, 1, 1, 23, 59, 59), hnsecs(1)), 0,
               SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(1)));
        testST(SysTime(DateTime(0, 1, 1, 23, 59, 59)), 0, SysTime(DateTime(0, 12, 31, 23, 59, 59)));

        // Test Both.
        testST(SysTime(DateTime(-512, 7, 20, 0, 0, 0)), 1, SysTime(DateTime(1, 1, 1, 0, 0, 0)));
        testST(SysTime(DateTime(-513, 6, 6, 0, 0, 0), hnsecs(1)), 1, SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1)));
        testST(SysTime(DateTime(-511, 5, 7, 23, 59, 59), hnsecs(9_999_999)), 1,
               SysTime(DateTime(1, 1, 1, 23, 59, 59), hnsecs(9_999_999)));

        testST(SysTime(DateTime(1607, 4, 8, 0, 0, 0)), 0, SysTime(DateTime(0, 12, 31, 0, 0, 0)));
        testST(SysTime(DateTime(1500, 3, 9, 23, 59, 59), hnsecs(9_999_999)), 0,
               SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999)));
        testST(SysTime(DateTime(999, 2, 10, 23, 59, 59), hnsecs(1)), 0,
               SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(1)));
        testST(SysTime(DateTime(2007, 12, 11, 23, 59, 59)), 0, SysTime(DateTime(0, 12, 31, 23, 59, 59)));


        auto st = SysTime(DateTime(1, 1, 1, 12, 2, 9), msecs(212));

        void testST2(int day, in SysTime expected, size_t line = __LINE__)
        {
            st.dayOfGregorianCal = day;
            if (st != expected)
                throw new AssertError(format("Failed. actual [%s] != expected [%s]", st, expected), __FILE__, line);
        }

        // Test A.D.
        testST2(1, SysTime(DateTime(1, 1, 1, 12, 2, 9), msecs(212)));
        testST2(2, SysTime(DateTime(1, 1, 2, 12, 2, 9), msecs(212)));
        testST2(32, SysTime(DateTime(1, 2, 1, 12, 2, 9), msecs(212)));
        testST2(366, SysTime(DateTime(2, 1, 1, 12, 2, 9), msecs(212)));
        testST2(731, SysTime(DateTime(3, 1, 1, 12, 2, 9), msecs(212)));
        testST2(1096, SysTime(DateTime(4, 1, 1, 12, 2, 9), msecs(212)));
        testST2(1462, SysTime(DateTime(5, 1, 1, 12, 2, 9), msecs(212)));
        testST2(17_898, SysTime(DateTime(50, 1, 1, 12, 2, 9), msecs(212)));
        testST2(35_065, SysTime(DateTime(97, 1, 1, 12, 2, 9), msecs(212)));
        testST2(36_160, SysTime(DateTime(100, 1, 1, 12, 2, 9), msecs(212)));
        testST2(36_525, SysTime(DateTime(101, 1, 1, 12, 2, 9), msecs(212)));
        testST2(37_986, SysTime(DateTime(105, 1, 1, 12, 2, 9), msecs(212)));
        testST2(72_684, SysTime(DateTime(200, 1, 1, 12, 2, 9), msecs(212)));
        testST2(73_049, SysTime(DateTime(201, 1, 1, 12, 2, 9), msecs(212)));
        testST2(109_208, SysTime(DateTime(300, 1, 1, 12, 2, 9), msecs(212)));
        testST2(109_573, SysTime(DateTime(301, 1, 1, 12, 2, 9), msecs(212)));
        testST2(145_732, SysTime(DateTime(400, 1, 1, 12, 2, 9), msecs(212)));
        testST2(146_098, SysTime(DateTime(401, 1, 1, 12, 2, 9), msecs(212)));
        testST2(182_257, SysTime(DateTime(500, 1, 1, 12, 2, 9), msecs(212)));
        testST2(182_622, SysTime(DateTime(501, 1, 1, 12, 2, 9), msecs(212)));
        testST2(364_878, SysTime(DateTime(1000, 1, 1, 12, 2, 9), msecs(212)));
        testST2(365_243, SysTime(DateTime(1001, 1, 1, 12, 2, 9), msecs(212)));
        testST2(584_023, SysTime(DateTime(1600, 1, 1, 12, 2, 9), msecs(212)));
        testST2(584_389, SysTime(DateTime(1601, 1, 1, 12, 2, 9), msecs(212)));
        testST2(693_596, SysTime(DateTime(1900, 1, 1, 12, 2, 9), msecs(212)));
        testST2(693_961, SysTime(DateTime(1901, 1, 1, 12, 2, 9), msecs(212)));
        testST2(729_755, SysTime(DateTime(1999, 1, 1, 12, 2, 9), msecs(212)));
        testST2(730_120, SysTime(DateTime(2000, 1, 1, 12, 2, 9), msecs(212)));
        testST2(730_486, SysTime(DateTime(2001, 1, 1, 12, 2, 9), msecs(212)));

        testST2(733_773, SysTime(DateTime(2010, 1, 1, 12, 2, 9), msecs(212)));
        testST2(733_803, SysTime(DateTime(2010, 1, 31, 12, 2, 9), msecs(212)));
        testST2(733_804, SysTime(DateTime(2010, 2, 1, 12, 2, 9), msecs(212)));
        testST2(733_831, SysTime(DateTime(2010, 2, 28, 12, 2, 9), msecs(212)));
        testST2(733_832, SysTime(DateTime(2010, 3, 1, 12, 2, 9), msecs(212)));
        testST2(733_862, SysTime(DateTime(2010, 3, 31, 12, 2, 9), msecs(212)));
        testST2(733_863, SysTime(DateTime(2010, 4, 1, 12, 2, 9), msecs(212)));
        testST2(733_892, SysTime(DateTime(2010, 4, 30, 12, 2, 9), msecs(212)));
        testST2(733_893, SysTime(DateTime(2010, 5, 1, 12, 2, 9), msecs(212)));
        testST2(733_923, SysTime(DateTime(2010, 5, 31, 12, 2, 9), msecs(212)));
        testST2(733_924, SysTime(DateTime(2010, 6, 1, 12, 2, 9), msecs(212)));
        testST2(733_953, SysTime(DateTime(2010, 6, 30, 12, 2, 9), msecs(212)));
        testST2(733_954, SysTime(DateTime(2010, 7, 1, 12, 2, 9), msecs(212)));
        testST2(733_984, SysTime(DateTime(2010, 7, 31, 12, 2, 9), msecs(212)));
        testST2(733_985, SysTime(DateTime(2010, 8, 1, 12, 2, 9), msecs(212)));
        testST2(734_015, SysTime(DateTime(2010, 8, 31, 12, 2, 9), msecs(212)));
        testST2(734_016, SysTime(DateTime(2010, 9, 1, 12, 2, 9), msecs(212)));
        testST2(734_045, SysTime(DateTime(2010, 9, 30, 12, 2, 9), msecs(212)));
        testST2(734_046, SysTime(DateTime(2010, 10, 1, 12, 2, 9), msecs(212)));
        testST2(734_076, SysTime(DateTime(2010, 10, 31, 12, 2, 9), msecs(212)));
        testST2(734_077, SysTime(DateTime(2010, 11, 1, 12, 2, 9), msecs(212)));
        testST2(734_106, SysTime(DateTime(2010, 11, 30, 12, 2, 9), msecs(212)));
        testST2(734_107, SysTime(DateTime(2010, 12, 1, 12, 2, 9), msecs(212)));
        testST2(734_137, SysTime(DateTime(2010, 12, 31, 12, 2, 9), msecs(212)));

        testST2(734_534, SysTime(DateTime(2012, 2, 1, 12, 2, 9), msecs(212)));
        testST2(734_561, SysTime(DateTime(2012, 2, 28, 12, 2, 9), msecs(212)));
        testST2(734_562, SysTime(DateTime(2012, 2, 29, 12, 2, 9), msecs(212)));
        testST2(734_563, SysTime(DateTime(2012, 3, 1, 12, 2, 9), msecs(212)));

        testST2(734_534,  SysTime(DateTime(2012, 2, 1, 12, 2, 9), msecs(212)));

        testST2(734_561, SysTime(DateTime(2012, 2, 28, 12, 2, 9), msecs(212)));
        testST2(734_562, SysTime(DateTime(2012, 2, 29, 12, 2, 9), msecs(212)));
        testST2(734_563, SysTime(DateTime(2012, 3, 1, 12, 2, 9), msecs(212)));

        // Test B.C.
        testST2(0, SysTime(DateTime(0, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-1, SysTime(DateTime(0, 12, 30, 12, 2, 9), msecs(212)));
        testST2(-30, SysTime(DateTime(0, 12, 1, 12, 2, 9), msecs(212)));
        testST2(-31, SysTime(DateTime(0, 11, 30, 12, 2, 9), msecs(212)));

        testST2(-366, SysTime(DateTime(-1, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-367, SysTime(DateTime(-1, 12, 30, 12, 2, 9), msecs(212)));
        testST2(-730, SysTime(DateTime(-1, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-731, SysTime(DateTime(-2, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-1095, SysTime(DateTime(-2, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-1096, SysTime(DateTime(-3, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-1460, SysTime(DateTime(-3, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-1461, SysTime(DateTime(-4, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-1826, SysTime(DateTime(-4, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-1827, SysTime(DateTime(-5, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-2191, SysTime(DateTime(-5, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-3652, SysTime(DateTime(-9, 1, 1, 12, 2, 9), msecs(212)));

        testST2(-18_262, SysTime(DateTime(-49, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-18_627, SysTime(DateTime(-50, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-35_794, SysTime(DateTime(-97, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-36_160, SysTime(DateTime(-99, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-36_524, SysTime(DateTime(-99, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-36_889, SysTime(DateTime(-100, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-37_254, SysTime(DateTime(-101, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-38_715, SysTime(DateTime(-105, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-73_413, SysTime(DateTime(-200, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-73_778, SysTime(DateTime(-201, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-109_937, SysTime(DateTime(-300, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-110_302, SysTime(DateTime(-301, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-146_097, SysTime(DateTime(-400, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-146_462, SysTime(DateTime(-400, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-146_827, SysTime(DateTime(-401, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-182_621, SysTime(DateTime(-499, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-182_986, SysTime(DateTime(-500, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-183_351, SysTime(DateTime(-501, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-365_607, SysTime(DateTime(-1000, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-365_972, SysTime(DateTime(-1001, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-584_387, SysTime(DateTime(-1599, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-584_388, SysTime(DateTime(-1600, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-584_753, SysTime(DateTime(-1600, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-585_118, SysTime(DateTime(-1601, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-694_325, SysTime(DateTime(-1900, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-694_690, SysTime(DateTime(-1901, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-730_484, SysTime(DateTime(-1999, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-730_485, SysTime(DateTime(-2000, 12, 31, 12, 2, 9), msecs(212)));
        testST2(-730_850, SysTime(DateTime(-2000, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-731_215, SysTime(DateTime(-2001, 1, 1, 12, 2, 9), msecs(212)));

        testST2(-734_502, SysTime(DateTime(-2010, 1, 1, 12, 2, 9), msecs(212)));
        testST2(-734_472, SysTime(DateTime(-2010, 1, 31, 12, 2, 9), msecs(212)));
        testST2(-734_471, SysTime(DateTime(-2010, 2, 1, 12, 2, 9), msecs(212)));
        testST2(-734_444, SysTime(DateTime(-2010, 2, 28, 12, 2, 9), msecs(212)));
        testST2(-734_443, SysTime(DateTime(-2010, 3, 1, 12, 2, 9), msecs(212)));
        testST2(-734_413, SysTime(DateTime(-2010, 3, 31, 12, 2, 9), msecs(212)));
        testST2(-734_412, SysTime(DateTime(-2010, 4, 1, 12, 2, 9), msecs(212)));
        testST2(-734_383, SysTime(DateTime(-2010, 4, 30, 12, 2, 9), msecs(212)));
        testST2(-734_382, SysTime(DateTime(-2010, 5, 1, 12, 2, 9), msecs(212)));
        testST2(-734_352, SysTime(DateTime(-2010, 5, 31, 12, 2, 9), msecs(212)));
        testST2(-734_351, SysTime(DateTime(-2010, 6, 1, 12, 2, 9), msecs(212)));
        testST2(-734_322, SysTime(DateTime(-2010, 6, 30, 12, 2, 9), msecs(212)));
        testST2(-734_321, SysTime(DateTime(-2010, 7, 1, 12, 2, 9), msecs(212)));
        testST2(-734_291, SysTime(DateTime(-2010, 7, 31, 12, 2, 9), msecs(212)));
        testST2(-734_290, SysTime(DateTime(-2010, 8, 1, 12, 2, 9), msecs(212)));
        testST2(-734_260, SysTime(DateTime(-2010, 8, 31, 12, 2, 9), msecs(212)));
        testST2(-734_259, SysTime(DateTime(-2010, 9, 1, 12, 2, 9), msecs(212)));
        testST2(-734_230, SysTime(DateTime(-2010, 9, 30, 12, 2, 9), msecs(212)));
        testST2(-734_229, SysTime(DateTime(-2010, 10, 1, 12, 2, 9), msecs(212)));
        testST2(-734_199, SysTime(DateTime(-2010, 10, 31, 12, 2, 9), msecs(212)));
        testST2(-734_198, SysTime(DateTime(-2010, 11, 1, 12, 2, 9), msecs(212)));
        testST2(-734_169, SysTime(DateTime(-2010, 11, 30, 12, 2, 9), msecs(212)));
        testST2(-734_168, SysTime(DateTime(-2010, 12, 1, 12, 2, 9), msecs(212)));
        testST2(-734_138, SysTime(DateTime(-2010, 12, 31, 12, 2, 9), msecs(212)));

        testST2(-735_202, SysTime(DateTime(-2012, 2, 1, 12, 2, 9), msecs(212)));
        testST2(-735_175, SysTime(DateTime(-2012, 2, 28, 12, 2, 9), msecs(212)));
        testST2(-735_174, SysTime(DateTime(-2012, 2, 29, 12, 2, 9), msecs(212)));
        testST2(-735_173, SysTime(DateTime(-2012, 3, 1, 12, 2, 9), msecs(212)));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        static assert(!__traits(compiles, cst.dayOfGregorianCal = 7));
        //static assert(!__traits(compiles, ist.dayOfGregorianCal = 7));
    }


    /++
        The ISO 8601 week of the year that this $(LREF SysTime) is in.

        See_Also:
            $(HTTP en.wikipedia.org/wiki/ISO_week_date, ISO Week Date).
      +/
    @property ubyte isoWeek() @safe const nothrow
    {
        return (cast(Date) this).isoWeek;
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(st.isoWeek == 27);
        assert(cst.isoWeek == 27);
        //assert(ist.isoWeek == 27);
    }


    /++
        $(LREF SysTime) for the last day in the month that this Date is in.
        The time portion of endOfMonth is always 23:59:59.9999999.
      +/
    @property SysTime endOfMonth() @safe const nothrow
    {
        immutable hnsecs = adjTime;
        immutable days = getUnitsFromHNSecs!"days"(hnsecs);

        auto date = Date(cast(int) days + 1).endOfMonth;
        auto newDays = date.dayOfGregorianCal - 1;
        long theTimeHNSecs;

        if (newDays < 0)
        {
            theTimeHNSecs = -1;
            ++newDays;
        }
        else
            theTimeHNSecs = convert!("days", "hnsecs")(1) - 1;

        immutable newDaysHNSecs = convert!("days", "hnsecs")(newDays);

        auto retval = SysTime(this._stdTime, this._timezone);
        retval.adjTime = newDaysHNSecs + theTimeHNSecs;

        return retval;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1999, 1, 6, 0, 0, 0)).endOfMonth ==
               SysTime(DateTime(1999, 1, 31, 23, 59, 59), hnsecs(9_999_999)));

        assert(SysTime(DateTime(1999, 2, 7, 19, 30, 0), msecs(24)).endOfMonth ==
               SysTime(DateTime(1999, 2, 28, 23, 59, 59), hnsecs(9_999_999)));

        assert(SysTime(DateTime(2000, 2, 7, 5, 12, 27), usecs(5203)).endOfMonth ==
               SysTime(DateTime(2000, 2, 29, 23, 59, 59), hnsecs(9_999_999)));

        assert(SysTime(DateTime(2000, 6, 4, 12, 22, 9), hnsecs(12345)).endOfMonth ==
               SysTime(DateTime(2000, 6, 30, 23, 59, 59), hnsecs(9_999_999)));
    }

    @safe unittest
    {
        // Test A.D.
        assert(SysTime(Date(1999, 1, 1)).endOfMonth == SysTime(DateTime(1999, 1, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 2, 1)).endOfMonth == SysTime(DateTime(1999, 2, 28, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(2000, 2, 1)).endOfMonth == SysTime(DateTime(2000, 2, 29, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 3, 1)).endOfMonth == SysTime(DateTime(1999, 3, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 4, 1)).endOfMonth == SysTime(DateTime(1999, 4, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 5, 1)).endOfMonth == SysTime(DateTime(1999, 5, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 6, 1)).endOfMonth == SysTime(DateTime(1999, 6, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 7, 1)).endOfMonth == SysTime(DateTime(1999, 7, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 8, 1)).endOfMonth == SysTime(DateTime(1999, 8, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 9, 1)).endOfMonth == SysTime(DateTime(1999, 9, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 10, 1)).endOfMonth == SysTime(DateTime(1999, 10, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 11, 1)).endOfMonth == SysTime(DateTime(1999, 11, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(1999, 12, 1)).endOfMonth == SysTime(DateTime(1999, 12, 31, 23, 59, 59), hnsecs(9_999_999)));

        // Test B.C.
        assert(SysTime(Date(-1999, 1, 1)).endOfMonth == SysTime(DateTime(-1999, 1, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 2, 1)).endOfMonth == SysTime(DateTime(-1999, 2, 28, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-2000, 2, 1)).endOfMonth == SysTime(DateTime(-2000, 2, 29, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 3, 1)).endOfMonth == SysTime(DateTime(-1999, 3, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 4, 1)).endOfMonth == SysTime(DateTime(-1999, 4, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 5, 1)).endOfMonth == SysTime(DateTime(-1999, 5, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 6, 1)).endOfMonth == SysTime(DateTime(-1999, 6, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 7, 1)).endOfMonth == SysTime(DateTime(-1999, 7, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 8, 1)).endOfMonth == SysTime(DateTime(-1999, 8, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 9, 1)).endOfMonth == SysTime(DateTime(-1999, 9, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 10, 1)).endOfMonth ==
               SysTime(DateTime(-1999, 10, 31, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 11, 1)).endOfMonth ==
               SysTime(DateTime(-1999, 11, 30, 23, 59, 59), hnsecs(9_999_999)));
        assert(SysTime(Date(-1999, 12, 1)).endOfMonth ==
               SysTime(DateTime(-1999, 12, 31, 23, 59, 59), hnsecs(9_999_999)));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.endOfMonth == SysTime(DateTime(1999, 7, 31, 23, 59, 59), hnsecs(9_999_999)));
        //assert(ist.endOfMonth == SysTime(DateTime(1999, 7, 31, 23, 59, 59), hnsecs(9_999_999)));
    }


    /++
        The last day in the month that this $(LREF SysTime) is in.
      +/
    @property ubyte daysInMonth() @safe const nothrow
    {
        return Date(dayOfGregorianCal).daysInMonth;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1999, 1, 6, 0, 0, 0)).daysInMonth == 31);
        assert(SysTime(DateTime(1999, 2, 7, 19, 30, 0)).daysInMonth == 28);
        assert(SysTime(DateTime(2000, 2, 7, 5, 12, 27)).daysInMonth == 29);
        assert(SysTime(DateTime(2000, 6, 4, 12, 22, 9)).daysInMonth == 30);
    }

    @safe unittest
    {
        // Test A.D.
        assert(SysTime(DateTime(1999, 1, 1, 12, 1, 13)).daysInMonth == 31);
        assert(SysTime(DateTime(1999, 2, 1, 17, 13, 12)).daysInMonth == 28);
        assert(SysTime(DateTime(2000, 2, 1, 13, 2, 12)).daysInMonth == 29);
        assert(SysTime(DateTime(1999, 3, 1, 12, 13, 12)).daysInMonth == 31);
        assert(SysTime(DateTime(1999, 4, 1, 12, 6, 13)).daysInMonth == 30);
        assert(SysTime(DateTime(1999, 5, 1, 15, 13, 12)).daysInMonth == 31);
        assert(SysTime(DateTime(1999, 6, 1, 13, 7, 12)).daysInMonth == 30);
        assert(SysTime(DateTime(1999, 7, 1, 12, 13, 17)).daysInMonth == 31);
        assert(SysTime(DateTime(1999, 8, 1, 12, 3, 13)).daysInMonth == 31);
        assert(SysTime(DateTime(1999, 9, 1, 12, 13, 12)).daysInMonth == 30);
        assert(SysTime(DateTime(1999, 10, 1, 13, 19, 12)).daysInMonth == 31);
        assert(SysTime(DateTime(1999, 11, 1, 12, 13, 17)).daysInMonth == 30);
        assert(SysTime(DateTime(1999, 12, 1, 12, 52, 13)).daysInMonth == 31);

        // Test B.C.
        assert(SysTime(DateTime(-1999, 1, 1, 12, 1, 13)).daysInMonth == 31);
        assert(SysTime(DateTime(-1999, 2, 1, 7, 13, 12)).daysInMonth == 28);
        assert(SysTime(DateTime(-2000, 2, 1, 13, 2, 12)).daysInMonth == 29);
        assert(SysTime(DateTime(-1999, 3, 1, 12, 13, 12)).daysInMonth == 31);
        assert(SysTime(DateTime(-1999, 4, 1, 12, 6, 13)).daysInMonth == 30);
        assert(SysTime(DateTime(-1999, 5, 1, 5, 13, 12)).daysInMonth == 31);
        assert(SysTime(DateTime(-1999, 6, 1, 13, 7, 12)).daysInMonth == 30);
        assert(SysTime(DateTime(-1999, 7, 1, 12, 13, 17)).daysInMonth == 31);
        assert(SysTime(DateTime(-1999, 8, 1, 12, 3, 13)).daysInMonth == 31);
        assert(SysTime(DateTime(-1999, 9, 1, 12, 13, 12)).daysInMonth == 30);
        assert(SysTime(DateTime(-1999, 10, 1, 13, 19, 12)).daysInMonth == 31);
        assert(SysTime(DateTime(-1999, 11, 1, 12, 13, 17)).daysInMonth == 30);
        assert(SysTime(DateTime(-1999, 12, 1, 12, 52, 13)).daysInMonth == 31);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.daysInMonth == 31);
        //assert(ist.daysInMonth == 31);
    }


    /++
        Whether the current year is a date in A.D.
      +/
    @property bool isAD() @safe const nothrow
    {
        return adjTime >= 0;
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(1, 1, 1, 12, 7, 0)).isAD);
        assert(SysTime(DateTime(2010, 12, 31, 0, 0, 0)).isAD);
        assert(!SysTime(DateTime(0, 12, 31, 23, 59, 59)).isAD);
        assert(!SysTime(DateTime(-2010, 1, 1, 2, 2, 2)).isAD);
    }

    @safe unittest
    {
        assert(SysTime(DateTime(2010, 7, 4, 12, 0, 9)).isAD);
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0)).isAD);
        assert(!SysTime(DateTime(0, 12, 31, 23, 59, 59)).isAD);
        assert(!SysTime(DateTime(0, 1, 1, 23, 59, 59)).isAD);
        assert(!SysTime(DateTime(-1, 1, 1, 23 ,59 ,59)).isAD);
        assert(!SysTime(DateTime(-2010, 7, 4, 12, 2, 2)).isAD);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.isAD);
        //assert(ist.isAD);
    }


    /++
        The $(HTTP en.wikipedia.org/wiki/Julian_day, Julian day)
        for this $(LREF SysTime) at the given time. For example,
        prior to noon, 1996-03-31 would be the Julian day number 2_450_173, so
        this function returns 2_450_173, while from noon onward, the Julian
        day number would be 2_450_174, so this function returns 2_450_174.
      +/
    @property long julianDay() @safe const nothrow
    {
        immutable jd = dayOfGregorianCal + 1_721_425;
        return hour < 12 ? jd - 1 : jd;
    }

    @safe unittest
    {
        assert(SysTime(DateTime(-4713, 11, 24, 0, 0, 0)).julianDay == -1);
        assert(SysTime(DateTime(-4713, 11, 24, 12, 0, 0)).julianDay == 0);

        assert(SysTime(DateTime(0, 12, 31, 0, 0, 0)).julianDay == 1_721_424);
        assert(SysTime(DateTime(0, 12, 31, 12, 0, 0)).julianDay == 1_721_425);

        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0)).julianDay == 1_721_425);
        assert(SysTime(DateTime(1, 1, 1, 12, 0, 0)).julianDay == 1_721_426);

        assert(SysTime(DateTime(1582, 10, 15, 0, 0, 0)).julianDay == 2_299_160);
        assert(SysTime(DateTime(1582, 10, 15, 12, 0, 0)).julianDay == 2_299_161);

        assert(SysTime(DateTime(1858, 11, 17, 0, 0, 0)).julianDay == 2_400_000);
        assert(SysTime(DateTime(1858, 11, 17, 12, 0, 0)).julianDay == 2_400_001);

        assert(SysTime(DateTime(1982, 1, 4, 0, 0, 0)).julianDay == 2_444_973);
        assert(SysTime(DateTime(1982, 1, 4, 12, 0, 0)).julianDay == 2_444_974);

        assert(SysTime(DateTime(1996, 3, 31, 0, 0, 0)).julianDay == 2_450_173);
        assert(SysTime(DateTime(1996, 3, 31, 12, 0, 0)).julianDay == 2_450_174);

        assert(SysTime(DateTime(2010, 8, 24, 0, 0, 0)).julianDay == 2_455_432);
        assert(SysTime(DateTime(2010, 8, 24, 12, 0, 0)).julianDay == 2_455_433);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.julianDay == 2_451_366);
        //assert(ist.julianDay == 2_451_366);
    }


    /++
        The modified $(HTTP en.wikipedia.org/wiki/Julian_day, Julian day) for any time on this date (since, the modified
        Julian day changes at midnight).
      +/
    @property long modJulianDay() @safe const nothrow
    {
        return dayOfGregorianCal + 1_721_425 - 2_400_001;
    }

    @safe unittest
    {
        assert(SysTime(DateTime(1858, 11, 17, 0, 0, 0)).modJulianDay == 0);
        assert(SysTime(DateTime(1858, 11, 17, 12, 0, 0)).modJulianDay == 0);

        assert(SysTime(DateTime(2010, 8, 24, 0, 0, 0)).modJulianDay == 55_432);
        assert(SysTime(DateTime(2010, 8, 24, 12, 0, 0)).modJulianDay == 55_432);

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cst.modJulianDay == 51_365);
        //assert(ist.modJulianDay == 51_365);
    }


    /++
        Returns a $(LREF Date) equivalent to this $(LREF SysTime).
      +/
    Date opCast(T)() @safe const nothrow
        if (is(Unqual!T == Date))
    {
        return Date(dayOfGregorianCal);
    }

    @safe unittest
    {
        assert(cast(Date) SysTime(Date(1999, 7, 6)) == Date(1999, 7, 6));
        assert(cast(Date) SysTime(Date(2000, 12, 31)) == Date(2000, 12, 31));
        assert(cast(Date) SysTime(Date(2001, 1, 1)) == Date(2001, 1, 1));

        assert(cast(Date) SysTime(DateTime(1999, 7, 6, 12, 10, 9)) == Date(1999, 7, 6));
        assert(cast(Date) SysTime(DateTime(2000, 12, 31, 13, 11, 10)) == Date(2000, 12, 31));
        assert(cast(Date) SysTime(DateTime(2001, 1, 1, 14, 12, 11)) == Date(2001, 1, 1));

        assert(cast(Date) SysTime(Date(-1999, 7, 6)) == Date(-1999, 7, 6));
        assert(cast(Date) SysTime(Date(-2000, 12, 31)) == Date(-2000, 12, 31));
        assert(cast(Date) SysTime(Date(-2001, 1, 1)) == Date(-2001, 1, 1));

        assert(cast(Date) SysTime(DateTime(-1999, 7, 6, 12, 10, 9)) == Date(-1999, 7, 6));
        assert(cast(Date) SysTime(DateTime(-2000, 12, 31, 13, 11, 10)) == Date(-2000, 12, 31));
        assert(cast(Date) SysTime(DateTime(-2001, 1, 1, 14, 12, 11)) == Date(-2001, 1, 1));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cast(Date) cst != Date.init);
        //assert(cast(Date) ist != Date.init);
    }


    /++
        Returns a $(LREF DateTime) equivalent to this $(LREF SysTime).
      +/
    DateTime opCast(T)() @safe const nothrow
        if (is(Unqual!T == DateTime))
    {
        try
        {
            auto hnsecs = adjTime;
            auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

            if (hnsecs < 0)
            {
                hnsecs += convert!("hours", "hnsecs")(24);
                --days;
            }

            immutable hour = splitUnitsFromHNSecs!"hours"(hnsecs);
            immutable minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
            immutable second = getUnitsFromHNSecs!"seconds"(hnsecs);

            return DateTime(Date(cast(int) days), TimeOfDay(cast(int) hour, cast(int) minute, cast(int) second));
        }
        catch (Exception e)
            assert(0, "Either DateTime's constructor or TimeOfDay's constructor threw.");
    }

    @safe unittest
    {
        assert(cast(DateTime) SysTime(DateTime(1, 1, 6, 7, 12, 22)) == DateTime(1, 1, 6, 7, 12, 22));
        assert(cast(DateTime) SysTime(DateTime(1, 1, 6, 7, 12, 22), msecs(22)) == DateTime(1, 1, 6, 7, 12, 22));
        assert(cast(DateTime) SysTime(Date(1999, 7, 6)) == DateTime(1999, 7, 6, 0, 0, 0));
        assert(cast(DateTime) SysTime(Date(2000, 12, 31)) == DateTime(2000, 12, 31, 0, 0, 0));
        assert(cast(DateTime) SysTime(Date(2001, 1, 1)) == DateTime(2001, 1, 1, 0, 0, 0));

        assert(cast(DateTime) SysTime(DateTime(1999, 7, 6, 12, 10, 9)) == DateTime(1999, 7, 6, 12, 10, 9));
        assert(cast(DateTime) SysTime(DateTime(2000, 12, 31, 13, 11, 10)) == DateTime(2000, 12, 31, 13, 11, 10));
        assert(cast(DateTime) SysTime(DateTime(2001, 1, 1, 14, 12, 11)) == DateTime(2001, 1, 1, 14, 12, 11));

        assert(cast(DateTime) SysTime(DateTime(-1, 1, 6, 7, 12, 22)) == DateTime(-1, 1, 6, 7, 12, 22));
        assert(cast(DateTime) SysTime(DateTime(-1, 1, 6, 7, 12, 22), msecs(22)) == DateTime(-1, 1, 6, 7, 12, 22));
        assert(cast(DateTime) SysTime(Date(-1999, 7, 6)) == DateTime(-1999, 7, 6, 0, 0, 0));
        assert(cast(DateTime) SysTime(Date(-2000, 12, 31)) == DateTime(-2000, 12, 31, 0, 0, 0));
        assert(cast(DateTime) SysTime(Date(-2001, 1, 1)) == DateTime(-2001, 1, 1, 0, 0, 0));

        assert(cast(DateTime) SysTime(DateTime(-1999, 7, 6, 12, 10, 9)) == DateTime(-1999, 7, 6, 12, 10, 9));
        assert(cast(DateTime) SysTime(DateTime(-2000, 12, 31, 13, 11, 10)) == DateTime(-2000, 12, 31, 13, 11, 10));
        assert(cast(DateTime) SysTime(DateTime(-2001, 1, 1, 14, 12, 11)) == DateTime(-2001, 1, 1, 14, 12, 11));

        assert(cast(DateTime) SysTime(DateTime(2011, 1, 13, 8, 17, 2), msecs(296), LocalTime()) ==
               DateTime(2011, 1, 13, 8, 17, 2));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cast(DateTime) cst != DateTime.init);
        //assert(cast(DateTime) ist != DateTime.init);
    }


    /++
        Returns a $(LREF TimeOfDay) equivalent to this $(LREF SysTime).
      +/
    TimeOfDay opCast(T)() @safe const nothrow
        if (is(Unqual!T == TimeOfDay))
    {
        try
        {
            auto hnsecs = adjTime;
            hnsecs = removeUnitsFromHNSecs!"days"(hnsecs);

            if (hnsecs < 0)
                hnsecs += convert!("hours", "hnsecs")(24);

            immutable hour = splitUnitsFromHNSecs!"hours"(hnsecs);
            immutable minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
            immutable second = getUnitsFromHNSecs!"seconds"(hnsecs);

            return TimeOfDay(cast(int) hour, cast(int) minute, cast(int) second);
        }
        catch (Exception e)
            assert(0, "TimeOfDay's constructor threw.");
    }

    @safe unittest
    {
        assert(cast(TimeOfDay) SysTime(Date(1999, 7, 6)) == TimeOfDay(0, 0, 0));
        assert(cast(TimeOfDay) SysTime(Date(2000, 12, 31)) == TimeOfDay(0, 0, 0));
        assert(cast(TimeOfDay) SysTime(Date(2001, 1, 1)) == TimeOfDay(0, 0, 0));

        assert(cast(TimeOfDay) SysTime(DateTime(1999, 7, 6, 12, 10, 9)) == TimeOfDay(12, 10, 9));
        assert(cast(TimeOfDay) SysTime(DateTime(2000, 12, 31, 13, 11, 10)) == TimeOfDay(13, 11, 10));
        assert(cast(TimeOfDay) SysTime(DateTime(2001, 1, 1, 14, 12, 11)) == TimeOfDay(14, 12, 11));

        assert(cast(TimeOfDay) SysTime(Date(-1999, 7, 6)) == TimeOfDay(0, 0, 0));
        assert(cast(TimeOfDay) SysTime(Date(-2000, 12, 31)) == TimeOfDay(0, 0, 0));
        assert(cast(TimeOfDay) SysTime(Date(-2001, 1, 1)) == TimeOfDay(0, 0, 0));

        assert(cast(TimeOfDay) SysTime(DateTime(-1999, 7, 6, 12, 10, 9)) == TimeOfDay(12, 10, 9));
        assert(cast(TimeOfDay) SysTime(DateTime(-2000, 12, 31, 13, 11, 10)) == TimeOfDay(13, 11, 10));
        assert(cast(TimeOfDay) SysTime(DateTime(-2001, 1, 1, 14, 12, 11)) == TimeOfDay(14, 12, 11));

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cast(TimeOfDay) cst != TimeOfDay.init);
        //assert(cast(TimeOfDay) ist != TimeOfDay.init);
    }


    // Temporary hack until bug http://d.puremagic.com/issues/show_bug.cgi?id=4867 is fixed.
    // This allows assignment from const(SysTime) to SysTime.
    // It may be a good idea to keep it though, since casting from a type to itself
    // should be allowed, and it doesn't work without this opCast() since opCast()
    // has already been defined for other types.
    SysTime opCast(T)() @safe const pure nothrow
        if (is(Unqual!T == SysTime))
    {
        return SysTime(_stdTime, _timezone);
    }


    /++
        Converts this $(LREF SysTime) to a string with the format
        YYYYMMDDTHHMMSS.FFFFFFFTZ (where F is fractional seconds and TZ is time
        zone).

        Note that the number of digits in the fractional seconds varies with the
        number of fractional seconds. It's a maximum of 7 (which would be
        hnsecs), but only has as many as are necessary to hold the correct value
        (so no trailing zeroes), and if there are no fractional seconds, then
        there is no decimal point.

        If this $(LREF SysTime)'s time zone is $(LREF LocalTime), then TZ is empty.
        If its time zone is $(D UTC), then it is "Z". Otherwise, it is the
        offset from UTC (e.g. +0100 or -0700). Note that the offset from UTC
        is $(I not) enough to uniquely identify the time zone.

        Time zone offsets will be in the form +HHMM or -HHMM.

        $(RED Warning:
            Previously, toISOString did the same as $(LREF toISOExtString) and
            generated +HH:MM or -HH:MM for the time zone when it was not
            $(LREF LocalTime) or $(LREF UTC), which is not in conformance with
            ISO 9601 for the non-extended string format. This has now been
            fixed. However, for now, fromISOString will continue to accept the
            extended format for the time zone so that any code which has been
            writing out the result of toISOString to read in later will continue
            to work.)
      +/
    string toISOString() @safe const nothrow
    {
        try
        {
            immutable adjustedTime = adjTime;
            long hnsecs = adjustedTime;

            auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

            if (hnsecs < 0)
            {
                hnsecs += convert!("hours", "hnsecs")(24);
                --days;
            }

            auto hour = splitUnitsFromHNSecs!"hours"(hnsecs);
            auto minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
            auto second = splitUnitsFromHNSecs!"seconds"(hnsecs);

            auto dateTime = DateTime(Date(cast(int) days), TimeOfDay(cast(int) hour,
                                          cast(int) minute, cast(int) second));
            auto fracSecStr = fracSecsToISOString(cast(int) hnsecs);

            if (_timezone is LocalTime())
                return dateTime.toISOString() ~ fracSecStr;

            if (_timezone is UTC())
                return dateTime.toISOString() ~ fracSecStr ~ "Z";

            immutable utcOffset = dur!"hnsecs"(adjustedTime - stdTime);

            return format("%s%s%s",
                          dateTime.toISOString(),
                          fracSecStr,
                          SimpleTimeZone.toISOExtString(utcOffset));
        }
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(2010, 7, 4, 7, 6, 12)).toISOString() ==
               "20100704T070612");

        assert(SysTime(DateTime(1998, 12, 25, 2, 15, 0), msecs(24)).toISOString() ==
               "19981225T021500.024");

        assert(SysTime(DateTime(0, 1, 5, 23, 9, 59)).toISOString() ==
               "00000105T230959");

        assert(SysTime(DateTime(-4, 1, 5, 0, 0, 2), hnsecs(520_920)).toISOString() ==
               "-00040105T000002.052092");
    }

    @safe unittest
    {
        // Test A.D.
        assert(SysTime(DateTime.init, UTC()).toISOString() == "00010101T000000Z");
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1), UTC()).toISOString() == "00010101T000000.0000001Z");

        assert(SysTime(DateTime(9, 12, 4, 0, 0, 0)).toISOString() == "00091204T000000");
        assert(SysTime(DateTime(99, 12, 4, 5, 6, 12)).toISOString() == "00991204T050612");
        assert(SysTime(DateTime(999, 12, 4, 13, 44, 59)).toISOString() == "09991204T134459");
        assert(SysTime(DateTime(9999, 7, 4, 23, 59, 59)).toISOString() == "99990704T235959");
        assert(SysTime(DateTime(10000, 10, 20, 1, 1, 1)).toISOString() == "+100001020T010101");

        assert(SysTime(DateTime(9, 12, 4, 0, 0, 0), msecs(42)).toISOString() == "00091204T000000.042");
        assert(SysTime(DateTime(99, 12, 4, 5, 6, 12), msecs(100)).toISOString() == "00991204T050612.1");
        assert(SysTime(DateTime(999, 12, 4, 13, 44, 59), usecs(45020)).toISOString() == "09991204T134459.04502");
        assert(SysTime(DateTime(9999, 7, 4, 23, 59, 59), hnsecs(12)).toISOString() == "99990704T235959.0000012");
        assert(SysTime(DateTime(10000, 10, 20, 1, 1, 1), hnsecs(507890)).toISOString() == "+100001020T010101.050789");

        assert(SysTime(DateTime(2012, 12, 21, 12, 12, 12),
                       new immutable SimpleTimeZone(dur!"minutes"(-360))).toISOString() ==
               "20121221T121212-06:00");

        assert(SysTime(DateTime(2012, 12, 21, 12, 12, 12),
                       new immutable SimpleTimeZone(dur!"minutes"(420))).toISOString() ==
               "20121221T121212+07:00");

        // Test B.C.
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC()).toISOString() ==
               "00001231T235959.9999999Z");
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(1), UTC()).toISOString() == "00001231T235959.0000001Z");
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), UTC()).toISOString() == "00001231T235959Z");

        assert(SysTime(DateTime(0, 12, 4, 0, 12, 4)).toISOString() == "00001204T001204");
        assert(SysTime(DateTime(-9, 12, 4, 0, 0, 0)).toISOString() == "-00091204T000000");
        assert(SysTime(DateTime(-99, 12, 4, 5, 6, 12)).toISOString() == "-00991204T050612");
        assert(SysTime(DateTime(-999, 12, 4, 13, 44, 59)).toISOString() == "-09991204T134459");
        assert(SysTime(DateTime(-9999, 7, 4, 23, 59, 59)).toISOString() == "-99990704T235959");
        assert(SysTime(DateTime(-10000, 10, 20, 1, 1, 1)).toISOString() == "-100001020T010101");

        assert(SysTime(DateTime(0, 12, 4, 0, 0, 0), msecs(7)).toISOString() == "00001204T000000.007");
        assert(SysTime(DateTime(-9, 12, 4, 0, 0, 0), msecs(42)).toISOString() == "-00091204T000000.042");
        assert(SysTime(DateTime(-99, 12, 4, 5, 6, 12), msecs(100)).toISOString() == "-00991204T050612.1");
        assert(SysTime(DateTime(-999, 12, 4, 13, 44, 59), usecs(45020)).toISOString() == "-09991204T134459.04502");
        assert(SysTime(DateTime(-9999, 7, 4, 23, 59, 59), hnsecs(12)).toISOString() == "-99990704T235959.0000012");
        assert(SysTime(DateTime(-10000, 10, 20, 1, 1, 1), hnsecs(507890)).toISOString() == "-100001020T010101.050789");

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cast(TimeOfDay) cst != TimeOfDay.init);
        //assert(cast(TimeOfDay) ist != TimeOfDay.init);
    }



    /++
        Converts this $(LREF SysTime) to a string with the format
        YYYY-MM-DDTHH:MM:SS.FFFFFFFTZ (where F is fractional seconds and TZ
        is the time zone).

        Note that the number of digits in the fractional seconds varies with the
        number of fractional seconds. It's a maximum of 7 (which would be
        hnsecs), but only has as many as are necessary to hold the correct value
        (so no trailing zeroes), and if there are no fractional seconds, then
        there is no decimal point.

        If this $(LREF SysTime)'s time zone is $(LREF LocalTime), then TZ is empty. If
        its time zone is $(D UTC), then it is "Z". Otherwise, it is the offset
        from UTC (e.g. +01:00 or -07:00). Note that the offset from UTC is
        $(I not) enough to uniquely identify the time zone.

        Time zone offsets will be in the form +HH:MM or -HH:MM.
      +/
    string toISOExtString() @safe const nothrow
    {
        try
        {
            immutable adjustedTime = adjTime;
            long hnsecs = adjustedTime;

            auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

            if (hnsecs < 0)
            {
                hnsecs += convert!("hours", "hnsecs")(24);
                --days;
            }

            auto hour = splitUnitsFromHNSecs!"hours"(hnsecs);
            auto minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
            auto second = splitUnitsFromHNSecs!"seconds"(hnsecs);

            auto dateTime = DateTime(Date(cast(int) days), TimeOfDay(cast(int) hour,
                                          cast(int) minute, cast(int) second));
            auto fracSecStr = fracSecsToISOString(cast(int) hnsecs);

            if (_timezone is LocalTime())
                return dateTime.toISOExtString() ~ fracSecStr;

            if (_timezone is UTC())
                return dateTime.toISOExtString() ~ fracSecStr ~ "Z";

            immutable utcOffset = dur!"hnsecs"(adjustedTime - stdTime);

            return format("%s%s%s",
                          dateTime.toISOExtString(),
                          fracSecStr,
                          SimpleTimeZone.toISOExtString(utcOffset));
        }
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(2010, 7, 4, 7, 6, 12)).toISOExtString() ==
               "2010-07-04T07:06:12");

        assert(SysTime(DateTime(1998, 12, 25, 2, 15, 0), msecs(24)).toISOExtString() ==
               "1998-12-25T02:15:00.024");

        assert(SysTime(DateTime(0, 1, 5, 23, 9, 59)).toISOExtString() ==
               "0000-01-05T23:09:59");

        assert(SysTime(DateTime(-4, 1, 5, 0, 0, 2), hnsecs(520_920)).toISOExtString() ==
               "-0004-01-05T00:00:02.052092");
    }

    @safe unittest
    {
        // Test A.D.
        assert(SysTime(DateTime.init, UTC()).toISOExtString() == "0001-01-01T00:00:00Z");
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1), UTC()).toISOExtString() ==
               "0001-01-01T00:00:00.0000001Z");

        assert(SysTime(DateTime(9, 12, 4, 0, 0, 0)).toISOExtString() == "0009-12-04T00:00:00");
        assert(SysTime(DateTime(99, 12, 4, 5, 6, 12)).toISOExtString() == "0099-12-04T05:06:12");
        assert(SysTime(DateTime(999, 12, 4, 13, 44, 59)).toISOExtString() == "0999-12-04T13:44:59");
        assert(SysTime(DateTime(9999, 7, 4, 23, 59, 59)).toISOExtString() == "9999-07-04T23:59:59");
        assert(SysTime(DateTime(10000, 10, 20, 1, 1, 1)).toISOExtString() == "+10000-10-20T01:01:01");

        assert(SysTime(DateTime(9, 12, 4, 0, 0, 0), msecs(42)).toISOExtString() == "0009-12-04T00:00:00.042");
        assert(SysTime(DateTime(99, 12, 4, 5, 6, 12), msecs(100)).toISOExtString() == "0099-12-04T05:06:12.1");
        assert(SysTime(DateTime(999, 12, 4, 13, 44, 59), usecs(45020)).toISOExtString() == "0999-12-04T13:44:59.04502");
        assert(SysTime(DateTime(9999, 7, 4, 23, 59, 59), hnsecs(12)).toISOExtString() == "9999-07-04T23:59:59.0000012");
        assert(SysTime(DateTime(10000, 10, 20, 1, 1, 1), hnsecs(507890)).toISOExtString() ==
               "+10000-10-20T01:01:01.050789");

        assert(SysTime(DateTime(2012, 12, 21, 12, 12, 12),
                       new immutable SimpleTimeZone(dur!"minutes"(-360))).toISOExtString() ==
               "2012-12-21T12:12:12-06:00");

        assert(SysTime(DateTime(2012, 12, 21, 12, 12, 12),
                       new immutable SimpleTimeZone(dur!"minutes"(420))).toISOExtString() ==
               "2012-12-21T12:12:12+07:00");

        // Test B.C.
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC()).toISOExtString() ==
               "0000-12-31T23:59:59.9999999Z");
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(1), UTC()).toISOExtString() ==
               "0000-12-31T23:59:59.0000001Z");
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), UTC()).toISOExtString() == "0000-12-31T23:59:59Z");

        assert(SysTime(DateTime(0, 12, 4, 0, 12, 4)).toISOExtString() == "0000-12-04T00:12:04");
        assert(SysTime(DateTime(-9, 12, 4, 0, 0, 0)).toISOExtString() == "-0009-12-04T00:00:00");
        assert(SysTime(DateTime(-99, 12, 4, 5, 6, 12)).toISOExtString() == "-0099-12-04T05:06:12");
        assert(SysTime(DateTime(-999, 12, 4, 13, 44, 59)).toISOExtString() == "-0999-12-04T13:44:59");
        assert(SysTime(DateTime(-9999, 7, 4, 23, 59, 59)).toISOExtString() == "-9999-07-04T23:59:59");
        assert(SysTime(DateTime(-10000, 10, 20, 1, 1, 1)).toISOExtString() == "-10000-10-20T01:01:01");

        assert(SysTime(DateTime(0, 12, 4, 0, 0, 0), msecs(7)).toISOExtString() == "0000-12-04T00:00:00.007");
        assert(SysTime(DateTime(-9, 12, 4, 0, 0, 0), msecs(42)).toISOExtString() == "-0009-12-04T00:00:00.042");
        assert(SysTime(DateTime(-99, 12, 4, 5, 6, 12), msecs(100)).toISOExtString() == "-0099-12-04T05:06:12.1");
        assert(SysTime(DateTime(-999, 12, 4, 13, 44, 59), usecs(45020)).toISOExtString() ==
               "-0999-12-04T13:44:59.04502");
        assert(SysTime(DateTime(-9999, 7, 4, 23, 59, 59), hnsecs(12)).toISOExtString() ==
               "-9999-07-04T23:59:59.0000012");
        assert(SysTime(DateTime(-10000, 10, 20, 1, 1, 1), hnsecs(507890)).toISOExtString() ==
               "-10000-10-20T01:01:01.050789");

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cast(TimeOfDay) cst != TimeOfDay.init);
        //assert(cast(TimeOfDay) ist != TimeOfDay.init);
    }

    /++
        Converts this $(LREF SysTime) to a string with the format
        YYYY-Mon-DD HH:MM:SS.FFFFFFFTZ (where F is fractional seconds and TZ
        is the time zone).

        Note that the number of digits in the fractional seconds varies with the
        number of fractional seconds. It's a maximum of 7 (which would be
        hnsecs), but only has as many as are necessary to hold the correct value
        (so no trailing zeroes), and if there are no fractional seconds, then
        there is no decimal point.

        If this $(LREF SysTime)'s time zone is $(LREF LocalTime), then TZ is empty. If
        its time zone is $(D UTC), then it is "Z". Otherwise, it is the offset
        from UTC (e.g. +01:00 or -07:00). Note that the offset from UTC is
        $(I not) enough to uniquely identify the time zone.

        Time zone offsets will be in the form +HH:MM or -HH:MM.
      +/
    string toSimpleString() @safe const nothrow
    {
        try
        {
            immutable adjustedTime = adjTime;
            long hnsecs = adjustedTime;

            auto days = splitUnitsFromHNSecs!"days"(hnsecs) + 1;

            if (hnsecs < 0)
            {
                hnsecs += convert!("hours", "hnsecs")(24);
                --days;
            }

            auto hour = splitUnitsFromHNSecs!"hours"(hnsecs);
            auto minute = splitUnitsFromHNSecs!"minutes"(hnsecs);
            auto second = splitUnitsFromHNSecs!"seconds"(hnsecs);

            auto dateTime = DateTime(Date(cast(int) days), TimeOfDay(cast(int) hour,
                                          cast(int) minute, cast(int) second));
            auto fracSecStr = fracSecsToISOString(cast(int) hnsecs);

            if (_timezone is LocalTime())
                return dateTime.toSimpleString() ~ fracSecStr;

            if (_timezone is UTC())
                return dateTime.toSimpleString() ~ fracSecStr ~ "Z";

            immutable utcOffset = dur!"hnsecs"(adjustedTime - stdTime);

            return format("%s%s%s",
                          dateTime.toSimpleString(),
                          fracSecStr,
                          SimpleTimeZone.toISOExtString(utcOffset));
        }
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(SysTime(DateTime(2010, 7, 4, 7, 6, 12)).toSimpleString() ==
               "2010-Jul-04 07:06:12");

        assert(SysTime(DateTime(1998, 12, 25, 2, 15, 0), msecs(24)).toSimpleString() ==
               "1998-Dec-25 02:15:00.024");

        assert(SysTime(DateTime(0, 1, 5, 23, 9, 59)).toSimpleString() ==
               "0000-Jan-05 23:09:59");

        assert(SysTime(DateTime(-4, 1, 5, 0, 0, 2), hnsecs(520_920)).toSimpleString() ==
                "-0004-Jan-05 00:00:02.052092");
    }

    @safe unittest
    {
        // Test A.D.
        assert(SysTime(DateTime.init, UTC()).toString() == "0001-Jan-01 00:00:00Z");
        assert(SysTime(DateTime(1, 1, 1, 0, 0, 0), hnsecs(1), UTC()).toString() == "0001-Jan-01 00:00:00.0000001Z");

        assert(SysTime(DateTime(9, 12, 4, 0, 0, 0)).toSimpleString() == "0009-Dec-04 00:00:00");
        assert(SysTime(DateTime(99, 12, 4, 5, 6, 12)).toSimpleString() == "0099-Dec-04 05:06:12");
        assert(SysTime(DateTime(999, 12, 4, 13, 44, 59)).toSimpleString() == "0999-Dec-04 13:44:59");
        assert(SysTime(DateTime(9999, 7, 4, 23, 59, 59)).toSimpleString() == "9999-Jul-04 23:59:59");
        assert(SysTime(DateTime(10000, 10, 20, 1, 1, 1)).toSimpleString() == "+10000-Oct-20 01:01:01");

        assert(SysTime(DateTime(9, 12, 4, 0, 0, 0), msecs(42)).toSimpleString() == "0009-Dec-04 00:00:00.042");
        assert(SysTime(DateTime(99, 12, 4, 5, 6, 12), msecs(100)).toSimpleString() == "0099-Dec-04 05:06:12.1");
        assert(SysTime(DateTime(999, 12, 4, 13, 44, 59), usecs(45020)).toSimpleString() ==
               "0999-Dec-04 13:44:59.04502");
        assert(SysTime(DateTime(9999, 7, 4, 23, 59, 59), hnsecs(12)).toSimpleString() ==
               "9999-Jul-04 23:59:59.0000012");
        assert(SysTime(DateTime(10000, 10, 20, 1, 1, 1), hnsecs(507890)).toSimpleString() ==
               "+10000-Oct-20 01:01:01.050789");

        assert(SysTime(DateTime(2012, 12, 21, 12, 12, 12),
                       new immutable SimpleTimeZone(dur!"minutes"(-360))).toSimpleString() ==
               "2012-Dec-21 12:12:12-06:00");

        assert(SysTime(DateTime(2012, 12, 21, 12, 12, 12),
                       new immutable SimpleTimeZone(dur!"minutes"(420))).toSimpleString() ==
               "2012-Dec-21 12:12:12+07:00");

        // Test B.C.
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(9_999_999), UTC()).toSimpleString() ==
               "0000-Dec-31 23:59:59.9999999Z");
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), hnsecs(1), UTC()).toSimpleString() ==
               "0000-Dec-31 23:59:59.0000001Z");
        assert(SysTime(DateTime(0, 12, 31, 23, 59, 59), UTC()).toSimpleString() == "0000-Dec-31 23:59:59Z");

        assert(SysTime(DateTime(0, 12, 4, 0, 12, 4)).toSimpleString() == "0000-Dec-04 00:12:04");
        assert(SysTime(DateTime(-9, 12, 4, 0, 0, 0)).toSimpleString() == "-0009-Dec-04 00:00:00");
        assert(SysTime(DateTime(-99, 12, 4, 5, 6, 12)).toSimpleString() == "-0099-Dec-04 05:06:12");
        assert(SysTime(DateTime(-999, 12, 4, 13, 44, 59)).toSimpleString() == "-0999-Dec-04 13:44:59");
        assert(SysTime(DateTime(-9999, 7, 4, 23, 59, 59)).toSimpleString() == "-9999-Jul-04 23:59:59");
        assert(SysTime(DateTime(-10000, 10, 20, 1, 1, 1)).toSimpleString() == "-10000-Oct-20 01:01:01");

        assert(SysTime(DateTime(0, 12, 4, 0, 0, 0), msecs(7)).toSimpleString() == "0000-Dec-04 00:00:00.007");
        assert(SysTime(DateTime(-9, 12, 4, 0, 0, 0), msecs(42)).toSimpleString() == "-0009-Dec-04 00:00:00.042");
        assert(SysTime(DateTime(-99, 12, 4, 5, 6, 12), msecs(100)).toSimpleString() == "-0099-Dec-04 05:06:12.1");
        assert(SysTime(DateTime(-999, 12, 4, 13, 44, 59), usecs(45020)).toSimpleString() ==
               "-0999-Dec-04 13:44:59.04502");
        assert(SysTime(DateTime(-9999, 7, 4, 23, 59, 59), hnsecs(12)).toSimpleString() ==
               "-9999-Jul-04 23:59:59.0000012");
        assert(SysTime(DateTime(-10000, 10, 20, 1, 1, 1), hnsecs(507890)).toSimpleString() ==
               "-10000-Oct-20 01:01:01.050789");

        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(cast(TimeOfDay) cst != TimeOfDay.init);
        //assert(cast(TimeOfDay) ist != TimeOfDay.init);
    }


    /++
        Converts this $(LREF SysTime) to a string.
      +/
    string toString() @safe const nothrow
    {
        return toSimpleString();
    }

    @safe unittest
    {
        auto st = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        const cst = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        //immutable ist = SysTime(DateTime(1999, 7, 6, 12, 30, 33));
        assert(st.toString());
        assert(cst.toString());
        //assert(ist.toString());
    }


    /++
        Creates a $(LREF SysTime) from a string with the format
        YYYYMMDDTHHMMSS.FFFFFFFTZ (where F is fractional seconds is the time
        zone). Whitespace is stripped from the given string.

        The exact format is exactly as described in $(D toISOString) except that
        trailing zeroes are permitted - including having fractional seconds with
        all zeroes. However, a decimal point with nothing following it is
        invalid.

        If there is no time zone in the string, then $(LREF LocalTime) is used.
        If the time zone is "Z", then $(D UTC) is used. Otherwise, a
        $(LREF SimpleTimeZone) which corresponds to the given offset from UTC is
        used. To get the returned $(LREF SysTime) to be a particular time
        zone, pass in that time zone and the $(LREF SysTime) to be returned
        will be converted to that time zone (though it will still be read in as
        whatever time zone is in its string).

        The accepted formats for time zone offsets are +HH, -HH, +HHMM, and
        -HHMM.

        $(RED Warning:
            Previously, $(LREF toISOString) did the same as
            $(LREF toISOExtString) and generated +HH:MM or -HH:MM for the time
            zone when it was not $(LREF LocalTime) or $(LREF UTC), which is not
            in conformance with ISO 9601 for the non-extended string format.
            This has now been fixed. However, for now, fromISOString will
            continue to accept the extended format for the time zone so that any
            code which has been writing out the result of toISOString to read in
            later will continue to work.)

        Params:
            isoString = A string formatted in the ISO format for dates and times.
            tz        = The time zone to convert the given time to (no
                        conversion occurs if null).

        Throws:
            $(LREF DateTimeException) if the given string is not in the ISO
            format or if the resulting $(LREF SysTime) would not be valid.
      +/
    static SysTime fromISOString(S)(in S isoString, immutable TimeZone tz = null) @safe
        if (isSomeString!S)
    {
        import std.algorithm.searching : startsWith, find;
        import std.conv : to;
        import std.range.primitives;
        import std.string : strip;

        auto dstr = to!dstring(strip(isoString));
        immutable skipFirst = dstr.startsWith('+', '-') != 0;

        auto found = (skipFirst ? dstr[1..$] : dstr).find('.', 'Z', '+', '-');
        auto dateTimeStr = dstr[0 .. $ - found[0].length];

        dstring fracSecStr;
        dstring zoneStr;

        if (found[1] != 0)
        {
            if (found[1] == 1)
            {
                auto foundTZ = found[0].find('Z', '+', '-');

                if (foundTZ[1] != 0)
                {
                    fracSecStr = found[0][0 .. $ - foundTZ[0].length];
                    zoneStr = foundTZ[0];
                }
                else
                    fracSecStr = found[0];
            }
            else
                zoneStr = found[0];
        }

        try
        {
            auto dateTime = DateTime.fromISOString(dateTimeStr);
            auto fracSec = fracSecsFromISOString(fracSecStr);
            Rebindable!(immutable TimeZone) parsedZone;

            if (zoneStr.empty)
                parsedZone = LocalTime();
            else if (zoneStr == "Z")
                parsedZone = UTC();
            else
            {
                try
                    parsedZone = SimpleTimeZone.fromISOString(zoneStr);
                catch (DateTimeException dte)
                    parsedZone = SimpleTimeZone.fromISOExtString(zoneStr);
            }

            auto retval = SysTime(dateTime, fracSec, parsedZone);

            if (tz !is null)
                retval.timezone = tz;

            return retval;
        }
        catch (DateTimeException dte)
            throw new DateTimeException(format("Invalid ISO String: %s", isoString));
    }

    ///
    @safe unittest
    {
        assert(SysTime.fromISOString("20100704T070612") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12)));

        assert(SysTime.fromISOString("19981225T021500.007") ==
               SysTime(DateTime(1998, 12, 25, 2, 15, 0), msecs(7)));

        assert(SysTime.fromISOString("00000105T230959.00002") ==
               SysTime(DateTime(0, 1, 5, 23, 9, 59), usecs(20)));

        assert(SysTime.fromISOString("-00040105T000002") ==
               SysTime(DateTime(-4, 1, 5, 0, 0, 2)));

        assert(SysTime.fromISOString(" 20100704T070612 ") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12)));

        assert(SysTime.fromISOString("20100704T070612Z") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12), UTC()));

        assert(SysTime.fromISOString("20100704T070612-0800") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12),
                       new immutable SimpleTimeZone(hours(-8))));

        assert(SysTime.fromISOString("20100704T070612+0800") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12),
                       new immutable SimpleTimeZone(hours(8))));
    }

    @safe unittest
    {
        foreach (str; ["", "20100704000000", "20100704 000000", "20100704t000000",
                       "20100704T000000.", "20100704T000000.A", "20100704T000000.Z",
                       "20100704T000000.00000000", "20100704T000000.00000000",
                       "20100704T000000+", "20100704T000000-", "20100704T000000:",
                       "20100704T000000-:", "20100704T000000+:", "20100704T000000-1:",
                       "20100704T000000+1:", "20100704T000000+1:0",
                       "20100704T000000-12.00", "20100704T000000+12.00",
                       "20100704T000000-8", "20100704T000000+8",
                       "20100704T000000-800", "20100704T000000+800",
                       "20100704T000000-080", "20100704T000000+080",
                       "20100704T000000-2400", "20100704T000000+2400",
                       "20100704T000000-1260", "20100704T000000+1260",
                       "20100704T000000.0-8", "20100704T000000.0+8",
                       "20100704T000000.0-800", "20100704T000000.0+800",
                       "20100704T000000.0-080", "20100704T000000.0+080",
                       "20100704T000000.0-2400", "20100704T000000.0+2400",
                       "20100704T000000.0-1260", "20100704T000000.0+1260",
                       "20100704T000000-8:00", "20100704T000000+8:00",
                       "20100704T000000-08:0", "20100704T000000+08:0",
                       "20100704T000000-24:00", "20100704T000000+24:00",
                       "20100704T000000-12:60", "20100704T000000+12:60",
                       "20100704T000000.0-8:00", "20100704T000000.0+8:00",
                       "20100704T000000.0-08:0", "20100704T000000.0+08:0",
                       "20100704T000000.0-24:00", "20100704T000000.0+24:00",
                       "20100704T000000.0-12:60", "20100704T000000.0+12:60",
                       "2010-07-0400:00:00", "2010-07-04 00:00:00",
                       "2010-07-04t00:00:00", "2010-07-04T00:00:00.",
                       "2010-Jul-0400:00:00", "2010-Jul-04 00:00:00", "2010-Jul-04t00:00:00",
                       "2010-Jul-04T00:00:00", "2010-Jul-04 00:00:00.",
                       "2010-12-22T172201", "2010-Dec-22 17:22:01"])
        {
            assertThrown!DateTimeException(SysTime.fromISOString(str), format("[%s]", str));
        }

        static void test(string str, SysTime st, size_t line = __LINE__)
        {
            if (SysTime.fromISOString(str) != st)
                throw new AssertError("unittest failure", __FILE__, line);
        }

        test("20101222T172201", SysTime(DateTime(2010, 12, 22, 17, 22, 01)));
        test("19990706T123033", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test("-19990706T123033", SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        test("+019990706T123033", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test("19990706T123033 ", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test(" 19990706T123033", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test(" 19990706T123033 ", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));

        test("19070707T121212.0", SysTime(DateTime(1907, 07, 07, 12, 12, 12)));
        test("19070707T121212.0000000", SysTime(DateTime(1907, 07, 07, 12, 12, 12)));
        test("19070707T121212.0000001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), hnsecs(1)));
        test("19070707T121212.000001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), usecs(1)));
        test("19070707T121212.0000010", SysTime(DateTime(1907, 07, 07, 12, 12, 12), usecs(1)));
        test("19070707T121212.001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), msecs(1)));
        test("19070707T121212.0010000", SysTime(DateTime(1907, 07, 07, 12, 12, 12), msecs(1)));

        auto west60 = new immutable SimpleTimeZone(hours(-1));
        auto west90 = new immutable SimpleTimeZone(minutes(-90));
        auto west480 = new immutable SimpleTimeZone(hours(-8));
        auto east60 = new immutable SimpleTimeZone(hours(1));
        auto east90 = new immutable SimpleTimeZone(minutes(90));
        auto east480 = new immutable SimpleTimeZone(hours(8));

        test("20101222T172201Z", SysTime(DateTime(2010, 12, 22, 17, 22, 01), UTC()));
        test("20101222T172201-0100", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west60));
        test("20101222T172201-01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west60));
        test("20101222T172201-0130", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west90));
        test("20101222T172201-0800", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west480));
        test("20101222T172201+0100", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("20101222T172201+01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("20101222T172201+0130", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("20101222T172201+0800", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east480));

        test("20101103T065106.57159Z", SysTime(DateTime(2010, 11, 3, 6, 51, 6), hnsecs(5715900), UTC()));
        test("20101222T172201.23412Z", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(2_341_200), UTC()));
        test("20101222T172201.23112-0100", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(2_311_200), west60));
        test("20101222T172201.45-01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(4_500_000), west60));
        test("20101222T172201.1-0130", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_000_000), west90));
        test("20101222T172201.55-0800", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(5_500_000), west480));
        test("20101222T172201.1234567+0100", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_234_567), east60));
        test("20101222T172201.0+01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("20101222T172201.0000000+0130", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("20101222T172201.45+0800", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(4_500_000), east480));

        // @@@DEPRECATED_2017-07@@@
        // This isn't deprecated per se, but that text will make it so that it
        // pops up when deprecations are moved along around July 2017. At that
        // time, the notice on the documentation should be removed, and we may
        // or may not change the behavior of fromISOString to no longer accept
        // ISO extended time zones (the concern being that programs will have
        // written out strings somewhere to read in again that they'll still be
        // reading in for years to come and may not be able to fix, even if the
        // code is fixed). If/when we do change the behavior, these tests will
        // start failing and will need to be updated accordingly.
        test("20101222T172201-01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west60));
        test("20101222T172201-01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west90));
        test("20101222T172201-08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west480));
        test("20101222T172201+01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("20101222T172201+01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("20101222T172201+08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east480));

        test("20101222T172201.23112-01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(2_311_200), west60));
        test("20101222T172201.1-01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_000_000), west90));
        test("20101222T172201.55-08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(5_500_000), west480));
        test("20101222T172201.1234567+01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_234_567), east60));
        test("20101222T172201.0000000+01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("20101222T172201.45+08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(4_500_000), east480));
    }


    /++
        Creates a $(LREF SysTime) from a string with the format
        YYYY-MM-DDTHH:MM:SS.FFFFFFFTZ (where F is fractional seconds is the
        time zone). Whitespace is stripped from the given string.

        The exact format is exactly as described in $(D toISOExtString)
        except that trailing zeroes are permitted - including having fractional
        seconds with all zeroes. However, a decimal point with nothing following
        it is invalid.

        If there is no time zone in the string, then $(LREF LocalTime) is used.
        If the time zone is "Z", then $(D UTC) is used. Otherwise, a
        $(LREF SimpleTimeZone) which corresponds to the given offset from UTC is
        used. To get the returned $(LREF SysTime) to be a particular time
        zone, pass in that time zone and the $(LREF SysTime) to be returned
        will be converted to that time zone (though it will still be read in as
        whatever time zone is in its string).

        The accepted formats for time zone offsets are +HH, -HH, +HH:MM, and
        -HH:MM.

        Params:
            isoExtString = A string formatted in the ISO Extended format for
                           dates and times.
            tz           = The time zone to convert the given time to (no
                           conversion occurs if null).

        Throws:
            $(LREF DateTimeException) if the given string is not in the ISO
            format or if the resulting $(LREF SysTime) would not be valid.
      +/
    static SysTime fromISOExtString(S)(in S isoExtString, immutable TimeZone tz = null) @safe
        if (isSomeString!(S))
    {
        import std.algorithm.searching : countUntil, find;
        import std.conv : to;
        import std.range.primitives;
        import std.string : strip;

        auto dstr = to!dstring(strip(isoExtString));

        auto tIndex = dstr.countUntil('T');
        enforce(tIndex != -1, new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));

        auto found = dstr[tIndex + 1 .. $].find('.', 'Z', '+', '-');
        auto dateTimeStr = dstr[0 .. $ - found[0].length];

        dstring fracSecStr;
        dstring zoneStr;

        if (found[1] != 0)
        {
            if (found[1] == 1)
            {
                auto foundTZ = found[0].find('Z', '+', '-');

                if (foundTZ[1] != 0)
                {
                    fracSecStr = found[0][0 .. $ - foundTZ[0].length];
                    zoneStr = foundTZ[0];
                }
                else
                    fracSecStr = found[0];
            }
            else
                zoneStr = found[0];
        }

        try
        {
            auto dateTime = DateTime.fromISOExtString(dateTimeStr);
            auto fracSec = fracSecsFromISOString(fracSecStr);
            Rebindable!(immutable TimeZone) parsedZone;

            if (zoneStr.empty)
                parsedZone = LocalTime();
            else if (zoneStr == "Z")
                parsedZone = UTC();
            else
                parsedZone = SimpleTimeZone.fromISOExtString(zoneStr);

            auto retval = SysTime(dateTime, fracSec, parsedZone);

            if (tz !is null)
                retval.timezone = tz;

            return retval;
        }
        catch (DateTimeException dte)
            throw new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString));
    }

    ///
    @safe unittest
    {
        assert(SysTime.fromISOExtString("2010-07-04T07:06:12") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12)));

        assert(SysTime.fromISOExtString("1998-12-25T02:15:00.007") ==
               SysTime(DateTime(1998, 12, 25, 2, 15, 0), msecs(7)));

        assert(SysTime.fromISOExtString("0000-01-05T23:09:59.00002") ==
               SysTime(DateTime(0, 1, 5, 23, 9, 59), usecs(20)));

        assert(SysTime.fromISOExtString("-0004-01-05T00:00:02") ==
               SysTime(DateTime(-4, 1, 5, 0, 0, 2)));

        assert(SysTime.fromISOExtString(" 2010-07-04T07:06:12 ") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12)));

        assert(SysTime.fromISOExtString("2010-07-04T07:06:12Z") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12), UTC()));

        assert(SysTime.fromISOExtString("2010-07-04T07:06:12-08:00") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12),
                       new immutable SimpleTimeZone(hours(-8))));
        assert(SysTime.fromISOExtString("2010-07-04T07:06:12+08:00") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12),
                       new immutable SimpleTimeZone(hours(8))));
    }

    @safe unittest
    {
        foreach (str; ["", "20100704000000", "20100704 000000",
                       "20100704t000000", "20100704T000000.", "20100704T000000.0",
                       "2010-07:0400:00:00", "2010-07-04 00:00:00",
                       "2010-07-04 00:00:00", "2010-07-04t00:00:00",
                       "2010-07-04T00:00:00.", "2010-07-04T00:00:00.A", "2010-07-04T00:00:00.Z",
                       "2010-07-04T00:00:00.00000000", "2010-07-04T00:00:00.00000000",
                       "2010-07-04T00:00:00+", "2010-07-04T00:00:00-",
                       "2010-07-04T00:00:00:", "2010-07-04T00:00:00-:", "2010-07-04T00:00:00+:",
                       "2010-07-04T00:00:00-1:", "2010-07-04T00:00:00+1:", "2010-07-04T00:00:00+1:0",
                       "2010-07-04T00:00:00-12.00", "2010-07-04T00:00:00+12.00",
                       "2010-07-04T00:00:00-8", "2010-07-04T00:00:00+8",
                       "20100704T000000-800", "20100704T000000+800",
                       "20100704T000000-080", "20100704T000000+080",
                       "20100704T000000-2400", "20100704T000000+2400",
                       "20100704T000000-1260", "20100704T000000+1260",
                       "20100704T000000.0-800", "20100704T000000.0+800",
                       "20100704T000000.0-8", "20100704T000000.0+8",
                       "20100704T000000.0-080", "20100704T000000.0+080",
                       "20100704T000000.0-2400", "20100704T000000.0+2400",
                       "20100704T000000.0-1260", "20100704T000000.0+1260",
                       "2010-07-04T00:00:00-8:00", "2010-07-04T00:00:00+8:00",
                       "2010-07-04T00:00:00-24:00", "2010-07-04T00:00:00+24:00",
                       "2010-07-04T00:00:00-12:60", "2010-07-04T00:00:00+12:60",
                       "2010-07-04T00:00:00.0-8:00", "2010-07-04T00:00:00.0+8:00",
                       "2010-07-04T00:00:00.0-8", "2010-07-04T00:00:00.0+8",
                       "2010-07-04T00:00:00.0-24:00", "2010-07-04T00:00:00.0+24:00",
                       "2010-07-04T00:00:00.0-12:60", "2010-07-04T00:00:00.0+12:60",
                       "2010-Jul-0400:00:00", "2010-Jul-04t00:00:00",
                       "2010-Jul-04 00:00:00.", "2010-Jul-04 00:00:00.0",
                       "20101222T172201", "2010-Dec-22 17:22:01"])
        {
            assertThrown!DateTimeException(SysTime.fromISOExtString(str), format("[%s]", str));
        }

        static void test(string str, SysTime st, size_t line = __LINE__)
        {
            if (SysTime.fromISOExtString(str) != st)
                throw new AssertError("unittest failure", __FILE__, line);
        }

        test("2010-12-22T17:22:01", SysTime(DateTime(2010, 12, 22, 17, 22, 01)));
        test("1999-07-06T12:30:33", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test("-1999-07-06T12:30:33", SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        test("+01999-07-06T12:30:33", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test("1999-07-06T12:30:33 ", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test(" 1999-07-06T12:30:33", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test(" 1999-07-06T12:30:33 ", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));

        test("1907-07-07T12:12:12.0", SysTime(DateTime(1907, 07, 07, 12, 12, 12)));
        test("1907-07-07T12:12:12.0000000", SysTime(DateTime(1907, 07, 07, 12, 12, 12)));
        test("1907-07-07T12:12:12.0000001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), hnsecs(1)));
        test("1907-07-07T12:12:12.000001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), usecs(1)));
        test("1907-07-07T12:12:12.0000010", SysTime(DateTime(1907, 07, 07, 12, 12, 12), usecs(1)));
        test("1907-07-07T12:12:12.001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), msecs(1)));
        test("1907-07-07T12:12:12.0010000", SysTime(DateTime(1907, 07, 07, 12, 12, 12), msecs(1)));

        auto west60 = new immutable SimpleTimeZone(hours(-1));
        auto west90 = new immutable SimpleTimeZone(minutes(-90));
        auto west480 = new immutable SimpleTimeZone(hours(-8));
        auto east60 = new immutable SimpleTimeZone(hours(1));
        auto east90 = new immutable SimpleTimeZone(minutes(90));
        auto east480 = new immutable SimpleTimeZone(hours(8));

        test("2010-12-22T17:22:01Z", SysTime(DateTime(2010, 12, 22, 17, 22, 01), UTC()));
        test("2010-12-22T17:22:01-01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west60));
        test("2010-12-22T17:22:01-01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west60));
        test("2010-12-22T17:22:01-01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west90));
        test("2010-12-22T17:22:01-08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west480));
        test("2010-12-22T17:22:01+01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("2010-12-22T17:22:01+01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("2010-12-22T17:22:01+01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("2010-12-22T17:22:01+08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east480));

        test("2010-11-03T06:51:06.57159Z", SysTime(DateTime(2010, 11, 3, 6, 51, 6), hnsecs(5715900), UTC()));
        test("2010-12-22T17:22:01.23412Z", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(2_341_200), UTC()));
        test("2010-12-22T17:22:01.23112-01:00",
             SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(2_311_200), west60));
        test("2010-12-22T17:22:01.45-01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(4_500_000), west60));
        test("2010-12-22T17:22:01.1-01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_000_000), west90));
        test("2010-12-22T17:22:01.55-08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(5_500_000), west480));
        test("2010-12-22T17:22:01.1234567+01:00",
             SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_234_567), east60));
        test("2010-12-22T17:22:01.0+01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("2010-12-22T17:22:01.0000000+01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("2010-12-22T17:22:01.45+08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(4_500_000), east480));
    }


    /++
        Creates a $(LREF SysTime) from a string with the format
        YYYY-MM-DD HH:MM:SS.FFFFFFFTZ (where F is fractional seconds is the
        time zone). Whitespace is stripped from the given string.

        The exact format is exactly as described in $(D toSimpleString) except
        that trailing zeroes are permitted - including having fractional seconds
        with all zeroes. However, a decimal point with nothing following it is
        invalid.

        If there is no time zone in the string, then $(LREF LocalTime) is used. If
        the time zone is "Z", then $(D UTC) is used. Otherwise, a
        $(LREF SimpleTimeZone) which corresponds to the given offset from UTC is
        used. To get the returned $(LREF SysTime) to be a particular time
        zone, pass in that time zone and the $(LREF SysTime) to be returned
        will be converted to that time zone (though it will still be read in as
        whatever time zone is in its string).

        The accepted formats for time zone offsets are +HH, -HH, +HH:MM, and
        -HH:MM.

        Params:
            simpleString = A string formatted in the way that
                           $(D toSimpleString) formats dates and times.
            tz           = The time zone to convert the given time to (no
                           conversion occurs if null).

        Throws:
            $(LREF DateTimeException) if the given string is not in the ISO format
            or if the resulting $(LREF SysTime) would not be valid.
      +/
    static SysTime fromSimpleString(S)(in S simpleString, immutable TimeZone tz = null) @safe
        if (isSomeString!(S))
    {
        import std.algorithm.searching : countUntil, find;
        import std.conv : to;
        import std.range.primitives;
        import std.string : strip;

        auto dstr = to!dstring(strip(simpleString));

        auto spaceIndex = dstr.countUntil(' ');
        enforce(spaceIndex != -1, new DateTimeException(format("Invalid Simple String: %s", simpleString)));

        auto found = dstr[spaceIndex + 1 .. $].find('.', 'Z', '+', '-');
        auto dateTimeStr = dstr[0 .. $ - found[0].length];

        dstring fracSecStr;
        dstring zoneStr;

        if (found[1] != 0)
        {
            if (found[1] == 1)
            {
                auto foundTZ = found[0].find('Z', '+', '-');

                if (foundTZ[1] != 0)
                {
                    fracSecStr = found[0][0 .. $ - foundTZ[0].length];
                    zoneStr = foundTZ[0];
                }
                else
                    fracSecStr = found[0];
            }
            else
                zoneStr = found[0];
        }

        try
        {
            auto dateTime = DateTime.fromSimpleString(dateTimeStr);
            auto fracSec = fracSecsFromISOString(fracSecStr);
            Rebindable!(immutable TimeZone) parsedZone;

            if (zoneStr.empty)
                parsedZone = LocalTime();
            else if (zoneStr == "Z")
                parsedZone = UTC();
            else
                parsedZone = SimpleTimeZone.fromISOExtString(zoneStr);

            auto retval = SysTime(dateTime, fracSec, parsedZone);

            if (tz !is null)
                retval.timezone = tz;

            return retval;
        }
        catch (DateTimeException dte)
            throw new DateTimeException(format("Invalid Simple String: %s", simpleString));
    }

    ///
    @safe unittest
    {
        assert(SysTime.fromSimpleString("2010-Jul-04 07:06:12") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12)));

        assert(SysTime.fromSimpleString("1998-Dec-25 02:15:00.007") ==
               SysTime(DateTime(1998, 12, 25, 2, 15, 0), msecs(7)));

        assert(SysTime.fromSimpleString("0000-Jan-05 23:09:59.00002") ==
               SysTime(DateTime(0, 1, 5, 23, 9, 59), usecs(20)));

        assert(SysTime.fromSimpleString("-0004-Jan-05 00:00:02") ==
               SysTime(DateTime(-4, 1, 5, 0, 0, 2)));

        assert(SysTime.fromSimpleString(" 2010-Jul-04 07:06:12 ") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12)));

        assert(SysTime.fromSimpleString("2010-Jul-04 07:06:12Z") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12), UTC()));

        assert(SysTime.fromSimpleString("2010-Jul-04 07:06:12-08:00") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12),
                       new immutable SimpleTimeZone(hours(-8))));

        assert(SysTime.fromSimpleString("2010-Jul-04 07:06:12+08:00") ==
               SysTime(DateTime(2010, 7, 4, 7, 6, 12),
                       new immutable SimpleTimeZone(hours(8))));
    }

    @safe unittest
    {
        foreach (str; ["", "20100704000000", "20100704 000000",
                       "20100704t000000", "20100704T000000.", "20100704T000000.0",
                       "2010-07-0400:00:00", "2010-07-04 00:00:00", "2010-07-04t00:00:00",
                       "2010-07-04T00:00:00.", "2010-07-04T00:00:00.0",
                       "2010-Jul-0400:00:00", "2010-Jul-04t00:00:00", "2010-Jul-04T00:00:00",
                       "2010-Jul-04 00:00:00.", "2010-Jul-04 00:00:00.A", "2010-Jul-04 00:00:00.Z",
                       "2010-Jul-04 00:00:00.00000000", "2010-Jul-04 00:00:00.00000000",
                       "2010-Jul-04 00:00:00+", "2010-Jul-04 00:00:00-",
                       "2010-Jul-04 00:00:00:", "2010-Jul-04 00:00:00-:",
                       "2010-Jul-04 00:00:00+:", "2010-Jul-04 00:00:00-1:",
                       "2010-Jul-04 00:00:00+1:", "2010-Jul-04 00:00:00+1:0",
                       "2010-Jul-04 00:00:00-12.00", "2010-Jul-04 00:00:00+12.00",
                       "2010-Jul-04 00:00:00-8", "2010-Jul-04 00:00:00+8",
                       "20100704T000000-800", "20100704T000000+800",
                       "20100704T000000-080", "20100704T000000+080",
                       "20100704T000000-2400", "20100704T000000+2400",
                       "20100704T000000-1260", "20100704T000000+1260",
                       "20100704T000000.0-800", "20100704T000000.0+800",
                       "20100704T000000.0-8", "20100704T000000.0+8",
                       "20100704T000000.0-080", "20100704T000000.0+080",
                       "20100704T000000.0-2400", "20100704T000000.0+2400",
                       "20100704T000000.0-1260", "20100704T000000.0+1260",
                       "2010-Jul-04 00:00:00-8:00", "2010-Jul-04 00:00:00+8:00",
                       "2010-Jul-04 00:00:00-08:0", "2010-Jul-04 00:00:00+08:0",
                       "2010-Jul-04 00:00:00-24:00", "2010-Jul-04 00:00:00+24:00",
                       "2010-Jul-04 00:00:00-12:60", "2010-Jul-04 00:00:00+24:60",
                       "2010-Jul-04 00:00:00.0-8:00", "2010-Jul-04 00:00:00+8:00",
                       "2010-Jul-04 00:00:00.0-8", "2010-Jul-04 00:00:00.0+8",
                       "2010-Jul-04 00:00:00.0-08:0", "2010-Jul-04 00:00:00.0+08:0",
                       "2010-Jul-04 00:00:00.0-24:00", "2010-Jul-04 00:00:00.0+24:00",
                       "2010-Jul-04 00:00:00.0-12:60", "2010-Jul-04 00:00:00.0+24:60",
                       "20101222T172201", "2010-12-22T172201"])
        {
            assertThrown!DateTimeException(SysTime.fromSimpleString(str), format("[%s]", str));
        }

        static void test(string str, SysTime st, size_t line = __LINE__)
        {
            if (SysTime.fromSimpleString(str) != st)
                throw new AssertError("unittest failure", __FILE__, line);
        }

        test("2010-Dec-22 17:22:01", SysTime(DateTime(2010, 12, 22, 17, 22, 01)));
        test("1999-Jul-06 12:30:33", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test("-1999-Jul-06 12:30:33", SysTime(DateTime(-1999, 7, 6, 12, 30, 33)));
        test("+01999-Jul-06 12:30:33", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test("1999-Jul-06 12:30:33 ", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test(" 1999-Jul-06 12:30:33", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));
        test(" 1999-Jul-06 12:30:33 ", SysTime(DateTime(1999, 7, 6, 12, 30, 33)));

        test("1907-Jul-07 12:12:12.0", SysTime(DateTime(1907, 07, 07, 12, 12, 12)));
        test("1907-Jul-07 12:12:12.0000000", SysTime(DateTime(1907, 07, 07, 12, 12, 12)));
        test("1907-Jul-07 12:12:12.0000001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), hnsecs(1)));
        test("1907-Jul-07 12:12:12.000001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), usecs(1)));
        test("1907-Jul-07 12:12:12.0000010", SysTime(DateTime(1907, 07, 07, 12, 12, 12), usecs(1)));
        test("1907-Jul-07 12:12:12.001", SysTime(DateTime(1907, 07, 07, 12, 12, 12), msecs(1)));
        test("1907-Jul-07 12:12:12.0010000", SysTime(DateTime(1907, 07, 07, 12, 12, 12), msecs(1)));

        auto west60 = new immutable SimpleTimeZone(hours(-1));
        auto west90 = new immutable SimpleTimeZone(minutes(-90));
        auto west480 = new immutable SimpleTimeZone(hours(-8));
        auto east60 = new immutable SimpleTimeZone(hours(1));
        auto east90 = new immutable SimpleTimeZone(minutes(90));
        auto east480 = new immutable SimpleTimeZone(hours(8));

        test("2010-Dec-22 17:22:01Z", SysTime(DateTime(2010, 12, 22, 17, 22, 01), UTC()));
        test("2010-Dec-22 17:22:01-01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west60));
        test("2010-Dec-22 17:22:01-01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west60));
        test("2010-Dec-22 17:22:01-01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west90));
        test("2010-Dec-22 17:22:01-08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), west480));
        test("2010-Dec-22 17:22:01+01:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("2010-Dec-22 17:22:01+01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("2010-Dec-22 17:22:01+01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("2010-Dec-22 17:22:01+08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east480));

        test("2010-Nov-03 06:51:06.57159Z", SysTime(DateTime(2010, 11, 3, 6, 51, 6), hnsecs(5715900), UTC()));
        test("2010-Dec-22 17:22:01.23412Z", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(2_341_200), UTC()));
        test("2010-Dec-22 17:22:01.23112-01:00",
             SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(2_311_200), west60));
        test("2010-Dec-22 17:22:01.45-01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(4_500_000), west60));
        test("2010-Dec-22 17:22:01.1-01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_000_000), west90));
        test("2010-Dec-22 17:22:01.55-08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(5_500_000), west480));
        test("2010-Dec-22 17:22:01.1234567+01:00",
             SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(1_234_567), east60));
        test("2010-Dec-22 17:22:01.0+01", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east60));
        test("2010-Dec-22 17:22:01.0000000+01:30", SysTime(DateTime(2010, 12, 22, 17, 22, 01), east90));
        test("2010-Dec-22 17:22:01.45+08:00", SysTime(DateTime(2010, 12, 22, 17, 22, 01), hnsecs(4_500_000), east480));
    }


    /++
        Returns the $(LREF SysTime) farthest in the past which is representable
        by $(LREF SysTime).

        The $(LREF SysTime) which is returned is in UTC.
      +/
    @property static SysTime min() @safe pure nothrow
    {
        return SysTime(long.min, UTC());
    }

    @safe unittest
    {
        assert(SysTime.min.year < 0);
        assert(SysTime.min < SysTime.max);
    }


    /++
        Returns the $(LREF SysTime) farthest in the future which is representable
        by $(LREF SysTime).

        The $(LREF SysTime) which is returned is in UTC.
      +/
    @property static SysTime max() @safe pure nothrow
    {
        return SysTime(long.max, UTC());
    }

    @safe unittest
    {
        assert(SysTime.max.year > 0);
        assert(SysTime.max > SysTime.min);
    }


private:

    /+
        Returns $(D stdTime) converted to $(LREF SysTime)'s time zone.
      +/
    @property long adjTime() @safe const nothrow
    {
        return _timezone.utcToTZ(_stdTime);
    }


    /+
        Converts the given hnsecs from $(LREF SysTime)'s time zone to std time.
      +/
    @property void adjTime(long adjTime) @safe nothrow
    {
        _stdTime = _timezone.tzToUTC(adjTime);
    }


    // Commented out due to bug http://d.puremagic.com/issues/show_bug.cgi?id=5058
    /+
    invariant()
    {
        assert(_timezone !is null, "Invariant Failure: timezone is null. Were you foolish enough to use " ~
                                   "SysTime.init? (since timezone for SysTime.init can't be set at compile time).");
    }
    +/


    long  _stdTime;
    Rebindable!(immutable TimeZone) _timezone;
}


/++
    Converts from unix time (which uses midnight, January 1st, 1970 UTC as its
    epoch and seconds as its units) to "std time" (which uses midnight,
    January 1st, 1 A.D. UTC and hnsecs as its units).

    The C standard does not specify the representation of time_t, so it is
    implementation defined. On POSIX systems, unix time is equivalent to
    time_t, but that's not necessarily true on other systems (e.g. it is
    not true for the Digital Mars C runtime). So, be careful when using unix
    time with C functions on non-POSIX systems.

    "std time"'s epoch is based on the Proleptic Gregorian Calendar per ISO
    8601 and is what $(LREF SysTime) uses internally. However, holding the time
    as an integer in hnescs since that epoch technically isn't actually part of
    the standard, much as it's based on it, so the name "std time" isn't
    particularly good, but there isn't an official name for it. C# uses "ticks"
    for the same thing, but they aren't actually clock ticks, and the term
    "ticks" $(I is) used for actual clock ticks for $(REF MonoTime, core,time), so
    it didn't make sense to use the term ticks here. So, for better or worse,
    std.datetime uses the term "std time" for this.

    Params:
        unixTime = The unix time to convert.

    See_Also:
        SysTime.fromUnixTime
  +/
long unixTimeToStdTime(long unixTime) @safe pure nothrow
{
    return 621_355_968_000_000_000L + convert!("seconds", "hnsecs")(unixTime);
}

///
@safe unittest
{
    // Midnight, January 1st, 1970
    assert(unixTimeToStdTime(0) == 621_355_968_000_000_000L);
    assert(SysTime(unixTimeToStdTime(0)) ==
           SysTime(DateTime(1970, 1, 1), UTC()));

    assert(unixTimeToStdTime(int.max) == 642_830_804_470_000_000L);
    assert(SysTime(unixTimeToStdTime(int.max)) ==
           SysTime(DateTime(2038, 1, 19, 3, 14, 07), UTC()));

    assert(unixTimeToStdTime(-127_127) == 621_354_696_730_000_000L);
    assert(SysTime(unixTimeToStdTime(-127_127)) ==
           SysTime(DateTime(1969, 12, 30, 12, 41, 13), UTC()));
}

@safe unittest
{
    // Midnight, January 2nd, 1970
    assert(unixTimeToStdTime(86_400) == 621_355_968_000_000_000L + 864_000_000_000L);
    // Midnight, December 31st, 1969
    assert(unixTimeToStdTime(-86_400) == 621_355_968_000_000_000L - 864_000_000_000L);

    assert(unixTimeToStdTime(0) == (Date(1970, 1, 1) - Date(1, 1, 1)).total!"hnsecs");
    assert(unixTimeToStdTime(0) == (DateTime(1970, 1, 1) - DateTime(1, 1, 1)).total!"hnsecs");

    foreach (dt; [DateTime(2010, 11, 1, 19, 5, 22), DateTime(1952, 7, 6, 2, 17, 9)])
        assert(unixTimeToStdTime((dt - DateTime(1970, 1, 1)).total!"seconds") == (dt - DateTime.init).total!"hnsecs");
}


/++
    Converts std time (which uses midnight, January 1st, 1 A.D. UTC as its epoch
    and hnsecs as its units) to unix time (which uses midnight, January 1st,
    1970 UTC as its epoch and seconds as its units).

    The C standard does not specify the representation of time_t, so it is
    implementation defined. On POSIX systems, unix time is equivalent to
    time_t, but that's not necessarily true on other systems (e.g. it is
    not true for the Digital Mars C runtime). So, be careful when using unix
    time with C functions on non-POSIX systems.

    "std time"'s epoch is based on the Proleptic Gregorian Calendar per ISO
    8601 and is what $(LREF SysTime) uses internally. However, holding the time
    as an integer in hnescs since that epoch technically isn't actually part of
    the standard, much as it's based on it, so the name "std time" isn't
    particularly good, but there isn't an official name for it. C# uses "ticks"
    for the same thing, but they aren't actually clock ticks, and the term
    "ticks" $(I is) used for actual clock ticks for $(REF MonoTime, core,time), so
    it didn't make sense to use the term ticks here. So, for better or worse,
    std.datetime uses the term "std time" for this.

    By default, the return type is time_t (which is normally an alias for
    int on 32-bit systems and long on 64-bit systems), but if a different
    size is required than either int or long can be passed as a template
    argument to get the desired size.

    If the return type is int, and the result can't fit in an int, then the
    closest value that can be held in 32 bits will be used (so $(D int.max)
    if it goes over and $(D int.min) if it goes under). However, no attempt
    is made to deal with integer overflow if the return type is long.

    Params:
        T = The return type (int or long). It defaults to time_t, which is
            normally 32 bits on a 32-bit system and 64 bits on a 64-bit
            system.
        stdTime = The std time to convert.

    Returns:
        A signed integer representing the unix time which is equivalent to
        the given std time.

    See_Also:
        SysTime.toUnixTime
  +/
T stdTimeToUnixTime(T = time_t)(long stdTime) @safe pure nothrow
if (is(T == int) || is(T == long))
{
    immutable unixTime = convert!("hnsecs", "seconds")(stdTime - 621_355_968_000_000_000L);

    static assert(is(time_t == int) || is(time_t == long),
                  "Currently, std.datetime only supports systems where time_t is int or long");

    static if (is(T == long))
        return unixTime;
    else static if (is(T == int))
    {
        if (unixTime > int.max)
            return int.max;
        return unixTime < int.min ? int.min : cast(int) unixTime;
    }
    else
        static assert(0, "Bug in template constraint. Only int and long allowed.");
}

///
@safe unittest
{
    // Midnight, January 1st, 1970 UTC
    assert(stdTimeToUnixTime(621_355_968_000_000_000L) == 0);

    // 2038-01-19 03:14:07 UTC
    assert(stdTimeToUnixTime(642_830_804_470_000_000L) == int.max);
}

@safe unittest
{
    enum unixEpochAsStdTime = (Date(1970, 1, 1) - Date.init).total!"hnsecs";

    assert(stdTimeToUnixTime(unixEpochAsStdTime) == 0);  // Midnight, January 1st, 1970
    assert(stdTimeToUnixTime(unixEpochAsStdTime + 864_000_000_000L) == 86_400);  // Midnight, January 2nd, 1970
    assert(stdTimeToUnixTime(unixEpochAsStdTime - 864_000_000_000L) == -86_400);  // Midnight, December 31st, 1969

    assert(stdTimeToUnixTime((Date(1970, 1, 1) - Date(1, 1, 1)).total!"hnsecs") == 0);
    assert(stdTimeToUnixTime((DateTime(1970, 1, 1) - DateTime(1, 1, 1)).total!"hnsecs") == 0);

    foreach (dt; [DateTime(2010, 11, 1, 19, 5, 22), DateTime(1952, 7, 6, 2, 17, 9)])
        assert(stdTimeToUnixTime((dt - DateTime.init).total!"hnsecs") == (dt - DateTime(1970, 1, 1)).total!"seconds");

    enum max = convert!("seconds", "hnsecs")(int.max);
    enum min = convert!("seconds", "hnsecs")(int.min);
    enum one = convert!("seconds", "hnsecs")(1);

    assert(stdTimeToUnixTime!long(unixEpochAsStdTime + max) == int.max);
    assert(stdTimeToUnixTime!int(unixEpochAsStdTime + max) == int.max);

    assert(stdTimeToUnixTime!long(unixEpochAsStdTime + max + one) == int.max + 1L);
    assert(stdTimeToUnixTime!int(unixEpochAsStdTime + max + one) == int.max);
    assert(stdTimeToUnixTime!long(unixEpochAsStdTime + max + 9_999_999) == int.max);
    assert(stdTimeToUnixTime!int(unixEpochAsStdTime + max + 9_999_999) == int.max);

    assert(stdTimeToUnixTime!long(unixEpochAsStdTime + min) == int.min);
    assert(stdTimeToUnixTime!int(unixEpochAsStdTime + min) == int.min);

    assert(stdTimeToUnixTime!long(unixEpochAsStdTime + min - one) == int.min - 1L);
    assert(stdTimeToUnixTime!int(unixEpochAsStdTime + min - one) == int.min);
    assert(stdTimeToUnixTime!long(unixEpochAsStdTime + min - 9_999_999) == int.min);
    assert(stdTimeToUnixTime!int(unixEpochAsStdTime + min - 9_999_999) == int.min);
}


private:

/+
    Returns the given hnsecs as an ISO string of fractional seconds.
  +/
static string fracSecsToISOString(int hnsecs) @safe pure nothrow
{
    import std.range.primitives : popBack;
    assert(hnsecs >= 0);

    try
    {
        if (hnsecs == 0)
            return "";

        string isoString = format(".%07d", hnsecs);

        while (isoString[$ - 1] == '0')
            isoString.popBack();

        return isoString;
    }
    catch (Exception e)
        assert(0, "format() threw.");
}

@safe unittest
{
    assert(fracSecsToISOString(0) == "");
    assert(fracSecsToISOString(1) == ".0000001");
    assert(fracSecsToISOString(10) == ".000001");
    assert(fracSecsToISOString(100) == ".00001");
    assert(fracSecsToISOString(1000) == ".0001");
    assert(fracSecsToISOString(10_000) == ".001");
    assert(fracSecsToISOString(100_000) == ".01");
    assert(fracSecsToISOString(1_000_000) == ".1");
    assert(fracSecsToISOString(1_000_001) == ".1000001");
    assert(fracSecsToISOString(1_001_001) == ".1001001");
    assert(fracSecsToISOString(1_071_601) == ".1071601");
    assert(fracSecsToISOString(1_271_641) == ".1271641");
    assert(fracSecsToISOString(9_999_999) == ".9999999");
    assert(fracSecsToISOString(9_999_990) == ".999999");
    assert(fracSecsToISOString(9_999_900) == ".99999");
    assert(fracSecsToISOString(9_999_000) == ".9999");
    assert(fracSecsToISOString(9_990_000) == ".999");
    assert(fracSecsToISOString(9_900_000) == ".99");
    assert(fracSecsToISOString(9_000_000) == ".9");
    assert(fracSecsToISOString(999) == ".0000999");
    assert(fracSecsToISOString(9990) == ".000999");
    assert(fracSecsToISOString(99_900) == ".00999");
    assert(fracSecsToISOString(999_000) == ".0999");
}


/+
    Returns a Duration corresponding to to the given ISO string of
    fractional seconds.
  +/
static Duration fracSecsFromISOString(S)(in S isoString) @trusted pure
if (isSomeString!S)
{
    import std.algorithm.searching : all;
    import std.ascii : isDigit;
    import std.conv : to;
    import std.range.primitives;
    import std.string : representation;

    if (isoString.empty)
        return Duration.zero;

    auto str = isoString.representation;

    enforce(str[0] == '.', new DateTimeException("Invalid ISO String"));
    str.popFront();

    enforce(!str.empty && str.length <= 7, new DateTimeException("Invalid ISO String"));
    enforce(all!isDigit(str), new DateTimeException("Invalid ISO String"));

    dchar[7] fullISOString = void;
    foreach (i, ref dchar c; fullISOString)
    {
        if (i < str.length)
            c = str[i];
        else
            c = '0';
    }

    return hnsecs(to!int(fullISOString[]));
}

@safe unittest
{
    static void testFSInvalid(string isoString)
    {
        fracSecsFromISOString(isoString);
    }

    assertThrown!DateTimeException(testFSInvalid("."));
    assertThrown!DateTimeException(testFSInvalid("0."));
    assertThrown!DateTimeException(testFSInvalid("0"));
    assertThrown!DateTimeException(testFSInvalid("0000000"));
    assertThrown!DateTimeException(testFSInvalid(".00000000"));
    assertThrown!DateTimeException(testFSInvalid(".00000001"));
    assertThrown!DateTimeException(testFSInvalid("T"));
    assertThrown!DateTimeException(testFSInvalid("T."));
    assertThrown!DateTimeException(testFSInvalid(".T"));

    assert(fracSecsFromISOString("") == Duration.zero);
    assert(fracSecsFromISOString(".0000001") == hnsecs(1));
    assert(fracSecsFromISOString(".000001") == hnsecs(10));
    assert(fracSecsFromISOString(".00001") == hnsecs(100));
    assert(fracSecsFromISOString(".0001") == hnsecs(1000));
    assert(fracSecsFromISOString(".001") == hnsecs(10_000));
    assert(fracSecsFromISOString(".01") == hnsecs(100_000));
    assert(fracSecsFromISOString(".1") == hnsecs(1_000_000));
    assert(fracSecsFromISOString(".1000001") == hnsecs(1_000_001));
    assert(fracSecsFromISOString(".1001001") == hnsecs(1_001_001));
    assert(fracSecsFromISOString(".1071601") == hnsecs(1_071_601));
    assert(fracSecsFromISOString(".1271641") == hnsecs(1_271_641));
    assert(fracSecsFromISOString(".9999999") == hnsecs(9_999_999));
    assert(fracSecsFromISOString(".9999990") == hnsecs(9_999_990));
    assert(fracSecsFromISOString(".999999") == hnsecs(9_999_990));
    assert(fracSecsFromISOString(".9999900") == hnsecs(9_999_900));
    assert(fracSecsFromISOString(".99999") == hnsecs(9_999_900));
    assert(fracSecsFromISOString(".9999000") == hnsecs(9_999_000));
    assert(fracSecsFromISOString(".9999") == hnsecs(9_999_000));
    assert(fracSecsFromISOString(".9990000") == hnsecs(9_990_000));
    assert(fracSecsFromISOString(".999") == hnsecs(9_990_000));
    assert(fracSecsFromISOString(".9900000") == hnsecs(9_900_000));
    assert(fracSecsFromISOString(".9900") == hnsecs(9_900_000));
    assert(fracSecsFromISOString(".99") == hnsecs(9_900_000));
    assert(fracSecsFromISOString(".9000000") == hnsecs(9_000_000));
    assert(fracSecsFromISOString(".9") == hnsecs(9_000_000));
    assert(fracSecsFromISOString(".0000999") == hnsecs(999));
    assert(fracSecsFromISOString(".0009990") == hnsecs(9990));
    assert(fracSecsFromISOString(".000999") == hnsecs(9990));
    assert(fracSecsFromISOString(".0099900") == hnsecs(99_900));
    assert(fracSecsFromISOString(".00999") == hnsecs(99_900));
    assert(fracSecsFromISOString(".0999000") == hnsecs(999_000));
    assert(fracSecsFromISOString(".0999") == hnsecs(999_000));
}


/+
    This function is used to split out the units without getting the remaining
    hnsecs.

    See_Also:
        $(LREF splitUnitsFromHNSecs)

    Params:
        units  = The units to split out.
        hnsecs = The current total hnsecs.

    Returns:
        The split out value.
  +/
long getUnitsFromHNSecs(string units)(long hnsecs) @safe pure nothrow
if (validTimeUnits(units) &&
    CmpTimeUnits!(units, "months") < 0)
{
    return convert!("hnsecs", units)(hnsecs);
}

@safe unittest
{
    auto hnsecs = 2595000000007L;
    immutable days = getUnitsFromHNSecs!"days"(hnsecs);
    assert(days == 3);
    assert(hnsecs == 2595000000007L);
}


/+
    This function is used to split out the units without getting the units but
    just the remaining hnsecs.

    See_Also:
        $(LREF splitUnitsFromHNSecs)

    Params:
        units  = The units to split out.
        hnsecs = The current total hnsecs.

    Returns:
        The remaining hnsecs.
  +/
long removeUnitsFromHNSecs(string units)(long hnsecs) @safe pure nothrow
if (validTimeUnits(units) &&
    CmpTimeUnits!(units, "months") < 0)
{
    immutable value = convert!("hnsecs", units)(hnsecs);
    return hnsecs - convert!(units, "hnsecs")(value);
}

@safe unittest
{
    auto hnsecs = 2595000000007L;
    auto returned = removeUnitsFromHNSecs!"days"(hnsecs);
    assert(returned == 3000000007);
    assert(hnsecs == 2595000000007L);
}


version(unittest)
{
    // Variables to help in testing.
    Duration currLocalDiffFromUTC;
    immutable (TimeZone)[] testTZs;

    // All of these helper arrays are sorted in ascending order.
    auto testYearsBC = [-1999, -1200, -600, -4, -1, 0];
    auto testYearsAD = [1, 4, 1000, 1999, 2000, 2012];

    // I'd use a Tuple, but I get forward reference errors if I try.
    struct MonthDay
    {
        Month month;
        short day;

        this(int m, short d)
        {
            month = cast(Month) m;
            day = d;
        }
    }

    MonthDay[] testMonthDays = [MonthDay(1, 1),
                                MonthDay(1, 2),
                                MonthDay(3, 17),
                                MonthDay(7, 4),
                                MonthDay(10, 27),
                                MonthDay(12, 30),
                                MonthDay(12, 31)];

    auto testDays = [1, 2, 9, 10, 16, 20, 25, 28, 29, 30, 31];

    auto testTODs = [TimeOfDay(0, 0, 0),
                     TimeOfDay(0, 0, 1),
                     TimeOfDay(0, 1, 0),
                     TimeOfDay(1, 0, 0),
                     TimeOfDay(13, 13, 13),
                     TimeOfDay(23, 59, 59)];

    auto testHours = [0, 1, 12, 22, 23];
    auto testMinSecs = [0, 1, 30, 58, 59];

    // Throwing exceptions is incredibly expensive, so we want to use a smaller
    // set of values for tests using assertThrown.
    auto testTODsThrown = [TimeOfDay(0, 0, 0),
                           TimeOfDay(13, 13, 13),
                           TimeOfDay(23, 59, 59)];

    Date[] testDatesBC;
    Date[] testDatesAD;

    DateTime[] testDateTimesBC;
    DateTime[] testDateTimesAD;

    Duration[] testFracSecs;

    SysTime[] testSysTimesBC;
    SysTime[] testSysTimesAD;

    // I'd use a Tuple, but I get forward reference errors if I try.
    struct GregDay { int day; Date date; }
    auto testGregDaysBC = [GregDay(-1_373_427, Date(-3760, 9, 7)), // Start of the Hebrew Calendar
                           GregDay(-735_233, Date(-2012, 1, 1)),
                           GregDay(-735_202, Date(-2012, 2, 1)),
                           GregDay(-735_175, Date(-2012, 2, 28)),
                           GregDay(-735_174, Date(-2012, 2, 29)),
                           GregDay(-735_173, Date(-2012, 3, 1)),
                           GregDay(-734_502, Date(-2010, 1, 1)),
                           GregDay(-734_472, Date(-2010, 1, 31)),
                           GregDay(-734_471, Date(-2010, 2, 1)),
                           GregDay(-734_444, Date(-2010, 2, 28)),
                           GregDay(-734_443, Date(-2010, 3, 1)),
                           GregDay(-734_413, Date(-2010, 3, 31)),
                           GregDay(-734_412, Date(-2010, 4, 1)),
                           GregDay(-734_383, Date(-2010, 4, 30)),
                           GregDay(-734_382, Date(-2010, 5, 1)),
                           GregDay(-734_352, Date(-2010, 5, 31)),
                           GregDay(-734_351, Date(-2010, 6, 1)),
                           GregDay(-734_322, Date(-2010, 6, 30)),
                           GregDay(-734_321, Date(-2010, 7, 1)),
                           GregDay(-734_291, Date(-2010, 7, 31)),
                           GregDay(-734_290, Date(-2010, 8, 1)),
                           GregDay(-734_260, Date(-2010, 8, 31)),
                           GregDay(-734_259, Date(-2010, 9, 1)),
                           GregDay(-734_230, Date(-2010, 9, 30)),
                           GregDay(-734_229, Date(-2010, 10, 1)),
                           GregDay(-734_199, Date(-2010, 10, 31)),
                           GregDay(-734_198, Date(-2010, 11, 1)),
                           GregDay(-734_169, Date(-2010, 11, 30)),
                           GregDay(-734_168, Date(-2010, 12, 1)),
                           GregDay(-734_139, Date(-2010, 12, 30)),
                           GregDay(-734_138, Date(-2010, 12, 31)),
                           GregDay(-731_215, Date(-2001, 1, 1)),
                           GregDay(-730_850, Date(-2000, 1, 1)),
                           GregDay(-730_849, Date(-2000, 1, 2)),
                           GregDay(-730_486, Date(-2000, 12, 30)),
                           GregDay(-730_485, Date(-2000, 12, 31)),
                           GregDay(-730_484, Date(-1999, 1, 1)),
                           GregDay(-694_690, Date(-1901, 1, 1)),
                           GregDay(-694_325, Date(-1900, 1, 1)),
                           GregDay(-585_118, Date(-1601, 1, 1)),
                           GregDay(-584_753, Date(-1600, 1, 1)),
                           GregDay(-584_388, Date(-1600, 12, 31)),
                           GregDay(-584_387, Date(-1599, 1, 1)),
                           GregDay(-365_972, Date(-1001, 1, 1)),
                           GregDay(-365_607, Date(-1000, 1, 1)),
                           GregDay(-183_351, Date(-501, 1, 1)),
                           GregDay(-182_986, Date(-500, 1, 1)),
                           GregDay(-182_621, Date(-499, 1, 1)),
                           GregDay(-146_827, Date(-401, 1, 1)),
                           GregDay(-146_462, Date(-400, 1, 1)),
                           GregDay(-146_097, Date(-400, 12, 31)),
                           GregDay(-110_302, Date(-301, 1, 1)),
                           GregDay(-109_937, Date(-300, 1, 1)),
                           GregDay(-73_778, Date(-201, 1, 1)),
                           GregDay(-73_413, Date(-200, 1, 1)),
                           GregDay(-38_715, Date(-105, 1, 1)),
                           GregDay(-37_254, Date(-101, 1, 1)),
                           GregDay(-36_889, Date(-100, 1, 1)),
                           GregDay(-36_524, Date(-99, 1, 1)),
                           GregDay(-36_160, Date(-99, 12, 31)),
                           GregDay(-35_794, Date(-97, 1, 1)),
                           GregDay(-18_627, Date(-50, 1, 1)),
                           GregDay(-18_262, Date(-49, 1, 1)),
                           GregDay(-3652, Date(-9, 1, 1)),
                           GregDay(-2191, Date(-5, 1, 1)),
                           GregDay(-1827, Date(-5, 12, 31)),
                           GregDay(-1826, Date(-4, 1, 1)),
                           GregDay(-1825, Date(-4, 1, 2)),
                           GregDay(-1462, Date(-4, 12, 30)),
                           GregDay(-1461, Date(-4, 12, 31)),
                           GregDay(-1460, Date(-3, 1, 1)),
                           GregDay(-1096, Date(-3, 12, 31)),
                           GregDay(-1095, Date(-2, 1, 1)),
                           GregDay(-731, Date(-2, 12, 31)),
                           GregDay(-730, Date(-1, 1, 1)),
                           GregDay(-367, Date(-1, 12, 30)),
                           GregDay(-366, Date(-1, 12, 31)),
                           GregDay(-365, Date(0, 1, 1)),
                           GregDay(-31, Date(0, 11, 30)),
                           GregDay(-30, Date(0, 12, 1)),
                           GregDay(-1, Date(0, 12, 30)),
                           GregDay(0, Date(0, 12, 31))];

    auto testGregDaysAD = [GregDay(1, Date(1, 1, 1)),
                           GregDay(2, Date(1, 1, 2)),
                           GregDay(32, Date(1, 2, 1)),
                           GregDay(365, Date(1, 12, 31)),
                           GregDay(366, Date(2, 1, 1)),
                           GregDay(731, Date(3, 1, 1)),
                           GregDay(1096, Date(4, 1, 1)),
                           GregDay(1097, Date(4, 1, 2)),
                           GregDay(1460, Date(4, 12, 30)),
                           GregDay(1461, Date(4, 12, 31)),
                           GregDay(1462, Date(5, 1, 1)),
                           GregDay(17_898, Date(50, 1, 1)),
                           GregDay(35_065, Date(97, 1, 1)),
                           GregDay(36_160, Date(100, 1, 1)),
                           GregDay(36_525, Date(101, 1, 1)),
                           GregDay(37_986, Date(105, 1, 1)),
                           GregDay(72_684, Date(200, 1, 1)),
                           GregDay(73_049, Date(201, 1, 1)),
                           GregDay(109_208, Date(300, 1, 1)),
                           GregDay(109_573, Date(301, 1, 1)),
                           GregDay(145_732, Date(400, 1, 1)),
                           GregDay(146_098, Date(401, 1, 1)),
                           GregDay(182_257, Date(500, 1, 1)),
                           GregDay(182_622, Date(501, 1, 1)),
                           GregDay(364_878, Date(1000, 1, 1)),
                           GregDay(365_243, Date(1001, 1, 1)),
                           GregDay(584_023, Date(1600, 1, 1)),
                           GregDay(584_389, Date(1601, 1, 1)),
                           GregDay(693_596, Date(1900, 1, 1)),
                           GregDay(693_961, Date(1901, 1, 1)),
                           GregDay(729_755, Date(1999, 1, 1)),
                           GregDay(730_120, Date(2000, 1, 1)),
                           GregDay(730_121, Date(2000, 1, 2)),
                           GregDay(730_484, Date(2000, 12, 30)),
                           GregDay(730_485, Date(2000, 12, 31)),
                           GregDay(730_486, Date(2001, 1, 1)),
                           GregDay(733_773, Date(2010, 1, 1)),
                           GregDay(733_774, Date(2010, 1, 2)),
                           GregDay(733_803, Date(2010, 1, 31)),
                           GregDay(733_804, Date(2010, 2, 1)),
                           GregDay(733_831, Date(2010, 2, 28)),
                           GregDay(733_832, Date(2010, 3, 1)),
                           GregDay(733_862, Date(2010, 3, 31)),
                           GregDay(733_863, Date(2010, 4, 1)),
                           GregDay(733_892, Date(2010, 4, 30)),
                           GregDay(733_893, Date(2010, 5, 1)),
                           GregDay(733_923, Date(2010, 5, 31)),
                           GregDay(733_924, Date(2010, 6, 1)),
                           GregDay(733_953, Date(2010, 6, 30)),
                           GregDay(733_954, Date(2010, 7, 1)),
                           GregDay(733_984, Date(2010, 7, 31)),
                           GregDay(733_985, Date(2010, 8, 1)),
                           GregDay(734_015, Date(2010, 8, 31)),
                           GregDay(734_016, Date(2010, 9, 1)),
                           GregDay(734_045, Date(2010, 9, 30)),
                           GregDay(734_046, Date(2010, 10, 1)),
                           GregDay(734_076, Date(2010, 10, 31)),
                           GregDay(734_077, Date(2010, 11, 1)),
                           GregDay(734_106, Date(2010, 11, 30)),
                           GregDay(734_107, Date(2010, 12, 1)),
                           GregDay(734_136, Date(2010, 12, 30)),
                           GregDay(734_137, Date(2010, 12, 31)),
                           GregDay(734_503, Date(2012, 1, 1)),
                           GregDay(734_534, Date(2012, 2, 1)),
                           GregDay(734_561, Date(2012, 2, 28)),
                           GregDay(734_562, Date(2012, 2, 29)),
                           GregDay(734_563, Date(2012, 3, 1)),
                           GregDay(734_858, Date(2012, 12, 21))];

    // I'd use a Tuple, but I get forward reference errors if I try.
    struct DayOfYear { int day; MonthDay md; }
    auto testDaysOfYear = [DayOfYear(1, MonthDay(1, 1)),
                           DayOfYear(2, MonthDay(1, 2)),
                           DayOfYear(3, MonthDay(1, 3)),
                           DayOfYear(31, MonthDay(1, 31)),
                           DayOfYear(32, MonthDay(2, 1)),
                           DayOfYear(59, MonthDay(2, 28)),
                           DayOfYear(60, MonthDay(3, 1)),
                           DayOfYear(90, MonthDay(3, 31)),
                           DayOfYear(91, MonthDay(4, 1)),
                           DayOfYear(120, MonthDay(4, 30)),
                           DayOfYear(121, MonthDay(5, 1)),
                           DayOfYear(151, MonthDay(5, 31)),
                           DayOfYear(152, MonthDay(6, 1)),
                           DayOfYear(181, MonthDay(6, 30)),
                           DayOfYear(182, MonthDay(7, 1)),
                           DayOfYear(212, MonthDay(7, 31)),
                           DayOfYear(213, MonthDay(8, 1)),
                           DayOfYear(243, MonthDay(8, 31)),
                           DayOfYear(244, MonthDay(9, 1)),
                           DayOfYear(273, MonthDay(9, 30)),
                           DayOfYear(274, MonthDay(10, 1)),
                           DayOfYear(304, MonthDay(10, 31)),
                           DayOfYear(305, MonthDay(11, 1)),
                           DayOfYear(334, MonthDay(11, 30)),
                           DayOfYear(335, MonthDay(12, 1)),
                           DayOfYear(363, MonthDay(12, 29)),
                           DayOfYear(364, MonthDay(12, 30)),
                           DayOfYear(365, MonthDay(12, 31))];

    auto testDaysOfLeapYear = [DayOfYear(1, MonthDay(1, 1)),
                               DayOfYear(2, MonthDay(1, 2)),
                               DayOfYear(3, MonthDay(1, 3)),
                               DayOfYear(31, MonthDay(1, 31)),
                               DayOfYear(32, MonthDay(2, 1)),
                               DayOfYear(59, MonthDay(2, 28)),
                               DayOfYear(60, MonthDay(2, 29)),
                               DayOfYear(61, MonthDay(3, 1)),
                               DayOfYear(91, MonthDay(3, 31)),
                               DayOfYear(92, MonthDay(4, 1)),
                               DayOfYear(121, MonthDay(4, 30)),
                               DayOfYear(122, MonthDay(5, 1)),
                               DayOfYear(152, MonthDay(5, 31)),
                               DayOfYear(153, MonthDay(6, 1)),
                               DayOfYear(182, MonthDay(6, 30)),
                               DayOfYear(183, MonthDay(7, 1)),
                               DayOfYear(213, MonthDay(7, 31)),
                               DayOfYear(214, MonthDay(8, 1)),
                               DayOfYear(244, MonthDay(8, 31)),
                               DayOfYear(245, MonthDay(9, 1)),
                               DayOfYear(274, MonthDay(9, 30)),
                               DayOfYear(275, MonthDay(10, 1)),
                               DayOfYear(305, MonthDay(10, 31)),
                               DayOfYear(306, MonthDay(11, 1)),
                               DayOfYear(335, MonthDay(11, 30)),
                               DayOfYear(336, MonthDay(12, 1)),
                               DayOfYear(364, MonthDay(12, 29)),
                               DayOfYear(365, MonthDay(12, 30)),
                               DayOfYear(366, MonthDay(12, 31))];

    void initializeTests() @safe
    {
        import std.algorithm.sorting : sort;
        import std.typecons : Rebindable;
        immutable lt = LocalTime().utcToTZ(0);
        currLocalDiffFromUTC = dur!"hnsecs"(lt);

        version(Posix)
        {
            immutable otherTZ = lt < 0 ? PosixTimeZone.getTimeZone("Australia/Sydney")
                                       : PosixTimeZone.getTimeZone("America/Denver");
        }
        else version(Windows)
        {
            immutable otherTZ = lt < 0 ? WindowsTimeZone.getTimeZone("AUS Eastern Standard Time")
                                       : WindowsTimeZone.getTimeZone("Mountain Standard Time");
        }

        immutable ot = otherTZ.utcToTZ(0);

        auto diffs = [0L, lt, ot];
        auto diffAA = [0L : Rebindable!(immutable TimeZone)(UTC())];
        diffAA[lt] = Rebindable!(immutable TimeZone)(LocalTime());
        diffAA[ot] = Rebindable!(immutable TimeZone)(otherTZ);

        sort(diffs);
        testTZs = [diffAA[diffs[0]], diffAA[diffs[1]], diffAA[diffs[2]]];

        testFracSecs = [Duration.zero, hnsecs(1), hnsecs(5007), hnsecs(9_999_999)];

        foreach (year; testYearsBC)
        {
            foreach (md; testMonthDays)
                testDatesBC ~= Date(year, md.month, md.day);
        }

        foreach (year; testYearsAD)
        {
            foreach (md; testMonthDays)
                testDatesAD ~= Date(year, md.month, md.day);
        }

        foreach (dt; testDatesBC)
        {
            foreach (tod; testTODs)
                testDateTimesBC ~= DateTime(dt, tod);
        }

        foreach (dt; testDatesAD)
        {
            foreach (tod; testTODs)
                testDateTimesAD ~= DateTime(dt, tod);
        }

        foreach (dt; testDateTimesBC)
        {
            foreach (tz; testTZs)
            {
                foreach (fs; testFracSecs)
                    testSysTimesBC ~= SysTime(dt, fs, tz);
            }
        }

        foreach (dt; testDateTimesAD)
        {
            foreach (tz; testTZs)
            {
                foreach (fs; testFracSecs)
                    testSysTimesAD ~= SysTime(dt, fs, tz);
            }
        }
    }
}
