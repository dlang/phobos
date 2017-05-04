// Written in the D programming language

/++
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonathan M Davis
    Source:    $(PHOBOSSRC std/_datetime.d)
    Macros:
        LREF2=<a href="#$1">$(D $2)</a>
+/
module std.datetime.timeofday;

import core.time;
import std.datetime.common;
import std.traits : isSomeString;

version(unittest) import std.exception : assertThrown;


/++
    Represents a time of day with hours, minutes, and seconds. It uses 24 hour
    time.
+/
struct TimeOfDay
{
public:

    /++
        Params:
            hour   = Hour of the day [0 - 24$(RPAREN).
            minute = Minute of the hour [0 - 60$(RPAREN).
            second = Second of the minute [0 - 60$(RPAREN).

        Throws:
            $(LREF DateTimeException) if the resulting $(LREF TimeOfDay) would be not
            be valid.
     +/
    this(int hour, int minute, int second = 0) @safe pure
    {
        enforceValid!"hours"(hour);
        enforceValid!"minutes"(minute);
        enforceValid!"seconds"(second);

        _hour   = cast(ubyte) hour;
        _minute = cast(ubyte) minute;
        _second = cast(ubyte) second;
    }

    @safe unittest
    {
        assert(TimeOfDay(0, 0) == TimeOfDay.init);

        {
            auto tod = TimeOfDay(0, 0);
            assert(tod._hour == 0);
            assert(tod._minute == 0);
            assert(tod._second == 0);
        }

        {
            auto tod = TimeOfDay(12, 30, 33);
            assert(tod._hour == 12);
            assert(tod._minute == 30);
            assert(tod._second == 33);
        }

        {
            auto tod = TimeOfDay(23, 59, 59);
            assert(tod._hour == 23);
            assert(tod._minute == 59);
            assert(tod._second == 59);
        }

        assertThrown!DateTimeException(TimeOfDay(24, 0, 0));
        assertThrown!DateTimeException(TimeOfDay(0, 60, 0));
        assertThrown!DateTimeException(TimeOfDay(0, 0, 60));
    }


    /++
        Compares this $(LREF TimeOfDay) with the given $(LREF TimeOfDay).

        Returns:
            $(BOOKTABLE,
            $(TR $(TD this &lt; rhs) $(TD &lt; 0))
            $(TR $(TD this == rhs) $(TD 0))
            $(TR $(TD this &gt; rhs) $(TD &gt; 0))
            )
     +/
    int opCmp(in TimeOfDay rhs) @safe const pure nothrow
    {
        if (_hour < rhs._hour)
            return -1;
        if (_hour > rhs._hour)
            return 1;

        if (_minute < rhs._minute)
            return -1;
        if (_minute > rhs._minute)
            return 1;

        if (_second < rhs._second)
            return -1;
        if (_second > rhs._second)
            return 1;

        return 0;
    }

    @safe unittest
    {
        assert(TimeOfDay(0, 0, 0).opCmp(TimeOfDay.init) == 0);

        assert(TimeOfDay(0, 0, 0).opCmp(TimeOfDay(0, 0, 0)) == 0);
        assert(TimeOfDay(12, 0, 0).opCmp(TimeOfDay(12, 0, 0)) == 0);
        assert(TimeOfDay(0, 30, 0).opCmp(TimeOfDay(0, 30, 0)) == 0);
        assert(TimeOfDay(0, 0, 33).opCmp(TimeOfDay(0, 0, 33)) == 0);

        assert(TimeOfDay(12, 30, 0).opCmp(TimeOfDay(12, 30, 0)) == 0);
        assert(TimeOfDay(12, 30, 33).opCmp(TimeOfDay(12, 30, 33)) == 0);

        assert(TimeOfDay(0, 30, 33).opCmp(TimeOfDay(0, 30, 33)) == 0);
        assert(TimeOfDay(0, 0, 33).opCmp(TimeOfDay(0, 0, 33)) == 0);

        assert(TimeOfDay(12, 30, 33).opCmp(TimeOfDay(13, 30, 33)) < 0);
        assert(TimeOfDay(13, 30, 33).opCmp(TimeOfDay(12, 30, 33)) > 0);
        assert(TimeOfDay(12, 30, 33).opCmp(TimeOfDay(12, 31, 33)) < 0);
        assert(TimeOfDay(12, 31, 33).opCmp(TimeOfDay(12, 30, 33)) > 0);
        assert(TimeOfDay(12, 30, 33).opCmp(TimeOfDay(12, 30, 34)) < 0);
        assert(TimeOfDay(12, 30, 34).opCmp(TimeOfDay(12, 30, 33)) > 0);

        assert(TimeOfDay(13, 30, 33).opCmp(TimeOfDay(12, 30, 34)) > 0);
        assert(TimeOfDay(12, 30, 34).opCmp(TimeOfDay(13, 30, 33)) < 0);
        assert(TimeOfDay(13, 30, 33).opCmp(TimeOfDay(12, 31, 33)) > 0);
        assert(TimeOfDay(12, 31, 33).opCmp(TimeOfDay(13, 30, 33)) < 0);

        assert(TimeOfDay(12, 31, 33).opCmp(TimeOfDay(12, 30, 34)) > 0);
        assert(TimeOfDay(12, 30, 34).opCmp(TimeOfDay(12, 31, 33)) < 0);

        const ctod = TimeOfDay(12, 30, 33);
        immutable itod = TimeOfDay(12, 30, 33);
        assert(ctod.opCmp(itod) == 0);
        assert(itod.opCmp(ctod) == 0);
    }


    /++
        Hours past midnight.
     +/
    @property ubyte hour() @safe const pure nothrow
    {
        return _hour;
    }

    @safe unittest
    {
        assert(TimeOfDay.init.hour == 0);
        assert(TimeOfDay(12, 0, 0).hour == 12);

        const ctod = TimeOfDay(12, 0, 0);
        immutable itod = TimeOfDay(12, 0, 0);
        assert(ctod.hour == 12);
        assert(itod.hour == 12);
    }


    /++
        Hours past midnight.

        Params:
            hour = The hour of the day to set this $(LREF TimeOfDay)'s hour to.

        Throws:
            $(LREF DateTimeException) if the given hour would result in an invalid
            $(LREF TimeOfDay).
     +/
    @property void hour(int hour) @safe pure
    {
        enforceValid!"hours"(hour);
        _hour = cast(ubyte) hour;
    }

    @safe unittest
    {
        assertThrown!DateTimeException((){TimeOfDay(0, 0, 0).hour = 24;}());

        auto tod = TimeOfDay(0, 0, 0);
        tod.hour = 12;
        assert(tod == TimeOfDay(12, 0, 0));

        const ctod = TimeOfDay(0, 0, 0);
        immutable itod = TimeOfDay(0, 0, 0);
        static assert(!__traits(compiles, ctod.hour = 12));
        static assert(!__traits(compiles, itod.hour = 12));
    }


    /++
        Minutes past the hour.
     +/
    @property ubyte minute() @safe const pure nothrow
    {
        return _minute;
    }

    @safe unittest
    {
        assert(TimeOfDay.init.minute == 0);
        assert(TimeOfDay(0, 30, 0).minute == 30);

        const ctod = TimeOfDay(0, 30, 0);
        immutable itod = TimeOfDay(0, 30, 0);
        assert(ctod.minute == 30);
        assert(itod.minute == 30);
    }


    /++
        Minutes past the hour.

        Params:
            minute = The minute to set this $(LREF TimeOfDay)'s minute to.

        Throws:
            $(LREF DateTimeException) if the given minute would result in an
            invalid $(LREF TimeOfDay).
     +/
    @property void minute(int minute) @safe pure
    {
        enforceValid!"minutes"(minute);
        _minute = cast(ubyte) minute;
    }

    @safe unittest
    {
        assertThrown!DateTimeException((){TimeOfDay(0, 0, 0).minute = 60;}());

        auto tod = TimeOfDay(0, 0, 0);
        tod.minute = 30;
        assert(tod == TimeOfDay(0, 30, 0));

        const ctod = TimeOfDay(0, 0, 0);
        immutable itod = TimeOfDay(0, 0, 0);
        static assert(!__traits(compiles, ctod.minute = 30));
        static assert(!__traits(compiles, itod.minute = 30));
    }


    /++
        Seconds past the minute.
     +/
    @property ubyte second() @safe const pure nothrow
    {
        return _second;
    }

    @safe unittest
    {
        assert(TimeOfDay.init.second == 0);
        assert(TimeOfDay(0, 0, 33).second == 33);

        const ctod = TimeOfDay(0, 0, 33);
        immutable itod = TimeOfDay(0, 0, 33);
        assert(ctod.second == 33);
        assert(itod.second == 33);
    }


    /++
        Seconds past the minute.

        Params:
            second = The second to set this $(LREF TimeOfDay)'s second to.

        Throws:
            $(LREF DateTimeException) if the given second would result in an
            invalid $(LREF TimeOfDay).
     +/
    @property void second(int second) @safe pure
    {
        enforceValid!"seconds"(second);
        _second = cast(ubyte) second;
    }

    @safe unittest
    {
        assertThrown!DateTimeException((){TimeOfDay(0, 0, 0).second = 60;}());

        auto tod = TimeOfDay(0, 0, 0);
        tod.second = 33;
        assert(tod == TimeOfDay(0, 0, 33));

        const ctod = TimeOfDay(0, 0, 0);
        immutable itod = TimeOfDay(0, 0, 0);
        static assert(!__traits(compiles, ctod.second = 33));
        static assert(!__traits(compiles, itod.second = 33));
    }


    /++
        Adds the given number of units to this $(LREF TimeOfDay). A negative number
        will subtract.

        The difference between rolling and adding is that rolling does not
        affect larger units. For instance, rolling a $(LREF TimeOfDay)
        one hours's worth of minutes gets the exact same
        $(LREF TimeOfDay).

        Accepted units are $(D "hours"), $(D "minutes"), and $(D "seconds").

        Params:
            units = The units to add.
            value = The number of $(D_PARAM units) to add to this
                    $(LREF TimeOfDay).
      +/
    ref TimeOfDay roll(string units)(long value) @safe pure nothrow
        if (units == "hours")
    {
        return this += dur!"hours"(value);
    }

    ///
    @safe unittest
    {
        auto tod1 = TimeOfDay(7, 12, 0);
        tod1.roll!"hours"(1);
        assert(tod1 == TimeOfDay(8, 12, 0));

        auto tod2 = TimeOfDay(7, 12, 0);
        tod2.roll!"hours"(-1);
        assert(tod2 == TimeOfDay(6, 12, 0));

        auto tod3 = TimeOfDay(23, 59, 0);
        tod3.roll!"minutes"(1);
        assert(tod3 == TimeOfDay(23, 0, 0));

        auto tod4 = TimeOfDay(0, 0, 0);
        tod4.roll!"minutes"(-1);
        assert(tod4 == TimeOfDay(0, 59, 0));

        auto tod5 = TimeOfDay(23, 59, 59);
        tod5.roll!"seconds"(1);
        assert(tod5 == TimeOfDay(23, 59, 0));

        auto tod6 = TimeOfDay(0, 0, 0);
        tod6.roll!"seconds"(-1);
        assert(tod6 == TimeOfDay(0, 0, 59));
    }

    @safe unittest
    {
        auto tod = TimeOfDay(12, 27, 2);
        tod.roll!"hours"(22).roll!"hours"(-7);
        assert(tod == TimeOfDay(3, 27, 2));

        const ctod = TimeOfDay(0, 0, 0);
        immutable itod = TimeOfDay(0, 0, 0);
        static assert(!__traits(compiles, ctod.roll!"hours"(53)));
        static assert(!__traits(compiles, itod.roll!"hours"(53)));
    }


    // Shares documentation with "hours" version.
    ref TimeOfDay roll(string units)(long value) @safe pure nothrow
        if (units == "minutes" || units == "seconds")
    {
        import std.format : format;

        enum memberVarStr = units[0 .. $ - 1];
        value %= 60;
        mixin(format("auto newVal = cast(ubyte)(_%s) + value;", memberVarStr));

        if (value < 0)
        {
            if (newVal < 0)
                newVal += 60;
        }
        else if (newVal >= 60)
            newVal -= 60;

        mixin(format("_%s = cast(ubyte) newVal;", memberVarStr));
        return this;
    }

    // Test roll!"minutes"().
    @safe unittest
    {
        static void testTOD(TimeOfDay orig, int minutes, in TimeOfDay expected, size_t line = __LINE__)
        {
            orig.roll!"minutes"(minutes);
            assert(orig == expected);
        }

        testTOD(TimeOfDay(12, 30, 33), 0, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 1, TimeOfDay(12, 31, 33));
        testTOD(TimeOfDay(12, 30, 33), 2, TimeOfDay(12, 32, 33));
        testTOD(TimeOfDay(12, 30, 33), 3, TimeOfDay(12, 33, 33));
        testTOD(TimeOfDay(12, 30, 33), 4, TimeOfDay(12, 34, 33));
        testTOD(TimeOfDay(12, 30, 33), 5, TimeOfDay(12, 35, 33));
        testTOD(TimeOfDay(12, 30, 33), 10, TimeOfDay(12, 40, 33));
        testTOD(TimeOfDay(12, 30, 33), 15, TimeOfDay(12, 45, 33));
        testTOD(TimeOfDay(12, 30, 33), 29, TimeOfDay(12, 59, 33));
        testTOD(TimeOfDay(12, 30, 33), 30, TimeOfDay(12, 0, 33));
        testTOD(TimeOfDay(12, 30, 33), 45, TimeOfDay(12, 15, 33));
        testTOD(TimeOfDay(12, 30, 33), 60, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 75, TimeOfDay(12, 45, 33));
        testTOD(TimeOfDay(12, 30, 33), 90, TimeOfDay(12, 0, 33));
        testTOD(TimeOfDay(12, 30, 33), 100, TimeOfDay(12, 10, 33));

        testTOD(TimeOfDay(12, 30, 33), 689, TimeOfDay(12, 59, 33));
        testTOD(TimeOfDay(12, 30, 33), 690, TimeOfDay(12, 0, 33));
        testTOD(TimeOfDay(12, 30, 33), 691, TimeOfDay(12, 1, 33));
        testTOD(TimeOfDay(12, 30, 33), 960, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 1439, TimeOfDay(12, 29, 33));
        testTOD(TimeOfDay(12, 30, 33), 1440, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 1441, TimeOfDay(12, 31, 33));
        testTOD(TimeOfDay(12, 30, 33), 2880, TimeOfDay(12, 30, 33));

        testTOD(TimeOfDay(12, 30, 33), -1, TimeOfDay(12, 29, 33));
        testTOD(TimeOfDay(12, 30, 33), -2, TimeOfDay(12, 28, 33));
        testTOD(TimeOfDay(12, 30, 33), -3, TimeOfDay(12, 27, 33));
        testTOD(TimeOfDay(12, 30, 33), -4, TimeOfDay(12, 26, 33));
        testTOD(TimeOfDay(12, 30, 33), -5, TimeOfDay(12, 25, 33));
        testTOD(TimeOfDay(12, 30, 33), -10, TimeOfDay(12, 20, 33));
        testTOD(TimeOfDay(12, 30, 33), -15, TimeOfDay(12, 15, 33));
        testTOD(TimeOfDay(12, 30, 33), -29, TimeOfDay(12, 1, 33));
        testTOD(TimeOfDay(12, 30, 33), -30, TimeOfDay(12, 0, 33));
        testTOD(TimeOfDay(12, 30, 33), -45, TimeOfDay(12, 45, 33));
        testTOD(TimeOfDay(12, 30, 33), -60, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), -75, TimeOfDay(12, 15, 33));
        testTOD(TimeOfDay(12, 30, 33), -90, TimeOfDay(12, 0, 33));
        testTOD(TimeOfDay(12, 30, 33), -100, TimeOfDay(12, 50, 33));

        testTOD(TimeOfDay(12, 30, 33), -749, TimeOfDay(12, 1, 33));
        testTOD(TimeOfDay(12, 30, 33), -750, TimeOfDay(12, 0, 33));
        testTOD(TimeOfDay(12, 30, 33), -751, TimeOfDay(12, 59, 33));
        testTOD(TimeOfDay(12, 30, 33), -960, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), -1439, TimeOfDay(12, 31, 33));
        testTOD(TimeOfDay(12, 30, 33), -1440, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), -1441, TimeOfDay(12, 29, 33));
        testTOD(TimeOfDay(12, 30, 33), -2880, TimeOfDay(12, 30, 33));

        testTOD(TimeOfDay(12, 0, 33), 1, TimeOfDay(12, 1, 33));
        testTOD(TimeOfDay(12, 0, 33), 0, TimeOfDay(12, 0, 33));
        testTOD(TimeOfDay(12, 0, 33), -1, TimeOfDay(12, 59, 33));

        testTOD(TimeOfDay(11, 59, 33), 1, TimeOfDay(11, 0, 33));
        testTOD(TimeOfDay(11, 59, 33), 0, TimeOfDay(11, 59, 33));
        testTOD(TimeOfDay(11, 59, 33), -1, TimeOfDay(11, 58, 33));

        testTOD(TimeOfDay(0, 0, 33), 1, TimeOfDay(0, 1, 33));
        testTOD(TimeOfDay(0, 0, 33), 0, TimeOfDay(0, 0, 33));
        testTOD(TimeOfDay(0, 0, 33), -1, TimeOfDay(0, 59, 33));

        testTOD(TimeOfDay(23, 59, 33), 1, TimeOfDay(23, 0, 33));
        testTOD(TimeOfDay(23, 59, 33), 0, TimeOfDay(23, 59, 33));
        testTOD(TimeOfDay(23, 59, 33), -1, TimeOfDay(23, 58, 33));

        auto tod = TimeOfDay(12, 27, 2);
        tod.roll!"minutes"(97).roll!"minutes"(-102);
        assert(tod == TimeOfDay(12, 22, 2));

        const ctod = TimeOfDay(0, 0, 0);
        immutable itod = TimeOfDay(0, 0, 0);
        static assert(!__traits(compiles, ctod.roll!"minutes"(7)));
        static assert(!__traits(compiles, itod.roll!"minutes"(7)));
    }

