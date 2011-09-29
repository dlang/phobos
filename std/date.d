// Written in the D programming language.

/**
 * $(RED Deprecated. It will be removed in February 2012.
 *       Please use std.datetime instead.)
 *
 * Dates are represented in several formats. The date implementation
 * revolves around a central type, $(D d_time), from which other
 * formats are converted to and from.  Dates are calculated using the
 * Gregorian calendar.
 *
 * References: $(WEB wikipedia.org/wiki/Gregorian_calendar, Gregorian
 * calendar (Wikipedia))
 *
 * Macros: WIKI = Phobos/StdDate
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 * Source:    $(PHOBOSSRC std/_date.d)
 */
/*          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.date;

import std.conv, std.datebase, std.dateparse, std.exception, std.stdio;
import std.c.stdlib;

pragma(msg, "Notice: As of Phobos 2.055, std.date and std.dateparse have been " ~
            "deprecated. They will be removed in February 2012. " ~
            "Please use std.datetime instead.");

deprecated:

/**
 * $(D d_time) is a signed arithmetic type giving the time elapsed
 * since January 1, 1970.  Negative values are for dates preceding
 * 1970. The time unit used is Ticks.  Ticks are milliseconds or
 * smaller intervals.
 *
 * The usual arithmetic operations can be performed on d_time, such as adding,
 * subtracting, etc. Elapsed time in Ticks can be computed by subtracting a
 * starting d_time from an ending d_time.
 */
alias long d_time;

/**
 * A value for d_time that does not represent a valid time.
 */
enum d_time d_time_nan = long.min;

/**
 * Time broken down into its components.
 */
struct Date
{
    int year = int.min;        /// use int.min as "nan" year value
    int month;                /// 1..12
    int day;                /// 1..31
    int hour;                /// 0..23
    int minute;                /// 0..59
    int second;                /// 0..59
    int ms;                /// 0..999
    int weekday;        /// 0: not specified, 1..7: Sunday..Saturday
    int tzcorrection = int.min;        /// -1200..1200 correction in hours

    /// Parse date out of string s[] and store it in this Date instance.
    void parse(string s)
    {
        DateParse dp;
        dp.parse(s, this);
    }
}

enum
{
    hoursPerDay    = 24,
    minutesPerHour = 60,
    msPerMinute    = 60 * 1000,
    msPerHour      = 60 * msPerMinute,
    msPerDay       = 86_400_000,
    ticksPerMs     = 1,
    ticksPerSecond = 1000,                        /// Will be at least 1000
    ticksPerMinute = ticksPerSecond * 60,
    ticksPerHour   = ticksPerMinute * 60,
    ticksPerDay    = ticksPerHour   * 24,
}

deprecated alias ticksPerSecond TicksPerSecond;
deprecated alias ticksPerMs TicksPerMs;
deprecated alias ticksPerMinute TicksPerMinute;
deprecated alias ticksPerHour TicksPerHour;
deprecated alias ticksPerDay TicksPerDay;

deprecated
unittest
{
    assert(ticksPerSecond == TicksPerSecond);
}

__gshared d_time localTZA = 0;

private immutable char[] daystr = "SunMonTueWedThuFriSat";
private immutable char[] monstr = "JanFebMarAprMayJunJulAugSepOctNovDec";

private immutable int[12] mdays =
    [ 0,31,59,90,120,151,181,212,243,273,304,334 ];

/********************************
 * Compute year and week [1..53] from t. The ISO 8601 week 1 is the first week
 * of the year that includes January 4. Monday is the first day of the week.
 * References:
 *        $(LINK2 http://en.wikipedia.org/wiki/ISO_8601, ISO 8601 (Wikipedia))
 */

