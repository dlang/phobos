/**
 * This is a low-level messaging API upon which more structured or restrictive
 * APIs may be built.  The general idea is that every messageable entity is
 * represented by a common handle type (called a Cid in this implementation),
 * which allows messages to be sent to in-process threads, on-host processes,
 * and foreign-host processes using the same interface.  This is an important
 * aspect of scalability because it allows the components of a program to be
 * spread across available resources with few to no changes to the actual
 * implementation.
 *
 * Right now, only in-process threads are supported and referenced by a more
 * specialized handle called a Tid.  It is effectively a subclass of Cid, with
 * additional features specific to in-process messaging.
 *
 * Synposis:
 *$(D_RUN_CODE
 *$(ARGS
 * ---
 * import std.stdio;
 * import std.concurrency;
 *
 * void spawnedFunc(Tid tid)
 * {
 *     // Receive a message from the owner thread.
 *     receive(
 *         (int i) { writeln("Received the number ", i);}
 *     );
 *
 *     // Send a message back to the owner thread
 *     // indicating success.
 *     send(tid, true);
 * }
 *
 * void main()
 * {
 *     // Start spawnedFunc in a new thread.
 *     auto tid = spawn(&spawnedFunc, thisTid);
 *
 *     // Send the number 42 to this new thread.
 *     send(tid, 42);
 *
 *     // Receive the result code.
 *     auto wasSuccessful = receiveOnly!(bool);
 *     assert(wasSuccessful);
 *     writeln("Successfully printed number.");
 * }
 * ---
 *), $(ARGS), $(ARGS), $(ARGS))
 *
 * Copyright: Copyright Sean Kelly 2009 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Source:    $(PHOBOSSRC std/_concurrency.d)
 */
/*          Copyright Sean Kelly 2009 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.concurrency;


public
{
    import std.variant;
}
private
{
    import core.thread;
    import core.sync.mutex;
    import core.sync.condition;
    import std.algorithm;
    import std.exception;
    import std.range;
    import std.string;
    import std.traits;
    import std.typecons;
    import std.typetuple;

    template hasLocalAliasing(T...)
    {
        static if( !T.length )
            enum hasLocalAliasing = false;
        else
            enum hasLocalAliasing = (std.traits.hasLocalAliasing!(T[0]) && !is(T[0] == Tid)) ||
                                    std.concurrency.hasLocalAliasing!(T[1 .. $]);
    }

    enum MsgType
    {
        standard,
        priority,
        linkDead,
    }

    struct Message
    {
        MsgType type;
        Variant data;

        this(T...)( MsgType t, T vals )
            if( T.length < 1 )
        {
            static assert( false, "messages must contain at least one item" );
        }

        this(T...)( MsgType t, T vals )
            if( T.length == 1 )
        {
            type = t;
            data = vals[0];
        }

        this(T...)( MsgType t, T vals )
            if( T.length > 1 )
        {
            type = t;
            data = Tuple!(T)( vals );
        }

        @property auto convertsTo(T...)()
        {
            static if( T.length == 1 )
                return is( T[0] == Variant ) ||
                       data.convertsTo!(T);
            else
                return data.convertsTo!(Tuple!(T));
        }

        @property auto get(T...)()
        {
            static if( T.length == 1 )
            {
                static if( is( T[0] == Variant ) )
                    return data;
                else
                    return data.get!(T);
            }
            else
            {
                return data.get!(Tuple!(T));
            }
        }

        auto map(Op)( Op op )
        {
            alias ParameterTypeTuple!(Op) Args;

            static if( Args.length == 1 )
            {
                static if( is( Args[0] == Variant ) )
                    return op( data );
                else
                    return op( data.get!(Args) );
            }
            else
            {
                return op( data.get!(Tuple!(Args)).expand );
            }
        }
    }

    void checkops(T...)( T ops )
    {
        foreach( i, t1; T )
        {
            static assert( isFunctionPointer!t1 || isDelegate!t1 );
            alias ParameterTypeTuple!(t1) a1;
            alias ReturnType!(t1) r1;

            static if( i < T.length - 1 && is( r1 == void ) )
            {
                static assert( a1.length != 1 || !is( a1[0] == Variant ),
                               "function with arguments " ~ a1.stringof ~
                               " occludes successive function" );

                foreach( t2; T[i+1 .. $] )
                {
                    static assert( isFunctionPointer!t2 || isDelegate!t2 );
                    alias ParameterTypeTuple!(t2) a2;

                    static assert( !is( a1 == a2 ),
                                   "function with arguments " ~ a1.stringof ~
                                   " occludes successive function" );
                }
            }
        }
    }

    MessageBox  mbox;
    bool[Tid]   links;
    Tid         owner;
}


shared static this()
{
    // NOTE: Normally, mbox is initialized by spawn() or thisTid().  This
    //       doesn't support the simple case of calling only receive() in main
    //       however.  To ensure that this works, initialize the main thread's
    //       mbox field here (as shared static ctors are run once on startup
    //       by the main thread).
    mbox = new MessageBox;
}


static ~this()
{
    if( mbox !is null )
    {
        mbox.close();
        auto me = thisTid;
        foreach( tid; links.keys )
            _send( MsgType.linkDead, tid, me );
        if( owner != Tid.init )
            _send( MsgType.linkDead, owner, me );
    }
}


//////////////////////////////////////////////////////////////////////////////
// Exceptions
//////////////////////////////////////////////////////////////////////////////


/**
 * Thrown on calls to $(D receiveOnly) if a message other than the type
 * the receiving thread expected is sent.
 */
