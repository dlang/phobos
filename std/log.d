// Written in the D programming language.

/**
Synopsis:
----
import std.log;

void main(string[] args)
{
    initLogging(args);

    log.info.when(args.length > 1)("You passed arguments: ", args[1 .. $]);

    log.info("This is an info message.");
    log.warning("This is a warning message.");
    log.error("This is an error message!");
    log.dfatal("This is a fatal message in debug mode!!");

    log.vlog(0)("Verbosity 0 message");
    log.vlog(1)("Verbosity 1 message");
    log.vlog(2)("Verbosity 2 message");

    foreach (i; 0 .. 10)
    {
        log.info.every(9)("Every nine");
        log.info.when(i & 1).every(3)("For odd numbers, show every three times: ", i);
        log.info.every(3).when(i & 1)("Every three times, show for odd numbers: ", i);
    }

    log.fatal("This is a fatal message!!!");
}
----

Source: $(PHOBOSSRC std/_log.d)

Macros: WIKI=Phobos/Log

Copyright: Copyright Digital Mars 2011-.
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB erdani.com, Andrei Alexandrescu)

The module $(D std._log) defines several entities that cover common
logging tasks. You can _log messages by broad severity levels, enable
or disable the minimum severity level logged both at compile time and
run time, _log based on a Boolean condition, _log every $(D n) times
or every $(D n) milliseconds to avoid flooding, and more.

Four logging levels are predefined, in increasing order of severity:
"info", "warning", "error", "critical", and "fatal". They output to
distinct _log files. The names of the files are of the form $(D
&laquo;program name&raquo;.&laquo;hostname&raquo;.&laquo;user
name&raquo;._log.&laquo;severity
level&raquo;.&laquo;date&raquo;.&laquo;time&raquo;.&laquo;pid&raquo;),
e.g.  $(D hello.erdani.com.johnsmith._log.INFO.0110508-180059.84301).
On Unix-like systems, the directory for all log files is the first
existing directory out of the following:

$(UL $(LI The $(D TEST_TMPDIR) environment variable;) $(LI The $(D
TMPDIR) environment variable;) $(LI The $(D TMP) environment
variable;) $(LI The $(D /tmp/) directory;) $(LI The current
directory.))

Any message logged at a given severity is also logged in logs of
lesser severity. Logging to the fatal _log always terminates the
application after logging. Logging to the critical _log always throws
an exception after logging.

The library responds to a few command line options:

$(UL $(LI $(D --logtostderr) causes all logging to go to stderr
instead of log files.)  $(LI $(D --stderrthreshold=n) causes all log
messages at and above severity $(D n) to be printed to $(D stderr) in
addition to their respective log files. The default is 2, meaning that
the $(D error), $(D critical), and $(D fatal) logs also log to $(D
stderr).) $(LI $(D --minloglevel=n)) causes only messages at or above
severity $(D n) to be actually logged (default: 0). $(LI $(D
--tmp_dir=/path/to/dir) causes the logging directory to be $(D
/path/to/dir) instead of the default-selected directory.) $(LI $(D
--v) bumps the verbosity level up one.))

BUGS: Not tested on Windows. Currently not working with multiple
threads due to bugs in the compiler.
 */
module std.log;

import std.array, std.datetime, std.exception, std.format, std.getopt, std.path,
    std.process, std.stdio, std.string;
import core.atomic, core.sys.posix.pthread, core.sys.posix.unistd;

private string
    fileNameFormat = "%1$s.%2$s.%3$s.log.%4$s.%5$s%6$02s%7$02s-%8:10$02s.%11$s",
    format = "%1$s%2:3$02u %4$02u:%5$02u:%6$02u.%7$06u %8$s %10$s:%11$u] %12:$s\n",
    opener = "Log file created at: %1$s/%2$02s/%3$02s %4$02s:%5$02s:%6$02s\n"
    "Running on machine: %7$s\n"
    "Log line format: %8$s\n",
    logToStderrFlag = "logtostderr",
    stderrThresholdFlag = "stderrthreshold",
    minLogLevelFlag = "minloglevel",
    logDirFlag = "log_dir",
    verbosityFlag = "v+";
private uint verbosityLevel;

/**
Logging functionality is exposed primarily via a global $(D log)
object, which logs to files and optionally to $(D stderr). Refer to
$(D LogBattery) right below for details on using $(D log) with various
logging levels.
 */