void toISO8601YearWeek(d_time t, out int year, out int week)
{
    year = yearFromTime(t);

    auto yday = day(t) - dayFromYear(year);

    /* Determine day of week Jan 4 falls on.
     * Weeks begin on a Monday.
     */

    auto d = dayFromYear(year);
    auto w = (d + 3/*Jan4*/ + 3) % 7;
    if (w < 0)
        w += 7;

    /* Find yday of beginning of ISO 8601 year
     */
    auto ydaybeg = 3/*Jan4*/ - w;

    /* Check if yday is actually the last week of the previous year
     */
    if (yday < ydaybeg)
    {
        year -= 1;
        week = 53;
        return;
    }

    /* Check if yday is actually the first week of the next year
     */
    if (yday >= 362)                            // possible
    {   int d2;
        int ydaybeg2;

        d2 = dayFromYear(year + 1);
        w = (d2 + 3/*Jan4*/ + 3) % 7;
        if (w < 0)
            w += 7;
        //printf("w = %d\n", w);
        ydaybeg2 = 3/*Jan4*/ - w;
        if (d + yday >= d2 + ydaybeg2)
        {
            year += 1;
            week = 1;
            return;
        }
    }

    week = (yday - ydaybeg) / 7 + 1;
}

/* ***********************************
 * Divide time by divisor. Always round down, even if d is negative.
 */

pure d_time floor(d_time d, int divisor)
{
    return (d < 0 ? d - divisor - 1 : d) / divisor;
}

int dmod(d_time n, d_time d)
{   d_time r;

    r = n % d;
    if (r < 0)
        r += d;
    assert(cast(int)r == r);
    return cast(int)r;
}

/********************************
 * Calculates the hour from time.
 *
 * Params:
 *      time = The time to compute the hour from.
 * Returns:
 *      The calculated hour, 0..23.
 */
int hourFromTime(d_time time)
{
    return dmod(floor(time, msPerHour), hoursPerDay);
}

/********************************
 * Calculates the minute from time.
 *
 * Params:
 *      time = The time to compute the minute from.
 * Returns:
 *      The calculated minute, 0..59.
 */
int minFromTime(d_time time)
{
    return dmod(floor(time, msPerMinute), minutesPerHour);
}

/********************************
 * Calculates the second from time.
 *
 * Params:
 *      time = The time to compute the second from.
 * Returns:
 *      The calculated second, 0..59.
 */
int secFromTime(d_time time)
{
    return dmod(floor(time, ticksPerSecond), 60);
}

/********************************
 * Calculates the milisecond from time.
 *
 * Params:
 *      time = The time to compute the milisecond from.
 * Returns:
 *      The calculated milisecond, 0..999.
 */
int msFromTime(d_time time)
{
    return dmod(time / (ticksPerSecond / 1000), 1000);
}

int timeWithinDay(d_time t)
{
    return dmod(t, msPerDay);
}

d_time toInteger(d_time n)
{
    return n;
}

int day(d_time t)
{
    return cast(int)floor(t, msPerDay);
}

pure bool leapYear(uint y)
{
    return (y % 4) == 0 && (y % 100 || (y % 400) == 0);
}

unittest {
    assert(!leapYear(1970));
    assert(leapYear(1984));
    assert(leapYear(2000));
    assert(!leapYear(2100));
}

/********************************
 * Calculates the number of days that exists in a year.
 *
 * Leap years have 366 days, while other years have 365.
 *
 * Params:
 *      year = The year to compute the number of days from.
 * Returns:
 *      The number of days in the year, 365 or 366.
 */
pure uint daysInYear(uint year)
{
    return (leapYear(year) ? 366 : 365);
}


/********************************
 * Calculates the number of days elapsed since 1 January 1970
 * until 1 January of the given year.
 *
 * Params:
 *      year = The year to compute the number of days from.
 * Returns:
 *      The number of days elapsed.
 *
 * Example:
 * ----------
 * writeln(dayFromYear(1970)); // writes '0'
 * writeln(dayFromYear(1971)); // writes '365'
 * writeln(dayFromYear(1972)); // writes '730'
 * ----------
 */
pure int dayFromYear(int year)
{
    return cast(int) (365 * (year - 1970) +
                floor((year - 1969), 4) -
                floor((year - 1901), 100) +
                floor((year - 1601), 400));
}

pure d_time timeFromYear(int y)
{
    return cast(d_time)msPerDay * dayFromYear(y);
}

/*****************************
 * Calculates the year from the d_time t.
 */