    // Test roll!"seconds"().
    @safe unittest
    {
        static void testTOD(TimeOfDay orig, int seconds, in TimeOfDay expected, size_t line = __LINE__)
        {
            orig.roll!"seconds"(seconds);
            assert(orig == expected);
        }

        testTOD(TimeOfDay(12, 30, 33), 0, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 1, TimeOfDay(12, 30, 34));
        testTOD(TimeOfDay(12, 30, 33), 2, TimeOfDay(12, 30, 35));
        testTOD(TimeOfDay(12, 30, 33), 3, TimeOfDay(12, 30, 36));
        testTOD(TimeOfDay(12, 30, 33), 4, TimeOfDay(12, 30, 37));
        testTOD(TimeOfDay(12, 30, 33), 5, TimeOfDay(12, 30, 38));
        testTOD(TimeOfDay(12, 30, 33), 10, TimeOfDay(12, 30, 43));
        testTOD(TimeOfDay(12, 30, 33), 15, TimeOfDay(12, 30, 48));
        testTOD(TimeOfDay(12, 30, 33), 26, TimeOfDay(12, 30, 59));
        testTOD(TimeOfDay(12, 30, 33), 27, TimeOfDay(12, 30, 0));
        testTOD(TimeOfDay(12, 30, 33), 30, TimeOfDay(12, 30, 3));
        testTOD(TimeOfDay(12, 30, 33), 59, TimeOfDay(12, 30, 32));
        testTOD(TimeOfDay(12, 30, 33), 60, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 61, TimeOfDay(12, 30, 34));

        testTOD(TimeOfDay(12, 30, 33), 1766, TimeOfDay(12, 30, 59));
        testTOD(TimeOfDay(12, 30, 33), 1767, TimeOfDay(12, 30, 0));
        testTOD(TimeOfDay(12, 30, 33), 1768, TimeOfDay(12, 30, 1));
        testTOD(TimeOfDay(12, 30, 33), 2007, TimeOfDay(12, 30, 0));
        testTOD(TimeOfDay(12, 30, 33), 3599, TimeOfDay(12, 30, 32));
        testTOD(TimeOfDay(12, 30, 33), 3600, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 3601, TimeOfDay(12, 30, 34));
        testTOD(TimeOfDay(12, 30, 33), 7200, TimeOfDay(12, 30, 33));

        testTOD(TimeOfDay(12, 30, 33), -1, TimeOfDay(12, 30, 32));
        testTOD(TimeOfDay(12, 30, 33), -2, TimeOfDay(12, 30, 31));
        testTOD(TimeOfDay(12, 30, 33), -3, TimeOfDay(12, 30, 30));
        testTOD(TimeOfDay(12, 30, 33), -4, TimeOfDay(12, 30, 29));
        testTOD(TimeOfDay(12, 30, 33), -5, TimeOfDay(12, 30, 28));
        testTOD(TimeOfDay(12, 30, 33), -10, TimeOfDay(12, 30, 23));
        testTOD(TimeOfDay(12, 30, 33), -15, TimeOfDay(12, 30, 18));
        testTOD(TimeOfDay(12, 30, 33), -33, TimeOfDay(12, 30, 0));
        testTOD(TimeOfDay(12, 30, 33), -34, TimeOfDay(12, 30, 59));
        testTOD(TimeOfDay(12, 30, 33), -35, TimeOfDay(12, 30, 58));
        testTOD(TimeOfDay(12, 30, 33), -59, TimeOfDay(12, 30, 34));
        testTOD(TimeOfDay(12, 30, 33), -60, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), -61, TimeOfDay(12, 30, 32));

