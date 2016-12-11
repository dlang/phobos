// Written in the D programming language.

/**
Reusable implementations of common idioms and design patterns.

This module implements boilerplate code and design patterns that assist in the
implementation of the code's architecture.

The $(I Properties) idiom assist in defining property member fields - variables
access by a pair of $(D @property) accessor methods instead of being used
directly.
$(BOOKTABLE ,
    $(TR $(TD $(D $(LREF Properties)))
        $(TD Template mixin used to easily declare property member fields.
    ))
    $(TR $(TD $(D $(LREF Asserting)))
        $(TD UDA that makes a property setter verify it's input using D's
        $(I contracts) mechanism($(D assert)).
    ))
    $(TR $(TD $(D $(LREF Enforcing)))
        $(TD UDA that makes a property setter verify it's input using D's
        $(I exception handling) mechanism.
    ))
)

The $(I Singleton) idiom turns classes to singletons. There is a version for
each one of the three types of globality that D offers:
$(BOOKTABLE ,
    $(TR $(TD $(D $(LREF ThreadLocalSingleton)))
        $(TD A singleton that is local to the thread. Corresponds to D's $(D
        static).
    ))
    $(TR $(TD $(D $(LREF SharedSingleton)))
        $(TD A thread-safe, process-global singleton. Corresponds to D's $(D
        static shared).
    ))
    $(TR $(TD $(D $(LREF __GSharedSingleton)))
        $(TD A process-global singleton, providing thread-safe initialization
        without forcing thread-safe methods. Corresponds to D's $(D ___gshared).
    ))
)

Macros:

WIKI = Phobos/StdIdioms

Copyright: Copyright Idan Arye 2013.
License:   $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   Idan Arye
Source:    $(PHOBOSSRC std/_idioms.d)
*/
/*
         Copyright Idan Arye 2013.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.idioms;

version(unittest)
{
    import std.array, std.conv, std.exception, std.parallelism;
    import core.exception, core.thread, core.sync.barrier;

}

/**
 * Exception thrown in case a property is assigned a value not approved by the
 * enforcement condition of an $(D Enforcing) UDA.
 */
public class PropertyException : Exception
{
    public this(T)(string propertyName, T badValue, string File = __FILE__,
            size_t line = __LINE__, Throwable next = null){
        super("Bad value " ~ badValue.to!string() ~ " for " ~ propertyName, file, line, next);
    }
    public this()(string message, string File = __FILE__,
            size_t line = __LINE__, Throwable next = null){
        super(message, file, line, next);
    }
}

/**
 * Exception thrown in case a user tries to access a singleton instance for a
 * singleton that was not initialized yet and that has no default constructor.
 */
public class SingletonException : Exception
{
    public this()(string message, string File = __FILE__,
            size_t line = __LINE__, Throwable next = null)
    {
        super(message, file, line, next);
    }
}

/**
 * When used as UDA inside $(D Properties), adds an assertion to verify that
 * the value for the property is correct.
 *
 * Unlike $(D Enforcing), Asserting will be disabled when compiled with the
 * $(I -release) flag.
 */
struct Asserting
{
    /**
     * An assertion string that represents the assert condition.  The string
     * must use symbol name $(D a) as the parameter.
     */
    string assertion;

    /**
     * If not null, the message the assert will throw when the assertion fails.
     */
    string message = null;
}


/**
 * When used as UDA inside $(D Properties), adds a check to verify that
 * the value for the property is correct, and throw $(D PropertyException) if
 * it isn't.
 *
 * Unlike $(D Asserting), Enforcing will be enabled when compiled with the
 * -release flag.
 */
struct Enforcing
{
    /**
     * An enforcement string that represents the checked condition.  The string
     * must use symbol name $(D a) as the parameter.
     */
    string enforcement;

    /**
     * If not null, the message for the $(D PropertyException).
     */
    string message = null;
}

/*
 * Used for mixing in the properties member field declarations, and give them a
 * namespace using a mixin identifier.
 */