pure int yearFromTime(d_time t)
{

    if (t == d_time_nan)
        return 0;

    // Hazard a guess
    //y = 1970 + cast(int) (t / (365.2425 * msPerDay));
    // Use integer only math
    int y = 1970 + cast(int) (t / (3652425 * (msPerDay / 10000)));

    if (timeFromYear(y) <= t)
    {
        while (timeFromYear(y + 1) <= t)
            y++;
    }
    else
    {
        do
        {
            y--;
        }
        while (timeFromYear(y) > t);
    }
    return y;
}

/*******************************
 * Determines if d_time t is a leap year.
 *
 * A leap year is every 4 years except years ending in 00 that are not
 * divsible by 400.
 *
 * Returns: !=0 if it is a leap year.
 *
 * References:
 *        $(LINK2 http://en.wikipedia.org/wiki/Leap_year, Wikipedia)
 */

pure bool inLeapYear(d_time t)
{
    return leapYear(yearFromTime(t));
}

/*****************************
 * Calculates the month from the d_time t.
 *
 * Returns: Integer in the range 0..11, where
 *        0 represents January and 11 represents December.
 */

int monthFromTime(d_time t)
{
    auto year = yearFromTime(t);
    auto day = day(t) - dayFromYear(year);

    int month;
    if (day < 59)
    {
        if (day < 31)
        {   assert(day >= 0);
            month = 0;
        }
        else
            month = 1;
    }
    else
    {
        day -= leapYear(year);
        if (day < 212)
        {
            if (day < 59)
                month = 1;
            else if (day < 90)
                month = 2;
            else if (day < 120)
                month = 3;
            else if (day < 151)
                month = 4;
            else if (day < 181)
                month = 5;
            else
                month = 6;
        }
        else
        {
            if (day < 243)
                month = 7;
            else if (day < 273)
                month = 8;
            else if (day < 304)
                month = 9;
            else if (day < 334)
                month = 10;
            else if (day < 365)
                month = 11;
            else
                assert(0);
        }
    }
    return month;
}

/*******************************
 * Compute which day in a month a d_time t is.
 * Returns:
 *        Integer in the range 1..31
 */
int dateFromTime(d_time t)
{
    auto year = yearFromTime(t);
    auto day = day(t) - dayFromYear(year);
    auto leap = leapYear(year);
    auto month = monthFromTime(t);
    int date;
    switch (month)
    {
        case 0:         date = day +   1;                break;
        case 1:         date = day -  30;                break;
        case 2:         date = day -  58 - leap;        break;
        case 3:         date = day -  89 - leap;        break;
        case 4:         date = day - 119 - leap;        break;
        case 5:         date = day - 150 - leap;        break;
        case 6:         date = day - 180 - leap;        break;
        case 7:         date = day - 211 - leap;        break;
        case 8:         date = day - 242 - leap;        break;
        case 9:         date = day - 272 - leap;        break;
        case 10: date = day - 303 - leap;        break;
        case 11: date = day - 333 - leap;        break;
        default:
            assert(0);
    }
    return date;
}

/*******************************
 * Compute which day of the week a d_time t is.
 * Returns:
 *        Integer in the range 0..6, where 0 represents Sunday
 *        and 6 represents Saturday.
 */
int weekDay(d_time t)
{
    auto w = (cast(int)day(t) + 4) % 7;
    if (w < 0)
        w += 7;
    return w;
}

/***********************************
 * Convert from UTC to local time.
 */

d_time UTCtoLocalTime(d_time t)
{
    return (t == d_time_nan)
        ? d_time_nan
        : t + localTZA + daylightSavingTA(t);
}

/***********************************
 * Convert from local time to UTC.
 */

d_time localTimetoUTC(d_time t)
{
    return (t == d_time_nan)
        ? d_time_nan
/* BUGZILLA 1752 says this line should be:
 *        : t - localTZA - daylightSavingTA(t);
 */
        : t - localTZA - daylightSavingTA(t - localTZA);
}


d_time makeTime(d_time hour, d_time min, d_time sec, d_time ms)
{
    return hour * ticksPerHour +
           min * ticksPerMinute +
           sec * ticksPerSecond +
           ms * ticksPerMs;
}

/* *****************************
 * Params:
 *        month = 0..11
 *        date = day of month, 1..31
 * Returns:
 *        number of days since start of epoch
 */

