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
 * Copyright: Copyright Sean Kelly 2009 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
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
    import core.atomic;
    import core.sync.barrier;
    import core.sync.condition;
    import core.sync.mutex;
    import core.sync.rwmutex;
    import core.sync.semaphore;
    import std.variant;
}
private
{
    import core.thread;
    import std.algorithm;
    import std.exception;
    import std.range;
    import std.range;
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

        auto convertsTo(T...)()
        {
            static if( T.length == 1 )
                return is( T[0] == Variant ) ||
                       data.convertsTo!(T);
            else
                return data.convertsTo!(Tuple!(T));
        }

        auto get(T...)()
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
            static assert( is( t1 == function ) || is( t1 == delegate ) );
            alias ParameterTypeTuple!(t1) a1;
            alias ReturnType!(t1) r1;

            static if( i < T.length - 1 && is( r1 == void ) )
            {
                static assert( a1.length != 1 || !is( a1[0] == Variant ),
                               "function with arguments " ~ a1.stringof ~
                               " occludes successive function" );

                foreach( t2; T[i+1 .. $] )
                {
                    static assert( is( t2 == function ) || is( t2 == delegate ) );
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
 *
 */
class MessageMismatch : Exception
{
    this( string msg = "Unexpected message type" )
    {
        super( msg );
    }
}


/**
 *
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
 *
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
 *
 */
class PriorityMessageException : Exception
{
    this( Variant vals )
    {
        super( "Priority message" );
        message = vals;
    }

    Variant message;
}


/**
 *
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


//////////////////////////////////////////////////////////////////////////////
// Thread ID
//////////////////////////////////////////////////////////////////////////////


/**
 * An opaque type used to represent a logical local process.
 */
struct Tid
{
    void send(T...)( T vals )
    {
        static assert( !hasLocalAliasing!(T),
                       "Aliases to mutable thread-local data not allowed." );
        _send( this, vals );
    }


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


//////////////////////////////////////////////////////////////////////////////
// Thread Creation
//////////////////////////////////////////////////////////////////////////////


/**
 * Executes the supplied function in a new context represented by Tid.  The
 * calling context is designated as the owner of the new context.  When the
 * owner context terminated an OwnerTerminated message will be sent to the
 * new context, causing an OwnerTerminated exception to be thrown on
 * receive().
 *
 * Params:
 *  fn   = The function to execute.
 *  args = Arguments to the function.
 *
 * Returns:
 *  A Tid representing the new context.
 */
Tid spawn(T...)( void function(T) fn, T args )
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
Tid spawnLinked(T...)( void function(T) fn, T args )
{
    static assert( !hasLocalAliasing!(T),
                   "Aliases to mutable thread-local data not allowed." );
    return _spawn( true, fn, args );
}


/*
 *
 */
private Tid _spawn(T...)( bool linked, void function(T) fn, T args )
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


//////////////////////////////////////////////////////////////////////////////
// Sending and Receiving Messages
//////////////////////////////////////////////////////////////////////////////


/**
 * Sends the supplied value to the context represented by tid.
 */
void send(T...)( Tid tid, T vals )
{
    static assert( !hasLocalAliasing!(T),
                   "Aliases to mutable thread-local data not allowed." );
    _send( tid, vals );
}


/**
 *
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
    tid.mbox.put( Message( type, vals ) );
}


/**
 *
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


private template receiveOnlyRet(T...)
{
    static if( T.length == 1 )
        alias T[0] receiveOnlyRet;
    else
        alias Tuple!(T) receiveOnlyRet;
}

/**
 *
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
                  throw new MessageMismatch;
              } );
    static if( T.length == 1 )
        return ret[0];
    else
        return ret;
}


/**
 * $(RED Scheduled for deprecation in January 2012. Please use the version
 *       which takes a $(CXREF time, Duration) instead.)
 */
bool receiveTimeout(T...)( long ms, T ops )
{
    return receiveTimeout( dur!"msecs"( ms ), ops );
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
                          receiveTimeout( 0, (Variant x) {} );
                          receiveTimeout( 0, (int x) {}, (Variant x) {} );
                      } ) );

    assert( !__traits( compiles,
                       {
                           receiveTimeout( 0, (Variant x) {}, (int x) {} );
                       } ) );

    assert( !__traits( compiles,
                       {
                           receiveTimeout( 0, (int x) {}, (int x) {} );
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
        final bool get(T...)( T vals )
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
                        if( onStandardMsg( Message( MsgType.standard, e ) ) )
                            return true;
                        throw e;
                    }
                }
                if( tid == owner )
                {
                    owner = Tid.init;
                    auto e = new OwnerTerminated( tid );
                    if( onStandardMsg( Message( MsgType.standard, e ) ) )
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
        bool empty()
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