LogBattery log;

version (StdDdoc)
    /**
       Battery of log objects by level.
     */
struct LogBattery
{
    /**
       The fatal log always terminates the application right after the
       first logging action to it. Logging at the fatal level cannot
       be disabled statically, but it can be disabled dynamically by
       passing $(D --minloglevel=5) or higher to the program's command
       line (it does terminate the app even if dynamically disabled).
     */
    FileLogger fatal;
    /**
       The critical log always throws an exception right after any
       logging action to it. Logging at the critical level cannot be
       disabled statically, but it can be disabled dynamically by
       passing $(D --minloglevel=4) or higher to the program's command
       line (it does throw an exception even if dynamically disabled).
     */
    FileLogger critical;
    /**
       The error log is conventionally used for logging error
       messages. It can be completely stripped statically by compiling
       with $(D -version=strip_log_error). It can be disabled
       dynamically by passing $(D --minloglevel=3) or higher to the
       program's command line.
     */
    FileLogger error;
    /**
       The warning log is conventionally used for logging warning
       messages. It can be completely stripped statically by compiling
       with $(D -version=strip_log_warning). It can be disabled
       dynamically by passing $(D --minloglevel=2) or higher to the
       program's command line.
     */
    FileLogger warning;
    /**
       The info log is conventionally used for logging informational
       messages. It can be completely stripped statically by compiling
       with $(D -version=strip_log_info). It can be disabled
       dynamically by passing $(D --minloglevel=1) or higher to the
       program's command line.
     */
    FileLogger info;
    /**
       The dfatal log is an alias for $(D fatal) in debug mode, and
       for $(D error) otherwise.
     */
    FileLogger dfatal;

    /**
       Logs by verbosity levels can be manually activated by passing
       $(D --v) once or more to the program's command line. The
       default verbosity level is $(D 0) and it gets bumped with each
       $(D --v). A message is actually logged if the verbosity
       parameter is less than or equal to the global verbosity
       level. All $(D vlog) logging goes to the $(D info) log, meaning
       that the $(D info) log must be enabled (both statically and
       dynamically).
     */
    FileLogger vlog(uint verbosity);
}
else
struct LogBattery
{
    FileLogger fatal, critical;
    version (strip_log_error)
        NullLogger error;
    else
       typeof(fatal) error;
    version (strip_log_warning)
        NullLogger warning;
    else
        typeof(error) warning;
    version (strip_log_info)
        NullLogger info;
    else
        typeof(warning) info;
    debug alias fatal dfatal;
    else alias error dfatal;

    // Verbose loggers
    static if (is(typeof(info) == NullLogger))
        NullLogger vlog(lazy uint) { return NullLogger.init; }
    else
        auto vlog(uint verbosity)
        {
            return info.when(verbosityLevel >= verbosity);
        }
}

private enum InitStatus { uninitialized, uninitializedAndWarnedUser, initialized, destroyed };
private InitStatus initStatus;

struct Once
{
    shared uint _state;

    void run(scope void delegate() fun) //shared
    {
        if (_state == 2) return;
        if (cas(&_state, 0, 1))
        {
            // Must call the function
            fun();
            _state = 2;
            return;
        }
        // Here we must wait until state_ becomes 2
        while (_state != 2)
        {
            sleep(1);
        }
    }
}

unittest
{
    shared Once once;
    int x;
    // once.run({ x++; });
    // once.run({ x++; });
    // assert(x == 1);
}

private struct LogData
{
    string _name;
    File _file;
    Once _once;
}

// 0 is INFO, 1 is WARNING, 2 is ERROR, 3 is CRITICAL, 4 is FATAL,
// and 5 is stderr
private __gshared LogData logData[6];

shared static this()
{
    // By default only the last log has an associated file, and that's stderr
    *(cast(File*) & logData[$ - 1]._file) = stderr;

    log.info.level = 'I';
    log.warning.level = 'W';
    log.error.level = 'E';
    log.critical.level = 'C';
    log.fatal.level = 'F';
}

/**
   This function initializes the logging subsystem, and must be called
   with the application command line in order to set up flags
   properly. All application-specific flags and other command line
   parameters are left alone.

   If logging is effected without having called this function, all
   parameters are at their default values and all logging is done only
   to $(D stderr).

   Example:
----
import std.log, ...;

void main(string[] args)
{
    initLogging(args);
}
----
 */