class MessageMismatch : Exception
{
    this( string msg = "Unexpected message type" )
    {
        super( msg );
    }
}


/**
 * Thrown on calls to $(D receive) if the thread that spawned the receiving
 * thread has terminated and no more messages exist.
 */
class OwnerTerminated : Exception
{
    this( Tid t, string msg = "Owner terminated" )
    {
        super( msg );
        tid = t;
    }

    Tid tid;
}


/**
 * Thrown if a linked thread has terminated.
 */
class LinkTerminated : Exception
{
    this( Tid t, string msg = "Link terminated" )
    {
        super( msg );
        tid = t;
    }

    Tid tid;
}


/**
 * Thrown if a message was sent to a thread via
 * $(XREF concurrency, prioritySend) and the receiver does not have a handler
 * for a message of this type.
 */
class PriorityMessageException : Exception
{
    this( Variant vals )
    {
        super( "Priority message" );
        message = vals;
    }

    /**
     * The message that was sent.
     */
    Variant message;
}


/**
 * Thrown on mailbox crowding if the mailbox is configured with
 * $(D OnCrowding.throwException).
 */
class MailboxFull : Exception
{
    this( Tid t, string msg = "Mailbox full" )
    {
        super( msg );
        tid = t;
    }

    Tid tid;
}


/**
 * Thrown when a Tid is missing, e.g. when $(D ownerTid) doesn't
 * find an owner thread.
 */
class TidMissingException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}


//////////////////////////////////////////////////////////////////////////////
// Thread ID
//////////////////////////////////////////////////////////////////////////////


/**
 * An opaque type used to represent a logical local process.
 */
struct Tid
{
private:
    this( MessageBox m )
    {
        mbox = m;
    }


    MessageBox  mbox;
}


/**
 * Returns the caller's Tid.
 */
@property Tid thisTid()
{
    if( mbox )
        return Tid( mbox );
    mbox = new MessageBox;
    return Tid( mbox );
}

/**
 * Return the Tid of the thread which
 * spawned the caller's thread.
 *
 * Throws: A $(D TidMissingException) exception if
 * there is no owner thread.
 */
@property Tid ownerTid()
{
    enforceEx!TidMissingException(owner.mbox !is null, "Error: Thread has no owner thread.");
    return owner;
}

unittest
{
    static void fun()
    {
        string res = receiveOnly!string();
        assert(res == "Main calling");
        ownerTid.send("Child responding");
    }

    assertThrown!TidMissingException(ownerTid);
    auto child = spawn(&fun);
    child.send("Main calling");
    string res = receiveOnly!string();
    assert(res == "Child responding");
}

//////////////////////////////////////////////////////////////////////////////
// Thread Creation
//////////////////////////////////////////////////////////////////////////////

private template isSpawnable(F, T...)
{
    template isParamsImplicitlyConvertible(F1, F2, int i=0)
    {
        alias ParameterTypeTuple!F1 param1;
        alias ParameterTypeTuple!F2 param2;
        static if (param1.length != param2.length)
            enum isParamsImplicitlyConvertible = false;
        else static if (param1.length == i)
            enum isParamsImplicitlyConvertible = true;
        else static if (isImplicitlyConvertible!(param2[i], param1[i]))
            enum isParamsImplicitlyConvertible = isParamsImplicitlyConvertible!(F1, F2, i+1);
        else
            enum isParamsImplicitlyConvertible = false;
    }
    enum isSpawnable = isCallable!F
      && is(ReturnType!F == void)
      && isParamsImplicitlyConvertible!(F, void function(T))
      && ( isFunctionPointer!F
        || !hasUnsharedAliasing!F);
}

/**
 * Executes the supplied function in a new context represented by $(D Tid).  The
 * calling context is designated as the owner of the new context.  When the
 * owner context terminated an $(D OwnerTerminated) message will be sent to the
 * new context, causing an $(D OwnerTerminated) exception to be thrown on
 * $(D receive()).
 *
 * Params:
 *  fn   = The function to execute.
 *  args = Arguments to the function.
 *
 * Returns:
 *  A Tid representing the new context.
 *
 * Notes:
 *  $(D args) must not have unshared aliasing.  In other words, all arguments
 *  to $(D fn) must either be $(D shared) or $(D immutable) or have no
 *  pointer indirection.  This is necessary for enforcing isolation among
 *  threads.
 *
 * Example:
 *$(D_RUN_CODE
 *$(ARGS
 * ---
 * import std.stdio, std.concurrency;
 *
 * void f1(string str)
 * {
 *     writeln(str);
 * }
 *
 * void f2(char[] str)
 * {
 *     writeln(str);
 * }
 *
 * void main()
 * {
 *     auto str = "Hello, world";
 *
 *     // Works:  string is immutable.
 *     auto tid1 = spawn(&f1, str);
 *
 *     // Fails:  char[] has mutable aliasing.
 *     auto tid2 = spawn(&f2, str.dup);
 * }
 * ---
 *), $(ARGS), $(ARGS), $(ARGS))
 */