d_time makeDay(d_time year, d_time month, d_time date)
{
    const y = cast(int)(year + floor(month, 12));
    const m = dmod(month, 12);

    const leap = leapYear(y);
    auto t = timeFromYear(y) + cast(d_time) mdays[m] * msPerDay;
    if (leap && month >= 2)
        t += msPerDay;

    if (yearFromTime(t) != y ||
        monthFromTime(t) != m ||
        dateFromTime(t) != 1)
    {
        return  d_time_nan;
    }

    return day(t) + date - 1;
}

d_time makeDate(d_time day, d_time time)
{
    if (day == d_time_nan || time == d_time_nan)
        return d_time_nan;

    return day * ticksPerDay + time;
}

d_time timeClip(d_time time)
{
    //printf("TimeClip(%g) = %g\n", time, toInteger(time));

    return toInteger(time);
}

/***************************************
 * Determine the date in the month, 1..31, of the nth
 * weekday.
 * Params:
 *        year = year
 *        month = month, 1..12
 *        weekday = day of week 0..6 representing Sunday..Saturday
 *        n = nth occurrence of that weekday in the month, 1..5, where
 *            5 also means "the last occurrence in the month"
 * Returns:
 *        the date in the month, 1..31, of the nth weekday
 */

int dateFromNthWeekdayOfMonth(int year, int month, int weekday, int n)
in
{
    assert(1 <= month && month <= 12);
    assert(0 <= weekday && weekday <= 6);
    assert(1 <= n && n <= 5);
}
body
{
    // Get day of the first of the month
    auto x = makeDay(year, month - 1, 1);

    // Get the week day 0..6 of the first of this month
    auto wd = weekDay(makeDate(x, 0));

    // Get monthday of first occurrence of weekday in this month
    auto mday = weekday - wd + 1;
    if (mday < 1)
        mday += 7;

    // Add in number of weeks
    mday += (n - 1) * 7;

    // If monthday is more than the number of days in the month,
    // back up to 'last' occurrence
    if (mday > 28 && mday > daysInMonth(year, month))
    {        assert(n == 5);
        mday -= 7;
    }

    return mday;
}

unittest
{
    assert(dateFromNthWeekdayOfMonth(2003,  3, 0, 5) == 30);
    assert(dateFromNthWeekdayOfMonth(2003, 10, 0, 5) == 26);
    assert(dateFromNthWeekdayOfMonth(2004,  3, 0, 5) == 28);
    assert(dateFromNthWeekdayOfMonth(2004, 10, 0, 5) == 31);
}

/**************************************
 * Determine the number of days in a month, 1..31.
 * Params:
 *        month = 1..12
 */

int daysInMonth(int year, int month)
{
    switch (month)
    {
        case 1:
        case 3:
        case 5:
        case 7:
        case 8:
        case 10:
        case 12:
            return 31;
        case 2:
            return 28 + leapYear(year);
        case 4:
        case 6:
        case 9:
        case 11:
            return 30;
    default:
        break;
    }
    return enforce(false, "Invalid month passed to daysInMonth");
}

unittest
{
    assert(daysInMonth(2003, 2) == 28);
    assert(daysInMonth(2004, 2) == 29);
}

/*************************************
 * Converts UTC time into a text string of the form:
 * "Www Mmm dd hh:mm:ss GMT+-TZ yyyy".
 * For example, "Tue Apr 02 02:04:57 GMT-0800 1996".
 * If time is invalid, i.e. is d_time_nan,
 * the string "Invalid date" is returned.
 *
 * Example:
 * ------------------------------------
  d_time lNow;
  char[] lNowString;

  // Grab the date and time relative to UTC
  lNow = std.date.getUTCtime();
  // Convert this into the local date and time for display.
  lNowString = std.date.UTCtoString(lNow);
 * ------------------------------------
 */

