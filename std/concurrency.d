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
 *
 *          Copyright Sean Kelly 2009 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.concurrency;


public
{
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
    //import core.sync.condition;
    //import core.sync.mutex;
    import std.algorithm;
    import std.exception;
    import std.range;
    import std.stdio;
    import std.range;
    import std.traits;
    import std.typecons;
    import std.typetuple;

    template isTuple(T)
    {
       enum isTuple = __traits(compiles,
                               { void f(X...)(Tuple!(X) t) {};
                                 f(T.init); });
    }

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
        {
            type = t;
            data = Tuple!(T)( vals );
        }

        this(U=void, T...)( MsgType t, Tuple!(T) vals )
        {
            type = t;
            data = vals;
        }
    }

    struct Priority
    {
        Variant   data;
        Throwable fail;

        this(T...)( T vals )
        {
            data = Tuple!(T)( vals );
            static if( T.length == 1 && is( T[0] : Throwable ) )
            {
                fail = vals[0];
            }
            else
            {
                fail = new PriorityMessageException!(T)( vals );
            }
        }
    }

    MessageBox  mbox;
    bool[Tid]   links;
    Tid         owner;
}


static this()
{
    mbox = new MessageBox;
}


static ~this()
{
    mbox.close();
    auto me = thisTid;
    foreach( tid; links.keys )
        _send( MsgType.linkDead, tid, me );
    if( owner != Tid.init )
        _send( MsgType.linkDead, owner, me );
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
class PriorityMessageException(T...) : Exception
{
    this( T vals )
    {
        super( "Priority message" );
        static if( T.length == 1 )
             message       = vals;
        else message.field = vals;
    }

    static if( T.length == 1 )
         T         message;
    else Tuple!(T) message;
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
    // TODO: MessageList and &exec should be shared.
    return spawn_( false, fn, args );
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
    return spawn_( true, fn, args );
}


/*
 *
 */
private Tid spawn_(T...)( bool linked, void function(T) fn, T args )
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
    _send( MsgType.priority, tid, Priority( vals ) );
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
    mbox.get( ops );
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
              ( Variant val )
              {
                  throw new MessageMismatch;
              } );
    static if( T.length == 1 )
        return ret.field[0];
    else
        return ret;
}


/**
 *
 */
