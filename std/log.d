// Written in the D programming language.

/**
Synopsis:
----
import std.log;

void main(string[] args)
{
    initLogging(args);

    logInfo.format("You passed %s argument(s)", args.length - 1);
    logInfo.when(args.length > 1)("Arguments: ", args[1 .. $]);

    logInfo("This is an info message.");
    logWarning("This is a warning message.");
    logError("This is an error message!");
    logDFatal("This is a fatal message in debug mode!!");

    vlog(0)("Verbosity 0 message");
    vlog(1)("Verbosity 1 message");
    vlog(2)("Verbosity 2 message");

    foreach (i; 0 .. 10)
    {
        logInfo.every(9)("Every nine");
        logInfo.when(i & 1).every(3)("For odd numbers, show every three times: ", i);
        logInfo.every(3).when(i & 1)("Every three times, show for odd numbers: ", i);
    }

    logFatal("This is a fatal message!!!");
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
distinct _log files. By default, the names of the files are of the
form $(D &laquo;program name&raquo;.&laquo;hostname&raquo;.&laquo;user
name&raquo;._log.&laquo;severity
level&raquo;.&laquo;date&raquo;.&laquo;time&raquo;.&laquo;pid&raquo;),
e.g.  $(D hello.erdani.com.johnsmith._log.INFO.0110508-180059.84301).
On Unix-like systems, the directory for all _log files is the first
existing directory out of the following:

$(UL $(LI The $(D TEST_TMPDIR) environment variable;) $(LI The $(D
TMPDIR) environment variable;) $(LI The $(D TMP) environment
variable;) $(LI The $(D /tmp/) directory;) $(LI The current
directory.))

Any message logged at a given severity is also logged in logs of
lesser severity. Logging to the fatal _log always terminates the
application after logging. Logging to the critical _log always throws
an exception after logging.

The library responds to a few command line options (loaded with the
call to $(D initLogging) below):

$(UL $(LI $(D --logtostderr) causes all logging to go to stderr
instead of _log files.)  $(LI $(D --stderrthreshold=n) causes all _log
messages at and above severity $(D n) to be printed to $(D stderr) in
addition to their respective _log files. The default is 2, meaning
that the $(D error), $(D critical), and $(D fatal) logs also _log to
$(D stderr).) $(LI $(D --minloglevel=n) causes only messages at or
above severity $(D n) to be actually logged (default: 0).) $(LI $(D
--log_dir=/path/to/dir) causes the logging directory to be $(D
/path/to/dir) instead of the default-selected directory.) $(LI $(D
--v) bumps the verbosity level up one.))

BUGS: Not tested on Windows. Not tested with multiple
threads. Using $(D vlog) in conjuction with $(D -version=strip_log_xxx)
causes linker errors.
 */
module std.log;

import std.array, std.datetime, std.exception, std.file, std.format,
    std.getopt, std.path, std.process, std.stdio, std.string;
import core.atomic, core.sys.posix.pthread, core.sys.posix.unistd;

private string
    dirName,
    fileNameFormat = "%1$s.%2$s.%3$s.log.%4$s.%5$s%6$02s%7$02s-%8:10$02s.%11$s",
    prefix = "%1$s%2:3$02u %4$02u:%5$02u:%6$02u.%7$06u %8$s %10$s:%11$u] ",
    suffix = "\n",
    opener = "Log file created at: %1$s/%2$02s/%3$02s %4$02s:%5$02s:%6$02s\n"
    "Running on machine: %7$s\n"
    "Log line prefix: \"%8$s\"\n"
    "Log line suffix: \"%9$s\"\n",
    logToStderrFlag = "logtostderr",
    stderrThresholdFlag = "stderrthreshold",
    minLogLevelFlag = "minloglevel",
    logDirFlag = "log_dir",
    verbosityFlag = "v+";

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
    ...
}
----
 */
