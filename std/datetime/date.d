// Written in the D programming language

/++
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis
    Source:    $(PHOBOSSRC std/datetime/_date.d)
+/
module std.datetime.date;

import core.time;
import std.datetime.common;
import std.traits : isSomeString;

version(unittest) import std.exception : assertThrown;


@safe unittest
{
    initializeTests();
}


/++
    Represents a date in the
    $(HTTP en.wikipedia.org/wiki/Proleptic_Gregorian_calendar, Proleptic
    Gregorian Calendar) ranging from 32,768 B.C. to 32,767 A.D. Positive years
    are A.D. Non-positive years are B.C.

    Year, month, and day are kept separately internally so that $(D Date) is
    optimized for calendar-based operations.

    $(D Date) uses the Proleptic Gregorian Calendar, so it assumes the Gregorian
    leap year calculations for its entire length. As per
    $(HTTP en.wikipedia.org/wiki/ISO_8601, ISO 8601), it treats 1 B.C. as
    year 0, i.e. 1 B.C. is 0, 2 B.C. is -1, etc. Use $(LREF yearBC) to use B.C.
    as a positive integer with 1 B.C. being the year prior to 1 A.D.

    Year 0 is a leap year.
 +/
struct Date
{
public:

    /++
        Throws:
            $(REF std,datetime,common,DateTimeException) if the resulting
            $(LREF Date) would not be valid.

        Params:
            year  = Year of the Gregorian Calendar. Positive values are A.D.
                    Non-positive values are B.C. with year 0 being the year
                    prior to 1 A.D.
            month = Month of the year.
            day   = Day of the month.
     +/
    this(int year, int month, int day) @safe pure
    {
        enforceValid!"months"(cast(Month) month);
        enforceValid!"days"(year, cast(Month) month, day);

        _year  = cast(short) year;
        _month = cast(Month) month;
        _day   = cast(ubyte) day;
    }

    @safe unittest
    {
        import std.exception : assertNotThrown;
        assert(Date(1, 1, 1) == Date.init);

        static void testDate(in Date date, int year, int month, int day)
        {
            assert(date._year == year);
            assert(date._month == month);
            assert(date._day == day);
        }

        testDate(Date(1999, 1 , 1), 1999, Month.jan, 1);
        testDate(Date(1999, 7 , 1), 1999, Month.jul, 1);
        testDate(Date(1999, 7 , 6), 1999, Month.jul, 6);

        // Test A.D.
        assertThrown!DateTimeException(Date(1, 0, 1));
        assertThrown!DateTimeException(Date(1, 1, 0));
        assertThrown!DateTimeException(Date(1999, 13, 1));
        assertThrown!DateTimeException(Date(1999, 1, 32));
        assertThrown!DateTimeException(Date(1999, 2, 29));
        assertThrown!DateTimeException(Date(2000, 2, 30));
        assertThrown!DateTimeException(Date(1999, 3, 32));
        assertThrown!DateTimeException(Date(1999, 4, 31));
        assertThrown!DateTimeException(Date(1999, 5, 32));
        assertThrown!DateTimeException(Date(1999, 6, 31));
        assertThrown!DateTimeException(Date(1999, 7, 32));
        assertThrown!DateTimeException(Date(1999, 8, 32));
        assertThrown!DateTimeException(Date(1999, 9, 31));
        assertThrown!DateTimeException(Date(1999, 10, 32));
        assertThrown!DateTimeException(Date(1999, 11, 31));
        assertThrown!DateTimeException(Date(1999, 12, 32));

        assertNotThrown!DateTimeException(Date(1999, 1, 31));
        assertNotThrown!DateTimeException(Date(1999, 2, 28));
        assertNotThrown!DateTimeException(Date(2000, 2, 29));
        assertNotThrown!DateTimeException(Date(1999, 3, 31));
        assertNotThrown!DateTimeException(Date(1999, 4, 30));
        assertNotThrown!DateTimeException(Date(1999, 5, 31));
        assertNotThrown!DateTimeException(Date(1999, 6, 30));
        assertNotThrown!DateTimeException(Date(1999, 7, 31));
        assertNotThrown!DateTimeException(Date(1999, 8, 31));
        assertNotThrown!DateTimeException(Date(1999, 9, 30));
        assertNotThrown!DateTimeException(Date(1999, 10, 31));
        assertNotThrown!DateTimeException(Date(1999, 11, 30));
        assertNotThrown!DateTimeException(Date(1999, 12, 31));

        // Test B.C.
        assertNotThrown!DateTimeException(Date(0, 1, 1));
        assertNotThrown!DateTimeException(Date(-1, 1, 1));
        assertNotThrown!DateTimeException(Date(-1, 12, 31));
        assertNotThrown!DateTimeException(Date(-1, 2, 28));
        assertNotThrown!DateTimeException(Date(-4, 2, 29));

        assertThrown!DateTimeException(Date(-1, 2, 29));
        assertThrown!DateTimeException(Date(-2, 2, 29));
        assertThrown!DateTimeException(Date(-3, 2, 29));
    }


    /++
        Params:
            day = The Xth day of the Gregorian Calendar that the constructed
                  $(LREF Date) will be for.
     +/
    this(int day) @safe pure nothrow
    {
        if (day > 0)
        {
            int years = (day / daysIn400Years) * 400 + 1;
            day %= daysIn400Years;

            {
                immutable tempYears = day / daysIn100Years;

                if (tempYears == 4)
                {
                    years += 300;
                    day -= daysIn100Years * 3;
                }
                else
                {
                    years += tempYears * 100;
                    day %= daysIn100Years;
                }
            }

            years += (day / daysIn4Years) * 4;
            day %= daysIn4Years;

            {
                immutable tempYears = day / daysInYear;

                if (tempYears == 4)
                {
                    years += 3;
                    day -= daysInYear * 3;
                }
                else
                {
                    years += tempYears;
                    day %= daysInYear;
                }
            }

            if (day == 0)
            {
                _year = cast(short)(years - 1);
                _month = Month.dec;
                _day = 31;
            }
            else
            {
                _year = cast(short) years;

                try
                    dayOfYear = day;
                catch (Exception e)
                    assert(0, "dayOfYear assignment threw.");
            }
        }
        else if (day <= 0 && -day < daysInLeapYear)
        {
            _year = 0;

            try
                dayOfYear = (daysInLeapYear + day);
            catch (Exception e)
                assert(0, "dayOfYear assignment threw.");
        }
        else
        {
            day += daysInLeapYear - 1;
            int years = (day / daysIn400Years) * 400 - 1;
            day %= daysIn400Years;

            {
                immutable tempYears = day / daysIn100Years;

                if (tempYears == -4)
                {
                    years -= 300;
                    day += daysIn100Years * 3;
                }
                else
                {
                    years += tempYears * 100;
                    day %= daysIn100Years;
                }
            }

            years += (day / daysIn4Years) * 4;
            day %= daysIn4Years;

            {
                immutable tempYears = day / daysInYear;

                if (tempYears == -4)
                {
                    years -= 3;
                    day += daysInYear * 3;
                }
                else
                {
                    years += tempYears;
                    day %= daysInYear;
                }
            }

            if (day == 0)
            {
                _year = cast(short)(years + 1);
                _month = Month.jan;
                _day = 1;
            }
            else
            {
                _year = cast(short) years;
                immutable newDoY = (yearIsLeapYear(_year) ? daysInLeapYear : daysInYear) + day + 1;

                try
                    dayOfYear = newDoY;
                catch (Exception e)
                    assert(0, "dayOfYear assignment threw.");
            }
        }
    }

    @safe unittest
    {
        import std.range : chain;

        // Test A.D.
        foreach (gd; chain(testGregDaysBC, testGregDaysAD))
            assert(Date(gd.day) == gd.date);
    }


    /++
        Compares this $(LREF Date) with the given $(LREF Date).

        Returns:
            $(BOOKTABLE,
            $(TR $(TD this &lt; rhs) $(TD &lt; 0))
            $(TR $(TD this == rhs) $(TD 0))
            $(TR $(TD this &gt; rhs) $(TD &gt; 0))
            )
     +/
    int opCmp(in Date rhs) @safe const pure nothrow
    {
        if (_year < rhs._year)
            return -1;
        if (_year > rhs._year)
            return 1;

        if (_month < rhs._month)
            return -1;
        if (_month > rhs._month)
            return 1;

        if (_day < rhs._day)
            return -1;
        if (_day > rhs._day)
            return 1;

        return 0;
    }

    @safe unittest
    {
        // Test A.D.
        assert(Date(1, 1, 1).opCmp(Date.init) == 0);

        assert(Date(1999, 1, 1).opCmp(Date(1999, 1, 1)) == 0);
        assert(Date(1, 7, 1).opCmp(Date(1, 7, 1)) == 0);
        assert(Date(1, 1, 6).opCmp(Date(1, 1, 6)) == 0);

        assert(Date(1999, 7, 1).opCmp(Date(1999, 7, 1)) == 0);
        assert(Date(1999, 7, 6).opCmp(Date(1999, 7, 6)) == 0);

        assert(Date(1, 7, 6).opCmp(Date(1, 7, 6)) == 0);

        assert(Date(1999, 7, 6).opCmp(Date(2000, 7, 6)) < 0);
        assert(Date(2000, 7, 6).opCmp(Date(1999, 7, 6)) > 0);
        assert(Date(1999, 7, 6).opCmp(Date(1999, 8, 6)) < 0);
        assert(Date(1999, 8, 6).opCmp(Date(1999, 7, 6)) > 0);
        assert(Date(1999, 7, 6).opCmp(Date(1999, 7, 7)) < 0);
        assert(Date(1999, 7, 7).opCmp(Date(1999, 7, 6)) > 0);

        assert(Date(1999, 8, 7).opCmp(Date(2000, 7, 6)) < 0);
        assert(Date(2000, 8, 6).opCmp(Date(1999, 7, 7)) > 0);
        assert(Date(1999, 7, 7).opCmp(Date(2000, 7, 6)) < 0);
        assert(Date(2000, 7, 6).opCmp(Date(1999, 7, 7)) > 0);
        assert(Date(1999, 7, 7).opCmp(Date(1999, 8, 6)) < 0);
        assert(Date(1999, 8, 6).opCmp(Date(1999, 7, 7)) > 0);

        // Test B.C.
        assert(Date(0, 1, 1).opCmp(Date(0, 1, 1)) == 0);
        assert(Date(-1, 1, 1).opCmp(Date(-1, 1, 1)) == 0);
        assert(Date(-1, 7, 1).opCmp(Date(-1, 7, 1)) == 0);
        assert(Date(-1, 1, 6).opCmp(Date(-1, 1, 6)) == 0);

        assert(Date(-1999, 7, 1).opCmp(Date(-1999, 7, 1)) == 0);
        assert(Date(-1999, 7, 6).opCmp(Date(-1999, 7, 6)) == 0);

        assert(Date(-1, 7, 6).opCmp(Date(-1, 7, 6)) == 0);

        assert(Date(-2000, 7, 6).opCmp(Date(-1999, 7, 6)) < 0);
        assert(Date(-1999, 7, 6).opCmp(Date(-2000, 7, 6)) > 0);
        assert(Date(-1999, 7, 6).opCmp(Date(-1999, 8, 6)) < 0);
        assert(Date(-1999, 8, 6).opCmp(Date(-1999, 7, 6)) > 0);
        assert(Date(-1999, 7, 6).opCmp(Date(-1999, 7, 7)) < 0);
        assert(Date(-1999, 7, 7).opCmp(Date(-1999, 7, 6)) > 0);

        assert(Date(-2000, 8, 6).opCmp(Date(-1999, 7, 7)) < 0);
        assert(Date(-1999, 8, 7).opCmp(Date(-2000, 7, 6)) > 0);
        assert(Date(-2000, 7, 6).opCmp(Date(-1999, 7, 7)) < 0);
        assert(Date(-1999, 7, 7).opCmp(Date(-2000, 7, 6)) > 0);
        assert(Date(-1999, 7, 7).opCmp(Date(-1999, 8, 6)) < 0);
        assert(Date(-1999, 8, 6).opCmp(Date(-1999, 7, 7)) > 0);

        // Test Both
        assert(Date(-1999, 7, 6).opCmp(Date(1999, 7, 6)) < 0);
        assert(Date(1999, 7, 6).opCmp(Date(-1999, 7, 6)) > 0);

        assert(Date(-1999, 8, 6).opCmp(Date(1999, 7, 6)) < 0);
        assert(Date(1999, 7, 6).opCmp(Date(-1999, 8, 6)) > 0);

        assert(Date(-1999, 7, 7).opCmp(Date(1999, 7, 6)) < 0);
        assert(Date(1999, 7, 6).opCmp(Date(-1999, 7, 7)) > 0);

        assert(Date(-1999, 8, 7).opCmp(Date(1999, 7, 6)) < 0);
        assert(Date(1999, 7, 6).opCmp(Date(-1999, 8, 7)) > 0);

        assert(Date(-1999, 8, 6).opCmp(Date(1999, 6, 6)) < 0);
        assert(Date(1999, 6, 8).opCmp(Date(-1999, 7, 6)) > 0);

        auto date = Date(1999, 7, 6);
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(date.opCmp(date) == 0);
        assert(date.opCmp(cdate) == 0);
        assert(date.opCmp(idate) == 0);
        assert(cdate.opCmp(date) == 0);
        assert(cdate.opCmp(cdate) == 0);
        assert(cdate.opCmp(idate) == 0);
        assert(idate.opCmp(date) == 0);
        assert(idate.opCmp(cdate) == 0);
        assert(idate.opCmp(idate) == 0);
    }