mixin template _impl_Properties_declarations(string declarationCode)
{
    mixin(declarationCode);
}


/*
 * Used to generates getter and setter property accessors for all the member
 * fields of the properties.
 *
 * Params:
 *      fieldsNamespace = the namespace of the property member fields.
 *      namesHead       = the name of the current property field to generate
 *                        accessors for.
 *      identifiersTail = the rest of the property fields, to send via template
 *                        recursion to the next _impl_Properties_accessors.
 */
mixin template _impl_Properties_accessors(alias fieldsNamespace, string namesHead, identifiersTail...)
{
    mixin(`@property typeof(_fields.` ~ namesHead ~ `) ` ~ namesHead ~ `()` ~ q{
        {
            return __traits(getMember, fieldsNamespace, namesHead);
        }
    });

    mixin(`@property auto ` ~ namesHead ~ `(typeof(_fields.` ~ namesHead ~ `) a)` ~ q{
        {
            foreach(annotation; __traits(getAttributes, __traits(getMember, fieldsNamespace, namesHead)))
            {
                alias typeof(annotation) AnnotationType;
                static if(is(AnnotationType == Asserting))
                {
                    static if(annotation.message == null)
                    {
                        import std.conv;
                        assert(mixin(annotation.assertion), "Bad value " ~ to!string(a) ~ " for " ~ namesHead);
                    }
                    else
                    {
                        assert(mixin(annotation.assertion), annotation.message);
                    }
                }
                else static if(is(AnnotationType == Enforcing))
                {
                    if(!mixin(annotation.enforcement))
                    {
                        static if(annotation.message == null)
                        {
                            throw new PropertyException(namesHead, a);
                        }
                        else
                        {
                            throw new PropertyException(annotation.message);
                        }
                    }
                }
            }
            return __traits(getMember, fieldsNamespace, namesHead) = a;
        }
    });

    mixin _impl_Properties_accessors!(fieldsNamespace, identifiersTail);
}

//End condition for _impl_Properties_accessors
mixin template _impl_Properties_accessors(alias fieldsNamespace) {}

/*
 * Create a string that declares aliases for all the members in a given
 * namespace.
 *
 * Params:
 *      namespace = the namespace to generate aliases for it's members.
 *
 * Returns:
 *      a string for a mixin to generate the aliases.
 */
string _impl_Properties_generateAliases(alias namespace)()
{
    auto result = appender!string();
    foreach(member; __traits(allMembers, namespace))
    {
        result ~= `alias ` ~ __traits(identifier, namespace) ~ `.` ~ member ~ ' ' ~ member ~ ';';
    }
    return result.data;
}

/**
 * Generate property getter and setter accessors for member fields.
 *
 * The member fields must be supplied as a string with member field
 * declarations. Token string is preferred.
 *
 * Use $(D Asserting) and $(D Enforcing) UDAs before properties to verify the
 * values assigned to them.
 *
 * Params:
 *      declarationCode = the code to declare the member fields that will be
 *                        turned into properties.
 */
public mixin template Properties(string declarationCode)
{
    private mixin _impl_Properties_declarations!declarationCode _fields;

    mixin _impl_Properties_accessors!(_fields, __traits(allMembers, _fields)) _accessors;

    mixin(_impl_Properties_generateAliases!_accessors());
}

///
unittest
{
    class Foo{
        mixin Properties!q{
            @Asserting(`a <= y`) int x;
            @Enforcing(`a != 0`) double y = 1;
            @Asserting(`a !is this`) typeof(this) z;
        };
    }

    //typeof(this) works properly
    static assert(is(Foo == typeof(Foo.z)));

    Foo foo = new Foo();

    //Defaults are working
    assert(foo.y == 1);

    //Assignments that doesn't break the conditions:
    foo.x = 1;
    assert(foo.x == 1);

    foo.y = 4.2;
    assert(foo.y == 4.2);

    //Assignments that break the conditions throws appropriate errors/exceptions:
    assertThrown!AssertError(foo.x = 5);
    assertThrown!PropertyException(foo.y = 0);

    //Assignments that break the conditions do not change the values:
    assert(foo.x == 1);
    assert(foo.y == 4.2);

    //Conditons operate in the scope of the struct/object:
    assertThrown!AssertError(foo.z = foo);

    //Works with function local variables:
    mixin Properties!q{
        @Asserting("a < 4") int x;
    };
    assertThrown!AssertError(x = 5);
}