string UTCtoString(d_time time)
{
    // Years are supposed to be -285616 .. 285616, or 7 digits
    // "Tue Apr 02 02:04:57 GMT-0800 1996"
    auto buffer = new char[29 + 7 + 1];

    if (time == d_time_nan)
        return "Invalid Date";

    auto dst = daylightSavingTA(time);
    auto offset = localTZA + dst;
    auto t = time + offset;
    auto sign = '+';
    if (offset < 0)
    {        sign = '-';
//        offset = -offset;
        offset = -(localTZA + dst);
    }

    auto mn = cast(int)(offset / msPerMinute);
    auto hr = mn / 60;
    mn %= 60;

    //printf("hr = %d, offset = %g, localTZA = %g, dst = %g, + = %g\n", hr, offset, localTZA, dst, localTZA + dst);

    auto len = sprintf(buffer.ptr,
            "%.3s %.3s %02d %02d:%02d:%02d GMT%c%02d%02d %d",
            &daystr[weekDay(t) * 3],
            &monstr[monthFromTime(t) * 3],
            dateFromTime(t),
            hourFromTime(t), minFromTime(t), secFromTime(t),
            sign, hr, mn,
            cast(long)yearFromTime(t));

    // Ensure no buggy buffer overflows
    //printf("len = %d, buffer.length = %d\n", len, buffer.length);
    assert(len < buffer.length);
    buffer = buffer[0 .. len];
    return assumeUnique(buffer);
}

/// Alias for UTCtoString (deprecated).
deprecated alias UTCtoString toString;

/***********************************
 * Converts t into a text string of the form: "Www, dd Mmm yyyy hh:mm:ss UTC".
 * If t is invalid, "Invalid date" is returned.
 */

string toUTCString(d_time t)
{
    // Years are supposed to be -285616 .. 285616, or 7 digits
    // "Tue, 02 Apr 1996 02:04:57 GMT"
    auto buffer = new char[25 + 7 + 1];

    if (t == d_time_nan)
        return "Invalid Date";

    auto len = sprintf(buffer.ptr, "%.3s, %02d %.3s %d %02d:%02d:%02d UTC",
            &daystr[weekDay(t) * 3], dateFromTime(t),
            &monstr[monthFromTime(t) * 3],
            yearFromTime(t),
            hourFromTime(t), minFromTime(t), secFromTime(t));

    // Ensure no buggy buffer overflows
    assert(len < buffer.length);

    return cast(string) buffer[0 .. len];
}

/************************************
 * Converts the date portion of time into a text string of the form: "Www Mmm dd
 * yyyy", for example, "Tue Apr 02 1996".
 * If time is invalid, "Invalid date" is returned.
 */

string toDateString(d_time time)
{
    // Years are supposed to be -285616 .. 285616, or 7 digits
    // "Tue Apr 02 1996"
    auto buffer = new char[29 + 7 + 1];

    if (time == d_time_nan)
        return "Invalid Date";

    auto dst = daylightSavingTA(time);
    auto offset = localTZA + dst;
    auto t = time + offset;

    auto len = sprintf(buffer.ptr, "%.3s %.3s %02d %d",
        &daystr[weekDay(t) * 3],
        &monstr[monthFromTime(t) * 3],
        dateFromTime(t),
        cast(long)yearFromTime(t));

    // Ensure no buggy buffer overflows
    assert(len < buffer.length);

    return cast(string) buffer[0 .. len];
}

/******************************************
 * Converts the time portion of t into a text string of the form: "hh:mm:ss
 * GMT+-TZ", for example, "02:04:57 GMT-0800".
 * If t is invalid, "Invalid date" is returned.
 * The input must be in UTC, and the output is in local time.
 */

string toTimeString(d_time time)
{
    // "02:04:57 GMT-0800"
    auto buffer = new char[17 + 1];

    if (time == d_time_nan)
        return "Invalid Date";

    auto dst = daylightSavingTA(time);
    auto offset = localTZA + dst;
    auto t = time + offset;
    auto sign = '+';
    if (offset < 0)
    {        sign = '-';
//        offset = -offset;
        offset = -(localTZA + dst);
    }

    auto mn = cast(int)(offset / msPerMinute);
    auto hr = mn / 60;
    mn %= 60;

    //printf("hr = %d, offset = %g, localTZA = %g, dst = %g, + = %g\n", hr, offset, localTZA, dst, localTZA + dst);

    auto len = sprintf(buffer.ptr, "%02d:%02d:%02d GMT%c%02d%02d",
        hourFromTime(t), minFromTime(t), secFromTime(t),
        sign, hr, mn);

    // Ensure no buggy buffer overflows
    assert(len < buffer.length);

    // Lop off terminating 0
    return cast(string) buffer[0 .. len];
}