    /++
        Year of the Gregorian Calendar. Positive numbers are A.D. Non-positive
        are B.C.
     +/
    @property short year() @safe const pure nothrow
    {
        return _year;
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 7, 6).year == 1999);
        assert(Date(2010, 10, 4).year == 2010);
        assert(Date(-7, 4, 5).year == -7);
    }

    @safe unittest
    {
        assert(Date.init.year == 1);
        assert(Date(1999, 7, 6).year == 1999);
        assert(Date(-1999, 7, 6).year == -1999);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.year == 1999);
        assert(idate.year == 1999);
    }

    /++
        Year of the Gregorian Calendar. Positive numbers are A.D. Non-positive
        are B.C.

        Params:
            year = The year to set this Date's year to.

        Throws:
            $(REF std,datetime,common,DateTimeException) if the new year is not
            a leap year and the resulting date would be on February 29th.
     +/
    @property void year(int year) @safe pure
    {
        enforceValid!"days"(year, _month, _day);
        _year = cast(short) year;
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 7, 6).year == 1999);
        assert(Date(2010, 10, 4).year == 2010);
        assert(Date(-7, 4, 5).year == -7);
    }

    @safe unittest
    {
        static void testDateInvalid(Date date, int year)
        {
            date.year = year;
        }

        static void testDate(Date date, int year, in Date expected)
        {
            date.year = year;
            assert(date == expected);
        }

        assertThrown!DateTimeException(testDateInvalid(Date(4, 2, 29), 1));

        testDate(Date(1, 1, 1), 1999, Date(1999, 1, 1));
        testDate(Date(1, 1, 1), 0, Date(0, 1, 1));
        testDate(Date(1, 1, 1), -1999, Date(-1999, 1, 1));

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.year = 1999));
        static assert(!__traits(compiles, idate.year = 1999));
    }


    /++
        Year B.C. of the Gregorian Calendar counting year 0 as 1 B.C.

        Throws:
            $(REF std,datetime,common,DateTimeException) if $(D isAD) is true.
     +/
    @property ushort yearBC() @safe const pure
    {
        import std.format : format;

        if (isAD)
            throw new DateTimeException(format("Year %s is A.D.", _year));
        return cast(ushort)((_year * -1) + 1);
    }

    ///
    @safe unittest
    {
        assert(Date(0, 1, 1).yearBC == 1);
        assert(Date(-1, 1, 1).yearBC == 2);
        assert(Date(-100, 1, 1).yearBC == 101);
    }

    @safe unittest
    {
        assertThrown!DateTimeException((in Date date){date.yearBC;}(Date(1, 1, 1)));

        auto date = Date(0, 7, 6);
        const cdate = Date(0, 7, 6);
        immutable idate = Date(0, 7, 6);
        assert(date.yearBC == 1);
        assert(cdate.yearBC == 1);
        assert(idate.yearBC == 1);
    }


    /++
        Year B.C. of the Gregorian Calendar counting year 0 as 1 B.C.

        Params:
            year = The year B.C. to set this $(LREF Date)'s year to.

        Throws:
            $(REF std,datetime,common,DateTimeException) if a non-positive value
            is given.
     +/
    @property void yearBC(int year) @safe pure
    {
        if (year <= 0)
            throw new DateTimeException("The given year is not a year B.C.");
        _year = cast(short)((year - 1) * -1);
    }

    ///
    @safe unittest
    {
        auto date = Date(2010, 1, 1);
        date.yearBC = 1;
        assert(date == Date(0, 1, 1));

        date.yearBC = 10;
        assert(date == Date(-9, 1, 1));
    }

    @safe unittest
    {
        assertThrown!DateTimeException((Date date){date.yearBC = -1;}(Date(1, 1, 1)));

        auto date = Date(0, 7, 6);
        const cdate = Date(0, 7, 6);
        immutable idate = Date(0, 7, 6);
        date.yearBC = 7;
        assert(date.yearBC == 7);
        static assert(!__traits(compiles, cdate.yearBC = 7));
        static assert(!__traits(compiles, idate.yearBC = 7));
    }


    /++
        Month of a Gregorian Year.
     +/
    @property Month month() @safe const pure nothrow
    {
        return _month;
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 7, 6).month == 7);
        assert(Date(2010, 10, 4).month == 10);
        assert(Date(-7, 4, 5).month == 4);
    }

    @safe unittest
    {
        assert(Date.init.month == 1);
        assert(Date(1999, 7, 6).month == 7);
        assert(Date(-1999, 7, 6).month == 7);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.month == 7);
        assert(idate.month == 7);
    }

    /++
        Month of a Gregorian Year.

        Params:
            month = The month to set this $(LREF Date)'s month to.

        Throws:
            $(REF std,datetime,common,DateTimeException) if the given month is
            not a valid month or if the current day would not be valid in the
            given month.
     +/
    @property void month(Month month) @safe pure
    {
        enforceValid!"months"(month);
        enforceValid!"days"(_year, month, _day);
        _month = cast(Month) month;
    }

    @safe unittest
    {
        static void testDate(Date date, Month month, in Date expected = Date.init)
        {
            date.month = month;
            assert(expected != Date.init);
            assert(date == expected);
        }

        assertThrown!DateTimeException(testDate(Date(1, 1, 1), cast(Month) 0));
        assertThrown!DateTimeException(testDate(Date(1, 1, 1), cast(Month) 13));
        assertThrown!DateTimeException(testDate(Date(1, 1, 29), cast(Month) 2));
        assertThrown!DateTimeException(testDate(Date(0, 1, 30), cast(Month) 2));

        testDate(Date(1, 1, 1), cast(Month) 7, Date(1, 7, 1));
        testDate(Date(-1, 1, 1), cast(Month) 7, Date(-1, 7, 1));

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.month = 7));
        static assert(!__traits(compiles, idate.month = 7));
    }


    /++
        Day of a Gregorian Month.
     +/
    @property ubyte day() @safe const pure nothrow
    {
        return _day;
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 7, 6).day == 6);
        assert(Date(2010, 10, 4).day == 4);
        assert(Date(-7, 4, 5).day == 5);
    }

    @safe unittest
    {
        import std.format : format;
        import std.range : chain;

        static void test(Date date, int expected)
        {
            assert(date.day == expected, format("Value given: %s", date));
        }

        foreach (year; chain(testYearsBC, testYearsAD))
        {
            foreach (md; testMonthDays)
                test(Date(year, md.month, md.day), md.day);
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.day == 6);
        assert(idate.day == 6);
    }

    /++
        Day of a Gregorian Month.

        Params:
            day = The day of the month to set this $(LREF Date)'s day to.

        Throws:
            $(REF std,datetime,common,DateTimeException) if the given day is not
            a valid day of the current month.
     +/
    @property void day(int day) @safe pure
    {
        enforceValid!"days"(_year, _month, day);
        _day = cast(ubyte) day;
    }

    @safe unittest
    {
        import std.exception : assertNotThrown;

        static void testDate(Date date, int day)
        {
            date.day = day;
        }

        // Test A.D.
        assertThrown!DateTimeException(testDate(Date(1, 1, 1), 0));
        assertThrown!DateTimeException(testDate(Date(1, 1, 1), 32));
        assertThrown!DateTimeException(testDate(Date(1, 2, 1), 29));
        assertThrown!DateTimeException(testDate(Date(4, 2, 1), 30));
        assertThrown!DateTimeException(testDate(Date(1, 3, 1), 32));
        assertThrown!DateTimeException(testDate(Date(1, 4, 1), 31));
        assertThrown!DateTimeException(testDate(Date(1, 5, 1), 32));
        assertThrown!DateTimeException(testDate(Date(1, 6, 1), 31));
        assertThrown!DateTimeException(testDate(Date(1, 7, 1), 32));
        assertThrown!DateTimeException(testDate(Date(1, 8, 1), 32));
        assertThrown!DateTimeException(testDate(Date(1, 9, 1), 31));
        assertThrown!DateTimeException(testDate(Date(1, 10, 1), 32));
        assertThrown!DateTimeException(testDate(Date(1, 11, 1), 31));
        assertThrown!DateTimeException(testDate(Date(1, 12, 1), 32));

        assertNotThrown!DateTimeException(testDate(Date(1, 1, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(1, 2, 1), 28));
        assertNotThrown!DateTimeException(testDate(Date(4, 2, 1), 29));
        assertNotThrown!DateTimeException(testDate(Date(1, 3, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(1, 4, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(1, 5, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(1, 6, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(1, 7, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(1, 8, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(1, 9, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(1, 10, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(1, 11, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(1, 12, 1), 31));

        {
            auto date = Date(1, 1, 1);
            date.day = 6;
            assert(date == Date(1, 1, 6));
        }

        // Test B.C.
        assertThrown!DateTimeException(testDate(Date(-1, 1, 1), 0));
        assertThrown!DateTimeException(testDate(Date(-1, 1, 1), 32));
        assertThrown!DateTimeException(testDate(Date(-1, 2, 1), 29));
        assertThrown!DateTimeException(testDate(Date(0, 2, 1), 30));
        assertThrown!DateTimeException(testDate(Date(-1, 3, 1), 32));
        assertThrown!DateTimeException(testDate(Date(-1, 4, 1), 31));
        assertThrown!DateTimeException(testDate(Date(-1, 5, 1), 32));
        assertThrown!DateTimeException(testDate(Date(-1, 6, 1), 31));
        assertThrown!DateTimeException(testDate(Date(-1, 7, 1), 32));
        assertThrown!DateTimeException(testDate(Date(-1, 8, 1), 32));
        assertThrown!DateTimeException(testDate(Date(-1, 9, 1), 31));
        assertThrown!DateTimeException(testDate(Date(-1, 10, 1), 32));
        assertThrown!DateTimeException(testDate(Date(-1, 11, 1), 31));
        assertThrown!DateTimeException(testDate(Date(-1, 12, 1), 32));

        assertNotThrown!DateTimeException(testDate(Date(-1, 1, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(-1, 2, 1), 28));
        assertNotThrown!DateTimeException(testDate(Date(0, 2, 1), 29));
        assertNotThrown!DateTimeException(testDate(Date(-1, 3, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(-1, 4, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(-1, 5, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(-1, 6, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(-1, 7, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(-1, 8, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(-1, 9, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(-1, 10, 1), 31));
        assertNotThrown!DateTimeException(testDate(Date(-1, 11, 1), 30));
        assertNotThrown!DateTimeException(testDate(Date(-1, 12, 1), 31));

        {
            auto date = Date(-1, 1, 1);
            date.day = 6;
            assert(date == Date(-1, 1, 6));
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.day = 6));
        static assert(!__traits(compiles, idate.day = 6));
    }


    /++
        Adds the given number of years or months to this $(LREF Date). A
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
                            $(LREF Date).
            allowOverflow = Whether the day should be allowed to overflow,
                            causing the month to increment.
      +/
    ref Date add(string units)(long value, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe pure nothrow
        if (units == "years")
    {
        _year += value;

        if (_month == Month.feb && _day == 29 && !yearIsLeapYear(_year))
        {
            if (allowOverflow == AllowDayOverflow.yes)
            {
                _month = Month.mar;
                _day = 1;
            }
            else
                _day = 28;
        }

        return this;
    }

    ///
    @safe unittest
    {
        import std.datetime.common : AllowDayOverflow;

        auto d1 = Date(2010, 1, 1);
        d1.add!"months"(11);
        assert(d1 == Date(2010, 12, 1));

        auto d2 = Date(2010, 1, 1);
        d2.add!"months"(-11);
        assert(d2 == Date(2009, 2, 1));

        auto d3 = Date(2000, 2, 29);
        d3.add!"years"(1);
        assert(d3 == Date(2001, 3, 1));

        auto d4 = Date(2000, 2, 29);
        d4.add!"years"(1, AllowDayOverflow.no);
        assert(d4 == Date(2001, 2, 28));
    }

    // Test add!"years"() with AllowDayOverflow.yes
    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 7, 6);
            date.add!"years"(7);
            assert(date == Date(2006, 7, 6));
            date.add!"years"(-9);
            assert(date == Date(1997, 7, 6));
        }

        {
            auto date = Date(1999, 2, 28);
            date.add!"years"(1);
            assert(date == Date(2000, 2, 28));
        }

        {
            auto date = Date(2000, 2, 29);
            date.add!"years"(-1);
            assert(date == Date(1999, 3, 1));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 7, 6);
            date.add!"years"(-7);
            assert(date == Date(-2006, 7, 6));
            date.add!"years"(9);
            assert(date == Date(-1997, 7, 6));
        }

        {
            auto date = Date(-1999, 2, 28);
            date.add!"years"(-1);
            assert(date == Date(-2000, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 29);
            date.add!"years"(1);
            assert(date == Date(-1999, 3, 1));
        }

        // Test Both
        {
            auto date = Date(4, 7, 6);
            date.add!"years"(-5);
            assert(date == Date(-1, 7, 6));
            date.add!"years"(5);
            assert(date == Date(4, 7, 6));
        }

        {
            auto date = Date(-4, 7, 6);
            date.add!"years"(5);
            assert(date == Date(1, 7, 6));
            date.add!"years"(-5);
            assert(date == Date(-4, 7, 6));
        }

        {
            auto date = Date(4, 7, 6);
            date.add!"years"(-8);
            assert(date == Date(-4, 7, 6));
            date.add!"years"(8);
            assert(date == Date(4, 7, 6));
        }

        {
            auto date = Date(-4, 7, 6);
            date.add!"years"(8);
            assert(date == Date(4, 7, 6));
            date.add!"years"(-8);
            assert(date == Date(-4, 7, 6));
        }

        {
            auto date = Date(-4, 2, 29);
            date.add!"years"(5);
            assert(date == Date(1, 3, 1));
        }

        {
            auto date = Date(4, 2, 29);
            date.add!"years"(-5);
            assert(date == Date(-1, 3, 1));
        }

        {
            auto date = Date(4, 2, 29);
            date.add!"years"(-5).add!"years"(7);
            assert(date == Date(6, 3, 1));
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.add!"years"(7)));
        static assert(!__traits(compiles, idate.add!"years"(7)));
    }

    // Test add!"years"() with AllowDayOverflow.no
    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 7, 6);
            date.add!"years"(7, AllowDayOverflow.no);
            assert(date == Date(2006, 7, 6));
            date.add!"years"(-9, AllowDayOverflow.no);
            assert(date == Date(1997, 7, 6));
        }

        {
            auto date = Date(1999, 2, 28);
            date.add!"years"(1, AllowDayOverflow.no);
            assert(date == Date(2000, 2, 28));
        }

        {
            auto date = Date(2000, 2, 29);
            date.add!"years"(-1, AllowDayOverflow.no);
            assert(date == Date(1999, 2, 28));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 7, 6);
            date.add!"years"(-7, AllowDayOverflow.no);
            assert(date == Date(-2006, 7, 6));
            date.add!"years"(9, AllowDayOverflow.no);
            assert(date == Date(-1997, 7, 6));
        }

        {
            auto date = Date(-1999, 2, 28);
            date.add!"years"(-1, AllowDayOverflow.no);
            assert(date == Date(-2000, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 29);
            date.add!"years"(1, AllowDayOverflow.no);
            assert(date == Date(-1999, 2, 28));
        }

        // Test Both
        {
            auto date = Date(4, 7, 6);
            date.add!"years"(-5, AllowDayOverflow.no);
            assert(date == Date(-1, 7, 6));
            date.add!"years"(5, AllowDayOverflow.no);
            assert(date == Date(4, 7, 6));
        }

        {
            auto date = Date(-4, 7, 6);
            date.add!"years"(5, AllowDayOverflow.no);
            assert(date == Date(1, 7, 6));
            date.add!"years"(-5, AllowDayOverflow.no);
            assert(date == Date(-4, 7, 6));
        }

        {
            auto date = Date(4, 7, 6);
            date.add!"years"(-8, AllowDayOverflow.no);
            assert(date == Date(-4, 7, 6));
            date.add!"years"(8, AllowDayOverflow.no);
            assert(date == Date(4, 7, 6));
        }

        {
            auto date = Date(-4, 7, 6);
            date.add!"years"(8, AllowDayOverflow.no);
            assert(date == Date(4, 7, 6));
            date.add!"years"(-8, AllowDayOverflow.no);
            assert(date == Date(-4, 7, 6));
        }

        {
            auto date = Date(-4, 2, 29);
            date.add!"years"(5, AllowDayOverflow.no);
            assert(date == Date(1, 2, 28));
        }

        {
            auto date = Date(4, 2, 29);
            date.add!"years"(-5, AllowDayOverflow.no);
            assert(date == Date(-1, 2, 28));
        }

        {
            auto date = Date(4, 2, 29);
            date.add!"years"(-5, AllowDayOverflow.no).add!"years"(7, AllowDayOverflow.no);
            assert(date == Date(6, 2, 28));
        }
    }


    // Shares documentation with "years" version.
    ref Date add(string units)(long months, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe pure nothrow
        if (units == "months")
    {
        auto years = months / 12;
        months %= 12;
        auto newMonth = _month + months;

        if (months < 0)
        {
            if (newMonth < 1)
            {
                newMonth += 12;
                --years;
            }
        }
        else if (newMonth > 12)
        {
            newMonth -= 12;
            ++years;
        }

        _year += years;
        _month = cast(Month) newMonth;

        immutable currMaxDay = maxDay(_year, _month);
        immutable overflow = _day - currMaxDay;

        if (overflow > 0)
        {
            if (allowOverflow == AllowDayOverflow.yes)
            {
                ++_month;
                _day = cast(ubyte) overflow;
            }
            else
                _day = cast(ubyte) currMaxDay;
        }

        return this;
    }

    // Test add!"months"() with AllowDayOverflow.yes
    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 7, 6);
            date.add!"months"(3);
            assert(date == Date(1999, 10, 6));
            date.add!"months"(-4);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.add!"months"(6);
            assert(date == Date(2000, 1, 6));
            date.add!"months"(-6);
            assert(date == Date(1999, 7, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.add!"months"(27);
            assert(date == Date(2001, 10, 6));
            date.add!"months"(-28);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 5, 31);
            date.add!"months"(1);
            assert(date == Date(1999, 7, 1));
        }

        {
            auto date = Date(1999, 5, 31);
            date.add!"months"(-1);
            assert(date == Date(1999, 5, 1));
        }

        {
            auto date = Date(1999, 2, 28);
            date.add!"months"(12);
            assert(date == Date(2000, 2, 28));
        }

        {
            auto date = Date(2000, 2, 29);
            date.add!"months"(12);
            assert(date == Date(2001, 3, 1));
        }

        {
            auto date = Date(1999, 7, 31);
            date.add!"months"(1);
            assert(date == Date(1999, 8, 31));
            date.add!"months"(1);
            assert(date == Date(1999, 10, 1));
        }

        {
            auto date = Date(1998, 8, 31);
            date.add!"months"(13);
            assert(date == Date(1999, 10, 1));
            date.add!"months"(-13);
            assert(date == Date(1998, 9, 1));
        }

        {
            auto date = Date(1997, 12, 31);
            date.add!"months"(13);
            assert(date == Date(1999, 1, 31));
            date.add!"months"(-13);
            assert(date == Date(1997, 12, 31));
        }

        {
            auto date = Date(1997, 12, 31);
            date.add!"months"(14);
            assert(date == Date(1999, 3, 3));
            date.add!"months"(-14);
            assert(date == Date(1998, 1, 3));
        }

        {
            auto date = Date(1998, 12, 31);
            date.add!"months"(14);
            assert(date == Date(2000, 3, 2));
            date.add!"months"(-14);
            assert(date == Date(1999, 1, 2));
        }

        {
            auto date = Date(1999, 12, 31);
            date.add!"months"(14);
            assert(date == Date(2001, 3, 3));
            date.add!"months"(-14);
            assert(date == Date(2000, 1, 3));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 7, 6);
            date.add!"months"(3);
            assert(date == Date(-1999, 10, 6));
            date.add!"months"(-4);
            assert(date == Date(-1999, 6, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.add!"months"(6);
            assert(date == Date(-1998, 1, 6));
            date.add!"months"(-6);
            assert(date == Date(-1999, 7, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.add!"months"(-27);
            assert(date == Date(-2001, 4, 6));
            date.add!"months"(28);
            assert(date == Date(-1999, 8, 6));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.add!"months"(1);
            assert(date == Date(-1999, 7, 1));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.add!"months"(-1);
            assert(date == Date(-1999, 5, 1));
        }

        {
            auto date = Date(-1999, 2, 28);
            date.add!"months"(-12);
            assert(date == Date(-2000, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 29);
            date.add!"months"(-12);
            assert(date == Date(-2001, 3, 1));
        }

        {
            auto date = Date(-1999, 7, 31);
            date.add!"months"(1);
            assert(date == Date(-1999, 8, 31));
            date.add!"months"(1);
            assert(date == Date(-1999, 10, 1));
        }

        {
            auto date = Date(-1998, 8, 31);
            date.add!"months"(13);
            assert(date == Date(-1997, 10, 1));
            date.add!"months"(-13);
            assert(date == Date(-1998, 9, 1));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.add!"months"(13);
            assert(date == Date(-1995, 1, 31));
            date.add!"months"(-13);
            assert(date == Date(-1997, 12, 31));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.add!"months"(14);
            assert(date == Date(-1995, 3, 3));
            date.add!"months"(-14);
            assert(date == Date(-1996, 1, 3));
        }

        {
            auto date = Date(-2002, 12, 31);
            date.add!"months"(14);
            assert(date == Date(-2000, 3, 2));
            date.add!"months"(-14);
            assert(date == Date(-2001, 1, 2));
        }

        {
            auto date = Date(-2001, 12, 31);
            date.add!"months"(14);
            assert(date == Date(-1999, 3, 3));
            date.add!"months"(-14);
            assert(date == Date(-2000, 1, 3));
        }

        // Test Both
        {
            auto date = Date(1, 1, 1);
            date.add!"months"(-1);
            assert(date == Date(0, 12, 1));
            date.add!"months"(1);
            assert(date == Date(1, 1, 1));
        }

        {
            auto date = Date(4, 1, 1);
            date.add!"months"(-48);
            assert(date == Date(0, 1, 1));
            date.add!"months"(48);
            assert(date == Date(4, 1, 1));
        }

        {
            auto date = Date(4, 3, 31);
            date.add!"months"(-49);
            assert(date == Date(0, 3, 2));
            date.add!"months"(49);
            assert(date == Date(4, 4, 2));
        }

        {
            auto date = Date(4, 3, 31);
            date.add!"months"(-85);
            assert(date == Date(-3, 3, 3));
            date.add!"months"(85);
            assert(date == Date(4, 4, 3));
        }

        {
            auto date = Date(-3, 3, 31);
            date.add!"months"(85).add!"months"(-83);
            assert(date == Date(-3, 6, 1));
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.add!"months"(3)));
        static assert(!__traits(compiles, idate.add!"months"(3)));
    }

    // Test add!"months"() with AllowDayOverflow.no
    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 7, 6);
            date.add!"months"(3, AllowDayOverflow.no);
            assert(date == Date(1999, 10, 6));
            date.add!"months"(-4, AllowDayOverflow.no);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.add!"months"(6, AllowDayOverflow.no);
            assert(date == Date(2000, 1, 6));
            date.add!"months"(-6, AllowDayOverflow.no);
            assert(date == Date(1999, 7, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.add!"months"(27, AllowDayOverflow.no);
            assert(date == Date(2001, 10, 6));
            date.add!"months"(-28, AllowDayOverflow.no);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 5, 31);
            date.add!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1999, 6, 30));
        }

        {
            auto date = Date(1999, 5, 31);
            date.add!"months"(-1, AllowDayOverflow.no);
            assert(date == Date(1999, 4, 30));
        }

        {
            auto date = Date(1999, 2, 28);
            date.add!"months"(12, AllowDayOverflow.no);
            assert(date == Date(2000, 2, 28));
        }

        {
            auto date = Date(2000, 2, 29);
            date.add!"months"(12, AllowDayOverflow.no);
            assert(date == Date(2001, 2, 28));
        }

        {
            auto date = Date(1999, 7, 31);
            date.add!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1999, 8, 31));
            date.add!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1999, 9, 30));
        }

        {
            auto date = Date(1998, 8, 31);
            date.add!"months"(13, AllowDayOverflow.no);
            assert(date == Date(1999, 9, 30));
            date.add!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(1998, 8, 30));
        }

        {
            auto date = Date(1997, 12, 31);
            date.add!"months"(13, AllowDayOverflow.no);
            assert(date == Date(1999, 1, 31));
            date.add!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(1997, 12, 31));
        }

        {
            auto date = Date(1997, 12, 31);
            date.add!"months"(14, AllowDayOverflow.no);
            assert(date == Date(1999, 2, 28));
            date.add!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(1997, 12, 28));
        }

        {
            auto date = Date(1998, 12, 31);
            date.add!"months"(14, AllowDayOverflow.no);
            assert(date == Date(2000, 2, 29));
            date.add!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(1998, 12, 29));
        }

        {
            auto date = Date(1999, 12, 31);
            date.add!"months"(14, AllowDayOverflow.no);
            assert(date == Date(2001, 2, 28));
            date.add!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(1999, 12, 28));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 7, 6);
            date.add!"months"(3, AllowDayOverflow.no);
            assert(date == Date(-1999, 10, 6));
            date.add!"months"(-4, AllowDayOverflow.no);
            assert(date == Date(-1999, 6, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.add!"months"(6, AllowDayOverflow.no);
            assert(date == Date(-1998, 1, 6));
            date.add!"months"(-6, AllowDayOverflow.no);
            assert(date == Date(-1999, 7, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.add!"months"(-27, AllowDayOverflow.no);
            assert(date == Date(-2001, 4, 6));
            date.add!"months"(28, AllowDayOverflow.no);
            assert(date == Date(-1999, 8, 6));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.add!"months"(1, AllowDayOverflow.no);
            assert(date == Date(-1999, 6, 30));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.add!"months"(-1, AllowDayOverflow.no);
            assert(date == Date(-1999, 4, 30));
        }

        {
            auto date = Date(-1999, 2, 28);
            date.add!"months"(-12, AllowDayOverflow.no);
            assert(date == Date(-2000, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 29);
            date.add!"months"(-12, AllowDayOverflow.no);
            assert(date == Date(-2001, 2, 28));
        }

        {
            auto date = Date(-1999, 7, 31);
            date.add!"months"(1, AllowDayOverflow.no);
            assert(date == Date(-1999, 8, 31));
            date.add!"months"(1, AllowDayOverflow.no);
            assert(date == Date(-1999, 9, 30));
        }

        {
            auto date = Date(-1998, 8, 31);
            date.add!"months"(13, AllowDayOverflow.no);
            assert(date == Date(-1997, 9, 30));
            date.add!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(-1998, 8, 30));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.add!"months"(13, AllowDayOverflow.no);
            assert(date == Date(-1995, 1, 31));
            date.add!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(-1997, 12, 31));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.add!"months"(14, AllowDayOverflow.no);
            assert(date == Date(-1995, 2, 28));
            date.add!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(-1997, 12, 28));
        }

        {
            auto date = Date(-2002, 12, 31);
            date.add!"months"(14, AllowDayOverflow.no);
            assert(date == Date(-2000, 2, 29));
            date.add!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(-2002, 12, 29));
        }

        {
            auto date = Date(-2001, 12, 31);
            date.add!"months"(14, AllowDayOverflow.no);
            assert(date == Date(-1999, 2, 28));
            date.add!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(-2001, 12, 28));
        }

        // Test Both
        {
            auto date = Date(1, 1, 1);
            date.add!"months"(-1, AllowDayOverflow.no);
            assert(date == Date(0, 12, 1));
            date.add!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1, 1, 1));
        }

        {
            auto date = Date(4, 1, 1);
            date.add!"months"(-48, AllowDayOverflow.no);
            assert(date == Date(0, 1, 1));
            date.add!"months"(48, AllowDayOverflow.no);
            assert(date == Date(4, 1, 1));
        }

        {
            auto date = Date(4, 3, 31);
            date.add!"months"(-49, AllowDayOverflow.no);
            assert(date == Date(0, 2, 29));
            date.add!"months"(49, AllowDayOverflow.no);
            assert(date == Date(4, 3, 29));
        }

        {
            auto date = Date(4, 3, 31);
            date.add!"months"(-85, AllowDayOverflow.no);
            assert(date == Date(-3, 2, 28));
            date.add!"months"(85, AllowDayOverflow.no);
            assert(date == Date(4, 3, 28));
        }

        {
            auto date = Date(-3, 3, 31);
            date.add!"months"(85, AllowDayOverflow.no).add!"months"(-83, AllowDayOverflow.no);
            assert(date == Date(-3, 5, 30));
        }
    }


    /++
        Adds the given number of years or months to this $(LREF Date). A negative
        number will subtract.

        The difference between rolling and adding is that rolling does not
        affect larger units. Rolling a $(LREF Date) 12 months gets
        the exact same $(LREF Date). However, the days can still be affected due
        to the differing number of days in each month.

        Because there are no units larger than years, there is no difference
        between adding and rolling years.

        Params:
            units         = The type of units to add ("years" or "months").
            value         = The number of months or years to add to this
                            $(LREF Date).
            allowOverflow = Whether the day should be allowed to overflow,
                            causing the month to increment.
      +/
    ref Date roll(string units)(long value, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe pure nothrow
        if (units == "years")
    {
        return add!"years"(value, allowOverflow);
    }

    ///
    @safe unittest
    {
        import std.datetime.common : AllowDayOverflow;

        auto d1 = Date(2010, 1, 1);
        d1.roll!"months"(1);
        assert(d1 == Date(2010, 2, 1));

        auto d2 = Date(2010, 1, 1);
        d2.roll!"months"(-1);
        assert(d2 == Date(2010, 12, 1));

        auto d3 = Date(1999, 1, 29);
        d3.roll!"months"(1);
        assert(d3 == Date(1999, 3, 1));

        auto d4 = Date(1999, 1, 29);
        d4.roll!"months"(1, AllowDayOverflow.no);
        assert(d4 == Date(1999, 2, 28));

        auto d5 = Date(2000, 2, 29);
        d5.roll!"years"(1);
        assert(d5 == Date(2001, 3, 1));

        auto d6 = Date(2000, 2, 29);
        d6.roll!"years"(1, AllowDayOverflow.no);
        assert(d6 == Date(2001, 2, 28));
    }

    @safe unittest
    {
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.roll!"years"(3)));
        static assert(!__traits(compiles, idate.rolYears(3)));
    }


    // Shares documentation with "years" version.
    ref Date roll(string units)(long months, AllowDayOverflow allowOverflow = AllowDayOverflow.yes) @safe pure nothrow
        if (units == "months")
    {
        months %= 12;
        auto newMonth = _month + months;

        if (months < 0)
        {
            if (newMonth < 1)
                newMonth += 12;
        }
        else
        {
            if (newMonth > 12)
                newMonth -= 12;
        }

        _month = cast(Month) newMonth;

        immutable currMaxDay = maxDay(_year, _month);
        immutable overflow = _day - currMaxDay;

        if (overflow > 0)
        {
            if (allowOverflow == AllowDayOverflow.yes)
            {
                ++_month;
                _day = cast(ubyte) overflow;
            }
            else
                _day = cast(ubyte) currMaxDay;
        }

        return this;
    }

    // Test roll!"months"() with AllowDayOverflow.yes
    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 7, 6);
            date.roll!"months"(3);
            assert(date == Date(1999, 10, 6));
            date.roll!"months"(-4);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.roll!"months"(6);
            assert(date == Date(1999, 1, 6));
            date.roll!"months"(-6);
            assert(date == Date(1999, 7, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.roll!"months"(27);
            assert(date == Date(1999, 10, 6));
            date.roll!"months"(-28);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 5, 31);
            date.roll!"months"(1);
            assert(date == Date(1999, 7, 1));
        }

        {
            auto date = Date(1999, 5, 31);
            date.roll!"months"(-1);
            assert(date == Date(1999, 5, 1));
        }

        {
            auto date = Date(1999, 2, 28);
            date.roll!"months"(12);
            assert(date == Date(1999, 2, 28));
        }

        {
            auto date = Date(2000, 2, 29);
            date.roll!"months"(12);
            assert(date == Date(2000, 2, 29));
        }

        {
            auto date = Date(1999, 7, 31);
            date.roll!"months"(1);
            assert(date == Date(1999, 8, 31));
            date.roll!"months"(1);
            assert(date == Date(1999, 10, 1));
        }

        {
            auto date = Date(1998, 8, 31);
            date.roll!"months"(13);
            assert(date == Date(1998, 10, 1));
            date.roll!"months"(-13);
            assert(date == Date(1998, 9, 1));
        }

        {
            auto date = Date(1997, 12, 31);
            date.roll!"months"(13);
            assert(date == Date(1997, 1, 31));
            date.roll!"months"(-13);
            assert(date == Date(1997, 12, 31));
        }

        {
            auto date = Date(1997, 12, 31);
            date.roll!"months"(14);
            assert(date == Date(1997, 3, 3));
            date.roll!"months"(-14);
            assert(date == Date(1997, 1, 3));
        }

        {
            auto date = Date(1998, 12, 31);
            date.roll!"months"(14);
            assert(date == Date(1998, 3, 3));
            date.roll!"months"(-14);
            assert(date == Date(1998, 1, 3));
        }

        {
            auto date = Date(1999, 12, 31);
            date.roll!"months"(14);
            assert(date == Date(1999, 3, 3));
            date.roll!"months"(-14);
            assert(date == Date(1999, 1, 3));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 7, 6);
            date.roll!"months"(3);
            assert(date == Date(-1999, 10, 6));
            date.roll!"months"(-4);
            assert(date == Date(-1999, 6, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.roll!"months"(6);
            assert(date == Date(-1999, 1, 6));
            date.roll!"months"(-6);
            assert(date == Date(-1999, 7, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.roll!"months"(-27);
            assert(date == Date(-1999, 4, 6));
            date.roll!"months"(28);
            assert(date == Date(-1999, 8, 6));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.roll!"months"(1);
            assert(date == Date(-1999, 7, 1));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.roll!"months"(-1);
            assert(date == Date(-1999, 5, 1));
        }

        {
            auto date = Date(-1999, 2, 28);
            date.roll!"months"(-12);
            assert(date == Date(-1999, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 29);
            date.roll!"months"(-12);
            assert(date == Date(-2000, 2, 29));
        }

        {
            auto date = Date(-1999, 7, 31);
            date.roll!"months"(1);
            assert(date == Date(-1999, 8, 31));
            date.roll!"months"(1);
            assert(date == Date(-1999, 10, 1));
        }

        {
            auto date = Date(-1998, 8, 31);
            date.roll!"months"(13);
            assert(date == Date(-1998, 10, 1));
            date.roll!"months"(-13);
            assert(date == Date(-1998, 9, 1));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.roll!"months"(13);
            assert(date == Date(-1997, 1, 31));
            date.roll!"months"(-13);
            assert(date == Date(-1997, 12, 31));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.roll!"months"(14);
            assert(date == Date(-1997, 3, 3));
            date.roll!"months"(-14);
            assert(date == Date(-1997, 1, 3));
        }

        {
            auto date = Date(-2002, 12, 31);
            date.roll!"months"(14);
            assert(date == Date(-2002, 3, 3));
            date.roll!"months"(-14);
            assert(date == Date(-2002, 1, 3));
        }

        {
            auto date = Date(-2001, 12, 31);
            date.roll!"months"(14);
            assert(date == Date(-2001, 3, 3));
            date.roll!"months"(-14);
            assert(date == Date(-2001, 1, 3));
        }

        // Test Both
        {
            auto date = Date(1, 1, 1);
            date.roll!"months"(-1);
            assert(date == Date(1, 12, 1));
            date.roll!"months"(1);
            assert(date == Date(1, 1, 1));
        }

        {
            auto date = Date(4, 1, 1);
            date.roll!"months"(-48);
            assert(date == Date(4, 1, 1));
            date.roll!"months"(48);
            assert(date == Date(4, 1, 1));
        }

        {
            auto date = Date(4, 3, 31);
            date.roll!"months"(-49);
            assert(date == Date(4, 3, 2));
            date.roll!"months"(49);
            assert(date == Date(4, 4, 2));
        }

        {
            auto date = Date(4, 3, 31);
            date.roll!"months"(-85);
            assert(date == Date(4, 3, 2));
            date.roll!"months"(85);
            assert(date == Date(4, 4, 2));
        }

        {
            auto date = Date(-1, 1, 1);
            date.roll!"months"(-1);
            assert(date == Date(-1, 12, 1));
            date.roll!"months"(1);
            assert(date == Date(-1, 1, 1));
        }

        {
            auto date = Date(-4, 1, 1);
            date.roll!"months"(-48);
            assert(date == Date(-4, 1, 1));
            date.roll!"months"(48);
            assert(date == Date(-4, 1, 1));
        }

        {
            auto date = Date(-4, 3, 31);
            date.roll!"months"(-49);
            assert(date == Date(-4, 3, 2));
            date.roll!"months"(49);
            assert(date == Date(-4, 4, 2));
        }

        {
            auto date = Date(-4, 3, 31);
            date.roll!"months"(-85);
            assert(date == Date(-4, 3, 2));
            date.roll!"months"(85);
            assert(date == Date(-4, 4, 2));
        }

        {
            auto date = Date(-3, 3, 31);
            date.roll!"months"(85).roll!"months"(-83);
            assert(date == Date(-3, 6, 1));
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.roll!"months"(3)));
        static assert(!__traits(compiles, idate.roll!"months"(3)));
    }

    // Test roll!"months"() with AllowDayOverflow.no
    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 7, 6);
            date.roll!"months"(3, AllowDayOverflow.no);
            assert(date == Date(1999, 10, 6));
            date.roll!"months"(-4, AllowDayOverflow.no);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.roll!"months"(6, AllowDayOverflow.no);
            assert(date == Date(1999, 1, 6));
            date.roll!"months"(-6, AllowDayOverflow.no);
            assert(date == Date(1999, 7, 6));
        }

        {
            auto date = Date(1999, 7, 6);
            date.roll!"months"(27, AllowDayOverflow.no);
            assert(date == Date(1999, 10, 6));
            date.roll!"months"(-28, AllowDayOverflow.no);
            assert(date == Date(1999, 6, 6));
        }

        {
            auto date = Date(1999, 5, 31);
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1999, 6, 30));
        }

        {
            auto date = Date(1999, 5, 31);
            date.roll!"months"(-1, AllowDayOverflow.no);
            assert(date == Date(1999, 4, 30));
        }

        {
            auto date = Date(1999, 2, 28);
            date.roll!"months"(12, AllowDayOverflow.no);
            assert(date == Date(1999, 2, 28));
        }

        {
            auto date = Date(2000, 2, 29);
            date.roll!"months"(12, AllowDayOverflow.no);
            assert(date == Date(2000, 2, 29));
        }

        {
            auto date = Date(1999, 7, 31);
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1999, 8, 31));
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1999, 9, 30));
        }

        {
            auto date = Date(1998, 8, 31);
            date.roll!"months"(13, AllowDayOverflow.no);
            assert(date == Date(1998, 9, 30));
            date.roll!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(1998, 8, 30));
        }

        {
            auto date = Date(1997, 12, 31);
            date.roll!"months"(13, AllowDayOverflow.no);
            assert(date == Date(1997, 1, 31));
            date.roll!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(1997, 12, 31));
        }

        {
            auto date = Date(1997, 12, 31);
            date.roll!"months"(14, AllowDayOverflow.no);
            assert(date == Date(1997, 2, 28));
            date.roll!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(1997, 12, 28));
        }

        {
            auto date = Date(1998, 12, 31);
            date.roll!"months"(14, AllowDayOverflow.no);
            assert(date == Date(1998, 2, 28));
            date.roll!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(1998, 12, 28));
        }

        {
            auto date = Date(1999, 12, 31);
            date.roll!"months"(14, AllowDayOverflow.no);
            assert(date == Date(1999, 2, 28));
            date.roll!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(1999, 12, 28));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 7, 6);
            date.roll!"months"(3, AllowDayOverflow.no);
            assert(date == Date(-1999, 10, 6));
            date.roll!"months"(-4, AllowDayOverflow.no);
            assert(date == Date(-1999, 6, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.roll!"months"(6, AllowDayOverflow.no);
            assert(date == Date(-1999, 1, 6));
            date.roll!"months"(-6, AllowDayOverflow.no);
            assert(date == Date(-1999, 7, 6));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.roll!"months"(-27, AllowDayOverflow.no);
            assert(date == Date(-1999, 4, 6));
            date.roll!"months"(28, AllowDayOverflow.no);
            assert(date == Date(-1999, 8, 6));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(-1999, 6, 30));
        }

        {
            auto date = Date(-1999, 5, 31);
            date.roll!"months"(-1, AllowDayOverflow.no);
            assert(date == Date(-1999, 4, 30));
        }

        {
            auto date = Date(-1999, 2, 28);
            date.roll!"months"(-12, AllowDayOverflow.no);
            assert(date == Date(-1999, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 29);
            date.roll!"months"(-12, AllowDayOverflow.no);
            assert(date == Date(-2000, 2, 29));
        }

        {
            auto date = Date(-1999, 7, 31);
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(-1999, 8, 31));
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(-1999, 9, 30));
        }

        {
            auto date = Date(-1998, 8, 31);
            date.roll!"months"(13, AllowDayOverflow.no);
            assert(date == Date(-1998, 9, 30));
            date.roll!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(-1998, 8, 30));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.roll!"months"(13, AllowDayOverflow.no);
            assert(date == Date(-1997, 1, 31));
            date.roll!"months"(-13, AllowDayOverflow.no);
            assert(date == Date(-1997, 12, 31));
        }

        {
            auto date = Date(-1997, 12, 31);
            date.roll!"months"(14, AllowDayOverflow.no);
            assert(date == Date(-1997, 2, 28));
            date.roll!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(-1997, 12, 28));
        }

        {
            auto date = Date(-2002, 12, 31);
            date.roll!"months"(14, AllowDayOverflow.no);
            assert(date == Date(-2002, 2, 28));
            date.roll!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(-2002, 12, 28));
        }

        {
            auto date = Date(-2001, 12, 31);
            date.roll!"months"(14, AllowDayOverflow.no);
            assert(date == Date(-2001, 2, 28));
            date.roll!"months"(-14, AllowDayOverflow.no);
            assert(date == Date(-2001, 12, 28));
        }

        // Test Both
        {
            auto date = Date(1, 1, 1);
            date.roll!"months"(-1, AllowDayOverflow.no);
            assert(date == Date(1, 12, 1));
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(1, 1, 1));
        }

        {
            auto date = Date(4, 1, 1);
            date.roll!"months"(-48, AllowDayOverflow.no);
            assert(date == Date(4, 1, 1));
            date.roll!"months"(48, AllowDayOverflow.no);
            assert(date == Date(4, 1, 1));
        }

        {
            auto date = Date(4, 3, 31);
            date.roll!"months"(-49, AllowDayOverflow.no);
            assert(date == Date(4, 2, 29));
            date.roll!"months"(49, AllowDayOverflow.no);
            assert(date == Date(4, 3, 29));
        }

        {
            auto date = Date(4, 3, 31);
            date.roll!"months"(-85, AllowDayOverflow.no);
            assert(date == Date(4, 2, 29));
            date.roll!"months"(85, AllowDayOverflow.no);
            assert(date == Date(4, 3, 29));
        }

        {
            auto date = Date(-1, 1, 1);
            date.roll!"months"(-1, AllowDayOverflow.no);
            assert(date == Date(-1, 12, 1));
            date.roll!"months"(1, AllowDayOverflow.no);
            assert(date == Date(-1, 1, 1));
        }

        {
            auto date = Date(-4, 1, 1);
            date.roll!"months"(-48, AllowDayOverflow.no);
            assert(date == Date(-4, 1, 1));
            date.roll!"months"(48, AllowDayOverflow.no);
            assert(date == Date(-4, 1, 1));
        }

        {
            auto date = Date(-4, 3, 31);
            date.roll!"months"(-49, AllowDayOverflow.no);
            assert(date == Date(-4, 2, 29));
            date.roll!"months"(49, AllowDayOverflow.no);
            assert(date == Date(-4, 3, 29));
        }

        {
            auto date = Date(-4, 3, 31);
            date.roll!"months"(-85, AllowDayOverflow.no);
            assert(date == Date(-4, 2, 29));
            date.roll!"months"(85, AllowDayOverflow.no);
            assert(date == Date(-4, 3, 29));
        }

        {
            auto date = Date(-3, 3, 31);
            date.roll!"months"(85, AllowDayOverflow.no).roll!"months"(-83, AllowDayOverflow.no);
            assert(date == Date(-3, 5, 30));
        }
    }


    /++
        Adds the given number of units to this $(LREF Date). A negative number
        will subtract.

        The difference between rolling and adding is that rolling does not
        affect larger units. For instance, rolling a $(LREF Date) one
        year's worth of days gets the exact same $(LREF Date).

        The only accepted units are $(D "days").

        Params:
            units = The units to add. Must be $(D "days").
            days  = The number of days to add to this $(LREF Date).
      +/
    ref Date roll(string units)(long days) @safe pure nothrow
        if (units == "days")
    {
        immutable limit = maxDay(_year, _month);
        days %= limit;
        auto newDay = _day + days;

        if (days < 0)
        {
            if (newDay < 1)
                newDay += limit;
        }
        else if (newDay > limit)
            newDay -= limit;

        _day = cast(ubyte) newDay;
        return this;
    }

    ///
    @safe unittest
    {
        auto d = Date(2010, 1, 1);
        d.roll!"days"(1);
        assert(d == Date(2010, 1, 2));
        d.roll!"days"(365);
        assert(d == Date(2010, 1, 26));
        d.roll!"days"(-32);
        assert(d == Date(2010, 1, 25));
    }

    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 2, 28);
            date.roll!"days"(1);
            assert(date == Date(1999, 2, 1));
            date.roll!"days"(-1);
            assert(date == Date(1999, 2, 28));
        }

        {
            auto date = Date(2000, 2, 28);
            date.roll!"days"(1);
            assert(date == Date(2000, 2, 29));
            date.roll!"days"(1);
            assert(date == Date(2000, 2, 1));
            date.roll!"days"(-1);
            assert(date == Date(2000, 2, 29));
        }

        {
            auto date = Date(1999, 6, 30);
            date.roll!"days"(1);
            assert(date == Date(1999, 6, 1));
            date.roll!"days"(-1);
            assert(date == Date(1999, 6, 30));
        }

        {
            auto date = Date(1999, 7, 31);
            date.roll!"days"(1);
            assert(date == Date(1999, 7, 1));
            date.roll!"days"(-1);
            assert(date == Date(1999, 7, 31));
        }

        {
            auto date = Date(1999, 1, 1);
            date.roll!"days"(-1);
            assert(date == Date(1999, 1, 31));
            date.roll!"days"(1);
            assert(date == Date(1999, 1, 1));
        }

        {
            auto date = Date(1999, 7, 6);
            date.roll!"days"(9);
            assert(date == Date(1999, 7, 15));
            date.roll!"days"(-11);
            assert(date == Date(1999, 7, 4));
            date.roll!"days"(30);
            assert(date == Date(1999, 7, 3));
            date.roll!"days"(-3);
            assert(date == Date(1999, 7, 31));
        }

        {
            auto date = Date(1999, 7, 6);
            date.roll!"days"(365);
            assert(date == Date(1999, 7, 30));
            date.roll!"days"(-365);
            assert(date == Date(1999, 7, 6));
            date.roll!"days"(366);
            assert(date == Date(1999, 7, 31));
            date.roll!"days"(730);
            assert(date == Date(1999, 7, 17));
            date.roll!"days"(-1096);
            assert(date == Date(1999, 7, 6));
        }

        {
            auto date = Date(1999, 2, 6);
            date.roll!"days"(365);
            assert(date == Date(1999, 2, 7));
            date.roll!"days"(-365);
            assert(date == Date(1999, 2, 6));
            date.roll!"days"(366);
            assert(date == Date(1999, 2, 8));
            date.roll!"days"(730);
            assert(date == Date(1999, 2, 10));
            date.roll!"days"(-1096);
            assert(date == Date(1999, 2, 6));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 2, 28);
            date.roll!"days"(1);
            assert(date == Date(-1999, 2, 1));
            date.roll!"days"(-1);
            assert(date == Date(-1999, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 28);
            date.roll!"days"(1);
            assert(date == Date(-2000, 2, 29));
            date.roll!"days"(1);
            assert(date == Date(-2000, 2, 1));
            date.roll!"days"(-1);
            assert(date == Date(-2000, 2, 29));
        }

        {
            auto date = Date(-1999, 6, 30);
            date.roll!"days"(1);
            assert(date == Date(-1999, 6, 1));
            date.roll!"days"(-1);
            assert(date == Date(-1999, 6, 30));
        }

        {
            auto date = Date(-1999, 7, 31);
            date.roll!"days"(1);
            assert(date == Date(-1999, 7, 1));
            date.roll!"days"(-1);
            assert(date == Date(-1999, 7, 31));
        }

        {
            auto date = Date(-1999, 1, 1);
            date.roll!"days"(-1);
            assert(date == Date(-1999, 1, 31));
            date.roll!"days"(1);
            assert(date == Date(-1999, 1, 1));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.roll!"days"(9);
            assert(date == Date(-1999, 7, 15));
            date.roll!"days"(-11);
            assert(date == Date(-1999, 7, 4));
            date.roll!"days"(30);
            assert(date == Date(-1999, 7, 3));
            date.roll!"days"(-3);
            assert(date == Date(-1999, 7, 31));
        }

        {
            auto date = Date(-1999, 7, 6);
            date.roll!"days"(365);
            assert(date == Date(-1999, 7, 30));
            date.roll!"days"(-365);
            assert(date == Date(-1999, 7, 6));
            date.roll!"days"(366);
            assert(date == Date(-1999, 7, 31));
            date.roll!"days"(730);
            assert(date == Date(-1999, 7, 17));
            date.roll!"days"(-1096);
            assert(date == Date(-1999, 7, 6));
        }

        // Test Both
        {
            auto date = Date(1, 7, 6);
            date.roll!"days"(-365);
            assert(date == Date(1, 7, 13));
            date.roll!"days"(365);
            assert(date == Date(1, 7, 6));
            date.roll!"days"(-731);
            assert(date == Date(1, 7, 19));
            date.roll!"days"(730);
            assert(date == Date(1, 7, 5));
        }

        {
            auto date = Date(0, 7, 6);
            date.roll!"days"(-365);
            assert(date == Date(0, 7, 13));
            date.roll!"days"(365);
            assert(date == Date(0, 7, 6));
            date.roll!"days"(-731);
            assert(date == Date(0, 7, 19));
            date.roll!"days"(730);
            assert(date == Date(0, 7, 5));
        }

        {
            auto date = Date(0, 7, 6);
            date.roll!"days"(-365).roll!"days"(362).roll!"days"(-12).roll!"days"(730);
            assert(date == Date(0, 7, 8));
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.roll!"days"(12)));
        static assert(!__traits(compiles, idate.roll!"days"(12)));
    }


    /++
        Gives the result of adding or subtracting a $(REF Duration, core,time)
        from

        The legal types of arithmetic for $(LREF Date) using this operator are

        $(BOOKTABLE,
        $(TR $(TD Date) $(TD +) $(TD Duration) $(TD -->) $(TD Date))
        $(TR $(TD Date) $(TD -) $(TD Duration) $(TD -->) $(TD Date))
        )

        Params:
            duration = The $(REF Duration, core,time) to add to or subtract from
                       this $(LREF Date).
      +/
    Date opBinary(string op)(Duration duration) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        Date retval = this;
        immutable days = duration.total!"days";
        mixin("return retval._addDays(" ~ op ~ "days);");
    }

    ///
    @safe unittest
    {
        import core.time : days;

        assert(Date(2015, 12, 31) + days(1) == Date(2016, 1, 1));
        assert(Date(2004, 2, 26) + days(4) == Date(2004, 3, 1));

        assert(Date(2016, 1, 1) - days(1) == Date(2015, 12, 31));
        assert(Date(2004, 3, 1) - days(4) == Date(2004, 2, 26));
    }

    @safe unittest
    {
        auto date = Date(1999, 7, 6);

        assert(date + dur!"weeks"(7) == Date(1999, 8, 24));
        assert(date + dur!"weeks"(-7) == Date(1999, 5, 18));
        assert(date + dur!"days"(7) == Date(1999, 7, 13));
        assert(date + dur!"days"(-7) == Date(1999, 6, 29));

        assert(date + dur!"hours"(24) == Date(1999, 7, 7));
        assert(date + dur!"hours"(-24) == Date(1999, 7, 5));
        assert(date + dur!"minutes"(1440) == Date(1999, 7, 7));
        assert(date + dur!"minutes"(-1440) == Date(1999, 7, 5));
        assert(date + dur!"seconds"(86_400) == Date(1999, 7, 7));
        assert(date + dur!"seconds"(-86_400) == Date(1999, 7, 5));
        assert(date + dur!"msecs"(86_400_000) == Date(1999, 7, 7));
        assert(date + dur!"msecs"(-86_400_000) == Date(1999, 7, 5));
        assert(date + dur!"usecs"(86_400_000_000) == Date(1999, 7, 7));
        assert(date + dur!"usecs"(-86_400_000_000) == Date(1999, 7, 5));
        assert(date + dur!"hnsecs"(864_000_000_000) == Date(1999, 7, 7));
        assert(date + dur!"hnsecs"(-864_000_000_000) == Date(1999, 7, 5));

        assert(date - dur!"weeks"(-7) == Date(1999, 8, 24));
        assert(date - dur!"weeks"(7) == Date(1999, 5, 18));
        assert(date - dur!"days"(-7) == Date(1999, 7, 13));
        assert(date - dur!"days"(7) == Date(1999, 6, 29));

        assert(date - dur!"hours"(-24) == Date(1999, 7, 7));
        assert(date - dur!"hours"(24) == Date(1999, 7, 5));
        assert(date - dur!"minutes"(-1440) == Date(1999, 7, 7));
        assert(date - dur!"minutes"(1440) == Date(1999, 7, 5));
        assert(date - dur!"seconds"(-86_400) == Date(1999, 7, 7));
        assert(date - dur!"seconds"(86_400) == Date(1999, 7, 5));
        assert(date - dur!"msecs"(-86_400_000) == Date(1999, 7, 7));
        assert(date - dur!"msecs"(86_400_000) == Date(1999, 7, 5));
        assert(date - dur!"usecs"(-86_400_000_000) == Date(1999, 7, 7));
        assert(date - dur!"usecs"(86_400_000_000) == Date(1999, 7, 5));
        assert(date - dur!"hnsecs"(-864_000_000_000) == Date(1999, 7, 7));
        assert(date - dur!"hnsecs"(864_000_000_000) == Date(1999, 7, 5));

        auto duration = dur!"days"(12);
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(date + duration == Date(1999, 7, 18));
        assert(cdate + duration == Date(1999, 7, 18));
        assert(idate + duration == Date(1999, 7, 18));

        assert(date - duration == Date(1999, 6, 24));
        assert(cdate - duration == Date(1999, 6, 24));
        assert(idate - duration == Date(1999, 6, 24));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    Date opBinary(string op)(TickDuration td) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        Date retval = this;
        immutable days = convert!("hnsecs", "days")(td.hnsecs);
        mixin("return retval._addDays(" ~ op ~ "days);");
    }

    deprecated @safe unittest
    {
        // This probably only runs in cases where gettimeofday() is used, but it's
        // hard to do this test correctly with variable ticksPerSec.
        if (TickDuration.ticksPerSec == 1_000_000)
        {
            auto date = Date(1999, 7, 6);

            assert(date + TickDuration.from!"usecs"(86_400_000_000) == Date(1999, 7, 7));
            assert(date + TickDuration.from!"usecs"(-86_400_000_000) == Date(1999, 7, 5));

            assert(date - TickDuration.from!"usecs"(-86_400_000_000) == Date(1999, 7, 7));
            assert(date - TickDuration.from!"usecs"(86_400_000_000) == Date(1999, 7, 5));
        }
    }


    /++
        Gives the result of adding or subtracting a $(REF Duration, core,time)
        from this $(LREF Date), as well as assigning the result to this
        $(LREF Date).

        The legal types of arithmetic for $(LREF Date) using this operator are

        $(BOOKTABLE,
        $(TR $(TD Date) $(TD +) $(TD Duration) $(TD -->) $(TD Date))
        $(TR $(TD Date) $(TD -) $(TD Duration) $(TD -->) $(TD Date))
        )

        Params:
            duration = The $(REF Duration, core,time) to add to or subtract from
                       this $(LREF Date).
      +/
    ref Date opOpAssign(string op)(Duration duration) @safe pure nothrow
        if (op == "+" || op == "-")
    {
        immutable days = duration.total!"days";
        mixin("return _addDays(" ~ op ~ "days);");
    }

    @safe unittest
    {
        assert(Date(1999, 7, 6) + dur!"weeks"(7) == Date(1999, 8, 24));
        assert(Date(1999, 7, 6) + dur!"weeks"(-7) == Date(1999, 5, 18));
        assert(Date(1999, 7, 6) + dur!"days"(7) == Date(1999, 7, 13));
        assert(Date(1999, 7, 6) + dur!"days"(-7) == Date(1999, 6, 29));

        assert(Date(1999, 7, 6) + dur!"hours"(24) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) + dur!"hours"(-24) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) + dur!"minutes"(1440) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) + dur!"minutes"(-1440) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) + dur!"seconds"(86_400) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) + dur!"seconds"(-86_400) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) + dur!"msecs"(86_400_000) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) + dur!"msecs"(-86_400_000) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) + dur!"usecs"(86_400_000_000) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) + dur!"usecs"(-86_400_000_000) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) + dur!"hnsecs"(864_000_000_000) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) + dur!"hnsecs"(-864_000_000_000) == Date(1999, 7, 5));

        assert(Date(1999, 7, 6) - dur!"weeks"(-7) == Date(1999, 8, 24));
        assert(Date(1999, 7, 6) - dur!"weeks"(7) == Date(1999, 5, 18));
        assert(Date(1999, 7, 6) - dur!"days"(-7) == Date(1999, 7, 13));
        assert(Date(1999, 7, 6) - dur!"days"(7) == Date(1999, 6, 29));

        assert(Date(1999, 7, 6) - dur!"hours"(-24) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) - dur!"hours"(24) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) - dur!"minutes"(-1440) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) - dur!"minutes"(1440) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) - dur!"seconds"(-86_400) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) - dur!"seconds"(86_400) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) - dur!"msecs"(-86_400_000) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) - dur!"msecs"(86_400_000) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) - dur!"usecs"(-86_400_000_000) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) - dur!"usecs"(86_400_000_000) == Date(1999, 7, 5));
        assert(Date(1999, 7, 6) - dur!"hnsecs"(-864_000_000_000) == Date(1999, 7, 7));
        assert(Date(1999, 7, 6) - dur!"hnsecs"(864_000_000_000) == Date(1999, 7, 5));

        {
            auto date = Date(0, 1, 31);
            (date += dur!"days"(507)) += dur!"days"(-2);
            assert(date == Date(1, 6, 19));
        }

        auto duration = dur!"days"(12);
        auto date = Date(1999, 7, 6);
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        date += duration;
        static assert(!__traits(compiles, cdate += duration));
        static assert(!__traits(compiles, idate += duration));

        date -= duration;
        static assert(!__traits(compiles, cdate -= duration));
        static assert(!__traits(compiles, idate -= duration));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    ref Date opOpAssign(string op)(TickDuration td) @safe pure nothrow
        if (op == "+" || op == "-")
    {
        immutable days = convert!("seconds", "days")(td.seconds);
        mixin("return _addDays(" ~ op ~ "days);");
    }

    deprecated @safe unittest
    {
        // This probably only runs in cases where gettimeofday() is used, but it's
        // hard to do this test correctly with variable ticksPerSec.
        if (TickDuration.ticksPerSec == 1_000_000)
        {
            {
                auto date = Date(1999, 7, 6);
                date += TickDuration.from!"usecs"(86_400_000_000);
                assert(date == Date(1999, 7, 7));
            }

            {
                auto date = Date(1999, 7, 6);
                date += TickDuration.from!"usecs"(-86_400_000_000);
                assert(date == Date(1999, 7, 5));
            }

            {
                auto date = Date(1999, 7, 6);
                date -= TickDuration.from!"usecs"(-86_400_000_000);
                assert(date == Date(1999, 7, 7));
            }

            {
                auto date = Date(1999, 7, 6);
                date -= TickDuration.from!"usecs"(86_400_000_000);
                assert(date == Date(1999, 7, 5));
            }
        }
    }


    /++
        Gives the difference between two $(LREF Date)s.

        The legal types of arithmetic for $(LREF Date) using this operator are

        $(BOOKTABLE,
        $(TR $(TD Date) $(TD -) $(TD Date) $(TD -->) $(TD duration))
        )
      +/
    Duration opBinary(string op)(in Date rhs) @safe const pure nothrow
        if (op == "-")
    {
        return dur!"days"(this.dayOfGregorianCal - rhs.dayOfGregorianCal);
    }

    @safe unittest
    {
        auto date = Date(1999, 7, 6);

        assert(Date(1999, 7, 6) - Date(1998, 7, 6) == dur!"days"(365));
        assert(Date(1998, 7, 6) - Date(1999, 7, 6) == dur!"days"(-365));
        assert(Date(1999, 6, 6) - Date(1999, 5, 6) == dur!"days"(31));
        assert(Date(1999, 5, 6) - Date(1999, 6, 6) == dur!"days"(-31));
        assert(Date(1999, 1, 1) - Date(1998, 12, 31) == dur!"days"(1));
        assert(Date(1998, 12, 31) - Date(1999, 1, 1) == dur!"days"(-1));

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(date - date == Duration.zero);
        assert(cdate - date == Duration.zero);
        assert(idate - date == Duration.zero);

        assert(date - cdate == Duration.zero);
        assert(cdate - cdate == Duration.zero);
        assert(idate - cdate == Duration.zero);

        assert(date - idate == Duration.zero);
        assert(cdate - idate == Duration.zero);
        assert(idate - idate == Duration.zero);
    }


    /++
        Returns the difference between the two $(LREF Date)s in months.

        To get the difference in years, subtract the year property
        of two $(LREF Date)s. To get the difference in days or weeks,
        subtract the $(LREF Date)s themselves and use the
        $(REF Duration, core,time) that results. Because converting between
        months and smaller units requires a specific date (which
        $(REF Duration, core,time)s don't have), getting the difference in
        months requires some math using both the year and month properties, so
        this is a convenience function for getting the difference in months.

        Note that the number of days in the months or how far into the month
        either $(LREF Date) is is irrelevant. It is the difference in the month
        property combined with the difference in years * 12. So, for instance,
        December 31st and January 1st are one month apart just as December 1st
        and January 31st are one month apart.

        Params:
            rhs = The $(LREF Date) to subtract from this one.
      +/
    int diffMonths(in Date rhs) @safe const pure nothrow
    {
        immutable yearDiff = _year - rhs._year;
        immutable monthDiff = _month - rhs._month;

        return yearDiff * 12 + monthDiff;
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 2, 1).diffMonths(Date(1999, 1, 31)) == 1);
        assert(Date(1999, 1, 31).diffMonths(Date(1999, 2, 1)) == -1);
        assert(Date(1999, 3, 1).diffMonths(Date(1999, 1, 1)) == 2);
        assert(Date(1999, 1, 1).diffMonths(Date(1999, 3, 31)) == -2);
    }

    @safe unittest
    {
        auto date = Date(1999, 7, 6);

        // Test A.D.
        assert(date.diffMonths(Date(1998, 6, 5)) == 13);
        assert(date.diffMonths(Date(1998, 7, 5)) == 12);
        assert(date.diffMonths(Date(1998, 8, 5)) == 11);
        assert(date.diffMonths(Date(1998, 9, 5)) == 10);
        assert(date.diffMonths(Date(1998, 10, 5)) == 9);
        assert(date.diffMonths(Date(1998, 11, 5)) == 8);
        assert(date.diffMonths(Date(1998, 12, 5)) == 7);
        assert(date.diffMonths(Date(1999, 1, 5)) == 6);
        assert(date.diffMonths(Date(1999, 2, 6)) == 5);
        assert(date.diffMonths(Date(1999, 3, 6)) == 4);
        assert(date.diffMonths(Date(1999, 4, 6)) == 3);
        assert(date.diffMonths(Date(1999, 5, 6)) == 2);
        assert(date.diffMonths(Date(1999, 6, 6)) == 1);
        assert(date.diffMonths(date) == 0);
        assert(date.diffMonths(Date(1999, 8, 6)) == -1);
        assert(date.diffMonths(Date(1999, 9, 6)) == -2);
        assert(date.diffMonths(Date(1999, 10, 6)) == -3);
        assert(date.diffMonths(Date(1999, 11, 6)) == -4);
        assert(date.diffMonths(Date(1999, 12, 6)) == -5);
        assert(date.diffMonths(Date(2000, 1, 6)) == -6);
        assert(date.diffMonths(Date(2000, 2, 6)) == -7);
        assert(date.diffMonths(Date(2000, 3, 6)) == -8);
        assert(date.diffMonths(Date(2000, 4, 6)) == -9);
        assert(date.diffMonths(Date(2000, 5, 6)) == -10);
        assert(date.diffMonths(Date(2000, 6, 6)) == -11);
        assert(date.diffMonths(Date(2000, 7, 6)) == -12);
        assert(date.diffMonths(Date(2000, 8, 6)) == -13);

        assert(Date(1998, 6, 5).diffMonths(date) == -13);
        assert(Date(1998, 7, 5).diffMonths(date) == -12);
        assert(Date(1998, 8, 5).diffMonths(date) == -11);
        assert(Date(1998, 9, 5).diffMonths(date) == -10);
        assert(Date(1998, 10, 5).diffMonths(date) == -9);
        assert(Date(1998, 11, 5).diffMonths(date) == -8);
        assert(Date(1998, 12, 5).diffMonths(date) == -7);
        assert(Date(1999, 1, 5).diffMonths(date) == -6);
        assert(Date(1999, 2, 6).diffMonths(date) == -5);
        assert(Date(1999, 3, 6).diffMonths(date) == -4);
        assert(Date(1999, 4, 6).diffMonths(date) == -3);
        assert(Date(1999, 5, 6).diffMonths(date) == -2);
        assert(Date(1999, 6, 6).diffMonths(date) == -1);
        assert(Date(1999, 8, 6).diffMonths(date) == 1);
        assert(Date(1999, 9, 6).diffMonths(date) == 2);
        assert(Date(1999, 10, 6).diffMonths(date) == 3);
        assert(Date(1999, 11, 6).diffMonths(date) == 4);
        assert(Date(1999, 12, 6).diffMonths(date) == 5);
        assert(Date(2000, 1, 6).diffMonths(date) == 6);
        assert(Date(2000, 2, 6).diffMonths(date) == 7);
        assert(Date(2000, 3, 6).diffMonths(date) == 8);
        assert(Date(2000, 4, 6).diffMonths(date) == 9);
        assert(Date(2000, 5, 6).diffMonths(date) == 10);
        assert(Date(2000, 6, 6).diffMonths(date) == 11);
        assert(Date(2000, 7, 6).diffMonths(date) == 12);
        assert(Date(2000, 8, 6).diffMonths(date) == 13);

        assert(date.diffMonths(Date(1999, 6, 30)) == 1);
        assert(date.diffMonths(Date(1999, 7, 1)) == 0);
        assert(date.diffMonths(Date(1999, 7, 6)) == 0);
        assert(date.diffMonths(Date(1999, 7, 11)) == 0);
        assert(date.diffMonths(Date(1999, 7, 16)) == 0);
        assert(date.diffMonths(Date(1999, 7, 21)) == 0);
        assert(date.diffMonths(Date(1999, 7, 26)) == 0);
        assert(date.diffMonths(Date(1999, 7, 31)) == 0);
        assert(date.diffMonths(Date(1999, 8, 1)) == -1);

        assert(date.diffMonths(Date(1990, 6, 30)) == 109);
        assert(date.diffMonths(Date(1990, 7, 1)) == 108);
        assert(date.diffMonths(Date(1990, 7, 6)) == 108);
        assert(date.diffMonths(Date(1990, 7, 11)) == 108);
        assert(date.diffMonths(Date(1990, 7, 16)) == 108);
        assert(date.diffMonths(Date(1990, 7, 21)) == 108);
        assert(date.diffMonths(Date(1990, 7, 26)) == 108);
        assert(date.diffMonths(Date(1990, 7, 31)) == 108);
        assert(date.diffMonths(Date(1990, 8, 1)) == 107);

        assert(Date(1999, 6, 30).diffMonths(date) == -1);
        assert(Date(1999, 7, 1).diffMonths(date) == 0);
        assert(Date(1999, 7, 6).diffMonths(date) == 0);
        assert(Date(1999, 7, 11).diffMonths(date) == 0);
        assert(Date(1999, 7, 16).diffMonths(date) == 0);
        assert(Date(1999, 7, 21).diffMonths(date) == 0);
        assert(Date(1999, 7, 26).diffMonths(date) == 0);
        assert(Date(1999, 7, 31).diffMonths(date) == 0);
        assert(Date(1999, 8, 1).diffMonths(date) == 1);

        assert(Date(1990, 6, 30).diffMonths(date) == -109);
        assert(Date(1990, 7, 1).diffMonths(date) == -108);
        assert(Date(1990, 7, 6).diffMonths(date) == -108);
        assert(Date(1990, 7, 11).diffMonths(date) == -108);
        assert(Date(1990, 7, 16).diffMonths(date) == -108);
        assert(Date(1990, 7, 21).diffMonths(date) == -108);
        assert(Date(1990, 7, 26).diffMonths(date) == -108);
        assert(Date(1990, 7, 31).diffMonths(date) == -108);
        assert(Date(1990, 8, 1).diffMonths(date) == -107);

        // Test B.C.
        auto dateBC = Date(-1999, 7, 6);

        assert(dateBC.diffMonths(Date(-2000, 6, 5)) == 13);
        assert(dateBC.diffMonths(Date(-2000, 7, 5)) == 12);
        assert(dateBC.diffMonths(Date(-2000, 8, 5)) == 11);
        assert(dateBC.diffMonths(Date(-2000, 9, 5)) == 10);
        assert(dateBC.diffMonths(Date(-2000, 10, 5)) == 9);
        assert(dateBC.diffMonths(Date(-2000, 11, 5)) == 8);
        assert(dateBC.diffMonths(Date(-2000, 12, 5)) == 7);
        assert(dateBC.diffMonths(Date(-1999, 1, 5)) == 6);
        assert(dateBC.diffMonths(Date(-1999, 2, 6)) == 5);
        assert(dateBC.diffMonths(Date(-1999, 3, 6)) == 4);
        assert(dateBC.diffMonths(Date(-1999, 4, 6)) == 3);
        assert(dateBC.diffMonths(Date(-1999, 5, 6)) == 2);
        assert(dateBC.diffMonths(Date(-1999, 6, 6)) == 1);
        assert(dateBC.diffMonths(dateBC) == 0);
        assert(dateBC.diffMonths(Date(-1999, 8, 6)) == -1);
        assert(dateBC.diffMonths(Date(-1999, 9, 6)) == -2);
        assert(dateBC.diffMonths(Date(-1999, 10, 6)) == -3);
        assert(dateBC.diffMonths(Date(-1999, 11, 6)) == -4);
        assert(dateBC.diffMonths(Date(-1999, 12, 6)) == -5);
        assert(dateBC.diffMonths(Date(-1998, 1, 6)) == -6);
        assert(dateBC.diffMonths(Date(-1998, 2, 6)) == -7);
        assert(dateBC.diffMonths(Date(-1998, 3, 6)) == -8);
        assert(dateBC.diffMonths(Date(-1998, 4, 6)) == -9);
        assert(dateBC.diffMonths(Date(-1998, 5, 6)) == -10);
        assert(dateBC.diffMonths(Date(-1998, 6, 6)) == -11);
        assert(dateBC.diffMonths(Date(-1998, 7, 6)) == -12);
        assert(dateBC.diffMonths(Date(-1998, 8, 6)) == -13);

        assert(Date(-2000, 6, 5).diffMonths(dateBC) == -13);
        assert(Date(-2000, 7, 5).diffMonths(dateBC) == -12);
        assert(Date(-2000, 8, 5).diffMonths(dateBC) == -11);
        assert(Date(-2000, 9, 5).diffMonths(dateBC) == -10);
        assert(Date(-2000, 10, 5).diffMonths(dateBC) == -9);
        assert(Date(-2000, 11, 5).diffMonths(dateBC) == -8);
        assert(Date(-2000, 12, 5).diffMonths(dateBC) == -7);
        assert(Date(-1999, 1, 5).diffMonths(dateBC) == -6);
        assert(Date(-1999, 2, 6).diffMonths(dateBC) == -5);
        assert(Date(-1999, 3, 6).diffMonths(dateBC) == -4);
        assert(Date(-1999, 4, 6).diffMonths(dateBC) == -3);
        assert(Date(-1999, 5, 6).diffMonths(dateBC) == -2);
        assert(Date(-1999, 6, 6).diffMonths(dateBC) == -1);
        assert(Date(-1999, 8, 6).diffMonths(dateBC) == 1);
        assert(Date(-1999, 9, 6).diffMonths(dateBC) == 2);
        assert(Date(-1999, 10, 6).diffMonths(dateBC) == 3);
        assert(Date(-1999, 11, 6).diffMonths(dateBC) == 4);
        assert(Date(-1999, 12, 6).diffMonths(dateBC) == 5);
        assert(Date(-1998, 1, 6).diffMonths(dateBC) == 6);
        assert(Date(-1998, 2, 6).diffMonths(dateBC) == 7);
        assert(Date(-1998, 3, 6).diffMonths(dateBC) == 8);
        assert(Date(-1998, 4, 6).diffMonths(dateBC) == 9);
        assert(Date(-1998, 5, 6).diffMonths(dateBC) == 10);
        assert(Date(-1998, 6, 6).diffMonths(dateBC) == 11);
        assert(Date(-1998, 7, 6).diffMonths(dateBC) == 12);
        assert(Date(-1998, 8, 6).diffMonths(dateBC) == 13);

        assert(dateBC.diffMonths(Date(-1999, 6, 30)) == 1);
        assert(dateBC.diffMonths(Date(-1999, 7, 1)) == 0);
        assert(dateBC.diffMonths(Date(-1999, 7, 6)) == 0);
        assert(dateBC.diffMonths(Date(-1999, 7, 11)) == 0);
        assert(dateBC.diffMonths(Date(-1999, 7, 16)) == 0);
        assert(dateBC.diffMonths(Date(-1999, 7, 21)) == 0);
        assert(dateBC.diffMonths(Date(-1999, 7, 26)) == 0);
        assert(dateBC.diffMonths(Date(-1999, 7, 31)) == 0);
        assert(dateBC.diffMonths(Date(-1999, 8, 1)) == -1);

        assert(dateBC.diffMonths(Date(-2008, 6, 30)) == 109);
        assert(dateBC.diffMonths(Date(-2008, 7, 1)) == 108);
        assert(dateBC.diffMonths(Date(-2008, 7, 6)) == 108);
        assert(dateBC.diffMonths(Date(-2008, 7, 11)) == 108);
        assert(dateBC.diffMonths(Date(-2008, 7, 16)) == 108);
        assert(dateBC.diffMonths(Date(-2008, 7, 21)) == 108);
        assert(dateBC.diffMonths(Date(-2008, 7, 26)) == 108);
        assert(dateBC.diffMonths(Date(-2008, 7, 31)) == 108);
        assert(dateBC.diffMonths(Date(-2008, 8, 1)) == 107);

        assert(Date(-1999, 6, 30).diffMonths(dateBC) == -1);
        assert(Date(-1999, 7, 1).diffMonths(dateBC) == 0);
        assert(Date(-1999, 7, 6).diffMonths(dateBC) == 0);
        assert(Date(-1999, 7, 11).diffMonths(dateBC) == 0);
        assert(Date(-1999, 7, 16).diffMonths(dateBC) == 0);
        assert(Date(-1999, 7, 21).diffMonths(dateBC) == 0);
        assert(Date(-1999, 7, 26).diffMonths(dateBC) == 0);
        assert(Date(-1999, 7, 31).diffMonths(dateBC) == 0);
        assert(Date(-1999, 8, 1).diffMonths(dateBC) == 1);

        assert(Date(-2008, 6, 30).diffMonths(dateBC) == -109);
        assert(Date(-2008, 7, 1).diffMonths(dateBC) == -108);
        assert(Date(-2008, 7, 6).diffMonths(dateBC) == -108);
        assert(Date(-2008, 7, 11).diffMonths(dateBC) == -108);
        assert(Date(-2008, 7, 16).diffMonths(dateBC) == -108);
        assert(Date(-2008, 7, 21).diffMonths(dateBC) == -108);
        assert(Date(-2008, 7, 26).diffMonths(dateBC) == -108);
        assert(Date(-2008, 7, 31).diffMonths(dateBC) == -108);
        assert(Date(-2008, 8, 1).diffMonths(dateBC) == -107);

        // Test Both
        assert(Date(3, 3, 3).diffMonths(Date(-5, 5, 5)) == 94);
        assert(Date(-5, 5, 5).diffMonths(Date(3, 3, 3)) == -94);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(date.diffMonths(date) == 0);
        assert(cdate.diffMonths(date) == 0);
        assert(idate.diffMonths(date) == 0);

        assert(date.diffMonths(cdate) == 0);
        assert(cdate.diffMonths(cdate) == 0);
        assert(idate.diffMonths(cdate) == 0);

        assert(date.diffMonths(idate) == 0);
        assert(cdate.diffMonths(idate) == 0);
        assert(idate.diffMonths(idate) == 0);
    }


    /++
        Whether this $(LREF Date) is in a leap year.
     +/
    @property bool isLeapYear() @safe const pure nothrow
    {
        return yearIsLeapYear(_year);
    }

    @safe unittest
    {
        auto date = Date(1999, 7, 6);
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, date.isLeapYear = true));
        static assert(!__traits(compiles, cdate.isLeapYear = true));
        static assert(!__traits(compiles, idate.isLeapYear = true));
    }


    /++
        Day of the week this $(LREF Date) is on.
      +/
    @property DayOfWeek dayOfWeek() @safe const pure nothrow
    {
        return getDayOfWeek(dayOfGregorianCal);
    }

    @safe unittest
    {
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.dayOfWeek == DayOfWeek.tue);
        static assert(!__traits(compiles, cdate.dayOfWeek = DayOfWeek.sun));
        assert(idate.dayOfWeek == DayOfWeek.tue);
        static assert(!__traits(compiles, idate.dayOfWeek = DayOfWeek.sun));
    }


    /++
        Day of the year this $(LREF Date) is on.
      +/
    @property ushort dayOfYear() @safe const pure nothrow
    {
        if (_month >= Month.jan && _month <= Month.dec)
        {
            immutable int[] lastDay = isLeapYear ? lastDayLeap : lastDayNonLeap;
            auto monthIndex = _month - Month.jan;

            return cast(ushort)(lastDay[monthIndex] + _day);
        }
        assert(0, "Invalid month.");
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 1, 1).dayOfYear == 1);
        assert(Date(1999, 12, 31).dayOfYear == 365);
        assert(Date(2000, 12, 31).dayOfYear == 366);
    }

    @safe unittest
    {
        import std.algorithm.iteration : filter;
        import std.range : chain;

        foreach (year; filter!((a){return !yearIsLeapYear(a);})(chain(testYearsBC, testYearsAD)))
        {
            foreach (doy; testDaysOfYear)
                assert(Date(year, doy.md.month, doy.md.day).dayOfYear == doy.day);
        }

        foreach (year; filter!((a){return yearIsLeapYear(a);})(chain(testYearsBC, testYearsAD)))
        {
            foreach (doy; testDaysOfLeapYear)
                assert(Date(year, doy.md.month, doy.md.day).dayOfYear == doy.day);
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.dayOfYear == 187);
        assert(idate.dayOfYear == 187);
    }

    /++
        Day of the year.

        Params:
            day = The day of the year to set which day of the year this
                  $(LREF Date) is on.

        Throws:
            $(REF std,datetime,common,DateTimeException) if the given day is an
            invalid day of the year.
      +/
    @property void dayOfYear(int day) @safe pure
    {
        immutable int[] lastDay = isLeapYear ? lastDayLeap : lastDayNonLeap;

        if (day <= 0 || day > (isLeapYear ? daysInLeapYear : daysInYear))
            throw new DateTimeException("Invalid day of the year.");

        foreach (i; 1 .. lastDay.length)
        {
            if (day <= lastDay[i])
            {
                _month = cast(Month)(cast(int) Month.jan + i - 1);
                _day = cast(ubyte)(day - lastDay[i - 1]);
                return;
            }
        }
        assert(0, "Invalid day of the year.");
    }

    @safe unittest
    {
        static void test(Date date, int day, MonthDay expected, size_t line = __LINE__)
        {
            date.dayOfYear = day;
            assert(date.month == expected.month);
            assert(date.day == expected.day);
        }

        foreach (doy; testDaysOfYear)
        {
            test(Date(1999, 1, 1), doy.day, doy.md);
            test(Date(-1, 1, 1), doy.day, doy.md);
        }

        foreach (doy; testDaysOfLeapYear)
        {
            test(Date(2000, 1, 1), doy.day, doy.md);
            test(Date(-4, 1, 1), doy.day, doy.md);
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.dayOfYear = 187));
        static assert(!__traits(compiles, idate.dayOfYear = 187));
    }


    /++
        The Xth day of the Gregorian Calendar that this $(LREF Date) is on.
     +/
    @property int dayOfGregorianCal() @safe const pure nothrow
    {
        if (isAD)
        {
            if (_year == 1)
                return dayOfYear;

            int years = _year - 1;
            auto days = (years / 400) * daysIn400Years;
            years %= 400;

            days += (years / 100) * daysIn100Years;
            years %= 100;

            days += (years / 4) * daysIn4Years;
            years %= 4;

            days += years * daysInYear;

            days += dayOfYear;

            return days;
        }
        else if (_year == 0)
            return dayOfYear - daysInLeapYear;
        else
        {
            int years = _year;
            auto days = (years / 400) * daysIn400Years;
            years %= 400;

            days += (years / 100) * daysIn100Years;
            years %= 100;

            days += (years / 4) * daysIn4Years;
            years %= 4;

            if (years < 0)
            {
                days -= daysInLeapYear;
                ++years;

                days += years * daysInYear;

                days -= daysInYear - dayOfYear;
            }
            else
                days -= daysInLeapYear - dayOfYear;

            return days;
        }
    }

    ///
    @safe unittest
    {
        assert(Date(1, 1, 1).dayOfGregorianCal == 1);
        assert(Date(1, 12, 31).dayOfGregorianCal == 365);
        assert(Date(2, 1, 1).dayOfGregorianCal == 366);

        assert(Date(0, 12, 31).dayOfGregorianCal == 0);
        assert(Date(0, 1, 1).dayOfGregorianCal == -365);
        assert(Date(-1, 12, 31).dayOfGregorianCal == -366);

        assert(Date(2000, 1, 1).dayOfGregorianCal == 730_120);
        assert(Date(2010, 12, 31).dayOfGregorianCal == 734_137);
    }

    @safe unittest
    {
        import std.range : chain;

        foreach (gd; chain(testGregDaysBC, testGregDaysAD))
            assert(gd.date.dayOfGregorianCal == gd.day);

        auto date = Date(1999, 7, 6);
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(date.dayOfGregorianCal == 729_941);
        assert(cdate.dayOfGregorianCal == 729_941);
        assert(idate.dayOfGregorianCal == 729_941);
    }

    /++
        The Xth day of the Gregorian Calendar that this $(LREF Date) is on.

        Params:
            day = The day of the Gregorian Calendar to set this $(LREF Date) to.
     +/
    @property void dayOfGregorianCal(int day) @safe pure nothrow
    {
        this = Date(day);
    }

    ///
    @safe unittest
    {
        auto date = Date.init;
        date.dayOfGregorianCal = 1;
        assert(date == Date(1, 1, 1));

        date.dayOfGregorianCal = 365;
        assert(date == Date(1, 12, 31));

        date.dayOfGregorianCal = 366;
        assert(date == Date(2, 1, 1));

        date.dayOfGregorianCal = 0;
        assert(date == Date(0, 12, 31));

        date.dayOfGregorianCal = -365;
        assert(date == Date(-0, 1, 1));

        date.dayOfGregorianCal = -366;
        assert(date == Date(-1, 12, 31));

        date.dayOfGregorianCal = 730_120;
        assert(date == Date(2000, 1, 1));

        date.dayOfGregorianCal = 734_137;
        assert(date == Date(2010, 12, 31));
    }

    @safe unittest
    {
        auto date = Date(1999, 7, 6);
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        date.dayOfGregorianCal = 187;
        assert(date.dayOfGregorianCal == 187);
        static assert(!__traits(compiles, cdate.dayOfGregorianCal = 187));
        static assert(!__traits(compiles, idate.dayOfGregorianCal = 187));
    }


    /++
        The ISO 8601 week of the year that this $(LREF Date) is in.

        See_Also:
            $(HTTP en.wikipedia.org/wiki/ISO_week_date, ISO Week Date)
      +/
    @property ubyte isoWeek() @safe const pure nothrow
    {
        immutable weekday = dayOfWeek;
        immutable adjustedWeekday = weekday == DayOfWeek.sun ? 7 : weekday;
        immutable week = (dayOfYear - adjustedWeekday + 10) / 7;

        try
        {
            if (week == 53)
            {
                switch (Date(_year + 1, 1, 1).dayOfWeek)
                {
                    case DayOfWeek.mon:
                    case DayOfWeek.tue:
                    case DayOfWeek.wed:
                    case DayOfWeek.thu:
                        return 1;
                    case DayOfWeek.fri:
                    case DayOfWeek.sat:
                    case DayOfWeek.sun:
                        return 53;
                    default:
                        assert(0, "Invalid ISO Week");
                }
            }
            else if (week > 0)
                return cast(ubyte) week;
            else
                return Date(_year - 1, 12, 31).isoWeek;
        }
        catch (Exception e)
            assert(0, "Date's constructor threw.");
    }

    @safe unittest
    {
        // Test A.D.
        assert(Date(2009, 12, 28).isoWeek == 53);
        assert(Date(2009, 12, 29).isoWeek == 53);
        assert(Date(2009, 12, 30).isoWeek == 53);
        assert(Date(2009, 12, 31).isoWeek == 53);
        assert(Date(2010, 1, 1).isoWeek == 53);
        assert(Date(2010, 1, 2).isoWeek == 53);
        assert(Date(2010, 1, 3).isoWeek == 53);
        assert(Date(2010, 1, 4).isoWeek == 1);
        assert(Date(2010, 1, 5).isoWeek == 1);
        assert(Date(2010, 1, 6).isoWeek == 1);
        assert(Date(2010, 1, 7).isoWeek == 1);
        assert(Date(2010, 1, 8).isoWeek == 1);
        assert(Date(2010, 1, 9).isoWeek == 1);
        assert(Date(2010, 1, 10).isoWeek == 1);
        assert(Date(2010, 1, 11).isoWeek == 2);
        assert(Date(2010, 12, 31).isoWeek == 52);

        assert(Date(2004, 12, 26).isoWeek == 52);
        assert(Date(2004, 12, 27).isoWeek == 53);
        assert(Date(2004, 12, 28).isoWeek == 53);
        assert(Date(2004, 12, 29).isoWeek == 53);
        assert(Date(2004, 12, 30).isoWeek == 53);
        assert(Date(2004, 12, 31).isoWeek == 53);
        assert(Date(2005, 1, 1).isoWeek == 53);
        assert(Date(2005, 1, 2).isoWeek == 53);

        assert(Date(2005, 12, 31).isoWeek == 52);
        assert(Date(2007, 1, 1).isoWeek == 1);

        assert(Date(2007, 12, 30).isoWeek == 52);
        assert(Date(2007, 12, 31).isoWeek == 1);
        assert(Date(2008, 1, 1).isoWeek == 1);

        assert(Date(2008, 12, 28).isoWeek == 52);
        assert(Date(2008, 12, 29).isoWeek == 1);
        assert(Date(2008, 12, 30).isoWeek == 1);
        assert(Date(2008, 12, 31).isoWeek == 1);
        assert(Date(2009, 1, 1).isoWeek == 1);
        assert(Date(2009, 1, 2).isoWeek == 1);
        assert(Date(2009, 1, 3).isoWeek == 1);
        assert(Date(2009, 1, 4).isoWeek == 1);

        // Test B.C.
        // The algorithm should work identically for both A.D. and B.C. since
        // it doesn't really take the year into account, so B.C. testing
        // probably isn't really needed.
        assert(Date(0, 12, 31).isoWeek == 52);
        assert(Date(0, 1, 4).isoWeek == 1);
        assert(Date(0, 1, 1).isoWeek == 52);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.isoWeek == 27);
        static assert(!__traits(compiles, cdate.isoWeek = 3));
        assert(idate.isoWeek == 27);
        static assert(!__traits(compiles, idate.isoWeek = 3));
    }


    /++
        $(LREF Date) for the last day in the month that this $(LREF Date) is in.
      +/
    @property Date endOfMonth() @safe const pure nothrow
    {
        try
            return Date(_year, _month, maxDay(_year, _month));
        catch (Exception e)
            assert(0, "Date's constructor threw.");
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 1, 6).endOfMonth == Date(1999, 1, 31));
        assert(Date(1999, 2, 7).endOfMonth == Date(1999, 2, 28));
        assert(Date(2000, 2, 7).endOfMonth == Date(2000, 2, 29));
        assert(Date(2000, 6, 4).endOfMonth == Date(2000, 6, 30));
    }

    @safe unittest
    {
        // Test A.D.
        assert(Date(1999, 1, 1).endOfMonth == Date(1999, 1, 31));
        assert(Date(1999, 2, 1).endOfMonth == Date(1999, 2, 28));
        assert(Date(2000, 2, 1).endOfMonth == Date(2000, 2, 29));
        assert(Date(1999, 3, 1).endOfMonth == Date(1999, 3, 31));
        assert(Date(1999, 4, 1).endOfMonth == Date(1999, 4, 30));
        assert(Date(1999, 5, 1).endOfMonth == Date(1999, 5, 31));
        assert(Date(1999, 6, 1).endOfMonth == Date(1999, 6, 30));
        assert(Date(1999, 7, 1).endOfMonth == Date(1999, 7, 31));
        assert(Date(1999, 8, 1).endOfMonth == Date(1999, 8, 31));
        assert(Date(1999, 9, 1).endOfMonth == Date(1999, 9, 30));
        assert(Date(1999, 10, 1).endOfMonth == Date(1999, 10, 31));
        assert(Date(1999, 11, 1).endOfMonth == Date(1999, 11, 30));
        assert(Date(1999, 12, 1).endOfMonth == Date(1999, 12, 31));

        // Test B.C.
        assert(Date(-1999, 1, 1).endOfMonth == Date(-1999, 1, 31));
        assert(Date(-1999, 2, 1).endOfMonth == Date(-1999, 2, 28));
        assert(Date(-2000, 2, 1).endOfMonth == Date(-2000, 2, 29));
        assert(Date(-1999, 3, 1).endOfMonth == Date(-1999, 3, 31));
        assert(Date(-1999, 4, 1).endOfMonth == Date(-1999, 4, 30));
        assert(Date(-1999, 5, 1).endOfMonth == Date(-1999, 5, 31));
        assert(Date(-1999, 6, 1).endOfMonth == Date(-1999, 6, 30));
        assert(Date(-1999, 7, 1).endOfMonth == Date(-1999, 7, 31));
        assert(Date(-1999, 8, 1).endOfMonth == Date(-1999, 8, 31));
        assert(Date(-1999, 9, 1).endOfMonth == Date(-1999, 9, 30));
        assert(Date(-1999, 10, 1).endOfMonth == Date(-1999, 10, 31));
        assert(Date(-1999, 11, 1).endOfMonth == Date(-1999, 11, 30));
        assert(Date(-1999, 12, 1).endOfMonth == Date(-1999, 12, 31));

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.endOfMonth = Date(1999, 7, 30)));
        static assert(!__traits(compiles, idate.endOfMonth = Date(1999, 7, 30)));
    }


    /++
        The last day in the month that this $(LREF Date) is in.
      +/
    @property ubyte daysInMonth() @safe const pure nothrow
    {
        return maxDay(_year, _month);
    }

    ///
    @safe unittest
    {
        assert(Date(1999, 1, 6).daysInMonth == 31);
        assert(Date(1999, 2, 7).daysInMonth == 28);
        assert(Date(2000, 2, 7).daysInMonth == 29);
        assert(Date(2000, 6, 4).daysInMonth == 30);
    }

    @safe unittest
    {
        // Test A.D.
        assert(Date(1999, 1, 1).daysInMonth == 31);
        assert(Date(1999, 2, 1).daysInMonth == 28);
        assert(Date(2000, 2, 1).daysInMonth == 29);
        assert(Date(1999, 3, 1).daysInMonth == 31);
        assert(Date(1999, 4, 1).daysInMonth == 30);
        assert(Date(1999, 5, 1).daysInMonth == 31);
        assert(Date(1999, 6, 1).daysInMonth == 30);
        assert(Date(1999, 7, 1).daysInMonth == 31);
        assert(Date(1999, 8, 1).daysInMonth == 31);
        assert(Date(1999, 9, 1).daysInMonth == 30);
        assert(Date(1999, 10, 1).daysInMonth == 31);
        assert(Date(1999, 11, 1).daysInMonth == 30);
        assert(Date(1999, 12, 1).daysInMonth == 31);

        // Test B.C.
        assert(Date(-1999, 1, 1).daysInMonth == 31);
        assert(Date(-1999, 2, 1).daysInMonth == 28);
        assert(Date(-2000, 2, 1).daysInMonth == 29);
        assert(Date(-1999, 3, 1).daysInMonth == 31);
        assert(Date(-1999, 4, 1).daysInMonth == 30);
        assert(Date(-1999, 5, 1).daysInMonth == 31);
        assert(Date(-1999, 6, 1).daysInMonth == 30);
        assert(Date(-1999, 7, 1).daysInMonth == 31);
        assert(Date(-1999, 8, 1).daysInMonth == 31);
        assert(Date(-1999, 9, 1).daysInMonth == 30);
        assert(Date(-1999, 10, 1).daysInMonth == 31);
        assert(Date(-1999, 11, 1).daysInMonth == 30);
        assert(Date(-1999, 12, 1).daysInMonth == 31);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate.daysInMonth = 30));
        static assert(!__traits(compiles, idate.daysInMonth = 30));
    }


    /++
        Whether the current year is a date in A.D.
      +/
    @property bool isAD() @safe const pure nothrow
    {
        return _year > 0;
    }

    ///
    @safe unittest
    {
        assert(Date(1, 1, 1).isAD);
        assert(Date(2010, 12, 31).isAD);
        assert(!Date(0, 12, 31).isAD);
        assert(!Date(-2010, 1, 1).isAD);
    }

    @safe unittest
    {
        assert(Date(2010, 7, 4).isAD);
        assert(Date(1, 1, 1).isAD);
        assert(!Date(0, 1, 1).isAD);
        assert(!Date(-1, 1, 1).isAD);
        assert(!Date(-2010, 7, 4).isAD);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.isAD);
        assert(idate.isAD);
    }


    /++
        The $(HTTP en.wikipedia.org/wiki/Julian_day, Julian day) for this
        $(LREF Date) at noon (since the Julian day changes at noon).
      +/
    @property long julianDay() @safe const pure nothrow
    {
        return dayOfGregorianCal + 1_721_425;
    }

    @safe unittest
    {
        assert(Date(-4713, 11, 24).julianDay == 0);
        assert(Date(0, 12, 31).julianDay == 1_721_425);
        assert(Date(1, 1, 1).julianDay == 1_721_426);
        assert(Date(1582, 10, 15).julianDay == 2_299_161);
        assert(Date(1858, 11, 17).julianDay == 2_400_001);
        assert(Date(1982, 1, 4).julianDay == 2_444_974);
        assert(Date(1996, 3, 31).julianDay == 2_450_174);
        assert(Date(2010, 8, 24).julianDay == 2_455_433);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.julianDay == 2_451_366);
        assert(idate.julianDay == 2_451_366);
    }


    /++
        The modified $(HTTP en.wikipedia.org/wiki/Julian_day, Julian day) for
        any time on this date (since, the modified Julian day changes at
        midnight).
      +/
    @property long modJulianDay() @safe const pure nothrow
    {
        return julianDay - 2_400_001;
    }

    @safe unittest
    {
        assert(Date(1858, 11, 17).modJulianDay == 0);
        assert(Date(2010, 8, 24).modJulianDay == 55_432);

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.modJulianDay == 51_365);
        assert(idate.modJulianDay == 51_365);
    }


    /++
        Converts this $(LREF Date) to a string with the format YYYYMMDD.
      +/
    string toISOString() @safe const pure nothrow
    {
        import std.format : format;
        try
        {
            if (_year >= 0)
            {
                if (_year < 10_000)
                    return format("%04d%02d%02d", _year, _month, _day);
                else
                    return format("+%05d%02d%02d", _year, _month, _day);
            }
            else if (_year > -10_000)
                return format("%05d%02d%02d", _year, _month, _day);
            else
                return format("%06d%02d%02d", _year, _month, _day);
        }
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(Date(2010, 7, 4).toISOString() == "20100704");
        assert(Date(1998, 12, 25).toISOString() == "19981225");
        assert(Date(0, 1, 5).toISOString() == "00000105");
        assert(Date(-4, 1, 5).toISOString() == "-00040105");
    }

    @safe unittest
    {
        // Test A.D.
        assert(Date(9, 12, 4).toISOString() == "00091204");
        assert(Date(99, 12, 4).toISOString() == "00991204");
        assert(Date(999, 12, 4).toISOString() == "09991204");
        assert(Date(9999, 7, 4).toISOString() == "99990704");
        assert(Date(10000, 10, 20).toISOString() == "+100001020");

        // Test B.C.
        assert(Date(0, 12, 4).toISOString() == "00001204");
        assert(Date(-9, 12, 4).toISOString() == "-00091204");
        assert(Date(-99, 12, 4).toISOString() == "-00991204");
        assert(Date(-999, 12, 4).toISOString() == "-09991204");
        assert(Date(-9999, 7, 4).toISOString() == "-99990704");
        assert(Date(-10000, 10, 20).toISOString() == "-100001020");

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.toISOString() == "19990706");
        assert(idate.toISOString() == "19990706");
    }

    /++
        Converts this $(LREF Date) to a string with the format YYYY-MM-DD.
      +/
    string toISOExtString() @safe const pure nothrow
    {
        import std.format : format;
        try
        {
            if (_year >= 0)
            {
                if (_year < 10_000)
                    return format("%04d-%02d-%02d", _year, _month, _day);
                else
                    return format("+%05d-%02d-%02d", _year, _month, _day);
            }
            else if (_year > -10_000)
                return format("%05d-%02d-%02d", _year, _month, _day);
            else
                return format("%06d-%02d-%02d", _year, _month, _day);
        }
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(Date(2010, 7, 4).toISOExtString() == "2010-07-04");
        assert(Date(1998, 12, 25).toISOExtString() == "1998-12-25");
        assert(Date(0, 1, 5).toISOExtString() == "0000-01-05");
        assert(Date(-4, 1, 5).toISOExtString() == "-0004-01-05");
    }

    @safe unittest
    {
        // Test A.D.
        assert(Date(9, 12, 4).toISOExtString() == "0009-12-04");
        assert(Date(99, 12, 4).toISOExtString() == "0099-12-04");
        assert(Date(999, 12, 4).toISOExtString() == "0999-12-04");
        assert(Date(9999, 7, 4).toISOExtString() == "9999-07-04");
        assert(Date(10000, 10, 20).toISOExtString() == "+10000-10-20");

        // Test B.C.
        assert(Date(0, 12, 4).toISOExtString() == "0000-12-04");
        assert(Date(-9, 12, 4).toISOExtString() == "-0009-12-04");
        assert(Date(-99, 12, 4).toISOExtString() == "-0099-12-04");
        assert(Date(-999, 12, 4).toISOExtString() == "-0999-12-04");
        assert(Date(-9999, 7, 4).toISOExtString() == "-9999-07-04");
        assert(Date(-10000, 10, 20).toISOExtString() == "-10000-10-20");

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.toISOExtString() == "1999-07-06");
        assert(idate.toISOExtString() == "1999-07-06");
    }

    /++
        Converts this $(LREF Date) to a string with the format YYYY-Mon-DD.
      +/
    string toSimpleString() @safe const pure nothrow
    {
        import std.format : format;
        try
        {
            if (_year >= 0)
            {
                if (_year < 10_000)
                    return format("%04d-%s-%02d", _year, monthToString(_month), _day);
                else
                    return format("+%05d-%s-%02d", _year, monthToString(_month), _day);
            }
            else if (_year > -10_000)
                return format("%05d-%s-%02d", _year, monthToString(_month), _day);
            else
                return format("%06d-%s-%02d", _year, monthToString(_month), _day);
        }
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(Date(2010, 7, 4).toSimpleString() == "2010-Jul-04");
        assert(Date(1998, 12, 25).toSimpleString() == "1998-Dec-25");
        assert(Date(0, 1, 5).toSimpleString() == "0000-Jan-05");
        assert(Date(-4, 1, 5).toSimpleString() == "-0004-Jan-05");
    }

    @safe unittest
    {
        // Test A.D.
        assert(Date(9, 12, 4).toSimpleString() == "0009-Dec-04");
        assert(Date(99, 12, 4).toSimpleString() == "0099-Dec-04");
        assert(Date(999, 12, 4).toSimpleString() == "0999-Dec-04");
        assert(Date(9999, 7, 4).toSimpleString() == "9999-Jul-04");
        assert(Date(10000, 10, 20).toSimpleString() == "+10000-Oct-20");

        // Test B.C.
        assert(Date(0, 12, 4).toSimpleString() == "0000-Dec-04");
        assert(Date(-9, 12, 4).toSimpleString() == "-0009-Dec-04");
        assert(Date(-99, 12, 4).toSimpleString() == "-0099-Dec-04");
        assert(Date(-999, 12, 4).toSimpleString() == "-0999-Dec-04");
        assert(Date(-9999, 7, 4).toSimpleString() == "-9999-Jul-04");
        assert(Date(-10000, 10, 20).toSimpleString() == "-10000-Oct-20");

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(cdate.toSimpleString() == "1999-Jul-06");
        assert(idate.toSimpleString() == "1999-Jul-06");
    }


    /++
        Converts this $(LREF Date) to a string.
      +/
    string toString() @safe const pure nothrow
    {
        return toSimpleString();
    }

    @safe unittest
    {
        auto date = Date(1999, 7, 6);
        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        assert(date.toString());
        assert(cdate.toString());
        assert(idate.toString());
    }


    /++
        Creates a $(LREF Date) from a string with the format YYYYMMDD. Whitespace
        is stripped from the given string.

        Params:
            isoString = A string formatted in the ISO format for dates.

        Throws:
            $(REF std,datetime,common,DateTimeException) if the given string is
            not in the ISO format or if the resulting $(LREF Date) would not be
            valid.
      +/
    static Date fromISOString(S)(in S isoString) @safe pure
        if (isSomeString!S)
    {
        import std.algorithm.searching : all, startsWith;
        import std.ascii : isDigit;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        auto dstr = to!dstring(strip(isoString));

        enforce(dstr.length >= 8, new DateTimeException(format("Invalid ISO String: %s", isoString)));

        auto day = dstr[$-2 .. $];
        auto month = dstr[$-4 .. $-2];
        auto year = dstr[0 .. $-4];

        enforce(all!isDigit(day), new DateTimeException(format("Invalid ISO String: %s", isoString)));
        enforce(all!isDigit(month), new DateTimeException(format("Invalid ISO String: %s", isoString)));

        if (year.length > 4)
        {
            enforce(year.startsWith('-', '+'),
                    new DateTimeException(format("Invalid ISO String: %s", isoString)));
            enforce(all!isDigit(year[1..$]),
                    new DateTimeException(format("Invalid ISO String: %s", isoString)));
        }
        else
            enforce(all!isDigit(year), new DateTimeException(format("Invalid ISO String: %s", isoString)));

        return Date(to!short(year), to!ubyte(month), to!ubyte(day));
    }

    ///
    @safe unittest
    {
        assert(Date.fromISOString("20100704") == Date(2010, 7, 4));
        assert(Date.fromISOString("19981225") == Date(1998, 12, 25));
        assert(Date.fromISOString("00000105") == Date(0, 1, 5));
        assert(Date.fromISOString("-00040105") == Date(-4, 1, 5));
        assert(Date.fromISOString(" 20100704 ") == Date(2010, 7, 4));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(Date.fromISOString(""));
        assertThrown!DateTimeException(Date.fromISOString("990704"));
        assertThrown!DateTimeException(Date.fromISOString("0100704"));
        assertThrown!DateTimeException(Date.fromISOString("2010070"));
        assertThrown!DateTimeException(Date.fromISOString("2010070 "));
        assertThrown!DateTimeException(Date.fromISOString("120100704"));
        assertThrown!DateTimeException(Date.fromISOString("-0100704"));
        assertThrown!DateTimeException(Date.fromISOString("+0100704"));
        assertThrown!DateTimeException(Date.fromISOString("2010070a"));
        assertThrown!DateTimeException(Date.fromISOString("20100a04"));
        assertThrown!DateTimeException(Date.fromISOString("2010a704"));

        assertThrown!DateTimeException(Date.fromISOString("99-07-04"));
        assertThrown!DateTimeException(Date.fromISOString("010-07-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-07-0"));
        assertThrown!DateTimeException(Date.fromISOString("2010-07-0 "));
        assertThrown!DateTimeException(Date.fromISOString("12010-07-04"));
        assertThrown!DateTimeException(Date.fromISOString("-010-07-04"));
        assertThrown!DateTimeException(Date.fromISOString("+010-07-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-07-0a"));
        assertThrown!DateTimeException(Date.fromISOString("2010-0a-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-a7-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010/07/04"));
        assertThrown!DateTimeException(Date.fromISOString("2010/7/04"));
        assertThrown!DateTimeException(Date.fromISOString("2010/7/4"));
        assertThrown!DateTimeException(Date.fromISOString("2010/07/4"));
        assertThrown!DateTimeException(Date.fromISOString("2010-7-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-7-4"));
        assertThrown!DateTimeException(Date.fromISOString("2010-07-4"));

        assertThrown!DateTimeException(Date.fromISOString("99Jul04"));
        assertThrown!DateTimeException(Date.fromISOString("010Jul04"));
        assertThrown!DateTimeException(Date.fromISOString("2010Jul0"));
        assertThrown!DateTimeException(Date.fromISOString("2010Jul0 "));
        assertThrown!DateTimeException(Date.fromISOString("12010Jul04"));
        assertThrown!DateTimeException(Date.fromISOString("-010Jul04"));
        assertThrown!DateTimeException(Date.fromISOString("+010Jul04"));
        assertThrown!DateTimeException(Date.fromISOString("2010Jul0a"));
        assertThrown!DateTimeException(Date.fromISOString("2010Jua04"));
        assertThrown!DateTimeException(Date.fromISOString("2010aul04"));

        assertThrown!DateTimeException(Date.fromISOString("99-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOString("010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-Jul-0"));
        assertThrown!DateTimeException(Date.fromISOString("2010-Jul-0 "));
        assertThrown!DateTimeException(Date.fromISOString("12010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOString("-010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOString("+010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-Jul-0a"));
        assertThrown!DateTimeException(Date.fromISOString("2010-Jua-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-Jal-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-aul-04"));

        assertThrown!DateTimeException(Date.fromISOString("2010-07-04"));
        assertThrown!DateTimeException(Date.fromISOString("2010-Jul-04"));

        assert(Date.fromISOString("19990706") == Date(1999, 7, 6));
        assert(Date.fromISOString("-19990706") == Date(-1999, 7, 6));
        assert(Date.fromISOString("+019990706") == Date(1999, 7, 6));
        assert(Date.fromISOString("19990706 ") == Date(1999, 7, 6));
        assert(Date.fromISOString(" 19990706") == Date(1999, 7, 6));
        assert(Date.fromISOString(" 19990706 ") == Date(1999, 7, 6));
    }


    /++
        Creates a $(LREF Date) from a string with the format YYYY-MM-DD.
        Whitespace is stripped from the given string.

        Params:
            isoExtString = A string formatted in the ISO Extended format for
                           dates.

        Throws:
            $(REF std,datetime,common,DateTimeException) if the given string is
            not in the ISO Extended format or if the resulting $(LREF Date)
            would not be valid.
      +/
    static Date fromISOExtString(S)(in S isoExtString) @safe pure
        if (isSomeString!(S))
    {
        import std.algorithm.searching : all, startsWith;
        import std.ascii : isDigit;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        auto dstr = to!dstring(strip(isoExtString));

        enforce(dstr.length >= 10, new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));

        auto day = dstr[$-2 .. $];
        auto month = dstr[$-5 .. $-3];
        auto year = dstr[0 .. $-6];

        enforce(dstr[$-3] == '-', new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        enforce(dstr[$-6] == '-', new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        enforce(all!isDigit(day),
                new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        enforce(all!isDigit(month),
                new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));

        if (year.length > 4)
        {
            enforce(year.startsWith('-', '+'),
                    new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
            enforce(all!isDigit(year[1..$]),
                    new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        }
        else
            enforce(all!isDigit(year),
                    new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));

        return Date(to!short(year), to!ubyte(month), to!ubyte(day));
    }

    ///
    @safe unittest
    {
        assert(Date.fromISOExtString("2010-07-04") == Date(2010, 7, 4));
        assert(Date.fromISOExtString("1998-12-25") == Date(1998, 12, 25));
        assert(Date.fromISOExtString("0000-01-05") == Date(0, 1, 5));
        assert(Date.fromISOExtString("-0004-01-05") == Date(-4, 1, 5));
        assert(Date.fromISOExtString(" 2010-07-04 ") == Date(2010, 7, 4));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(Date.fromISOExtString(""));
        assertThrown!DateTimeException(Date.fromISOExtString("990704"));
        assertThrown!DateTimeException(Date.fromISOExtString("0100704"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010070"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010070 "));
        assertThrown!DateTimeException(Date.fromISOExtString("120100704"));
        assertThrown!DateTimeException(Date.fromISOExtString("-0100704"));
        assertThrown!DateTimeException(Date.fromISOExtString("+0100704"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010070a"));
        assertThrown!DateTimeException(Date.fromISOExtString("20100a04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010a704"));

        assertThrown!DateTimeException(Date.fromISOExtString("99-07-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("010-07-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-07-0"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-07-0 "));
        assertThrown!DateTimeException(Date.fromISOExtString("12010-07-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("-010-07-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("+010-07-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-07-0a"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-0a-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-a7-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010/07/04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010/7/04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010/7/4"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010/07/4"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-7-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-7-4"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-07-4"));

        assertThrown!DateTimeException(Date.fromISOExtString("99Jul04"));
        assertThrown!DateTimeException(Date.fromISOExtString("010Jul04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010Jul0"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-Jul-0 "));
        assertThrown!DateTimeException(Date.fromISOExtString("12010Jul04"));
        assertThrown!DateTimeException(Date.fromISOExtString("-010Jul04"));
        assertThrown!DateTimeException(Date.fromISOExtString("+010Jul04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010Jul0a"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010Jua04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010aul04"));

        assertThrown!DateTimeException(Date.fromISOExtString("99-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-Jul-0"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010Jul0 "));
        assertThrown!DateTimeException(Date.fromISOExtString("12010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("-010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("+010-Jul-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-Jul-0a"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-Jua-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-Jal-04"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-aul-04"));

        assertThrown!DateTimeException(Date.fromISOExtString("20100704"));
        assertThrown!DateTimeException(Date.fromISOExtString("2010-Jul-04"));

        assert(Date.fromISOExtString("1999-07-06") == Date(1999, 7, 6));
        assert(Date.fromISOExtString("-1999-07-06") == Date(-1999, 7, 6));
        assert(Date.fromISOExtString("+01999-07-06") == Date(1999, 7, 6));
        assert(Date.fromISOExtString("1999-07-06 ") == Date(1999, 7, 6));
        assert(Date.fromISOExtString(" 1999-07-06") == Date(1999, 7, 6));
        assert(Date.fromISOExtString(" 1999-07-06 ") == Date(1999, 7, 6));
    }


    /++
        Creates a $(LREF Date) from a string with the format YYYY-Mon-DD.
        Whitespace is stripped from the given string.

        Params:
            simpleString = A string formatted in the way that toSimpleString
                           formats dates.

        Throws:
            $(REF std,datetime,common,DateTimeException) if the given string is
            not in the correct format or if the resulting $(LREF Date) would not
            be valid.
      +/
    static Date fromSimpleString(S)(in S simpleString) @safe pure
        if (isSomeString!(S))
    {
        import std.algorithm.searching : all, startsWith;
        import std.ascii : isDigit;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        auto dstr = to!dstring(strip(simpleString));

        enforce(dstr.length >= 11, new DateTimeException(format("Invalid string format: %s", simpleString)));

        auto day = dstr[$-2 .. $];
        auto month = monthFromString(to!string(dstr[$-6 .. $-3]));
        auto year = dstr[0 .. $-7];

        enforce(dstr[$-3] == '-', new DateTimeException(format("Invalid string format: %s", simpleString)));
        enforce(dstr[$-7] == '-', new DateTimeException(format("Invalid string format: %s", simpleString)));
        enforce(all!isDigit(day), new DateTimeException(format("Invalid string format: %s", simpleString)));

        if (year.length > 4)
        {
            enforce(year.startsWith('-', '+'),
                    new DateTimeException(format("Invalid string format: %s", simpleString)));
            enforce(all!isDigit(year[1..$]),
                    new DateTimeException(format("Invalid string format: %s", simpleString)));
        }
        else
            enforce(all!isDigit(year),
                    new DateTimeException(format("Invalid string format: %s", simpleString)));

        return Date(to!short(year), month, to!ubyte(day));
    }

    ///
    @safe unittest
    {
        assert(Date.fromSimpleString("2010-Jul-04") == Date(2010, 7, 4));
        assert(Date.fromSimpleString("1998-Dec-25") == Date(1998, 12, 25));
        assert(Date.fromSimpleString("0000-Jan-05") == Date(0, 1, 5));
        assert(Date.fromSimpleString("-0004-Jan-05") == Date(-4, 1, 5));
        assert(Date.fromSimpleString(" 2010-Jul-04 ") == Date(2010, 7, 4));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(Date.fromSimpleString(""));
        assertThrown!DateTimeException(Date.fromSimpleString("990704"));
        assertThrown!DateTimeException(Date.fromSimpleString("0100704"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010070"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010070 "));
        assertThrown!DateTimeException(Date.fromSimpleString("120100704"));
        assertThrown!DateTimeException(Date.fromSimpleString("-0100704"));
        assertThrown!DateTimeException(Date.fromSimpleString("+0100704"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010070a"));
        assertThrown!DateTimeException(Date.fromSimpleString("20100a04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010a704"));

        assertThrown!DateTimeException(Date.fromSimpleString("99-07-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("010-07-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-07-0"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-07-0 "));
        assertThrown!DateTimeException(Date.fromSimpleString("12010-07-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("-010-07-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("+010-07-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-07-0a"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-0a-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-a7-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010/07/04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010/7/04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010/7/4"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010/07/4"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-7-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-7-4"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-07-4"));

        assertThrown!DateTimeException(Date.fromSimpleString("99Jul04"));
        assertThrown!DateTimeException(Date.fromSimpleString("010Jul04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010Jul0"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010Jul0 "));
        assertThrown!DateTimeException(Date.fromSimpleString("12010Jul04"));
        assertThrown!DateTimeException(Date.fromSimpleString("-010Jul04"));
        assertThrown!DateTimeException(Date.fromSimpleString("+010Jul04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010Jul0a"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010Jua04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010aul04"));

        assertThrown!DateTimeException(Date.fromSimpleString("99-Jul-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("010-Jul-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-Jul-0"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-Jul-0 "));
        assertThrown!DateTimeException(Date.fromSimpleString("12010-Jul-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("-010-Jul-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("+010-Jul-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-Jul-0a"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-Jua-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-Jal-04"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-aul-04"));

        assertThrown!DateTimeException(Date.fromSimpleString("20100704"));
        assertThrown!DateTimeException(Date.fromSimpleString("2010-07-04"));

        assert(Date.fromSimpleString("1999-Jul-06") == Date(1999, 7, 6));
        assert(Date.fromSimpleString("-1999-Jul-06") == Date(-1999, 7, 6));
        assert(Date.fromSimpleString("+01999-Jul-06") == Date(1999, 7, 6));
        assert(Date.fromSimpleString("1999-Jul-06 ") == Date(1999, 7, 6));
        assert(Date.fromSimpleString(" 1999-Jul-06") == Date(1999, 7, 6));
        assert(Date.fromSimpleString(" 1999-Jul-06 ") == Date(1999, 7, 6));
    }


    /++
        Returns the $(LREF Date) farthest in the past which is representable by
        $(LREF Date).
      +/
    @property static Date min() @safe pure nothrow
    {
        auto date = Date.init;
        date._year = short.min;
        date._month = Month.jan;
        date._day = 1;

        return date;
    }

    @safe unittest
    {
        assert(Date.min.year < 0);
        assert(Date.min < Date.max);
    }


    /++
        Returns the $(LREF Date) farthest in the future which is representable
        by $(LREF Date).
      +/
    @property static Date max() @safe pure nothrow
    {
        auto date = Date.init;
        date._year = short.max;
        date._month = Month.dec;
        date._day = 31;

        return date;
    }

    @safe unittest
    {
        assert(Date.max.year > 0);
        assert(Date.max > Date.min);
    }


private:

    /+
        Whether the given values form a valid date.

        Params:
            year  = The year to test.
            month = The month of the Gregorian Calendar to test.
            day   = The day of the month to test.
     +/
    static bool _valid(int year, int month, int day) @safe pure nothrow
    {
        if (!valid!"months"(month))
            return false;
        return valid!"days"(year, month, day);
    }


package:

    /+
        Adds the given number of days to this $(LREF Date). A negative number
        will subtract.

        The month will be adjusted along with the day if the number of days
        added (or subtracted) would overflow (or underflow) the current month.
        The year will be adjusted along with the month if the increase (or
        decrease) to the month would cause it to overflow (or underflow) the
        current year.

        $(D _addDays(numDays)) is effectively equivalent to
        $(D date.dayOfGregorianCal = date.dayOfGregorianCal + days).

        Params:
            days = The number of days to add to this Date.
      +/
    ref Date _addDays(long days) return @safe pure nothrow
    {
        dayOfGregorianCal = cast(int)(dayOfGregorianCal + days);
        return this;
    }

    @safe unittest
    {
        // Test A.D.
        {
            auto date = Date(1999, 2, 28);
            date._addDays(1);
            assert(date == Date(1999, 3, 1));
            date._addDays(-1);
            assert(date == Date(1999, 2, 28));
        }

        {
            auto date = Date(2000, 2, 28);
            date._addDays(1);
            assert(date == Date(2000, 2, 29));
            date._addDays(1);
            assert(date == Date(2000, 3, 1));
            date._addDays(-1);
            assert(date == Date(2000, 2, 29));
        }

        {
            auto date = Date(1999, 6, 30);
            date._addDays(1);
            assert(date == Date(1999, 7, 1));
            date._addDays(-1);
            assert(date == Date(1999, 6, 30));
        }

        {
            auto date = Date(1999, 7, 31);
            date._addDays(1);
            assert(date == Date(1999, 8, 1));
            date._addDays(-1);
            assert(date == Date(1999, 7, 31));
        }

        {
            auto date = Date(1999, 1, 1);
            date._addDays(-1);
            assert(date == Date(1998, 12, 31));
            date._addDays(1);
            assert(date == Date(1999, 1, 1));
        }

        {
            auto date = Date(1999, 7, 6);
            date._addDays(9);
            assert(date == Date(1999, 7, 15));
            date._addDays(-11);
            assert(date == Date(1999, 7, 4));
            date._addDays(30);
            assert(date == Date(1999, 8, 3));
            date._addDays(-3);
            assert(date == Date(1999, 7, 31));
        }

        {
            auto date = Date(1999, 7, 6);
            date._addDays(365);
            assert(date == Date(2000, 7, 5));
            date._addDays(-365);
            assert(date == Date(1999, 7, 6));
            date._addDays(366);
            assert(date == Date(2000, 7, 6));
            date._addDays(730);
            assert(date == Date(2002, 7, 6));
            date._addDays(-1096);
            assert(date == Date(1999, 7, 6));
        }

        // Test B.C.
        {
            auto date = Date(-1999, 2, 28);
            date._addDays(1);
            assert(date == Date(-1999, 3, 1));
            date._addDays(-1);
            assert(date == Date(-1999, 2, 28));
        }

        {
            auto date = Date(-2000, 2, 28);
            date._addDays(1);
            assert(date == Date(-2000, 2, 29));
            date._addDays(1);
            assert(date == Date(-2000, 3, 1));
            date._addDays(-1);
            assert(date == Date(-2000, 2, 29));
        }

        {
            auto date = Date(-1999, 6, 30);
            date._addDays(1);
            assert(date == Date(-1999, 7, 1));
            date._addDays(-1);
            assert(date == Date(-1999, 6, 30));
        }

        {
            auto date = Date(-1999, 7, 31);
            date._addDays(1);
            assert(date == Date(-1999, 8, 1));
            date._addDays(-1);
            assert(date == Date(-1999, 7, 31));
        }

        {
            auto date = Date(-1999, 1, 1);
            date._addDays(-1);
            assert(date == Date(-2000, 12, 31));
            date._addDays(1);
            assert(date == Date(-1999, 1, 1));
        }

        {
            auto date = Date(-1999, 7, 6);
            date._addDays(9);
            assert(date == Date(-1999, 7, 15));
            date._addDays(-11);
            assert(date == Date(-1999, 7, 4));
            date._addDays(30);
            assert(date == Date(-1999, 8, 3));
            date._addDays(-3);
        }

        {
            auto date = Date(-1999, 7, 6);
            date._addDays(365);
            assert(date == Date(-1998, 7, 6));
            date._addDays(-365);
            assert(date == Date(-1999, 7, 6));
            date._addDays(366);
            assert(date == Date(-1998, 7, 7));
            date._addDays(730);
            assert(date == Date(-1996, 7, 6));
            date._addDays(-1096);
            assert(date == Date(-1999, 7, 6));
        }

        // Test Both
        {
            auto date = Date(1, 7, 6);
            date._addDays(-365);
            assert(date == Date(0, 7, 6));
            date._addDays(365);
            assert(date == Date(1, 7, 6));
            date._addDays(-731);
            assert(date == Date(-1, 7, 6));
            date._addDays(730);
            assert(date == Date(1, 7, 5));
        }

        const cdate = Date(1999, 7, 6);
        immutable idate = Date(1999, 7, 6);
        static assert(!__traits(compiles, cdate._addDays(12)));
        static assert(!__traits(compiles, idate._addDays(12)));
    }


    @safe pure invariant()
    {
        import std.format : format;
        assert(valid!"months"(_month),
               format("Invariant Failure: year [%s] month [%s] day [%s]", _year, _month, _day));
        assert(valid!"days"(_year, _month, _day),
               format("Invariant Failure: year [%s] month [%s] day [%s]", _year, _month, _day));
    }

    short _year  = 1;
    Month _month = Month.jan;
    ubyte _day   = 1;
}


package:

/+
    Returns the day of the week for the given day of the Gregorian Calendar.

    Params:
        day = The day of the Gregorian Calendar for which to get the day of
              the week.
  +/
DayOfWeek getDayOfWeek(int day) @safe pure nothrow
{
    // January 1st, 1 A.D. was a Monday
    if (day >= 0)
        return cast(DayOfWeek)(day % 7);
    else
    {
        immutable dow = cast(DayOfWeek)((day % 7) + 7);

        if (dow == 7)
            return DayOfWeek.sun;
        else
            return dow;
    }
}

@safe unittest
{
    import std.datetime.systime : SysTime;

    // Test A.D.
    assert(getDayOfWeek(SysTime(Date(1, 1, 1)).dayOfGregorianCal) == DayOfWeek.mon);
    assert(getDayOfWeek(SysTime(Date(1, 1, 2)).dayOfGregorianCal) == DayOfWeek.tue);
    assert(getDayOfWeek(SysTime(Date(1, 1, 3)).dayOfGregorianCal) == DayOfWeek.wed);
    assert(getDayOfWeek(SysTime(Date(1, 1, 4)).dayOfGregorianCal) == DayOfWeek.thu);
    assert(getDayOfWeek(SysTime(Date(1, 1, 5)).dayOfGregorianCal) == DayOfWeek.fri);
    assert(getDayOfWeek(SysTime(Date(1, 1, 6)).dayOfGregorianCal) == DayOfWeek.sat);
    assert(getDayOfWeek(SysTime(Date(1, 1, 7)).dayOfGregorianCal) == DayOfWeek.sun);
    assert(getDayOfWeek(SysTime(Date(1, 1, 8)).dayOfGregorianCal) == DayOfWeek.mon);
    assert(getDayOfWeek(SysTime(Date(1, 1, 9)).dayOfGregorianCal) == DayOfWeek.tue);
    assert(getDayOfWeek(SysTime(Date(2, 1, 1)).dayOfGregorianCal) == DayOfWeek.tue);
    assert(getDayOfWeek(SysTime(Date(3, 1, 1)).dayOfGregorianCal) == DayOfWeek.wed);
    assert(getDayOfWeek(SysTime(Date(4, 1, 1)).dayOfGregorianCal) == DayOfWeek.thu);
    assert(getDayOfWeek(SysTime(Date(5, 1, 1)).dayOfGregorianCal) == DayOfWeek.sat);
    assert(getDayOfWeek(SysTime(Date(2000, 1, 1)).dayOfGregorianCal) == DayOfWeek.sat);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 22)).dayOfGregorianCal) == DayOfWeek.sun);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 23)).dayOfGregorianCal) == DayOfWeek.mon);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 24)).dayOfGregorianCal) == DayOfWeek.tue);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 25)).dayOfGregorianCal) == DayOfWeek.wed);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 26)).dayOfGregorianCal) == DayOfWeek.thu);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 27)).dayOfGregorianCal) == DayOfWeek.fri);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 28)).dayOfGregorianCal) == DayOfWeek.sat);
    assert(getDayOfWeek(SysTime(Date(2010, 8, 29)).dayOfGregorianCal) == DayOfWeek.sun);

    // Test B.C.
    assert(getDayOfWeek(SysTime(Date(0, 12, 31)).dayOfGregorianCal) == DayOfWeek.sun);
    assert(getDayOfWeek(SysTime(Date(0, 12, 30)).dayOfGregorianCal) == DayOfWeek.sat);
    assert(getDayOfWeek(SysTime(Date(0, 12, 29)).dayOfGregorianCal) == DayOfWeek.fri);
    assert(getDayOfWeek(SysTime(Date(0, 12, 28)).dayOfGregorianCal) == DayOfWeek.thu);
    assert(getDayOfWeek(SysTime(Date(0, 12, 27)).dayOfGregorianCal) == DayOfWeek.wed);
    assert(getDayOfWeek(SysTime(Date(0, 12, 26)).dayOfGregorianCal) == DayOfWeek.tue);
    assert(getDayOfWeek(SysTime(Date(0, 12, 25)).dayOfGregorianCal) == DayOfWeek.mon);
    assert(getDayOfWeek(SysTime(Date(0, 12, 24)).dayOfGregorianCal) == DayOfWeek.sun);
    assert(getDayOfWeek(SysTime(Date(0, 12, 23)).dayOfGregorianCal) == DayOfWeek.sat);
}


