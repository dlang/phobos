// Written in the D programming language

/++
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis
    Source:    $(PHOBOSSRC std/_datetime.d)
    Macros:
        LREF2=<a href="#$1">$(D $2)</a>
+/
module std.datetime.datetime;

import core.time;
import std.datetime.common;
import std.datetime.date;
import std.datetime.timeofday;
import std.traits : isSomeString, Unqual;

version(unittest) import std.exception : assertThrown;


@safe unittest
{
    initializeTests();
}


/++
   Combines the $(LREF Date) and $(LREF TimeOfDay) structs to give an object
   which holds both the date and the time. It is optimized for calendar-based
   operations and has no concept of time zone. For an object which is
   optimized for time operations based on the system time, use
   $(LREF SysTime). $(LREF SysTime) has a concept of time zone and has much higher
   precision (hnsecs). $(D DateTime) is intended primarily for calendar-based
   uses rather than precise time operations.
  +/
struct DateTime
{
public:

    /++
        Params:
            date = The date portion of $(LREF DateTime).
            tod  = The time portion of $(LREF DateTime).
      +/
    this(in Date date, in TimeOfDay tod = TimeOfDay.init) @safe pure nothrow
    {
        _date = date;
        _tod = tod;
    }

    @safe unittest
    {
        {
            auto dt = DateTime.init;
            assert(dt._date == Date.init);
            assert(dt._tod == TimeOfDay.init);
        }

        {
            auto dt = DateTime(Date(1999, 7 ,6));
            assert(dt._date == Date(1999, 7, 6));
            assert(dt._tod == TimeOfDay.init);
        }

        {
            auto dt = DateTime(Date(1999, 7 ,6), TimeOfDay(12, 30, 33));
            assert(dt._date == Date(1999, 7, 6));
            assert(dt._tod == TimeOfDay(12, 30, 33));
        }
    }


    /++
        Params:
            year   = The year portion of the date.
            month  = The month portion of the date.
            day    = The day portion of the date.
            hour   = The hour portion of the time;
            minute = The minute portion of the time;
            second = The second portion of the time;
      +/
    this(int year, int month, int day, int hour = 0, int minute = 0, int second = 0) @safe pure
    {
        _date = Date(year, month, day);
        _tod = TimeOfDay(hour, minute, second);
    }

    @safe unittest
    {
        {
            auto dt = DateTime(1999, 7 ,6);
            assert(dt._date == Date(1999, 7, 6));
            assert(dt._tod == TimeOfDay.init);
        }

        {
            auto dt = DateTime(1999, 7 ,6, 12, 30, 33);
            assert(dt._date == Date(1999, 7, 6));
            assert(dt._tod == TimeOfDay(12, 30, 33));
        }
    }


    /++
        Compares this $(LREF DateTime) with the given $(D DateTime.).

        Returns:
            $(BOOKTABLE,
            $(TR $(TD this &lt; rhs) $(TD &lt; 0))
            $(TR $(TD this == rhs) $(TD 0))
            $(TR $(TD this &gt; rhs) $(TD &gt; 0))
            )
     +/
    int opCmp(in DateTime rhs) @safe const pure nothrow
    {
        immutable dateResult = _date.opCmp(rhs._date);

        if (dateResult != 0)
            return dateResult;

        return _tod.opCmp(rhs._tod);
    }