Tid spawn(F, T...)( F fn, T args )
    if ( isSpawnable!(F, T) )
{
    static assert( !hasLocalAliasing!(T),
                   "Aliases to mutable thread-local data not allowed." );
    return _spawn( false, fn, args );
}


/**
 * Executes the supplied function in a new context represented by Tid.  This
 * new context is linked to the calling context so that if either it or the
 * calling context terminates a LinkTerminated message will be sent to the
 * other, causing a LinkTerminated exception to be thrown on receive().  The
 * owner relationship from spawn() is preserved as well, so if the link
 * between threads is broken, owner termination will still result in an
 * OwnerTerminated exception to be thrown on receive().
 *
 * Params:
 *  fn   = The function to execute.
 *  args = Arguments to the function.
 *
 * Returns:
 *  A Tid representing the new context.
 */
Tid spawnLinked(F, T...)( F fn, T args )
    if ( isSpawnable!(F, T) )
{
    static assert( !hasLocalAliasing!(T),
                   "Aliases to mutable thread-local data not allowed." );
    return _spawn( true, fn, args );
}


/*
 *
 */
private Tid _spawn(F, T...)( bool linked, F fn, T args )
    if ( isSpawnable!(F, T) )
{
    // TODO: MessageList and &exec should be shared.
    auto spawnTid = Tid( new MessageBox );
    auto ownerTid = thisTid;

    void exec()
    {
        mbox  = spawnTid.mbox;
        owner = ownerTid;
        fn( args );
    }

    // TODO: MessageList and &exec should be shared.
    auto t = new Thread( &exec ); t.start();
    links[spawnTid] = linked;
    return spawnTid;
}

unittest
{
    void function()                                fn1;
    void function(int)                             fn2;
    static assert( __traits(compiles, spawn(fn1)));
    static assert( __traits(compiles, spawn(fn2, 2)));
    static assert(!__traits(compiles, spawn(fn1, 1)));
    static assert(!__traits(compiles, spawn(fn2)));

    void delegate(int) shared                      dg1;
    shared(void delegate(int))                     dg2;
    shared(void delegate(long) shared)             dg3;
    shared(void delegate(real, int , long) shared) dg4;
    void delegate(int) immutable                   dg5;
    void delegate(int)                             dg6;
    static assert( __traits(compiles, spawn(dg1, 1)));
    static assert( __traits(compiles, spawn(dg2, 2)));
    static assert( __traits(compiles, spawn(dg3, 3)));
    static assert( __traits(compiles, spawn(dg4, 4, 4, 4)));
    static assert( __traits(compiles, spawn(dg5, 5)));
    static assert(!__traits(compiles, spawn(dg6, 6)));

    auto callable1  = new class{ void opCall(int) shared {} };
    auto callable2  = cast(shared)new class{ void opCall(int) shared {} };
    auto callable3  = new class{ void opCall(int) immutable {} };
    auto callable4  = cast(immutable)new class{ void opCall(int) immutable {} };
    auto callable5  = new class{ void opCall(int) {} };
    auto callable6  = cast(shared)new class{ void opCall(int) immutable {} };
    auto callable7  = cast(immutable)new class{ void opCall(int) shared {} };
    auto callable8  = cast(shared)new class{ void opCall(int) const shared {} };
    auto callable9  = cast(const shared)new class{ void opCall(int) shared {} };
    auto callable10 = cast(const shared)new class{ void opCall(int) const shared {} };
    auto callable11 = cast(immutable)new class{ void opCall(int) const shared {} };
    static assert(!__traits(compiles, spawn(callable1,  1)));
    static assert( __traits(compiles, spawn(callable2,  2)));
    static assert(!__traits(compiles, spawn(callable3,  3)));
    static assert( __traits(compiles, spawn(callable4,  4)));
    static assert(!__traits(compiles, spawn(callable5,  5)));
    static assert(!__traits(compiles, spawn(callable6,  6)));
    static assert(!__traits(compiles, spawn(callable7,  7)));
    static assert( __traits(compiles, spawn(callable8,  8)));
    static assert(!__traits(compiles, spawn(callable9,  9)));
    static assert( __traits(compiles, spawn(callable10, 10)));
    static assert( __traits(compiles, spawn(callable11, 11)));
}


