/**
`rcstring` is a reference-counted string which is based on
$(REF Array, std,experimental,collections) of `ubyte`s.
By default, `rcstring` is not a range. Various helpers can be used to specify
the iteration mode.
`rcstring` internally stores the string as UTF-8 $(REF Array, std.experimental.allocator,collections,array).

$(UL
    $(LI `.chars` - iterates over individual `char` characters. No auto-decoding is done.)
    $(LI `.wchars` - iterates over `wchar` characters. Auto-decoding is done.)
    $(LI `.dchars` - iterates over `dchar` characters. Auto-decoding is done.)
    $(LI `.ubytes` - iterates over the raw `ubyte` representation. No auto-decoding is done.
    This is similar to $(REF representation, std,string) for built-in strings)
)

If no allocator was provided when the array was created, the
$(REF, Mallocator, std,experimental,allocator,mallocator) will be used.
*/
module std.experimental.collections.rcstring;

///
@safe unittest
{
    rcstring s = "I'm an rcstring";
    assert(s[0 .. 3] == "I'm"); // You can slice me
    assert(s[7 .. $] == "rcstring"); // till the end

    //static assert(!__traits(compiles, s[0])); // but I don't support indexing
    static assert(!__traits(compiles, s.length)); // nor a length

    // If you want to iterate over me, you need to choose the iteration mode:
    //assert(s.chars[0] == 'I'); // provides indexing (TODO)
    assert(s.wchars.front == 'I');
    assert(s.dchars.front == 'I');

    // Typical string comparison methods are provided out of the box:
    assert(s.startsWith("I'm")); // and accept normal string-like ranges
    //assert(s.endsWith("ing".rcstring)); // or rcstrings // TODO

    // Comparison of rcstring excepts a normalized rcstring
    assert("äöü".rcstring == "äöü");
    // TODO: non-normalized example

    static assert(rcstring.sizeof == size_t.sizeof * 5); // TODO
}

/// Quickstart into rcstring
@safe unittest
{
    assert("".rcstring.empty); // rcstrings can be empty

    rcstring s = "One rcstring";

    // string concatenation is supported:
    assert(s ~ ", two rcstrings" == "One rcstring, two rcstrings");
    assert(s == "One rcstring");

    // directly assigning the new string is possible too:
    s ~= ", two rcstrings";
    assert(s == "One rcstring, two rcstrings");
}

/// `rcstring` support lexicographical ordering
@safe unittest
{
    assert("abc".rcstring == "abc".rcstring);
    assert("abc".rcstring < "abd".rcstring);
    assert("abc".rcstring > "Abd".rcstring);
}

/**
`rcstring` can be used with custom allocators.
An $(REF IAllocator, std,experimental,allocator) needs to be passed though.
However, $(REF allocator, std,experimental,allocator) can be used to convert any allocator into an `IAllocator` object.
By default, `theAllocator` is used.
*/
@system unittest
{
    import std.experimental.allocator : allocatorObject;
    import std.experimental.allocator.mallocator : Mallocator;

    alias alloc = Mallocator.instance;
    auto s = alloc.allocatorObject.rcstring("malloc-allocated rcstring");
}

import std.experimental.collections.common;
import std.experimental.collections.rcstring_phobos;
import std.experimental.collections.array;
import std.range.primitives : isInputRange, ElementType, hasLength;
import std.traits : isDynamicArray, isSomeChar, isSomeString, Unqual;


debug(CollectionRCString) import std.stdio;

version(unittest)
{
    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.building_blocks.stats_collector;
    import std.experimental.allocator : RCIAllocator, RCISharedAllocator,
           allocatorObject, sharedAllocatorObject;
    import std.algorithm.mutation : move;
    import std.stdio;

    private alias SCAlloc = StatsCollector!(Mallocator, Options.bytesUsed);
}

private template isRCStringable(R)
{
    enum isRCStringable = is(typeof(R.init.rcstring));
}

@safe unittest
{
    static assert(isRCStringable!string);
    static assert(isRCStringable!wstring);
    static assert(isRCStringable!wstring);
    static assert(!isRCStringable!int);
    static assert(isRCStringable!(char[]));
}