void initLogging(ref string[] args)
{
    enforce(initStatus == InitStatus.uninitialized, "You can't call initLogging twice.");
    scope(success) initStatus = InitStatus.initialized;

    bool logToStderr;
    uint stderrThreshold = 2;
    uint minLogLevel;
    string logDir;
    getopt(args, config.passThrough,
            logToStderrFlag, &logToStderr,
            stderrThresholdFlag, &stderrThreshold,
            minLogLevelFlag, &minLogLevel,
            logDirFlag, &logDir,
            verbosityFlag, &verbosityLevel);

    if (!logToStderr)
    {
        immutable logDir = logDir ? logDir : getLogDir();
        immutable pid = getpid();

        static immutable dchar[5] levels = [ 'I', 'W', 'E', 'C', 'F' ];
        foreach (i; 0 .. levels.length)
        {
            logData[i]._name = std.path.join(logDir,
                    getLogBasename(args[0], pid, levels[i]));
            writeln(logData[i]._name);
        }

        log.info.indices = [ 0 ];
        log.warning.indices = [ 1, 0 ];
        log.error.indices = [ 2, 1, 0 ];
        log.critical.indices = [ 3, 2, 1, 0 ];
        log.fatal.indices = [ 4, 3, 2, 1, 0 ];

        switch (stderrThreshold)
        {
        case 0:
            log.info.indices ~= 5;
            goto case 1;
        case 1:
            log.warning.indices ~= 5;
            goto case 2;
        case 2:
            log.error.indices ~= 5;
            goto case 3;
        case 3:
            log.critical.indices ~= 5;
            break;
        case 4:
            log.fatal.indices ~= 5;
            break;
        default:
            break;
        }
    }

    switch (minLogLevel)
    {
    default:
        log.fatal.indices = null;
        goto case 4;
    case 4:
        log.critical.indices = null;
        goto case 3;
    case 3:
        log.error.indices = null;
        goto case 2;
    case 2:
        log.warning.indices = null;
        goto case 1;
    case 1:
        log.info.indices = null;
        break;
    case 0:
        // Everything stays enabled
        break;
    }
}

struct NullLogger
{
    static @property void level(dchar) {}
    static @property void indices(int[]) {}
    static void opCall(T...)(lazy T) {}
    static NullLogger when(lazy bool) { return NullLogger.init; }
    static NullLogger every(lazy size_t) { return NullLogger.init; }
    static NullLogger everyMs(lazy size_t) { return NullLogger.init; }
}

/**
   Implementation for each of $(D info), $(D warning), $(D error), $(D
   critical), and $(D fatal) logs.
 */
struct FileLogger
{
    private static __gshared FileLogger nullLogger = { true, null };

    private bool _wasOpened;
    private size_t[] indices = [ 5 ];
    private dchar level;

    private bool ensureOpened()
    {
        if (_wasOpened) return true;
        scope(success) _wasOpened = true;

        if (initStatus == InitStatus.uninitialized)
        {
            stderr.writeln("std.log.initLogging not called. Logging will go to stderr.");
            initStatus = InitStatus.uninitializedAndWarnedUser;
            _wasOpened = true;
            return true;
        }

        string hostname = chomp(shell("hostname"));/* = @@@TODO@@@ */;

        foreach (index; indices)
        {
            string name = logData[index]._name;
            if (name.empty)
            {
                // Empty filename means by convention stderr
                assert(logData[index]._file.isOpen);
            }
            else
            {
                logData[index]._once.run({
                            (cast(File*) & logData[index]._file).open(name, "w");
                            // Write the opener
                            auto t = Clock.currTime();
                            logData[index]._file.writef(opener, t.year, t.month, t.day,
                                    t.hour, t.minute, t.second, hostname, format);
                        });
            }
        }

        return true;
    }

