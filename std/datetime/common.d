// Written in the D programming language

/++
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis
    Source:    $(PHOBOSSRC std/_datetime.d)
    Macros:
        LREF2=<a href="#$1">$(D $2)</a>
+/
module std.datetime.common;

import core.time : TimeException;
import std.typecons : Flag;


/++
    Exception type used by std.datetime. It's an alias to $(REF TimeException, core,time).
    Either can be caught without concern about which
    module it came from.
  +/
alias DateTimeException = TimeException;


/++
    Represents the 12 months of the Gregorian year (January is 1).
  +/
enum Month : ubyte { jan = 1, ///
                     feb,     ///
                     mar,     ///
                     apr,     ///
                     may,     ///
                     jun,     ///
                     jul,     ///
                     aug,     ///
                     sep,     ///
                     oct,     ///
                     nov,     ///
                     dec      ///
                   }


/++
    Represents the 7 days of the Gregorian week (Sunday is 0).
  +/
enum DayOfWeek : ubyte { sun = 0, ///
                         mon,     ///
                         tue,     ///
                         wed,     ///
                         thu,     ///
                         fri,     ///
                         sat      ///
                       }


/++
    In some date calculations, adding months or years can cause the date to fall
    on a day of the month which is not valid (e.g. February 29th 2001 or
    June 31st 2000). If overflow is allowed (as is the default), then the month
    will be incremented accordingly (so, February 29th 2001 would become
    March 1st 2001, and June 31st 2000 would become July 1st 2000). If overflow
    is not allowed, then the day will be adjusted to the last valid day in that
    month (so, February 29th 2001 would become February 28th 2001 and
    June 31st 2000 would become June 30th 2000).

    AllowDayOverflow only applies to calculations involving months or years.

    If set to $(D AllowDayOverflow.no), then day overflow is not allowed.

    Otherwise, if set to $(D AllowDayOverflow.yes), then day overflow is
    allowed.
  +/
alias AllowDayOverflow = Flag!"allowDayOverflow";


/++
    Array of the strings representing time units, starting with the smallest
    unit and going to the largest. It does not include $(D "nsecs").

   Includes $(D "hnsecs") (hecto-nanoseconds (100 ns)),
   $(D "usecs") (microseconds), $(D "msecs") (milliseconds), $(D "seconds"),
   $(D "minutes"), $(D "hours"), $(D "days"), $(D "weeks"), $(D "months"), and
   $(D "years")
  +/
immutable string[] timeStrings = ["hnsecs", "usecs", "msecs", "seconds", "minutes",
                                  "hours", "days", "weeks", "months", "years"];


/++
    Returns whether the given value is valid for the given unit type when in a
    time point. Naturally, a duration is not held to a particular range, but
    the values in a time point are (e.g. a month must be in the range of
    1 - 12 inclusive).

    Params:
        units = The units of time to validate.
        value = The number to validate.
  +/
bool valid(string units)(int value) @safe pure nothrow
if (units == "months" ||
    units == "hours" ||
    units == "minutes" ||
    units == "seconds")
{
    static if (units == "months")
        return value >= Month.jan && value <= Month.dec;
    else static if (units == "hours")
        return value >= 0 && value <= 23;
    else static if (units == "minutes")
        return value >= 0 && value <= 59;
    else static if (units == "seconds")
        return value >= 0 && value <= 59;
}

///
@safe unittest
{
    assert(valid!"hours"(12));
    assert(!valid!"hours"(32));
    assert(valid!"months"(12));
    assert(!valid!"months"(13));
}

/++
    Returns whether the given day is valid for the given year and month.

    Params:
        units = The units of time to validate.
        year  = The year of the day to validate.
        month = The month of the day to validate.
        day   = The day to validate.
  +/
bool valid(string units)(int year, int month, int day) @safe pure nothrow
if (units == "days")
{
    return day > 0 && day <= maxDay(year, month);
}


