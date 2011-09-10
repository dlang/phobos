//Written in the D programming language

/**
    Copyright: Copyright 2011-
    License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(WEB erdani.com,Andrei Alexandrescu) and Kato Shoichi
    Source:    $(PHOBOSSRC std/_benchmark.d)
 */
module std.benchmark;
import std.array, std.datetime, std.stdio, std.traits, std.typecons;
version(unittest) import std.conv;

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
        import core.exception;
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
        import core.exception;
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

    /**
    Returns $(D true) iff the $(D StopWatch) object is currently
    _running.

    Example:
----
StopWatch sw;
assert(!sw.running);
sw.start();
assert(sw.running);
sw.stop();
assert(!sw.running);
----
     */
    @property bool running() const pure
    {
        return _flagStarted;
    }

private:

    // true if observing.
    bool _flagStarted = false;

    // TickDuration at the time of StopWatch starting measurement.
    TickDuration _timeStart;

    // Total time that StopWatch ran.
    TickDuration _timeMeasured;
}

__EOF__
// workaround for bug4886
@safe size_t lengthof(aliases...)() pure nothrow
{
    return aliases.length;
}

/**
Benchmarks one or more functions for speed assessment and
comparison. A baseline timing that accounts for benchmarking overheads
is kept along with the results and automatically deducted from all
timings. A timing indistinguishable from the baseline looping overhead
appears with a run time of zero and indicates a function that does too
little work to be timed.

Params:

fun = Aliases of callable objects (e.g. function names). Each should
take either no arguments or one integral argument, which is the
iterations count.
n   = The number of times each function is to be executed.

Returns:

The amount of time (as a $(CXREF time, TickDuration)) that it took to
call each function $(D n) times. The first value is the length of time
that it took to call $(D fun[0]) $(D n) times. The second value is the
length of time it took to call $(D fun[1]) $(D n) times. Etc.

Example:
--------------------
int a;
void intToString() {auto b = to!string(a);}
void intToWstring() {auto b = to!wstring(a);}
void intToDstring() {auto b = to!dstring(a);}
auto r = benchmark!(intToString, intToWstring, intToDstring)(10_000_000);
auto names = [ "intToString", "intToWstring", "intToDstring" ];
foreach (i, timing; r)
    writefln("%s: %sms", names[i], r[i].to!("msecs", int));
--------------------

If one or more of the functions being benchmarked accept one numeric
argument convertible from $(D uint), then $(D benchmark) assumes that
function does its own iteration internally and simply passes the
iteration count to that function.

Example:
--------------------
// Variant with internal iteration
int a;
void intToString(uint n) {foreach (i; 0 .. n) auto b = to!string(a);}
void intToWstring(uint n) {foreach (i; 0 .. n) auto b = to!wstring(a);}
void intToDstring(uint n) {foreach (i; 0 .. n) auto b = to!dstring(a);}
auto r = benchmark!(intToString, intToWstring, intToDstring)(10_000_000);
auto names = [ "intToString", "intToWstring", "intToDstring" ];
foreach (i, timing; r)
    writefln("%s: %sms", names[i], r[i].to!("msecs", int));
--------------------
*/
auto benchmark(fun...)(uint times)
if ((is(typeof(fun[0]())) || is(typeof(fun[0](times))))
        && (lengthof!fun() == 1 || is(typeof(benchmark!(fun[1 .. $])(times)))))
{
    // Baseline function. Use asm inside the body to avoid
    // optimizations.
    static void baseline() { asm { nop; } }

    // Use a local pointer to avoid TLS access overhead
    auto theStopWatch = &.theStopWatch;

    // Get baseline loop time
    with (*theStopWatch) running ? reset() : start();
    foreach(j; 0 .. times)
    {
        baseline();
    }
    auto baselineTime = theStopWatch.peek();

    TickDuration[lengthof!fun()] result;
    foreach (i, unused; fun)
    {
        theStopWatch.reset();
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
        auto elapsed = theStopWatch.peek();

        // Subtract baseline
        result[i] = elapsed < baselineTime
            ? result[i].init
            : elapsed - baselineTime;
    }

    return result;
}

// Verify Example 1
unittest
{
    void writefln(S...)(S args){}

    int a;
    void intToString() {auto b = to!string(a);}
    void intToWstring() {auto b = to!wstring(a);}
    void intToDstring() {auto b = to!dstring(a);}
    auto r = benchmark!(intToString, intToWstring, intToDstring)(10_000_000);
    auto names = [ "intToString", "intToWstring", "intToDstring" ];
    foreach (i, timing; r)
        writefln("%s: %sms", names[i], r[i].to!("msecs", int));
}

// Verify Example 2
unittest
{
    void writefln(S...)(S args){}

    int a;
    void intToString(uint n) {foreach (i; 0 .. n) auto b = to!string(a);}
    void intToWstring(uint n) {foreach (i; 0 .. n) auto b = to!wstring(a);}
    void intToDstring(uint n) {foreach (i; 0 .. n) auto b = to!dstring(a);}
    auto r = benchmark!(intToString, intToWstring, intToDstring)(10_000_000);
    auto names = [ "intToString", "intToWstring", "intToDstring" ];
    foreach (i, timing; r)
        writefln("%s: %sms", names[i], r[i].to!("msecs", int));
}