@safe unittest
{
    import std.range : take;
    import std.utf : byCodeUnit;
    static assert(isRCStringable!(typeof("foo".take(2))));
    static assert(isRCStringable!(typeof("foo".byCodeUnit.take(2))));
}

///
struct rcstring
{
private:
    Array!ubyte _support;
public:

    /**
     Constructs a qualified rcstring that will use the provided
     allocator object. For `immutable` objects, a `RCISharedAllocator` must
     be supplied.

     Params:
          allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                      $(REF RCISharedAllocator, std,experimental,allocator)
                      allocator object

     Complexity: $(BIGOH 1)
    */
    this(A, this Q)(A allocator)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator)))
    {
        debug(CollectionRCString)
        {
            writefln("rcstring.ctor: begin");
            scope(exit) writefln("rcstring.ctor: end");
        }
        static if (is(Q == immutable) || is(Q == const))
        {
            auto alloc = immutable AllocatorHandler(allocator);
            //_support.setAllocator(alloc); // TODO
        }
        else
            _support.setAllocator(allocator);
    }

    ///
    @safe unittest
    {
        import std.experimental.allocator : theAllocator, processAllocator;

        auto a = rcstring(theAllocator);
        auto ca = const rcstring(processAllocator);
        auto ia = immutable rcstring(processAllocator);
    }

    /**
    Constructs a qualified rcstring out of a number of bytes
    that will use the provided allocator object.
    For `immutable` objects, a `RCISharedAllocator` must be supplied.
    If no allocator is passed, the default allocator will be used.

    Params:
         allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                     $(REF RCISharedAllocator, std,experimental,allocator)
                     allocator object
         bytes = a variable number of bytes, either in the form of a
                  list or as a built-in rcstring

    Complexity: $(BIGOH m), where `m` is the number of bytes.
    */
    this()(ubyte[] bytes...)
    {
        this(defaultAllocator!(typeof(this)), bytes);
    }

    ///
    @safe unittest
    {
        // Create a list from a list of bytes
        auto a = rcstring('1', '2', '3');

        // Create a list from an array of bytes
        auto b = rcstring(['1', '2', '3']);

        // Create a const list from a list of bytes
        auto c = const rcstring('1', '2', '3');
    }

    /// ditto
    this(A, this Q)(A allocator, ubyte[] bytes...)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator)))
    {
        this(allocator);
        _support = typeof(_support)(allocator, bytes);
    }

    ///
    @safe unittest
    {
        import std.experimental.allocator : theAllocator, processAllocator;

        // Create a list from a list of ints
        auto a = rcstring(theAllocator, '1', '2', '3');

        // Create a list from an array of ints
        auto b = rcstring(theAllocator, ['1', '2', '3']);
    }

    /**
    Constructs a qualified rcstring out of a string
    that will use the provided allocator object.
    For `immutable` objects, a `RCISharedAllocator` must be supplied.
    If no allocator is passed, the default allocator will be used.

    Params:
         allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                     $(REF RCISharedAllocator, std,experimental,allocator)
                     allocator object
         s = input string

    Complexity: $(BIGOH m), where `m` is the number of bytes of the input string.
    */
    this()(const(char)[] s)
    {
        import std.string : representation;
        import std.utf : byChar;
        this(defaultAllocator!(typeof(this)), s.dup.representation); // TODO: is the .dup necessary?
    }

    /**
    Constructs a qualified rcstring out of an input range
    that will use the provided allocator object.
    For `immutable` objects, a `RCISharedAllocator` must be supplied.
    If no allocator is passed, the default allocator will be used.

    Params:
         allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                     $(REF RCISharedAllocator, std,experimental,allocator)
                     allocator object
         r = input range

    Complexity: $(BIGOH n), where `n` is the number of elements of the input range.
    */
    this(this Q, A, R)(A allocator, R r)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator))
        && isInputRange!R && isSomeChar!(ElementType!R))
    {
        import std.utf : byChar;
        this(allocator);
        static if (hasLength!R)
        {
            // TODO: this might be a bit too eager
            static if (is(ElementType!R == dchar))
                _support.reserve(r.length * 4);
            else static if (is(ElementType!R == dchar))
                _support.reserve(r.length * 2);
            else
                _support.reserve(r.length);
        }
        foreach (e; r.byChar)
            _support ~= cast(ubyte) e;
    }

    /// ditto
    this(this Q, R)(R r)
    if (isInputRange!R && isSomeChar!(ElementType!R))
    {
        this(defaultAllocator!(typeof(this)), r);
    }

    /// Construct a rcstring from a string
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        auto s = rcstring("dlang");
        assert(s.chars.equal("dlang"));
    }

    /// Construct a rcstring from a wstring
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        auto s = rcstring("dlang"w);
        assert(s.chars.equal("dlang"));
    }

    /// Construct a rcstring from a dstring
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        auto s = rcstring("dlang"d);
        assert(s.chars.equal("dlang"));
    }

    ///
    @system unittest
    {
        import std.experimental.allocator : allocatorObject;
        import std.experimental.allocator.mallocator : Mallocator;

        auto alloc = Mallocator.instance.allocatorObject;
        auto s = rcstring(alloc, "malloc-allocated rcstring");
        auto s2 = rcstring(alloc, "malloc-allocated rcstring"w);
        auto s3 = rcstring(alloc, "malloc-allocated rcstring"d);
    }

    ///
    @safe unittest
    {
        import std.range : take;
        import std.utf : byCodeUnit;
        auto s = rcstring("dlang".byCodeUnit.take(10));
        assert(s.equal("dlang"));
    }

    /**
    Constructs a qualified rcstring out of an input range
    that will use the provided allocator object.
    For `immutable` objects, a `RCISharedAllocator` must be supplied.
    If no allocator is passed, the default allocator will be used.

    Params:
         allocator = a $(REF RCIAllocator, std,experimental,allocator) or
                     $(REF RCISharedAllocator, std,experimental,allocator)
                     allocator object
         r = input range

    Complexity: $(BIGOH n), where `n` is the number of elements of the input range.
    */
    this(this Q, R)(R r)
    if (isInputRange!(typeof(r)) && is(ElementType!(typeof(r)) == ubyte))
    {
        this(defaultAllocator!(typeof(this)), r);
    }

    /// ditto
    this(this Q, A, R)(A allocator, R r)
    if (!is(Q == shared)
        && (is(A == RCISharedAllocator) || !is(Q == immutable))
        && (is(A == RCIAllocator) || is(A == RCISharedAllocator))
        && isInputRange!(typeof(r)) && is(ElementType!(typeof(r)) == ubyte)
        && !isDynamicArray!R)
    {
        this(allocator);
        static if (hasLength!R)
            _support.reserve(r.length);
        foreach (e; r)
            _support ~= e;
    }

    ///
    @safe unittest
    {
        import std.range : iota, repeat, take;
        assert(ubyte(65).repeat.take(3).rcstring.equal("AAA"));
        assert(ubyte(65).iota(ubyte(68)).rcstring.equal("ABC"));
    }

    ///
    @nogc nothrow pure @safe
    bool empty() const
    {
        return _support.empty;
    }

    ///
    @safe unittest
    {
        assert(!rcstring("dlang").empty);
        assert(rcstring("").empty);
    }

    ///
    private auto by(T)() @trusted
    if (is(T == char) || is(T == wchar) || is(T == dchar))
    {
        Array!char tmp = *cast(Array!char*)(&_support);
        static if (is(T == char))
        {
            return tmp;
        }
        else
        {
            import std.utf : byUTF;
            return tmp.byUTF!T();
        }
    }

    // test empty ranges
    unittest
    {
        import std.range : iota;
        assert(char(65).iota(char(3)).rcstring.equal(""));
        import std.algorithm.comparison : equal;
        assert("".rcstring.by!char.equal(""));
        assert("".rcstring.by!dchar.equal(""));
    }

    /// Returns the rcstring as a range of `char`s
    auto chars()
    {
        return by!char;
    }

    ///
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        import std.utf : byChar, byWchar;
        auto hello = rcstring("你好");
        assert(hello.chars.equal("你好".byChar));
    }

    /// Returns the rcstring as a range of `wchar`s
    auto wchars()
    {
        return by!wchar;
    }

    ///
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        import std.utf : byChar, byWchar;
        auto hello = rcstring("你好");
        assert(hello.wchars.equal("你好".byWchar));
    }

    /// Returns the rcstring as a range of `dchar`s
    auto dchars()
    {
        return by!dchar;
    }

    ///
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        import std.utf : byChar, byWchar;
        auto hello = rcstring("你好");
        assert(hello.dchars.equal("你好"));
    }

    /// Returns the rcstring as a range of `ubyte`s
    auto bytes()
    {
        return _support;
    }

    ///
    @system unittest
    {
        import std.algorithm.comparison : equal;
        assert("ABC".rcstring.bytes.equal([65, 66, 67]));
    }

    ///
    typeof(this) opBinary(string op)(typeof(this) rhs)
    if (op == "~")
    {
        rcstring s = this;
        s._support ~= rhs._support;
        return s;
    }

    /// ditto
    typeof(this) opBinary(string op, C)(C c)
    if (op == "~" && isSomeChar!C)
    {
        rcstring s = this;
        s._support ~= cast(ubyte) c;
        return s;
    }

    /// ditto
    typeof(this) opBinary(string op, R)(R r)
    if (op == "~" && isInputRange!R && isSomeChar!(ElementType!R))
    {
        rcstring s = this;
        static if (hasLength!R)
            s._support.reserve(s._support.length + r.length);
        foreach (el; r)
        {
            s._support ~= cast(ubyte) el;
        }
        return s;
    }

    /// ditto
    typeof(this) opBinaryRight(string op, R)(R lhs)
    if (op == "~" && isInputRange!R && isSomeChar!(ElementType!R))
    {
        auto s = rcstring(lhs);
        rcstring rcs = this;
        s._support ~= rcs._support;
        return s;
    }

    /// ditto
    typeof(this) opBinaryRight(string op, C)(C c)
    if (op == "~" && isSomeChar!C)
    {
        rcstring rcs = this;
        rcs._support.insert(0, cast(ubyte) c);
        return rcs;
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abc");
        auto r2 = rcstring("def");
        assert((r1 ~ r2).equal("abcdef"));
        assert((r1 ~ "foo").equal("abcfoo"));
        assert(("abc" ~ r2).equal("abcdef"));
        assert((r1 ~ 'd').equal("abcd"));
        assert(('a' ~ r2).equal("adef"));
    }

    ///
    @safe unittest
    {
        import std.range : take;
        import std.utf : byCodeUnit;
        auto r1 = rcstring("abc");
        auto r2 = "def".byCodeUnit.take(3);
        assert((r1 ~ r2).equal("abcdef"));
        assert((r2 ~ r1).equal("defabc"));
    }