/++
    Params:
        units = The units of time to validate.
        value = The number to validate.
        file  = The file that the $(LREF DateTimeException) will list if thrown.
        line  = The line number that the $(LREF DateTimeException) will list if
                thrown.

    Throws:
        $(LREF DateTimeException) if $(D valid!units(value)) is false.
  +/
void enforceValid(string units)(int value, string file = __FILE__, size_t line = __LINE__) @safe pure
if (units == "months" ||
    units == "hours" ||
    units == "minutes" ||
    units == "seconds")
{
    import std.format : format;

    static if (units == "months")
    {
        if (!valid!units(value))
            throw new DateTimeException(format("%s is not a valid month of the year.", value), file, line);
    }
    else static if (units == "hours")
    {
        if (!valid!units(value))
            throw new DateTimeException(format("%s is not a valid hour of the day.", value), file, line);
    }
    else static if (units == "minutes")
    {
        if (!valid!units(value))
            throw new DateTimeException(format("%s is not a valid minute of an hour.", value), file, line);
    }
    else static if (units == "seconds")
    {
        if (!valid!units(value))
            throw new DateTimeException(format("%s is not a valid second of a minute.", value), file, line);
    }
}


/++
    Params:
        units = The units of time to validate.
        year  = The year of the day to validate.
        month = The month of the day to validate.
        day   = The day to validate.
        file  = The file that the $(LREF DateTimeException) will list if thrown.
        line  = The line number that the $(LREF DateTimeException) will list if
                thrown.

    Throws:
        $(LREF DateTimeException) if $(D valid!"days"(year, month, day)) is false.
  +/
void enforceValid(string units)
                 (int year, Month month, int day, string file = __FILE__, size_t line = __LINE__) @safe pure
if (units == "days")
{
    import std.format : format;
    if (!valid!"days"(year, month, day))
        throw new DateTimeException(format("%s is not a valid day in %s in %s", day, month, year), file, line);
}


/++
    Returns the number of days from the current day of the week to the given
    day of the week. If they are the same, then the result is 0.

    Params:
        currDoW = The current day of the week.
        dow     = The day of the week to get the number of days to.
  +/
int daysToDayOfWeek(DayOfWeek currDoW, DayOfWeek dow) @safe pure nothrow
{
    if (currDoW == dow)
        return 0;
    if (currDoW < dow)
        return dow - currDoW;
    return (DayOfWeek.sat - currDoW) + dow + 1;
}

