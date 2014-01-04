// Written in the D programming language.

/**
 * Signals and Slots are an implementation of the $(LINK2 http://en.wikipedia.org/wiki/Observer_pattern, Observer pattern)$(BR)
 * Essentially, when a Signal is emitted, a list of connected Observers
 * (called slots) are called.
 *
 * They were first introduced in the
 * $(LINK2 http://en.wikipedia.org/wiki/Qt_%28framework%29, Qt GUI toolkit), alternate implementations are
 * $(LINK2 http://libsigc.sourceforge.net, libsig++) or
 * $(LINK2 http://www.boost.org/doc/libs/1_55_0/doc/html/signals.html, Boost.Signals2)
 * similar concepts are implemented in other languages than C++ too. 
 *
 * This implementation supersedes the former std.signals, it fixes a few bugs,
 * but of more interest is the much more powerful interface. Not only can you
 * now attach signals to non objects, but also make indirect connections to
 * objects via wrapping delegates, adapting parameters as needed.
 *
 * Copyright: Copyright Robert Klotzner 2012 - 2014.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Robert Klotzner
 */
/*          Copyright Robert Klotzner 2012 - 2013.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 *
 * Based on the original implementation written by Walter Bright. (std.signals)
 * I shamelessly stole some ideas of: http://forum.dlang.org/thread/jjote0$1cql$1@digitalmars.com
 * written by Alex Rønne Petersen.
 *
 * Also thanks to Denis Shelomovskij who made me aware of some
 * deficiencies in the concurrent part of WeakRef.
 */
module std.signal;

import core.atomic;
import core.memory;


// Hook into the GC to get informed about object deletions.
private alias void delegate(Object) DisposeEvt;
private extern (C) void  rt_attachDisposeEvent( Object obj, DisposeEvt evt );
private extern (C) void  rt_detachDisposeEvent( Object obj, DisposeEvt evt );

/**
 * string mixin for creating a signal.
 *
 * It creates a Signal instance named "_name", where name is given
 * as first parameter with given protection and an accessor method
 * with the current context protection named "name" returning either a
 * ref RestrictedSignal or ref Signal depending on the given
 * protection.
 *
 * Bugs:
 *     This mixin generator does not work with templated types right now because of:
 *     $(LINK2 http://d.puremagic.com/issues/show_bug.cgi?id=10502, 10502)$(BR)
 *     You might want to use the Signal struct directly in this
 *     case. Ideally you write the code, the mixin would generate, manually
 *     to ensure an easy upgrade path when the above bug gets fixed:
 ---
 *     ref RestrictedSignal!(SomeTemplate!int) mysig() { return _mysig;}
 *     private Signal!(SomeTemplate!int) _mysig;
 ---     
 *
 * Params:
 *   name = How the signal should be named. The ref returning function
 *   will be named like this, the actual struct instance will have an
 *   underscore prefixed.
 *   
 *   protection = Specifies how the full functionality (emit) of the
 *   signal should be protected. Default is private. If
 *   Protection.none is given, private is used for the Signal member
 *   variable and the ref returning accessor method will return a
 *   Signal instead of a RestrictedSignal. The protection of the
 *   accessor method is specified by the surrounding protection scope:
 ---
 *     public: // Everyone can access mysig now:
 *     // Result of mixin(signal!int("mysig", Protection.none))
 *     ref Signal!int mysig() { return _mysig;}
 *     private Signal!int _mysig;
 ---
 *
 * Example:
 ---
 import std.signal;
 import std.stdio;
 import std.functional;

 class MyObject
 {
     // Mixin signal named valueChanged, with default "private" protection.
     // (Only MyObject is allowed to emit the signal)
     mixin(signal!(string, int)("valueChanged"));

     int value() @property { return _value; }
     int value(int v) @property
     {
        if (v != _value)
        {
            _value = v;
            // call all the connected slots with the two parameters
            _valueChanged.emit("setting new value", v);
        }
        return v;
    }
private:
    int _value;
}

class Observer
{   // our slot
    void watch(string msg, int i)
    {
        writefln("Observed msg '%s' and value %s", msg, i);
    }
}
void watch(string msg, int i)
{
    writefln("Globally observed msg '%s' and value %s", msg, i);
}
void main()
{
    auto a = new MyObject;
    Observer o = new Observer;

    a.value = 3;                // should not call o.watch()
    a.valueChanged.connect!"watch"(o);        // o.watch is the slot
    a.value = 4;                // should call o.watch()
    a.valueChanged.disconnect!"watch"(o);     // o.watch is no longer a slot
    a.value = 5;                // should not call o.watch()
    a.valueChanged.connect!"watch"(o);        // connect again
    // Do some fancy stuff:
    a.valueChanged.connect!Observer(o, (obj, msg, i) =>  obj.watch("Some other text I made up", i+1));
    a.valueChanged.strongConnect(toDelegate(&watch));
    a.value = 6;                // should call o.watch()
    destroy(o);                 // destroying o should automatically disconnect it
    a.value = 7;                // should not call o.watch()

}
---
 * which should print:
 * <pre>
 * Observed msg 'setting new value' and value 4
 * Observed msg 'setting new value' and value 6
 * Observed msg 'Some other text I made up' and value 7
 * Globally observed msg 'setting new value' and value 6
 * Globally observed msg 'setting new value' and value 7
 * </pre>
 */