        testTOD(TimeOfDay(12, 30, 0), 1, TimeOfDay(12, 30, 1));
        testTOD(TimeOfDay(12, 30, 0), 0, TimeOfDay(12, 30, 0));
        testTOD(TimeOfDay(12, 30, 0), -1, TimeOfDay(12, 30, 59));

        testTOD(TimeOfDay(12, 0, 0), 1, TimeOfDay(12, 0, 1));
        testTOD(TimeOfDay(12, 0, 0), 0, TimeOfDay(12, 0, 0));
        testTOD(TimeOfDay(12, 0, 0), -1, TimeOfDay(12, 0, 59));

        testTOD(TimeOfDay(0, 0, 0), 1, TimeOfDay(0, 0, 1));
        testTOD(TimeOfDay(0, 0, 0), 0, TimeOfDay(0, 0, 0));
        testTOD(TimeOfDay(0, 0, 0), -1, TimeOfDay(0, 0, 59));

        testTOD(TimeOfDay(23, 59, 59), 1, TimeOfDay(23, 59, 0));
        testTOD(TimeOfDay(23, 59, 59), 0, TimeOfDay(23, 59, 59));
        testTOD(TimeOfDay(23, 59, 59), -1, TimeOfDay(23, 59, 58));

        auto tod = TimeOfDay(12, 27, 2);
        tod.roll!"seconds"(105).roll!"seconds"(-77);
        assert(tod == TimeOfDay(12, 27, 30));

