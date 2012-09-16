// Written in the D programming language

/**
Copyright: Copyright 2011-
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB erdani.com, Andrei Alexandrescu) and Kato Shoichi
Source:    $(PHOBOSSRC std/_benchmark.d)

Synopsis:
----
module module_one;
import std.benchmark, std.file;

void benchmark_fileWrite()
{
    std.file.write("/tmp/deleteme", "hello, world!");
}

void benchmark_fileRead()
{
    std.file.read("/tmp/deleteme");
}

mixin(scheduleForBenchmarking);

void main()
{
    printBenchmarks();
}
----

The code above prints:

---
===============================================================================
module_one                                             relative ns/iter  iter/s
===============================================================================
fileWrite                                                        144.2K    6.9K
fileRead                                                          27.1K   36.9K
===============================================================================
---
 */
module std.benchmark;

import std.algorithm, std.datetime, std.range, std.stdio, std.traits, std.typecons;
version(unittest) import std.random;

debug = std_benchmark;

/**
Benchmarks one or more functions for speed assessment and comparison,
and prints results as formatted text. A baseline timing that accounts
for benchmarking overheads is kept along with the results and
automatically deducted from all timings. A timing indistinguishable
from the baseline looping overhead appears with a run time of zero and
indicates a function that does too little work to be timed.

Measurement is done in epochs. For each function benchmarked, the
smallest time is taken over all epochs.

Benchmark results report time per iteration.

Params:

funs = If one ore more $(D funs) are provided, they must come as pairs
in which the first element is a string (the name of the benchmark) and
the second element is the alias of a function (the actual
benchmark). Each alias must refer to a function that takes either no
arguments or one integral argument (which is the iterations count).
target = $(D File) where output is printed.

Example:
---
printBenchmarks!(
    "file write", { std.file.write("/tmp/deleteme", "hello, world!"); },
    "file read",  { std.file.read("/tmp/deleteme"); })
    ();
---

The example above outputs to $(D stdout):

---
===============================================================================
Benchmark                                              relative ns/iter  iter/s
===============================================================================
file write                                                       144.3K    6.9K
file read                                                         26.3K   38.0K
===============================================================================
---

With internal iteration, the results would be similar:

Example:
---
printBenchmarks!(
    "file write", { std.file.write("/tmp/deleteme", "hello, world!"); },
    "file read",  (uint n) {
        foreach (i; 0 .. n) std.file.read("/tmp/deleteme");
    })
    ();
---

In the example above, the framework iterates the first lambda many
times and collects timing information. For the second lambda, instead
of doing the iteration, the framework simply passes increasing values
of $(D n) to the lambda. In the end time per iteration is measured, so
the performance profile (and the printout) would be virtually
identical to the one in the previous example.

If the call to $(D printBenchmarks) does not provide a name for some
benchmarks, the name of the benchmarked function is used. (For
lambdas, the name is e.g. $(D __lambda5).)

Example:
---
void benchmark_fileWrite()
{
    std.file.write("/tmp/deleteme", "hello, world!");
}
printBenchmarks!(
    benchmark_fileWrite,
    "file read", { std.file.read("/tmp/deleteme"); },
    { std.file.read("/tmp/deleteme"); })
    ();
---

The example above outputs to $(D stdout):

---
===============================================================================
Benchmark                                              relative ns/iter  iter/s
===============================================================================
fileWrite2()                                                      76.0K   13.2K
file read                                                         28.6K   34.9K
__lambda2                                                         27.8K   36.0K
===============================================================================
---

If the name of the benchmark starts with $(D "benchmark_") or $(D
"benchmark_relative_"), that prefix does not appear in the printed
name. If the prefix is $(D "benchmark_relative_"), the "relative"
column is filled in the output. The relative performance is computed
relative to the last non-relative benchmark completed and expressed in
either times (suffix $(D "x")) or percentage (suffix $(D "%")). The
percentage is, for example, $(D 100.0%) if benchmark runs at the same
speed as the baseline, $(D 200.0%) if the benchmark is twice as fast
as the baseline, and $(D 50%) if the benchmark is half as fast.

Example:
---
printBenchmarks!(
    "file write", { std.file.write("/tmp/deleteme", "hello, world!"); },
    "benchmark_relative_file read",  { std.file.read("/tmp/deleteme"); },
    "benchmark_relative_array creation",  { new char[32]; })
    ();
---

This example has one baseline and two relative tests. The output looks
as follows:

---
===============================================================================
Benchmark                                              relative ns/iter  iter/s
===============================================================================
file write                                                       140.2K    7.1K
file read                                                517.8%   27.1K   36.9K
array creation                                          1284.3%  116.0     8.6M
===============================================================================
---

According to the data above, file reading is $(D 5.178) times faster
than file writing, whereas array creation is $(D 1200) times faster
than file writing.

If no functions are passed as $(D funs), calling $(D printBenchmarks)
prints the previously registered per-module benchmarks.
Refer to $(LREF scheduleForBenchmarking).
 */