private:

enum daysInYear     = 365;  // The number of days in a non-leap year.
enum daysInLeapYear = 366;  // The numbef or days in a leap year.
enum daysIn4Years   = daysInYear * 3 + daysInLeapYear;  // Number of days in 4 years.
enum daysIn100Years = daysIn4Years * 25 - 1;  // The number of days in 100 years.
enum daysIn400Years = daysIn100Years * 4 + 1; // The number of days in 400 years.

/+
    Array of integers representing the last days of each month in a year.
  +/
immutable int[13] lastDayNonLeap = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365];

/+
    Array of integers representing the last days of each month in a leap year.
  +/
immutable int[13] lastDayLeap = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366];


/+
    Returns the string representation of the given month.
  +/
string monthToString(Month month) @safe pure
{
    import std.format : format;
    assert(month >= Month.jan && month <= Month.dec, format("Invalid month: %s", month));
    return _monthNames[month - Month.jan];
}

@safe unittest
{
    assert(monthToString(Month.jan) == "Jan");
    assert(monthToString(Month.feb) == "Feb");
    assert(monthToString(Month.mar) == "Mar");
    assert(monthToString(Month.apr) == "Apr");
    assert(monthToString(Month.may) == "May");
    assert(monthToString(Month.jun) == "Jun");
    assert(monthToString(Month.jul) == "Jul");
    assert(monthToString(Month.aug) == "Aug");
    assert(monthToString(Month.sep) == "Sep");
    assert(monthToString(Month.oct) == "Oct");
    assert(monthToString(Month.nov) == "Nov");
    assert(monthToString(Month.dec) == "Dec");
}