/**
 * Turns the class into a singleon, using David Simcha's and Alexander
 * Terekhov's low lock singleton implementation approach.
 *
 * This version of the $(I Singleton) idiom only synchronizes the
 * $(U initialization) of the singleton. Methods of the instance $(B $(RED are not
 * synchronized automatically)) by $(D __GSharedSingleton).
 *
 * $(B $(RED This template mixin does not create a private constructor!)) A
 * private constructor must be declared separately, otherwise the class could
 * be created from outside.
 */
mixin template _GSharedSingleton()
{
    private __gshared typeof(this) _singleton_instance;
    private static typeof(this) _singleton_local_reference;

    /**
     * Initialize the singleton instance if no instance exists.
     *
     * Params:
     *      instance = the instance to set.
     *
     * Returns:
     *      true if new instance was created, false if there already was an old
     *      instance.
     */
    private static bool singleton_tryInitInstance(lazy typeof(this) instance){
        if(_singleton_local_reference is null)
        {
            synchronized(typeid(typeof(this)))
            {
                if(_singleton_instance is null)
                {
                    _singleton_instance = instance;
                    _singleton_local_reference = _singleton_instance;
                    return true;
                }
                else
                {
                    _singleton_local_reference = _singleton_instance;
                }
            }
        }
        return false;
    }

    /**
     * Initialize the singleton instance. Fails if instance already exists.
     *
     * Params:
     *      instance = the instance to set.
     *
     * Throws:
     *      SingletonException if instance already exists.
     */
    private static void singleton_initInstance(lazy typeof(this) instance){
        if(!singleton_tryInitInstance(instance))
        {
            throw new SingletonException(typeof(this).stringof ~ " is already initialized.");
        }
    }

    /**
     * Checks if an instance has already been initialized.
     *
     * Returns:
     *      true if instance was already initialized, false otherwise.
     */
    static @property bool hasInstance(){
        if(_singleton_local_reference !is null)
        {
            return true;
        }
        synchronized(typeid(typeof(this)))
        {
            if(_singleton_instance !is null)
            {
                _singleton_local_reference = _singleton_instance;
                return true;
            }
            return false;
        }
    }

    /**
     * Returns the singleton instance.
     *
     * If the instance does not yet exist, and a default constructor is
     * available, creates the instance using the default constructor.
     *
     * Returns:
     *      The singleton instance.
     */
    static @property typeof(this) instance()
    {
        if(_singleton_local_reference is null)
        {
            //Allow implicit initialization if and only if there is a default constructor:
            static if(__traits(compiles, new typeof(this)()))
            {
                singleton_tryInitInstance(new typeof(this)());
            }
            else
            {
                synchronized(typeid(typeof(this)))
                {
                    if(_singleton_instance is null)
                    {
                        throw new SingletonException(typeof(this).stringof ~
                                " has no default constructor and must be initialized manually.");
                    }
                    else
                    {
                        _singleton_local_reference = _singleton_instance;
                    }
                }
            }
        }
        return _singleton_local_reference;
    }
}