void printBenchmarks(funs...)(File target = stdout)
{
    BenchmarkResult[] results;
    static if (funs.length > 0)
    {
        benchmark!(funs)(results);
    }
    else
    {
        runBenchmarks(results);
    }
    printResults(results);
}

/**
Benchmarks functions and appends the results to the $(D results)
parameter. This function is used by $(LREF printBenchmarks), and the
$(D funs) parameter has the same requirements as for that function.

Using $(D benchmark) directly is recommended for custom processing and
printing of _benchmark results.

Example:
---
BenchmarkResults[] timings;
benchmark!(
    "file write", { std.file.write("/tmp/deleteme", "hello, world!"); },
    "file read",  { std.file.read("/tmp/deleteme"); })
    (timings);
foreach (ref datum; timings)
{
    writefln("%s: %s ns/iteration", datum.benchmarkName,
        datum.perIteration.to!("nsecs", uint));
}
---
 */
void benchmark(funs...)(ref BenchmarkResult[] results, string moduleName = null)
{
    auto times = benchmarkImpl!(onlyAliases!funs)();
    uint curBenchmark = 0;
    string name;
    TickDuration lastBaseline;

    foreach (i, fun; funs)
    {
        static if (is(typeof(fun): string))
        {
            name = fun;
        }
        else
        {
            if (!name) name = funs[i].stringof;
            const isRelative = skipOver(name, "benchmark_") &&
                skipOver(name, "relative_");
            double relative;
            if (isRelative)
            {
                relative = cast(double) lastBaseline.to!("nsecs", uint) /
                    times[curBenchmark].to!("nsecs", uint);
            }
            else
            {
                lastBaseline = times[curBenchmark];
            }
            results ~= BenchmarkResult(
                moduleName,
                name,
                times[curBenchmark++],
                relative);
            name = null;
        }
    }
}

/**
   Result of one function's benchmark.
*/
struct BenchmarkResult
{
    /**
       Module name in which the function resides ($(D null) if not applicable).
    */
    string moduleName;
    /**
       Name of the benchmark (sans the $(D benchmark_) or $(D
       benchmark_relative_) prefix, if any).
    */
    string benchmarkName;
    /**
       Time per iteration.
    */
    TickDuration perIteration;
    /**
       Relative timing (if benchmark is a _relative one). Refer to the
       definition of $(D benchmarkModule) below for what constitutes a
       relative benchmark. For relative benchmarks, $(D relative) is
       $(D 1.0) if the benchmark has the same speed as its baseline,
       $(D 2.0) is the benchmark is twice as fast, and $(D 0.5) if the
       benchmark has half the speed. For non-_relative benchmarks, $(D
       relative) is set to $(D NaN), which is testable with $(XREF
       math,isNaN).
     */
    double relative;
}