    @safe unittest
    {
        // Test A.D.
        assert(DateTime(Date.init, TimeOfDay.init).opCmp(DateTime.init) == 0);

        assert(DateTime(Date(1999, 1, 1)).opCmp(DateTime(Date(1999, 1, 1))) == 0);
        assert(DateTime(Date(1, 7, 1)).opCmp(DateTime(Date(1, 7, 1))) == 0);
        assert(DateTime(Date(1, 1, 6)).opCmp(DateTime(Date(1, 1, 6))) == 0);

        assert(DateTime(Date(1999, 7, 1)).opCmp(DateTime(Date(1999, 7, 1))) == 0);
        assert(DateTime(Date(1999, 7, 6)).opCmp(DateTime(Date(1999, 7, 6))) == 0);

        assert(DateTime(Date(1, 7, 6)).opCmp(DateTime(Date(1, 7, 6))) == 0);

        assert(DateTime(Date(1999, 7, 6)).opCmp(DateTime(Date(2000, 7, 6))) < 0);
        assert(DateTime(Date(2000, 7, 6)).opCmp(DateTime(Date(1999, 7, 6))) > 0);
        assert(DateTime(Date(1999, 7, 6)).opCmp(DateTime(Date(1999, 8, 6))) < 0);
        assert(DateTime(Date(1999, 8, 6)).opCmp(DateTime(Date(1999, 7, 6))) > 0);
        assert(DateTime(Date(1999, 7, 6)).opCmp(DateTime(Date(1999, 7, 7))) < 0);
        assert(DateTime(Date(1999, 7, 7)).opCmp(DateTime(Date(1999, 7, 6))) > 0);

        assert(DateTime(Date(1999, 8, 7)).opCmp(DateTime(Date(2000, 7, 6))) < 0);
        assert(DateTime(Date(2000, 8, 6)).opCmp(DateTime(Date(1999, 7, 7))) > 0);
        assert(DateTime(Date(1999, 7, 7)).opCmp(DateTime(Date(2000, 7, 6))) < 0);
        assert(DateTime(Date(2000, 7, 6)).opCmp(DateTime(Date(1999, 7, 7))) > 0);
        assert(DateTime(Date(1999, 7, 7)).opCmp(DateTime(Date(1999, 8, 6))) < 0);
        assert(DateTime(Date(1999, 8, 6)).opCmp(DateTime(Date(1999, 7, 7))) > 0);


        assert(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 0)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 0))) == 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 0)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 0))) == 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 0)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 0))) == 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33))) == 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0))) == 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) == 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33))) == 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33))) == 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33))) < 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33))) < 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)).opCmp(
                   DateTime(Date(2000, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(2000, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)).opCmp(
                   DateTime(Date(2000, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(2000, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)).opCmp(
                   DateTime(Date(2000, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(2000, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34))) > 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)).opCmp(
                   DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)).opCmp(
                   DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)).opCmp(
                   DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34))) > 0);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 7), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)).opCmp(
                   DateTime(Date(1999, 7, 7), TimeOfDay(12, 31, 33))) < 0);
        assert(DateTime(Date(1999, 7, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)).opCmp(
                   DateTime(Date(1999, 7, 7), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34))) > 0);

        // Test B.C.
        assert(DateTime(Date(-1, 1, 1), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1, 1, 1), TimeOfDay(12, 30, 33))) == 0);
        assert(DateTime(Date(-1, 7, 1), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1, 7, 1), TimeOfDay(12, 30, 33))) == 0);
        assert(DateTime(Date(-1, 1, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1, 1, 6), TimeOfDay(12, 30, 33))) == 0);

        assert(DateTime(Date(-1999, 7, 1), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 1), TimeOfDay(12, 30, 33))) == 0);
        assert(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33))) == 0);

        assert(DateTime(Date(-1, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1, 7, 6), TimeOfDay(12, 30, 33))) == 0);

        assert(DateTime(Date(-2000, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-2000, 7, 6), TimeOfDay(12, 30, 33))) > 0);
        assert(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 8, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(-1999, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);
        assert(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);

        assert(DateTime(Date(-2000, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(-1999, 8, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-2000, 7, 6), TimeOfDay(12, 30, 33))) > 0);
        assert(DateTime(Date(-2000, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-2000, 7, 6), TimeOfDay(12, 30, 33))) > 0);
        assert(DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 8, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(-1999, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33))) > 0);

        // Test Both
        assert(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);

        assert(DateTime(Date(-1999, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 8, 6), TimeOfDay(12, 30, 33))) > 0);

        assert(DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 7), TimeOfDay(12, 30, 33))) > 0);

        assert(DateTime(Date(-1999, 8, 7), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 8, 7), TimeOfDay(12, 30, 33))) > 0);

        assert(DateTime(Date(-1999, 8, 6), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(1999, 6, 6), TimeOfDay(12, 30, 33))) < 0);
        assert(DateTime(Date(1999, 6, 8), TimeOfDay(12, 30, 33)).opCmp(
                   DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33))) > 0);

        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 33, 30));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 33, 30));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 33, 30));
        assert(dt.opCmp(dt) == 0);
        assert(dt.opCmp(cdt) == 0);
        assert(dt.opCmp(idt) == 0);
        assert(cdt.opCmp(dt) == 0);
        assert(cdt.opCmp(cdt) == 0);
        assert(cdt.opCmp(idt) == 0);
        assert(idt.opCmp(dt) == 0);
        assert(idt.opCmp(cdt) == 0);
        assert(idt.opCmp(idt) == 0);
    }


    /++
        The date portion of $(LREF DateTime).
      +/
    @property Date date() @safe const pure nothrow
    {
        return _date;
    }

    @safe unittest
    {
        {
            auto dt = DateTime.init;
            assert(dt.date == Date.init);
        }

        {
            auto dt = DateTime(Date(1999, 7, 6));
            assert(dt.date == Date(1999, 7, 6));
        }

        const cdt = DateTime(1999, 7, 6);
        immutable idt = DateTime(1999, 7, 6);
        assert(cdt.date == Date(1999, 7, 6));
        assert(idt.date == Date(1999, 7, 6));
    }


    /++
        The date portion of $(LREF DateTime).

        Params:
            date = The Date to set this $(LREF DateTime)'s date portion to.
      +/
    @property void date(in Date date) @safe pure nothrow
    {
        _date = date;
    }

    @safe unittest
    {
        auto dt = DateTime.init;
        dt.date = Date(1999, 7, 6);
        assert(dt._date == Date(1999, 7, 6));
        assert(dt._tod == TimeOfDay.init);

        const cdt = DateTime(1999, 7, 6);
        immutable idt = DateTime(1999, 7, 6);
        static assert(!__traits(compiles, cdt.date = Date(2010, 1, 1)));
        static assert(!__traits(compiles, idt.date = Date(2010, 1, 1)));
    }


    /++
        The time portion of $(LREF DateTime).
      +/
    @property TimeOfDay timeOfDay() @safe const pure nothrow
    {
        return _tod;
    }

    @safe unittest
    {
        {
            auto dt = DateTime.init;
            assert(dt.timeOfDay == TimeOfDay.init);
        }

        {
            auto dt = DateTime(Date.init, TimeOfDay(12, 30, 33));
            assert(dt.timeOfDay == TimeOfDay(12, 30, 33));
        }

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.timeOfDay == TimeOfDay(12, 30, 33));
        assert(idt.timeOfDay == TimeOfDay(12, 30, 33));
    }


    /++
        The time portion of $(LREF DateTime).

        Params:
            tod = The $(LREF TimeOfDay) to set this $(LREF DateTime)'s time portion
                  to.
      +/
    @property void timeOfDay(in TimeOfDay tod) @safe pure nothrow
    {
        _tod = tod;
    }

    @safe unittest
    {
        auto dt = DateTime.init;
        dt.timeOfDay = TimeOfDay(12, 30, 33);
        assert(dt._date == Date.init);
        assert(dt._tod == TimeOfDay(12, 30, 33));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.timeOfDay = TimeOfDay(12, 30, 33)));
        static assert(!__traits(compiles, idt.timeOfDay = TimeOfDay(12, 30, 33)));
    }


    /++
        Year of the Gregorian Calendar. Positive numbers are A.D. Non-positive
        are B.C.
     +/
    @property short year() @safe const pure nothrow
    {
        return _date.year;
    }

    @safe unittest
    {
        assert(Date.init.year == 1);
        assert(Date(1999, 7, 6).year == 1999);
        assert(Date(-1999, 7, 6).year == -1999);

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(idt.year == 1999);
        assert(idt.year == 1999);
    }


    /++
        Year of the Gregorian Calendar. Positive numbers are A.D. Non-positive
        are B.C.

        Params:
            year = The year to set this $(LREF DateTime)'s year to.

        Throws:
            $(LREF DateTimeException) if the new year is not a leap year and if the
            resulting date would be on February 29th.
     +/
    @property void year(int year) @safe pure
    {
        _date.year = year;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(9, 7, 5)).year == 1999);
        assert(DateTime(Date(2010, 10, 4), TimeOfDay(0, 0, 30)).year == 2010);
        assert(DateTime(Date(-7, 4, 5), TimeOfDay(7, 45, 2)).year == -7);
    }

    @safe unittest
    {
        static void testDT(DateTime dt, int year, in DateTime expected, size_t line = __LINE__)
        {
            dt.year = year;
            assert(dt == expected);
        }

        testDT(DateTime(Date(1, 1, 1), TimeOfDay(12, 30, 33)),
               1999,
               DateTime(Date(1999, 1, 1), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(12, 30, 33)),
               0,
               DateTime(Date(0, 1, 1), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(12, 30, 33)),
               -1999,
               DateTime(Date(-1999, 1, 1), TimeOfDay(12, 30, 33)));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.year = 7));
        static assert(!__traits(compiles, idt.year = 7));
    }


    /++
        Year B.C. of the Gregorian Calendar counting year 0 as 1 B.C.

        Throws:
            $(LREF DateTimeException) if $(D isAD) is true.
     +/
    @property short yearBC() @safe const pure
    {
        return _date.yearBC;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(0, 1, 1), TimeOfDay(12, 30, 33)).yearBC == 1);
        assert(DateTime(Date(-1, 1, 1), TimeOfDay(10, 7, 2)).yearBC == 2);
        assert(DateTime(Date(-100, 1, 1), TimeOfDay(4, 59, 0)).yearBC == 101);
    }

    @safe unittest
    {
        assertThrown!DateTimeException((in DateTime dt){dt.yearBC;}(DateTime(Date(1, 1, 1))));

        auto dt = DateTime(1999, 7, 6, 12, 30, 33);
        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        dt.yearBC = 12;
        assert(dt.yearBC == 12);
        static assert(!__traits(compiles, cdt.yearBC = 12));
        static assert(!__traits(compiles, idt.yearBC = 12));
    }


    /++
        Year B.C. of the Gregorian Calendar counting year 0 as 1 B.C.

        Params:
            year = The year B.C. to set this $(LREF DateTime)'s year to.

        Throws:
            $(LREF DateTimeException) if a non-positive value is given.
     +/
    @property void yearBC(int year) @safe pure
    {
        _date.yearBC = year;
    }

    ///
    @safe unittest
    {
        auto dt = DateTime(Date(2010, 1, 1), TimeOfDay(7, 30, 0));
        dt.yearBC = 1;
        assert(dt == DateTime(Date(0, 1, 1), TimeOfDay(7, 30, 0)));

        dt.yearBC = 10;
        assert(dt == DateTime(Date(-9, 1, 1), TimeOfDay(7, 30, 0)));
    }

    @safe unittest
    {
        assertThrown!DateTimeException((DateTime dt){dt.yearBC = -1;}(DateTime(Date(1, 1, 1))));

        auto dt = DateTime(1999, 7, 6, 12, 30, 33);
        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        dt.yearBC = 12;
        assert(dt.yearBC == 12);
        static assert(!__traits(compiles, cdt.yearBC = 12));
        static assert(!__traits(compiles, idt.yearBC = 12));
    }


    /++
        Month of a Gregorian Year.
     +/
    @property Month month() @safe const pure nothrow
    {
        return _date.month;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(9, 7, 5)).month == 7);
        assert(DateTime(Date(2010, 10, 4), TimeOfDay(0, 0, 30)).month == 10);
        assert(DateTime(Date(-7, 4, 5), TimeOfDay(7, 45, 2)).month == 4);
    }

    @safe unittest
    {
        assert(DateTime.init.month == 1);
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)).month == 7);
        assert(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)).month == 7);

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.month == 7);
        assert(idt.month == 7);
    }


    /++
        Month of a Gregorian Year.

        Params:
            month = The month to set this $(LREF DateTime)'s month to.

        Throws:
            $(LREF DateTimeException) if the given month is not a valid month.
     +/
    @property void month(Month month) @safe pure
    {
        _date.month = month;
    }

    @safe unittest
    {
        static void testDT(DateTime dt, Month month, in DateTime expected = DateTime.init, size_t line = __LINE__)
        {
            dt.month = month;
            assert(expected != DateTime.init);
            assert(dt == expected);
        }

        assertThrown!DateTimeException(testDT(DateTime(Date(1, 1, 1), TimeOfDay(12, 30, 33)), cast(Month) 0));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 1, 1), TimeOfDay(12, 30, 33)), cast(Month) 13));

        testDT(DateTime(Date(1, 1, 1), TimeOfDay(12, 30, 33)),
               cast(Month) 7,
               DateTime(Date(1, 7, 1), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1, 1, 1), TimeOfDay(12, 30, 33)),
               cast(Month) 7,
               DateTime(Date(-1, 7, 1), TimeOfDay(12, 30, 33)));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.month = 12));
        static assert(!__traits(compiles, idt.month = 12));
    }


    /++
        Day of a Gregorian Month.
     +/
    @property ubyte day() @safe const pure nothrow
    {
        return _date.day;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(9, 7, 5)).day == 6);
        assert(DateTime(Date(2010, 10, 4), TimeOfDay(0, 0, 30)).day == 4);
        assert(DateTime(Date(-7, 4, 5), TimeOfDay(7, 45, 2)).day == 5);
    }

    @safe unittest
    {
        import std.format : format;
        import std.range : chain;

        static void test(DateTime dateTime, int expected)
        {
            assert(dateTime.day == expected, format("Value given: %s", dateTime));
        }

        foreach (year; chain(testYearsBC, testYearsAD))
        {
            foreach (md; testMonthDays)
            {
                foreach (tod; testTODs)
                    test(DateTime(Date(year, md.month, md.day), tod), md.day);
            }
        }

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.day == 6);
        assert(idt.day == 6);
    }


    /++
        Day of a Gregorian Month.

        Params:
            day = The day of the month to set this $(LREF DateTime)'s day to.

        Throws:
            $(LREF DateTimeException) if the given day is not a valid day of the
            current month.
     +/
    @property void day(int day) @safe pure
    {
        _date.day = day;
    }

    @safe unittest
    {
        import std.exception : assertNotThrown;

        static void testDT(DateTime dt, int day)
        {
            dt.day = day;
        }

        // Test A.D.
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 1, 1)), 0));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 1, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 2, 1)), 29));
        assertThrown!DateTimeException(testDT(DateTime(Date(4, 2, 1)), 30));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 3, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 4, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 5, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 6, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 7, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 8, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 9, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 10, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 11, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(1, 12, 1)), 32));

        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 1, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 2, 1)), 28));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(4, 2, 1)), 29));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 3, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 4, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 5, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 6, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 7, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 8, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 9, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 10, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 11, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(1, 12, 1)), 31));

        {
            auto dt = DateTime(Date(1, 1, 1), TimeOfDay(7, 12, 22));
            dt.day = 6;
            assert(dt == DateTime(Date(1, 1, 6), TimeOfDay(7, 12, 22)));
        }

        // Test B.C.
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 1, 1)), 0));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 1, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 2, 1)), 29));
        assertThrown!DateTimeException(testDT(DateTime(Date(0, 2, 1)), 30));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 3, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 4, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 5, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 6, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 7, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 8, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 9, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 10, 1)), 32));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 11, 1)), 31));
        assertThrown!DateTimeException(testDT(DateTime(Date(-1, 12, 1)), 32));

        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 1, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 2, 1)), 28));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(0, 2, 1)), 29));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 3, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 4, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 5, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 6, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 7, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 8, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 9, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 10, 1)), 31));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 11, 1)), 30));
        assertNotThrown!DateTimeException(testDT(DateTime(Date(-1, 12, 1)), 31));

        auto dt = DateTime(Date(-1, 1, 1), TimeOfDay(7, 12, 22));
        dt.day = 6;
        assert(dt == DateTime(Date(-1, 1, 6), TimeOfDay(7, 12, 22)));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.day = 27));
        static assert(!__traits(compiles, idt.day = 27));
    }


    /++
        Hours past midnight.
     +/
    @property ubyte hour() @safe const pure nothrow
    {
        return _tod.hour;
    }

    @safe unittest
    {
        assert(DateTime.init.hour == 0);
        assert(DateTime(Date.init, TimeOfDay(12, 0, 0)).hour == 12);

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.hour == 12);
        assert(idt.hour == 12);
    }


    /++
        Hours past midnight.

        Params:
            hour = The hour of the day to set this $(LREF DateTime)'s hour to.

        Throws:
            $(LREF DateTimeException) if the given hour would result in an invalid
            $(LREF DateTime).
     +/
    @property void hour(int hour) @safe pure
    {
        _tod.hour = hour;
    }

    @safe unittest
    {
        assertThrown!DateTimeException((){DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 0)).hour = 24;}());

        auto dt = DateTime.init;
        dt.hour = 12;
        assert(dt == DateTime(1, 1, 1, 12, 0, 0));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.hour = 27));
        static assert(!__traits(compiles, idt.hour = 27));
    }


    /++
        Minutes past the hour.
     +/
    @property ubyte minute() @safe const pure nothrow
    {
        return _tod.minute;
    }

    @safe unittest
    {
        assert(DateTime.init.minute == 0);
        assert(DateTime(1, 1, 1, 0, 30, 0).minute == 30);

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.minute == 30);
        assert(idt.minute == 30);
    }


    /++
        Minutes past the hour.

        Params:
            minute = The minute to set this $(LREF DateTime)'s minute to.

        Throws:
            $(LREF DateTimeException) if the given minute would result in an
            invalid $(LREF DateTime).
     +/
    @property void minute(int minute) @safe pure
    {
        _tod.minute = minute;
    }

    @safe unittest
    {
        assertThrown!DateTimeException((){DateTime.init.minute = 60;}());

        auto dt = DateTime.init;
        dt.minute = 30;
        assert(dt == DateTime(1, 1, 1, 0, 30, 0));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.minute = 27));
        static assert(!__traits(compiles, idt.minute = 27));
    }


    /++
        Seconds past the minute.
     +/
    @property ubyte second() @safe const pure nothrow
    {
        return _tod.second;
    }

    @safe unittest
    {
        assert(DateTime.init.second == 0);
        assert(DateTime(1, 1, 1, 0, 0, 33).second == 33);

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.second == 33);
        assert(idt.second == 33);
    }


    /++
        Seconds past the minute.

        Params:
            second = The second to set this $(LREF DateTime)'s second to.

        Throws:
            $(LREF DateTimeException) if the given seconds would result in an
            invalid $(LREF DateTime).
     +/
    @property void second(int second) @safe pure
    {
        _tod.second = second;
    }

    @safe unittest
    {
        assertThrown!DateTimeException((){DateTime.init.second = 60;}());

        auto dt = DateTime.init;
        dt.second = 33;
        assert(dt == DateTime(1, 1, 1, 0, 0, 33));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.second = 27));
        static assert(!__traits(compiles, idt.second = 27));
    }


    /++
        Adds the given number of years or months to this $(LREF DateTime). A
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
                            $(LREF DateTime).
            allowOverflow = Whether the days should be allowed to overflow,
                            causing the month to increment.
      +/
    ref DateTime add(string units)
                    (long value, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe pure nothrow
        if (units == "years" || units == "months")
    {
        _date.add!units(value, allowOverflow);
        return this;
    }

    ///
    @safe unittest
    {
        auto dt1 = DateTime(2010, 1, 1, 12, 30, 33);
        dt1.add!"months"(11);
        assert(dt1 == DateTime(2010, 12, 1, 12, 30, 33));

        auto dt2 = DateTime(2010, 1, 1, 12, 30, 33);
        dt2.add!"months"(-11);
        assert(dt2 == DateTime(2009, 2, 1, 12, 30, 33));

        auto dt3 = DateTime(2000, 2, 29, 12, 30, 33);
        dt3.add!"years"(1);
        assert(dt3 == DateTime(2001, 3, 1, 12, 30, 33));

        auto dt4 = DateTime(2000, 2, 29, 12, 30, 33);
        dt4.add!"years"(1, AllowDayOverflow.no);
        assert(dt4 == DateTime(2001, 2, 28, 12, 30, 33));
    }

    @safe unittest
    {
        auto dt = DateTime(2000, 1, 31);
        dt.add!"years"(7).add!"months"(-4);
        assert(dt == DateTime(2006, 10, 1));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.add!"years"(4)));
        static assert(!__traits(compiles, idt.add!"years"(4)));
        static assert(!__traits(compiles, cdt.add!"months"(4)));
        static assert(!__traits(compiles, idt.add!"months"(4)));
    }


    /++
        Adds the given number of years or months to this $(LREF DateTime). A
        negative number will subtract.

        The difference between rolling and adding is that rolling does not
        affect larger units. Rolling a $(LREF DateTime) 12 months
        gets the exact same $(LREF DateTime). However, the days can still be
        affected due to the differing number of days in each month.

        Because there are no units larger than years, there is no difference
        between adding and rolling years.

        Params:
            units         = The type of units to add ("years" or "months").
            value         = The number of months or years to add to this
                            $(LREF DateTime).
            allowOverflow = Whether the days should be allowed to overflow,
                            causing the month to increment.
      +/
    ref DateTime roll(string units)
                     (long value, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe pure nothrow
        if (units == "years" || units == "months")
    {
        _date.roll!units(value, allowOverflow);
        return this;
    }

    ///
    @safe unittest
    {
        auto dt1 = DateTime(2010, 1, 1, 12, 33, 33);
        dt1.roll!"months"(1);
        assert(dt1 == DateTime(2010, 2, 1, 12, 33, 33));

        auto dt2 = DateTime(2010, 1, 1, 12, 33, 33);
        dt2.roll!"months"(-1);
        assert(dt2 == DateTime(2010, 12, 1, 12, 33, 33));

        auto dt3 = DateTime(1999, 1, 29, 12, 33, 33);
        dt3.roll!"months"(1);
        assert(dt3 == DateTime(1999, 3, 1, 12, 33, 33));

        auto dt4 = DateTime(1999, 1, 29, 12, 33, 33);
        dt4.roll!"months"(1, AllowDayOverflow.no);
        assert(dt4 == DateTime(1999, 2, 28, 12, 33, 33));

        auto dt5 = DateTime(2000, 2, 29, 12, 30, 33);
        dt5.roll!"years"(1);
        assert(dt5 == DateTime(2001, 3, 1, 12, 30, 33));

        auto dt6 = DateTime(2000, 2, 29, 12, 30, 33);
        dt6.roll!"years"(1, AllowDayOverflow.no);
        assert(dt6 == DateTime(2001, 2, 28, 12, 30, 33));
    }

    @safe unittest
    {
        auto dt = DateTime(2000, 1, 31);
        dt.roll!"years"(7).roll!"months"(-4);
        assert(dt == DateTime(2007, 10, 1));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.roll!"years"(4)));
        static assert(!__traits(compiles, idt.roll!"years"(4)));
        static assert(!__traits(compiles, cdt.roll!"months"(4)));
        static assert(!__traits(compiles, idt.roll!"months"(4)));
    }


    /++
        Adds the given number of units to this $(LREF DateTime). A negative number
        will subtract.

        The difference between rolling and adding is that rolling does not
        affect larger units. For instance, rolling a $(LREF DateTime) one
        year's worth of days gets the exact same $(LREF DateTime).

        Accepted units are $(D "days"), $(D "minutes"), $(D "hours"),
        $(D "minutes"), and $(D "seconds").

        Params:
            units = The units to add.
            value = The number of $(D_PARAM units) to add to this $(LREF DateTime).
      +/
    ref DateTime roll(string units)(long value) @safe pure nothrow
        if (units == "days")
    {
        _date.roll!"days"(value);
        return this;
    }

    ///
    @safe unittest
    {
        auto dt1 = DateTime(2010, 1, 1, 11, 23, 12);
        dt1.roll!"days"(1);
        assert(dt1 == DateTime(2010, 1, 2, 11, 23, 12));
        dt1.roll!"days"(365);
        assert(dt1 == DateTime(2010, 1, 26, 11, 23, 12));
        dt1.roll!"days"(-32);
        assert(dt1 == DateTime(2010, 1, 25, 11, 23, 12));

        auto dt2 = DateTime(2010, 7, 4, 12, 0, 0);
        dt2.roll!"hours"(1);
        assert(dt2 == DateTime(2010, 7, 4, 13, 0, 0));

        auto dt3 = DateTime(2010, 1, 1, 0, 0, 0);
        dt3.roll!"seconds"(-1);
        assert(dt3 == DateTime(2010, 1, 1, 0, 0, 59));
    }

    @safe unittest
    {
        auto dt = DateTime(2000, 1, 31);
        dt.roll!"days"(7).roll!"days"(-4);
        assert(dt == DateTime(2000, 1, 3));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.roll!"days"(4)));
        static assert(!__traits(compiles, idt.roll!"days"(4)));
    }


    // Shares documentation with "days" version.
    ref DateTime roll(string units)(long value) @safe pure nothrow
        if (units == "hours" ||
            units == "minutes" ||
            units == "seconds")
    {
        _tod.roll!units(value);
        return this;
    }

    // Test roll!"hours"().
    @safe unittest
    {
        static void testDT(DateTime orig, int hours, in DateTime expected, size_t line = __LINE__)
        {
            orig.roll!"hours"(hours);
            assert(orig == expected);
        }

        // Test A.D.
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 2,
               DateTime(Date(1999, 7, 6), TimeOfDay(14, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 3,
               DateTime(Date(1999, 7, 6), TimeOfDay(15, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 4,
               DateTime(Date(1999, 7, 6), TimeOfDay(16, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 5,
               DateTime(Date(1999, 7, 6), TimeOfDay(17, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 6,
               DateTime(Date(1999, 7, 6), TimeOfDay(18, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 7,
               DateTime(Date(1999, 7, 6), TimeOfDay(19, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 8,
               DateTime(Date(1999, 7, 6), TimeOfDay(20, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 9,
               DateTime(Date(1999, 7, 6), TimeOfDay(21, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 10,
               DateTime(Date(1999, 7, 6), TimeOfDay(22, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 11,
               DateTime(Date(1999, 7, 6), TimeOfDay(23, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 12,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 13,
               DateTime(Date(1999, 7, 6), TimeOfDay(1, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 14,
               DateTime(Date(1999, 7, 6), TimeOfDay(2, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 15,
               DateTime(Date(1999, 7, 6), TimeOfDay(3, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 16,
               DateTime(Date(1999, 7, 6), TimeOfDay(4, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 17,
               DateTime(Date(1999, 7, 6), TimeOfDay(5, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 18,
               DateTime(Date(1999, 7, 6), TimeOfDay(6, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 19,
               DateTime(Date(1999, 7, 6), TimeOfDay(7, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 20,
               DateTime(Date(1999, 7, 6), TimeOfDay(8, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 21,
               DateTime(Date(1999, 7, 6), TimeOfDay(9, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 22,
               DateTime(Date(1999, 7, 6), TimeOfDay(10, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 23,
               DateTime(Date(1999, 7, 6), TimeOfDay(11, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 24,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 25,
               DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(11, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -2,
               DateTime(Date(1999, 7, 6), TimeOfDay(10, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -3,
               DateTime(Date(1999, 7, 6), TimeOfDay(9, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -4,
               DateTime(Date(1999, 7, 6), TimeOfDay(8, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -5,
               DateTime(Date(1999, 7, 6), TimeOfDay(7, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -6,
               DateTime(Date(1999, 7, 6), TimeOfDay(6, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -7,
               DateTime(Date(1999, 7, 6), TimeOfDay(5, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -8,
               DateTime(Date(1999, 7, 6), TimeOfDay(4, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -9,
               DateTime(Date(1999, 7, 6), TimeOfDay(3, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -10,
               DateTime(Date(1999, 7, 6), TimeOfDay(2, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -11,
               DateTime(Date(1999, 7, 6), TimeOfDay(1, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -12,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -13,
               DateTime(Date(1999, 7, 6), TimeOfDay(23, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -14,
               DateTime(Date(1999, 7, 6), TimeOfDay(22, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -15,
               DateTime(Date(1999, 7, 6), TimeOfDay(21, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -16,
               DateTime(Date(1999, 7, 6), TimeOfDay(20, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -17,
               DateTime(Date(1999, 7, 6), TimeOfDay(19, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -18,
               DateTime(Date(1999, 7, 6), TimeOfDay(18, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -19,
               DateTime(Date(1999, 7, 6), TimeOfDay(17, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -20,
               DateTime(Date(1999, 7, 6), TimeOfDay(16, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -21,
               DateTime(Date(1999, 7, 6), TimeOfDay(15, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -22,
               DateTime(Date(1999, 7, 6), TimeOfDay(14, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -23,
               DateTime(Date(1999, 7, 6), TimeOfDay(13, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -24,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -25,
               DateTime(Date(1999, 7, 6), TimeOfDay(11, 30, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(1, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(23, 30, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(23, 30, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(23, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(23, 30, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(22, 30, 33)));

        testDT(DateTime(Date(1999, 7, 31), TimeOfDay(23, 30, 33)), 1,
               DateTime(Date(1999, 7, 31), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(1999, 8, 1), TimeOfDay(0, 30, 33)), -1,
               DateTime(Date(1999, 8, 1), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(1999, 12, 31), TimeOfDay(23, 30, 33)), 1,
               DateTime(Date(1999, 12, 31), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(2000, 1, 1), TimeOfDay(0, 30, 33)), -1,
               DateTime(Date(2000, 1, 1), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(1999, 2, 28), TimeOfDay(23, 30, 33)), 25,
               DateTime(Date(1999, 2, 28), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(1999, 3, 2), TimeOfDay(0, 30, 33)), -25,
               DateTime(Date(1999, 3, 2), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(2000, 2, 28), TimeOfDay(23, 30, 33)), 25,
               DateTime(Date(2000, 2, 28), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(2000, 3, 1), TimeOfDay(0, 30, 33)), -25,
               DateTime(Date(2000, 3, 1), TimeOfDay(23, 30, 33)));

        // Test B.C.
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(13, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 2,
               DateTime(Date(-1999, 7, 6), TimeOfDay(14, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 3,
               DateTime(Date(-1999, 7, 6), TimeOfDay(15, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 4,
               DateTime(Date(-1999, 7, 6), TimeOfDay(16, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 5,
               DateTime(Date(-1999, 7, 6), TimeOfDay(17, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 6,
               DateTime(Date(-1999, 7, 6), TimeOfDay(18, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 7,
               DateTime(Date(-1999, 7, 6), TimeOfDay(19, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 8,
               DateTime(Date(-1999, 7, 6), TimeOfDay(20, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 9,
               DateTime(Date(-1999, 7, 6), TimeOfDay(21, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 10,
               DateTime(Date(-1999, 7, 6), TimeOfDay(22, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 11,
               DateTime(Date(-1999, 7, 6), TimeOfDay(23, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 12,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 13,
               DateTime(Date(-1999, 7, 6), TimeOfDay(1, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 14,
               DateTime(Date(-1999, 7, 6), TimeOfDay(2, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 15,
               DateTime(Date(-1999, 7, 6), TimeOfDay(3, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 16,
               DateTime(Date(-1999, 7, 6), TimeOfDay(4, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 17,
               DateTime(Date(-1999, 7, 6), TimeOfDay(5, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 18,
               DateTime(Date(-1999, 7, 6), TimeOfDay(6, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 19,
               DateTime(Date(-1999, 7, 6), TimeOfDay(7, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 20,
               DateTime(Date(-1999, 7, 6), TimeOfDay(8, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 21,
               DateTime(Date(-1999, 7, 6), TimeOfDay(9, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 22,
               DateTime(Date(-1999, 7, 6), TimeOfDay(10, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 23,
               DateTime(Date(-1999, 7, 6), TimeOfDay(11, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 24,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 25,
               DateTime(Date(-1999, 7, 6), TimeOfDay(13, 30, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(11, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -2,
               DateTime(Date(-1999, 7, 6), TimeOfDay(10, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -3,
               DateTime(Date(-1999, 7, 6), TimeOfDay(9, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -4,
               DateTime(Date(-1999, 7, 6), TimeOfDay(8, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -5,
               DateTime(Date(-1999, 7, 6), TimeOfDay(7, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -6,
               DateTime(Date(-1999, 7, 6), TimeOfDay(6, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -7,
               DateTime(Date(-1999, 7, 6), TimeOfDay(5, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -8,
               DateTime(Date(-1999, 7, 6), TimeOfDay(4, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -9,
               DateTime(Date(-1999, 7, 6), TimeOfDay(3, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -10,
               DateTime(Date(-1999, 7, 6), TimeOfDay(2, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -11,
               DateTime(Date(-1999, 7, 6), TimeOfDay(1, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -12,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -13,
               DateTime(Date(-1999, 7, 6), TimeOfDay(23, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -14,
               DateTime(Date(-1999, 7, 6), TimeOfDay(22, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -15,
               DateTime(Date(-1999, 7, 6), TimeOfDay(21, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -16,
               DateTime(Date(-1999, 7, 6), TimeOfDay(20, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -17,
               DateTime(Date(-1999, 7, 6), TimeOfDay(19, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -18,
               DateTime(Date(-1999, 7, 6), TimeOfDay(18, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -19,
               DateTime(Date(-1999, 7, 6), TimeOfDay(17, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -20,
               DateTime(Date(-1999, 7, 6), TimeOfDay(16, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -21,
               DateTime(Date(-1999, 7, 6), TimeOfDay(15, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -22,
               DateTime(Date(-1999, 7, 6), TimeOfDay(14, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -23,
               DateTime(Date(-1999, 7, 6), TimeOfDay(13, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -24,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -25,
               DateTime(Date(-1999, 7, 6), TimeOfDay(11, 30, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 30, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(1, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 30, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 30, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(23, 30, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(23, 30, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(23, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(23, 30, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(22, 30, 33)));

        testDT(DateTime(Date(-1999, 7, 31), TimeOfDay(23, 30, 33)), 1,
               DateTime(Date(-1999, 7, 31), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-1999, 8, 1), TimeOfDay(0, 30, 33)), -1,
               DateTime(Date(-1999, 8, 1), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(-2001, 12, 31), TimeOfDay(23, 30, 33)), 1,
               DateTime(Date(-2001, 12, 31), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-2000, 1, 1), TimeOfDay(0, 30, 33)), -1,
               DateTime(Date(-2000, 1, 1), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(-2001, 2, 28), TimeOfDay(23, 30, 33)), 25,
               DateTime(Date(-2001, 2, 28), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-2001, 3, 2), TimeOfDay(0, 30, 33)), -25,
               DateTime(Date(-2001, 3, 2), TimeOfDay(23, 30, 33)));

        testDT(DateTime(Date(-2000, 2, 28), TimeOfDay(23, 30, 33)), 25,
               DateTime(Date(-2000, 2, 28), TimeOfDay(0, 30, 33)));
        testDT(DateTime(Date(-2000, 3, 1), TimeOfDay(0, 30, 33)), -25,
               DateTime(Date(-2000, 3, 1), TimeOfDay(23, 30, 33)));

        // Test Both
        testDT(DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 33)), 17_546,
               DateTime(Date(-1, 1, 1), TimeOfDay(13, 30, 33)));
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 33)), -17_546,
               DateTime(Date(1, 1, 1), TimeOfDay(11, 30, 33)));

        auto dt = DateTime(2000, 1, 31, 9, 7, 6);
        dt.roll!"hours"(27).roll!"hours"(-9);
        assert(dt == DateTime(2000, 1, 31, 3, 7, 6));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.roll!"hours"(4)));
        static assert(!__traits(compiles, idt.roll!"hours"(4)));
    }

    // Test roll!"minutes"().
    @safe unittest
    {
        static void testDT(DateTime orig, int minutes, in DateTime expected, size_t line = __LINE__)
        {
            orig.roll!"minutes"(minutes);
            assert(orig == expected);
        }

        // Test A.D.
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 2,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 32, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 3,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 33, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 4,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 34, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 5,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 35, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 10,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 40, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 15,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 45, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 29,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 59, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 30,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 45,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 15, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 60,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 75,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 45, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 90,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 100,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 10, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 689,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 59, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 690,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 691,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 960,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1439,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 29, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1440,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1441,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 2880,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 29, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -2,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 28, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -3,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 27, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -4,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 26, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -5,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 25, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -10,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 20, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -15,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 15, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -29,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -30,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -45,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 45, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -60,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -75,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 15, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -90,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -100,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 50, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -749,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -750,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -751,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 59, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -960,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -1439,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -1440,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -1441,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 29, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -2880,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 59, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(11, 59, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(11, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(11, 59, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(11, 59, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(11, 59, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(11, 58, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 1, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 59, 33)));

        testDT(DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 33)), 1,
               DateTime(Date(1999, 7, 5), TimeOfDay(23, 0, 33)));
        testDT(DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 33)), 0,
               DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 33)));
        testDT(DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 33)), -1,
               DateTime(Date(1999, 7, 5), TimeOfDay(23, 58, 33)));

        testDT(DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 33)), 1,
               DateTime(Date(1998, 12, 31), TimeOfDay(23, 0, 33)));
        testDT(DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 33)), 0,
               DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 33)));
        testDT(DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 33)), -1,
               DateTime(Date(1998, 12, 31), TimeOfDay(23, 58, 33)));

        // Test B.C.
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 31, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 2,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 32, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 3,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 33, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 4,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 34, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 5,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 35, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 10,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 40, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 15,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 45, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 29,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 59, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 30,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 45,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 15, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 60,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 75,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 45, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 90,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 100,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 10, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 689,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 59, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 690,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 691,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 960,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1439,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 29, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1440,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1441,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 31, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 2880,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 29, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -2,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 28, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -3,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 27, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -4,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 26, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -5,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 25, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -10,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 20, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -15,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 15, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -29,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -30,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -45,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 45, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -60,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -75,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 15, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -90,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -100,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 50, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -749,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -750,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -751,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 59, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -960,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -1439,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 31, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -1440,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -1441,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 29, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -2880,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 1, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 59, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(11, 59, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(11, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(11, 59, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(11, 59, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(11, 59, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(11, 58, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 1, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 59, 33)));

        testDT(DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 33)), 1,
               DateTime(Date(-1999, 7, 5), TimeOfDay(23, 0, 33)));
        testDT(DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 33)), 0,
               DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 33)));
        testDT(DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 33)), -1,
               DateTime(Date(-1999, 7, 5), TimeOfDay(23, 58, 33)));

        testDT(DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 33)), 1,
               DateTime(Date(-2000, 12, 31), TimeOfDay(23, 0, 33)));
        testDT(DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 33)), 0,
               DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 33)));
        testDT(DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 33)), -1,
               DateTime(Date(-2000, 12, 31), TimeOfDay(23, 58, 33)));

        // Test Both
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(0, 0, 0)), -1,
               DateTime(Date(1, 1, 1), TimeOfDay(0, 59, 0)));
        testDT(DateTime(Date(0, 12, 31), TimeOfDay(23, 59, 0)), 1,
               DateTime(Date(0, 12, 31), TimeOfDay(23, 0, 0)));

        testDT(DateTime(Date(0, 1, 1), TimeOfDay(0, 0, 0)), -1,
               DateTime(Date(0, 1, 1), TimeOfDay(0, 59, 0)));
        testDT(DateTime(Date(-1, 12, 31), TimeOfDay(23, 59, 0)), 1,
               DateTime(Date(-1, 12, 31), TimeOfDay(23, 0, 0)));

        testDT(DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 33)), 1_052_760,
               DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 33)));
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 33)), -1_052_760,
               DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 33)));

        testDT(DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 33)), 1_052_782,
               DateTime(Date(-1, 1, 1), TimeOfDay(11, 52, 33)));
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(13, 52, 33)), -1_052_782,
               DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 33)));

        auto dt = DateTime(2000, 1, 31, 9, 7, 6);
        dt.roll!"minutes"(92).roll!"minutes"(-292);
        assert(dt == DateTime(2000, 1, 31, 9, 47, 6));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.roll!"minutes"(4)));
        static assert(!__traits(compiles, idt.roll!"minutes"(4)));
    }

    // Test roll!"seconds"().
    @safe unittest
    {
        static void testDT(DateTime orig, int seconds, in DateTime expected, size_t line = __LINE__)
        {
            orig.roll!"seconds"(seconds);
            assert(orig == expected);
        }

        // Test A.D.
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 2,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 35)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 3,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 36)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 4,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 37)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 5,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 38)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 10,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 43)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 15,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 48)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 26,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 59)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 27,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 30,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 3)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 59,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 32)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 60,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 61,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1766,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 59)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1767,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 1768,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 1)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 2007,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 3599,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 32)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 3600,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 3601,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), 7200,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 32)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -2,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 31)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -3,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 30)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -4,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 29)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -5,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 28)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -10,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 23)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -15,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 18)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -33,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -34,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 59)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -35,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 58)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -59,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -60,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)), -61,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 32)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 1)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 0)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 59)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 0)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 1)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 0)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 0)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 0)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 0, 59)));

        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 0)), 1,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 1)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 0)), 0,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 0)));
        testDT(DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 0)), -1,
               DateTime(Date(1999, 7, 6), TimeOfDay(0, 0, 59)));

        testDT(DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 59)), 1,
               DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 0)));
        testDT(DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 59)), 0,
               DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 59)));
        testDT(DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 59)), -1,
               DateTime(Date(1999, 7, 5), TimeOfDay(23, 59, 58)));

        testDT(DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 59)), 1,
               DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 0)));
        testDT(DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 59)), 0,
               DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 59)));
        testDT(DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 59)), -1,
               DateTime(Date(1998, 12, 31), TimeOfDay(23, 59, 58)));

        // Test B.C.
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 34)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 2,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 35)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 3,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 36)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 4,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 37)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 5,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 38)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 10,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 43)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 15,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 48)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 26,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 59)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 27,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 30,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 3)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 59,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 32)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 60,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 61,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 34)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1766,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 59)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1767,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 1768,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 1)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 2007,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 3599,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 32)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 3600,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 3601,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 34)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), 7200,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 32)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -2,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 31)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -3,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 30)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -4,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 29)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -5,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 28)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -10,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 23)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -15,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 18)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -33,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -34,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 59)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -35,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 58)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -59,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 34)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -60,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)), -61,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 32)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 1)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 0)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 59)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 0)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 1)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 0)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 0)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 0)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 0, 59)));

        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 0)), 1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 1)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 0)), 0,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 0)));
        testDT(DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 0)), -1,
               DateTime(Date(-1999, 7, 6), TimeOfDay(0, 0, 59)));

        testDT(DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 59)), 1,
               DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 0)));
        testDT(DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 59)), 0,
               DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 59)));
        testDT(DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 59)), -1,
               DateTime(Date(-1999, 7, 5), TimeOfDay(23, 59, 58)));

        testDT(DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 59)), 1,
               DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 0)));
        testDT(DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 59)), 0,
               DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 59)));
        testDT(DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 59)), -1,
               DateTime(Date(-2000, 12, 31), TimeOfDay(23, 59, 58)));

        // Test Both
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(0, 0, 0)), -1,
               DateTime(Date(1, 1, 1), TimeOfDay(0, 0, 59)));
        testDT(DateTime(Date(0, 12, 31), TimeOfDay(23, 59, 59)), 1,
               DateTime(Date(0, 12, 31), TimeOfDay(23, 59, 0)));

        testDT(DateTime(Date(0, 1, 1), TimeOfDay(0, 0, 0)), -1,
               DateTime(Date(0, 1, 1), TimeOfDay(0, 0, 59)));
        testDT(DateTime(Date(-1, 12, 31), TimeOfDay(23, 59, 59)), 1,
               DateTime(Date(-1, 12, 31), TimeOfDay(23, 59, 0)));

        testDT(DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 33)), 63_165_600L,
               DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 33)));
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 33)), -63_165_600L,
               DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 33)));

        testDT(DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 33)), 63_165_617L,
               DateTime(Date(-1, 1, 1), TimeOfDay(11, 30, 50)));
        testDT(DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 50)), -63_165_617L,
               DateTime(Date(1, 1, 1), TimeOfDay(13, 30, 33)));

        auto dt = DateTime(2000, 1, 31, 9, 7, 6);
        dt.roll!"seconds"(92).roll!"seconds"(-292);
        assert(dt == DateTime(2000, 1, 31, 9, 7, 46));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt.roll!"seconds"(4)));
        static assert(!__traits(compiles, idt.roll!"seconds"(4)));
    }


    /++
        Gives the result of adding or subtracting a $(REF Duration, core,time) from
        this $(LREF DateTime).

        The legal types of arithmetic for $(LREF DateTime) using this operator
        are

        $(BOOKTABLE,
        $(TR $(TD DateTime) $(TD +) $(TD Duration) $(TD -->) $(TD DateTime))
        $(TR $(TD DateTime) $(TD -) $(TD Duration) $(TD -->) $(TD DateTime))
        )

        Params:
            duration = The $(REF Duration, core,time) to add to or subtract from
                       this $(LREF DateTime).
      +/
    DateTime opBinary(string op)(Duration duration) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        DateTime retval = this;
        immutable seconds = duration.total!"seconds";
        mixin("return retval._addSeconds(" ~ op ~ "seconds);");
    }

    ///
    @safe unittest
    {
        assert(DateTime(2015, 12, 31, 23, 59, 59) + seconds(1) ==
               DateTime(2016, 1, 1, 0, 0, 0));

        assert(DateTime(2015, 12, 31, 23, 59, 59) + hours(1) ==
               DateTime(2016, 1, 1, 0, 59, 59));

        assert(DateTime(2016, 1, 1, 0, 0, 0) - seconds(1) ==
               DateTime(2015, 12, 31, 23, 59, 59));

        assert(DateTime(2016, 1, 1, 0, 59, 59) - hours(1) ==
               DateTime(2015, 12, 31, 23, 59, 59));
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));

        assert(dt + dur!"weeks"(7) == DateTime(Date(1999, 8, 24), TimeOfDay(12, 30, 33)));
        assert(dt + dur!"weeks"(-7) == DateTime(Date(1999, 5, 18), TimeOfDay(12, 30, 33)));
        assert(dt + dur!"days"(7) == DateTime(Date(1999, 7, 13), TimeOfDay(12, 30, 33)));
        assert(dt + dur!"days"(-7) == DateTime(Date(1999, 6, 29), TimeOfDay(12, 30, 33)));

        assert(dt + dur!"hours"(7) == DateTime(Date(1999, 7, 6), TimeOfDay(19, 30, 33)));
        assert(dt + dur!"hours"(-7) == DateTime(Date(1999, 7, 6), TimeOfDay(5, 30, 33)));
        assert(dt + dur!"minutes"(7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 37, 33)));
        assert(dt + dur!"minutes"(-7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 23, 33)));
        assert(dt + dur!"seconds"(7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt + dur!"seconds"(-7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(dt + dur!"msecs"(7_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt + dur!"msecs"(-7_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(dt + dur!"usecs"(7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt + dur!"usecs"(-7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(dt + dur!"hnsecs"(70_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt + dur!"hnsecs"(-70_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));

        assert(dt - dur!"weeks"(-7) == DateTime(Date(1999, 8, 24), TimeOfDay(12, 30, 33)));
        assert(dt - dur!"weeks"(7) == DateTime(Date(1999, 5, 18), TimeOfDay(12, 30, 33)));
        assert(dt - dur!"days"(-7) == DateTime(Date(1999, 7, 13), TimeOfDay(12, 30, 33)));
        assert(dt - dur!"days"(7) == DateTime(Date(1999, 6, 29), TimeOfDay(12, 30, 33)));

        assert(dt - dur!"hours"(-7) == DateTime(Date(1999, 7, 6), TimeOfDay(19, 30, 33)));
        assert(dt - dur!"hours"(7) == DateTime(Date(1999, 7, 6), TimeOfDay(5, 30, 33)));
        assert(dt - dur!"minutes"(-7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 37, 33)));
        assert(dt - dur!"minutes"(7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 23, 33)));
        assert(dt - dur!"seconds"(-7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt - dur!"seconds"(7) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(dt - dur!"msecs"(-7_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt - dur!"msecs"(7_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(dt - dur!"usecs"(-7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt - dur!"usecs"(7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(dt - dur!"hnsecs"(-70_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(dt - dur!"hnsecs"(70_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));

        auto duration = dur!"seconds"(12);
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(cdt + duration == DateTime(1999, 7, 6, 12, 30, 45));
        assert(idt + duration == DateTime(1999, 7, 6, 12, 30, 45));
        assert(cdt - duration == DateTime(1999, 7, 6, 12, 30, 21));
        assert(idt - duration == DateTime(1999, 7, 6, 12, 30, 21));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    DateTime opBinary(string op)(in TickDuration td) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        DateTime retval = this;
        immutable seconds = td.seconds;
        mixin("return retval._addSeconds(" ~ op ~ "seconds);");
    }

    deprecated @safe unittest
    {
        // This probably only runs in cases where gettimeofday() is used, but it's
        // hard to do this test correctly with variable ticksPerSec.
        if (TickDuration.ticksPerSec == 1_000_000)
        {
            auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));

            assert(dt + TickDuration.from!"usecs"(7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
            assert(dt + TickDuration.from!"usecs"(-7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));

            assert(dt - TickDuration.from!"usecs"(-7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
            assert(dt - TickDuration.from!"usecs"(7_000_000) == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        }
    }


    /++
        Gives the result of adding or subtracting a duration from this
        $(LREF DateTime), as well as assigning the result to this $(LREF DateTime).

        The legal types of arithmetic for $(LREF DateTime) using this operator are

        $(BOOKTABLE,
        $(TR $(TD DateTime) $(TD +) $(TD duration) $(TD -->) $(TD DateTime))
        $(TR $(TD DateTime) $(TD -) $(TD duration) $(TD -->) $(TD DateTime))
        )

        Params:
            duration = The duration to add to or subtract from this
                       $(LREF DateTime).
      +/
    ref DateTime opOpAssign(string op, D)(in D duration) @safe pure nothrow
        if ((op == "+" || op == "-") &&
           (is(Unqual!D == Duration) ||
            is(Unqual!D == TickDuration)))
    {
        import std.format : format;

        DateTime retval = this;

        static if (is(Unqual!D == Duration))
            immutable hnsecs = duration.total!"hnsecs";
        else static if (is(Unqual!D == TickDuration))
            immutable hnsecs = duration.hnsecs;

        mixin(format(`return _addSeconds(convert!("hnsecs", "seconds")(%shnsecs));`, op));
    }

    @safe unittest
    {
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"weeks"(7) ==
               DateTime(Date(1999, 8, 24), TimeOfDay(12, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"weeks"(-7) ==
               DateTime(Date(1999, 5, 18), TimeOfDay(12, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"days"(7) ==
               DateTime(Date(1999, 7, 13), TimeOfDay(12, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"days"(-7) ==
               DateTime(Date(1999, 6, 29), TimeOfDay(12, 30, 33)));

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"hours"(7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(19, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"hours"(-7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(5, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"minutes"(7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 37, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"minutes"(-7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 23, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"seconds"(7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"seconds"(-7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"msecs"(7_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"msecs"(-7_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"usecs"(7_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"usecs"(-7_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"hnsecs"(70_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) + dur!"hnsecs"(-70_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"weeks"(-7) ==
               DateTime(Date(1999, 8, 24), TimeOfDay(12, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"weeks"(7) ==
               DateTime(Date(1999, 5, 18), TimeOfDay(12, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"days"(-7) ==
               DateTime(Date(1999, 7, 13), TimeOfDay(12, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"days"(7) ==
               DateTime(Date(1999, 6, 29), TimeOfDay(12, 30, 33)));

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"hours"(-7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(19, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"hours"(7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(5, 30, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"minutes"(-7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 37, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"minutes"(7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 23, 33)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"seconds"(-7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"seconds"(7) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"msecs"(-7_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"msecs"(7_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"usecs"(-7_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"usecs"(7_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"hnsecs"(-70_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - dur!"hnsecs"(70_000_000) ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));

        auto dt = DateTime(2000, 1, 31, 9, 7, 6);
        (dt += dur!"seconds"(92)) -= dur!"days"(-500);
        assert(dt == DateTime(2001, 6, 14, 9, 8, 38));

        auto duration = dur!"seconds"(12);
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        static assert(!__traits(compiles, cdt += duration));
        static assert(!__traits(compiles, idt += duration));
        static assert(!__traits(compiles, cdt -= duration));
        static assert(!__traits(compiles, idt -= duration));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    ref DateTime opOpAssign(string op)(TickDuration td) @safe pure nothrow
        if (op == "+" || op == "-")
    {
        DateTime retval = this;
        immutable seconds = td.seconds;
        mixin("return _addSeconds(" ~ op ~ "seconds);");
    }

    deprecated @safe unittest
    {
        // This probably only runs in cases where gettimeofday() is used, but it's
        // hard to do this test correctly with variable ticksPerSec.
        if (TickDuration.ticksPerSec == 1_000_000)
        {
            {
                auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
                dt += TickDuration.from!"usecs"(7_000_000);
                assert(dt == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
            }

            {
                auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
                dt += TickDuration.from!"usecs"(-7_000_000);
                assert(dt == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
            }

            {
                auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
                dt -= TickDuration.from!"usecs"(-7_000_000);
                assert(dt == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 40)));
            }

            {
                auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
                dt -= TickDuration.from!"usecs"(7_000_000);
                assert(dt == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 26)));
            }
        }
    }


    /++
        Gives the difference between two $(LREF DateTime)s.

        The legal types of arithmetic for $(LREF DateTime) using this operator are

        $(BOOKTABLE,
        $(TR $(TD DateTime) $(TD -) $(TD DateTime) $(TD -->) $(TD duration))
        )
      +/
    Duration opBinary(string op)(in DateTime rhs) @safe const pure nothrow
        if (op == "-")
    {
        immutable dateResult = _date - rhs.date;
        immutable todResult = _tod - rhs._tod;

        return dur!"hnsecs"(dateResult.total!"hnsecs" + todResult.total!"hnsecs");
    }

    @safe unittest
    {
        auto dt = DateTime(1999, 7, 6, 12, 30, 33);

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1998, 7, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(31_536_000));
        assert(DateTime(Date(1998, 7, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(-31_536_000));

        assert(DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(26_78_400));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 8, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(-26_78_400));

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 7, 5), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(86_400));
        assert(DateTime(Date(1999, 7, 5), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(-86_400));

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(11, 30, 33)) ==
               dur!"seconds"(3600));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(11, 30, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(-3600));

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(60));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 31, 33)) ==
               dur!"seconds"(-60));

        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) ==
               dur!"seconds"(1));
        assert(DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)) - DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 34)) ==
               dur!"seconds"(-1));

        assert(DateTime(1, 1, 1, 12, 30, 33) - DateTime(1, 1, 1, 0, 0, 0) == dur!"seconds"(45033));
        assert(DateTime(1, 1, 1, 0, 0, 0) - DateTime(1, 1, 1, 12, 30, 33) == dur!"seconds"(-45033));
        assert(DateTime(0, 12, 31, 12, 30, 33) - DateTime(1, 1, 1, 0, 0, 0) == dur!"seconds"(-41367));
        assert(DateTime(1, 1, 1, 0, 0, 0) - DateTime(0, 12, 31, 12, 30, 33) == dur!"seconds"(41367));

        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(dt - dt == Duration.zero);
        assert(cdt - dt == Duration.zero);
        assert(idt - dt == Duration.zero);

        assert(dt - cdt == Duration.zero);
        assert(cdt - cdt == Duration.zero);
        assert(idt - cdt == Duration.zero);

        assert(dt - idt == Duration.zero);
        assert(cdt - idt == Duration.zero);
        assert(idt - idt == Duration.zero);
    }


    /++
        Returns the difference between the two $(LREF DateTime)s in months.

        To get the difference in years, subtract the year property
        of two $(LREF DateTime)s. To get the difference in days or weeks,
        subtract the $(LREF DateTime)s themselves and use the $(REF Duration, core,time)
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
            rhs = The $(LREF DateTime) to subtract from this one.
      +/
    int diffMonths(in DateTime rhs) @safe const pure nothrow
    {
        return _date.diffMonths(rhs._date);
    }

    ///
    @safe unittest
    {
        assert(DateTime(1999, 2, 1, 12, 2, 3).diffMonths(
                   DateTime(1999, 1, 31, 23, 59, 59)) == 1);

        assert(DateTime(1999, 1, 31, 0, 0, 0).diffMonths(
                   DateTime(1999, 2, 1, 12, 3, 42)) == -1);

        assert(DateTime(1999, 3, 1, 5, 30, 0).diffMonths(
                   DateTime(1999, 1, 1, 2, 4, 7)) == 2);

        assert(DateTime(1999, 1, 1, 7, 2, 4).diffMonths(
                   DateTime(1999, 3, 31, 0, 30, 58)) == -2);
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(dt.diffMonths(dt) == 0);
        assert(cdt.diffMonths(dt) == 0);
        assert(idt.diffMonths(dt) == 0);

        assert(dt.diffMonths(cdt) == 0);
        assert(cdt.diffMonths(cdt) == 0);
        assert(idt.diffMonths(cdt) == 0);

        assert(dt.diffMonths(idt) == 0);
        assert(cdt.diffMonths(idt) == 0);
        assert(idt.diffMonths(idt) == 0);
    }


    /++
        Whether this $(LREF DateTime) is in a leap year.
     +/
    @property bool isLeapYear() @safe const pure nothrow
    {
        return _date.isLeapYear;
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(!dt.isLeapYear);
        assert(!cdt.isLeapYear);
        assert(!idt.isLeapYear);
    }


    /++
        Day of the week this $(LREF DateTime) is on.
      +/
    @property DayOfWeek dayOfWeek() @safe const pure nothrow
    {
        return _date.dayOfWeek;
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(dt.dayOfWeek == DayOfWeek.tue);
        assert(cdt.dayOfWeek == DayOfWeek.tue);
        assert(idt.dayOfWeek == DayOfWeek.tue);
    }


    /++
        Day of the year this $(LREF DateTime) is on.
      +/
    @property ushort dayOfYear() @safe const pure nothrow
    {
        return _date.dayOfYear;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1999, 1, 1), TimeOfDay(12, 22, 7)).dayOfYear == 1);
        assert(DateTime(Date(1999, 12, 31), TimeOfDay(7, 2, 59)).dayOfYear == 365);
        assert(DateTime(Date(2000, 12, 31), TimeOfDay(21, 20, 0)).dayOfYear == 366);
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(dt.dayOfYear == 187);
        assert(cdt.dayOfYear == 187);
        assert(idt.dayOfYear == 187);
    }


    /++
        Day of the year.

        Params:
            day = The day of the year to set which day of the year this
                  $(LREF DateTime) is on.
      +/
    @property void dayOfYear(int day) @safe pure
    {
        _date.dayOfYear = day;
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        dt.dayOfYear = 12;
        assert(dt.dayOfYear == 12);
        static assert(!__traits(compiles, cdt.dayOfYear = 12));
        static assert(!__traits(compiles, idt.dayOfYear = 12));
    }


    /++
        The Xth day of the Gregorian Calendar that this $(LREF DateTime) is on.
     +/
    @property int dayOfGregorianCal() @safe const pure nothrow
    {
        return _date.dayOfGregorianCal;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1, 1, 1), TimeOfDay(0, 0, 0)).dayOfGregorianCal == 1);
        assert(DateTime(Date(1, 12, 31), TimeOfDay(23, 59, 59)).dayOfGregorianCal == 365);
        assert(DateTime(Date(2, 1, 1), TimeOfDay(2, 2, 2)).dayOfGregorianCal == 366);

        assert(DateTime(Date(0, 12, 31), TimeOfDay(7, 7, 7)).dayOfGregorianCal == 0);
        assert(DateTime(Date(0, 1, 1), TimeOfDay(19, 30, 0)).dayOfGregorianCal == -365);
        assert(DateTime(Date(-1, 12, 31), TimeOfDay(4, 7, 0)).dayOfGregorianCal == -366);

        assert(DateTime(Date(2000, 1, 1), TimeOfDay(9, 30, 20)).dayOfGregorianCal == 730_120);
        assert(DateTime(Date(2010, 12, 31), TimeOfDay(15, 45, 50)).dayOfGregorianCal == 734_137);
    }

    @safe unittest
    {
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(cdt.dayOfGregorianCal == 729_941);
        assert(idt.dayOfGregorianCal == 729_941);
    }


    /++
        The Xth day of the Gregorian Calendar that this $(LREF DateTime) is on.
        Setting this property does not affect the time portion of
        $(LREF DateTime).

        Params:
            days = The day of the Gregorian Calendar to set this $(LREF DateTime)
                   to.
     +/
    @property void dayOfGregorianCal(int days) @safe pure nothrow
    {
        _date.dayOfGregorianCal = days;
    }

    ///
    @safe unittest
    {
        auto dt = DateTime(Date.init, TimeOfDay(12, 0, 0));
        dt.dayOfGregorianCal = 1;
        assert(dt == DateTime(Date(1, 1, 1), TimeOfDay(12, 0, 0)));

        dt.dayOfGregorianCal = 365;
        assert(dt == DateTime(Date(1, 12, 31), TimeOfDay(12, 0, 0)));

        dt.dayOfGregorianCal = 366;
        assert(dt == DateTime(Date(2, 1, 1), TimeOfDay(12, 0, 0)));

        dt.dayOfGregorianCal = 0;
        assert(dt == DateTime(Date(0, 12, 31), TimeOfDay(12, 0, 0)));

        dt.dayOfGregorianCal = -365;
        assert(dt == DateTime(Date(-0, 1, 1), TimeOfDay(12, 0, 0)));

        dt.dayOfGregorianCal = -366;
        assert(dt == DateTime(Date(-1, 12, 31), TimeOfDay(12, 0, 0)));

        dt.dayOfGregorianCal = 730_120;
        assert(dt == DateTime(Date(2000, 1, 1), TimeOfDay(12, 0, 0)));

        dt.dayOfGregorianCal = 734_137;
        assert(dt == DateTime(Date(2010, 12, 31), TimeOfDay(12, 0, 0)));
    }

    @safe unittest
    {
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        static assert(!__traits(compiles, cdt.dayOfGregorianCal = 7));
        static assert(!__traits(compiles, idt.dayOfGregorianCal = 7));
    }


    /++
        The ISO 8601 week of the year that this $(LREF DateTime) is in.

        See_Also:
            $(HTTP en.wikipedia.org/wiki/ISO_week_date, ISO Week Date)
      +/
    @property ubyte isoWeek() @safe const pure nothrow
    {
        return _date.isoWeek;
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(dt.isoWeek == 27);
        assert(cdt.isoWeek == 27);
        assert(idt.isoWeek == 27);
    }


    /++
        $(LREF DateTime) for the last day in the month that this $(LREF DateTime) is
        in. The time portion of endOfMonth is always 23:59:59.
      +/
    @property DateTime endOfMonth() @safe const pure nothrow
    {
        try
            return DateTime(_date.endOfMonth, TimeOfDay(23, 59, 59));
        catch (Exception e)
            assert(0, "DateTime constructor threw.");
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1999, 1, 6), TimeOfDay(0, 0, 0)).endOfMonth ==
               DateTime(Date(1999, 1, 31), TimeOfDay(23, 59, 59)));

        assert(DateTime(Date(1999, 2, 7), TimeOfDay(19, 30, 0)).endOfMonth ==
               DateTime(Date(1999, 2, 28), TimeOfDay(23, 59, 59)));

        assert(DateTime(Date(2000, 2, 7), TimeOfDay(5, 12, 27)).endOfMonth ==
               DateTime(Date(2000, 2, 29), TimeOfDay(23, 59, 59)));

        assert(DateTime(Date(2000, 6, 4), TimeOfDay(12, 22, 9)).endOfMonth ==
               DateTime(Date(2000, 6, 30), TimeOfDay(23, 59, 59)));
    }

    @safe unittest
    {
        // Test A.D.
        assert(DateTime(1999, 1, 1, 0, 13, 26).endOfMonth == DateTime(1999, 1, 31, 23, 59, 59));
        assert(DateTime(1999, 2, 1, 1, 14, 27).endOfMonth == DateTime(1999, 2, 28, 23, 59, 59));
        assert(DateTime(2000, 2, 1, 2, 15, 28).endOfMonth == DateTime(2000, 2, 29, 23, 59, 59));
        assert(DateTime(1999, 3, 1, 3, 16, 29).endOfMonth == DateTime(1999, 3, 31, 23, 59, 59));
        assert(DateTime(1999, 4, 1, 4, 17, 30).endOfMonth == DateTime(1999, 4, 30, 23, 59, 59));
        assert(DateTime(1999, 5, 1, 5, 18, 31).endOfMonth == DateTime(1999, 5, 31, 23, 59, 59));
        assert(DateTime(1999, 6, 1, 6, 19, 32).endOfMonth == DateTime(1999, 6, 30, 23, 59, 59));
        assert(DateTime(1999, 7, 1, 7, 20, 33).endOfMonth == DateTime(1999, 7, 31, 23, 59, 59));
        assert(DateTime(1999, 8, 1, 8, 21, 34).endOfMonth == DateTime(1999, 8, 31, 23, 59, 59));
        assert(DateTime(1999, 9, 1, 9, 22, 35).endOfMonth == DateTime(1999, 9, 30, 23, 59, 59));
        assert(DateTime(1999, 10, 1, 10, 23, 36).endOfMonth == DateTime(1999, 10, 31, 23, 59, 59));
        assert(DateTime(1999, 11, 1, 11, 24, 37).endOfMonth == DateTime(1999, 11, 30, 23, 59, 59));
        assert(DateTime(1999, 12, 1, 12, 25, 38).endOfMonth == DateTime(1999, 12, 31, 23, 59, 59));

        // Test B.C.
        assert(DateTime(-1999, 1, 1, 0, 13, 26).endOfMonth == DateTime(-1999, 1, 31, 23, 59, 59));
        assert(DateTime(-1999, 2, 1, 1, 14, 27).endOfMonth == DateTime(-1999, 2, 28, 23, 59, 59));
        assert(DateTime(-2000, 2, 1, 2, 15, 28).endOfMonth == DateTime(-2000, 2, 29, 23, 59, 59));
        assert(DateTime(-1999, 3, 1, 3, 16, 29).endOfMonth == DateTime(-1999, 3, 31, 23, 59, 59));
        assert(DateTime(-1999, 4, 1, 4, 17, 30).endOfMonth == DateTime(-1999, 4, 30, 23, 59, 59));
        assert(DateTime(-1999, 5, 1, 5, 18, 31).endOfMonth == DateTime(-1999, 5, 31, 23, 59, 59));
        assert(DateTime(-1999, 6, 1, 6, 19, 32).endOfMonth == DateTime(-1999, 6, 30, 23, 59, 59));
        assert(DateTime(-1999, 7, 1, 7, 20, 33).endOfMonth == DateTime(-1999, 7, 31, 23, 59, 59));
        assert(DateTime(-1999, 8, 1, 8, 21, 34).endOfMonth == DateTime(-1999, 8, 31, 23, 59, 59));
        assert(DateTime(-1999, 9, 1, 9, 22, 35).endOfMonth == DateTime(-1999, 9, 30, 23, 59, 59));
        assert(DateTime(-1999, 10, 1, 10, 23, 36).endOfMonth == DateTime(-1999, 10, 31, 23, 59, 59));
        assert(DateTime(-1999, 11, 1, 11, 24, 37).endOfMonth == DateTime(-1999, 11, 30, 23, 59, 59));
        assert(DateTime(-1999, 12, 1, 12, 25, 38).endOfMonth == DateTime(-1999, 12, 31, 23, 59, 59));

        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(cdt.endOfMonth == DateTime(1999, 7, 31, 23, 59, 59));
        assert(idt.endOfMonth == DateTime(1999, 7, 31, 23, 59, 59));
    }


    /++
        The last day in the month that this $(LREF DateTime) is in.
      +/
    @property ubyte daysInMonth() @safe const pure nothrow
    {
        return _date.daysInMonth;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1999, 1, 6), TimeOfDay(0, 0, 0)).daysInMonth == 31);
        assert(DateTime(Date(1999, 2, 7), TimeOfDay(19, 30, 0)).daysInMonth == 28);
        assert(DateTime(Date(2000, 2, 7), TimeOfDay(5, 12, 27)).daysInMonth == 29);
        assert(DateTime(Date(2000, 6, 4), TimeOfDay(12, 22, 9)).daysInMonth == 30);
    }

    @safe unittest
    {
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(cdt.daysInMonth == 31);
        assert(idt.daysInMonth == 31);
    }


    /++
        Whether the current year is a date in A.D.
      +/
    @property bool isAD() @safe const pure nothrow
    {
        return _date.isAD;
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(1, 1, 1), TimeOfDay(12, 7, 0)).isAD);
        assert(DateTime(Date(2010, 12, 31), TimeOfDay(0, 0, 0)).isAD);
        assert(!DateTime(Date(0, 12, 31), TimeOfDay(23, 59, 59)).isAD);
        assert(!DateTime(Date(-2010, 1, 1), TimeOfDay(2, 2, 2)).isAD);
    }

    @safe unittest
    {
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(cdt.isAD);
        assert(idt.isAD);
    }


    /++
        The $(HTTP en.wikipedia.org/wiki/Julian_day, Julian day) for this
        $(LREF DateTime) at the given time. For example, prior to noon,
        1996-03-31 would be the Julian day number 2_450_173, so this function
        returns 2_450_173, while from noon onward, the julian day number would
        be 2_450_174, so this function returns 2_450_174.
      +/
    @property long julianDay() @safe const pure nothrow
    {
        if (_tod._hour < 12)
            return _date.julianDay - 1;
        else
            return _date.julianDay;
    }

    @safe unittest
    {
        assert(DateTime(Date(-4713, 11, 24), TimeOfDay(0, 0, 0)).julianDay == -1);
        assert(DateTime(Date(-4713, 11, 24), TimeOfDay(12, 0, 0)).julianDay == 0);

        assert(DateTime(Date(0, 12, 31), TimeOfDay(0, 0, 0)).julianDay == 1_721_424);
        assert(DateTime(Date(0, 12, 31), TimeOfDay(12, 0, 0)).julianDay == 1_721_425);

        assert(DateTime(Date(1, 1, 1), TimeOfDay(0, 0, 0)).julianDay == 1_721_425);
        assert(DateTime(Date(1, 1, 1), TimeOfDay(12, 0, 0)).julianDay == 1_721_426);

        assert(DateTime(Date(1582, 10, 15), TimeOfDay(0, 0, 0)).julianDay == 2_299_160);
        assert(DateTime(Date(1582, 10, 15), TimeOfDay(12, 0, 0)).julianDay == 2_299_161);

        assert(DateTime(Date(1858, 11, 17), TimeOfDay(0, 0, 0)).julianDay == 2_400_000);
        assert(DateTime(Date(1858, 11, 17), TimeOfDay(12, 0, 0)).julianDay == 2_400_001);

        assert(DateTime(Date(1982, 1, 4), TimeOfDay(0, 0, 0)).julianDay == 2_444_973);
        assert(DateTime(Date(1982, 1, 4), TimeOfDay(12, 0, 0)).julianDay == 2_444_974);

        assert(DateTime(Date(1996, 3, 31), TimeOfDay(0, 0, 0)).julianDay == 2_450_173);
        assert(DateTime(Date(1996, 3, 31), TimeOfDay(12, 0, 0)).julianDay == 2_450_174);

        assert(DateTime(Date(2010, 8, 24), TimeOfDay(0, 0, 0)).julianDay == 2_455_432);
        assert(DateTime(Date(2010, 8, 24), TimeOfDay(12, 0, 0)).julianDay == 2_455_433);

        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(cdt.julianDay == 2_451_366);
        assert(idt.julianDay == 2_451_366);
    }


    /++
        The modified $(HTTP en.wikipedia.org/wiki/Julian_day, Julian day) for any
        time on this date (since, the modified Julian day changes at midnight).
      +/
    @property long modJulianDay() @safe const pure nothrow
    {
        return _date.modJulianDay;
    }

    @safe unittest
    {
        assert(DateTime(Date(1858, 11, 17), TimeOfDay(0, 0, 0)).modJulianDay == 0);
        assert(DateTime(Date(1858, 11, 17), TimeOfDay(12, 0, 0)).modJulianDay == 0);

        assert(DateTime(Date(2010, 8, 24), TimeOfDay(0, 0, 0)).modJulianDay == 55_432);
        assert(DateTime(Date(2010, 8, 24), TimeOfDay(12, 0, 0)).modJulianDay == 55_432);

        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(cdt.modJulianDay == 51_365);
        assert(idt.modJulianDay == 51_365);
    }


    /++
        Converts this $(LREF DateTime) to a string with the format YYYYMMDDTHHMMSS.
      +/
    string toISOString() @safe const pure nothrow
    {
        import std.format : format;
        try
            return format("%sT%s", _date.toISOString(), _tod.toISOString());
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)).toISOString() ==
               "20100704T070612");

        assert(DateTime(Date(1998, 12, 25), TimeOfDay(2, 15, 0)).toISOString() ==
               "19981225T021500");

        assert(DateTime(Date(0, 1, 5), TimeOfDay(23, 9, 59)).toISOString() ==
               "00000105T230959");

        assert(DateTime(Date(-4, 1, 5), TimeOfDay(0, 0, 2)).toISOString() ==
               "-00040105T000002");
    }

    @safe unittest
    {
        // Test A.D.
        assert(DateTime(Date(9, 12, 4), TimeOfDay(0, 0, 0)).toISOString() == "00091204T000000");
        assert(DateTime(Date(99, 12, 4), TimeOfDay(5, 6, 12)).toISOString() == "00991204T050612");
        assert(DateTime(Date(999, 12, 4), TimeOfDay(13, 44, 59)).toISOString() == "09991204T134459");
        assert(DateTime(Date(9999, 7, 4), TimeOfDay(23, 59, 59)).toISOString() == "99990704T235959");
        assert(DateTime(Date(10000, 10, 20), TimeOfDay(1, 1, 1)).toISOString() == "+100001020T010101");

        // Test B.C.
        assert(DateTime(Date(0, 12, 4), TimeOfDay(0, 12, 4)).toISOString() == "00001204T001204");
        assert(DateTime(Date(-9, 12, 4), TimeOfDay(0, 0, 0)).toISOString() == "-00091204T000000");
        assert(DateTime(Date(-99, 12, 4), TimeOfDay(5, 6, 12)).toISOString() == "-00991204T050612");
        assert(DateTime(Date(-999, 12, 4), TimeOfDay(13, 44, 59)).toISOString() == "-09991204T134459");
        assert(DateTime(Date(-9999, 7, 4), TimeOfDay(23, 59, 59)).toISOString() == "-99990704T235959");
        assert(DateTime(Date(-10000, 10, 20), TimeOfDay(1, 1, 1)).toISOString() == "-100001020T010101");

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.toISOString() == "19990706T123033");
        assert(idt.toISOString() == "19990706T123033");
    }


    /++
        Converts this $(LREF DateTime) to a string with the format
        YYYY-MM-DDTHH:MM:SS.
      +/
    string toISOExtString() @safe const pure nothrow
    {
        import std.format : format;
        try
            return format("%sT%s", _date.toISOExtString(), _tod.toISOExtString());
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)).toISOExtString() ==
               "2010-07-04T07:06:12");

        assert(DateTime(Date(1998, 12, 25), TimeOfDay(2, 15, 0)).toISOExtString() ==
               "1998-12-25T02:15:00");

        assert(DateTime(Date(0, 1, 5), TimeOfDay(23, 9, 59)).toISOExtString() ==
               "0000-01-05T23:09:59");

        assert(DateTime(Date(-4, 1, 5), TimeOfDay(0, 0, 2)).toISOExtString() ==
               "-0004-01-05T00:00:02");
    }

    @safe unittest
    {
        // Test A.D.
        assert(DateTime(Date(9, 12, 4), TimeOfDay(0, 0, 0)).toISOExtString() == "0009-12-04T00:00:00");
        assert(DateTime(Date(99, 12, 4), TimeOfDay(5, 6, 12)).toISOExtString() == "0099-12-04T05:06:12");
        assert(DateTime(Date(999, 12, 4), TimeOfDay(13, 44, 59)).toISOExtString() == "0999-12-04T13:44:59");
        assert(DateTime(Date(9999, 7, 4), TimeOfDay(23, 59, 59)).toISOExtString() == "9999-07-04T23:59:59");
        assert(DateTime(Date(10000, 10, 20), TimeOfDay(1, 1, 1)).toISOExtString() == "+10000-10-20T01:01:01");

        // Test B.C.
        assert(DateTime(Date(0, 12, 4), TimeOfDay(0, 12, 4)).toISOExtString() == "0000-12-04T00:12:04");
        assert(DateTime(Date(-9, 12, 4), TimeOfDay(0, 0, 0)).toISOExtString() == "-0009-12-04T00:00:00");
        assert(DateTime(Date(-99, 12, 4), TimeOfDay(5, 6, 12)).toISOExtString() == "-0099-12-04T05:06:12");
        assert(DateTime(Date(-999, 12, 4), TimeOfDay(13, 44, 59)).toISOExtString() == "-0999-12-04T13:44:59");
        assert(DateTime(Date(-9999, 7, 4), TimeOfDay(23, 59, 59)).toISOExtString() == "-9999-07-04T23:59:59");
        assert(DateTime(Date(-10000, 10, 20), TimeOfDay(1, 1, 1)).toISOExtString() == "-10000-10-20T01:01:01");

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.toISOExtString() == "1999-07-06T12:30:33");
        assert(idt.toISOExtString() == "1999-07-06T12:30:33");
    }

    /++
        Converts this $(LREF DateTime) to a string with the format
        YYYY-Mon-DD HH:MM:SS.
      +/
    string toSimpleString() @safe const pure nothrow
    {
        import std.format : format;
        try
            return format("%s %s", _date.toSimpleString(), _tod.toString());
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)).toSimpleString() ==
               "2010-Jul-04 07:06:12");

        assert(DateTime(Date(1998, 12, 25), TimeOfDay(2, 15, 0)).toSimpleString() ==
               "1998-Dec-25 02:15:00");

        assert(DateTime(Date(0, 1, 5), TimeOfDay(23, 9, 59)).toSimpleString() ==
               "0000-Jan-05 23:09:59");

        assert(DateTime(Date(-4, 1, 5), TimeOfDay(0, 0, 2)).toSimpleString() ==
               "-0004-Jan-05 00:00:02");
    }

    @safe unittest
    {
        // Test A.D.
        assert(DateTime(Date(9, 12, 4), TimeOfDay(0, 0, 0)).toSimpleString() == "0009-Dec-04 00:00:00");
        assert(DateTime(Date(99, 12, 4), TimeOfDay(5, 6, 12)).toSimpleString() == "0099-Dec-04 05:06:12");
        assert(DateTime(Date(999, 12, 4), TimeOfDay(13, 44, 59)).toSimpleString() == "0999-Dec-04 13:44:59");
        assert(DateTime(Date(9999, 7, 4), TimeOfDay(23, 59, 59)).toSimpleString() == "9999-Jul-04 23:59:59");
        assert(DateTime(Date(10000, 10, 20), TimeOfDay(1, 1, 1)).toSimpleString() == "+10000-Oct-20 01:01:01");

        // Test B.C.
        assert(DateTime(Date(0, 12, 4), TimeOfDay(0, 12, 4)).toSimpleString() == "0000-Dec-04 00:12:04");
        assert(DateTime(Date(-9, 12, 4), TimeOfDay(0, 0, 0)).toSimpleString() == "-0009-Dec-04 00:00:00");
        assert(DateTime(Date(-99, 12, 4), TimeOfDay(5, 6, 12)).toSimpleString() == "-0099-Dec-04 05:06:12");
        assert(DateTime(Date(-999, 12, 4), TimeOfDay(13, 44, 59)).toSimpleString() == "-0999-Dec-04 13:44:59");
        assert(DateTime(Date(-9999, 7, 4), TimeOfDay(23, 59, 59)).toSimpleString() == "-9999-Jul-04 23:59:59");
        assert(DateTime(Date(-10000, 10, 20), TimeOfDay(1, 1, 1)).toSimpleString() == "-10000-Oct-20 01:01:01");

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        assert(cdt.toSimpleString() == "1999-Jul-06 12:30:33");
        assert(idt.toSimpleString() == "1999-Jul-06 12:30:33");
    }


    /++
        Converts this $(LREF DateTime) to a string.
      +/
    string toString() @safe const pure nothrow
    {
        return toSimpleString();
    }

    @safe unittest
    {
        auto dt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        const cdt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        immutable idt = DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33));
        assert(dt.toString());
        assert(cdt.toString());
        assert(idt.toString());
    }



    /++
        Creates a $(LREF DateTime) from a string with the format YYYYMMDDTHHMMSS.
        Whitespace is stripped from the given string.

        Params:
            isoString = A string formatted in the ISO format for dates and times.

        Throws:
            $(LREF DateTimeException) if the given string is not in the ISO format
            or if the resulting $(LREF DateTime) would not be valid.
      +/
    static DateTime fromISOString(S)(in S isoString) @safe pure
        if (isSomeString!S)
    {
        import std.algorithm.searching : countUntil;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        immutable dstr = to!dstring(strip(isoString));

        enforce(dstr.length >= 15, new DateTimeException(format("Invalid ISO String: %s", isoString)));
        auto t = dstr.countUntil('T');

        enforce(t != -1, new DateTimeException(format("Invalid ISO String: %s", isoString)));

        immutable date = Date.fromISOString(dstr[0 .. t]);
        immutable tod = TimeOfDay.fromISOString(dstr[t+1 .. $]);

        return DateTime(date, tod);
    }

    ///
    @safe unittest
    {
        assert(DateTime.fromISOString("20100704T070612") ==
               DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)));

        assert(DateTime.fromISOString("19981225T021500") ==
               DateTime(Date(1998, 12, 25), TimeOfDay(2, 15, 0)));

        assert(DateTime.fromISOString("00000105T230959") ==
               DateTime(Date(0, 1, 5), TimeOfDay(23, 9, 59)));

        assert(DateTime.fromISOString("-00040105T000002") ==
               DateTime(Date(-4, 1, 5), TimeOfDay(0, 0, 2)));

        assert(DateTime.fromISOString(" 20100704T070612 ") ==
               DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(DateTime.fromISOString(""));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704000000"));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704 000000"));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704t000000"));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704T000000."));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704T000000.0"));

        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-0400:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04 00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04t00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04T00:00:00."));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04T00:00:00.0"));

        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-0400:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04 00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04t00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04T00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04 00:00:00."));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04 00:00:00.0"));

        assertThrown!DateTimeException(DateTime.fromISOString("2010-12-22T172201"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Dec-22 17:22:01"));

        assert(DateTime.fromISOString("20101222T172201") == DateTime(Date(2010, 12, 22), TimeOfDay(17, 22, 01)));
        assert(DateTime.fromISOString("19990706T123033") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOString("-19990706T123033") == DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOString("+019990706T123033") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOString("19990706T123033 ") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOString(" 19990706T123033") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOString(" 19990706T123033 ") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
    }


    /++
        Creates a $(LREF DateTime) from a string with the format
        YYYY-MM-DDTHH:MM:SS. Whitespace is stripped from the given string.

        Params:
            isoExtString = A string formatted in the ISO Extended format for dates
                           and times.

        Throws:
            $(LREF DateTimeException) if the given string is not in the ISO
            Extended format or if the resulting $(LREF DateTime) would not be
            valid.
      +/
    static DateTime fromISOExtString(S)(in S isoExtString) @safe pure
        if (isSomeString!(S))
    {
        import std.algorithm.searching : countUntil;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        immutable dstr = to!dstring(strip(isoExtString));

        enforce(dstr.length >= 15, new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        auto t = dstr.countUntil('T');

        enforce(t != -1, new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));

        immutable date = Date.fromISOExtString(dstr[0 .. t]);
        immutable tod = TimeOfDay.fromISOExtString(dstr[t+1 .. $]);

        return DateTime(date, tod);
    }

    ///
    @safe unittest
    {
        assert(DateTime.fromISOExtString("2010-07-04T07:06:12") ==
               DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)));

        assert(DateTime.fromISOExtString("1998-12-25T02:15:00") ==
               DateTime(Date(1998, 12, 25), TimeOfDay(2, 15, 0)));

        assert(DateTime.fromISOExtString("0000-01-05T23:09:59") ==
               DateTime(Date(0, 1, 5), TimeOfDay(23, 9, 59)));

        assert(DateTime.fromISOExtString("-0004-01-05T00:00:02") ==
               DateTime(Date(-4, 1, 5), TimeOfDay(0, 0, 2)));

        assert(DateTime.fromISOExtString(" 2010-07-04T07:06:12 ") ==
               DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(DateTime.fromISOExtString(""));
        assertThrown!DateTimeException(DateTime.fromISOExtString("20100704000000"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("20100704 000000"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("20100704t000000"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("20100704T000000."));
        assertThrown!DateTimeException(DateTime.fromISOExtString("20100704T000000.0"));

        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-07:0400:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-07-04 00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-07-04 00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-07-04t00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-07-04T00:00:00."));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-07-04T00:00:00.0"));

        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-Jul-0400:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-Jul-04t00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-Jul-04 00:00:00."));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-Jul-04 00:00:00.0"));

        assertThrown!DateTimeException(DateTime.fromISOExtString("20101222T172201"));
        assertThrown!DateTimeException(DateTime.fromISOExtString("2010-Dec-22 17:22:01"));

        assert(DateTime.fromISOExtString("2010-12-22T17:22:01") == DateTime(Date(2010, 12, 22), TimeOfDay(17, 22, 01)));
        assert(DateTime.fromISOExtString("1999-07-06T12:30:33") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOExtString("-1999-07-06T12:30:33") == DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOExtString("+01999-07-06T12:30:33") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOExtString("1999-07-06T12:30:33 ") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOExtString(" 1999-07-06T12:30:33") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromISOExtString(" 1999-07-06T12:30:33 ") == DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
    }


    /++
        Creates a $(LREF DateTime) from a string with the format
        YYYY-Mon-DD HH:MM:SS. Whitespace is stripped from the given string.

        Params:
            simpleString = A string formatted in the way that toSimpleString
                           formats dates and times.

        Throws:
            $(LREF DateTimeException) if the given string is not in the correct
            format or if the resulting $(LREF DateTime) would not be valid.
      +/
    static DateTime fromSimpleString(S)(in S simpleString) @safe pure
        if (isSomeString!(S))
    {
        import std.algorithm.searching : countUntil;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        immutable dstr = to!dstring(strip(simpleString));

        enforce(dstr.length >= 15, new DateTimeException(format("Invalid string format: %s", simpleString)));
        auto t = dstr.countUntil(' ');

        enforce(t != -1, new DateTimeException(format("Invalid string format: %s", simpleString)));

        immutable date = Date.fromSimpleString(dstr[0 .. t]);
        immutable tod = TimeOfDay.fromISOExtString(dstr[t+1 .. $]);

        return DateTime(date, tod);
    }

    ///
    @safe unittest
    {
        assert(DateTime.fromSimpleString("2010-Jul-04 07:06:12") ==
               DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)));
        assert(DateTime.fromSimpleString("1998-Dec-25 02:15:00") ==
               DateTime(Date(1998, 12, 25), TimeOfDay(2, 15, 0)));
        assert(DateTime.fromSimpleString("0000-Jan-05 23:09:59") ==
               DateTime(Date(0, 1, 5), TimeOfDay(23, 9, 59)));
        assert(DateTime.fromSimpleString("-0004-Jan-05 00:00:02") ==
               DateTime(Date(-4, 1, 5), TimeOfDay(0, 0, 2)));
        assert(DateTime.fromSimpleString(" 2010-Jul-04 07:06:12 ") ==
               DateTime(Date(2010, 7, 4), TimeOfDay(7, 6, 12)));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(DateTime.fromISOString(""));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704000000"));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704 000000"));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704t000000"));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704T000000."));
        assertThrown!DateTimeException(DateTime.fromISOString("20100704T000000.0"));

        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-0400:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04 00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04t00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04T00:00:00."));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-07-04T00:00:00.0"));

        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-0400:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04 00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04t00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04T00:00:00"));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04 00:00:00."));
        assertThrown!DateTimeException(DateTime.fromISOString("2010-Jul-04 00:00:00.0"));

        assertThrown!DateTimeException(DateTime.fromSimpleString("20101222T172201"));
        assertThrown!DateTimeException(DateTime.fromSimpleString("2010-12-22T172201"));

        assert(DateTime.fromSimpleString("2010-Dec-22 17:22:01") ==
               DateTime(Date(2010, 12, 22), TimeOfDay(17, 22, 01)));
        assert(DateTime.fromSimpleString("1999-Jul-06 12:30:33") ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromSimpleString("-1999-Jul-06 12:30:33") ==
               DateTime(Date(-1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromSimpleString("+01999-Jul-06 12:30:33") ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromSimpleString("1999-Jul-06 12:30:33 ") ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromSimpleString(" 1999-Jul-06 12:30:33") ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
        assert(DateTime.fromSimpleString(" 1999-Jul-06 12:30:33 ") ==
               DateTime(Date(1999, 7, 6), TimeOfDay(12, 30, 33)));
    }


    /++
        Returns the $(LREF DateTime) farthest in the past which is representable by
        $(LREF DateTime).
      +/
    @property static DateTime min() @safe pure nothrow
    out(result)
    {
        assert(result._date == Date.min);
        assert(result._tod == TimeOfDay.min);
    }
    body
    {
        auto dt = DateTime.init;
        dt._date._year = short.min;
        dt._date._month = Month.jan;
        dt._date._day = 1;

        return dt;
    }

    @safe unittest
    {
        assert(DateTime.min.year < 0);
        assert(DateTime.min < DateTime.max);
    }


    /++
        Returns the $(LREF DateTime) farthest in the future which is representable
        by $(LREF DateTime).
      +/
    @property static DateTime max() @safe pure nothrow
    out(result)
    {
        assert(result._date == Date.max);
        assert(result._tod == TimeOfDay.max);
    }
    body
    {
        auto dt = DateTime.init;
        dt._date._year = short.max;
        dt._date._month = Month.dec;
        dt._date._day = 31;
        dt._tod._hour = TimeOfDay.maxHour;
        dt._tod._minute = TimeOfDay.maxMinute;
        dt._tod._second = TimeOfDay.maxSecond;

        return dt;
    }

    @safe unittest
    {
        assert(DateTime.max.year > 0);
        assert(DateTime.max > DateTime.min);
    }


private:

    /+
        Add seconds to the time of day. Negative values will subtract. If the
        number of seconds overflows (or underflows), then the seconds will wrap,
        increasing (or decreasing) the number of minutes accordingly. The
        same goes for any larger units.

        Params:
            seconds = The number of seconds to add to this $(LREF DateTime).
      +/
    ref DateTime _addSeconds(long seconds) return @safe pure nothrow
    {
        long hnsecs = convert!("seconds", "hnsecs")(seconds);
        hnsecs += convert!("hours", "hnsecs")(_tod._hour);
        hnsecs += convert!("minutes", "hnsecs")(_tod._minute);
        hnsecs += convert!("seconds", "hnsecs")(_tod._second);

        auto days = splitUnitsFromHNSecs!"days"(hnsecs);

        if (hnsecs < 0)
        {
            hnsecs += convert!("days", "hnsecs")(1);
            --days;
        }

        _date._addDays(days);

        immutable newHours = splitUnitsFromHNSecs!"hours"(hnsecs);
        immutable newMinutes = splitUnitsFromHNSecs!"minutes"(hnsecs);
        immutable newSeconds = splitUnitsFromHNSecs!"seconds"(hnsecs);

        _tod._hour = cast(ubyte) newHours;
        _tod._minute = cast(ubyte) newMinutes;
        _tod._second = cast(ubyte) newSeconds;

        return this;
    }

    @safe unittest
    {
        static void testDT(DateTime orig, int seconds, in DateTime expected, size_t line = __LINE__)
        {
            orig._addSeconds(seconds);
            assert(orig == expected);
        }

        // Test A.D.
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 0, DateTime(1999, 7, 6, 12, 30, 33));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 1, DateTime(1999, 7, 6, 12, 30, 34));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 2, DateTime(1999, 7, 6, 12, 30, 35));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 3, DateTime(1999, 7, 6, 12, 30, 36));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 4, DateTime(1999, 7, 6, 12, 30, 37));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 5, DateTime(1999, 7, 6, 12, 30, 38));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 10, DateTime(1999, 7, 6, 12, 30, 43));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 15, DateTime(1999, 7, 6, 12, 30, 48));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 26, DateTime(1999, 7, 6, 12, 30, 59));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 27, DateTime(1999, 7, 6, 12, 31, 0));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 30, DateTime(1999, 7, 6, 12, 31, 3));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 59, DateTime(1999, 7, 6, 12, 31, 32));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 60, DateTime(1999, 7, 6, 12, 31, 33));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 61, DateTime(1999, 7, 6, 12, 31, 34));

        testDT(DateTime(1999, 7, 6, 12, 30, 33), 1766, DateTime(1999, 7, 6, 12, 59, 59));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 1767, DateTime(1999, 7, 6, 13, 0, 0));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 1768, DateTime(1999, 7, 6, 13, 0, 1));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 2007, DateTime(1999, 7, 6, 13, 4, 0));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 3599, DateTime(1999, 7, 6, 13, 30, 32));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 3600, DateTime(1999, 7, 6, 13, 30, 33));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 3601, DateTime(1999, 7, 6, 13, 30, 34));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), 7200, DateTime(1999, 7, 6, 14, 30, 33));
        testDT(DateTime(1999, 7, 6, 23, 0, 0), 432_123, DateTime(1999, 7, 11, 23, 2, 3));

        testDT(DateTime(1999, 7, 6, 12, 30, 33), -1, DateTime(1999, 7, 6, 12, 30, 32));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -2, DateTime(1999, 7, 6, 12, 30, 31));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -3, DateTime(1999, 7, 6, 12, 30, 30));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -4, DateTime(1999, 7, 6, 12, 30, 29));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -5, DateTime(1999, 7, 6, 12, 30, 28));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -10, DateTime(1999, 7, 6, 12, 30, 23));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -15, DateTime(1999, 7, 6, 12, 30, 18));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -33, DateTime(1999, 7, 6, 12, 30, 0));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -34, DateTime(1999, 7, 6, 12, 29, 59));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -35, DateTime(1999, 7, 6, 12, 29, 58));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -59, DateTime(1999, 7, 6, 12, 29, 34));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -60, DateTime(1999, 7, 6, 12, 29, 33));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -61, DateTime(1999, 7, 6, 12, 29, 32));

        testDT(DateTime(1999, 7, 6, 12, 30, 33), -1833, DateTime(1999, 7, 6, 12, 0, 0));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -1834, DateTime(1999, 7, 6, 11, 59, 59));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -3600, DateTime(1999, 7, 6, 11, 30, 33));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -3601, DateTime(1999, 7, 6, 11, 30, 32));
        testDT(DateTime(1999, 7, 6, 12, 30, 33), -5134, DateTime(1999, 7, 6, 11, 4, 59));
        testDT(DateTime(1999, 7, 6, 23, 0, 0), -432_123, DateTime(1999, 7, 1, 22, 57, 57));

        testDT(DateTime(1999, 7, 6, 12, 30, 0), 1, DateTime(1999, 7, 6, 12, 30, 1));
        testDT(DateTime(1999, 7, 6, 12, 30, 0), 0, DateTime(1999, 7, 6, 12, 30, 0));
        testDT(DateTime(1999, 7, 6, 12, 30, 0), -1, DateTime(1999, 7, 6, 12, 29, 59));

        testDT(DateTime(1999, 7, 6, 12, 0, 0), 1, DateTime(1999, 7, 6, 12, 0, 1));
        testDT(DateTime(1999, 7, 6, 12, 0, 0), 0, DateTime(1999, 7, 6, 12, 0, 0));
        testDT(DateTime(1999, 7, 6, 12, 0, 0), -1, DateTime(1999, 7, 6, 11, 59, 59));

        testDT(DateTime(1999, 7, 6, 0, 0, 0), 1, DateTime(1999, 7, 6, 0, 0, 1));
        testDT(DateTime(1999, 7, 6, 0, 0, 0), 0, DateTime(1999, 7, 6, 0, 0, 0));
        testDT(DateTime(1999, 7, 6, 0, 0, 0), -1, DateTime(1999, 7, 5, 23, 59, 59));

        testDT(DateTime(1999, 7, 5, 23, 59, 59), 1, DateTime(1999, 7, 6, 0, 0, 0));
        testDT(DateTime(1999, 7, 5, 23, 59, 59), 0, DateTime(1999, 7, 5, 23, 59, 59));
        testDT(DateTime(1999, 7, 5, 23, 59, 59), -1, DateTime(1999, 7, 5, 23, 59, 58));

        testDT(DateTime(1998, 12, 31, 23, 59, 59), 1, DateTime(1999, 1, 1, 0, 0, 0));
        testDT(DateTime(1998, 12, 31, 23, 59, 59), 0, DateTime(1998, 12, 31, 23, 59, 59));
        testDT(DateTime(1998, 12, 31, 23, 59, 59), -1, DateTime(1998, 12, 31, 23, 59, 58));

        testDT(DateTime(1998, 1, 1, 0, 0, 0), 1, DateTime(1998, 1, 1, 0, 0, 1));
        testDT(DateTime(1998, 1, 1, 0, 0, 0), 0, DateTime(1998, 1, 1, 0, 0, 0));
        testDT(DateTime(1998, 1, 1, 0, 0, 0), -1, DateTime(1997, 12, 31, 23, 59, 59));

        // Test B.C.
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 0, DateTime(-1999, 7, 6, 12, 30, 33));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 1, DateTime(-1999, 7, 6, 12, 30, 34));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 2, DateTime(-1999, 7, 6, 12, 30, 35));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 3, DateTime(-1999, 7, 6, 12, 30, 36));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 4, DateTime(-1999, 7, 6, 12, 30, 37));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 5, DateTime(-1999, 7, 6, 12, 30, 38));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 10, DateTime(-1999, 7, 6, 12, 30, 43));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 15, DateTime(-1999, 7, 6, 12, 30, 48));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 26, DateTime(-1999, 7, 6, 12, 30, 59));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 27, DateTime(-1999, 7, 6, 12, 31, 0));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 30, DateTime(-1999, 7, 6, 12, 31, 3));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 59, DateTime(-1999, 7, 6, 12, 31, 32));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 60, DateTime(-1999, 7, 6, 12, 31, 33));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 61, DateTime(-1999, 7, 6, 12, 31, 34));

        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 1766, DateTime(-1999, 7, 6, 12, 59, 59));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 1767, DateTime(-1999, 7, 6, 13, 0, 0));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 1768, DateTime(-1999, 7, 6, 13, 0, 1));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 2007, DateTime(-1999, 7, 6, 13, 4, 0));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 3599, DateTime(-1999, 7, 6, 13, 30, 32));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 3600, DateTime(-1999, 7, 6, 13, 30, 33));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 3601, DateTime(-1999, 7, 6, 13, 30, 34));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), 7200, DateTime(-1999, 7, 6, 14, 30, 33));
        testDT(DateTime(-1999, 7, 6, 23, 0, 0), 432_123, DateTime(-1999, 7, 11, 23, 2, 3));

        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -1, DateTime(-1999, 7, 6, 12, 30, 32));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -2, DateTime(-1999, 7, 6, 12, 30, 31));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -3, DateTime(-1999, 7, 6, 12, 30, 30));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -4, DateTime(-1999, 7, 6, 12, 30, 29));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -5, DateTime(-1999, 7, 6, 12, 30, 28));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -10, DateTime(-1999, 7, 6, 12, 30, 23));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -15, DateTime(-1999, 7, 6, 12, 30, 18));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -33, DateTime(-1999, 7, 6, 12, 30, 0));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -34, DateTime(-1999, 7, 6, 12, 29, 59));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -35, DateTime(-1999, 7, 6, 12, 29, 58));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -59, DateTime(-1999, 7, 6, 12, 29, 34));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -60, DateTime(-1999, 7, 6, 12, 29, 33));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -61, DateTime(-1999, 7, 6, 12, 29, 32));

        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -1833, DateTime(-1999, 7, 6, 12, 0, 0));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -1834, DateTime(-1999, 7, 6, 11, 59, 59));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -3600, DateTime(-1999, 7, 6, 11, 30, 33));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -3601, DateTime(-1999, 7, 6, 11, 30, 32));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -5134, DateTime(-1999, 7, 6, 11, 4, 59));
        testDT(DateTime(-1999, 7, 6, 12, 30, 33), -7200, DateTime(-1999, 7, 6, 10, 30, 33));
        testDT(DateTime(-1999, 7, 6, 23, 0, 0), -432_123, DateTime(-1999, 7, 1, 22, 57, 57));

        testDT(DateTime(-1999, 7, 6, 12, 30, 0), 1, DateTime(-1999, 7, 6, 12, 30, 1));
        testDT(DateTime(-1999, 7, 6, 12, 30, 0), 0, DateTime(-1999, 7, 6, 12, 30, 0));
        testDT(DateTime(-1999, 7, 6, 12, 30, 0), -1, DateTime(-1999, 7, 6, 12, 29, 59));

        testDT(DateTime(-1999, 7, 6, 12, 0, 0), 1, DateTime(-1999, 7, 6, 12, 0, 1));
        testDT(DateTime(-1999, 7, 6, 12, 0, 0), 0, DateTime(-1999, 7, 6, 12, 0, 0));
        testDT(DateTime(-1999, 7, 6, 12, 0, 0), -1, DateTime(-1999, 7, 6, 11, 59, 59));

        testDT(DateTime(-1999, 7, 6, 0, 0, 0), 1, DateTime(-1999, 7, 6, 0, 0, 1));
        testDT(DateTime(-1999, 7, 6, 0, 0, 0), 0, DateTime(-1999, 7, 6, 0, 0, 0));
        testDT(DateTime(-1999, 7, 6, 0, 0, 0), -1, DateTime(-1999, 7, 5, 23, 59, 59));

        testDT(DateTime(-1999, 7, 5, 23, 59, 59), 1, DateTime(-1999, 7, 6, 0, 0, 0));
        testDT(DateTime(-1999, 7, 5, 23, 59, 59), 0, DateTime(-1999, 7, 5, 23, 59, 59));
        testDT(DateTime(-1999, 7, 5, 23, 59, 59), -1, DateTime(-1999, 7, 5, 23, 59, 58));

        testDT(DateTime(-2000, 12, 31, 23, 59, 59), 1, DateTime(-1999, 1, 1, 0, 0, 0));
        testDT(DateTime(-2000, 12, 31, 23, 59, 59), 0, DateTime(-2000, 12, 31, 23, 59, 59));
        testDT(DateTime(-2000, 12, 31, 23, 59, 59), -1, DateTime(-2000, 12, 31, 23, 59, 58));

        testDT(DateTime(-2000, 1, 1, 0, 0, 0), 1, DateTime(-2000, 1, 1, 0, 0, 1));
        testDT(DateTime(-2000, 1, 1, 0, 0, 0), 0, DateTime(-2000, 1, 1, 0, 0, 0));
        testDT(DateTime(-2000, 1, 1, 0, 0, 0), -1, DateTime(-2001, 12, 31, 23, 59, 59));

        // Test Both
        testDT(DateTime(1, 1, 1, 0, 0, 0), -1, DateTime(0, 12, 31, 23, 59, 59));
        testDT(DateTime(0, 12, 31, 23, 59, 59), 1, DateTime(1, 1, 1, 0, 0, 0));

        testDT(DateTime(0, 1, 1, 0, 0, 0), -1, DateTime(-1, 12, 31, 23, 59, 59));
        testDT(DateTime(-1, 12, 31, 23, 59, 59), 1, DateTime(0, 1, 1, 0, 0, 0));

        testDT(DateTime(-1, 1, 1, 11, 30, 33), 63_165_600L, DateTime(1, 1, 1, 13, 30, 33));
        testDT(DateTime(1, 1, 1, 13, 30, 33), -63_165_600L, DateTime(-1, 1, 1, 11, 30, 33));

        testDT(DateTime(-1, 1, 1, 11, 30, 33), 63_165_617L, DateTime(1, 1, 1, 13, 30, 50));
        testDT(DateTime(1, 1, 1, 13, 30, 50), -63_165_617L, DateTime(-1, 1, 1, 11, 30, 33));

        const cdt = DateTime(1999, 7, 6, 12, 30, 33);
        immutable idt = DateTime(1999, 7, 6, 12, 30, 33);
        static assert(!__traits(compiles, cdt._addSeconds(4)));
        static assert(!__traits(compiles, idt._addSeconds(4)));
    }


    Date      _date;
    TimeOfDay _tod;
}


version(unittest)
{
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
    }
}
