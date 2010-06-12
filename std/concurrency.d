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
    import std.contracts;
    import std.range;
    import std.stdio;
    import std.range;
    import std.traits;
    import std.typecons;
    import std.typetuple;
    
    enum MsgType
    {
        User,
        LinkDead,
    }
    
    struct Message
    {
        MsgType type;
        Variant data;
        
        this( MsgType t )
        {
            type = t;
        }
    }

    MessageBox mbox;
    Tid[]      owned;
    Tid        owner;
}


static this()
{
    mbox = new MessageBox;
}


static ~this()
{
    auto me = thisTid;
    foreach( tid; owned )
        _send( MsgType.LinkDead, tid, me );
    if( owner != Tid.init )
        _send( MsgType.LinkDead, owner, me );
}


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
    this( string msg = "Owner terminated" )
    {
        super( msg );
    }
}


/**
 * An opaque type used to represent a logical local process.
 */
struct Tid
{
    void send(T...)( T vals )
    {
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


/**
 * Executes the supplied function in a new context represented by Tid.
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
    // TODO: MessageList and &exec should be shared.
    auto spawnTid = Tid( new MessageBox );
    auto ownerTid = thisTid;

    void exec()
    {
        mbox  = spawnTid.mbox;
        owner = ownerTid;
        fn( args );
    }

    auto t = new Thread( &exec );
    
    t.start();
    owned ~= spawnTid;
    return spawnTid;
}


/**
 * Sends the supplied value to the context represented by tid.
 */
void send(T...)( Tid tid, T vals )
{
    _send( tid, vals );
}


/*
 * Implementation of send.  This allows parameter checking to be different for
 * both Tid.send() and .send().
 */
private void _send(T...)( MsgType type, Tid tid, T vals )
{
    alias Tuple!(T) Wrap;

    static if( Variant.allowed!(Wrap) )
    {
        Wrap    wrap;
        Message msg  = Message( type );

        wrap.field = vals;
        msg.data   = wrap;
        tid.mbox.put( msg );
    }
    else
    {
        // TODO: This should be shared.
        Wrap*   wrap = cast(Wrap*) (new void[Wrap.sizeof]).ptr;
        Message msg  = Message( type );

        wrap.field = vals;
        msg.data   = wrap;
        tid.mbox.put( msg );
    }
}


/*
 * ditto
 */
private void _send(T...)( Tid tid, T vals )
{
    _send( MsgType.User, tid, vals );
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


/**
 *
 */
enum OnCrowding
{
    block,          ///
    throwException, ///
    ignore          ///
}


/**
 *
 */
void setMaxMailboxSize( Tid tid, size_t messages, OnCrowding doThis )
{

}


/**
 *
 */
void setMaxMailboxSize( Tid tid, size_t messages, bool function(Tid) onCrowdingDoThis )
{

}


private
{
    /*
     *
     */
    class MessageBox
    {
        this()
        {
            m_sharedLock = new Mutex;
            m_sharedRecv = new Condition( m_sharedLock );
        }
        
        
        final void put( Message val )
        {
            synchronized( m_sharedLock )
            {
                m_shared.put( val );
                m_sharedRecv.notify();
            }
        }
        
        
        final void get(T...)( T ops )
        {
            static assert( T.length );

            static if( isImplicitlyConvertible!(T[0], long) )
            {
                alias TypeTuple!(T[1 .. $]) Ops;
                assert( ops[0] >= 0 );
                long period = ops[0];
                ops = ops[1 .. $];
            }
            else
            {
                alias TypeTuple!(T) Ops;
            }
            
            bool onUserMsg( Message msg )
            {
                Variant data = msg.data;

                foreach( i, t; Ops )
                {
                    alias Tuple!(ParameterTypeTuple!(t)) Wrap;
                    auto op = ops[i];

                    static if( is( Wrap == Tuple!(Variant) ) )
                    {
                        static if( is( ReturnType!(t) == bool ) )
                            return op( data );
                        op( data );
                        return true;
                    }
                    else static if( Variant.allowed!(Wrap) )
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
                    else
                    {
                        if( data.convertsTo!(Wrap*) )
                        {
                            static if( is( ReturnType!(t) == bool ) )
                                return op( data.get!(Wrap*).expand );
                            op( data.get!(Wrap*).expand );
                            return true;
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
                if( wrap.field[0] == owner )
                {
                    ownerDead = true;
                    return false;
                }
                foreach( i, e; owned )
                {
                    if( wrap.field[0] == e )
                    {
                        owned[i]   = owned[$-1];
                        owned[$-1] = Tid.init;
                        owned = owned[0 .. $-1];
                        return true;
                    }
                }
                return false;
            }
            
            bool onControlMsg( Message msg )
            {
                switch( msg.type )
                {
                case MsgType.LinkDead:
                    return onLinkDeadMsg( msg.data );
                default:
                    return false;
                }
            }
            
            bool isControlMsg( Message msg )
            {
                return msg.type != MsgType.User;
            }
            
            bool scan( ref ListT list )
            {
                for( auto range = list[]; !range.empty; )
                {
                    if( isControlMsg( range.front ) )
                    {
                        if( onControlMsg( range.front ) )
                            list.removeAt( range );
                        else
                            range.popFront();
                        continue;
                    }
                    if( onUserMsg( range.front ) )
                    {
                        list.removeAt( range );
                        return true;
                    }
                    range.popFront();
                }
                return false;
            }
            
            while( true )
            {
                ListT newvals;

                if( scan( m_local ) )
                    return;
                synchronized( m_sharedLock )
                {
                    while( m_shared.empty )
                    {
                        if( ownerDead )
                            throw new OwnerTerminated;
                        static if( isImplicitlyConvertible!(T[0], long) )
                            m_sharedRecv.wait( period );
                        else
                            m_sharedRecv.wait();
                    }
                    newvals.put( m_shared );
                }
                bool ok = scan( newvals );
                m_local.put( newvals );
                if( ok ) return;
            }
        }
        
    
    private:
        alias List!(Message) ListT;
        
        ListT       m_local;
        ListT       m_shared;
        Mutex       m_sharedLock;
        Condition   m_sharedRecv;
    }


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


        void put( T val )
        {
            put( new Node( val ) );
        }


        void put( ref List!(T) rhs )
        {
            if( !rhs.empty )
            {
                put( rhs.m_first );
                while( m_last.next !is null )
                    m_last = m_last.next;
                rhs.m_first = null;
                rhs.m_last = null;
            }
        }


        Range opSlice()
        {
            return Range( cast(Node*) &m_first );
        }


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
        }


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


        Node* m_first;
        Node* m_last;
    }
}


version( unittest )
{
    void testfn( Tid tid )
    {
        receive( (float val) { assert(0); },
                (int val, int val2) { assert(val == 42 && val2 == 86); } );
        receive( (Tuple!(int, int) val) { assert(val.field[0] == 42
                            && val.field[1] == 86 ); } );
        receive( (Variant val) {  } );
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
