//Written in the D programming language

/**
    Copyright: Copyright 2011-
    License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(WEB erdani.com,Andrei Alexandrescu) and Kato Shoichi
    Source:    $(PHOBOSSRC std/_benchmark.d)
 */
module std.benchmark;
import std.conv, std.datetime, std.functional, std.traits;
import core.exception;

//==============================================================================
// Section with StopWatch and Benchmark Code.
//==============================================================================

/++
   Used by StopWatch to indicate whether it should start immediately upon
   construction.
  +/
enum AutoStart
{
    /// No, don't start the StopWatch when it is constructed.
    no,

    /// Yes, do start the StopWatch when it is constructed.
    yes
}

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

   Examples:
--------------------
void foo()
{
    StopWatch sw;
    enum n = 100;
    TickDuration[n] times;
    TickDuration last = TickDuration.from!"seconds"(0);
    foreach(i; 0..n)
    {
       sw.start(); //start/resume mesuring.
       foreach(unused; 0..1_000_000)
           bar();
       sw.stop();  //stop/pause measuring.
       //Return value of peek() after having stopped are the always same.
       writeln((i + 1) * 1_000_000, " times done, lap time: ",
               sw.peek().msecs, "[ms]");
       times[i] = sw.peek() - last;
       last = sw.peek();
    }
    real sum = 0;
    // When you want to know the number of seconds,
    // you can use properties of TickDuration.
    // (seconds, mseconds, useconds, hnsecs)
    foreach(t; times)
       sum += t.hnsecs;
    writeln("Average time: ", sum/n, " hnsecs");
}
--------------------
  +/
@safe struct StopWatch
{
public:
    //Verify Example
    @safe unittest
    {
        void writeln(S...)(S args){}
        static void bar() {}

        StopWatch sw;
        enum n = 100;
        TickDuration[n] times;
        TickDuration last = TickDuration.from!"seconds"(0);
        foreach(i; 0..n)
        {
           sw.start(); //start/resume mesuring.
           foreach(unused; 0..1_000_000)
               bar();
           sw.stop();  //stop/pause measuring.
           //Return value of peek() after having stopped are the always same.
           writeln((i + 1) * 1_000_000, " times done, lap time: ",
                   sw.peek().msecs, "[ms]");
           times[i] = sw.peek() - last;
           last = sw.peek();
        }
        real sum = 0;
        // When you want to know the number of seconds,
        // you can use properties of TickDuration.
        // (seconds, mseconds, useconds, hnsecs)
        foreach(t; times)
           sum += t.hnsecs;
        writeln("Average time: ", sum/n, " hnsecs");
    }

    /++
       Auto start with constructor.
      +/
    this(AutoStart autostart)
    {
        if(autostart)
            start();
    }

    @safe unittest
    {
        auto sw = StopWatch(AutoStart.yes);
        sw.stop();
    }


    ///
    bool opEquals(const ref StopWatch rhs) const pure nothrow
    {
        return _timeStart == rhs._timeStart &&
               _timeMeasured == rhs._timeMeasured;
    }


    /++
       Resets the stop watch.
      +/
    void reset()
    {
        if(_flagStarted)
        {
            // Set current system time if StopWatch is measuring.
            _timeStart = Clock.currSystemTick;
        }
        else
        {
            // Set zero if StopWatch is not measuring.
            _timeStart.length = 0;
        }

        _timeMeasured.length = 0;
    }

    @safe unittest
    {
        StopWatch sw;
        sw.start();
        sw.stop();
        sw.reset();
        assert(sw.peek().to!("seconds", real) == 0);
    }


    /++
       Starts the stop watch.
      +/
    void start()
    {
        assert(!_flagStarted);
        StopWatch sw;
        _flagStarted = true;
        _timeStart = Clock.currSystemTick;
    }

    @safe unittest
    {
        StopWatch sw;
        sw.start();
        auto t1 = sw.peek();
        bool doublestart = true;
        try
            sw.start();
        catch(AssertError e)
            doublestart = false;
        assert(!doublestart);
        sw.stop();
        assert((t1 - sw.peek()).to!("seconds", real) <= 0);
    }


    /++
       Stops the stop watch.
      +/
    void stop()
    {
        assert(_flagStarted);
        _flagStarted = false;
        _timeMeasured += Clock.currSystemTick - _timeStart;
    }

    @safe unittest
    {
        StopWatch sw;
        sw.start();
        sw.stop();
        auto t1 = sw.peek();
        bool doublestop = true;
        try
            sw.stop();
        catch(AssertError e)
            doublestop = false;
        assert(!doublestop);
        assert((t1 - sw.peek()).to!("seconds", real) == 0);
    }


    /++
       Peek at the amount of time which has passed since the stop watch was
       started.
      +/
    TickDuration peek() const
    {
        if(_flagStarted)
            return Clock.currSystemTick - _timeStart + _timeMeasured;

        return _timeMeasured;
    }

    @safe unittest
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

private:

    // true if observing.
    bool _flagStarted = false;