void initLogging(ref string[] args)
{
    enforce(initStatus == InitStatus.uninitialized,
            "You can't call initLogging twice.");
    scope(success) initStatus = InitStatus.initialized;

    dirName = getLogDir();

    bool logToStderr;
    uint stderrThreshold = 2;
    uint minLogLevel;
    getopt(args, config.passThrough,
            logToStderrFlag, &logToStderr,
            stderrThresholdFlag, &stderrThreshold,
            minLogLevelFlag, &minLogLevel,
            logDirFlag, &dirName,
            verbosityFlag, &verbosityLevel);

    if (!logToStderr)
    {
        immutable pid = getpid();

        static immutable dchar[5] levels = [ 'I', 'W', 'E', 'C', 'F' ];
        foreach (i; 0 .. levels.length)
        {
            logData[i]._name = std.path.join(dirName,
                    getLogBasename(args[0], pid, levels[i]));
            //writeln(logData[i]._name);
        }

        logInfo.indices = [ 0 ];
        logWarning.indices = [ 1, 0 ];
        logError.indices = [ 2, 1, 0 ];
        logCritical.indices = [ 3, 2, 1, 0 ];
        logFatal.indices = [ 4, 3, 2, 1, 0 ];

        switch (stderrThreshold)
        {
        case 0:
            logInfo.indices ~= 5;
            goto case 1;
        case 1:
            logWarning.indices ~= 5;
            goto case 2;
        case 2:
            logError.indices ~= 5;
            goto case 3;
        case 3:
            logCritical.indices ~= 5;
            break;
        case 4:
            logFatal.indices ~= 5;
            break;
        default:
            break;
        }
    }

    switch (minLogLevel)
    {
    default:
        logFatal.indices = null;
        goto case 4;
    case 4:
        logCritical.indices = null;
        goto case 3;
    case 3:
        logError.indices = null;
        goto case 2;
    case 2:
        logWarning.indices = null;
        goto case 1;
    case 1:
        logInfo.indices = null;
        break;
    case 0:
        // Everything stays enabled
        break;
    }
}

version (StdDdoc)
{
    /**
       The fatal log always terminates the application right after the
       first logging action to it. Logging at the fatal level cannot
       be disabled statically, but it can be disabled dynamically by
       passing $(D --minloglevel=5) or higher to the program's command
       line (it does terminate the app even if dynamically disabled).
     */
    FileLogger logFatal;
    /**
       The critical log always throws an exception right after any
       logging action to it. Logging at the critical level cannot be
       disabled statically, but it can be disabled dynamically by
       passing $(D --minloglevel=4) or higher to the program's command
       line (it does throw an exception even if dynamically disabled).
     */
    FileLogger logCritical;
    /**
       The error log is conventionally used for logging error
       messages. It can be completely stripped statically by compiling
       with $(D -version=strip_log_error). It can be disabled
       dynamically by passing $(D --minloglevel=3) or higher to the
       program's command line.
     */
    FileLogger logError;
    /**
       The warning log is conventionally used for logging warning
       messages. It can be completely stripped statically by compiling
       with $(D -version=strip_log_warning) or $(D
       -version=strip_log_error). It can be disabled dynamically by
       passing $(D --minloglevel=2) or higher to the program's command
       line.
     */
    FileLogger logWarning;
    /**
       The info log is conventionally used for logging informational
       messages. It can be completely stripped statically by compiling
       with $(D -version=strip_log_info), $(D
       -version=strip_log_warning), or $(D
       -version=strip_log_error). It can be disabled dynamically by
       passing $(D --minloglevel=1) or higher to the program's command
       line.
     */
    FileLogger logInfo;
    /**
       Alias for $(D logFatal) in debug mode (i.e. when compiled with
       $(D -debug)), and for $(D logError) otherwise.
     */
    FileLogger logDFatal;

    /**
       Logs by verbosity levels can be manually activated by passing
       $(D --v) one or more times to the program's command line. The
       default verbosity level is $(D 0) and it gets bumped with each
       $(D --v). A message is actually logged if the verbosity
       parameter is less than or equal to the global verbosity
       level. All $(D vlog) logging goes to $(D logInfo), meaning that
       $(D logInfo) must be enabled (both statically and dynamically)
       in order for $(D vlog) to work.
     */
    ref FileLogger vlog(uint verbosity);
}
else
{
    FileLogger logFatal, logCritical;
    version (strip_log_error)
        StaticNullLogger logError;
    else
       typeof(logFatal) logError;
    version (strip_log_warning)
        StaticNullLogger logWarning;
    else
        typeof(logError) logWarning;
    version (strip_log_info)
        StaticNullLogger logInfo;
    else
        typeof(logWarning) logInfo;
    debug alias logFatal logDFatal;
    else alias logError logDFatal;

    // Verbose loggers
    static if (is(typeof(logInfo) == StaticNullLogger))
        auto vlog(lazy uint) { return StaticNullLogger.init; }
    else
        auto ref vlog(uint verbosity)
        {
            return logInfo.when(verbosityLevel >= verbosity);
        }
}