string signal(Args...)(string name, Protection protection=Protection.private_) @trusted // trusted necessary because of to!string
{
    import std.conv;
    string argList="(";
    import std.traits : fullyQualifiedName;
    foreach (arg; Args)
    {
        argList~=fullyQualifiedName!(arg)~", ";
    }
    if (argList.length>"(".length)
        argList = argList[0 .. $-2];
    argList ~= ")";

    string output = (protection == Protection.none ? "private" : to!string(protection)[0..$-1]) ~
        " Signal!" ~ argList ~ " _" ~ name ~ ";\n";
    string rType = protection == Protection.none ? "Signal!" : "RestrictedSignal!";
    output ~= "ref " ~ rType ~ argList ~ " " ~ name ~ "() { return _" ~ name ~ ";}\n";
    return output;
}

/**
 * Protection to use for the signal string mixin.
 */
enum Protection
{
    none, /// No protection at all, the wrapping function will return a ref Signal instead of a ref RestrictedSignal
    private_, /// The Signal member variable will be private.
    protected_, /// The signal member variable will be protected.
    package_ /// The signal member variable will have package protection.
}

/**
 * Full signal implementation.
 *
 * It implements the emit function for all other functionality it has
 * this aliased to RestrictedSignal.
 *
 * A signal is a way to couple components together in a very loose
 * way. The receiver does not need to know anything about the sender
 * and the sender does not need to know anything about the
 * receivers. The sender will just call emit when something happens,
 * the signal takes care of notifying all interested parties. By using
 * wrapper delegates/functions, not even the function signature of
 * sender/receiver need to match.
 *
 * Another consequence of this very loose coupling is, that a
 * connected object will be freed by the GC if all references to it
 * are dropped, even if it was still connected to a signal, the
 * connection will simply be dropped. This way the developer is freed of
 * manually keeping track of connections.
 *
 * If in your application the connections made by a signal are not
 * that loose you can use strongConnect(), in this case the GC won't
 * free your object until it was disconnected from the signal or the
 * signal got itself destroyed.
 *
 * This struct is not thread-safe in general, it just handles the
 * concurrent parts of the GC.
 *
 * Bugs: The code probably won't compile with -profile because of bug:
 *       $(LINK2 http://d.puremagic.com/issues/show_bug.cgi?id=10260, 10260)
 */
struct Signal(Args...)
{
    alias restricted this;

    /**
     * Emit the signal.
     *
     * All connected slots which are still alive will be called.  If
     * any of the slots throws an exception, the other slots will
     * still be called. You'll receive a chained exception with all
     * exceptions that were thrown. Thus slots won't influence each
     * others execution.
     *
     * The slots are called in the same sequence as they were registered.
     *
     * emit also takes care of actually removing dead connections. For
     * concurrency reasons they are set just to an invalid state by the GC.
     *
     * If you remove a slot during emit() it won't be called in the
     * current run if it was not already.
     *
     * If you add a slot during emit() it will be called in the
     * current emit() run. Note however Signal is not thread-safe, "called
     * during emit" basically means called from within a slot.
     */
    void emit( Args args ) @trusted
    {
        _restricted._impl.emit(args);
    }

    /**
     * Get access to the rest of the signals functionality.
     */
    ref RestrictedSignal!(Args) restricted() @property @trusted
    {
        return _restricted;
    }

    private:
    RestrictedSignal!(Args) _restricted;
}

/**
 * The signal implementation, not providing an emit method.
 *
 * The idea is to instantiate a Signal privately and provide a
 * public accessor method for accessing the contained
 * RestrictedSignal. You can use the signal string mixin, which does
 * exactly that.
 */
struct RestrictedSignal(Args...)
{
    /**
      * Direct connection to an object.
      *
      * Use this method if you want to connect directly to an object's
      * method matching the signature of this signal.  The connection
      * will have weak reference semantics, meaning if you drop all
      * references to the object the garbage collector will collect it
      * and this connection will be removed.
      *
      * Preconditions: obj must not be null. mixin("&obj."~method)
      * must be valid and compatible.
      * Params:
      *     obj = Some object of a class implementing a method
      *     compatible with this signal.
      */
    void connect(string method, ClassType)(ClassType obj) @trusted
        if (is(ClassType == class) && __traits(compiles, {void delegate(Args) dg = mixin("&obj."~method);})) 
    in
    {
        assert(obj);
    }
    body
    {
        _impl.addSlot(obj, cast(void delegate())mixin("&obj."~method));
    }
    /**
      * Indirect connection to an object.
      *
      * Use this overload if you want to connect to an objects method
      * which does not match the signal's signature.  You can provide
      * any delegate to do the parameter adaption, but make sure your
      * delegates' context does not contain a reference to the target
      * object, instead use the provided obj parameter, where the
      * object passed to connect will be passed to your delegate.
      * This is to make weak ref semantics possible, if your delegate
      * contains a ref to obj, the object won't be freed as long as
      * the connection remains.
      *
      * Preconditions: obj and dg must not be null (dgs context
      * may). dg's context must not be equal to obj.
      *
      * Params:
      *     obj = The object to connect to. It will be passed to the
      *     delegate when the signal is emitted.
      *     
      *     dg = A wrapper delegate which takes care of calling some
      *     method of obj. It can do any kind of parameter adjustments
      *     necessary.
     */
    void connect(ClassType)(ClassType obj, void delegate(ClassType obj, Args) dg) @trusted
        if (is(ClassType == class)) 
    in
    {
        assert(obj);
        assert(dg);
        assert(cast(void*)obj !is dg.ptr);
    }
    body
    {
        _impl.addSlot(obj, cast(void delegate()) dg);
    }

