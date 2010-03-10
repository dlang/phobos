/**
 * This is a low-level messaging API upon which more structured or restrictive
 * APIs may be built.  The general idea is that every messageable entity is
 * represtented by a common handle type (called a Cid in this implementation),
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
    import std.stdio;
    import std.range;
    import std.traits;
    import std.typecons;
    import std.typetuple;

    alias SyncList!(Variant) MessageBox;
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
 * An opaque type used to represent a logical local process.
 */
struct Tid
{
    void send(T...)( Tid tid, T vals )
    {
        _send( tid, vals );
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
    auto tid = Tid( new MessageBox );
    
    void exec()
    {
        mbox = tid.mbox;
        fn( args );
    }
    
    auto t = new Thread( &exec );

    t.start();
    return tid;
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
private void _send(T...)( Tid tid, T vals )
{
    alias Tuple!(T) Wrap;

    static if( Variant.allowed!(Wrap) )
    {
        Wrap wrap;

        foreach( i, e; vals )
            wrap.field[i] = e;
        tid.mbox.put( Variant( wrap ) );
    }
    else
    {
        // TODO: This should be shared.
        Wrap* wrap = cast(Wrap*) (new void[Wrap.sizeof]).ptr;
        
        foreach( i, e; vals )
            wrap.field[i] = e;
        tid.mbox.put( Variant( wrap ) );
    }
}


/**
 *
 */
void receive(T...)( T ops )
{
    _receive( ops );
}


/**
 *
 */
Tuple!(T) receiveOnly(T...)()
{
    Tuple!(T) ret;

    _receive( ( T val )
              {
                  foreach( i, v; ret.Types )
                      ret.field[i] = val[i];
              },
              ( Variant val )
              {
                  throw new MessageMismatch;
              } );
    return ret;
}


/**
 *
 */
bool receiveTimeout(T...)( long ms, T ops )
{
    static enum long TICKS_PER_MILLI = 10_000;
    return _receive( ms * TICKS_PER_MILLI, ops );
}


/*
 *
 */
private bool _receive(T...)( T ops )
{
    static assert( T.length );

    static if( isImplicitlyConvertible!(T[0], long) )
    {
        alias TypeTuple!(T[1 .. $]) Ops;
        ops = ops[1 .. $];
    }
    else
    {
        alias TypeTuple!(T) Ops;
    }

    bool get( Variant val )
    {
        foreach( i, t; Ops )
        {
            alias Tuple!(ParameterTypeTuple!(t)) Vals;
            auto op = ops[i];

            static if( is( Vals == Tuple!(Variant) ) )
            {
                static if( is( ReturnType!(t) == bool ) )
                    return op( val );
                op( val );
                return true;
            }
            static if( Variant.allowed!(Vals) )
            {
                if( val.convertsTo!(Vals) )
                {
                    static if( is( ReturnType!(t) == bool ) )
                        return op( val.get!(Vals).expand );
                    op( val.get!(Vals).expand );
                    return true;
                }
            }
            else
            {
                if( val.convertsTo!(Vals*) )
                {
                    static if( is( ReturnType!(t) == bool ) )
                        return op( val.get!(Vals*).expand );
                    op( val.get!(Vals*).expand );
                    return true;
                }
            }
        }
        return false;
    }
    
    static if( isImplicitlyConvertible!(T[0], long) )
    {
        return mbox.get( ops[0], &get );
    }
    else
    {
        mbox.get( &get );
        return true;
    }
}


static this()
{
    mbox = new MessageBox;
}


private
{
    MessageBox mbox;


    class SyncList(T)
    {
        this()
        {
            m_sharedLock = new Mutex;
            m_sharedRecv = new Condition( m_sharedLock );
        }
    
    
    private:
        final void put( T val )
        {
            synchronized( m_sharedLock )
            {
                m_shared.put( val );
                m_sharedRecv.notify();
            }
        }
    
    
        final void get( scope bool delegate(T) op )
        {
            if( m_local.get( op ) )
                return;
            while( true )
            { 
                ListT newvals;
        
                synchronized( m_sharedLock )
                {
                    while( m_shared.isEmpty )
                        m_sharedRecv.wait();
                    newvals.put( m_shared );
                }
                bool ok = newvals.get( op );
                m_local.put( newvals );
                if( ok ) return;
            }
        }
        
        
        final bool get( scope bool delegate(T) op, long period )
        in
        {
            assert( period >= 0 );
        }
        body
        {
            if( m_local.get( op ) )
                return true;
            while( true )
            { 
                ListT newvals;
        
                synchronized( m_sharedLock )
                {
                    while( m_shared.isEmpty )
                    {
                        if( !m_sharedRecv.wait( period ) )
                            return false;
                    }
                    newvals.put( m_shared );
                }
                bool ok = newvals.get( op );
                m_local.put( newvals );
                if( ok ) return true;
            }
        }
    
    
    private:
        alias List!(T) ListT;

        ListT       m_local;
        ListT       m_shared;
        Mutex       m_sharedLock;
        Condition   m_sharedRecv;
    }
    
    
    struct List(T)
    {    
        void put( T val )
        {
            put( new Node( val ) );
        }
    
    
        void put( ref List!(T) rhs )
        {
            if( !rhs.isEmpty )
            {
                put( rhs.m_first );
                while( m_last.next !is null )
                    m_last = m_last.next;
                rhs.m_first = null;
                rhs.m_last = null;
            }
        }
    
    
        bool get( scope bool delegate(T) op )
        {
            Node* n = cast(Node*) &m_first;
        
            for( ; n.next; n = n.next )
            {
                if( op( n.next.val ) )
                {
                    if( m_last is m_first )
                        m_last = null;
                    else if( m_last is n.next )
                        m_last = n;
                    Node* todelete = n.next;
                    n.next = n.next.next;
                    delete todelete;
                    return true;
                }
            }
            return false;
        }
    
    
        bool isEmpty()
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
            if( !isEmpty )
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
        receive( (float val) { writefln( "got float: %s", val ); },
                 (int val, int val2) { writefln( "got int: %s, %s", val, val2 ); } );
        receive( (Tuple!(int, int) val) { writefln( "got tuple: %s", val ); } );
        receive( (Variant val) { writefln( "got something: %s", val ); } );
        receive( (string val)
                 {
                     if( "the quick brown fox" != val )
                         return false;
                     writefln( "matched string: %s", val );
                     return true;
                 },
                 (string val)
                 {
                     writefln( "got string: %s", val );
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
        receive( (string val) { writefln( "spawned thread returned: %s", val ); } );
    }
}