private enum InitStatus { uninitialized, uninitializedAndWarnedUser,
        initialized, destroyed };
private InitStatus initStatus;

private struct Once
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

    logInfo.level = 'I';
    logWarning.level = 'W';
    logError.level = 'E';
    logCritical.level = 'C';
    logFatal.level = 'F';
}

struct StaticNullLogger
{
    static @property void level(dchar) {}
    static @property void indices(int[]) {}
    static void opCall(T...)(lazy T) {}
    static void format(T...)(lazy string, lazy T) {}
    static StaticNullLogger when(lazy bool) { return StaticNullLogger.init; }
    static StaticNullLogger every(lazy size_t) { return StaticNullLogger.init; }
    static StaticNullLogger everyMs(lazy size_t)
    { return StaticNullLogger.init; }
}

/**
   Implementation for each of $(D logInfo), $(D logWarning), $(D
   logError), $(D logCritical), and $(D logFatal) logs. When stripped
   statically by compiling with with $(D -version=strip_log_xxx), the
   type of the stripped logs is replaced with a do-nothing type
   offering the same nominal interface as $(D FileLogger).
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
                                    t.hour, t.minute, t.second, hostname,
                                    prefix, suffix);
                        });
            }
        }

        return true;
    }

    /**
       Basic logging is defined as an overload of the function call
       operator. Formats and prints each argument in turn.

       Example:
----
double transmogrificationFactor;
...
logInfo("Transmogrification occurs with factor ", transmogrificationFactor);
----
     */
    void opCall(string f = __FILE__, size_t n = __LINE__, T...)(lazy T args)
    {
        return format!(f, n, T)("%1:$s", args);
    }

    /**
       Outputs a formatted string to the log.

       Example:
----
int n;
double transmogrificationFactor;
...
// writes e.g. "Factor 42.42 for the 5th transmogrification"
logInfo.format("Factor %s for the %sth transmogrification",
    transmogrificationFactor, n);
----
     */
    void format(string f = __FILE__, size_t n = __LINE__, T...)
        (lazy string format, lazy T args)
    {
        if (!indices.ptr || !ensureOpened()) return;
        auto t = Clock.currTime();
        immutable ulong tid = cast(ulong) pthread_self();
        static immutable fname = basename(f);
        static immutable fdir = f[0 .. $ - fname.length];

        foreach (index; indices)
        {
            auto writer = logData[index]._file.lockingTextWriter();
            formattedWrite(writer, prefix, level,
                    t.month, t.day, t.hour, t.minute, t.second,
                    t.fracSec.usecs, tid, fdir, fname, n);
            formattedWrite(writer, format, args);
            writer.put(suffix);
        }
        level != 'F' || assert(0, "Fatal error encountered.");
        level != 'C' || enforce(0, "Fatal error encountered.");
    }

    /**
       Conditional logging only executes logging _when the condition
       is true. This may seem redundant because a similar effect can
       be achieved with $(D if (condition) logXxx(message)), but using
       $(D logXxx.when(condition)(message)) does not evaluate $(D
       condition) at all if the logging level is disabled, and
       disappears entirely _when the logging level is statically
       stripped.

       Example:
----
int cakes;
...
logWarning.when(cakes > 2000)("Got tons of cakes");
----
     */
    ref FileLogger when(bool condition)
    {
        return condition ? this : nullLogger;
    }

    /**
       Sampled down logging only executes logging _every $(D times)
       calls (the first call does write to log).

       Example:
----
foreach (i; 0 .. 1_000_000) {
    logWarning.every(1000).format("# i=%s;", i);
    ...
}
----
     */
    ref FileLogger every(string f = __FILE__, size_t n = __LINE__)(size_t times)
    {
        static size_t counter;
        return counter++ % times ? nullLogger : this;
    }

    /**
       Only executes logging after the first $(D times) calls.

       Example:
----
foreach (i; 0 .. 1_000_000) {
    // One entry per 1000 passes, starting at the 10_000th call
    logWarning.after(10_000).every(1000)("Index has risen to ", i);
    ...
}
----
     */
    ref FileLogger after(string f = __FILE__, size_t n = __LINE__)
    (size_t times)
    {
        static size_t counter;
        return counter >= times ? this : (++counter, nullLogger);
    }

    /**
       Sampled down logging only executes logging only if at least $(D
       millis) milliseconds have passed since the last call. The first
       call does execute logging.

       Example:
----
foreach (i; 0 .. 1_000_000) {
    logWarning.everyMs(1000)("One more second went by...");
    ...
}
----
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

    /**
       Delayed logging writes a log entry only after at least $(D
       millis) milliseconds have passed since the first call.

       Example:
----
foreach (i; 0 .. 1_000_000) {
    logWarning.afterMs(1000)("Things are kind of slow...");
    ...
}
----

       Combining $(D when), $(D every), $(D after), $(D _everyMs), and
       $(D _afterMs) is possible and leads to different useful
       behaviors depending on the order in which they are
       combined. For example, $(D logWarning.when(a > b).every(10)(a,
       " greater than ", b)) will test $(D a > b) _every call and will
       issue a log message once _every tenth time they match. In
       contrast, $(D logWarning.every(10).when(a > b)(a, " greater
       than ", b)) will do the test _every tenth call and will issue a
       log message whenever the condition is true. The expression $(D
       logWarning._afterMs(10_000).every(10).when(a >
       b)._everyMs(5000)(a, " greater than ", b)) first "waits" for
       ten seconds, then tests $(D a > b) every pass and issues a
       warning log entry every tenth time that condition is true, but
       no more frequently than every five seconds.
     */
    ref FileLogger afterMs(string f = __FILE__, size_t n = __LINE__)
    (size_t millis)
    {
        static ulong lastTimeInHnsecs;
        if (!lastTime)
        {
            // Wasn't initialized
            lastTimeInHnsecs = Clock.currTime.stdTime;
            return nullLogger;
        }
        immutable ulong now = Clock.currTime.stdTime;
        if (now - lastTimeInHnsecs < millis * 10)
        {
            return nullLogger;
        }
        return this; // will log
    }
}