    // TickDuration at the time of StopWatch starting measurement.
    TickDuration _timeStart;

    // Total time that StopWatch ran.
    TickDuration _timeMeasured;
}


// workaround for bug4886
@safe size_t lengthof(aliases...)() pure nothrow
{
    return aliases.length;
}


/++
    Benchmarks code for speed assessment and comparison.

    Params:
        fun = aliases of callable objects (e.g. function names). Each should
              take no arguments.
        n   = The number of times each function is to be executed.

    Returns:
        The amount of time (as a $(CXREF time, TickDuration)) that it took to
        call each function $(D n) times. The first value is the length of time
        that it took to call $(D fun[0]) $(D n) times. The second value is the
        length of time it took to call $(D fun[1]) $(D n) times. Etc.

   Examples:
--------------------
int a;
void f0() {}
void f1() {auto b = a;}
void f2() {auto b = to!(string)(a);}
auto r = benchmark!(f0, f1, f2)(10_000_000);
writefln("Milliseconds to call fun[0] n times: %s", r[0].to!("msecs", int));
--------------------
  +/
@safe TickDuration[lengthof!(fun)()] benchmark(fun...)(uint times)
    if(areAllSafe!fun)
{
    TickDuration[lengthof!(fun)()] result;
    StopWatch sw;
    sw.start();

    foreach(i, unused; fun)
    {
        sw.reset();
        static if (is(typeof(fun[i](times))))
        {
            fun[i](times);
        }
        else
        {
            foreach(j; 0 .. times)
            {
                fun[i]();
            }
        }
        result[i] = sw.peek();
    }

    return result;
}

/++ Ditto +/
TickDuration[lengthof!(fun)()] benchmark(fun...)(uint times)
    if(!areAllSafe!fun)
{
    TickDuration[lengthof!(fun)()] result;
    StopWatch sw;
    sw.start();

    foreach(i, unused; fun)
    {
        sw.reset();
        static if (is(typeof(fun[i](times))))
        {
            fun[i](times);
        }
        else
        {
            foreach(j; 0 .. times)
            {
                fun[i]();
            }
        }
        result[i] = sw.peek();
    }

    return result;
}

//Verify Examples.
unittest
{
    void writefln(S...)(S args){}

    int a;
    void f0() {}
    void f1() {auto b = a;}
    void f2() {auto b = to!(string)(a);}
    auto r = benchmark!(f0, f1, f2)(10_000_000);
    writefln("Milliseconds to call fun[0] n times: %s", r[0].to!("msecs", int));
}

@safe unittest
{
    int a;
    void f0() {}
    //void f1() {auto b = to!(string)(a);}
    void f2() {auto b = (a);}
    auto r = benchmark!(f0, f2)(100);
}

/**
Benchmarks one or more functions, automatically issuing multiple calls
to achieve good accuracy. A baseline timing that accounts for
benchmarking overheads is kept along with the results and
automatically deducted from all timings.

The call $(D benchmark(fun)()) first calls $(D fun) once. If the call
completed too fast to gather an accurate timing, $(D fun) is called 10
times, then 100 times and so on, until a meaningful timing is
collected.

The returned value is a tuple containing the number of iterations in
the first member and the times in $(D TickDuration) format for each
function being benchmarked.

A timing indistinguishable from the baseline looping overhead appears
with a run time of zero and indicates a function that does too little
work to be timed.

Example:
----
import std.conv;
int a;
void fun() {auto b = to!(string)(a);}
auto r = benchmark!(fun)(10_000_000);
writefln("Milliseconds to call fun() %s times: %s",
    r[0], r[1][0].to!("msecs", int));
----

Since the number of iteration is the same for all functions tested,
one call to $(D benchmark) should only group together functions of
close performance profile; otherwise, slower functions will take a
long time to run catching up with faster functions.
 */
TickDuration[lengthof!(fun)()] benchmark2(fun...)()
{
    // Baseline function. Use asm inside the body to avoid
    // optimizations.
    static void baseline() { asm { nop; } }
    alias .benchmark!(fun, baseline) run;

    uint n = 1;
    typeof(run(n)) timings;
  bigloop:
    for (; n < 1_000_000_000; n *= 10)
    {
        timings = run(n);
        foreach (t; timings[0 .. $ - 1])
        {
            if (t.to!("msecs", int) < 100)
            {
                continue bigloop;
            }
        }
        break;
    }

    //writeln("iterations: ", n);
    auto baselineMs = timings[$ - 1].to!("msecs", int);
    //writeln("baseline: ", baselineMs);

    foreach (i, unused; fun)
    {
        auto ms = timings[i].to!("msecs", int);
        if (ms >= baselineMs + 10)
        {
            timings[i] -= timings[$ - 1];
            //writeln(fun[i].stringof, ": ", timings[i].to!("msecs", int));
        }
        else
        {
            timings[i] = timings[i].init;
            //writeln(fun[i].stringof, ": indistinguishable from baseline");
        }
    }

    return tuple(n, /*cast(TickDuration[timings.length - 1])*/ timings);
}