    /**
      * Connect with strong ref semantics.
      *
      * Use this overload if you either really, really want strong ref
      * semantics for some reason or because you want to connect some
      * non-class method delegate. Whatever the delegates' context
      * references, will stay in memory as long as the signals
      * connection is not removed and the signal gets not destroyed
      * itself.
      *
      * Preconditions: dg must not be null. (Its context may.)
      *
      * Params:
      *     dg = The delegate to be connected.
      */
    void strongConnect(void delegate(Args) dg) @trusted
    in
    {
        assert(dg);
    }
    body
    {
        _impl.addSlot(null, cast(void delegate()) dg);
    }


    /**
      * Disconnect a direct connection.
      *
      * After issuing this call, the connection to method of obj is lost
      * and obj.method() will no longer be called on emit.
      * Preconditions: Same as for direct connect.
      */
    void disconnect(string method, ClassType)(ClassType obj) @trusted
        if (is(ClassType == class) && __traits(compiles, {void delegate(Args) dg = mixin("&obj."~method);}))
    in
    {
        assert(obj);
    }
    body
    {
        void delegate(Args) dg = mixin("&obj."~method);
        _impl.removeSlot(obj, cast(void delegate()) dg);
    }

    /**
      * Disconnect an indirect connection.
      *
      * For this to work properly, dg has to be exactly the same as
      * the one passed to connect. So if you used a lamda you have to
      * keep a reference to it somewhere if you want to disconnect
      * the connection later on.  If you want to remove all
      * connections to a particular object, use the overload which only
      * takes an object parameter.
     */
    void disconnect(ClassType)(ClassType obj, void delegate(ClassType, T1) dg) @trusted
        if (is(ClassType == class))
    in
    {
        assert(obj);
        assert(dg);
    }
    body
    {
        _impl.removeSlot(obj, cast(void delegate())dg);
    }

    /**
      * Disconnect all connections to obj.
      *
      * All connections to obj made with calls to connect are removed. 
     */
    void disconnect(ClassType)(ClassType obj) @trusted if (is(ClassType == class))
    in
    {
        assert(obj);
    }
    body
    {
        _impl.removeSlot(obj);
    }
    
    /**
      * Disconnect a connection made with strongConnect.
      *
      * Disconnects all connections to dg.
      */
    void strongDisconnect(void delegate(Args) dg) @trusted
    in
    {
        assert(dg);
    }
    body
    {
        _impl.removeSlot(null, cast(void delegate()) dg);
    }
    private:
    SignalImpl _impl;
}

private struct SignalImpl
{
    /**
      * Forbid copying.
      * Unlike the old implementations, it would now be theoretically
      * possible to copy a signal. Even different semantics are
      * possible. But none of the possible semantics are what the user
      * intended in all cases, so I believe it is still the safer
      * choice to simply disallow copying.
      */
    @disable this(this);
    /// Forbid copying
    @disable void opAssign(SignalImpl other);

    void emit(Args...)( Args args )
    {
        int emptyCount = 0;
        if (!_slots.emitInProgress)
        {
            _slots.emitInProgress = true;
            scope (exit) _slots.emitInProgress = false;
        }
        else
            emptyCount = -1;
        doEmit(0, emptyCount, args);
        if (emptyCount > 0)
        {
            _slots.slots = _slots.slots[0 .. $-emptyCount]; 
            _slots.slots.assumeSafeAppend();
        }
    }

    void addSlot(Object obj, void delegate() dg)
    {
        auto oldSlots = _slots.slots;
        if (oldSlots.capacity <= oldSlots.length)
        {
            auto buf = new SlotImpl[oldSlots.length+1]; // TODO: This growing strategy might be inefficient.
            foreach (i, ref slot ; oldSlots)
                buf[i].moveFrom(slot);
            oldSlots = buf;
        }
        else
            oldSlots.length = oldSlots.length + 1;

        oldSlots[$-1].construct(obj, dg);
        _slots.slots = oldSlots;
    }
    void removeSlot(Object obj, void delegate() dg)
    {
        removeSlot((ref SlotImpl item) => item.wasConstructedFrom(obj, dg));
    }
    void removeSlot(Object obj) 
    {
        removeSlot((ref SlotImpl item) => item.obj is obj);
    }

    ~this()
    {
        foreach (ref slot; _slots.slots)
        {
            debug (signal) { import std.stdio; stderr.writefln("Destruction, removing some slot(%s, weakref: %s), signal: ", &slot, &slot._obj, &this); }
            slot.reset(); // This is needed because ATM the GC won't trigger struct
                        // destructors to be run when within a GC managed array.
        }
    }
/// Little helper functions:

    /**
     * Find and make invalid any slot for which isRemoved returns true.
     */
    void removeSlot(bool delegate(ref SlotImpl) isRemoved)
    {
        if (_slots.emitInProgress)
        {
            foreach (ref slot; _slots.slots)
                if (isRemoved(slot))
                    slot.reset();
        }
        else // It is save to do immediate cleanup:
        {
            int emptyCount = 0;
            auto mslots = _slots.slots;
            foreach (int i, ref slot; mslots)
            {
            // We are retrieving obj twice which is quite expensive because of GC lock:
                if (!slot.isValid || isRemoved(slot)) 
                {
                    emptyCount++;
                    slot.reset();
                }
                else if (emptyCount)
                    mslots[i-emptyCount].moveFrom(slot);
            }
            
            if (emptyCount > 0)
            {
                mslots = mslots[0..$-emptyCount];
                mslots.assumeSafeAppend();
                _slots.slots = mslots;
            }
        }
    }