/**
Returns or sets the log directory name.
 */
@property string logDir()
{
    return dirName;
}
/// Ditto
@property void logDir(string name)
{
    mkdirRecurse(name);
    dirName = name;
}

/**
Returns or sets the current log file format (without directory). The
format is in $(XREF format, formattedWrite) style and may include the
following format specs:

$(BOOKTABLE , $(TR $(TD $(D "%1$")) $(TD The name of the program that
created the process)) $(TR $(TD $(D "%2$")) $(TD User name)) $(TR $(TD
$(D "%3$")) $(TD Host name)) $(TR $(TD $(D "%4$")) $(TD Log severity
($(D "INFO"), $(D "WARNING") $(D "ERROR"), $(D "CRITICAL"), or $(D
"FATAL")))) $(TR $(TD $(D "%5$")) $(TD Creation year)) $(TR $(TD $(D
"%6$")) $(TD Creation month)) $(TR $(TD $(D "%7$")) $(TD Creation
day)) $(TR $(TD $(D "%8$")) $(TD Creation hour)) $(TR $(TD $(D "%9$"))
$(TD Creation minute)) $(TR $(TD $(D "%10$")) $(TD Creation second))
$(TR $(TD $(D "%11$")) $(TD ID of the process)) )

The default log file format is $(D
"%1&#36;s.%2&#36;s.%3&#36;s.log.%4&#36;s.%5&#36;s%6&#36;02s%7&#36;02s-%8:10&#36;02s.%11&#36;s").
 */
@property string logFileNameFormat()
{
    return fileNameFormat;
}
/// Ditto
@property void logFileNameFormat(string s)
{
    enforce(!s.empty);
    fileNameFormat = s;
}

/**
Returns or sets the first thing written to a log file at opening. The
format is in $(XREF format, formattedWrite) style and may include the
following format specs:

$(BOOKTABLE ,
$(TR $(TD $(D "%1$")) $(TD Creation year))
$(TR $(TD $(D "%2$")) $(TD Creation month))
$(TR $(TD $(D "%3$")) $(TD Creation day))
$(TR $(TD $(D "%4$")) $(TD Creation hour))
$(TR $(TD $(D "%5$")) $(TD Creation minute))
$(TR $(TD $(D "%6$")) $(TD Creation second))
$(TR $(TD $(D "%7$")) $(TD Host name))
$(TR $(TD $(D "%8$")) $(TD Log line prefix))
$(TR $(TD $(D "%9$")) $(TD Log line suffix))
)

The default log file header format is $(D
"Log file created at: %1&#36;s/%2&#36;02s/%3&#36;02s %4&#36;02s:%5&#36;02s:%6&#36;02s\nRunning on machine: %7&#36;s\nLog line prefix: \"%8&#36;s\"\nLog line suffix: \"%9&#36;s\"\n").
 */