/*
  Given a bunch of aliases, benchmarks them all and returns their
  respective durations.
*/
private TickDuration[fun.length] benchmarkImpl(fun...)()
{
    immutable uint epochs = 1000;
    TickDuration minSignificantDuration = TickDuration.from!"usecs"(50);

    // Baseline function. Use asm inside the body to avoid
    // optimizations.
    static void baseline() { asm { nop; } }

    // Use a local pointer to avoid TLS access overhead
    auto theStopWatch = &.theStopWatch;

    // All functions to look at include the baseline and the measured
    // functions.
    import std.typetuple;
    alias TypeTuple!(baseline, fun) allFuns;
    TickDuration baselineTimePerIteration;
    TickDuration[fun.length] result;

    // MEASUREMENTS START HERE

    foreach (i, measured; allFuns)
    {
        TickDuration bestEpoch;

        // So we have several epochs, and bestEpoch will track the
        // minimum time across epochs.
        foreach (epoch; 0 .. epochs)
        {
            // Within each epoch, we call the function repeatedly
            // until we collect at least a total time of
            // minSignificantDuration.
            for (uint repeats = 1; repeats < 1_000_000_000; repeats *= 10)
            {
                auto elapsed = callFun!(allFuns[i])(repeats, *theStopWatch);

                if (elapsed < minSignificantDuration)
                {
                    // Crappy measurement, try again with more repeats
                    continue;
                }

                // Good measurement, record it if it's better than the
                // minimum.

                // Removing this useless test exposes a codegen bug.
                if (!repeats) throw new Exception(null);

                auto timePerIteration = elapsed / cast(double) repeats;
                if (bestEpoch == bestEpoch.init || timePerIteration < bestEpoch)
                {
                    bestEpoch = timePerIteration;
                }
                break;
            }
        }

        // Store the final result
        static if (i == 0)
        {
            baselineTimePerIteration = bestEpoch;
        }
        else
        {
            result[i - 1] = bestEpoch;
        }
    }

    // MEASUREMENTS JUST ENDED

    // Subtract the baseline from all results
    foreach (i, f; fun)
    {
        //writeln(__traits(identifier, fun[i]));
        if ((result[i] -= baselineTimePerIteration) < TickDuration.init) {
            result[i] = TickDuration.init;
        }
    }

    // Return result sans the baseline
    return result;
}

unittest
{
    import std.conv;

    debug(std_benchmark) {} else void writefln(S...)(S args){}

    int a = 123_456_789;
    auto r = benchmarkImpl!(
        {auto b = to!string(a);},
        {auto b = to!wstring(a);},
        {auto b = to!dstring(a);})
        ();
    auto names = [ "intToString", "intToWstring", "intToDstring" ];
    foreach (i, timing; r)
        writefln("%s: %sns/call", names[i], r[i].to!("nsecs", int)());
}

// Verify Example 2
unittest
{
    import std.conv;

    debug (std_benchmark) {} else void writefln(S...)(S args){}

    int a = 123_456_789;
    auto r = benchmarkImpl!(
        (uint n) { foreach (i; 0 .. n) auto b = to!string(a); },
        (uint n) { foreach (i; 0 .. n) auto b = to!wstring(a); },
        (uint n) { foreach (i; 0 .. n) auto b = to!dstring(a); })
        ();
    auto names = [ "intToString", "intToWstring", "intToDstring" ];
    foreach (i, timing; r)
        writefln("%s: %sns/call", names[i], r[i].to!("nsecs", int)());
}

/*
 * Calls a function either by alias or by string. Returns the duration
 * per iteration.
 */
private TickDuration callFun(alias measured)(uint repeats, ref StopWatch theStopWatch)
{
    with (theStopWatch) running ? reset() : start();

    static if (is(typeof(measured(repeats))))
    {
        // Internal iteration
        measured(repeats);
    }
    else
    {
        // External iteration
        foreach (j; 0 .. repeats)
        {
            measured();
        }
    }

    return theStopWatch.peek();
}

/*
 * Given a bunch of aliases and strings, keeps only aliases of symbols
 * that start with "benchmark_".
 */