//////////////////////////////////////////////////////////////////////////////
// Sending and Receiving Messages
//////////////////////////////////////////////////////////////////////////////


/**
 * Sends the supplied value to the context represented by tid.  As with
 * $(XREF concurrency, spawn), $(D T) must not have unshared aliasing.
 */
void send(T...)( Tid tid, T vals )
{
    static assert( !hasLocalAliasing!(T),
                   "Aliases to mutable thread-local data not allowed." );
    _send( tid, vals );
}


/**
 * Send a message to $(D tid) but place it at the front of $(D tid)'s message
 * queue instead of at the back.  This function is typically used for
 * out-of-band communication, to signal exceptional conditions, etc.
 */
void prioritySend(T...)( Tid tid, T vals )
{
    static assert( !hasLocalAliasing!(T),
                   "Aliases to mutable thread-local data not allowed." );
    _send( MsgType.priority, tid, vals );
}


/*
 * ditto
 */
private void _send(T...)( Tid tid, T vals )
{
    _send( MsgType.standard, tid, vals );
}


/*
 * Implementation of send.  This allows parameter checking to be different for
 * both Tid.send() and .send().
 */
private void _send(T...)( MsgType type, Tid tid, T vals )
{
    auto msg = Message( type, vals );
    tid.mbox.put( msg );
}


/**
 * Receive a message from another thread, or block if no messages of the
 * specified types are available.  This function works by pattern matching
 * a message against a set of delegates and executing the first match found.
 *
 * If a delegate that accepts a $(XREF variant, Variant) is included as
 * the last argument to $(D receive), it will match any message that was not
 * matched by an earlier delegate.  If more than one argument is sent,
 * the $(D Variant) will contain a $(XREF typecons, Tuple) of all values
 * sent.
 *
 * Example:
 *$(D_RUN_CODE
 *$(ARGS
 * ---
 * import std.stdio;
 * import std.variant;
 * import std.concurrency;
 *
 * void spawnedFunction()
 * {
 *     receive(
 *         (int i) { writeln("Received an int."); },
 *         (float f) { writeln("Received a float."); },
 *         (Variant v) { writeln("Received some other type."); }
 *     );
 * }
 *
 * void main()
 * {
 *      auto tid = spawn(&spawnedFunction);
 *      send(tid, 42);
 * }
 * ---
 *), $(ARGS), $(ARGS), $(ARGS))
 */
void receive(T...)( T ops )
{
    checkops( ops );
    mbox.get( ops );
}


unittest
{
    assert( __traits( compiles,
                      {
                          receive( (Variant x) {} );
                          receive( (int x) {}, (Variant x) {} );
                      } ) );

    assert( !__traits( compiles,
                       {
                           receive( (Variant x) {}, (int x) {} );
                       } ) );

    assert( !__traits( compiles,
                       {
                           receive( (int x) {}, (int x) {} );
                       } ) );
}

// Make sure receive() works with free functions as well.
version (unittest)
{
    private void receiveFunction(int x) {}
}
unittest
{
    assert( __traits( compiles,
                      {
                          receive( &receiveFunction );
                          receive( &receiveFunction, (Variant x) {} );
                      } ) );
}


private template receiveOnlyRet(T...)
{
    static if( T.length == 1 )
        alias T[0] receiveOnlyRet;
    else
        alias Tuple!(T) receiveOnlyRet;
}

/**
 * Receives only messages with arguments of types $(D T).
 *
 * Throws:  $(D MessageMismatch) if a message of types other than $(D T)
 *          is received.
 *
 * Returns: The received message.  If $(D T.length) is greater than one,
 *          the message will be packed into a $(XREF typecons, Tuple).
 *
 * Example:
 *$(D_RUN_CODE
 *$(ARGS
 * ---
 * import std.concurrency;

 * void spawnedFunc()
 * {
 *     auto msg = receiveOnly!(int, string)();
 *     assert(msg[0] == 42);
 *     assert(msg[1] == "42");
 * }
 *
 * void main()
 * {
 *     auto tid = spawn(&spawnedFunc);
 *     send(tid, 42, "42");
 * }
 * ---
 *), $(ARGS), $(ARGS), $(ARGS))
 */
receiveOnlyRet!(T) receiveOnly(T...)()
{
    Tuple!(T) ret;

    mbox.get( ( T val )
              {
                  static if( T.length )
                      ret.field = val;
              },
              ( LinkTerminated e )
              {
                  throw e;
              },
              ( OwnerTerminated e )
              {
                  throw e;
              },
              ( Variant val )
              {
                  static if (T.length > 1)
                      string exp = T.stringof;
                  else
                      string exp = T[0].stringof;

                  throw new MessageMismatch(
                      format("Unexpected message type: expected '%s', got '%s'",
                          exp, val.type.toString()));
              } );
    static if( T.length == 1 )
        return ret[0];
    else
        return ret;
}

