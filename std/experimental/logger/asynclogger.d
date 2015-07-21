module std.experimental.logger.asynclogger;

import std.experimental.logger.core;
import std.concurrency;
public import std.typecons : Unique, unique;

/** The $(D AsyncLogger) processes logs asynchronously by using another $(D Logger) implementation
as a backend. Every data logged to this $(D AsyncLogger) will be send to separate logging thread
in order to be logged there. It can help to improve logging performance for $(D log) caller,
for example by removing waiting for flushing logs to a file.
Example:
-------------
void main()
{
    import std.algorithm;
    import std.conv;
    import std.stdio;
    import std.datetime;
    import std.experimental.logger;

    auto fl = new FileLogger("defaultFileLogger.log", LogLevel.all);
    void logFileDefault()
    {
        fl.log("test message");
    }

    auto afl = new AsyncLogger(unique!FileLogger("asyncFileLogger.log", LogLevel.all));
    void logFileAsync()
    {
        afl.log("test message");
    }

    auto r = benchmark!(logFileDefault, logFileAsync)(100_000);
    writeln(map!(a => to!string(to!Duration(a)))(r[]));
}
-------------
*/
final class AsyncLogger : Logger
{
    import std.algorithm : move;
    /// Shuntdown message
    private struct ShutdownMsg {}

    private static void spawnedFunc(shared Logger ptr) @trusted
    {
        auto l = cast(Logger)(ptr);
        bool isRunning = true;
        while (isRunning)
        {
            receive(
                (LogEntryBase e)
                {
                    LogEntry tmp;
                    tmp.base = e;
                    tmp.threadId = ownerTid;
                    tmp.logger = l;
                    l.forwardMsg(tmp);
                },
                (ShutdownMsg msg) { isRunning = false; },
                (OwnerTerminated ex) { isRunning = false; },
                (Variant v) { throw new Error("unhandled message"); }
            );
        }
    }

    /** This constructor sets a LogLevel, takes $(D logger)'s ownership
    and starts a new logging thread that logs every
    entry asynchronously by using $(D logger).
    */
    this(T)(Unique!T logger, LogLevel lv = LogLevel.all) @trusted
        if (__traits(compiles, { Unique!Logger l = move(logger); }))
    {
        Unique!Logger l = move(logger);
        this(move(l), lv);
    }

    /// Ditto
    this(Unique!Logger logger, LogLevel lv = LogLevel.all) @trusted
    {
        super(lv);
        this.ownedLogger_ = move(logger);
        this.logger_ = cast(shared Logger)(this.ownedLogger_.get());
        this.tid_ = spawn(&spawnedFunc, this.logger_);
    }

    override void writeLogMsg(ref LogEntry payload) @trusted
    {
        LogEntryBase msg = payload;
        send(this.tid_, msg);
    }

    /// Stops logging thread by sending ShutdownMsg to it.
    ~this() @trusted
    {
        send(this.tid_, ShutdownMsg());
    }

    Tid tid_;
    Unique!Logger ownedLogger_;
    shared Logger logger_;
}

version (unittest)
{
    import core.sync.condition;
    class TestConditionalLogger : TestLogger
    {
        this(const LogLevel lv, Condition condition) @safe
        {
            super(lv);
            this.cond = condition;
        }

        override protected void writeLogMsg(ref LogEntry payload) @trusted
        {
            super.writeLogMsg(payload);
            synchronized(this.cond.mutex()) { this.cond.notify(); }
        }

        private Condition cond;
    }
}

unittest
{
    import std.algorithm : move;
    auto mtx = new Mutex;
    auto cond = new Condition(mtx);

    auto tl = unique!TestConditionalLogger(LogLevel.all, cond);
    auto al = new AsyncLogger(move(tl));
    scope(exit) destroy(al);
    string msg = "test_entry";
    al.log(msg); enum line = __LINE__;

    synchronized (cond.mutex()) { cond.wait(dur!"seconds"(1)); }

    auto logger = cast(TestConditionalLogger)al.ownedLogger_.get();
    assert(logger.msg == msg);
    assert(logger.line == line);
}
