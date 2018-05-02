// Written in the D programming language.
/**
Source: $(PHOBOSSRC std/experimental/logger/_nulllogger.d)
*/
module std.experimental.logger.alloclogger;

import std.experimental.logger.core;

private struct AllocOutRange(Alloc)
{
    /// The used allocator
    Alloc* alloc;
    /// the output
    char[]* str;

    static AllocOutRange!(Alloc) opCall(Alloc* alloc, char[]* str)
    {
        typeof(return) ret;
        ret.alloc = alloc;
        ret.str = str;
        return ret;
    }

    void put(const(char)[] msg)
    {
        import std.experimental.allocator : expandArray;
        import std.exception : enforce;
        size_t oldLen = str.length;
        enforce(expandArray(*(this.alloc), *(this.str), msg.length),
                "couldn't expand the array");
        (*this.str)[oldLen - 1 .. $ - 1] = msg;
    }
}

@safe unittest
{
    import std.experimental.allocator : theAllocator;
    import std.experimental.allocator.gc_allocator : GCAllocator;
    import std.range : isOutputRange;
    static assert(isOutputRange!(
                AllocOutRange!(typeof(GCAllocator.instance)), string)
            );
    static assert(isOutputRange!(
                AllocOutRange!(typeof(theAllocator)), string)
            );
}

/** The `AllocLogger` will save the log messages to the array `output`.
This array is allocated by the passed Allocator `alloc`.

Params:
    Alloc = The allocator to be used by `AllocLogger`
*/
class AllocLogger(Alloc) : Logger
{
    import std.concurrency : Tid;
    import std.format : formattedWrite;
    import std.datetime.systime : SysTime;

    /// The allocator used to alloc memory for log messages
    Alloc alloc;

    /// The OutputRange used by formattedWrite
    AllocOutRange!(Alloc) oRange;

    /// The output produced by `oRange`
    char[] output;

    /** The default constructor for the `AllocLogger`.

    Independent of the parameter this Logger will never log a message.

    Params:
      alloc = The Allocator to use.
      lv = The `LogLevel` for the `AllocLogger`. By default the `LogLevel`
      for `AllocLogger` is `LogLevel.all`.
    */
    this(Alloc alloc, const LogLevel lv = LogLevel.all)
    {
        import std.experimental.allocator : makeArray;
        super(lv);
        this.alloc = alloc;
        this.output = this.alloc.makeArray!char(1);
        this.oRange = AllocOutRange!(Alloc)(&this.alloc, &this.output);
        this.fatalHandler = delegate() {};
    }

    override void beginLogMsg(string file, int line, string funcName,
        string prettyFuncName, string moduleName, LogLevel logLevel,
        Tid threadId, SysTime timestamp, Logger logger) @safe
    {
        this.curMsgLogLevel = logLevel;
        if (isLoggingEnabled(this.curMsgLogLevel, this.logLevel, globalLogLevel))
        {
            import std.string : lastIndexOf;
            ptrdiff_t fnIdx = file.lastIndexOf('/') + 1;
            ptrdiff_t funIdx = funcName.lastIndexOf('.') + 1;

            ()@trusted
            {
                systimeToISOString(this.oRange, timestamp);
                formattedWrite(this.oRange, ":%s:%s:%u ", file[fnIdx .. $],
                    funcName[funIdx .. $], line);
            }();
        }
    }

    override void logMsgPart(scope const(char)[] msg) @safe
    {
        if (isLoggingEnabled(this.curMsgLogLevel, this.logLevel, globalLogLevel))
        {
            () @trusted
            {
                formattedWrite(this.oRange, msg);
            }();
        }
    }

    override void finishLogMsg() @safe
    {
        if (isLoggingEnabled(this.curMsgLogLevel, this.logLevel, globalLogLevel))
        {
            () @trusted
            {
                formattedWrite(this.oRange, "\n");
            }();
        }
    }
}

///
@system unittest
{
    import std.experimental.allocator.gc_allocator : GCAllocator;
    import std.experimental.allocator : theAllocator;
    import std.experimental.logger.core : LogLevel;
    import std.algorithm.searching : canFind;

    void test(Alloc)(auto ref Alloc alloc)
    {
        auto nl1 = new AllocLogger!(Alloc)(alloc, LogLevel.all);
        auto msgs = ["You will never read this.",
             "You will never read this, and it will not throw"
            ];
        foreach (msg; msgs)
        {
            nl1.info(msg);
        }
        foreach (msg; msgs)
        {
            assert(canFind(nl1.output, msg));
        }
    }

    test(GCAllocator.instance);
    test(theAllocator);
}
