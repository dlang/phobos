// Written in the D programming language

/* /////////////////////////////////////////////////////////////////////////////
 * File:        perf.d
 *
 * Created      19th March 2004
 * Updated:     18th July 2004
 *
 * www:         http://www.digitalmars.com/
 *
 * Copyright (C) 2004 by Digital Mars
 * All Rights Reserved
 * Written by Matthew Wilson
 * http://www.digitalmars.com
 * License for redistribution is by either the Artistic License in artistic.txt,
 * or the LGPL
 *
 * ////////////////////////////////////////////////////////////////////////// */


/**
 * Platform-independent performance measurement and timing classes.
 *
 * $(D_PARAM PerformanceCounter) is the main platform-independent timer class provided,
 * covering the most typical use case, measuring elapsed wall-clock time.
 *
 * The module also provides several Windows-specific timers that can
 * be useful in specialized situations.
 *
 * Synopsis:
 ----
alias PerformanceCounter.interval_t interval_t;
auto timer = new PerformanceCounter;
timer.start();
// do computation
timer.stop();
interval_t elapsedMsec = timer.milliseconds;
writefln("Time elapsed: %s msec", elapsedMsec);
----
 * In particular note that $(D_PARAM stop()) must be called
 * before querying the elapsed time.
 *
 * These classes were ported to D from the
 * $(LINK2 http://stlsoft.org/,STLSoft C++ libraries),
 * which were documented in the article
 * "$(LINK2 http://www.windevnet.com/documents/win0305a/,
 * Win32 Performance Measurement Options)",
 * May 2003 issue of Windows Develper Network.
 *
 * Author:
 * Matthew Wilson
 *
 * Source:    $(PHOBOSSRC std/_perf.d)
 *
 * Macros:
 *      WIKI=Phobos/StdPerf
 */

module std.perf;

pragma(msg, "std.perf has been scheduled for deprecation. "
            "Please use std.datetime instead.");