/**
Benchmarks one function, automatically issuing multiple calls to
achieve good accuracy.

The call $(D benchmark!fun()) first calls $(D fun) once. If the call
completed too fast to gather an accurate timing, $(D fun) is called 10
times, then 100 times and so on, until a meaningful timing is
collected.

Params:

fun = Alias of callable object (e.g. function name). It should take
either no arguments or one integral argument, which is the iterations
count.

Returns:

A tuple containing the number of iterations in the first member and
the time in $(D TickDuration) format for the function being
benchmarked.

Example:
----
import std.conv;
int a;
void fun() { auto b = to!(string)(a); }
auto r = benchmark!fun();
writefln("Milliseconds to call fun() %s times: %s",
    r[0], r[1][0].to!("msecs", int));
----
 */
auto benchmark(alias fun)()
if (is(typeof(benchmark!fun(1u))))
{
    uint n = 1;
    TickDuration elapsed;
  bigloop:
    for (; n < 1_000_000_000; n *= 10)
    {
        elapsed = benchmark!fun(n)[0];
        if (elapsed.to!("msecs", int) < 10)
        {
            continue bigloop;
        }
        break;
    }

    return tuple(n, elapsed);
}

/**
Benchmarks an entire module given its name. Benchmarking proceeds
as follows: all symbols inside the module are enumerated, and those that
start with "benchmark_" are considered benchmark functions and are
timed using $(D benchmark) defined above.

This function prints to $(D target) a table containing for each
benchmark the function name (excluding the $(D "benchmark_") prefix),
the number of calls issued, the average duration per call, and the
speed in calls per second.

Example:
----
module module_one;
import std.file, std.array;

void benchmark_fileWrite()
{
    std.file.write("/tmp/deleteme", "hello, world!");
}

void benchmark_fileRead()
{
    std.file.read("/tmp/deleteme");
}

void main()
{
    benchmarkModule!"module_one"();
}
----

The program above prints a table with the benchmark results in the
following format.

----
===============================================================================
Benchmark                               relative  iters       t/iter    iters/s
===============================================================================
fileWrite                                         1E+02  1.768E+02μs  5.657E+03
fileRead                                          1E+03  4.208E+01μs  2.376E+04
===============================================================================
----

The $(D calls) column contains the number of iterations through the function
(always a multiple of 10). The $(D t/iter) column is the time taken by
each iteration (smaller is better), and column $(D iters/s) shows the
iterations per second (larger is better).

It is possible to benchmark functions in groups so as to see relative
differences between functions. For example, say we add the following
functions to $(D module_one) above:

----
void benchmark_append_builtin(uint n)
{
    string a;
    foreach (i; 0 .. n)
    {
        a ~= 'x';
    }
}

void benchmark_append_appender(uint n)
{
    auto a = appender!string();
    foreach (i; 0 .. n)
    {
        put(a, 'x');
    }
}

void benchmark_append_concat(uint n)
{
    string a;
    foreach (i; 0 .. n)
    {
        a = a ~ 'x';
    }
}
----

In this case, $(D benchmarkModule) detects that $(D
append_builtin) and $(D append_appender) contain the common prefix $(D
append_) and groups them together when benchmarking. The output table
in that case looks like this:

----
===============================================================================
Benchmark                                 relative  calls     t/call    calls/s
===============================================================================
fileWrite                                           1E+02  1.70E+02μs  5.87E+03
fileRead                                            1E+03  3.96E+01μs  2.52E+04
append:builtin                                      1E+06  7.80E-02μs  1.28E+07
       appender                          6.15E+00x  1E+06  1.20E-02μs  7.85E+07
       concat                            4.94E-02x  1E+04  1.51E+00μs  6.63E+05
===============================================================================
----

The benchmark has filled the column titled $(D relative) with $(D
6.15E+00x) for $(D appender) (which means in this run $(D append_appender) was $(D 6.15)
times faster than $(D append_builtin)), and with $(D 4.94E-02x) for
$(D concat) (meaning that $(D append_concat)'s speed was $(D 0.0494) of
$(D append_builtin)'s speed).
 */