///
unittest
{
    //Singleton with default constructor:
    static class Foo
    {
        mixin _GSharedSingleton;

        private this(){}
    }

    Foo foo = Foo.instance;

    //We initialized it here, so it's initialized in all threads:
    auto checkIfFooIsInitializedInAnotherThread = task!(Foo.hasInstance)();
    checkIfFooIsInitializedInAnotherThread.executeInNewThread();
    assert(checkIfFooIsInitializedInAnotherThread.spinForce());

    //Different threads - same instances:
    auto getFooFromAnotherThread = task!(Foo.instance)();
    getFooFromAnotherThread.executeInNewThread();
    assert(foo == getFooFromAnotherThread.spinForce());

    //Singleton with no default constructor needs to be initialized:
    static class Bar
    {
        mixin _GSharedSingleton;

        private int x;

        private this(int x)
        {
            this.x = x;
        }

        private static void init(int x)
        {
            singleton_tryInitInstance(new Bar(x));
        }

    }

    assertThrown!SingletonException(Bar.instance);

    Bar.init(1);
    assert(Bar.instance.x == 1);

    //Only first initialization works:
    Bar.init(2);
    assert(Bar.instance.x == 1);

    //Even if you try to initialize again from another thread:
    auto getBarFromAnotherThread = task!({
            Bar.init(3);
            return Bar.instance;
            })();
    getBarFromAnotherThread.executeInNewThread();
    assert(Bar.instance == getBarFromAnotherThread.spinForce());
    assert(getBarFromAnotherThread.spinForce().x == 1);
}

//Try to force a read/write race to see if the singleton can evade it:
unittest
{
    enum NUMBER_OF_THREADS = 10;
    static shared int threadsThatPassedTheBarrier = 0;

    static class Foo
    {
        mixin _GSharedSingleton;

        private this()
        {
            //Wait until at least half the threads got a chance to run after
            //passing the barrier:
            while(threadsThatPassedTheBarrier < NUMBER_OF_THREADS / 2)
            {
                //Sleep for 0 seconds to get a context switch:
                Thread.sleep(dur!"msecs"(0));
            }
        }
    }

    Foo[NUMBER_OF_THREADS] foos;
    Thread[NUMBER_OF_THREADS] threads;
    Barrier barrier = new Barrier(NUMBER_OF_THREADS);

    class FooInitializer : Thread
    {
        ulong index;

        this(ulong index)
        {
            super(&run);
            this.index = index;
        }

        void run()
        {
            //Hold all the threads here before releasing them:
            barrier.wait();
            ++threadsThatPassedTheBarrier;
            foos[index] = Foo.instance;
        }
    }

    foreach(i; 0 .. NUMBER_OF_THREADS)
    {
        threads[i] = new FooInitializer(i);
        threads[i].start();
    }

    foreach(thread; threads)
    {
        thread.join();
    }

    foreach(i; 1 .. NUMBER_OF_THREADS)
    {
        assert(foos[0] == foos[i]);
    }
}


/**
 * Turns the class into a thread local singleon.
 *
 * $(B $(RED This template mixin does not create a private constructor!)) A
 * private constructor must be declared separately, otherwise the class could
 * be created from outside.
 */
mixin template ThreadLocalSingleton()
{
    private static typeof(this) _singleton_instance;

    /**
     * Initialize the singleton instance if no instance exists in the current
     * thread.
     *
     * Params:
     *      instance = the instance to set.
     *
     * Returns:
     *      true if new instance was created, false if there already was an old
     *      instance.
     */
    private static bool singleton_tryInitInstance(lazy typeof(this) instance){
        if(_singleton_instance is null)
        {
            _singleton_instance = instance;
            return true;
        }
        return false;
    }

    /**
     * Initialize the singleton instance. Fails if instance already exists in
     * the current thread.
     *
     * Params:
     *      instance = the instance to set.
     *
     * Throws:
     *      SingletonException if instance already exists.
     */
    private static void singleton_initInstance(lazy typeof(this) instance){
        if(!singleton_tryInitInstance(instance))
        {
            throw new SingletonException(typeof(this).stringof ~ " is already initialized.");
        }
    }

    /**
     * Checks if an instance has already been initialized in the current
     * thread.
     *
     * Returns:
     *      true if instance was already initialized in the current thread,
     *      false otherwise.
     */
    static @property bool hasInstance(){
        return _singleton_instance !is null;
    }

    /**
     * Returns the singleton instance for the current thread.
     *
     * If the instance does not yet exist in the current thread, and a default
     * constructor is available, creates the instance using the default
     * constructor.
     *
     * Returns:
     *      The singleton instance.
     */
    static @property typeof(this) instance()
    {
        //Allow implicit initialization if and only if there is a default constructor:
        static if(__traits(compiles, new typeof(this)()))
        {
            singleton_tryInitInstance(new typeof(this)());
        }
        else
        {
            if(_singleton_instance is null)
            {
                throw new SingletonException(typeof(this).stringof ~
                        " has no default constructor and must be initialized manually.");
            }
        }
        return _singleton_instance;
    }
}

