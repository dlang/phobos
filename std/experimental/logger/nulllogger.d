module std.experimental.logger.nulllogger;

import std.experimental.logger.core;

/** The $(D NullLogger) will not process any log messages.

In case of a log message with $(D LogLevel.fatal) nothing will happen.
*/
class NullLogger : Logger
{
    /** The default constructor for the $(D NullLogger).

    Independent of the parameter this Logger will never log a message.

    Params:
      lv = The $(D LogLevel) for the $(D NullLogger). By default the $(D LogLevel)
      for $(D NullLogger) is $(D LogLevel.info).
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