        const ctod = TimeOfDay(0, 0, 0);
        immutable itod = TimeOfDay(0, 0, 0);
        static assert(!__traits(compiles, ctod.roll!"seconds"(7)));
        static assert(!__traits(compiles, itod.roll!"seconds"(7)));
    }


    /++
        Gives the result of adding or subtracting a $(REF Duration, core,time) from
        this $(LREF TimeOfDay).

        The legal types of arithmetic for $(LREF TimeOfDay) using this operator
        are

        $(BOOKTABLE,
        $(TR $(TD TimeOfDay) $(TD +) $(TD Duration) $(TD -->) $(TD TimeOfDay))
        $(TR $(TD TimeOfDay) $(TD -) $(TD Duration) $(TD -->) $(TD TimeOfDay))
        )

        Params:
            duration = The $(REF Duration, core,time) to add to or subtract from
                       this $(LREF TimeOfDay).
      +/
    TimeOfDay opBinary(string op)(Duration duration) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        TimeOfDay retval = this;
        immutable seconds = duration.total!"seconds";
        mixin("return retval._addSeconds(" ~ op ~ "seconds);");
    }

    ///
    @safe unittest
    {
        assert(TimeOfDay(12, 12, 12) + seconds(1) == TimeOfDay(12, 12, 13));
        assert(TimeOfDay(12, 12, 12) + minutes(1) == TimeOfDay(12, 13, 12));
        assert(TimeOfDay(12, 12, 12) + hours(1) == TimeOfDay(13, 12, 12));
        assert(TimeOfDay(23, 59, 59) + seconds(1) == TimeOfDay(0, 0, 0));

        assert(TimeOfDay(12, 12, 12) - seconds(1) == TimeOfDay(12, 12, 11));
        assert(TimeOfDay(12, 12, 12) - minutes(1) == TimeOfDay(12, 11, 12));
        assert(TimeOfDay(12, 12, 12) - hours(1) == TimeOfDay(11, 12, 12));
        assert(TimeOfDay(0, 0, 0) - seconds(1) == TimeOfDay(23, 59, 59));
    }

    @safe unittest
    {
        auto tod = TimeOfDay(12, 30, 33);

        assert(tod + dur!"hours"(7) == TimeOfDay(19, 30, 33));
        assert(tod + dur!"hours"(-7) == TimeOfDay(5, 30, 33));
        assert(tod + dur!"minutes"(7) == TimeOfDay(12, 37, 33));
        assert(tod + dur!"minutes"(-7) == TimeOfDay(12, 23, 33));
        assert(tod + dur!"seconds"(7) == TimeOfDay(12, 30, 40));
        assert(tod + dur!"seconds"(-7) == TimeOfDay(12, 30, 26));

        assert(tod + dur!"msecs"(7000) == TimeOfDay(12, 30, 40));
        assert(tod + dur!"msecs"(-7000) == TimeOfDay(12, 30, 26));
        assert(tod + dur!"usecs"(7_000_000) == TimeOfDay(12, 30, 40));
        assert(tod + dur!"usecs"(-7_000_000) == TimeOfDay(12, 30, 26));
        assert(tod + dur!"hnsecs"(70_000_000) == TimeOfDay(12, 30, 40));
        assert(tod + dur!"hnsecs"(-70_000_000) == TimeOfDay(12, 30, 26));

        assert(tod - dur!"hours"(-7) == TimeOfDay(19, 30, 33));
        assert(tod - dur!"hours"(7) == TimeOfDay(5, 30, 33));
        assert(tod - dur!"minutes"(-7) == TimeOfDay(12, 37, 33));
        assert(tod - dur!"minutes"(7) == TimeOfDay(12, 23, 33));
        assert(tod - dur!"seconds"(-7) == TimeOfDay(12, 30, 40));
        assert(tod - dur!"seconds"(7) == TimeOfDay(12, 30, 26));

        assert(tod - dur!"msecs"(-7000) == TimeOfDay(12, 30, 40));
        assert(tod - dur!"msecs"(7000) == TimeOfDay(12, 30, 26));
        assert(tod - dur!"usecs"(-7_000_000) == TimeOfDay(12, 30, 40));
        assert(tod - dur!"usecs"(7_000_000) == TimeOfDay(12, 30, 26));
        assert(tod - dur!"hnsecs"(-70_000_000) == TimeOfDay(12, 30, 40));
        assert(tod - dur!"hnsecs"(70_000_000) == TimeOfDay(12, 30, 26));

        auto duration = dur!"hours"(11);
        const ctod = TimeOfDay(12, 30, 33);
        immutable itod = TimeOfDay(12, 30, 33);
        assert(tod + duration == TimeOfDay(23, 30, 33));
        assert(ctod + duration == TimeOfDay(23, 30, 33));
        assert(itod + duration == TimeOfDay(23, 30, 33));

        assert(tod - duration == TimeOfDay(1, 30, 33));
        assert(ctod - duration == TimeOfDay(1, 30, 33));
        assert(itod - duration == TimeOfDay(1, 30, 33));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    TimeOfDay opBinary(string op)(TickDuration td) @safe const pure nothrow
        if (op == "+" || op == "-")
    {
        TimeOfDay retval = this;
        immutable seconds = td.seconds;
        mixin("return retval._addSeconds(" ~ op ~ "seconds);");
    }

    deprecated @safe unittest
    {
        // This probably only runs in cases where gettimeofday() is used, but it's
        // hard to do this test correctly with variable ticksPerSec.
        if (TickDuration.ticksPerSec == 1_000_000)
        {
            auto tod = TimeOfDay(12, 30, 33);

            assert(tod + TickDuration.from!"usecs"(7_000_000) == TimeOfDay(12, 30, 40));
            assert(tod + TickDuration.from!"usecs"(-7_000_000) == TimeOfDay(12, 30, 26));

            assert(tod - TickDuration.from!"usecs"(-7_000_000) == TimeOfDay(12, 30, 40));
            assert(tod - TickDuration.from!"usecs"(7_000_000) == TimeOfDay(12, 30, 26));
        }
    }


    /++
        Gives the result of adding or subtracting a $(REF Duration, core,time) from
        this $(LREF TimeOfDay), as well as assigning the result to this
        $(LREF TimeOfDay).

        The legal types of arithmetic for $(LREF TimeOfDay) using this operator
        are

        $(BOOKTABLE,
        $(TR $(TD TimeOfDay) $(TD +) $(TD Duration) $(TD -->) $(TD TimeOfDay))
        $(TR $(TD TimeOfDay) $(TD -) $(TD Duration) $(TD -->) $(TD TimeOfDay))
        )

        Params:
            duration = The $(REF Duration, core,time) to add to or subtract from
                       this $(LREF TimeOfDay).
      +/
    ref TimeOfDay opOpAssign(string op)(Duration duration) @safe pure nothrow
        if (op == "+" || op == "-")
    {
        immutable seconds = duration.total!"seconds";
        mixin("return _addSeconds(" ~ op ~ "seconds);");
    }

    @safe unittest
    {
        auto duration = dur!"hours"(12);

        assert(TimeOfDay(12, 30, 33) + dur!"hours"(7) == TimeOfDay(19, 30, 33));
        assert(TimeOfDay(12, 30, 33) + dur!"hours"(-7) == TimeOfDay(5, 30, 33));
        assert(TimeOfDay(12, 30, 33) + dur!"minutes"(7) == TimeOfDay(12, 37, 33));
        assert(TimeOfDay(12, 30, 33) + dur!"minutes"(-7) == TimeOfDay(12, 23, 33));
        assert(TimeOfDay(12, 30, 33) + dur!"seconds"(7) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) + dur!"seconds"(-7) == TimeOfDay(12, 30, 26));

        assert(TimeOfDay(12, 30, 33) + dur!"msecs"(7000) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) + dur!"msecs"(-7000) == TimeOfDay(12, 30, 26));
        assert(TimeOfDay(12, 30, 33) + dur!"usecs"(7_000_000) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) + dur!"usecs"(-7_000_000) == TimeOfDay(12, 30, 26));
        assert(TimeOfDay(12, 30, 33) + dur!"hnsecs"(70_000_000) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) + dur!"hnsecs"(-70_000_000) == TimeOfDay(12, 30, 26));

        assert(TimeOfDay(12, 30, 33) - dur!"hours"(-7) == TimeOfDay(19, 30, 33));
        assert(TimeOfDay(12, 30, 33) - dur!"hours"(7) == TimeOfDay(5, 30, 33));
        assert(TimeOfDay(12, 30, 33) - dur!"minutes"(-7) == TimeOfDay(12, 37, 33));
        assert(TimeOfDay(12, 30, 33) - dur!"minutes"(7) == TimeOfDay(12, 23, 33));
        assert(TimeOfDay(12, 30, 33) - dur!"seconds"(-7) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) - dur!"seconds"(7) == TimeOfDay(12, 30, 26));

        assert(TimeOfDay(12, 30, 33) - dur!"msecs"(-7000) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) - dur!"msecs"(7000) == TimeOfDay(12, 30, 26));
        assert(TimeOfDay(12, 30, 33) - dur!"usecs"(-7_000_000) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) - dur!"usecs"(7_000_000) == TimeOfDay(12, 30, 26));
        assert(TimeOfDay(12, 30, 33) - dur!"hnsecs"(-70_000_000) == TimeOfDay(12, 30, 40));
        assert(TimeOfDay(12, 30, 33) - dur!"hnsecs"(70_000_000) == TimeOfDay(12, 30, 26));

        auto tod = TimeOfDay(19, 17, 22);
        (tod += dur!"seconds"(9)) += dur!"seconds"(-7292);
        assert(tod == TimeOfDay(17, 15, 59));

        const ctod = TimeOfDay(12, 33, 30);
        immutable itod = TimeOfDay(12, 33, 30);
        static assert(!__traits(compiles, ctod += duration));
        static assert(!__traits(compiles, itod += duration));
        static assert(!__traits(compiles, ctod -= duration));
        static assert(!__traits(compiles, itod -= duration));
    }

    // Explicitly undocumented. It will be removed in January 2018. @@@DEPRECATED_2018-01@@@
    deprecated("Use Duration instead of TickDuration.")
    ref TimeOfDay opOpAssign(string op)(TickDuration td) @safe pure nothrow
        if (op == "+" || op == "-")
    {
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
                auto tod = TimeOfDay(12, 30, 33);
                tod += TickDuration.from!"usecs"(7_000_000);
                assert(tod == TimeOfDay(12, 30, 40));
            }

            {
                auto tod = TimeOfDay(12, 30, 33);
                tod += TickDuration.from!"usecs"(-7_000_000);
                assert(tod == TimeOfDay(12, 30, 26));
            }

            {
                auto tod = TimeOfDay(12, 30, 33);
                tod -= TickDuration.from!"usecs"(-7_000_000);
                assert(tod == TimeOfDay(12, 30, 40));
            }

            {
                auto tod = TimeOfDay(12, 30, 33);
                tod -= TickDuration.from!"usecs"(7_000_000);
                assert(tod == TimeOfDay(12, 30, 26));
            }
        }
    }


    /++
        Gives the difference between two $(LREF TimeOfDay)s.

        The legal types of arithmetic for $(LREF TimeOfDay) using this operator are

        $(BOOKTABLE,
        $(TR $(TD TimeOfDay) $(TD -) $(TD TimeOfDay) $(TD -->) $(TD duration))
        )

        Params:
            rhs = The $(LREF TimeOfDay) to subtract from this one.
      +/
    Duration opBinary(string op)(in TimeOfDay rhs) @safe const pure nothrow
        if (op == "-")
    {
        immutable lhsSec = _hour * 3600 + _minute * 60 + _second;
        immutable rhsSec = rhs._hour * 3600 + rhs._minute * 60 + rhs._second;

        return dur!"seconds"(lhsSec - rhsSec);
    }

    @safe unittest
    {
        auto tod = TimeOfDay(12, 30, 33);

        assert(TimeOfDay(7, 12, 52) - TimeOfDay(12, 30, 33) == dur!"seconds"(-19_061));
        assert(TimeOfDay(12, 30, 33) - TimeOfDay(7, 12, 52) == dur!"seconds"(19_061));
        assert(TimeOfDay(12, 30, 33) - TimeOfDay(14, 30, 33) == dur!"seconds"(-7200));
        assert(TimeOfDay(14, 30, 33) - TimeOfDay(12, 30, 33) == dur!"seconds"(7200));
        assert(TimeOfDay(12, 30, 33) - TimeOfDay(12, 34, 33) == dur!"seconds"(-240));
        assert(TimeOfDay(12, 34, 33) - TimeOfDay(12, 30, 33) == dur!"seconds"(240));
        assert(TimeOfDay(12, 30, 33) - TimeOfDay(12, 30, 34) == dur!"seconds"(-1));
        assert(TimeOfDay(12, 30, 34) - TimeOfDay(12, 30, 33) == dur!"seconds"(1));

        const ctod = TimeOfDay(12, 30, 33);
        immutable itod = TimeOfDay(12, 30, 33);
        assert(tod - tod == Duration.zero);
        assert(ctod - tod == Duration.zero);
        assert(itod - tod == Duration.zero);

        assert(tod - ctod == Duration.zero);
        assert(ctod - ctod == Duration.zero);
        assert(itod - ctod == Duration.zero);

        assert(tod - itod == Duration.zero);
        assert(ctod - itod == Duration.zero);
        assert(itod - itod == Duration.zero);
    }


    /++
        Converts this $(LREF TimeOfDay) to a string with the format HHMMSS.
      +/
    string toISOString() @safe const pure nothrow
    {
        import std.format : format;
        try
            return format("%02d%02d%02d", _hour, _minute, _second);
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(TimeOfDay(0, 0, 0).toISOString() == "000000");
        assert(TimeOfDay(12, 30, 33).toISOString() == "123033");
    }

    @safe unittest
    {
        auto tod = TimeOfDay(12, 30, 33);
        const ctod = TimeOfDay(12, 30, 33);
        immutable itod = TimeOfDay(12, 30, 33);
        assert(tod.toISOString() == "123033");
        assert(ctod.toISOString() == "123033");
        assert(itod.toISOString() == "123033");
    }


    /++
        Converts this $(LREF TimeOfDay) to a string with the format HH:MM:SS.
      +/
    string toISOExtString() @safe const pure nothrow
    {
        import std.format : format;
        try
            return format("%02d:%02d:%02d", _hour, _minute, _second);
        catch (Exception e)
            assert(0, "format() threw.");
    }

    ///
    @safe unittest
    {
        assert(TimeOfDay(0, 0, 0).toISOExtString() == "00:00:00");
        assert(TimeOfDay(12, 30, 33).toISOExtString() == "12:30:33");
    }

    @safe unittest
    {
        auto tod = TimeOfDay(12, 30, 33);
        const ctod = TimeOfDay(12, 30, 33);
        immutable itod = TimeOfDay(12, 30, 33);
        assert(tod.toISOExtString() == "12:30:33");
        assert(ctod.toISOExtString() == "12:30:33");
        assert(itod.toISOExtString() == "12:30:33");
    }


    /++
        Converts this TimeOfDay to a string.
      +/
    string toString() @safe const pure nothrow
    {
        return toISOExtString();
    }

    @safe unittest
    {
        auto tod = TimeOfDay(12, 30, 33);
        const ctod = TimeOfDay(12, 30, 33);
        immutable itod = TimeOfDay(12, 30, 33);
        assert(tod.toString());
        assert(ctod.toString());
        assert(itod.toString());
    }


    /++
        Creates a $(LREF TimeOfDay) from a string with the format HHMMSS.
        Whitespace is stripped from the given string.

        Params:
            isoString = A string formatted in the ISO format for times.

        Throws:
            $(LREF DateTimeException) if the given string is not in the ISO format
            or if the resulting $(LREF TimeOfDay) would not be valid.
      +/
    static TimeOfDay fromISOString(S)(in S isoString) @safe pure
        if (isSomeString!S)
    {
        import std.algorithm.searching : all;
        import std.ascii : isDigit;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        auto dstr = to!dstring(strip(isoString));

        enforce(dstr.length == 6, new DateTimeException(format("Invalid ISO String: %s", isoString)));

        auto hours = dstr[0 .. 2];
        auto minutes = dstr[2 .. 4];
        auto seconds = dstr[4 .. $];

        enforce(all!isDigit(hours), new DateTimeException(format("Invalid ISO String: %s", isoString)));
        enforce(all!isDigit(minutes), new DateTimeException(format("Invalid ISO String: %s", isoString)));
        enforce(all!isDigit(seconds), new DateTimeException(format("Invalid ISO String: %s", isoString)));

        return TimeOfDay(to!int(hours), to!int(minutes), to!int(seconds));
    }

    ///
    @safe unittest
    {
        assert(TimeOfDay.fromISOString("000000") == TimeOfDay(0, 0, 0));
        assert(TimeOfDay.fromISOString("123033") == TimeOfDay(12, 30, 33));
        assert(TimeOfDay.fromISOString(" 123033 ") == TimeOfDay(12, 30, 33));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(TimeOfDay.fromISOString(""));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("00"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("000"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("0000"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("00000"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("13033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("1277"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12707"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12070"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12303a"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("1230a3"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("123a33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12a033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("1a0033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("a20033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("1200330"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("0120033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("-120033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("+120033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("120033am"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("120033pm"));

        assertThrown!DateTimeException(TimeOfDay.fromISOString("0::"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString(":0:"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("::0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("0:0:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("0:0:00"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("0:00:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("00:0:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("00:00:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("00:0:00"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("13:0:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:7:7"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:7:07"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:07:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:30:3a"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:30:a3"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:3a:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:a0:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("1a:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("a2:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:003:30"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("120:03:30"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("012:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("01:200:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("-12:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("+12:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:00:33am"));
        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:00:33pm"));

        assertThrown!DateTimeException(TimeOfDay.fromISOString("12:00:33"));

        assert(TimeOfDay.fromISOString("011217") == TimeOfDay(1, 12, 17));
        assert(TimeOfDay.fromISOString("001412") == TimeOfDay(0, 14, 12));
        assert(TimeOfDay.fromISOString("000007") == TimeOfDay(0, 0, 7));
        assert(TimeOfDay.fromISOString("011217 ") == TimeOfDay(1, 12, 17));
        assert(TimeOfDay.fromISOString(" 011217") == TimeOfDay(1, 12, 17));
        assert(TimeOfDay.fromISOString(" 011217 ") == TimeOfDay(1, 12, 17));
    }


    /++
        Creates a $(LREF TimeOfDay) from a string with the format HH:MM:SS.
        Whitespace is stripped from the given string.

        Params:
            isoExtString = A string formatted in the ISO Extended format for times.

        Throws:
            $(LREF DateTimeException) if the given string is not in the ISO
            Extended format or if the resulting $(LREF TimeOfDay) would not be
            valid.
      +/
    static TimeOfDay fromISOExtString(S)(in S isoExtString) @safe pure
        if (isSomeString!S)
    {
        import std.algorithm.searching : all;
        import std.ascii : isDigit;
        import std.conv : to;
        import std.exception : enforce;
        import std.format : format;
        import std.string : strip;

        auto dstr = to!dstring(strip(isoExtString));

        enforce(dstr.length == 8, new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));

        auto hours = dstr[0 .. 2];
        auto minutes = dstr[3 .. 5];
        auto seconds = dstr[6 .. $];

        enforce(dstr[2] == ':', new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        enforce(dstr[5] == ':', new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        enforce(all!isDigit(hours),
                new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        enforce(all!isDigit(minutes),
                new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));
        enforce(all!isDigit(seconds),
                new DateTimeException(format("Invalid ISO Extended String: %s", isoExtString)));

        return TimeOfDay(to!int(hours), to!int(minutes), to!int(seconds));
    }

    ///
    @safe unittest
    {
        assert(TimeOfDay.fromISOExtString("00:00:00") == TimeOfDay(0, 0, 0));
        assert(TimeOfDay.fromISOExtString("12:30:33") == TimeOfDay(12, 30, 33));
        assert(TimeOfDay.fromISOExtString(" 12:30:33 ") == TimeOfDay(12, 30, 33));
    }

    @safe unittest
    {
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString(""));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("00"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("000"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("0000"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("00000"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("13033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("1277"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12707"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12070"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12303a"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("1230a3"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("123a33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12a033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("1a0033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("a20033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("1200330"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("0120033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("-120033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("+120033"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("120033am"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("120033pm"));

        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("0::"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString(":0:"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("::0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("0:0:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("0:0:00"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("0:00:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("00:0:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("00:00:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("00:0:00"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("13:0:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:7:7"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:7:07"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:07:0"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:30:3a"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:30:a3"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:3a:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:a0:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("1a:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("a2:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:003:30"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("120:03:30"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("012:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("01:200:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("-12:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("+12:00:33"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:00:33am"));
        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("12:00:33pm"));

        assertThrown!DateTimeException(TimeOfDay.fromISOExtString("120033"));

        assert(TimeOfDay.fromISOExtString("01:12:17") == TimeOfDay(1, 12, 17));
        assert(TimeOfDay.fromISOExtString("00:14:12") == TimeOfDay(0, 14, 12));
        assert(TimeOfDay.fromISOExtString("00:00:07") == TimeOfDay(0, 0, 7));
        assert(TimeOfDay.fromISOExtString("01:12:17 ") == TimeOfDay(1, 12, 17));
        assert(TimeOfDay.fromISOExtString(" 01:12:17") == TimeOfDay(1, 12, 17));
        assert(TimeOfDay.fromISOExtString(" 01:12:17 ") == TimeOfDay(1, 12, 17));
    }


    /++
        Returns midnight.
      +/
    @property static TimeOfDay min() @safe pure nothrow
    {
        return TimeOfDay.init;
    }

    @safe unittest
    {
        assert(TimeOfDay.min.hour == 0);
        assert(TimeOfDay.min.minute == 0);
        assert(TimeOfDay.min.second == 0);
        assert(TimeOfDay.min < TimeOfDay.max);
    }


    /++
        Returns one second short of midnight.
      +/
    @property static TimeOfDay max() @safe pure nothrow
    {
        auto tod = TimeOfDay.init;
        tod._hour = maxHour;
        tod._minute = maxMinute;
        tod._second = maxSecond;

        return tod;
    }

    @safe unittest
    {
        assert(TimeOfDay.max.hour == 23);
        assert(TimeOfDay.max.minute == 59);
        assert(TimeOfDay.max.second == 59);
        assert(TimeOfDay.max > TimeOfDay.min);
    }


private:

    /+
        Add seconds to the time of day. Negative values will subtract. If the
        number of seconds overflows (or underflows), then the seconds will wrap,
        increasing (or decreasing) the number of minutes accordingly. If the
        number of minutes overflows (or underflows), then the minutes will wrap.
        If the number of minutes overflows(or underflows), then the hour will
        wrap. (e.g. adding 90 seconds to 23:59:00 would result in 00:00:30).

        Params:
            seconds = The number of seconds to add to this TimeOfDay.
      +/
    ref TimeOfDay _addSeconds(long seconds) return @safe pure nothrow
    {
        long hnsecs = convert!("seconds", "hnsecs")(seconds);
        hnsecs += convert!("hours", "hnsecs")(_hour);
        hnsecs += convert!("minutes", "hnsecs")(_minute);
        hnsecs += convert!("seconds", "hnsecs")(_second);

        hnsecs %= convert!("days", "hnsecs")(1);

        if (hnsecs < 0)
            hnsecs += convert!("days", "hnsecs")(1);

        immutable newHours = splitUnitsFromHNSecs!"hours"(hnsecs);
        immutable newMinutes = splitUnitsFromHNSecs!"minutes"(hnsecs);
        immutable newSeconds = splitUnitsFromHNSecs!"seconds"(hnsecs);

        _hour = cast(ubyte) newHours;
        _minute = cast(ubyte) newMinutes;
        _second = cast(ubyte) newSeconds;

        return this;
    }

    @safe unittest
    {
        static void testTOD(TimeOfDay orig, int seconds, in TimeOfDay expected, size_t line = __LINE__)
        {
            orig._addSeconds(seconds);
            assert(orig == expected);
        }

        testTOD(TimeOfDay(12, 30, 33), 0, TimeOfDay(12, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 1, TimeOfDay(12, 30, 34));
        testTOD(TimeOfDay(12, 30, 33), 2, TimeOfDay(12, 30, 35));
        testTOD(TimeOfDay(12, 30, 33), 3, TimeOfDay(12, 30, 36));
        testTOD(TimeOfDay(12, 30, 33), 4, TimeOfDay(12, 30, 37));
        testTOD(TimeOfDay(12, 30, 33), 5, TimeOfDay(12, 30, 38));
        testTOD(TimeOfDay(12, 30, 33), 10, TimeOfDay(12, 30, 43));
        testTOD(TimeOfDay(12, 30, 33), 15, TimeOfDay(12, 30, 48));
        testTOD(TimeOfDay(12, 30, 33), 26, TimeOfDay(12, 30, 59));
        testTOD(TimeOfDay(12, 30, 33), 27, TimeOfDay(12, 31, 0));
        testTOD(TimeOfDay(12, 30, 33), 30, TimeOfDay(12, 31, 3));
        testTOD(TimeOfDay(12, 30, 33), 59, TimeOfDay(12, 31, 32));
        testTOD(TimeOfDay(12, 30, 33), 60, TimeOfDay(12, 31, 33));
        testTOD(TimeOfDay(12, 30, 33), 61, TimeOfDay(12, 31, 34));

        testTOD(TimeOfDay(12, 30, 33), 1766, TimeOfDay(12, 59, 59));
        testTOD(TimeOfDay(12, 30, 33), 1767, TimeOfDay(13, 0, 0));
        testTOD(TimeOfDay(12, 30, 33), 1768, TimeOfDay(13, 0, 1));
        testTOD(TimeOfDay(12, 30, 33), 2007, TimeOfDay(13, 4, 0));
        testTOD(TimeOfDay(12, 30, 33), 3599, TimeOfDay(13, 30, 32));
        testTOD(TimeOfDay(12, 30, 33), 3600, TimeOfDay(13, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), 3601, TimeOfDay(13, 30, 34));
        testTOD(TimeOfDay(12, 30, 33), 7200, TimeOfDay(14, 30, 33));

        testTOD(TimeOfDay(12, 30, 33), -1, TimeOfDay(12, 30, 32));
        testTOD(TimeOfDay(12, 30, 33), -2, TimeOfDay(12, 30, 31));
        testTOD(TimeOfDay(12, 30, 33), -3, TimeOfDay(12, 30, 30));
        testTOD(TimeOfDay(12, 30, 33), -4, TimeOfDay(12, 30, 29));
        testTOD(TimeOfDay(12, 30, 33), -5, TimeOfDay(12, 30, 28));
        testTOD(TimeOfDay(12, 30, 33), -10, TimeOfDay(12, 30, 23));
        testTOD(TimeOfDay(12, 30, 33), -15, TimeOfDay(12, 30, 18));
        testTOD(TimeOfDay(12, 30, 33), -33, TimeOfDay(12, 30, 0));
        testTOD(TimeOfDay(12, 30, 33), -34, TimeOfDay(12, 29, 59));
        testTOD(TimeOfDay(12, 30, 33), -35, TimeOfDay(12, 29, 58));
        testTOD(TimeOfDay(12, 30, 33), -59, TimeOfDay(12, 29, 34));
        testTOD(TimeOfDay(12, 30, 33), -60, TimeOfDay(12, 29, 33));
        testTOD(TimeOfDay(12, 30, 33), -61, TimeOfDay(12, 29, 32));

        testTOD(TimeOfDay(12, 30, 33), -1833, TimeOfDay(12, 0, 0));
        testTOD(TimeOfDay(12, 30, 33), -1834, TimeOfDay(11, 59, 59));
        testTOD(TimeOfDay(12, 30, 33), -3600, TimeOfDay(11, 30, 33));
        testTOD(TimeOfDay(12, 30, 33), -3601, TimeOfDay(11, 30, 32));
        testTOD(TimeOfDay(12, 30, 33), -5134, TimeOfDay(11, 4, 59));
        testTOD(TimeOfDay(12, 30, 33), -7200, TimeOfDay(10, 30, 33));

        testTOD(TimeOfDay(12, 30, 0), 1, TimeOfDay(12, 30, 1));
        testTOD(TimeOfDay(12, 30, 0), 0, TimeOfDay(12, 30, 0));
        testTOD(TimeOfDay(12, 30, 0), -1, TimeOfDay(12, 29, 59));

        testTOD(TimeOfDay(12, 0, 0), 1, TimeOfDay(12, 0, 1));
        testTOD(TimeOfDay(12, 0, 0), 0, TimeOfDay(12, 0, 0));
        testTOD(TimeOfDay(12, 0, 0), -1, TimeOfDay(11, 59, 59));

        testTOD(TimeOfDay(0, 0, 0), 1, TimeOfDay(0, 0, 1));
        testTOD(TimeOfDay(0, 0, 0), 0, TimeOfDay(0, 0, 0));
        testTOD(TimeOfDay(0, 0, 0), -1, TimeOfDay(23, 59, 59));

        testTOD(TimeOfDay(23, 59, 59), 1, TimeOfDay(0, 0, 0));
        testTOD(TimeOfDay(23, 59, 59), 0, TimeOfDay(23, 59, 59));
        testTOD(TimeOfDay(23, 59, 59), -1, TimeOfDay(23, 59, 58));

        const ctod = TimeOfDay(0, 0, 0);
        immutable itod = TimeOfDay(0, 0, 0);
        static assert(!__traits(compiles, ctod._addSeconds(7)));
        static assert(!__traits(compiles, itod._addSeconds(7)));
    }


    /+
        Whether the given values form a valid $(LREF TimeOfDay).
     +/
    static bool _valid(int hour, int minute, int second) @safe pure nothrow
    {
        return valid!"hours"(hour) && valid!"minutes"(minute) && valid!"seconds"(second);
    }


    @safe pure invariant()
    {
        import std.format : format;
        assert(_valid(_hour, _minute, _second),
               format("Invariant Failure: hour [%s] minute [%s] second [%s]", _hour, _minute, _second));
    }


package:

    ubyte _hour;
    ubyte _minute;
    ubyte _second;

    enum ubyte maxHour   = 24 - 1;
    enum ubyte maxMinute = 60 - 1;
    enum ubyte maxSecond = 60 - 1;
}


package:

/+
    Splits out a particular unit from hnsecs and gives the value for that
    unit and the remaining hnsecs. It really shouldn't be used unless unless
    all units larger than the given units have already been split out.

    Params:
        units  = The units to split out.
        hnsecs = The current total hnsecs. Upon returning, it is the hnsecs left
                 after splitting out the given units.

    Returns:
        The number of the given units from converting hnsecs to those units.
  +/
long splitUnitsFromHNSecs(string units)(ref long hnsecs) @safe pure nothrow
if (validTimeUnits(units) && CmpTimeUnits!(units, "months") < 0)
{
    import core.time : convert;
    immutable value = convert!("hnsecs", units)(hnsecs);
    hnsecs -= convert!(units, "hnsecs")(value);
    return value;
}

@safe unittest
{
    auto hnsecs = 2595000000007L;
    immutable days = splitUnitsFromHNSecs!"days"(hnsecs);
    assert(days == 3);
    assert(hnsecs == 3000000007);

    immutable minutes = splitUnitsFromHNSecs!"minutes"(hnsecs);
    assert(minutes == 5);
    assert(hnsecs == 7);
}
