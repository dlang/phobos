/**
Implements logging facilities.

Message logging is a common approach to expose runtime information of a
program. Logging should be easy, but also flexible and powerful, therefore
`D` provides a standard interface for logging.

The easiest way to create a log message is to write
$(D import std.logger; log("I am here");) this will print a message to the
`stderr` device.  The message will contain the filename, the linenumber, the
name of the surrounding function, the time and the message.

Copyright: Copyright Robert "burner" Schadek 2013 --
License: <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors: $(WEB http://www.svs.informatik.uni-oldenburg.de/60865.html, Robert burner Schadek)

-------------
log("Logging to the sharedLog with its default LogLevel");
logf(LogLevel.info, 5 < 6, "%s to the sharedLog with its LogLevel.info", "Logging");
info("Logging to the sharedLog with its info LogLevel");
warning(5 < 6, "Logging to the sharedLog with its LogLevel.warning if 5 is less than 6");
error("Logging to the sharedLog with its error LogLevel");
errorf("Logging %s the sharedLog %s its error LogLevel", "to", "with");
critical("Logging to the"," sharedLog with its error LogLevel");
fatal("Logging to the sharedLog with its fatal LogLevel");

auto fLogger = new FileLogger("NameOfTheLogFile");
fLogger.log("Logging to the fileLogger with its default LogLevel");
fLogger.info("Logging to the fileLogger with its default LogLevel");
fLogger.warning(5 < 6, "Logging to the fileLogger with its LogLevel.warning if 5 is less than 6");
fLogger.warningf(5 < 6, "Logging to the fileLogger with its LogLevel.warning if %s is %s than 6", 5, "less");
fLogger.critical("Logging to the fileLogger with its info LogLevel");
fLogger.log(LogLevel.trace, 5 < 6, "Logging to the fileLogger"," with its default LogLevel if 5 is less than 6");
fLogger.fatal("Logging to the fileLogger with its warning LogLevel");
-------------

Top-level calls to logging-related functions go to the default `Logger`
object called `sharedLog`.
$(LI `log`)
$(LI `trace`)
$(LI `info`)
$(LI `warning`)
$(LI `critical`)
$(LI `fatal`)
The default `Logger` will by default log to `stderr` and has a default
`LogLevel` of `LogLevel.all`. The default Logger can be accessed by
using the property called `sharedLog`. This property a reference to the
current default `Logger`. This reference can be used to assign a new
default `Logger`.
-------------
sharedLog = new FileLogger("New_Default_Log_File.log");
-------------

Additional `Logger` can be created by creating a new instance of the
required `Logger`.

The `LogLevel` of an log call can be defined in two ways. The first is by
calling `log` and passing the `LogLevel` explicit as the first argument.
The second way of setting the `LogLevel` of a
log call, is by calling either `trace`, `info`, `warning`,
`critical`, or `fatal`. The log call will than have the respective
`LogLevel`. If no `LogLevel` is defined the log call will use the
current `LogLevel` of the used `Logger`. If data is logged with
`LogLevel` `fatal` by default an `Error` will be thrown.
This behaviour can be modified by using the member `fatalHandler` to
assign a custom delegate to handle log call with `LogLevel` `fatal`.

Conditional logging can be achieved be appending passing a `bool` as first
argument to a log function.  If conditional logging is used the condition must
be `true` in order to have the log message logged.

In order to combine an explicit `LogLevel` passing with conditional
logging, the `LogLevel` has to be passed as first argument followed by the
`bool`.

Messages are logged if the `LogLevel` of the log message is greater than or
equal to than the `LogLevel` of the used `Logger` and additionally if the
`LogLevel` of the log message is greater equal to the global `LogLevel`.
If a condition is passed into the log call, this condition must be true.

The global `LogLevel` is accessible by using `globalLogLevel`.
To assign the `LogLevel` of a `Logger` use the `logLevel` property of
the logger.

If `printf`-style logging is needed add a $(B f) to the logging call, such as
$(D myLogger.infof("Hello %s", "world");) or $(fatalf("errno %d", 1337))
The additional $(B f) enables `printf`-style logging for call combinations of
explicit `LogLevel` and conditional logging functions and methods.

To customize the `Logger` behavior, create a new `class` that inherits from
the abstract `Logger` `class`, and implements the `writeLogMsg`
method.
-------------
class MyCustomLogger : Logger
{
    this(string newName, LogLevel lv) @safe
    {
        super(newName, lv);
    }

    override void writeLogMsg(ref LogEntry payload)
    {
        // log message in my custom way
    }
}

auto logger = new MyCustomLogger();
logger.log("Awesome log message");
-------------

To gain more precise control over the logging process, additionally to
overwriting the `writeLogMsg` method the methods `beginLogMsg`,
`logMsgPart` and `finishLogMsg` can be overwritten.

In order to disable logging at compile time, pass `StdLoggerDisableLogging` as a
version argument to the `D` compiler when compiling your program code.
This will disable all logging functionality.
Specific `LogLevel` can be disabled at compile time as well.
In order to disable logging with the `trace` `LogLevel` pass
`StdLoggerDisableTrace` as a version.
The following table shows which version statement disables which
`LogLevel`.
$(TABLE
    $(TR $(TD `LogLevel.trace` ) $(TD StdLoggerDisableTrace))
    $(TR $(TD `LogLevel.info` ) $(TD StdLoggerDisableInfo))
    $(TR $(TD `LogLevel.warning` ) $(TD StdLoggerDisableWarning))
    $(TR $(TD `LogLevel.error` ) $(TD StdLoggerDisableError))
    $(TR $(TD `LogLevel.critical` ) $(TD StdLoggerDisableCritical))
    $(TR $(TD `LogLevel.fatal` ) $(TD StdLoggerDisableFatal))
)
Such a version statement will only disable logging in the associated compile
unit.

By default four `Logger` implementations are given. The `FileLogger`
logs data to files. It can also be used to log to `stdout` and `stderr`
as these devices are files as well. A `Logger` that logs to `stdout` can
therefore be created by $(D new FileLogger(stdout)).
The `MultiLogger` is basically an associative array of `string`s to
`Logger`. It propagates log calls to its stored `Logger`. The
`ArrayLogger` contains an array of `Logger` and also propagates log
calls to its stored `Logger`. The `NullLogger` does not do anything. It
will never log a message and will never throw on a log call with `LogLevel`
`error`.
*/
module std.experimental.logger;

public import std.experimental.logger.core;
public import std.experimental.logger.filelogger;
public import std.experimental.logger.nulllogger;
public import std.experimental.logger.multilogger;