bool receiveTimeout(T...)( long ms, T ops )
{
    static enum long TICKS_PER_MILLI = 10_000;
    return mbox.get( ms * TICKS_PER_MILLI, ops );
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
        final void put( Message msg )
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

            static if( isImplicitlyConvertible!(T[0], long) )
            {
                alias TypeTuple!(T[1 .. $]) Ops;
                alias vals[1 .. $] ops;
                assert( vals[0] >= 0 );
                enum timedWait = true;
                long period = vals[0];
            }
            else
            {
                alias TypeTuple!(T) Ops;
                alias vals[0 .. $] ops;
                enum timedWait = false;
            }

            bool onStandardMsg( Message msg )
            {
                Variant data = msg.data;

                foreach( i, t; Ops )
                {
                    alias ParameterTypeTuple!(t) Args;
                    alias Tuple!(Args) Wrap;
                    auto op = ops[i];

                    static if( is( Wrap == Tuple!(Variant) ) )
                    {
                        static if( is( ReturnType!(t) == bool ) )
                        {
                            return op( data );
                        }
                        else
                        {
                            op( data );
                            return true;
                        }
                    }
                    else static if( Args.length == 1 && isTuple!(Args) )
                    {
                        static if( is( ReturnType!(t) == bool ) )
                        {
                            return op( data.get!(Args) );
                        }
                        else
                        {
                            op( data.get!(Args) );
                            return true;
                        }
                    }
                    else
                    {
                        if( data.convertsTo!(Wrap) )
                        {
                            static if( is( ReturnType!(t) == bool ) )
                            {
                                return op( data.get!(Wrap).expand );
                            }
                            else
                            {
                                op( data.get!(Wrap).expand );
                                return true;
                            }
                        }
                    }
                }
                return false;
            }

            bool ownerDead = false;

            bool onLinkDeadMsg( Variant data )
            {
                alias Tuple!(Tid) Wrap;

                static if( Variant.allowed!(Wrap) )
                {
                    assert( data.convertsTo!(Wrap) );
                    auto wrap = data.get!(Wrap);
                }
                else
                {
                    assert( data.convertsTo!(Wrap*) );
                    auto wrap = data.get!(Wrap*);
                }
                if( bool* depends = (wrap.field[0] in links) )
                {
                    links.remove( wrap.field[0] );
                    if( *depends )
                    {
                        if( wrap.field[0] == owner )
                            owner = Tid.init;
                        throw new LinkTerminated( wrap.field[0] );
                    }
                    return false;
                }
                if( wrap.field[0] == owner )
                {
                    ownerDead = true;
                    return false;
                }
                return false;
            }

            bool onControlMsg( Message msg )
            {
                switch( msg.type )
                {
                case MsgType.linkDead:
                    return onLinkDeadMsg( msg.data );
                default:
                    return false;
                }
            }

            bool scan( ref ListT list )
            {
                for( auto range = list[]; !range.empty; )
                {
                    if( isControlMsg( range.front ) )
                    {
                        scope(failure) list.removeAt( range );
                        if( onControlMsg( range.front ) )
                            list.removeAt( range );
                        else
                            range.popFront();
                        continue;
                    }
                    if( onStandardMsg( range.front ) )
                    {
                        list.removeAt( range );
                        return true;
                    }
                    range.popFront();
                }
                return false;
            }


            bool pty( ref ListT list )
            {
                alias Tuple!(Priority) Wrap;

                if( !list.empty )
                {
                    auto    range = list[];
                    Variant data  = range.front.data;
                    assert( data.convertsTo!(Wrap) );
                    auto p = data.get!(Wrap).field[0];
                    Message msg;

                    msg.data = p.data;
                    if( onStandardMsg( msg ) )
                    {
                        list.removeAt( range );
                        return true;
                    }
                    throw p.fail;
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
                        if( ownerDead )
                            onOwnerDead();
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
                    bool ok = scan( arrived );
                    m_localBox.put( arrived );
                    if( ok ) return true;
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
            void onLinkDeadMsg( Variant data )
            {
                alias Tuple!(Tid) Wrap;

                static if( Variant.allowed!(Wrap) )
                {
                    assert( data.convertsTo!(Wrap) );
                    auto wrap = data.get!(Wrap);
                }
                else
                {
                    assert( data.convertsTo!(Wrap*) );
                    auto wrap = data.get!(Wrap*);
                }
                links.remove( wrap.field[0] );
                if( wrap.field[0] == owner )
                    owner = Tid.init;
            }

            void sweep( ref ListT list )
            {
                for( auto range = list[]; !range.empty; range.popFront() )
                {
                    if( range.front.type == MsgType.linkDead )
                        onLinkDeadMsg( range.front.data );
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
        // Routines for specific message types, no lock necessary.
        //////////////////////////////////////////////////////////////////////


        void onOwnerDead()
        {
            for( auto range = m_localBox[]; !range.empty; range.popFront() )
            {
                if( range.front.type == MsgType.linkDead )
                {
                    alias Tuple!(Tid) Wrap;

                    static if( Variant.allowed!(Wrap) )
                    {
                        assert( range.front.data.convertsTo!(Wrap) );
                        auto wrap = range.front.data.get!(Wrap);
                    }
                    else
                    {
                        assert( range.front.data.convertsTo!(Wrap*) );
                        auto wrap = range.front.data.get!(Wrap*);
                    }

                    if( wrap.field[0] == owner )
                    {
                        m_localBox.removeAt( range );
                        break;
                    }
                }
            }
            scope(failure) owner = Tid.init;
            throw new OwnerTerminated( owner );
        }


    private:
        //////////////////////////////////////////////////////////////////////
        // Routines involving local data only, no lock needed.
        //////////////////////////////////////////////////////////////////////


        pure final bool isControlMsg( Message msg )
        {
            return msg.type != MsgType.standard &&
                   msg.type != MsgType.priority;
        }


        pure final bool isPriorityMsg( Message msg )
        {
            return msg.type == MsgType.priority;
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
            bool empty() const
            {
                return !m_prev.next;
            }

            @property T front()
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
            m_count++;
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
                     assert( val.field[0] == 42 &&
                             val.field[1] == 86 );
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
                     writefln( "got string: %s", val );
                     assert(0);
                 } );
        send( tid, "done" );
    }


    unittest
    {
        auto tid = spawn( &testfn, thisTid );

        send( tid, 42, 86 );
        send( tid, tuple(42, 86) );
        send( tid, "hello", "there" );
        send( tid, "the quick brown fox" );
        receive( (string val) { assert(val == "done"); } );
    }
}