version(none)
{
    ///
    auto opBinary(string op)(typeof(this) rhs)
    if (op == "in")
    {
        // TODO
        import std.algorithm.searching : find;
        return this.chars.find(rhs.chars);
    }

    auto opBinaryRight(string op)(string rhs)
    if (op == "in")
    {
        // TODO
        import std.algorithm.searching : find;
        return rhs.find(this.chars);
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abc");
        auto r2 = rcstring("def");
        auto rtext = rcstring("abcdefgh");
        //import std.stdio;
        //(r1 in rtext).writeln;
        //(r1 in rtext).writeln;
    }
}

    ///
    typeof(this) opOpAssign(string op)(typeof(this) rhs)
    if (op == "~")
    {
        _support ~= rhs._support;
        return this;
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abc");
        r1 ~= rcstring("def");
        assert(r1.equal("abcdef"));
    }

    /// ditto
    typeof(this) opOpAssign(string op)(const(char)[] rhs)
    if (op == "~")
    {
        import std.string : representation;
        _support ~= rhs.representation;
        return this;
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abc");
        r1 ~= "def";
        assert(r1.equal("abcdef"));
    }

    typeof(this) opOpAssign(string op, C)(C c)
    if (op == "~" && isSomeChar!C)
    {
        _support ~= cast(ubyte) c;
        return this;
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abc");
        r1 ~= 'd';
        assert(r1.equal("abcd"));
    }

    ///
    typeof(this) opOpAssign(string op, R)(R r)
    if (op == "~" && isSomeChar!(ElementType!R) && isInputRange!R && !is(R : const(char)[]))
    {
        _support ~= rcstring(r)._support;
        return this;
    }

    ///
    @safe unittest
    {
        import std.range : take;
        import std.utf : byCodeUnit;
        auto r1 = rcstring("abc");
        r1 ~= "foo".byCodeUnit.take(4);
        assert(r1.equal("abcfoo"));
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abc");
        r1 ~= "def"w;
        assert(r1.equal("abcdef"));
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abc");
        r1 ~= "def"d;
        assert(r1.equal("abcdef"));
    }

    ///
    bool opEquals()(auto ref typeof(this) rhs) const
    {
        return _support == rhs._support;
    }

    ///
    @safe unittest
    {
        assert(rcstring("abc") == rcstring("abc"));
        assert(rcstring("abc") != rcstring("Abc"));
        assert(rcstring("abc") != rcstring("abd"));
        assert(rcstring("abc") != rcstring(""));
        assert(rcstring("") == rcstring(""));
    }

    /// ditto
    bool opEquals()(const(char[]) rhs) const
    {
        import std.string : representation;
        import std.algorithm.comparison : equal;
        return _support._payload.equal(rhs.representation);
    }

    ///
    @safe unittest
    {
        assert(rcstring("abc") == "abc");
        assert(rcstring("abc") != "Abc");
        assert(rcstring("abc") != "abd");
        assert(rcstring("abc") != "");
        assert(rcstring("") == "");
    }

    /// ditto
    bool opEquals(R)(R r)
    if (isSomeChar!(ElementType!R) && isInputRange!R && !is(R : const(char)[]))
    {
        import std.algorithm.comparison : equal;
        return _support.equal(r);
    }

    ///
    @safe unittest
    {
        import std.range : take;
        import std.utf : byCodeUnit;
        assert(rcstring("abc") == "abc".byCodeUnit.take(3));
        assert(rcstring("abc") != "Abc".byCodeUnit.take(3));
        assert(rcstring("abc") != "abd".byCodeUnit.take(3));
        assert(rcstring("abc") != "".byCodeUnit.take(3));
        assert(rcstring("") == "".byCodeUnit.take(3));
    }

    @safe unittest
    {
        assert(rcstring("abc") == "abc"w);
        assert(rcstring("abc") != "Abc"d);
        assert(rcstring("abc") != "abd"w);
        assert(rcstring("abc") != ""w);
        assert(rcstring("") == ""d);
    }

    ///
    int opCmp()(auto ref typeof(this) rhs)
    {
        return _support.opCmp(rhs._support);
    }

    ///
    @safe unittest
    {
        assert(rcstring("abc") <= rcstring("abc"));
        assert(rcstring("abc") >= rcstring("abc"));
        assert(rcstring("abc") > rcstring("Abc"));
        assert(rcstring("Abc") < rcstring("abc"));
        assert(rcstring("abc") < rcstring("abd"));
        assert(rcstring("abc") > rcstring(""));
        assert(rcstring("") <= rcstring(""));
        assert(rcstring("") >= rcstring(""));
    }

    /// ditto
    int opCmp()(const(char[]) rhs)
    {
        import std.string : representation;
        return _support.opCmp(rhs.representation);
    }

    ///
    @safe unittest
    {
        assert(rcstring("abc") <= "abc");
        assert(rcstring("abc") >= "abc");
        assert(rcstring("abc") > "Abc");
        assert(rcstring("Abc") < "abc");
        assert(rcstring("abc") < "abd");
        assert(rcstring("abc") > "");
        assert(rcstring("") <= "");
        assert(rcstring("") >= "");
    }

    /// ditto
    int opCmp(R)(R rhs)
    if (isSomeChar!(ElementType!R) && isInputRange!R && !is(R : const(char)[]))
    {
        static if (is(ElementType == char))
        {
            import std.string : representation;
            return _support.opCmp(rhs);
        }
        else
        {
            return opCmp(rhs.rcstring); // TODO
        }
    }

    ///
    @safe unittest
    {
        import std.range : take;
        import std.utf : byCodeUnit;
        assert(rcstring("abc") <= "abc".byCodeUnit.take(3));
        assert(rcstring("abc") >= "abc".byCodeUnit.take(3));
        assert(rcstring("abc") > "Abc".byCodeUnit.take(3));
        assert(rcstring("Abc") < "abc".byCodeUnit.take(3));
        assert(rcstring("abc") < "abd".byCodeUnit.take(3));
        assert(rcstring("abc") > "".byCodeUnit.take(3));
        assert(rcstring("") <= "".byCodeUnit.take(3));
        assert(rcstring("") >= "".byCodeUnit.take(3));
    }

    @safe unittest
    {
        assert(rcstring("abc") <= "abc"w);
        assert(rcstring("abc") >= "abc"d);
        assert(rcstring("abc") > "Abc"w);
        assert(rcstring("Abc") < "abc"d);
    }

    ///
    auto opSlice(size_t start, size_t end)
    {
        rcstring s = save;
        s._support = s._support[start .. end];
        return s;
    }

    ///
    @safe unittest
    {
        auto a = rcstring("abcdef");
        assert(a[2 .. $].equal("cdef"));
        assert(a[0 .. 2].equal("ab"));
        assert(a[3 .. $ - 1].equal("de"));
    }

    ///
    auto opDollar()
    {
        return _support.length;
    }

    ///
    auto save()
    {
        rcstring s = this;
        return s;
    }

    ///
    auto opSlice()
    {
        return this.save;
    }

    ///
    auto opSliceAssign(char c, size_t start, size_t end)
    {
        _support[start .. end] = cast(ubyte) c;
    }

    ///
    @safe unittest
    {
        auto r1 = rcstring("abcdef");
        r1[2..4] = '0';
        assert(r1.equal("ab00ef"));
    }

    ///
    bool opCast(T : bool)()
    {
        return !empty;
    }

    ///
    @safe unittest
    {
        assert(rcstring("foo"));
        assert(!rcstring(""));
    }

    /// ditto
    auto ref opAssign()(rcstring rhs)
    {
        _support = rhs._support;
        return this;
    }

    /// ditto
    auto ref opAssign(R)(R rhs)
    if (isRCStringable!R && !is(R == rcstring))
    {
        _support = rcstring(rhs)._support;
        return this;
    }

    ///
    @safe unittest
    {
        auto rc = rcstring("foo");
        assert(rc.equal("foo"));
        rc = rcstring("bar1");
        assert(rc.equal("bar1"));
        rc = "bar2";
        assert(rc.equal("bar2"));

        import std.range : take;
        import std.utf : byCodeUnit;
        rc = "bar3".take(10).byCodeUnit;
        assert(rc.equal("bar3"));
    }

    @safe unittest
    {
        rcstring rc = "bar2"w;
        assert(rc.equal("bar2"));
        rc = "bar3"d;
        assert(rc.equal("bar3"));
    }

    ///
    auto dup()()
    {
        return chars.rcstring;
    }

    ///
    @safe unittest
    {
        auto s = rcstring("foo");
        s = rcstring("bar");
        assert(s.equal("bar"));
        auto s2 = s.dup;
        s2 = rcstring("fefe");
        assert(s.equal("bar"));
        assert(s2.equal("fefe"));
    }

    ///
    auto idup()()
    {
        return rcstring!(immutable(char))(chars);
    }

    ///
    @safe unittest
    {
        auto s = rcstring("foo");
        s = rcstring("bar");
        assert(s.equal("bar"));
        auto s2 = s.dup;
        s2 = rcstring("fefe");
        assert(s.equal("bar"));
        assert(s2.equal("fefe"));
    }

    ///
    auto opIndex(size_t pos)
    in
    {
        assert(pos < _support.length, "Invalid position.");
    }
    body
    {
        return _support[pos];
    }

    ///
    @safe unittest
    {
        auto s = rcstring("bar");
        assert(s[0] == 'b');
        assert(s[1] == 'a');
        assert(s[2] == 'r');
    }

    ///
    auto opIndexAssign(char el, size_t pos)
    in
    {
        assert(pos < _support.length, "Invalid position.");
    }
    body
    {
        return _support[pos] = cast(ubyte) el;
    }

    ///
    @safe unittest
    {
        auto s = rcstring("bar");
        assert(s[0] == 'b');
        s[0] = 'f';
        assert(s.equal("far"));
    }

    ///
    auto opIndexAssign(char c)
    {
        _support[] = cast(ubyte) c;
    }

    ///
    auto toHash() const
    {
        return _support.hashOf;
    }

    ///
    @safe unittest
    {
        auto rc = rcstring("abc");
        assert(rc.toHash == rcstring("abc").toHash);
        rc ~= 'd';
        assert(rc.toHash == rcstring("abcd").toHash);
        assert(rcstring().toHash == rcstring().toHash);
    }

    /**
    Checks if the given `rcstring` starts with (one of) the given needle(s). The reciprocal of $(LREF endsWith).

    Params:
        needles = The needles to check against

    Returns:
        0 if the needle(s) do not occur at the end of the given range; otherwise the position of the matching needle, that is, 1 if the range ends with withOneOfThese[0], 2 if it ends with withOneOfThese[1], and so on.
    */
    bool startsWith()(rcstring a)
    {
        import std.algorithm.searching : startsWith;
        return chars.startsWith(a.chars);
    }

    /// ditto
    bool startsWith(R)(R a)
    if (isInputRange!R && isSomeChar!(Unqual!(ElementType!R)))
    {
        import std.algorithm.searching : startsWith;
        return chars.startsWith(a);
    }

    ///
    @safe unittest
    {
        assert("foobar".rcstring.startsWith("foo".rcstring));
        assert(!"foobar".rcstring.startsWith("fooc"));
    }

    @safe unittest
    {
        assert("foobar".rcstring.startsWith("foo"w));
        assert("foobar".rcstring.startsWith("foo"d));
    }

    /**
    Checks if the given `rcstring` ends with (one of) the given needle(s). The reciprocal of $(LREF startsWith).

    Params:
        needles = The needles to check against

    Returns:
        0 if the needle(s) do not occur at the end of the given range; otherwise the position of the matching needle, that is, 1 if the range ends with withOneOfThese[0], 2 if it ends with withOneOfThese[1], and so on.
    */
    int endsWith()(rcstring needles...)
    {
        import std.algorithm.searching : endsWith;
        import std.range : retro;
        // TODO: extend by to be bi-directional
        //return chars.retro.endsWith(needles[0].chars.retro);
        return 0;
    }

    /// ditto
    bool endsWith(R)(R a)
    if (isInputRange!R && isSomeChar!(Unqual!(ElementType!R)))
    {
        import std.algorithm.searching : endsWith;
        import std.range : retro;
        // TODO: extend by to be bi-directional
        //return chars.retro.startsWith(a.retro);
        return 0;
    }

    ///
    @safe unittest
    {
        //assert("foobar".rcstring.endsWith("bar".rcstring));
        //assert(!"foobar".rcstring.endsWith("foo"));
    }

    /**
    Capitalize a string.

    Returns: the current string with the first character in uppercase.
    */
    rcstring capitalize()()
    {
        import std.uni : asCapitalized;
        import std.conv : text;
        import std.string : capitalize;
        return chars.text.capitalize.rcstring;
    }

    ///
    @system unittest
    {
        assert("foo".rcstring.capitalize == "Foo");
        assert("Foo".rcstring.capitalize == "Foo");
        assert("foF".rcstring.capitalize == "Fof");
    }

    ///
    rcstring replace()(rcstring a, rcstring b)
    {
        import std.array : array, replace;
        import std.exception : assumeUnique;
        return chars.array.replace(a.chars, b.chars).assumeUnique.rcstring;
    }

    @system unittest
    {
        assert("foobar".rcstring.replace("foo".rcstring, "bar".rcstring));
    }

    /**
    Upper-cases a string.

    Returns: A range of the rcstring with all characters replaced with
    their lowercase analog.
    */
    auto asLower()()
    {
        import std.uni : asLowerCase;
        return chars.asLowerCase;
    }

    ///
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        assert("FooBAR".rcstring.asLower.equal("foobar"));
    }

    /**
    Upper-cases a string.

    Returns: A range of the rcstring with all characters replaced with
    their uppercase analog.
    */
    auto asUpper()()
    {
        import std.uni : asUpperCase;
        return chars.asUpperCase;
    }

    ///
    @safe unittest
    {
        import std.algorithm.comparison : equal;
        assert("fooBar".rcstring.asUpper.equal("FOOBAR"));
    }

    /**
    Checks whether the current string consists only of valid UTF characters.

    Returns: `true` if only valid characters exist, `false` otherwise.
    */
    bool isValid()()
    {
        import std.utf : decode, UTFException;
        auto s = cast(char[]) _support._payload;
        try
        {
            for (size_t i = 0; i < s.length; )
                decode(s, i);
        } catch (UTFException)
        {
            return false;
        }
        return true;
    }

    ///
    @safe unittest
    {
        assert("foo".rcstring.isValid);
        assert("föö".rcstring.isValid);
        assert(!rcstring('a', cast(char) 255).isValid);
    }

    /**
    Create a null-terminated string of the `rcstring` s.

    `s` must not contain embedded `'\0'`'s as any C function will treat the first `'\0'`
    that it sees as the end of the string.

    Warning: this allocates new memory with the garbage collector

    Important_Note: When passing a `char*` to a C function, and the C function keeps it around for any reason, make sure that you keep a reference to it in your D code.
    Otherwise, it may become invalid during a garbage collection cycle and cause a nasty bug when the C code tries to use it.

    Returns:
        C-style null-terminated string equivalent to s.
        If `s.empty` is true, then a string containing only `'\0'` is returned.
    */
    auto toStringz()()
    {
        import std.conv : to;
        import std.string : toStringz;
        return chars.to!string.toStringz;
    }

    ///
    @system unittest
    {
        rcstring s = "foo";
        auto p = s.toStringz;
        assert(p[s.chars.length] == '\0');
    }

    string toString()
    {
        import std.conv : to;
        return chars.to!string;
    }

    ///
    @system unittest
    {
        assert("foo".rcstring.toString == "foo");
    }
}