/+
    Returns the Month corresponding to the given string.

    Params:
        monthStr = The string representation of the month to get the Month for.

    Throws:
        $(REF std,datetime,common,DateTimeException) if the given month is not a
        valid month string.
  +/
Month monthFromString(string monthStr) @safe pure
{
    import std.format : format;
    switch (monthStr)
    {
        case "Jan":
            return Month.jan;
        case "Feb":
            return Month.feb;
        case "Mar":
            return Month.mar;
        case "Apr":
            return Month.apr;
        case "May":
            return Month.may;
        case "Jun":
            return Month.jun;
        case "Jul":
            return Month.jul;
        case "Aug":
            return Month.aug;
        case "Sep":
            return Month.sep;
        case "Oct":
            return Month.oct;
        case "Nov":
            return Month.nov;
        case "Dec":
            return Month.dec;
        default:
            throw new DateTimeException(format("Invalid month %s", monthStr));
    }
}

@safe unittest
{
    import std.stdio : writeln;
    import std.traits : EnumMembers;
    foreach (badStr; ["Ja", "Janu", "Januar", "Januarys", "JJanuary", "JANUARY",
                      "JAN", "january", "jaNuary", "jaN", "jaNuaRy", "jAn"])
    {
        scope(failure) writeln(badStr);
        assertThrown!DateTimeException(monthFromString(badStr));
    }

    foreach (month; EnumMembers!Month)
    {
        scope(failure) writeln(month);
        assert(monthFromString(monthToString(month)) == month);
    }
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

    Date[] testDatesBC;
    Date[] testDatesAD;

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
    }
}