    /**
     * Helper method to allow all slots being called even in case of an exception. 
     * All exceptions that occur will be chained.
     * Any invalid slots (GC collected or removed) will be dropped.
     */
    void doEmit(Args...)(int offset, ref int emptyCount, Args args )
    {
        int i=offset;
        auto myslots = _slots.slots; 
        scope (exit) if (i+1<myslots.length) doEmit(i+1, emptyCount, args); // Carry on.
        if (emptyCount == -1)
        {
            for (; i<myslots.length; i++)
            {
                myslots[i](args);
                myslots = _slots.slots; // Refresh because addSlot might have been called.
            }
        }
        else
        {
            for (; i<myslots.length; i++)
            {
                bool result = myslots[i](args);
                myslots = _slots.slots; // Refresh because addSlot might have been called.
                if (!result) 
                    emptyCount++;
                else if (emptyCount>0)
                {
                    myslots[i-emptyCount].reset();
                    myslots[i-emptyCount].moveFrom(myslots[i]);
                }
            }
        }
    }

    SlotArray _slots;
}


// Simple convenience struct for signal implementation.
// Its is inherently unsafe. It is not a template so SignalImpl does
// not need to be one.
private struct SlotImpl 
{
    @disable this(this);
    @disable void opAssign(SlotImpl other);
    
    /// Pass null for o if you have a strong ref delegate.
    /// dg.funcptr must not point to heap memory.
    void construct(Object o, void delegate() dg)
    in { assert(this is SlotImpl.init); }
    body
    {
        _obj.construct(o);
        _dataPtr = dg.ptr;
        _funcPtr = dg.funcptr;
        assert(GC.addrOf(_funcPtr) is null, "Your function is implemented on the heap? Such dirty tricks are not supported with std.signal!");
        if (o)
        {
            if (_dataPtr is cast(void*) o) 
                _dataPtr = directPtrFlag;
            hasObject = true;
        }
    }

    /**
     * Check whether this slot was constructed from object o and delegate dg.
     */
    bool wasConstructedFrom(Object o, void delegate() dg)
    {
        if ( o && dg.ptr is cast(void*) o)
            return obj is o && _dataPtr is directPtrFlag && funcPtr is dg.funcptr;
        else
            return obj is o && _dataPtr is dg.ptr && funcPtr is dg.funcptr;
    }
    /**
     * Implement proper explicit move.
     */
    void moveFrom(ref SlotImpl other)
    in { assert(this is SlotImpl.init); }
    body
    {
        auto o = other.obj;
        _obj.construct(o);
        _dataPtr = other._dataPtr;
        _funcPtr = other._funcPtr;
        other.reset(); // Destroy original!
    }
    
    @property Object obj()
    {
        return _obj.obj;
    }

    /**
     * Whether or not _obj should contain a valid object. (We have a weak connection)
     */
    bool hasObject() @property const
    {
        return cast(ptrdiff_t) _funcPtr & 1;
    }

    /**
     * Check whether this is a valid slot.
     *
     * Meaning opCall will call something and return true;
     */
    bool isValid() @property 
    {
        return funcPtr && (!hasObject || obj !is null);
    }
    /**
     * Call the slot.
     *
     * Returns: True if the call was successful (the slot was valid).
     */
    bool opCall(Args...)(Args args)
    {
        auto o = obj;
        void* o_addr = cast(void*)(o);
        
        if (!funcPtr || (hasObject && !o_addr)) 
            return false;
        if (_dataPtr is directPtrFlag || !hasObject)
        {
            void delegate(Args) mdg;
            mdg.funcptr=cast(void function(Args)) funcPtr;
            debug (signal) { import std.stdio; writefln("hasObject: %s, o_addr: %s, dataPtr: %s", hasObject, o_addr, _dataPtr);}
            assert((hasObject && _dataPtr is directPtrFlag) || (!hasObject && _dataPtr !is directPtrFlag));
            if (hasObject)
                mdg.ptr = o_addr;
            else
                mdg.ptr = _dataPtr;
            mdg(args);
        }
        else
        {
            void delegate(Object, Args) mdg;
            mdg.ptr = _dataPtr;
            mdg.funcptr = cast(void function(Object, Args)) funcPtr;
            mdg(o, args);
        }
        return true;
    }
    /**
     * Reset this instance to its initial value.
     */   
    void reset() {
        _funcPtr = SlotImpl.init._funcPtr;
        _dataPtr = SlotImpl.init._dataPtr;
        _obj.reset();
    }
private:
    void* funcPtr() @property const
    {
        return cast(void*)( cast(ptrdiff_t)_funcPtr & ~cast(ptrdiff_t)1);
    }
    void hasObject(bool yes) @property
    {
        if (yes)
            _funcPtr = cast(void*)(cast(ptrdiff_t) _funcPtr | 1);
        else
            _funcPtr = cast(void*)(cast(ptrdiff_t) _funcPtr & ~cast(ptrdiff_t)1);
    }
    void* _funcPtr;
    void* _dataPtr;
    WeakRef _obj;


    enum directPtrFlag = cast(void*)(~0);
}


