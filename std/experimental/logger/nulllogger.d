module std.experimental.logger.nulllogger;

import std.experimental.logger.core;

/** The `NullLogger` will not process any log messages.

In case of a log message with `LogLevel.fatal` nothing will happen.
*/
class NullLogger : Logger
{
    /** The default constructor for the `NullLogger`.

    Independent of the parameter this Logger will never log a message.

    Params:
      lv = The `LogLevel` for the `NullLogger`. By default the `LogLevel`
      for `NullLogger` is `LogLevel.info`.
    */
    this(const LogLevel lv = LogLevel.info) @safe
    {
        super(lv);
        this.fatalHandler = delegate() {};
    }

    override protected void writeLogMsg(ref LogEntry payload) @safe @nogc
    {
    }
}

///
@safe unittest
{
    auto nl1 = new NullLogger(LogLevel.all);
    nl1.info("You will never read this.");
    nl1.fatal("You will never read this, either and it will not throw");
}