    /**
       Main logging function is an overload of the function call
       operator.

       Example:
----
double transmogrificationFactor;
...
log.info("Transmogrification occurs with factor ", transmogrificationFactor);
----
     */
    private void opCall(string f = __FILE__, size_t n = __LINE__, T...)(lazy T args)
    {
        if (!indices.ptr || !ensureOpened()) return;
        auto t = Clock.currTime();
        immutable ulong tid = cast(ulong) pthread_self();
        static immutable fname = basename(f);
        static immutable fdir = f[0 .. $ - fname.length];

        foreach (index; indices)
        {
            logData[index]._file.writef(format, level,
                    t.month, t.day, t.hour, t.minute, t.second,
                    t.fracSec.usecs, tid, fdir, fname, n, args);
        }
        level != 'F' || assert(0, "Fatal error encountered.");
        level != 'C' || enforce(0, "Fatal error encountered.");
    }

    /**
       Conditional logging only executes logging when the condition is
       true.

       Example:
----
int cakes;
...
log.warning.when(cakes > 100)("Got tons of cakes");
----
     */
    ref FileLogger when(bool condition)
    {
        return condition ? this : nullLogger;
    }

    /**
       Sampled down logging only executes logging every $(D times)
       calls.

       Example:
----
foreach (i; 0 .. 1_000_000) {
    log.warning.every(1000)("Index is now ", i);
    ...
}
----

       Combining $(D when) and $(D every) is possible and leads to
       different behaviors depending on the order in which they are
       combined. For example, $(D log.warning.when(a > b).every(10)(a,
       " greater than ", b)) will test $(D a > b) every call and will
       issue a log message once every tenth time they match. In
       contrast, $(D log.warning.every(10).when(a > b)(a, " greater
       than ", b)) will do the test every tenth call and will issue a
       log message whenever the condition is true.
     */
    ref FileLogger every(string f = __FILE__, size_t n = __LINE__)(size_t times)
    {
        static size_t counter;
        return counter++ % times ? nullLogger : this;
    }

    /**
       Sampled down logging only executes logging only if at least $(D
       millis) milliseconds have passed since the last call.

       Example:
----
foreach (i; 0 .. 1_000_000) {
    log.warning.everyMs(1000)("One more second went by...");
    ...
}
----

       Combining $(D everyMs) with $(D when) and/or $(D every) is
       possible and subject to the expected interactions.
     */
    ref FileLogger everyMs(string f = __FILE__, size_t n = __LINE__)(size_t millis)
    {
        static ulong lastTimeInHnsecs;
        if (!lastTime)
        {
            // Wasn't initialized, do call it'
            lastTimeInHnsecs = Clock.currTime.stdTime;
            return this;
        }
        immutable ulong now = Clock.currTime.stdTime;
        if (now - lastTimeInHnsecs < millis * 10)
        {
            return nullLogger;
        }
        lastTimeInHnsecs = now;
        return this; // will log
    }
}

struct NoLog
{
    NullLogger error, warning, info;
    // Verbose loggers
    auto vlog(uint)
    {
        return NullLogger.init;
    }
}

NoLog nolog;

debug alias log dlog;
else alias nolog dlog;

// Get all temp directory candidates
private string getLogDir()
{
    static bool isDir(in char[] d)
    {
        bool test;
        return !collectException(test = std.file.isDir(d)) && test;
    }

    string[] candidates;
    version(Windows)
    {
        char tmp[MAX_PATH];
        if (GetTempPathA(MAX_PATH, tmp))
        {
            candidates ~= to!string(tmp);
        }
        else
        {
            candidates ~= "C:\\tmp\\";
            candidates ~= "C:\\temp\\";
        }
    }
    else
    {
        candidates =
            [
                getenv("TEST_TMPDIR"),
                getenv("TMPDIR"),
                getenv("TMP"),
                "/tmp",
            ];
    }

    foreach (candidate; candidates)
    {
        if (!candidate || !isDir(candidate)) continue;
        return candidate;
    }
    return "./";
}

string getLogBasename(in char[] progName, in ulong pid, in dchar logKind)
{
    auto t = Clock.currTime();
    string logKindLong = logKind == 'I' ? "INFO" : logKind == 'W' ? "WARNING"
        : logKind == 'E' ? "ERROR" : logKind == 'C' ? "CRITICAL" : "FATAL";
    string hostname = chomp(shell("hostname"));/* = @@@TODO@@@ */;
    auto result = appender!string();
    formattedWrite(result, fileNameFormat, basename(progName), getenv("USER"),
            hostname, logKindLong, t.year, t.month, t.day, t.hour,
            t.minute, t.second, pid);
    return result.data;
}