// Provides a way of holding a reference to an object, without the GC seeing it.
private struct WeakRef
{
    /**
     * As struct must be relocatable, it is not even possible to
     * provide proper copy support for WeakRef.  rt_attachDisposeEvent
     * is used for registering unhook. D's move semantics assume
     * relocatable objects, which results in this(this) being called
     * for one instance and the destructor for another, thus the wrong
     * handlers are deregistered.  D's assumption of relocatable
     * objects is not matched, so move() for example will still simply
     * swap contents of two structs, resulting in the wrong unhook
     * delegates being unregistered.

     * Unfortunately the runtime still blindly copies WeakRefs if they
     * are in a dynamic array and reallocation is needed. This case
     * has to be handled separately.
     */
    @disable this(this);
    @disable void opAssign(WeakRef other);
    void construct(Object o) 
    in { assert(this is WeakRef.init); }
    body
    {
        debug (signal) createdThis=&this;
        debug (signal) { import std.stdio; writefln("WeakRef.construct for %s and object: %s", &this, o); }
        if (!o)
            return;
        _obj.construct(cast(void*)o);
        rt_attachDisposeEvent(o, &unhook);
    }
    Object obj() @property 
    {
        return cast(Object) _obj.address;
    }
    /**
     * Reset this instance to its intial value.
     */   
    void reset()
    {
        auto o = obj;
        debug (signal) { import std.stdio; writefln("WeakRef.reset for %s and object: %s", &this, o); }
        if (o)
            rt_detachDisposeEvent(o, &unhook);
        unhook(o); // unhook has to be done unconditionally, because in case the GC
        //kicked in during toggleVisibility(), obj would contain -1
        //so the assertion of SlotImpl.moveFrom would fail.
        debug (signal) createdThis = null;
    }
    
    ~this()
    {
        reset();
    }
    private:
    debug (signal)
    {
        invariant()
        {
            import std.conv : text;
            assert(createdThis is null || &this is createdThis,
                   text("We changed address! This should really not happen! Orig address: ",
                    cast(void*)createdThis, " new address: ", cast(void*)&this));
        }

        WeakRef* createdThis;
    }
    
    void unhook(Object o)
    {
        _obj.reset();
    }
    
    shared(InvisibleAddress) _obj;
}

// Do all the dirty stuff, WeakRef is only a thin wrapper completing
// the functionality by means of rt_ hooks.
private shared struct InvisibleAddress
{
    /// Initialize with o, state is set to invisible immediately.
    /// No precautions regarding thread safety are necessary because
    /// obviously a live reference exists.
    void construct(void* o)
    {
        auto tmp = cast(ptrdiff_t) o;
        _addr = makeInvisible(cast(ptrdiff_t) o);
    }
    void reset()
    {
        atomicStore(_addr, 0L);
    }
    void* address() @property 
    {
        makeVisible(); 
        scope (exit) makeInvisible(); 
        GC.addrOf(cast(void*)atomicLoad(_addr)); // Just a dummy call to the GC
                                 // in order to wait for any possible running
                                 // collection to complete (have unhook called).
        auto buf = atomicLoad(_addr);
        if ( isNull(buf) )
            return null;
        assert(isVisible(buf));
        return cast(void*) buf;
    }
    debug(signal)        string toString()
    {
        import std.conv : text;
        return text(address);
    }
private:

    long _addr;

    void makeVisible()
    {
        long buf, wbuf;
        do
        {
            buf = atomicLoad(_addr);
            wbuf = makeVisible(buf);
        }
        while(!cas(&_addr, buf, wbuf));
    }
    void makeInvisible()
    {
        long buf, wbuf;
        do
        {
            buf = atomicLoad(_addr);
            wbuf = makeInvisible(buf);
        }
        while(!cas(&_addr, buf, wbuf));
    }
    version(D_LP64)
    {
        static long makeVisible(long addr)
        {
            return ~addr;
        }

        static long makeInvisible(long addr)
        {
            return ~addr;
        }                
        static bool isVisible(long addr)
        {
            return !(addr & (1L << (ptrdiff_t.sizeof*8-1)));
        }
        static bool isNull(long addr)
        {  
            return ( addr == 0 || addr == (~0) );
        }
    }
    else
    {
        static long makeVisible(long addr)
        {
            auto addrHigh = (addr >> 32) & 0xffff;
            auto addrLow = addr & 0xffff;
            return addrHigh << 16 | addrLow;
        }

        static long makeInvisible(long addr)
        {
            auto addrHigh = ((addr >> 16) & 0x0000ffff) | 0xffff0000;
            auto addrLow = (addr & 0x0000ffff) | 0xffff0000;
            return (cast(long)addrHigh << 32) | addrLow;
        }                
        static bool isVisible(long addr)
        {
            return !((addr >> 32) & 0xffffffff);
        }
        static bool isNull(long addr)
        {
            return ( addr == 0 || addr == ((0xffff0000L << 32) | 0xffff0000) );
        }
    }
}

/**
 * Provides a way of storing flags in unused parts of a typical D array.
 *
 * By unused I mean the highest bits of the length.
 * (We don't need to support 4 billion slots per signal with int
 * or 10^19 if length gets changed to 64 bits.)
 */