unittest
{
    static void t1(Tid mainTid)
    {
        try
        {
            receiveOnly!string();
            mainTid.send("");
        }
        catch (Throwable th)
        {
            mainTid.send(th.msg);
        }
    }

    auto tid = spawn(&t1, thisTid);
    tid.send(1);
    string result = receiveOnly!string();
    assert(result == "Unexpected message type: expected 'string', got 'int'");
}

/++
    Same as $(D receive) except that rather than wait forever for a message,
    it waits until either it receives a message or the given
    $(CXREF time, Duration) has passed. It returns $(D true) if it received a
    message and $(D false) if it timed out waiting for one.
  +/
bool receiveTimeout(T...)( Duration duration, T ops )
{
    checkops( ops );
    return mbox.get( duration, ops );
}

unittest
{
    assert( __traits( compiles,
                      {
                          receiveTimeout( dur!"msecs"(0), (Variant x) {} );
                          receiveTimeout( dur!"msecs"(0), (int x) {}, (Variant x) {} );
                      } ) );

    assert( !__traits( compiles,
                       {
                           receiveTimeout( dur!"msecs"(0), (Variant x) {}, (int x) {} );
                       } ) );

    assert( !__traits( compiles,
                       {
                           receiveTimeout( dur!"msecs"(0), (int x) {}, (int x) {} );
                       } ) );

    assert( __traits( compiles,
                      {
                          receiveTimeout( dur!"msecs"(10), (int x) {}, (Variant x) {} );
                      } ) );
}


//////////////////////////////////////////////////////////////////////////////
// MessageBox Limits
//////////////////////////////////////////////////////////////////////////////


/**
 * These behaviors may be specified when a mailbox is full.
 */
enum OnCrowding
{
    block,          /// Wait until room is available.
    throwException, /// Throw a MailboxFull exception.
    ignore          /// Abort the send and return.
}


private
{
    bool onCrowdingBlock( Tid tid )
    {
        return true;
    }


    bool onCrowdingThrow( Tid tid )
    {
        throw new MailboxFull( tid );
    }


    bool onCrowdingIgnore( Tid tid )
    {
        return false;
    }
}


/**
 * Sets a limit on the maximum number of user messages allowed in the mailbox.
 * If this limit is reached, the caller attempting to add a new message will
 * execute the behavior specified by doThis.  If messages is zero, the mailbox
 * is unbounded.
 *
 * Params:
 *  tid      = The Tid of the thread for which this limit should be set.
 *  messages = The maximum number of messages or zero if no limit.
 *  doThis   = The behavior executed when a message is sent to a full
 *             mailbox.
 */
void setMaxMailboxSize( Tid tid, size_t messages, OnCrowding doThis )
{
    final switch( doThis )
    {
    case OnCrowding.block:
        return tid.mbox.setMaxMsgs( messages, &onCrowdingBlock );
    case OnCrowding.throwException:
        return tid.mbox.setMaxMsgs( messages, &onCrowdingThrow );
    case OnCrowding.ignore:
        return tid.mbox.setMaxMsgs( messages, &onCrowdingIgnore );
    }
}


/**
 * Sets a limit on the maximum number of user messages allowed in the mailbox.
 * If this limit is reached, the caller attempting to add a new message will
 * execute onCrowdingDoThis.  If messages is zero, the mailbox is unbounded.
 *
 * Params:
 *  tid      = The Tid of the thread for which this limit should be set.
 *  messages = The maximum number of messages or zero if no limit.
 *  onCrowdingDoThis = The routine called when a message is sent to a full
 *                     mailbox.
 */
void setMaxMailboxSize( Tid tid, size_t messages, bool function(Tid) onCrowdingDoThis )
{
    tid.mbox.setMaxMsgs( messages, onCrowdingDoThis );
}


//////////////////////////////////////////////////////////////////////////////
// Name Registration
//////////////////////////////////////////////////////////////////////////////


private
{
    __gshared Tid[string]   tidByName;
    __gshared string[][Tid] namesByTid;
    __gshared Mutex         registryLock;
}


shared static this()
{
    registryLock = new Mutex;
}


static ~this()
{
    auto me = thisTid;

    synchronized( registryLock )
    {
        if( auto allNames = me in namesByTid )
        {
            foreach( name; *allNames )
                tidByName.remove( name );
            namesByTid.remove( me );
        }
    }
}


/**
 * Associates name with tid in a process-local map.  When the thread
 * represented by tid termiantes, any names associated with it will be
 * automatically unregistered.
 *
 * Params:
 *  name = The name to associate with tid.
 *  tid  = The tid register by name.
 *
 * Returns:
 *  true if the name is available and tid is not known to represent a
 *  defunct thread.
 */
bool register( string name, Tid tid )
{
    synchronized( registryLock )
    {
        if( name in tidByName )
            return false;
        if( tid.mbox.isClosed )
            return false;
        namesByTid[tid] ~= name;
        tidByName[name] = tid;
        return true;
    }
}


/**
 * Removes the registered name associated with a tid.
 *
 * Params:
 *  name = The name to unregister.
 *
 * Returns:
 *  true if the name is registered, false if not.
 */