@safe unittest
{
    assert(daysToDayOfWeek(DayOfWeek.sun, DayOfWeek.sun) == 0);
    assert(daysToDayOfWeek(DayOfWeek.sun, DayOfWeek.mon) == 1);
    assert(daysToDayOfWeek(DayOfWeek.sun, DayOfWeek.tue) == 2);
    assert(daysToDayOfWeek(DayOfWeek.sun, DayOfWeek.wed) == 3);
    assert(daysToDayOfWeek(DayOfWeek.sun, DayOfWeek.thu) == 4);
    assert(daysToDayOfWeek(DayOfWeek.sun, DayOfWeek.fri) == 5);
    assert(daysToDayOfWeek(DayOfWeek.sun, DayOfWeek.sat) == 6);

    assert(daysToDayOfWeek(DayOfWeek.mon, DayOfWeek.sun) == 6);
    assert(daysToDayOfWeek(DayOfWeek.mon, DayOfWeek.mon) == 0);
    assert(daysToDayOfWeek(DayOfWeek.mon, DayOfWeek.tue) == 1);
    assert(daysToDayOfWeek(DayOfWeek.mon, DayOfWeek.wed) == 2);
    assert(daysToDayOfWeek(DayOfWeek.mon, DayOfWeek.thu) == 3);
    assert(daysToDayOfWeek(DayOfWeek.mon, DayOfWeek.fri) == 4);
    assert(daysToDayOfWeek(DayOfWeek.mon, DayOfWeek.sat) == 5);

    assert(daysToDayOfWeek(DayOfWeek.tue, DayOfWeek.sun) == 5);
    assert(daysToDayOfWeek(DayOfWeek.tue, DayOfWeek.mon) == 6);
    assert(daysToDayOfWeek(DayOfWeek.tue, DayOfWeek.tue) == 0);
    assert(daysToDayOfWeek(DayOfWeek.tue, DayOfWeek.wed) == 1);
    assert(daysToDayOfWeek(DayOfWeek.tue, DayOfWeek.thu) == 2);
    assert(daysToDayOfWeek(DayOfWeek.tue, DayOfWeek.fri) == 3);
    assert(daysToDayOfWeek(DayOfWeek.tue, DayOfWeek.sat) == 4);

    assert(daysToDayOfWeek(DayOfWeek.wed, DayOfWeek.sun) == 4);
    assert(daysToDayOfWeek(DayOfWeek.wed, DayOfWeek.mon) == 5);
    assert(daysToDayOfWeek(DayOfWeek.wed, DayOfWeek.tue) == 6);
    assert(daysToDayOfWeek(DayOfWeek.wed, DayOfWeek.wed) == 0);
    assert(daysToDayOfWeek(DayOfWeek.wed, DayOfWeek.thu) == 1);
    assert(daysToDayOfWeek(DayOfWeek.wed, DayOfWeek.fri) == 2);
    assert(daysToDayOfWeek(DayOfWeek.wed, DayOfWeek.sat) == 3);

    assert(daysToDayOfWeek(DayOfWeek.thu, DayOfWeek.sun) == 3);
    assert(daysToDayOfWeek(DayOfWeek.thu, DayOfWeek.mon) == 4);
    assert(daysToDayOfWeek(DayOfWeek.thu, DayOfWeek.tue) == 5);
    assert(daysToDayOfWeek(DayOfWeek.thu, DayOfWeek.wed) == 6);
    assert(daysToDayOfWeek(DayOfWeek.thu, DayOfWeek.thu) == 0);
    assert(daysToDayOfWeek(DayOfWeek.thu, DayOfWeek.fri) == 1);
    assert(daysToDayOfWeek(DayOfWeek.thu, DayOfWeek.sat) == 2);

    assert(daysToDayOfWeek(DayOfWeek.fri, DayOfWeek.sun) == 2);
    assert(daysToDayOfWeek(DayOfWeek.fri, DayOfWeek.mon) == 3);
    assert(daysToDayOfWeek(DayOfWeek.fri, DayOfWeek.tue) == 4);
    assert(daysToDayOfWeek(DayOfWeek.fri, DayOfWeek.wed) == 5);
    assert(daysToDayOfWeek(DayOfWeek.fri, DayOfWeek.thu) == 6);
    assert(daysToDayOfWeek(DayOfWeek.fri, DayOfWeek.fri) == 0);
    assert(daysToDayOfWeek(DayOfWeek.fri, DayOfWeek.sat) == 1);

    assert(daysToDayOfWeek(DayOfWeek.sat, DayOfWeek.sun) == 1);
    assert(daysToDayOfWeek(DayOfWeek.sat, DayOfWeek.mon) == 2);
    assert(daysToDayOfWeek(DayOfWeek.sat, DayOfWeek.tue) == 3);
    assert(daysToDayOfWeek(DayOfWeek.sat, DayOfWeek.wed) == 4);
    assert(daysToDayOfWeek(DayOfWeek.sat, DayOfWeek.thu) == 5);
    assert(daysToDayOfWeek(DayOfWeek.sat, DayOfWeek.fri) == 6);
    assert(daysToDayOfWeek(DayOfWeek.sat, DayOfWeek.sat) == 0);
}


/++
    Returns the number of months from the current months of the year to the
    given month of the year. If they are the same, then the result is 0.

    Params:
        currMonth = The current month of the year.
        month     = The month of the year to get the number of months to.
  +/
int monthsToMonth(int currMonth, int month) @safe pure
{
    enforceValid!"months"(currMonth);
    enforceValid!"months"(month);

    if (currMonth == month)
        return 0;
    if (currMonth < month)
        return month - currMonth;
    return (Month.dec - currMonth) + month;
}