/******************************************
 * Parses s as a textual date string, and returns it as a d_time.  If
 * the string is not a valid date, $(D d_time_nan) is returned.
 */

d_time parse(string s)
{
    try
    {
        Date dp;
        dp.parse(s);
        auto time = makeTime(dp.hour, dp.minute, dp.second, dp.ms);
        // Assume UTC if no tzcorrection is set (runnable/testdate).
        if (dp.tzcorrection != int.min)
        {
            time += cast(d_time)(dp.tzcorrection / 100) * msPerHour +
                    cast(d_time)(dp.tzcorrection % 100) * msPerMinute;
        }
        auto day = makeDay(dp.year, dp.month - 1, dp.day);
        auto result = makeDate(day,time);
        return timeClip(result);
    }
    catch
    {
        return d_time_nan;                // erroneous date string
    }
}

extern(C) void std_date_static_this()
{
    localTZA = getLocalTZA();
}

version (Win32)
{
    private import std.c.windows.windows;
    //import c.time;

    /******
     * Get current UTC time.
     */
    d_time getUTCtime()
    {
        SYSTEMTIME st;
        GetSystemTime(&st);                // get time in UTC
        return SYSTEMTIME2d_time(&st, 0);
        //return c.time.time(null) * ticksPerSecond;
    }

    static d_time FILETIME2d_time(const FILETIME *ft)
    {
        SYSTEMTIME st = void;
        if (!FileTimeToSystemTime(ft, &st))
            return d_time_nan;
        return SYSTEMTIME2d_time(&st, 0);
    }

    FILETIME d_time2FILETIME(d_time dt)
    {
        static assert(10_000_000 >= ticksPerSecond);
        static assert(10_000_000 % ticksPerSecond == 0);
        enum ulong ticksFrom1601To1970 = 11_644_473_600UL * ticksPerSecond;
        ulong t = (dt + ticksFrom1601To1970) * (10_000_000 / ticksPerSecond);
        FILETIME result = void;
        result.dwLowDateTime = cast(uint) (t & uint.max);
        result.dwHighDateTime = cast(uint) (t >> 32);
        return result;
    }

    unittest
    {
        auto dt = getUTCtime;
        auto ft = d_time2FILETIME(dt);
        auto dt1 = FILETIME2d_time(&ft);
        assert(dt == dt1, text(dt, " != ", dt1));
    }

    static d_time SYSTEMTIME2d_time(const SYSTEMTIME *st, d_time t)
    {
        /* More info: http://delphicikk.atw.hu/listaz.php?id=2667&oldal=52
         */
        d_time day = void;
        d_time time = void;

        if (st.wYear)
        {
            time = makeTime(st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
            day = makeDay(st.wYear, st.wMonth - 1, st.wDay);
        }
        else
        {   /* wYear being 0 is a flag to indicate relative time:
             * wMonth is the month 1..12
             * wDayOfWeek is weekday 0..6 corresponding to Sunday..Saturday
             * wDay is the nth time, 1..5, that wDayOfWeek occurs
             */

            auto year = yearFromTime(t);
            auto mday = dateFromNthWeekdayOfMonth(year,
                    st.wMonth, st.wDay, st.wDayOfWeek);
            day = makeDay(year, st.wMonth - 1, mday);
            time = makeTime(st.wHour, st.wMinute, 0, 0);
        }
        auto n = makeDate(day,time);
        return timeClip(n);
    }

    d_time getLocalTZA()
    {
        TIME_ZONE_INFORMATION tzi = void;

        /* http://msdn.microsoft.com/library/en-us/sysinfo/base/gettimezoneinformation.asp
         * http://msdn2.microsoft.com/en-us/library/ms725481.aspx
         */
        auto r = GetTimeZoneInformation(&tzi);
        //printf("bias = %d\n", tzi.Bias);
        //printf("standardbias = %d\n", tzi.StandardBias);
        //printf("daylightbias = %d\n", tzi.DaylightBias);
        switch (r)
        {
            case TIME_ZONE_ID_STANDARD:
                return -(tzi.Bias + tzi.StandardBias)
                    * cast(d_time)(60 * ticksPerSecond);
            case TIME_ZONE_ID_DAYLIGHT:
                // falthrough
                //t = -(tzi.Bias + tzi.DaylightBias) * cast(d_time)(60 * ticksPerSecond);
                //break;
            case TIME_ZONE_ID_UNKNOWN:
                return -(tzi.Bias) * cast(d_time)(60 * ticksPerSecond);
            default:
                return 0;
        }
    }

    /*
     * Get daylight savings time adjust for time dt.
     */

    int daylightSavingTA(d_time dt)
    {
        TIME_ZONE_INFORMATION tzi = void;
        d_time ts;
        d_time td;

        /* http://msdn.microsoft.com/library/en-us/sysinfo/base/gettimezoneinformation.asp
         */
        auto r = GetTimeZoneInformation(&tzi);
        auto t = 0;
        switch (r)
        {
            case TIME_ZONE_ID_STANDARD:
            case TIME_ZONE_ID_DAYLIGHT:
                if (tzi.StandardDate.wMonth == 0 ||
                    tzi.DaylightDate.wMonth == 0)
                    break;

                ts = SYSTEMTIME2d_time(&tzi.StandardDate, dt);
                td = SYSTEMTIME2d_time(&tzi.DaylightDate, dt);

                if (td <= dt && dt < ts)
                {
                    t = -tzi.DaylightBias * (60 * ticksPerSecond);
                    //printf("DST is in effect, %d\n", t);
                }
                else
                {
                    //printf("no DST\n");
                }
                break;

            case TIME_ZONE_ID_UNKNOWN:
                // Daylight savings time not used in this time zone
                break;

            default:
                assert(0);
        }
        return t;
    }
}

version (Posix)
{
    private import core.sys.posix.time;
    private import core.sys.posix.sys.time;

    /******
     * Get current UTC time.
     */
    d_time getUTCtime()
    {   timeval tv;

        //printf("getUTCtime()\n");
        if (gettimeofday(&tv, null))
        {   // Some error happened - try time() instead
            return time(null) * ticksPerSecond;
        }

        return tv.tv_sec * cast(d_time)ticksPerSecond +
                (tv.tv_usec / (1000000 / cast(d_time)ticksPerSecond));
    }

    d_time getLocalTZA()
    {
        time_t t;

        time(&t);
        version (OSX)
        {
            tm result;
            localtime_r(&t, &result);
            return result.tm_gmtoff * ticksPerSecond;
        }
        else version (FreeBSD)
        {
            tm result;
            localtime_r(&t, &result);
            return result.tm_gmtoff * ticksPerSecond;
        }
        else
        {
            localtime(&t);        // this will set timezone
            return -(timezone * ticksPerSecond);
        }
    }

    /*
     * Get daylight savings time adjust for time dt.
     */

    int daylightSavingTA(d_time dt)
    {
        tm *tmp;
        time_t t;
        int dst = 0;

        if (dt != d_time_nan)
        {
            d_time seconds = dt / ticksPerSecond;
            t = cast(time_t) seconds;
            if (t == seconds)        // if in range
            {
                tmp = localtime(&t);
                if (tmp.tm_isdst > 0)
                    dst = ticksPerHour;        // BUG: Assume daylight savings time is plus one hour.
            }
            else // out of range for system time, use our own calculation
            {
                /* BUG: this works for the US, but not other timezones.
                 */

                dt -= localTZA;

                int year = yearFromTime(dt);

                /* Compute time given year, month 1..12,
                 * week in month, weekday, hour
                 */
                d_time dstt(int year, int month, int week, int weekday, int hour)
                {
                    auto mday = dateFromNthWeekdayOfMonth(year,  month, weekday, week);
                    return timeClip(makeDate(
                        makeDay(year, month - 1, mday),
                        makeTime(hour, 0, 0, 0)));
                }

                d_time start;
                d_time end;
                if (year < 2007)
                {   // Daylight savings time goes from 2 AM the first Sunday
                    // in April through 2 AM the last Sunday in October
                    start = dstt(year,  4, 1, 0, 2);
                    end   = dstt(year, 10, 5, 0, 2);
                }
                else
                {
                    // the second Sunday of March to
                    // the first Sunday in November
                    start = dstt(year,  3, 2, 0, 2);
                    end   = dstt(year, 11, 1, 0, 2);
                }

                if (start <= dt && dt < end)
                    dst = ticksPerHour;
                //writefln("start = %s, dt = %s, end = %s, dst = %s", start, dt, end, dst);
            }
        }
        return dst;
    }

}


/+ DOS File Time +/

/***
 * Type representing the DOS file date/time format.
 */
alias uint DosFileTime;

/************************************
 * Convert from DOS file date/time to d_time.
 */

d_time toDtime(DosFileTime time)
{
    uint dt = cast(uint)time;

    if (dt == 0)
        return d_time_nan;

    int year = ((dt >> 25) & 0x7F) + 1980;
    int month = ((dt >> 21) & 0x0F) - 1;        // 0..12
    int dayofmonth = ((dt >> 16) & 0x1F);        // 0..31
    int hour = (dt >> 11) & 0x1F;                // 0..23
    int minute = (dt >> 5) & 0x3F;                // 0..59
    int second = (dt << 1) & 0x3E;                // 0..58 (in 2 second increments)

    d_time t;

    t = std.date.makeDate(std.date.makeDay(year, month, dayofmonth),
            std.date.makeTime(hour, minute, second, 0));

    assert(yearFromTime(t) == year);
    assert(monthFromTime(t) == month);
    assert(dateFromTime(t) == dayofmonth);
    assert(hourFromTime(t) == hour);
    assert(minFromTime(t) == minute);
    assert(secFromTime(t) == second);

    t -= localTZA + daylightSavingTA(t);

    return t;
}

/****************************************
 * Convert from d_time to DOS file date/time.
 */

DosFileTime toDosFileTime(d_time t)
{   uint dt;

    if (t == d_time_nan)
        return cast(DosFileTime)0;

    t += localTZA + daylightSavingTA(t);

    uint year = yearFromTime(t);
    uint month = monthFromTime(t);
    uint dayofmonth = dateFromTime(t);
    uint hour = hourFromTime(t);
    uint minute = minFromTime(t);
    uint second = secFromTime(t);

    dt = (year - 1980) << 25;
    dt |= ((month + 1) & 0x0F) << 21;
    dt |= (dayofmonth & 0x1F) << 16;
    dt |= (hour & 0x1F) << 11;
    dt |= (minute & 0x3F) << 5;
    dt |= (second >> 1) & 0x1F;

    return cast(DosFileTime)dt;
}

/**
Benchmarks code for speed assessment and comparison.

Params:

fun = aliases of callable objects (e.g. function names). Each should
take no arguments.

times = The number of times each function is to be executed.

result = The optional store for the return value. If $(D null) is
passed in, new store is allocated appropriately.

Returns:

An array of $(D n) $(D uint)s. Element at slot $(D i) contains the
number of milliseconds spent in calling the $(D i)th function $(D
times) times.

Example:
----
int a;
void f0() { }
void f1() { auto b = a; }
void f2() { auto b = to!(string)(a); }
auto r = benchmark!(f0, f1, f2)(10_000_000);
----
 */
ulong[] benchmark(fun...)(uint times, ulong[] result = null)
{
    result.length = fun.length;
    result.length = 0;
    foreach (i, Unused; fun)
    {
        immutable t = getUTCtime;
        foreach (j; 0 .. times)
        {
            fun[i]();
        }
        immutable delta = getUTCtime - t;
        result ~= cast(uint)delta;
    }
    foreach (ref e; result)
    {
        e *= 1000;
        e /= ticksPerSecond;
    }
    return result;
}

unittest
{
    int a;
    void f0() { }
    //void f1() { auto b = to!(string)(a); }
    void f2() { auto b = (a); }
    auto r = benchmark!(f0, f2)(100);
    //writeln(r);
}