void benchmarkModule(string mod)(File target = stdout)
{
    import std.algorithm;

    struct TestResult
    {
        string name;
        string groupName;
        uint iterations;
        TickDuration time;
        TickDuration timePerIteration;
        double itersPerSecond;
        double ratio = 0;
    }

    TestResult[] results;

    // Step 1: fill the results with name information
    {
        // Import stuff here so we have access to it
        mixin("import " ~ mod ~ ";");

        foreach (entity; mixin("__traits(allMembers, " ~ mod ~ ")"))
        {
            static if (entity.length >= 10
                    && entity[0 .. 10] == "benchmark_")
            {
                ++results.length;
                results.back().name = entity[10 .. $];
                auto sub = findSplit(results.back().name, "_");
                if (!sub[1].empty)
                {
                    results.back().groupName = sub[0];
                    results.back().name = sub[2];
                }
            }
        }
    }

    size_t index;

    void collectResult(string entity, Tuple!(uint, TickDuration) stats)
    {
        scope(exit) ++index;
        if (index == 0)
        {
            target.writefln(
                "=================================================="
                "=============================\n"
                "%-42s%8s%7s%11s%10s\n" // sum must be 79
                "================================================="
                "==============================", "Benchmark",
                "relative", "calls", "t/call", "calls/s");
        }
        with (results[index])
        {
            iterations = stats[0];
            time = stats[1];
            timePerIteration = time / iterations;
            itersPerSecond = iterations /
                time.to!("seconds", double);

            // Format and print
            string format, printedName;
            if (groupName && index > 0
                    && groupName == results[index - 1].groupName)
            {
                // This is part of a group of related benchmarks
                size_t reference = index - 1;
                while (results[reference].groupName == groupName)
                    --reference;
                ++reference;
                ratio = itersPerSecond / results[reference].itersPerSecond;
                format = "%1$-40s %5$1.2Ex  %2$1.0E  %3$1.2Eμs  %4$1.2E";
                printedName = replicate(" ", groupName.length + 1) ~ name;
            }
            else
            {
                // No grouping
                format = "%1$-51s %2$1.0E  %3$1.2Eμs  %4$1.2E";
                printedName = groupName ? groupName~":"~name : name;
            }
            target.writefln(format,
                    printedName, cast(double) iterations,
                    timePerIteration.to!("usecs", double),
                    itersPerSecond, ratio);
        }
    }

    {
        // Import stuff here so we have access to it
        mixin("import " ~ mod ~ ";");
        foreach (entity; mixin("__traits(allMembers, " ~ mod ~ ")"))
        {
            static if (entity.length >= 10
                    && entity[0 .. 10] == "benchmark_")
            {
                auto r = mixin("benchmark!(" ~ mod ~ "."
                        ~ entity ~ ")()");
                collectResult(entity, r);
            }
        }
    }

    if (results.length)
    {
        target.writeln(
            "========================================================="
            "======================");
    }
}

version(StdRunBenchmarks)
{
    private void benchmark_fileWrite()
    {
        std.file.write("/tmp/deleteme", "hello, world!");
    }

    private void benchmark_fileRead()
    {
        std.file.read("/tmp/deleteme");
    }

    private void benchmark_append_builtin(uint n)
    {
        string a;
        foreach (i; 0 .. n)
        {
            a ~= 'x';
        }
    }

    private void benchmark_append_appender(uint n)
    {
        import std.range;
        auto a = appender!string();
        foreach (i; 0 .. n)
        {
            put(a, 'x');
        }
    }

    private void benchmark_append_concat(uint n)
    {
        string a;
        foreach (i; 0 .. n)
        {
            a = a ~ 'x';
        }
    }

    unittest
    {
        benchmarkModule!"std.benchmark"();
    }

    unittest
    {
        // Make sure this compiles
        if (false) benchmarkModule!"std.benchmark"();
        version(StdRunBenchmarks) benchmarkModule!"std.benchmark"();
    }

// One benchmark stopwatch
private StopWatch theStopWatch;

/**
Pauses and resumes the current benchmark, respectively. This is useful
if the benchmark needs to set things up before performing the
measurement.

Example:
----
import std.algorithm;
void benchmark_findDouble(uint n)
{
    // Fill an array of random numbers and an array of random indexes
    benchmarkPause();
    auto array = new double[n];
    auto indexes = new size_t[n];
    foreach (i; 0 .. n)
    {
        array[i] = uniform(0.0, 1000.0);
        indexes[i] = uniform(0, n);
    }
    benchmarkResume();

    // The actual benchmark begins here
    foreach (i; 0 .. n)
    {
        auto balance = std.algorithm.find(array, array[indexes[i]]);
    }
}
unittest
{
    writeln(benchmark!benchmark_findDouble(10_000).to!("msecs", uint));
}
----
 */
void benchmarkPause()
{
    theStopWatch.stop();
}

/// Ditto
void benchmarkResume()
{
    theStopWatch.start();
}

version(unittest) import std.random, std.stdio;
unittest
{
    void benchmark_findDouble(uint n)
    {
        // Fill an array of random numbers and an array of random indexes
        benchmarkPause();
        auto array = new double[n];
        auto indexes = new size_t[n];
        foreach (i; 0 .. n)
        {
            array[i] = uniform(0.0, 1000.0);
            indexes[i] = uniform(0, n);
        }
        benchmarkResume();

        // The actual benchmark begins here
        foreach (i; 0 .. n)
        {
            auto balance = std.algorithm.find(array, array[indexes[i]]);
        }
    }

    //writeln(benchmark!benchmark_findDouble(10_000)[0].to!("msecs",
    //uint));
    benchmark!benchmark_findDouble(10_000);
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
ComparingBenchmarkResult comparingBenchmark(alias baseFunc,
                                            alias targetFunc,
                                            int times = 0xfff)()
{
    auto t = benchmark!(baseFunc, targetFunc)(times);
    return ComparingBenchmarkResult(t[0], t[1]);
}


@trusted unittest
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
            import std.functional;
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
            import std.functional;
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