version(Windows)
{

    private import std.c.windows.windows;

    /* ////////////////////////////////////////////////////////////////////////// */

    // This library provides performance measurement facilities

    /* ////////////////////////////////////////////////////////////////////////// */

    /** A performance counter that uses the most accurate measurement APIs available on the host machine

        On Linux, the implementation uses $(D_PARAM gettimeofday()).
        For Windows, $(D_PARAM QueryPerformanceCounter()) is used if available,
        $(D_PARAM GetTickCount()) otherwise.
    */
    class PerformanceCounter
    {
    private:
        alias   long    epoch_type;
    public:
        /// The type of the interval measurement (generally a 64-bit signed integer)
        alias   long    interval_t;

        deprecated alias interval_t interval_type;

    private:
        /** Class constructor
        */
        shared static this()
        {
            // Detects availability of the high performance hardware counter, and if
            // not available adjusts

            interval_t freq;
            if (QueryPerformanceFrequency(&freq))
            {
                sm_freq =   freq;
                sm_fn    =   &_qpc;
            }
            else
            {
                sm_freq =   1000;
                sm_fn    =   &_qtc;
            }
        }

    public:
        /** Starts measurement

            Begins a measurement period
        */
        void start()
        {
            sm_fn(m_start);
        }

        /** Ends measurement

            Marks the end of a measurement period.
            This must be called before querying the elapsed time with
            $(D_PARAM period_count), $(D_PARAM seconds),
            $(D_PARAM milliseconds), or $(D_PARAM microseconds).

            The $(D_PARAM stop()) method may be called multiple times without an intervening $(D_PARAM start()).
            Elapsed time is always measured from most recent $(D_PARAM start()) to the most recent
            $(D_PARAM stop()).
        */
        void stop()
        {
            sm_fn(m_end);
        }

    public:
        /** The elapsed count in the measurement period

            This represents the extent, in machine-specific increments, of the measurement period
        */
        interval_t periodCount() const
        {
            return m_end - m_start;
        }

        /** The number of whole seconds in the measurement period

            This represents the extent, in whole seconds, of the measurement period
        */
        interval_t seconds() const
        {
            return periodCount() / sm_freq;
        }

        /** The number of whole milliseconds in the measurement period

            This represents the extent, in whole milliseconds, of the measurement period
        */
        interval_t milliseconds() const
        {
            interval_t   result;
            interval_t   count   =      periodCount();

            if(count < 0x20C49BA5E353F7L)
            {
                result = (count * 1000) / sm_freq;
            }
            else
            {
                result = (count / sm_freq) * 1000;
            }

            return result;
        }

        /** The number of whole microseconds in the measurement period

            This represents the extent, in whole microseconds, of the measurement period
        */
        interval_t microseconds() const
        {
            interval_t   result;
            interval_t   count   =      periodCount();

            if(count < 0x8637BD05AF6L)
            {
                result = (count * 1000000) / sm_freq;
            }
            else
            {
                result = (count / sm_freq) * 1000000;
            }

            return result;
        }

    private:
        alias void function(out epoch_type interval)    measure_func;

        static void _qpc(out epoch_type interval)
        {
            QueryPerformanceCounter(&interval);
        }

        static void _qtc(out epoch_type interval)
        {
            interval = GetTickCount();
        }

    private:
        epoch_type              m_start;    // start of measurement period
        epoch_type              m_end;      // End of measurement period
        __gshared const interval_t          sm_freq;    // Frequency
        __gshared const measure_func    sm_fn;      // Measurement function
    }

    unittest
    {
        alias PerformanceCounter    counter_type;

        counter_type    counter = new counter_type();

        counter.start();
        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us1 =   counter.microseconds();
        counter_type.interval_t  ms1 =   counter.milliseconds();
        counter_type.interval_t  s1     =   counter.seconds();

        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us2 =   counter.microseconds();
        counter_type.interval_t  ms2 =   counter.milliseconds();
        counter_type.interval_t  s2     =   counter.seconds();

        assert(us2 >= us1);
        assert(ms2 >= ms1);
        assert(s2 >= s1);
    }

    /* ////////////////////////////////////////////////////////////////////////// */

    /** A low-cost, low-resolution performance counter

        This class provides low-resolution, but low-latency, performance monitoring.

        This class is available only on Windows, but
        is guaranteed to be meaningful on all Windows operating systems.
    */
    class TickCounter
    {
    private:
        alias   long    epoch_type;
    public:
        /** The interval type

            The type of the interval measurement (generally a 64-bit signed integer)
        */
        alias   long    interval_t;

        deprecated alias interval_t interval_type;

    public:

    public:
        /** Starts measurement

            Begins a measurement period
        */
        void start()
        {
            m_start = GetTickCount();
        }

        /** Ends measurement

            Marks the end of a measurement period.
            This must be called before querying the elapsed time with
            $(D_PARAM period_count), $(D_PARAM seconds),
            $(D_PARAM milliseconds), or $(D_PARAM microseconds).

            The $(D_PARAM stop()) method may be called multiple times without an intervening $(D_PARAM start()).
            Elapsed time is always measured from most recent $(D_PARAM start()) to the most recent
            $(D_PARAM stop()).
        */
        void stop()
        {
            m_end = GetTickCount();
        }

    public:
        /**
           The elapsed count in the measurement period

           This represents the extent, in machine-specific increments, of the measurement period
        */
        interval_t periodCount() const
        {
            return m_end - m_start;
        }

        /** The number of whole seconds in the measurement period

            This represents the extent, in whole seconds, of the measurement period
        */
        interval_t seconds() const
        {
            return periodCount() / 1000;
        }

        /** The number of whole milliseconds in the measurement period

            This represents the extent, in whole milliseconds, of the measurement period
        */
        interval_t milliseconds() const
        {
            return periodCount();
        }

        /** The number of whole microseconds in the measurement period

            This represents the extent, in whole microseconds, of the measurement period
        */
        interval_t microseconds() const
        {
            return periodCount() * 1000;
        }

    private:
        uint    m_start;    // start of measurement period
        uint    m_end;      // End of measurement period
    }

    unittest
    {
        alias TickCounter   counter_type;

        counter_type    counter = new counter_type();

        counter.start();
        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us1 =   counter.microseconds();
        counter_type.interval_t  ms1 =   counter.milliseconds();
        counter_type.interval_t  s1     =   counter.seconds();

        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us2 =   counter.microseconds();
        counter_type.interval_t  ms2 =   counter.milliseconds();
        counter_type.interval_t  s2     =   counter.seconds();

        assert(us2 >= us1);
        assert(ms2 >= ms1);
        assert(s2 >= s1);
    }

    /* ////////////////////////////////////////////////////////////////////////// */

    /** A performance counter that provides thread-specific performance timings

        This class uses the operating system's performance monitoring facilities to provide timing
        information pertaining to the calling thread only, irrespective of the activities of other
        threads on the system. This class does not provide meaningful timing information on operating
        systems that do not provide thread-specific monitoring.

        This class is available only on Windows.
    */
    class ThreadTimesCounter
    {
    private:
        alias   long    epoch_type;
    public:
        /** The interval type

            The type of the interval measurement (generally a 64-bit signed integer)
        */
        alias   long    interval_t;

        deprecated alias interval_t interval_type;

    public:
        /** Constructor

            Creates an instance of the class, and caches the thread token so that measurements will
            be taken with respect to the thread in which the class was created.
        */
        this()
        {
            m_thread = GetCurrentThread();
        }

    public:
        /** Starts measurement

            Begins a measurement period
        */
        void start()
        {
            FILETIME    creationTime;
            FILETIME    exitTime;

            GetThreadTimes(m_thread, &creationTime, &exitTime, cast(FILETIME*)&m_kernelStart, cast(FILETIME*)&m_userStart);
        }

        /** Ends measurement

            Marks the end of a measurement period.
            This must be called before querying the elapsed time with
            $(D_PARAM period_count), $(D_PARAM seconds),
            $(D_PARAM milliseconds), or $(D_PARAM microseconds).

            The $(D_PARAM stop()) method may be called multiple times without an intervening $(D_PARAM start()).
            Elapsed time is always measured from most recent $(D_PARAM start()) to the most recent
            $(D_PARAM stop()).
        */
        void stop()
        {
            FILETIME    creationTime;
            FILETIME    exitTime;

            GetThreadTimes(m_thread, &creationTime, &exitTime, cast(FILETIME*)&m_kernelEnd, cast(FILETIME*)&m_userEnd);
        }


    public:

        /** The elapsed count in the measurement period for kernel mode activity

            This represents the extent, in machine-specific increments, of the measurement period for kernel mode activity
        */
        interval_t kernelPeriodCount() const
        {
            return m_kernelEnd - m_kernelStart;
        }
        /** The number of whole seconds in the measurement period for kernel mode activity

            This represents the extent, in whole seconds, of the measurement period for kernel mode activity
        */
        interval_t kernelSeconds() const
        {
            return kernelPeriodCount() / 10000000;
        }
        /** The number of whole milliseconds in the measurement period for kernel mode activity

            This represents the extent, in whole milliseconds, of the measurement period for kernel mode activity
        */
        interval_t kernelMilliseconds() const
        {
            return kernelPeriodCount() / 10000;
        }
        /** The number of whole microseconds in the measurement period for kernel mode activity

            This represents the extent, in whole microseconds, of the measurement period for kernel mode activity
        */
        interval_t kernelMicroseconds() const
        {
            return kernelPeriodCount() / 10;
        }


        /** The elapsed count in the measurement period for user mode activity

            This represents the extent, in machine-specific increments, of the measurement period for user mode activity
        */
        interval_t userPeriodCount() const
        {
            return m_userEnd - m_userStart;
        }
        /** The number of whole seconds in the measurement period for user mode activity

            This represents the extent, in whole seconds, of the measurement period for user mode activity
        */
        interval_t userSeconds() const
        {
            return userPeriodCount() / 10000000;
        }
        /** The number of whole milliseconds in the measurement period for user mode activity

            This represents the extent, in whole milliseconds, of the measurement period for user mode activity
        */
        interval_t userMilliseconds() const
        {
            return userPeriodCount() / 10000;
        }
        /** The number of whole microseconds in the measurement period for user mode activity

            This represents the extent, in whole microseconds, of the measurement period for user mode activity
        */
        interval_t userMicroseconds() const
        {
            return userPeriodCount() / 10;
        }


        /** The elapsed count in the measurement period

            This represents the extent, in machine-specific increments, of the measurement period
        */
        interval_t periodCount() const
        {
            return kernelPeriodCount() + userPeriodCount();
        }

        /** The number of whole seconds in the measurement period

            This represents the extent, in whole seconds, of the measurement period
        */
        interval_t seconds() const
        {
            return periodCount() / 10000000;
        }

        /** The number of whole milliseconds in the measurement period

            This represents the extent, in whole milliseconds, of the measurement period
        */
        interval_t milliseconds() const
        {
            return periodCount() / 10000;
        }

        /** The number of whole microseconds in the measurement period

            This represents the extent, in whole microseconds, of the measurement period
        */
        interval_t microseconds() const
        {
            return periodCount() / 10;
        }


    private:
        epoch_type  m_kernelStart;
        epoch_type  m_kernelEnd;
        epoch_type  m_userStart;
        epoch_type  m_userEnd;
        HANDLE      m_thread;
    }

    unittest
    {
        alias ThreadTimesCounter    counter_type;

        counter_type    counter = new counter_type();

        counter.start();
        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us1 =   counter.microseconds();
        counter_type.interval_t  ms1 =   counter.milliseconds();
        counter_type.interval_t  s1     =   counter.seconds();

        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us2 =   counter.microseconds();
        counter_type.interval_t  ms2 =   counter.milliseconds();
        counter_type.interval_t  s2     =   counter.seconds();

        assert(us2 >= us1);
        assert(ms2 >= ms1);
        assert(s2 >= s1);
    }

    /* ////////////////////////////////////////////////////////////////////////// */

    /** A performance counter that provides process-specific performance timings

        This class uses the operating system's performance monitoring facilities to provide timing
        information pertaining to the calling process only, irrespective of the activities of other
        processes on the system. This class does not provide meaningful timing information on operating
        systems that do not provide process-specific monitoring.

        This class is available only on Windows.
    */
    class ProcessTimesCounter
    {
    private:
        alias   long    epoch_type;
    public:
        /** The interval type

            The type of the interval measurement (generally a 64-bit signed integer)
        */
        alias   long    interval_t;

        deprecated alias interval_t interval_type;

    private:
        /** Class constructor

        */
        shared static this()
        {
            sm_process = GetCurrentProcess();
        }

    public:
        /** Starts measurement

            Begins a measurement period
        */
        void start()
        {
            FILETIME    creationTime;
            FILETIME    exitTime;

            GetProcessTimes(sm_process, &creationTime, &exitTime, cast(FILETIME*)&m_kernelStart, cast(FILETIME*)&m_userStart);
        }

        /** Ends measurement

            Marks the end of a measurement period.
            This must be called before querying the elapsed time with
            $(D_PARAM period_count), $(D_PARAM seconds),
            $(D_PARAM milliseconds), or $(D_PARAM microseconds).

            The $(D_PARAM stop()) method may be called multiple times without an intervening $(D_PARAM start()).
            Elapsed time is always measured from most recent $(D_PARAM start()) to the most recent
            $(D_PARAM stop()).
        */
        void stop()
        {
            FILETIME    creationTime;
            FILETIME    exitTime;

            GetProcessTimes(sm_process, &creationTime, &exitTime, cast(FILETIME*)&m_kernelEnd, cast(FILETIME*)&m_userEnd);
        }

    public:
        /** The elapsed count in the measurement period for kernel mode activity

            This represents the extent, in machine-specific increments, of the measurement period for kernel mode activity
        */
        interval_t kernelPeriodCount() const
        {
            return m_kernelEnd - m_kernelStart;
        }
        /** The number of whole seconds in the measurement period for kernel mode activity

            This represents the extent, in whole seconds, of the measurement period for kernel mode activity
        */
        interval_t kernelSeconds() const
        {
            return kernelPeriodCount() / 10000000;
        }
        /** The number of whole milliseconds in the measurement period for kernel mode activity

            This represents the extent, in whole milliseconds, of the measurement period for kernel mode activity
        */
        interval_t kernelMilliseconds() const
        {
            return kernelPeriodCount() / 10000;
        }
        /** The number of whole microseconds in the measurement period for kernel mode activity

            This represents the extent, in whole microseconds, of the measurement period for kernel mode activity
        */
        interval_t kernelMicroseconds() const
        {
            return kernelPeriodCount() / 10;
        }


        /** The elapsed count in the measurement period for user mode activity

            This represents the extent, in machine-specific increments, of the measurement period for user mode activity
        */
        interval_t userPeriodCount() const
        {
            return m_userEnd - m_userStart;
        }
        /** The number of whole seconds in the measurement period for user mode activity

            This represents the extent, in whole seconds, of the measurement period for user mode activity
        */
        interval_t userSeconds() const
        {
            return userPeriodCount() / 10000000;
        }
        /** The number of whole milliseconds in the measurement period for user mode activity

            This represents the extent, in whole milliseconds, of the measurement period for user mode activity
        */
        interval_t userMilliseconds() const
        {
            return userPeriodCount() / 10000;
        }
        /** The number of whole microseconds in the measurement period for user mode activity

            This represents the extent, in whole microseconds, of the measurement period for user mode activity
        */
        interval_t userMicroseconds() const
        {
            return userPeriodCount() / 10;
        }

        /** The elapsed count in the measurement period

            This represents the extent, in machine-specific increments, of the measurement period
        */
        interval_t periodCount() const
        {
            return kernelPeriodCount() + userPeriodCount();
        }

        /** The number of whole seconds in the measurement period

            This represents the extent, in whole seconds, of the measurement period
        */
        interval_t seconds() const
        {
            return periodCount() / 10000000;
        }

        /** The number of whole milliseconds in the measurement period

            This represents the extent, in whole milliseconds, of the measurement period
        */
        interval_t milliseconds() const
        {
            return periodCount() / 10000;
        }

        /** The number of whole microseconds in the measurement period

            This represents the extent, in whole microseconds, of the measurement period
        */
        interval_t microseconds() const
        {
            return periodCount() / 10;
        }

    private:
        epoch_type      m_kernelStart;
        epoch_type      m_kernelEnd;
        epoch_type      m_userStart;
        epoch_type      m_userEnd;
        __gshared HANDLE        sm_process;
    }

    unittest
    {
        alias ProcessTimesCounter   counter_type;

        counter_type    counter = new counter_type();

        counter.start();
        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us1 =   counter.microseconds();
        counter_type.interval_t  ms1 =   counter.milliseconds();
        counter_type.interval_t  s1     =   counter.seconds();

        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us2 =   counter.microseconds();
        counter_type.interval_t  ms2 =   counter.milliseconds();
        counter_type.interval_t  s2     =   counter.seconds();

        assert(us2 >= us1);
        assert(ms2 >= ms1);
        assert(s2 >= s1);
    }

    /* ////////////////////////////////////////////////////////////////////////// */
}
else version(Posix)
{
    extern (C)
    {
        private struct timeval
        {
            int tv_sec;    // The number of seconds, since Jan. 1, 1970, in the time value.
            int tv_usec;   // The number of microseconds in the time value.
        };
        private struct timezone
        {
            int tz_minuteswest; // minutes west of Greenwich.
            int tz_dsttime;     // type of dst corrections to apply.
        };
        private void gettimeofday(timeval *tv, timezone *tz);
    }

    /* ////////////////////////////////////////////////////////////////////////// */

    class PerformanceCounter
    {
        // documentation is in the Windows version of the class above


    private:
        alias   timeval epoch_type;
    public:
        alias   long    interval_t;

    public:
        void start()
        {
            timezone tz;

            gettimeofday(&m_start, &tz);
        }

        void stop()
        {
            timezone tz;

            gettimeofday(&m_end, &tz);
        }

    public:
        interval_t periodCount() const
        {
            return microseconds;
        }

        interval_t seconds() const
        {
            interval_t   start   =      cast(interval_t)m_start.tv_sec + cast(interval_t)m_start.tv_usec / (1000 * 1000);
            interval_t   end        =   cast(interval_t)m_end.tv_sec      + cast(interval_t)m_end.tv_usec   / (1000 * 1000);

            return end - start;
        }

        interval_t milliseconds() const
        {
            interval_t   start   =      cast(interval_t)m_start.tv_sec * 1000 + cast(interval_t)m_start.tv_usec / 1000;
            interval_t   end        =   cast(interval_t)m_end.tv_sec      * 1000 + cast(interval_t)m_end.tv_usec   / 1000;

            return end - start;
        }

        interval_t microseconds() const
        {
            interval_t   start   =      cast(interval_t)m_start.tv_sec * 1000 * 1000 + cast(interval_t)m_start.tv_usec;
            interval_t   end        =   cast(interval_t)m_end.tv_sec      * 1000 * 1000 + cast(interval_t)m_end.tv_usec;

            return end - start;
        }

    private:
        epoch_type  m_start;  // start of measurement period
        epoch_type  m_end;    // End of measurement period
    }

    unittest
    {
        alias PerformanceCounter    counter_type;

        counter_type    counter = new counter_type();

        counter.start();
        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us1 =   counter.microseconds();
        counter_type.interval_t  ms1 =   counter.milliseconds();
        counter_type.interval_t  s1     =   counter.seconds();

        for(int i = 0; i < 10000000; ++i)
        {   }
        counter.stop();

        counter_type.interval_t  us2 =   counter.microseconds();
        counter_type.interval_t  ms2 =   counter.milliseconds();
        counter_type.interval_t  s2     =   counter.seconds();

        assert(us2 >= us1);
        assert(ms2 >= ms1);
        assert(s2 >= s1);
    }

    /* ////////////////////////////////////////////////////////////////////////// */
}
else
{
    const int platform_not_supported = 0;

    static assert(platform_not_supported);
}
