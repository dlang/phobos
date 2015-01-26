/**
Implements logging facilities.

Message logging is a common approach to expose runtime information of a
program. Logging should be easy, but also flexible and powerful, therefore
$(D D) provides a standard interface for logging.

The easiest way to create a log message is to write
$(D import std.logger; log("I am here");) this will print a message to the
$(D stderr) device.  The message will contain the filename, the linenumber, the
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

Top-level calls to logging-related functions go to the default $(D Logger)
object called $(D sharedLog).
$(LI $(D log))
$(LI $(D trace))
$(LI $(D info))
$(LI $(D warning))
$(LI $(D critical))
$(LI $(D fatal))
The default $(D Logger) will by default log to $(D stderr) and has a default
$(D LogLevel) of $(D LogLevel.all). The default Logger can be accessed by
using the property called $(D sharedLog). This property a reference to the
current default $(D Logger). This reference can be used to assign a new
default $(D Logger).
-------------
sharedLog = new FileLogger("New_Default_Log_File.log");
-------------

Additional $(D Logger) can be created by creating a new instance of the
required $(D Logger).

The $(D LogLevel) of an log call can be defined in two ways. The first is by
calling $(D log) and passing the $(D LogLevel) explicit as the first argument.
The second way of setting the $(D LogLevel) of a
log call, is by calling either $(D trace), $(D info), $(D warning),
$(D critical), or $(D fatal). The log call will than have the respective
$(D LogLevel). If no $(D LogLevel) is defined the log call will use the
current $(D LogLevel) of the used $(D Logger). If data is logged with
$(D LogLevel) $(D fatal) by default an $(D Error) will be thrown.
This behaviour can be modified by using the member $(D fatalHandler) to
assign a custom delegate to handle log call with $(D LogLevel) $(D fatal).

Conditional logging can be achieved be appending passing a $(D bool) as first
argument to a log function.  If conditional logging is used the condition must
be $(D true) in order to have the log message logged.

In order to combine an explicit $(D LogLevel) passing with conditional
logging, the $(D LogLevel) has to be passed as first argument followed by the
$(D bool).

Messages are logged if the $(D LogLevel) of the log message is greater than or
equal to than the $(D LogLevel) of the used $(D Logger) and additionally if the
$(D LogLevel) of the log message is greater equal to the global $(D LogLevel).
If a condition is passed into the log call, this condition must be true.

The global $(D LogLevel) is accessible by using $(D globalLogLevel).
To assign the $(D LogLevel) of a $(D Logger) use the $(D logLevel) property of
the logger.

If $(D printf)-style logging is needed add a $(B f) to the logging call, such as
$(D myLogger.infof("Hello %s", "world");) or $(fatalf("errno %d", 1337))
The additional $(B f) enables $(D printf)-style logging for call combinations of
explicit $(D LogLevel) and conditional logging functions and methods.

To customize the $(D Logger) behavior, create a new $(D class) that inherits from
the abstract $(D Logger) $(D class), and implements the $(D writeLogMsg)
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
overwriting the $(D writeLogMsg) method the methods $(D beginLogMsg),
$(D logMsgPart) and $(D finishLogMsg) can be overwritten.

In order to disable logging at compile time, pass $(D StdLoggerDisableLogging) as a
version argument to the $(D D) compiler when compiling your program code.
This will disable all logging functionality.
Specific $(D LogLevel) can be disabled at compile time as well.
In order to disable logging with the $(D trace) $(D LogLevel) pass
$(D StdLoggerDisableTrace) as a version.
The following table shows which version statement disables which
$(D LogLevel).
$(TABLE
    $(TR $(TD $(D LogLevel.trace) ) $(TD StdLoggerDisableTrace))
    $(TR $(TD $(D LogLevel.info) ) $(TD StdLoggerDisableInfo))
    $(TR $(TD $(D LogLevel.warning) ) $(TD StdLoggerDisableWarning))
    $(TR $(TD $(D LogLevel.error) ) $(TD StdLoggerDisableError))
    $(TR $(TD $(D LogLevel.critical) ) $(TD StdLoggerDisableCritical))
    $(TR $(TD $(D LogLevel.fatal) ) $(TD StdLoggerDisableFatal))
)
Such a version statement will only disable logging in the associated compile
unit.

By default four $(D Logger) implementations are given. The $(D FileLogger)
logs data to files. It can also be used to log to $(D stdout) and $(D stderr)
as these devices are files as well. A $(D Logger) that logs to $(D stdout) can
therefore be created by $(D new FileLogger(stdout)).
The $(D MultiLogger) is basically an associative array of $(D string)s to
$(D Logger). It propagates log calls to its stored $(D Logger). The
$(D ArrayLogger) contains an array of $(D Logger) and also propagates log
calls to its stored $(D Logger). The $(D NullLogger) does not do anything. It
will never log a message and will never throw on a log call with $(D LogLevel)
$(D error).
*/
module std.experimental.logger;

public import std.experimental.logger.core;
public import std.experimental.logger.filelogger;
public import std.experimental.logger.nulllogger;
public import std.experimental.logger.multilogger;