@property string logFileHeaderFormat()
{
    return opener;
}
/// Ditto
@property void logFileHeaderFormat(string s)
{
    opener = s;
}

/**
Returns or sets the formatting for the prefix prepended to each log
line. The format is in $(XREF format, formattedWrite) style and may
include the following format specs:

$(BOOKTABLE ,
$(TR $(TD $(D "%1$")) $(TD A one-letter severity indicator: $(D 'I') for info, $(D 'W') for warning, $(D 'E') for error, $(D 'C') for critical, and $(D 'F') for fatal.))
$(TR $(TD $(D "%2$")) $(TD Month))
$(TR $(TD $(D "%3$")) $(TD Day))
$(TR $(TD $(D "%4$")) $(TD Hour))
$(TR $(TD $(D "%5$")) $(TD Minute))
$(TR $(TD $(D "%6$")) $(TD Second))
$(TR $(TD $(D "%7$")) $(TD Microsecond))
$(TR $(TD $(D "%8$")) $(TD Thread ID))
$(TR $(TD $(D "%9$")) $(TD Directory of the source file issuing the log entry))
$(TR $(TD $(D "%10$")) $(TD Base name of the source file issuing the log entry))
$(TR $(TD $(D "%11$")) $(TD Source line number issuing the log entry))
)

The default prefix is $(D
"%1&#36;s%2:3&#36;02u %4&#36;02u:%5&#36;02u:%6&#36;02u.%7&#36;06u %8&#36;s %10&#36;s:%11&#36;u] ").
 */
@property string logLinePrefix()
{
    return prefix;
}
/// Ditto
@property void logLinePrefix(string s)
{
    enforce(!s.empty);
    prefix = s;
}

/**
Returns or sets the suffix appended to each log line. The suffix is a
simple string without formatting abilities. The default suffix is
$(D"\n").
 */
@property string logLineSuffix()
{
    return suffix;
}
/// Ditto
@property void logLineSuffix(string s)
{
    suffix = s;
}

/**
Returns or sets the respective flag name. The $(D flag) parameter may
be $(D "logtostderr"), $(D "stderrthreshold"), $(D "minloglevel"), $(D
log_dir), $(D "v"). By default each flag name is set to its own
string, e.g. $(D flagName("logtostderr")) returns $(D
"logtostderr"). Changing the flag names is useful if the application
wants to customize command line parameters.

Setting flags must be done before calling $(D initLogging).

Example:
----
void main(string[] args)
{
    flagName("stderrthreshold", "threshold-for-stderr");
    initLogging(args); // interprets --threshold-for-stderr
    ...
}
----
 */
string flagName(in char[] flag)
{
    switch (flag)
    {
    case "logtostderr": return logToStderrFlag;
    case "stderrthreshold": return stderrThresholdFlag;
    case "minloglevel": return minLogLevelFlag;
    case "log_dir": return logDirFlag;
    case "v": return verbosityFlag;
    default: break;
    }
    return enforce(cast(string) null, "Invalid flag name \"" ~ flag ~ "\"");
}
/// Ditto
void flagName(string flag, string newName)
{
    enforce(initStatus == InitStatus.uninitialized,
            "flagName: Flag names should be set before calling initLogging()");
    string * p;
    switch (flag)
    {
    case "logtostderr": p = &logToStderrFlag; break;
    case "stderrthreshold": p = &stderrThresholdFlag; break;
    case "minloglevel": p = &minLogLevelFlag; break;
    case "log_dir": p = &logDirFlag; break;
    case "v": p = &verbosityFlag; break;
    default: enforce(null, "Invalid flag name \"" ~ flag ~ "\"");
    }
    // @@@TODO@@@ Insert newName checks here?
    *p = newName;
}

/**
Gets or sets the verbosity level. The verbosity level is 0 by
default. Each occurrence of $(D "--v") in the command line bumps it up
by one.
 */
uint verbosityLevel;

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