///
unittest
{
    //Singleton with default constructor:
    static class Foo
    {
        mixin ThreadLocalSingleton;

        private this(){}
    }

    Foo foo = Foo.instance;

    //Even though we initialized it here, it is still uninitialized in other threads:
    auto checkIfFooIsInitializedInAnotherThread = task!(Foo.hasInstance)();
    checkIfFooIsInitializedInAnotherThread.executeInNewThread();
    assert(!checkIfFooIsInitializedInAnotherThread.spinForce());

    //Different threads - different instances:
    auto getFooFromAnotherThread = task!(Foo.instance)();
    getFooFromAnotherThread.executeInNewThread();
    assert(foo != getFooFromAnotherThread.spinForce());

    //Singleton with no default constructor needs to be initialized:
    static class Bar
    {
        mixin ThreadLocalSingleton;

        private int x;

        private this(int x)
        {
            this.x = x;
        }

        private static void init(int x)
        {
            singleton_tryInitInstance(new Bar(x));
        }

    }

    assertThrown!SingletonException(Bar.instance);

    Bar.init(1);
    assert(Bar.instance.x == 1);

    //Only first initialization in each thread works:
    Bar.init(2);
    assert(Bar.instance.x == 1);

    //But you can still initialize again from another thread:
    auto getBarFromAnotherThread = task!({
            Bar.init(3);
            return Bar.instance;
            })();
    getBarFromAnotherThread.executeInNewThread();
    assert(Bar.instance != getBarFromAnotherThread.spinForce());
    assert(getBarFromAnotherThread.spinForce().x == 3);
}


/**
 * Turns the class into a singleon, using David Simcha's and Alexander
 * Terekhov's low lock singleton implementation approach.
 *
 * This version of the $(I Singleton) idiom creates a shared instance of the
 * singleton object, which means that non-shared instance methods will not be
 * accessible.
 *
 * $(B $(RED This template mixin does not create a private constructor!)) A
 * private constructor must be declared separately, otherwise the class could
 * be created from outside.
 */
mixin template SharedSingleton()
{
    private static shared typeof(this) _singleton_instance;
    private static bool _singleton_is_instantiated;

    /**
     * Initialize the singleton instance if no instance exists.
     *
     * Params:
     *      instance = the instance to set.
     *
     * Returns:
     *      true if new instance was created, false if there already was an old
     *      instance.
     */
    private static bool singleton_tryInitInstance(lazy shared typeof(this) instance){
        if(!_singleton_is_instantiated)
        {
            synchronized(typeid(typeof(this)))
            {
                if(_singleton_instance is null)
                {
                    _singleton_instance = instance;
                    _singleton_is_instantiated = true;
                    return true;
                }
                else
                {
                    _singleton_is_instantiated = true;
                }
            }
        }
        return false;
    }

    /**
     * Initialize the singleton instance. Fails if instance already exists.
     *
     * Params:
     *      instance = the instance to set.
     *
     * Throws:
     *      SingletonException if instance already exists.
     */
    private static void singleton_initInstance(lazy shared typeof(this) instance){
        if(!singleton_tryInitInstance(instance))
        {
            throw new SingletonException(typeof(this).stringof ~ " is already initialized.");
        }
    }

    /**
     * Checks if an instance has already been initialized.
     *
     * Returns:
     *      true if instance was already initialized, false otherwise.
     */
    static @property bool hasInstance(){
        if(_singleton_is_instantiated)
        {
            return true;
        }
        synchronized(typeid(typeof(this)))
        {
            if(_singleton_instance !is null)
            {
                _singleton_is_instantiated = true;
                return true;
            }
            return false;
        }
    }

    /**
     * Returns the singleton instance.
     *
     * If the instance does not yet exist, and a default constructor is
     * available, creates the instance using the default constructor.
     *
     * Returns:
     *      The singleton instance.
     */
    static @property shared(typeof(this)) instance()
    {
        if(!_singleton_is_instantiated)
        {
            //Allow implicit initialization if and only if there is a default constructor:
            static if(__traits(compiles, new shared(typeof(this))()))
            {
                singleton_tryInitInstance(new shared(typeof(this))());
            }
            else
            {
                synchronized(typeid(typeof(this)))
                {
                    if(_singleton_instance is null)
                    {
                        throw new SingletonException(typeof(this).stringof ~
                                " has no default constructor and must be initialized manually.");
                    }
                    else
                    {
                        _singleton_is_instantiated = true;
                    }
                }
            }
        }
        return _singleton_instance;
    }
}