/// Usage in @nogc
// TODO
@safe unittest
{
    import std.array : staticArray;
    auto rc = "Hello @nogc rcstring".staticArray.rcstring;
}

@safe unittest
{
    import std.algorithm.comparison : equal;

    auto buf = cast(ubyte[])("aaa".dup);
    auto s = buf.rcstring;

    assert(equal(s.chars, "aaa"));
    s.chars.front = 'b';
    assert(equal(s.chars, "baa"));
}

@safe unittest
{
    import std.algorithm.comparison : equal;

    auto buf = cast(ubyte[])("hell\u00F6".dup);
    auto s = buf.rcstring;

    assert(s.chars.equal(['h', 'e', 'l', 'l', 0xC3, 0xB6]));

    // `wchar`s are able to hold the ö in a single element (UTF-16 code unit)
    assert(s.wchars().equal(['h', 'e', 'l', 'l', 'ö']));
}

@safe unittest
{
    import std.algorithm.comparison : equal;

    auto buf = cast(ubyte[])("hello".dup);
    auto s = buf.rcstring;
    auto charStr = s.chars;

    charStr[$ - 2] = cast(ubyte) 0xC3;
    charStr[$ - 1] = cast(ubyte) 0xB6;

    assert(s.wchars().equal(['h', 'e', 'l', 'ö']));
}