private template onlyBenchmarks(T...)
{
    import std.typetuple;

    static if (!T.length)
    {
        alias T onlyBenchmarks;
    }
    else static if (T[0].stringof.length > 10 && T[0].stringof[0 .. 10] == "benchmark_")
    {
        alias TypeTuple!(T[0], onlyBenchmarks!(T[1 .. $])) onlyBenchmarks;
    }
    else
    {
        alias TypeTuple!(onlyBenchmarks!(T[1 .. $])) onlyBenchmarks;
    }
}

/*
  Eliminates strings, keeping only aliases.
 */
private template onlyAliases(T...)
{
    import std.typetuple;

    static if (!T.length)
    {
        alias T onlyAliases;
    }
    else static if (!is(typeof(T[0]) : string))
    {
        alias TypeTuple!(T[0], onlyAliases!(T[1 .. $])) onlyAliases;
    }
    else
    {
        alias TypeTuple!(onlyAliases!(T[1 .. $])) onlyAliases;
    }
}

unittest
{
    alias onlyAliases!("hello", int, "world", double) aliases;
    static assert(aliases.length == 2);
    static assert(is(int == aliases[0]));
    static assert(is(double == aliases[1]));
}

debug (std_benchmark) mixin(scheduleForBenchmarking);

/*
Generates benchmarking code for a bunch of functions passed as
strings. Intended to be used during compilation as part of $(D
scheduleForBenchmarking).
 */
string benchmarkModuleCodegen()(string[] funs...)
{
    auto result = q{addBenchmarks(& benchmark!(};
    foreach (fun; funs)
    {
        import std.algorithm;
        if (!startsWith(fun, "benchmark_"))
        {
            continue;
        }
        result ~= fun;
        result ~= ", ";
    }
    result ~= q{), "test");};
    return result;
}

/**
The examples shown so far feature simple, ad-hoc benchmarks, but $(D
std.benchmark) allows for superior automation and systematic use aimed
at large projects.

The code $(D mixin(scheduleForBenchmarking)) planted at module level
schedules the entire module for benchmarking. The actual benchmarking
can be done globally by calling $(LREF printBenchmarks) (with no
arguments) or $(LREF runBenchmarks). Either call is usually made from
$(D main).

In a multi-module application, several modules may define benchmarks,
and $(D printBenchmarks) distinguishes each visually.

Example:
---
module acme;
import std.file, std.array;

void benchmark_fileWrite()
{
    std.file.write("/tmp/deleteme", "hello, world!");
}

void benchmark_relative_fileRead()
{
    std.file.read("/tmp/deleteme");
}

mixin(scheduleForBenchmarking);
---

Typically the $(D mixin) is guarded by a version so benchmarks are only run if desired.

Example:
---
version (benchmark_enabled) mixin(scheduleForBenchmarking);
---
 */
@property string scheduleForBenchmarking()
{
    return `
shared static this()
{
    mixin("enum code = benchmarkModuleCodegen(__traits(allMembers, "~
            .stringof[7 .. $]~"));");
    mixin(code);
}`;
}

debug (std_benchmark)
{
    private void benchmark_fileWrite()
    {
        std.file.write("/tmp/deleteme", "hello, world!");
    }

    private void benchmark_fileRead()
    {
        std.file.read("/tmp/deleteme");
    }

    private void benchmark_appendBuiltin(uint n)
    {
        string a;
        foreach (i; 0 .. n)
        {
            a ~= 'x';
        }
    }

    private void benchmark_relative_appendAppender(uint n)
    {
        import std.range;
        auto a = appender!string();
        foreach (i; 0 .. n)
        {
            put(a, 'x');
        }
    }

    private void benchmark_relative_appendConcat(uint n)
    {
        string a;
        foreach (i; 0 .. n)
        {
            a = a ~ 'x';
        }
    }
}