private struct SlotArray {
    // Choose int for now, this saves 4 bytes on 64 bits.
    alias int lengthType;
    import std.bitmanip : bitfields;
    enum reservedBitsCount = 3;
    enum maxSlotCount = lengthType.max >> reservedBitsCount;
    SlotImpl[] slots() @property
    {
        return _ptr[0 .. length];
    }
    void slots(SlotImpl[] newSlots) @property
    {
        _ptr = newSlots.ptr;
        version(assert)
        {
            import std.conv : text;
            assert(newSlots.length <= maxSlotCount, text("Maximum slots per signal exceeded: ", newSlots.length, "/", maxSlotCount));
        }
        _blength.length &= ~maxSlotCount;
        _blength.length |= newSlots.length;
    }
    size_t length() @property
    {
        return _blength.length & maxSlotCount;
    }

    bool emitInProgress() @property
    {
        return _blength.emitInProgress;
    }
    void emitInProgress(bool val) @property
    {
        _blength.emitInProgress = val;
    }
private:
    SlotImpl* _ptr;
    union BitsLength {
        mixin(bitfields!(
                  bool, "", lengthType.sizeof*8-1,
                  bool, "emitInProgress", 1
                  ));
        lengthType length;
    }
    BitsLength _blength;
}
unittest {
    SlotArray arr;
    auto tmp = new SlotImpl[10];
    arr.slots = tmp;
    assert(arr.length == 10);
    assert(!arr.emitInProgress);
    arr.emitInProgress = true;
    assert(arr.emitInProgress);
    assert(arr.length == 10);
    assert(arr.slots is tmp);
    arr.slots = tmp;
    assert(arr.emitInProgress);
    assert(arr.length == 10);
    assert(arr.slots is tmp);
    debug (signal){ import std.stdio;
        writeln("Slot array tests passed!");
    }
}

unittest
{ // Check that above example really works ...
    import std.functional;
    debug (signal) import std.stdio;
    class MyObject
    {
        mixin(signal!(string, int)("valueChanged"));

        int value() @property { return _value; }
        int value(int v) @property
        {
            if (v != _value)
            {
                _value = v;
                // call all the connected slots with the two parameters
                _valueChanged.emit("setting new value", v);
            }
            return v;
        }
    private:
        int _value;
    }

    class Observer
    {   // our slot
        void watch(string msg, int i)
        {
            debug (signal) writefln("Observed msg '%s' and value %s", msg, i);
        }
    }

    static void watch(string msg, int i)
    {
        debug (signal) writefln("Globally observed msg '%s' and value %s", msg, i);
    }

    auto a = new MyObject;
    Observer o = new Observer;

    a.value = 3;                // should not call o.watch()
    a.valueChanged.connect!"watch"(o);        // o.watch is the slot
    a.value = 4;                // should call o.watch()
    a.valueChanged.disconnect!"watch"(o);     // o.watch is no longer a slot
    a.value = 5;                // so should not call o.watch()
    a.valueChanged.connect!"watch"(o);        // connect again
    // Do some fancy stuff:
    a.valueChanged.connect!Observer(o, (obj, msg, i) =>  obj.watch("Some other text I made up", i+1));
    a.valueChanged.strongConnect(toDelegate(&watch));
    a.value = 6;                // should call o.watch()
    destroy(o);                 // destroying o should automatically disconnect it
    a.value = 7;                // should not call o.watch()
}

unittest
{
    debug (signal) import std.stdio;
    class Observer
    {
        void watch(string msg, int i)
        {
            //writefln("Observed msg '%s' and value %s", msg, i);
            captured_value = i;
            captured_msg   = msg;
        }


        int    captured_value;
        string captured_msg;
    }

    class SimpleObserver 
    {
        void watchOnlyInt(int i) {
            captured_value = i;
        }
        int captured_value;
    }

    class Foo
    {
        @property int value() { return _value; }

        @property int value(int v)
        {
            if (v != _value)
            {   _value = v;
                _extendedSig.emit("setting new value", v);
                //_simpleSig.emit(v);
            }
            return v;
        }

        mixin(signal!(string, int)("extendedSig"));
        //Signal!(int) simpleSig;

        private:
        int _value;
    }

    Foo a = new Foo;
    Observer o = new Observer;
    SimpleObserver so = new SimpleObserver;
    // check initial condition
    assert(o.captured_value == 0);
    assert(o.captured_msg == "");

    // set a value while no observation is in place
    a.value = 3;
    assert(o.captured_value == 0);
    assert(o.captured_msg == "");

    // connect the watcher and trigger it
    a.extendedSig.connect!"watch"(o);
    a.value = 4;
    assert(o.captured_value == 4);
    assert(o.captured_msg == "setting new value");

    // disconnect the watcher and make sure it doesn't trigger
    a.extendedSig.disconnect!"watch"(o);
    a.value = 5;
    assert(o.captured_value == 4);
    assert(o.captured_msg == "setting new value");
    //a.extendedSig.connect!Observer(o, (obj, msg, i) { obj.watch("Hahah", i); });
    a.extendedSig.connect!Observer(o, (obj, msg, i) => obj.watch("Hahah", i) );

    a.value = 7;        
    debug (signal) stderr.writeln("After asignment!");
    assert(o.captured_value == 7);
    assert(o.captured_msg == "Hahah");
    a.extendedSig.disconnect(o); // Simply disconnect o, otherwise we would have to store the lamda somewhere if we want to disconnect later on.
    // reconnect the watcher and make sure it triggers
    a.extendedSig.connect!"watch"(o);
    a.value = 6;
    assert(o.captured_value == 6);
    assert(o.captured_msg == "setting new value");

    // destroy the underlying object and make sure it doesn't cause
    // a crash or other problems
    debug (signal) stderr.writefln("Disposing");
    destroy(o);
    debug (signal) stderr.writefln("Disposed");
    a.value = 7;
}