@safe unittest
{
    assert(monthsToMonth(Month.jan, Month.jan) == 0);
    assert(monthsToMonth(Month.jan, Month.feb) == 1);
    assert(monthsToMonth(Month.jan, Month.mar) == 2);
    assert(monthsToMonth(Month.jan, Month.apr) == 3);
    assert(monthsToMonth(Month.jan, Month.may) == 4);
    assert(monthsToMonth(Month.jan, Month.jun) == 5);
    assert(monthsToMonth(Month.jan, Month.jul) == 6);
    assert(monthsToMonth(Month.jan, Month.aug) == 7);
    assert(monthsToMonth(Month.jan, Month.sep) == 8);
    assert(monthsToMonth(Month.jan, Month.oct) == 9);
    assert(monthsToMonth(Month.jan, Month.nov) == 10);
    assert(monthsToMonth(Month.jan, Month.dec) == 11);

    assert(monthsToMonth(Month.may, Month.jan) == 8);
    assert(monthsToMonth(Month.may, Month.feb) == 9);
    assert(monthsToMonth(Month.may, Month.mar) == 10);
    assert(monthsToMonth(Month.may, Month.apr) == 11);
    assert(monthsToMonth(Month.may, Month.may) == 0);
    assert(monthsToMonth(Month.may, Month.jun) == 1);
    assert(monthsToMonth(Month.may, Month.jul) == 2);
    assert(monthsToMonth(Month.may, Month.aug) == 3);
    assert(monthsToMonth(Month.may, Month.sep) == 4);
    assert(monthsToMonth(Month.may, Month.oct) == 5);
    assert(monthsToMonth(Month.may, Month.nov) == 6);
    assert(monthsToMonth(Month.may, Month.dec) == 7);

    assert(monthsToMonth(Month.oct, Month.jan) == 3);
    assert(monthsToMonth(Month.oct, Month.feb) == 4);
    assert(monthsToMonth(Month.oct, Month.mar) == 5);
    assert(monthsToMonth(Month.oct, Month.apr) == 6);
    assert(monthsToMonth(Month.oct, Month.may) == 7);
    assert(monthsToMonth(Month.oct, Month.jun) == 8);
    assert(monthsToMonth(Month.oct, Month.jul) == 9);
    assert(monthsToMonth(Month.oct, Month.aug) == 10);
    assert(monthsToMonth(Month.oct, Month.sep) == 11);
    assert(monthsToMonth(Month.oct, Month.oct) == 0);
    assert(monthsToMonth(Month.oct, Month.nov) == 1);
    assert(monthsToMonth(Month.oct, Month.dec) == 2);

    assert(monthsToMonth(Month.dec, Month.jan) == 1);
    assert(monthsToMonth(Month.dec, Month.feb) == 2);
    assert(monthsToMonth(Month.dec, Month.mar) == 3);
    assert(monthsToMonth(Month.dec, Month.apr) == 4);
    assert(monthsToMonth(Month.dec, Month.may) == 5);
    assert(monthsToMonth(Month.dec, Month.jun) == 6);
    assert(monthsToMonth(Month.dec, Month.jul) == 7);
    assert(monthsToMonth(Month.dec, Month.aug) == 8);
    assert(monthsToMonth(Month.dec, Month.sep) == 9);
    assert(monthsToMonth(Month.dec, Month.oct) == 10);
    assert(monthsToMonth(Month.dec, Month.nov) == 11);
    assert(monthsToMonth(Month.dec, Month.dec) == 0);
}


/++
    Whether the given Gregorian Year is a leap year.

    Params:
        year = The year to to be tested.
 +/
bool yearIsLeapYear(int year) @safe pure nothrow
{
    if (year % 400 == 0)
        return true;
    if (year % 100 == 0)
        return false;
    return year % 4 == 0;
}