/*
Adds benchmarks to the global queue of benchmarks to be executed. Most
frequently used implicitly by $(LREF scheduleForBenchmarking).
 */
void addBenchmarks(
    void function(ref BenchmarkResult[], string) fun,
    string moduleName)
{
    allBenchmarks ~= tuple(moduleName, fun);
}

// One benchmark stopwatch
private StopWatch theStopWatch;

/*
Array containing all benchmarks to be executed. Usually they are
executed by calling $(D runBenchmarks) or $(D printBenchmarks).
 */
private Tuple!(string, void function(ref BenchmarkResult[], string))[]
allBenchmarks;

/**

Performs all benchmarks previously scheduled with $(LREF
scheduleForBenchmarking), application-wide. Usually not called
directly, but instead as support for $(LREF printBenchmarks). User
code may be interested in using this function directly for
e.g. results formatting.

  */
void runBenchmarks(ref BenchmarkResult[] results)
{
    foreach (b; allBenchmarks)
    {
        b[1](results, b[0]);
    }
}

/**
Prints benchmark results as described with $(LREF
printBenchmarks). This is useful if benchmark postprocessing is
desired before printing.
 */
void printResults(in BenchmarkResult[] data, File target = stdout)
{
    if (data.empty)
    {
        return;
    }

    enum columns = 79;
    string thisModule, thisGroup;

    void printModuleHeader()
    {
        target.writefln(
            "=================================================="
            "=============================\n"
            "%-*s%8s%8s%8s\n"
            "================================================="
            "==============================", columns - 24,
            thisModule is null ? "Benchmark" : thisModule,
            "relative", "t/iter", "iter/s");
    }

    foreach (i, datum; data)
    {
        if (thisModule != datum.moduleName || i == 0)
        {
            thisModule = datum.moduleName;
            printModuleHeader();
        }
        double itersPerSecond = 1.0 / datum.perIteration.to!("seconds", double)();
        auto name = datum.benchmarkName;
        if (datum.relative is double.init)
        {
            // Write without relative information
            target.writefln("%-*s %6.1ms  %6.1m",
                    columns - 16, name,
                    datum.perIteration.to!("seconds", double)(),
                    itersPerSecond);
        }
        else
        {
            // Write with relative information
            double relative = datum.relative;
            string fmt;
            if (relative < 1000)
            {
                // represent relative speed as percent
                fmt = "%-*s %7.1f%%  %6.1m  %6.1m";
                relative *= 100;
            }
            else
            {
                // represent relative speed as multiplication factor
                fmt = "%-*s  %6.1mx  %6.1m  %6.1m";
            }
            target.writefln(fmt,
                    columns - 25, name,
                    relative,
                    datum.perIteration.to!("seconds", double)(),
                    itersPerSecond);
        }
    }
    target.writeln(repeat('=', columns));
}

/**
Suspends and resumes the current benchmark, respectively. This is useful
if the benchmark needs to set things up before performing the
measurement.

Example:
----
import std.algorithm;
void benchmark_findDouble(uint n)
{
    // Fill an array of random numbers and an array of random indexes
    benchmarkSuspend();
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
    TODO writeln(benchmark!benchmark_findDouble(10_000).to!("msecs", uint));
}
----
 */
void benchmarkSuspend()
{
    theStopWatch.stop();
}

/// Ditto
void benchmarkResume()
{
    theStopWatch.start();
}

unittest
{
    void benchmark_findDouble(uint n)
    {
        // Fill an array of random numbers and an array of random indexes
        benchmarkSuspend();
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
    benchmarkImpl!benchmark_findDouble();
}

/++
   Aliases from $(D std.datetime).
  +/
alias std.datetime.AutoStart AutoStart;
/// ditto
alias std.datetime.StopWatch StopWatch;
/// ditto
alias std.datetime.ComparingBenchmarkResult ComparingBenchmarkResult;
/// ditto
alias std.datetime.comparingBenchmark comparingBenchmark;
/// ditto
alias std.datetime.measureTime measureTime;