/**
Benchmarks an entire module given its name. Benchmarking proceeds as
follows: all symbols inside the module are enumerated, and those that
start with "benchmark_" are considered benchmark functions and are
timed using $(D benchmark) defined above.

This function prints a table containing the benchmark name (excluding
the $(D "benchmark_") prefix), the number of calls issued, the average
duration per call, and the speed in calls per second.

Example:
----
// file module_one.d
import std.file, std.array;

void benchmark_fileWrite()
{
    std.file.write("hello, world!");
}

void benchmark_stringAppend(uint n)
{
    string a;
    foreach (i; 0 .. n)
    {
        a ~= 'x';
    }
}

void benchmark_appender(uint n)
{
    auto s = appender!string();
    foreach (i; 0 .. n)
    {
        put(a, 'x');
    }
}

// file module_two.d
import module_one;

void main()
{
    benchmarkModule!module_one();
}
----

The program above prints a table with the benchmark results. Note that
a benchmark function may either take no parameters, indicating that
    the iteration should be done outside, or accept one $(D uint)
parameter, indicating that it does iteration on its own.
*/
void benchmarkModule(string mod)()
{
    write(
        "benchmark                                        calls       t/call  calls/sec\n"
        "------------------------------------------------------------------------------\n");

    static struct Local
    {
        // Import stuff here so we have access to it
        mixin("import " ~ mod ~ ";");

        static void doBenchmark()
        {
            struct TestResults
            {
                string name;
                uint iterations;
                TickDuration time;
                TickDuration timePerIteration;
                double itersPerSecond;
            }

            TestResults[] results;
            foreach (entity; mixin("__traits(allMembers, " ~ mod ~ ")"))
            {
                static if (entity.length >= 10
                        && entity[0 .. 10] == "benchmark_")
                {
                    auto r = mixin("benchmark2!(" ~ mod ~ "."
                            ~ entity ~ ")()");
                    ++results.length;
                    with (results[$ - 1])
                    {
                        name = entity[10 .. $];
                        iterations = r[0];
                        time = r[1][0];
                        timePerIteration = time / iterations;
                        itersPerSecond = iterations /
                            time.to!("seconds", double);
                        writefln("%-44s %1.3E  %1.3Eμs  %1.3E",
                                name, cast(double) iterations,
                                timePerIteration.to!("usecs", double),
                                itersPerSecond);
                    }
                }
            }
        }
    }

    Local.doBenchmark();
    writeln(
        "------------------------------------------------------------------------------");
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

   Examples:
--------------------
void f1() {
   // ...
}
void f2() {
   // ...
}

void main() {
   auto b = comparingBenchmark!(f1, f2, 0x80);
   writeln(b.point);
}
--------------------
  +/
@safe ComparingBenchmarkResult comparingBenchmark(alias baseFunc,
                                                  alias targetFunc,
                                                  int times = 0xfff)()
    if(isSafe!baseFunc && isSafe!targetFunc)
{
    auto t = benchmark!(baseFunc, targetFunc)(times);
    return ComparingBenchmarkResult(t[0], t[1]);
}


/++ Ditto +/
ComparingBenchmarkResult comparingBenchmark(alias baseFunc,
                                            alias targetFunc,
                                            int times = 0xfff)()
    if(!isSafe!baseFunc || !isSafe!targetFunc)
{
    auto t = benchmark!(baseFunc, targetFunc)(times);
    return ComparingBenchmarkResult(t[0], t[1]);
}


@safe unittest
{
    void f1x() {}
    void f2x() {}
    @safe void f1o() {}
    @safe void f2o() {}
    auto b1 = comparingBenchmark!(f1o, f2o, 1); // OK
    //static auto b2 = comparingBenchmark!(f1x, f2x, 1); // NG
}


unittest
{
    void f1x() {}
    void f2x() {}
    @safe void f1o() {}
    @safe void f2o() {}
    auto b1 = comparingBenchmark!(f1o, f2o, 1); // OK
    auto b2 = comparingBenchmark!(f1x, f2x, 1); // OK
}

version(StdDdoc)
{
    /++
        Function for starting to a stop watch time when the function is called
        and stopping it when its return value goes out of scope and is destroyed.

        When the value that is returned by this function is destroyed,
        $(D func) will run. $(D func) is a unary function that takes a
        $(CXREF TickDuration).

        Examples:
--------------------
writeln("benchmark start!");
{
auto mt = measureTime!((a){assert(a.seconds);});
doSomething();
}
writeln("benchmark end!");
--------------------
      +/
    auto measureTime(alias func)();
}
else
{
    @safe auto measureTime(alias func)()
        if(isSafe!func)
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
        return Result(AutoStart.yes);
    }

    auto measureTime(alias func)()
        if(!isSafe!func)
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
        return Result(AutoStart.yes);
    }
}

@safe unittest
{
    @safe static void func(TickDuration td)
    {
        assert(td.to!("seconds", real) <>= 0);
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

unittest
{
    static void func(TickDuration td)
    {
        assert(td.to!("seconds", real) <>= 0);
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