@safe unittest
{
    import std.format : format;
    foreach (year; [1, 2, 3, 5, 6, 7, 100, 200, 300, 500, 600, 700, 1998, 1999,
                   2001, 2002, 2003, 2005, 2006, 2007, 2009, 2010, 2011])
    {
        assert(!yearIsLeapYear(year), format("year: %s.", year));
        assert(!yearIsLeapYear(-year), format("year: %s.", year));
    }

    foreach (year; [0, 4, 8, 400, 800, 1600, 1996, 2000, 2004, 2008, 2012])
    {
        assert(yearIsLeapYear(year), format("year: %s.", year));
        assert(yearIsLeapYear(-year), format("year: %s.", year));
    }
}


/++
    Whether the given type defines all of the necessary functions for it to
    function as a time point.

    1. $(D T) must define a static property named $(D min) which is the smallest
       value of $(D T) as $(Unqual!T).

    2. $(D T) must define a static property named $(D max) which is the largest
       value of $(D T) as $(Unqual!T).

    3. $(D T) must define an $(D opBinary) for addition and subtraction that
       accepts $(REF Duration, core,time) and returns $(D Unqual!T).

    4. $(D T) must define an $(D opOpAssign) for addition and subtraction that
       accepts $(REF Duration, core,time) and returns $(D ref Unqual!T).

    5. $(D T) must define a $(D opBinary) for subtraction which accepts $(D T)
       and returns returns $(REF Duration, core,time).
  +/
template isTimePoint(T)
{
    import core.time : Duration;
    import std.traits : FunctionAttribute, functionAttributes, Unqual;

    enum isTimePoint = hasMin &&
                       hasMax &&
                       hasOverloadedOpBinaryWithDuration &&
                       hasOverloadedOpAssignWithDuration &&
                       hasOverloadedOpBinaryWithSelf &&
                       !is(U == Duration);

private:

    alias U = Unqual!T;

    enum hasMin = __traits(hasMember, T, "min") &&
                  is(typeof(T.min) == U) &&
                  is(typeof({static assert(__traits(isStaticFunction, T.min));}));

    enum hasMax = __traits(hasMember, T, "max") &&
                  is(typeof(T.max) == U) &&
                  is(typeof({static assert(__traits(isStaticFunction, T.max));}));

    enum hasOverloadedOpBinaryWithDuration = is(typeof(T.init + Duration.init) == U) &&
                                             is(typeof(T.init - Duration.init) == U);

    enum hasOverloadedOpAssignWithDuration = is(typeof(U.init += Duration.init) == U) &&
                                             is(typeof(U.init -= Duration.init) == U) &&
                                             is(typeof(
                                             {
                                                 // Until the overload with TickDuration is removed, this is ambiguous.
                                                 //alias add = U.opOpAssign!"+";
                                                 //alias sub = U.opOpAssign!"-";
                                                 U u;
                                                 auto ref add() { return u += Duration.init; }
                                                 auto ref sub() { return u -= Duration.init; }
                                                 alias FA = FunctionAttribute;
                                                 static assert((functionAttributes!add & FA.ref_) != 0);
                                                 static assert((functionAttributes!sub & FA.ref_) != 0);
                                             }));

    enum hasOverloadedOpBinaryWithSelf = is(typeof(T.init - T.init) == Duration);
}

///
@safe unittest
{
    import core.time : Duration;
    import std.datetime : Date, DateTime, Interval, SysTime, TimeOfDay; // temporary
    /+
    import std.datetime.date : Date;
    import std.datetime.datetime : DateTime;
    import std.datetime.interval : Interval;
    import std.datetime.systime : SysTime;
    import std.datetime.timeofday : TimeOfDay;
    +/

    static assert(isTimePoint!Date);
    static assert(isTimePoint!DateTime);
    static assert(isTimePoint!SysTime);
    static assert(isTimePoint!TimeOfDay);

    static assert(!isTimePoint!int);
    static assert(!isTimePoint!Duration);
    static assert(!isTimePoint!(Interval!SysTime));
}