unittest {
    class Observer
    {
        int    i;
        long   l;
        string str;

        void watchInt(string str, int i)
        {
            this.str = str;
            this.i = i;
        }

        void watchLong(string str, long l)
        {
            this.str = str;
            this.l = l;
        }
    }

    class Bar
    {
        @property void value1(int v)  { _s1.emit("str1", v); }
        @property void value2(int v)  { _s2.emit("str2", v); }
        @property void value3(long v) { _s3.emit("str3", v); }

        mixin(signal!(string, int) ("s1"));
        mixin(signal!(string, int) ("s2"));
        mixin(signal!(string, long)("s3"));
    }

    void test(T)(T a)
    {
        auto o1 = new Observer;
        auto o2 = new Observer;
        auto o3 = new Observer;

        // connect the watcher and trigger it
        a.s1.connect!"watchInt"(o1);
        a.s2.connect!"watchInt"(o2);
        a.s3.connect!"watchLong"(o3);

        assert(!o1.i && !o1.l && !o1.str);
        assert(!o2.i && !o2.l && !o2.str);
        assert(!o3.i && !o3.l && !o3.str);

        a.value1 = 11;
        assert(o1.i == 11 && !o1.l && o1.str == "str1");
        assert(!o2.i && !o2.l && !o2.str);
        assert(!o3.i && !o3.l && !o3.str);
        o1.i = -11; o1.str = "x1";

        a.value2 = 12;
        assert(o1.i == -11 && !o1.l && o1.str == "x1");
        assert(o2.i == 12 && !o2.l && o2.str == "str2");
        assert(!o3.i && !o3.l && !o3.str);
        o2.i = -12; o2.str = "x2";

        a.value3 = 13;
        assert(o1.i == -11 && !o1.l && o1.str == "x1");
        assert(o2.i == -12 && !o1.l && o2.str == "x2");
        assert(!o3.i && o3.l == 13 && o3.str == "str3");
        o3.l = -13; o3.str = "x3";

        // disconnect the watchers and make sure it doesn't trigger
        a.s1.disconnect!"watchInt"(o1);
        a.s2.disconnect!"watchInt"(o2);
        a.s3.disconnect!"watchLong"(o3);

        a.value1 = 21;
        a.value2 = 22;
        a.value3 = 23;
        assert(o1.i == -11 && !o1.l && o1.str == "x1");
        assert(o2.i == -12 && !o1.l && o2.str == "x2");
        assert(!o3.i && o3.l == -13 && o3.str == "x3");

        // reconnect the watcher and make sure it triggers
        a.s1.connect!"watchInt"(o1);
        a.s2.connect!"watchInt"(o2);
        a.s3.connect!"watchLong"(o3);

        a.value1 = 31;
        a.value2 = 32;
        a.value3 = 33;
        assert(o1.i == 31 && !o1.l && o1.str == "str1");
        assert(o2.i == 32 && !o1.l && o2.str == "str2");
        assert(!o3.i && o3.l == 33 && o3.str == "str3");

        // destroy observers
        destroy(o1);
        destroy(o2);
        destroy(o3);
        a.value1 = 41;
        a.value2 = 42;
        a.value3 = 43;
    }

    test(new Bar);

    class BarDerived: Bar
    {
        @property void value4(int v)  { _s4.emit("str4", v); }
        @property void value5(int v)  { _s5.emit("str5", v); }
        @property void value6(long v) { _s6.emit("str6", v); }

        mixin(signal!(string, int) ("s4"));
        mixin(signal!(string, int) ("s5"));
        mixin(signal!(string, long)("s6"));
    }

    auto a = new BarDerived;

    test!Bar(a);
    test!BarDerived(a);

    auto o4 = new Observer;
    auto o5 = new Observer;
    auto o6 = new Observer;

    // connect the watcher and trigger it
    a.s4.connect!"watchInt"(o4);
    a.s5.connect!"watchInt"(o5);
    a.s6.connect!"watchLong"(o6);

    assert(!o4.i && !o4.l && !o4.str);
    assert(!o5.i && !o5.l && !o5.str);
    assert(!o6.i && !o6.l && !o6.str);

    a.value4 = 44;
    assert(o4.i == 44 && !o4.l && o4.str == "str4");
    assert(!o5.i && !o5.l && !o5.str);
    assert(!o6.i && !o6.l && !o6.str);
    o4.i = -44; o4.str = "x4";

    a.value5 = 45;
    assert(o4.i == -44 && !o4.l && o4.str == "x4");
    assert(o5.i == 45 && !o5.l && o5.str == "str5");
    assert(!o6.i && !o6.l && !o6.str);
    o5.i = -45; o5.str = "x5";

    a.value6 = 46;
    assert(o4.i == -44 && !o4.l && o4.str == "x4");
    assert(o5.i == -45 && !o4.l && o5.str == "x5");
    assert(!o6.i && o6.l == 46 && o6.str == "str6");
    o6.l = -46; o6.str = "x6";

    // disconnect the watchers and make sure it doesn't trigger
    a.s4.disconnect!"watchInt"(o4);
    a.s5.disconnect!"watchInt"(o5);
    a.s6.disconnect!"watchLong"(o6);

    a.value4 = 54;
    a.value5 = 55;
    a.value6 = 56;
    assert(o4.i == -44 && !o4.l && o4.str == "x4");
    assert(o5.i == -45 && !o4.l && o5.str == "x5");
    assert(!o6.i && o6.l == -46 && o6.str == "x6");

    // reconnect the watcher and make sure it triggers
    a.s4.connect!"watchInt"(o4);
    a.s5.connect!"watchInt"(o5);
    a.s6.connect!"watchLong"(o6);

    a.value4 = 64;
    a.value5 = 65;
    a.value6 = 66;
    assert(o4.i == 64 && !o4.l && o4.str == "str4");
    assert(o5.i == 65 && !o4.l && o5.str == "str5");
    assert(!o6.i && o6.l == 66 && o6.str == "str6");

    // destroy observers
    destroy(o4);
    destroy(o5);
    destroy(o6);
    a.value4 = 44;
    a.value5 = 45;
    a.value6 = 46;
}