///
unittest
{
    //Singleton with default constructor:
    static shared class Foo
    {
        mixin SharedSingleton;

        private this(){}
    }

    shared(Foo) foo = Foo.instance;

    //We initialized it here, so it's initialized in all threads:
    auto checkIfFooIsInitializedInAnotherThread = task!(Foo.hasInstance)();
    checkIfFooIsInitializedInAnotherThread.executeInNewThread();
    assert(checkIfFooIsInitializedInAnotherThread.spinForce());

    //Different threads - same instances:
    auto getFooFromAnotherThread = task!(Foo.instance)();
    getFooFromAnotherThread.executeInNewThread();
    assert(foo == getFooFromAnotherThread.spinForce());

    //Singleton with no default constructor needs to be initialized:
    static shared class Bar
    {
        mixin SharedSingleton;

        private int x;

        private this(int x)
        {
            this.x = x;
        }

        private static void init(int x)
        {
            singleton_tryInitInstance(new shared(Bar)(x));
        }

    }

    assertThrown!SingletonException(Bar.instance);

    Bar.init(1);
    assert(Bar.instance.x == 1);

    //Only first initialization works:
    Bar.init(2);
    assert(Bar.instance.x == 1);

    //Even if you try to initialize again from another thread:
    auto getBarFromAnotherThread = task!({
            Bar.init(3);
            return Bar.instance;
            })();
    getBarFromAnotherThread.executeInNewThread();
    assert(Bar.instance == getBarFromAnotherThread.spinForce());
    assert(getBarFromAnotherThread.spinForce().x == 1);
}

//Try to force a read/write race to see if the singleton can evade it:
unittest
{
    enum NUMBER_OF_THREADS = 10;
    static shared int threadsThatPassedTheBarrier = 0;

    static shared class Foo
    {
        mixin SharedSingleton;

        private this()
        {
            //Wait until at least half the threads got a chance to run after
            //passing the barrier:
            while(threadsThatPassedTheBarrier < NUMBER_OF_THREADS / 2)
            {
                //Sleep for 0 seconds to get a context switch:
                Thread.sleep(dur!"msecs"(0));
            }
        }
    }

    shared(Foo)[NUMBER_OF_THREADS] foos;
    Thread[NUMBER_OF_THREADS] threads;
    Barrier barrier = new Barrier(NUMBER_OF_THREADS);

    class FooInitializer : Thread
    {
        ulong index;

        this(ulong index)
        {
            super(&run);
            this.index = index;
        }

        void run()
        {
            //Hold all the threads here before releasing them:
            barrier.wait();
            ++threadsThatPassedTheBarrier;
            foos[index] = Foo.instance;
        }
    }

    foreach(i; 0 .. NUMBER_OF_THREADS)
    {
        threads[i] = new FooInitializer(i);
        threads[i].start();
    }

    foreach(thread; threads)
    {
        thread.join();
    }

    foreach(i; 1 .. NUMBER_OF_THREADS)
    {
        assert(foos[0] == foos[i]);
    }
}
