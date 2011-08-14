// Written in the D programming language.

/**
 * $(RED Deprecated. It will be removed in February 2012.
 *       Please use std.datetime instead.)

Macros:
WIKI = Phobos/StdGregorian

Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
Source:    $(PHOBOSSRC std/_gregorian.d)
*/
/*
         Copyright Andrei Alexandrescu 2010-.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.gregorian;

pragma(msg, "Notice: As of Phobos 2.055, std.gregorian has been deprecated. " ~
            "It will be removed in February 2012. Please use std.datetime instead.");

version(posix) import core.sys.posix.time;
import std.typecons;
import std.conv;
version(unittest) import std.stdio;

deprecated:

version(none) unittest
{
    auto d = Date(2010, May, 1);
    auto d1 = d;
    assert(d.year == 2010);
    assert(d.month == May);
    assert(d.day == 1);
    assert(d.dayOfWeek == 6);
    assert(d.dayOfYear == 121);
    assert(Date(2010, Jan, 5).dayOfYear == 5);
}

version(none) unittest
{
    auto d1 = Date(negInfin);
    auto d2 = Date(posInfin);
    auto d3 = Date(notADateTime);
    auto d4 = Date(maxDateTime);
    auto d5 = Date(minDateTime);
}

version(none) unittest
{
    auto d1 = fromString("2002-1-25");
    auto d2 = fromUndelimitedString("20020125");
}

version(none) unittest
{
    auto d1 = dayClockLocalDay();
    auto d2 = dayClockUniversalDay();
}

alias ushort GregYear;
alias ushort GregMonth;
alias ushort GregDay;
alias uint GregDayOfWeek;
alias uint GregDayOfYear;

enum { Jan = 1, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec }

// Special constants
struct Special { ulong value; }
static immutable
    notADateTime = Special(0),
    negInfin = Special(1),
    posInfin = Special(2),
    minDateTime = Special(3),
    maxDateTime = Special(4),
    notSpecial = Special(5);

struct Date
{
    this(uint year, uint month, uint day)
    {
        immutable
            a = cast(ushort)((14-month)/12),
            y = cast(ushort)(year + 4800 - a),
            m = cast(ushort)(month + 12*a - 3);
        days_ = day + ((153*m + 2)/5) + 365*y + (y/4)
            - (y/100) + (y/400) - 32045;
    }

    this(Special s)
    {
    }

    // Accessors
    @property GregYear year() const
    {
        immutable
            a = days_ + 32044,
            b = (4*a + 3)/146097,
            c = a-((146097*b)/4),
            d = (4*c + 3)/1461,
            e = c - (1461*d)/4,
            m = (5*e + 2)/153;
        //auto day = cast(ushort) (e - ((153*m + 2)/5) + 1);
        //auto month = cast(ushort) (m + 3 - 12 * (m/10));
        immutable year = cast(ushort) (100*b + d - 4800 + (m/10));

        return year;
    }

    @property GregMonth month() const
    {
        immutable
            a = days_ + 32044,
            b = (4*a + 3)/146097,
            c = a-((146097*b)/4),
            d = (4*c + 3)/1461,
            e = c - (1461*d)/4,
            m = (5*e + 2)/153;
        //auto day = cast(ushort) (e - ((153*m + 2)/5) + 1);
        immutable month = cast(ushort) (m + 3 - 12 * (m/10));
        //auto year = cast(ushort) (100*b + d - 4800 + (m/10));

        return month;
    }

    @property GregDay day() const
    {
        immutable
            a = days_ + 32044,
            b = (4*a + 3)/146097,
            c = a-((146097*b)/4),
            d = (4*c + 3)/1461,
            e = c - (1461*d)/4,
            m = (5*e + 2)/153,
            day = cast(ushort) (e - ((153*m + 2)/5) + 1);
        //auto month = cast(ushort) (m + 3 - 12 * (m/10));
        //auto year = cast(ushort) (100*b + d - 4800 + (m/10));

        return day;
    }

    @property Tuple!(GregYear, GregMonth, GregDay)
    yearMonthDay() const
    {
        immutable
            a = days_ + 32044,
            b = (4*a + 3)/146097,
            c = a-((146097*b)/4),
            d = (4*c + 3)/1461,
            e = c - (1461*d)/4,
            m = (5*e + 2)/153;
        auto day = cast(ushort) (e - ((153*m + 2)/5) + 1);
        auto month = cast(ushort) (m + 3 - 12 * (m/10));
        auto year = cast(ushort) (100*b + d - 4800 + (m/10));

        return tuple(year, month, day);
    }

    @property GregDayOfWeek dayOfWeek() const
    {
        immutable
            ymd = yearMonthDay,
            a = cast(ushort) ((14-ymd._1)/12),
            y = cast(ushort) (ymd._0 - a),
            m = cast(ushort) (ymd._1 + 12*a - 2),
            d = cast(ushort) ((ymd._2 + y + (y/4) - (y/100) +
                            (y/400) + (31*m)/12) % 7);
        return d;
    }

    @property GregDayOfYear dayOfYear() const
    {
        const start_of_year = Date(year(), 1, 1);
        auto doy = cast(ushort) ((this - start_of_year).days() + 1);
        return cast(GregDayOfYear) doy;
    }

    @property Date endOfMonth() const
    {
        assert(0);
    }

    @property bool isInfinity() const
    {
        return isNegInfinity || isPosInfinity;
    }

    @property bool isNegInfinity() const
    {
        return days_ == negInfin.value;
    }

    @property bool isPosInfinity() const
    {
        return days_ == posInfin.value;
    }

    @property bool isNotADate() const
    {
        return days_ == notADateTime.value;
    }

    @property bool isSpecial() const
    {
        return isNotADate || isInfinity;
    }

    @property Special asSpecial() const
    {
        return days_ < notSpecial.value
            ? Special(days_)
            : notSpecial;
    }

    @property long modJulianDay() const
    {
        auto ymd = yearMonthDay();
        return julianDay(ymd) - 2400001; //prerounded
    }

    static @property long julianDay(Tuple!(ushort, ushort, ushort) ymd)
    {
        immutable
            a = cast(ushort) ((14-ymd._1)/12),
            y = cast(ushort) (ymd._0 + 4800 - a),
            m = cast(ushort) (ymd._1 + 12*a - 3),
            d = ymd._2 + ((153*m + 2)/5) + 365*y + (y/4) - (y/100)
            + (y/400) - 32045;
        return d;
    }

    static bool isLeapYear(uint year)
    {
        //divisible by 4, not if divisible by 100, but true if
        //divisible by 400
        return (!(year % 4)) && ((year % 100) || (!(year % 400)));
    }

    @property int weekNumber() const
    {
        auto
            ymd = yearMonthDay,
            julianbegin = julianDay(tuple(cast(ushort)ymd._0,
                            cast(ushort)1, cast(ushort)1)),
            juliantoday = julianDay(ymd);
        long day = (julianbegin + 3) % 7;
        ulong week = (juliantoday + day - julianbegin + 4)/7;

        if ((week >= 1) && (week <= 52))
        {
            return cast(int) week;
        }

        if ((week == 53))
        {
            if((day==6) ||(day == 5 && isLeapYear(ymd._0)))
            {
                return cast(int) week; //under these circumstances week == 53.
            }
            else
            {
                return 1; //monday - wednesday is in week 1 of next year
            }
        }

        //if the week is not in current year recalculate using the
        //previous year as the beginning year
        else
            if (week == 0)
            {
                julianbegin = julianDay(
                    tuple(cast(ushort) (ymd._0 - 1), cast(ushort) 1,
                            cast(ushort) 1));
                juliantoday = julianDay(ymd);
                day = (julianbegin + 3) % 7;
                week = (juliantoday + day - julianbegin + 4)/7;
                return cast(int) week;
            }
        return cast(int) week;  //not reachable -- well except if day == 5 and
                      //is_leap_year != true
    }

    @property uint endOfMonthDay() const
    {
        switch (month) {
            case 2:
                if (isLeapYear(year)) {
                    return 29;
                } else {
                    return 28;
                };
            case 4:
            case 6:
            case 9:
            case 11:
                return 30;
            default:
                return 31;
        }
    }

    @property string toSimpleString() const
    {
        auto ymd = yearMonthDay;
        return text(ymd._0, '-', ymd._1, '-', ymd._2);
    }

    @property string toIsoString() const
    {
        assert(0);
    }

    @property string toIsoExtendedString() const
    {
        assert(0);
    }

    bool opEquals(ref const Date rhs) const
    {
        return days_ == rhs.days_;
    }

    int opCmp(in Date rhs) const
    {
        return days_ < rhs.days_ ? -1 : days_ > rhs.days_ ? 1 : 0;
    }

    // Date opBinary(string op)(const Date d) const
    // if (op == "-")
    // {
    // }

    Days opBinary(string op)(const Date d) const
    if (op == "-")
    {
        if (!isSpecial && !d.isSpecial)
        {
            return Days(days_ - d.days_);
        }
        else
        {
            assert(0);
        }
    }

    static if (is(tm))
    {
        tm toTm()
        {
            assert(0);
        }
    }

    private ulong days_;
}

struct Days
{
    private long days_;
    this(long d) { days_ = d; }
    this(Special s) { }
    @property long days() const { return days_; }
    @property bool isNegative() const { return days_ < 0; }
    @property static Days unit() { return Days(1); }
    @property bool isSpecial()
    {
        assert(0);
    }
    bool opEquals(ref const Days rhs) const
    {
        return days_ == rhs.days_;
    }

    int opCmp(in Days rhs) const
    {
        return days_ < rhs.days_ ? -1 : days_ > rhs.days_ ? 1 : 0;
    }

    Days opBinary(string op)(Days d) const
    if (op == "+" || op == "-")
    {
    }
}

Date fromString(in char[] s)
{
    Date result;
    return result;
}

Date fromUndelimitedString(in char[] s)
{
    Date result;
    return result;
}

Date dayClockLocalDay()
{
    Date result;
    return result;
}

Date dayClockUniversalDay()
{
    Date result;
    return result;
}

static if (is(tm))
{
    Date dateFromTm(tm)
    {
        assert(0);
    }
}