@safe unittest
{
    import core.time;
    import std.datetime : Date, DateTime, Interval, NegInfInterval, PosInfInterval, SysTime, TimeOfDay; // temporary
    /+
    import std.datetime.date;
    import std.datetime.datetime;
    import std.datetime.interval;
    import std.datetime.systime;
    import std.datetime.timeofday;
    +/
    import std.meta : AliasSeq;

    foreach (TP; AliasSeq!(Date, DateTime, SysTime, TimeOfDay))
    {
        static assert(isTimePoint!(const TP), TP.stringof);
        static assert(isTimePoint!(immutable TP), TP.stringof);
    }

    foreach (T; AliasSeq!(float, string, Duration, Interval!Date, PosInfInterval!Date, NegInfInterval!Date))
        static assert(!isTimePoint!T, T.stringof);
}


package:

/+
    The maximum valid Day in the given month in the given year.

    Params:
        year  = The year to get the day for.
        month = The month of the Gregorian Calendar to get the day for.
 +/
ubyte maxDay(int year, int month) @safe pure nothrow
in
{
    assert(valid!"months"(month));
}
body
{
    switch (month)
    {
        case Month.jan, Month.mar, Month.may, Month.jul, Month.aug, Month.oct, Month.dec:
            return 31;
        case Month.feb:
            return yearIsLeapYear(year) ? 29 : 28;
        case Month.apr, Month.jun, Month.sep, Month.nov:
            return 30;
        default:
            assert(0, "Invalid month.");
    }
}

@safe unittest
{
    // Test A.D.
    assert(maxDay(1999, 1) == 31);
    assert(maxDay(1999, 2) == 28);
    assert(maxDay(1999, 3) == 31);
    assert(maxDay(1999, 4) == 30);
    assert(maxDay(1999, 5) == 31);
    assert(maxDay(1999, 6) == 30);
    assert(maxDay(1999, 7) == 31);
    assert(maxDay(1999, 8) == 31);
    assert(maxDay(1999, 9) == 30);
    assert(maxDay(1999, 10) == 31);
    assert(maxDay(1999, 11) == 30);
    assert(maxDay(1999, 12) == 31);

    assert(maxDay(2000, 1) == 31);
    assert(maxDay(2000, 2) == 29);
    assert(maxDay(2000, 3) == 31);
    assert(maxDay(2000, 4) == 30);
    assert(maxDay(2000, 5) == 31);
    assert(maxDay(2000, 6) == 30);
    assert(maxDay(2000, 7) == 31);
    assert(maxDay(2000, 8) == 31);
    assert(maxDay(2000, 9) == 30);
    assert(maxDay(2000, 10) == 31);
    assert(maxDay(2000, 11) == 30);
    assert(maxDay(2000, 12) == 31);

    // Test B.C.
    assert(maxDay(-1999, 1) == 31);
    assert(maxDay(-1999, 2) == 28);
    assert(maxDay(-1999, 3) == 31);
    assert(maxDay(-1999, 4) == 30);
    assert(maxDay(-1999, 5) == 31);
    assert(maxDay(-1999, 6) == 30);
    assert(maxDay(-1999, 7) == 31);
    assert(maxDay(-1999, 8) == 31);
    assert(maxDay(-1999, 9) == 30);
    assert(maxDay(-1999, 10) == 31);
    assert(maxDay(-1999, 11) == 30);
    assert(maxDay(-1999, 12) == 31);

    assert(maxDay(-2000, 1) == 31);
    assert(maxDay(-2000, 2) == 29);
    assert(maxDay(-2000, 3) == 31);
    assert(maxDay(-2000, 4) == 30);
    assert(maxDay(-2000, 5) == 31);
    assert(maxDay(-2000, 6) == 30);
    assert(maxDay(-2000, 7) == 31);
    assert(maxDay(-2000, 8) == 31);
    assert(maxDay(-2000, 9) == 30);
    assert(maxDay(-2000, 10) == 31);
    assert(maxDay(-2000, 11) == 30);
    assert(maxDay(-2000, 12) == 31);
}