unittest 
{
    import std.stdio;

    struct Property 
    {
        alias value this;
        mixin(signal!(int)("signal"));
        @property int value() 
        {
            return value_;
        }
        ref Property opAssign(int val) 
        {
            debug (signal) writeln("Assigning int to property with signal: ", &this);
            value_ = val;
            _signal.emit(val);
            return this;
        }
        private: 
        int value_;
    }

    void observe(int val)
    {
        debug (signal) writefln("observe: Wow! The value changed: %s", val);
    }

    class Observer 
    {
        void observe(int val)
        {
            debug (signal) writefln("Observer: Wow! The value changed: %s", val);
            debug (signal) writefln("Really! I must know I am an observer (old value was: %s)!", observed);
            observed = val;
            count++;
        }
        int observed;
        int count;
    }
    Property prop;
    void delegate(int) dg = (val) => observe(val);
    prop.signal.strongConnect(dg);
    assert(prop.signal._impl._slots.length==1);
    Observer o=new Observer;
    prop.signal.connect!"observe"(o);
    assert(prop.signal._impl._slots.length==2);
    debug (signal) writeln("Triggering on original property with value 8 ...");
    prop=8;
    assert(o.count==1);
    assert(o.observed==prop);
}

unittest 
{
    debug (signal) import std.stdio;
    import std.conv;
    Signal!() s1;
    void testfunc(int id) 
    {
        throw new Exception(to!string(id));
    }
    s1.strongConnect(() => testfunc(0));
    s1.strongConnect(() => testfunc(1));
    s1.strongConnect(() => testfunc(2));
    try s1.emit();
    catch(Exception e)
    {
        Throwable t=e;
        int i=0;
        while (t)
        {
            debug (signal) stderr.writefln("Caught exception (this is fine)");
            assert(to!int(t.msg)==i);
            t=t.next;
            i++;
        }
        assert(i==3);
    }
}
unittest
{
    class A
    {
        mixin(signal!(string, int)("s1"));
    }

    class B : A
    {
        mixin(signal!(string, int)("s2"));
    }
}

unittest
{
    struct Test
    {
        mixin(signal!int("a", Protection.package_));
        mixin(signal!int("ap", Protection.private_));
        mixin(signal!int("app", Protection.protected_));
        mixin(signal!int("an", Protection.none));
    }

    static assert(signal!int("a", Protection.package_)=="package Signal!(int) _a;\nref RestrictedSignal!(int) a() { return _a;}\n");
    static assert(signal!int("a", Protection.protected_)=="protected Signal!(int) _a;\nref RestrictedSignal!(int) a() { return _a;}\n");
    static assert(signal!int("a", Protection.private_)=="private Signal!(int) _a;\nref RestrictedSignal!(int) a() { return _a;}\n");
    static assert(signal!int("a", Protection.none)=="private Signal!(int) _a;\nref Signal!(int) a() { return _a;}\n");
    
    debug (signal)
    {
        pragma(msg, signal!int("a", Protection.package_));
        pragma(msg, signal!(int, string, int[int])("a", Protection.private_));
        pragma(msg, signal!(int, string, int[int], float, double)("a", Protection.protected_));
        pragma(msg, signal!(int, string, int[int], float, double, long)("a", Protection.none));
    }
}

unittest // Test nested emit/removal/addition ...
{
    Signal!() sig;
    bool doEmit = true;
    int counter = 0;
    int slot3called = 0;
    int slot3shouldcalled = 0;
    void slot1()
    {
        doEmit = !doEmit;
        if (!doEmit)
            sig.emit();
    }
    void slot3()
    {
        slot3called++;
    }
    void slot2()
    {
        debug (signal) { import std.stdio; writefln("\nCALLED: %s, should called: %s", slot3called, slot3shouldcalled);}
        assert (slot3called == slot3shouldcalled);
        if ( ++counter < 100) 
            slot3shouldcalled += counter;
        if ( counter < 100 )
            sig.strongConnect(&slot3);
    }
    void slot4()
    {
        if ( counter == 100 )
            sig.strongDisconnect(&slot3); // All connections dropped
    }
    sig.strongConnect(&slot1);
    sig.strongConnect(&slot2);
    sig.strongConnect(&slot4);
    for (int i=0; i<1000; i++)
        sig.emit();
    debug (signal)
    {
        import std.stdio;
        writeln("slot3called: ", slot3called);
    }
}
/* vim: set ts=4 sw=4 expandtab : */