bool unregister( string name )
{
    synchronized( registryLock )
    {
        if( auto tid = name in tidByName )
        {
            auto allNames = *tid in namesByTid;
            auto pos      = countUntil( *allNames, name );
            remove!(SwapStrategy.unstable)( *allNames, pos );
            tidByName.remove( name );
            return true;
        }
        return false;
    }
}


/**
 * Gets the Tid associated with name.
 *
 * Params:
 *  name = The name to locate within the registry.
 *
 * Returns:
 *  The associated Tid or Tid.init if name is not registered.
 */
Tid locate( string name )
{
    synchronized( registryLock )
    {
        if( auto tid = name in tidByName )
            return *tid;
        return Tid.init;
    }
}


//////////////////////////////////////////////////////////////////////////////
// MessageBox Implementation
//////////////////////////////////////////////////////////////////////////////


private
{
    /*
     * A MessageBox is a message queue for one thread.  Other threads may send
     * messages to this owner by calling put(), and the owner receives them by
     * calling get().  The put() call is therefore effectively shared and the
     * get() call is effectively local.  setMaxMsgs may be used by any thread
     * to limit the size of the message queue.
     */
    class MessageBox
    {
        this()
        {
            m_lock      = new Mutex;
            m_putMsg    = new Condition( m_lock );
            m_notFull   = new Condition( m_lock );
            m_closed    = false;
        }


        /*
         *
         */
        final @property bool isClosed() const
        {
            synchronized( m_lock )
            {
                return m_closed;
            }
        }


        /*
         * Sets a limit on the maximum number of user messages allowed in the
         * mailbox.  If this limit is reached, the caller attempting to add
         * a new message will execute call.  If num is zero, there is no limit
         * on the message queue.
         *
         * Params:
         *  num  = The maximum size of the queue or zero if the queue is
         *         unbounded.
         *  call = The routine to call when the queue is full.
         */
        final void setMaxMsgs( size_t num, bool function(Tid) call )
        {
            synchronized( m_lock )
            {
                m_maxMsgs   = num;
                m_onMaxMsgs = call;
            }
        }


        /*
         * If maxMsgs is not set, the message is added to the queue and the
         * owner is notified.  If the queue is full, the message will still be
         * accepted if it is a control message, otherwise onCrowdingDoThis is
         * called.  If the routine returns true, this call will block until
         * the owner has made space available in the queue.  If it returns
         * false, this call will abort.
         *
         * Params:
         *  msg = The message to put in the queue.
         *
         * Throws:
         *  An exception if the queue is full and onCrowdingDoThis throws.
         */
        final void put( ref Message msg )
        {
            synchronized( m_lock )
            {
                // TODO: Generate an error here if m_closed is true, or maybe
                //       put a message in the caller's queue?
                if( !m_closed )
                {
                    while( true )
                    {
                        if( isPriorityMsg( msg ) )
                        {
                            m_sharedPty.put( msg );
                            m_putMsg.notify();
                            return;
                        }
                        if( !mboxFull() || isControlMsg( msg ) )
                        {
                            m_sharedBox.put( msg );
                            m_putMsg.notify();
                            return;
                        }
                        if( m_onMaxMsgs !is null && !m_onMaxMsgs( thisTid ) )
                        {
                            return;
                        }
                        m_putQueue++;
                        m_notFull.wait();
                        m_putQueue--;
                    }
                }
            }
        }


        /*
         * Matches ops against each message in turn until a match is found.
         *
         * Params:
         *  ops = The operations to match.  Each may return a bool to indicate
         *        whether a message with a matching type is truly a match.
         *
         * Returns:
         *  true if a message was retrieved and false if not (such as if a
         *  timeout occurred).
         *
         * Throws:
         *  LinkTerminated if a linked thread terminated, or OwnerTerminated
         * if the owner thread terminates and no existing messages match the
         * supplied ops.
         */
        final bool get(T...)( scope T vals )
        {
            static assert( T.length );

            static if( isImplicitlyConvertible!(T[0], Duration) )
            {
                alias TypeTuple!(T[1 .. $]) Ops;
                alias vals[1 .. $] ops;
                assert( vals[0] >= dur!"msecs"(0) );
                enum timedWait = true;
                Duration period = vals[0];
            }
            else
            {
                alias TypeTuple!(T) Ops;
                alias vals[0 .. $] ops;
                enum timedWait = false;
            }

            bool onStandardMsg( ref Message msg )
            {
                foreach( i, t; Ops )
                {
                    alias ParameterTypeTuple!(t) Args;
                    auto op = ops[i];

                    if( msg.convertsTo!(Args) )
                    {
                        static if( is( ReturnType!(t) == bool ) )
                        {
                            return msg.map( op );
                        }
                        else
                        {
                            msg.map( op );
                            return true;
                        }
                    }
                }
                return false;
            }

            bool onLinkDeadMsg( ref Message msg )
            {
                assert( msg.convertsTo!(Tid) );
                auto tid = msg.get!(Tid);

                if( bool* depends = (tid in links) )
                {
                    links.remove( tid );
                    // Give the owner relationship precedence.
                    if( *depends && tid != owner )
                    {
                        auto e = new LinkTerminated( tid );
                        auto m = Message( MsgType.standard, e );
                        if( onStandardMsg( m ) )
                            return true;
                        throw e;
                    }
                }
                if( tid == owner )
                {
                    owner = Tid.init;
                    auto e = new OwnerTerminated( tid );
                    auto m = Message( MsgType.standard, e );
                    if( onStandardMsg( m ) )
                        return true;
                    throw e;
                }
                return false;
            }

            bool onControlMsg( ref Message msg )
            {
                switch( msg.type )
                {
                case MsgType.linkDead:
                    return onLinkDeadMsg( msg );
                default:
                    return false;
                }
            }

            bool scan( ref ListT list )
            {
                for( auto range = list[]; !range.empty; )
                {
                    // Only the message handler will throw, so if this occurs
                    // we can be certain that the message was handled.
                    scope(failure) list.removeAt( range );

                    if( isControlMsg( range.front ) )
                    {
                        if( onControlMsg( range.front ) )
                        {
                            // Although the linkDead message is a control message,
                            // it can be handled by the user.  Since the linkDead
                            // message throws if not handled, if we get here then
                            // it has been handled and we can return from receive.
                            // This is a weird special case that will have to be
                            // handled in a more general way if more are added.
                            if( !isLinkDeadMsg( range.front ) )
                            {
                                list.removeAt( range );
                                continue;
                            }
                            list.removeAt( range );
                            return true;
                        }
                        range.popFront();
                        continue;
                    }
                    else
                    {
                        if( onStandardMsg( range.front ) )
                        {
                            list.removeAt( range );
                            return true;
                        }
                        range.popFront();
                        continue;
                    }
                }
                return false;
            }


            bool pty( ref ListT list )
            {
                if( !list.empty )
                {
                    auto range = list[];

                    if( onStandardMsg( range.front ) )
                    {
                        list.removeAt( range );
                        return true;
                    }
                    if( range.front.convertsTo!(Throwable) )
                        throw range.front.get!(Throwable);
                    else if( range.front.convertsTo!(shared(Throwable)) )
                        throw range.front.get!(shared(Throwable));
                    else throw new PriorityMessageException( range.front.data );
                }
                return false;
            }

            while( true )
            {
                ListT arrived;

                if( pty( m_localPty ) ||
                    scan( m_localBox ) )
                {
                    return true;
                }
                synchronized( m_lock )
                {
                    updateMsgCount();
                    while( m_sharedPty.empty && m_sharedBox.empty )
                    {
                        // NOTE: We're notifying all waiters here instead of just
                        //       a few because the onCrowding behavior may have
                        //       changed and we don't want to block sender threads
                        //       unnecessarily if the new behavior is not to block.
                        //       This will admittedly result in spurious wakeups
                        //       in other situations, but what can you do?
                        if( m_putQueue && !mboxFull() )
                            m_notFull.notifyAll();
                        static if( timedWait )
                        {
                            if( !m_putMsg.wait( period ) )
                                return false;
                        }
                        else
                        {
                            m_putMsg.wait();
                        }
                    }
                    m_localPty.put( m_sharedPty );
                    arrived.put( m_sharedBox );
                }
                if( m_localPty.empty )
                {
                    scope(exit) m_localBox.put( arrived );
                    if( scan( arrived ) )
                        return true;
                    else continue;
                }
                m_localBox.put( arrived );
                pty( m_localPty );
                return true;
            }
        }


        /*
         * Called on thread termination.  This routine processes any remaining
         * control messages, clears out message queues, and sets a flag to
         * reject any future messages.
         */
        final void close()
        {
            void onLinkDeadMsg( ref Message msg )
            {
                assert( msg.convertsTo!(Tid) );
                auto tid = msg.get!(Tid);

                links.remove( tid );
                if( tid == owner )
                    owner = Tid.init;
            }

            void sweep( ref ListT list )
            {
                for( auto range = list[]; !range.empty; range.popFront() )
                {
                    if( range.front.type == MsgType.linkDead )
                        onLinkDeadMsg( range.front );
                }
            }

            ListT arrived;

            sweep( m_localBox );
            synchronized( m_lock )
            {
                arrived.put( m_sharedBox );
                m_closed = true;
            }
            m_localBox.clear();
            sweep( arrived );
        }


    private:
        //////////////////////////////////////////////////////////////////////
        // Routines involving shared data, m_lock must be held.
        //////////////////////////////////////////////////////////////////////


        bool mboxFull()
        {
            return m_maxMsgs &&
                   m_maxMsgs <= m_localMsgs + m_sharedBox.length;
        }


        void updateMsgCount()
        {
            m_localMsgs = m_localBox.length;
        }


    private:
        //////////////////////////////////////////////////////////////////////
        // Routines involving local data only, no lock needed.
        //////////////////////////////////////////////////////////////////////


        pure final bool isControlMsg( ref Message msg )
        {
            return msg.type != MsgType.standard &&
                   msg.type != MsgType.priority;
        }


        pure final bool isPriorityMsg( ref Message msg )
        {
            return msg.type == MsgType.priority;
        }


        pure final bool isLinkDeadMsg( ref Message msg )
        {
            return msg.type == MsgType.linkDead;
        }


    private:
        //////////////////////////////////////////////////////////////////////
        // Type declarations.
        //////////////////////////////////////////////////////////////////////


        alias bool function(Tid) OnMaxFn;
        alias List!(Message)     ListT;

    private:
        //////////////////////////////////////////////////////////////////////
        // Local data, no lock needed.
        //////////////////////////////////////////////////////////////////////


        ListT       m_localBox;
        ListT       m_localPty;


    private:
        //////////////////////////////////////////////////////////////////////
        // Shared data, m_lock must be held on access.
        //////////////////////////////////////////////////////////////////////


        Mutex       m_lock;
        Condition   m_putMsg;
        Condition   m_notFull;
        size_t      m_putQueue;
        ListT       m_sharedBox;
        ListT       m_sharedPty;
        OnMaxFn     m_onMaxMsgs;
        size_t      m_localMsgs;
        size_t      m_maxMsgs;
        bool        m_closed;
    }


    /*
     *
     */
    struct List(T)
    {
        struct Range
        {
            @property bool empty() const
            {
                return !m_prev.next;
            }

            @property ref T front()
            {
                enforce( m_prev.next );
                return m_prev.next.val;
            }

            @property void front( T val )
            {
                enforce( m_prev.next );
                m_prev.next.val = val;
            }

            void popFront()
            {
                enforce( m_prev.next );
                m_prev = m_prev.next;
            }

            //T moveFront()
            //{
            //    enforce( m_prev.next );
            //    return move( m_prev.next.val );
            //}

            private this( Node* p )
            {
                m_prev = p;
            }

            private Node* m_prev;
        }


        /*
         *
         */
        void put( T val )
        {
            put( new Node( val ) );
        }


        /*
         *
         */
        void put( ref List!(T) rhs )
        {
            if( !rhs.empty )
            {
                put( rhs.m_first );
                while( m_last.next !is null )
                {
                    m_last = m_last.next;
                    m_count++;
                }
                rhs.m_first = null;
                rhs.m_last  = null;
                rhs.m_count = 0;
            }
        }


        /*
         *
         */
        Range opSlice()
        {
            return Range( cast(Node*) &m_first );
        }


        /*
         *
         */
        void removeAt( Range r )
        {
            assert( m_count );
            Node* n = r.m_prev;
            enforce( n && n.next );

            if( m_last is m_first )
                m_last = null;
            else if( m_last is n.next )
                m_last = n;
            Node* todelete = n.next;
            n.next = n.next.next;
            //delete todelete;
            m_count--;
        }


        /*
         *
         */
        @property size_t length()
        {
            return m_count;
        }


        /*
         *
         */
        void clear()
        {
            m_first = m_last = null;
            m_count = 0;
        }


        /*
         *
         */
        @property bool empty()
        {
            return m_first is null;
        }


    private:
        struct Node
        {
            Node*   next;
            T       val;

            this( T v )
            {
                val = v;
            }
        }


        /*
         *
         */
        void put( Node* n )
        {
            m_count++;
            if( !empty )
            {
                m_last.next = n;
                m_last = n;
                return;
            }
            m_first = n;
            m_last = n;
        }


        Node*   m_first;
        Node*   m_last;
        size_t  m_count;
    }
}


version( unittest )
{
    import std.stdio;

    void testfn( Tid tid )
    {
        receive( (float val) { assert(0); },
                 (int val, int val2)
                 {
                     assert( val == 42 && val2 == 86 );
                 } );
        receive( (Tuple!(int, int) val)
                 {
                     assert( val[0] == 42 &&
                             val[1] == 86 );
                 } );
        receive( (Variant val) {} );
        receive( (string val)
                 {
                     if( "the quick brown fox" != val )
                         return false;
                     return true;
                 },
                 (string val)
                 {
                     assert( false );
                 } );
        prioritySend( tid, "done" );
    }

    void runTest( Tid tid )
    {
        send( tid, 42, 86 );
        send( tid, tuple(42, 86) );
        send( tid, "hello", "there" );
        send( tid, "the quick brown fox" );
        receive( (string val) { assert(val == "done"); } );
    }


    unittest
    {
        auto tid = spawn( &testfn, thisTid );
        runTest( tid );

        // Run the test again with a limited mailbox size.
        tid = spawn( &testfn, thisTid );
        setMaxMailboxSize( tid, 2, OnCrowding.block );
        runTest( tid );
    }
}
