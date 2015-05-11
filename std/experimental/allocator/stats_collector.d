module std.experimental.allocator.stats_collector;

import std.experimental.allocator.common;

/**
_Options for $(D StatsCollector) defined below. Each enables during
compilation one specific counter, statistic, or other piece of information.
*/
enum Options : uint
{
    /**
    Counts the number of calls to $(D owns).
    */
    numOwns = 1u << 0,
    /**
    Counts the number of calls to $(D allocate). All calls are counted,
    including requests for zero bytes or failed requests.
    */
    numAllocate = 1u << 1,
    /**
    Counts the number of calls to $(D allocate) that succeeded, i.e. they were
    for more than zero bytes and returned a non-null block.
    */
    numAllocateOK = 1u << 2,
    /**
    Counts the number of calls to $(D expand), regardless of arguments or
    result.
    */
    numExpand = 1u << 3,
    /**
    Counts the number of calls to $(D expand) that resulted in a successful
    expansion.
    */
    numExpandOK = 1u << 4,
    /**
    Counts the number of calls to $(D reallocate), regardless of arguments or
    result.
    */
    numReallocate = 1u << 5,
    /**
    Counts the number of calls to $(D reallocate) that succeeded.
    (Reallocations to zero bytes count as successful.)
    */
    numReallocateOK = 1u << 6,
    /**
    Counts the number of calls to $(D reallocate) that resulted in an in-place
    reallocation (no memory moved). If this number is close to the total number
    of reallocations, that indicates the allocator finds room at the current
    block's end in a large fraction of the cases, but also that internal
    fragmentation may be high (the size of the unit of allocation is large
    compared to the typical allocation size of the application).
    */
    numReallocateInPlace = 1u << 7,
    /**
    Counts the number of calls to $(D deallocate).
    */
    numDeallocate = 1u << 8,
    /**
    Counts the number of calls to $(D deallocateAll).
    */
    numDeallocateAll = 1u << 9,
    /**
    Chooses all $(D numXxx) flags.
    */
    numAll = (1u << 10) - 1,
    /**
    Tracks bytes currently allocated by this allocator. This number goes up
    and down as memory is allocated and deallocated, and is zero if the
    allocator currently has no active allocation.
    */
    bytesUsed = 1u << 10,
    /**
    Tracks total cumulative bytes allocated by means of $(D allocate),
    $(D expand), and $(D reallocate) (when resulting in an expansion). This
    number always grows and indicates allocation traffic. To compute bytes
    deallocated cumulatively, subtract $(D bytesUsed) from $(D bytesAllocated).
    */
    bytesAllocated = 1u << 11,
    /**
    Tracks the sum of all $(D delta) values in calls of the form
    $(D expand(b, delta)) that succeed (return $(D true)).
    */
    bytesExpanded = 1u << 12,
    /**
    Tracks the sum of all $(D b.length - s) with $(D b.length > s) in calls of
    the form $(D realloc(b, s)) that succeed (return $(D true)).
    */
    bytesContracted = 1u << 13,
    /**
    Tracks the sum of all bytes moved as a result of calls to $(D realloc) that
    were unable to reallocate in place. A large number (relative to $(D
    bytesAllocated)) indicates that the application should use larger
    preallocations.
    */
    bytesMoved = 1u << 14,
    /**
    Tracks the sum of all bytes NOT moved as result of calls to $(D realloc)
    that managed to reallocate in place. A large number (relative to $(D
    bytesAllocated)) indicates that the application is expansion-intensive and
    is saving a good amount of moves. However, if this number is relatively
    small and $(D bytesSlack) is high, it means the application is
    overallocating for little benefit.
    */
    bytesNotMoved = 1u << 15,
    /**
    Measures the sum of extra bytes allocated beyond the bytes requested, i.e.
    the $(WEB goo.gl/YoKffF, internal fragmentation). This is the current
    effective number of slack bytes, and it goes up and down with time.
    */
    bytesSlack = 1u << 16,
    /**
    Measures the maximum bytes allocated over the time. This is useful for
    dimensioning allocators.
    */
    bytesHighTide = 1u << 17,
    /**
    Chooses all $(D byteXxx) flags.
    */
    bytesAll = ((1u << 18) - 1) & ~numAll,
    /**
    Instructs $(D StatsCollector) to store the size asked by the caller for
    each allocation. All per-allocation data is stored just before the actually
    allocation (see $(D AffixAllocator)).
    */
    callerSize = 1u << 18,
    /**
    Instructs $(D StatsCollector) to store the caller module for each
    allocation.
    */
    callerModule = 1u << 19,
    /**
    Instructs $(D StatsCollector) to store the caller's file for each
    allocation.
    */
    callerFile = 1u << 20,
    /**
    Instructs $(D StatsCollector) to store the caller $(D __FUNCTION__) for
    each allocation.
    */
    callerFunction = 1u << 21,
    /**
    Instructs $(D StatsCollector) to store the caller's line for each
    allocation.
    */
    callerLine = 1u << 22,
    /**
    Instructs $(D StatsCollector) to store the time of each allocation.
    */
    callerTime = 1u << 23,
    /**
    Chooses all $(D callerXxx) flags.
    */
    callerAll = ((1u << 24) - 1) & ~numAll & ~bytesAll,
    /**
    Combines all flags above.
    */
    all = (1u << 25) - 1
}

/**

Allocator that collects extra data about allocations. Since each piece of
information adds size and time overhead, statistics can be individually enabled
or disabled through compile-time $(D flags).

All stats of the form $(D numXxx) record counts of events occurring, such as
calls to functions and specific results. The stats of the form $(D bytesXxx)
collect cumulative sizes.

In addition, the data $(D callerSize), $(D callerModule), $(D callerFile), $(D
callerLine), and $(D callerTime) is associated with each specific allocation.
This data prefixes each allocation.

*/
struct StatsCollector(Allocator, uint flags = Options.all)
{
private:
    import std.traits;

    static string define(string type, string[] names...)
    {
        string result;
        foreach (v; names)
            result ~= "static if (flags & Options."~v~") {"
                "private "~type~" _"~v~";"
                "public const("~type~") "~v~"() const { return _"~v~"; }"
                "}";
        return result;
    }

    void add(string counter)(Signed!size_t n)
    {
        mixin("static if (flags & Options." ~ counter
            ~ ") _" ~ counter ~ " += n;");
    }

    void up(string counter)() { add!counter(1); }
    void down(string counter)() { add!counter(-1); }

    version (StdDdoc)
    {
        /**
        Read-only properties enabled by the homonym $(D flags) chosen by the
        user.

        Example:
        ----
        StatsCollector!(Mallocator,
            Options.bytesUsed | Options.bytesAllocated) a;
        auto d1 = a.allocate(10);
        auto d2 = a.allocate(11);
        a.deallocate(d1);
        assert(a.bytesAllocated == 21);
        assert(a.bytesUsed == 11);
        a.deallocate(d2);
        assert(a.bytesAllocated == 21);
        assert(a.bytesUsed == 0);
        ----
        */
        @property ulong numOwns() const;
        /// Ditto
        @property ulong numAllocate() const;
        /// Ditto
        @property ulong numAllocateOK() const;
        /// Ditto
        @property ulong numExpand() const;
        /// Ditto
        @property ulong numExpandOK() const;
        /// Ditto
        @property ulong numReallocate() const;
        /// Ditto
        @property ulong numReallocateOK() const;
        /// Ditto
        @property ulong numReallocateInPlace() const;
        /// Ditto
        @property ulong numDeallocate() const;
        /// Ditto
        @property ulong numDeallocateAll() const;
        /// Ditto
        @property ulong bytesUsed() const;
        /// Ditto
        @property ulong bytesAllocated() const;
        /// Ditto
        @property ulong bytesExpanded() const;
        /// Ditto
        @property ulong bytesContracted() const;
        /// Ditto
        @property ulong bytesMoved() const;
        /// Ditto
        @property ulong bytesNotMoved() const;
        /// Ditto
        @property ulong bytesSlack() const;
        /// Ditto
        @property ulong bytesHighTide() const;
    }

    // Do flags require any per allocation state?
    enum hasPerAllocationState = flags & (Options.callerTime
        | Options.callerModule | Options.callerFile | Options.callerLine);

    version (StdDdoc)
    {
        /**
        Per-allocation information that can be iterated upon by using
        $(D byAllocation). This only tracks live allocations and is useful for
        e.g. tracking memory leaks.

        Example:
        ----
        StatsCollector!(Mallocator, Options.all) a;
        auto d1 = a.allocate(10);
        auto d2 = a.allocate(11);
        a.deallocate(d1);
        foreach (ref e; a.byAllocation)
        {
            writeln("Allocation module: ", e.callerModule);
        }
        ----
        */
        public struct AllocationInfo
        {
            /**
            Read-only property defined by the corresponding flag chosen in
            $(D options).
            */
            @property size_t callerSize() const;
            /// Ditto
            @property string callerModule() const;
            /// Ditto
            @property string callerFile() const;
            /// Ditto
            @property uint callerLine() const;
            /// Ditto
            @property uint callerFunction() const;
            /// Ditto
            @property const(SysTime) callerTime() const;
        }
    }
    else static if (hasPerAllocationState)
    {
        public struct AllocationInfo
        {
            import std.datetime;
            mixin(define("string", "callerModule", "callerFile",
                "callerFunction"));
            mixin(define("uint", "callerLine"));
            mixin(define("size_t", "callerSize"));
            mixin(define("SysTime", "callerTime"));
            private AllocationInfo* _prev, _next;
        }
        AllocationInfo* _root;
        import std.experimental.allocator.affix_allocator;
        alias MyAllocator = AffixAllocator!(Allocator, AllocationInfo);

        public auto byAllocation()
        {
            struct Voldemort
            {
                private AllocationInfo* _root;
                bool empty() { return _root is null; }
                ref AllocationInfo front() { return *_root; }
                void popFront() { _root = _root._next; }
                Voldemort save() { return this; }
            }
            return Voldemort(_root);
        }
    }
    else
    {
        alias MyAllocator = Allocator;
    }

public:
    // Parent allocator (publicly accessible)
    static if (stateSize!MyAllocator) MyAllocator parent;
    else alias parent = MyAllocator.it;

private:
    // Per-allocator state
    mixin(define("ulong",
        "numOwns",
        "numAllocate",
        "numAllocateOK",
        "numExpand",
        "numExpandOK",
        "numReallocate",
        "numReallocateOK",
        "numReallocateInPlace",
        "numDeallocate",
        "numDeallocateAll",
        "bytesUsed",
        "bytesAllocated",
        "bytesExpanded",
        "bytesContracted",
        "bytesMoved",
        "bytesNotMoved",
        "bytesSlack",
        "bytesHighTide",
    ));

public:
    enum uint alignment = Allocator.alignment;

    /// Constructor taking a parent allocator
    this(Allocator parent)
    {
        this.parent = parent;
    }

    /// Ditto
    this(ref Allocator parent)
    {
        this.parent = parent;
    }

    static if (hasMember!(Allocator, "owns"))
    bool owns(void[] b)
    {
        up!"numOwns";
        return parent.owns(b);
    }

    static if (flags & Options.callerLine)
    {
        void[] allocate
            (string m = __MODULE__, string f = __FILE__,
                string fun = __FUNCTION__, ulong n = __LINE__)
            (size_t bytes)
        {
            return allocateImpl!(m, f, fun, n)(bytes);
        }
    }
    else static if (flags & Options.callerFunction)
    {
        void[] allocate
            (string m = __MODULE__, string f = __FILE__,
                string fun = __FUNCTION__)
            (size_t bytes)
        {
            return allocateImpl!(m, f, fun, 0)(bytes);
        }
    }
    else static if (flags & Options.callerFile)
    {
        void[] allocate(string m = __MODULE__, string f = __FILE__)
            (size_t bytes)
        {
            return allocateImpl!(m, f, null, 0)(bytes);
        }
    }
    else static if (flags & Options.callerModule)
    {
        void[] allocate(string m = __MODULE__)(size_t bytes)
        {
            return allocateImpl!(m, null, null, 0)(bytes);
        }
    }
    else
    {
        void[] allocate(size_t bytes)
        {
            return allocateImpl!(null, null, null, 0)(bytes);
        }
    }

    private void[] allocateImpl(string m, string f, string fun, ulong n)
        (size_t bytes)
    {
        up!"numAllocate";
        auto result = parent.allocate(bytes);
        add!"bytesUsed"(result.length);
        add!"bytesAllocated"(result.length);
        add!"bytesSlack"(this.goodAllocSize(result.length) - result.length);
        add!"numAllocateOK"(result.ptr || !bytes); // allocating 0 bytes is OK
        static if (flags & Options.bytesHighTide)
        {
            if (_bytesHighTide < _bytesUsed) _bytesHighTide = _bytesUsed;
        }
        static if (hasPerAllocationState)
        {
            auto p = &parent.prefix(result);
            static if (flags & Options.callerSize)
                p._callerSize = bytes;
            static if (flags & Options.callerModule)
                p._callerModule = m;
            static if (flags & Options.callerFile)
                p._callerFile = f;
            static if (flags & Options.callerFunction)
                p._callerFunction = fun;
            static if (flags & Options.callerLine)
                p._callerLine = n;
            static if (flags & Options.callerTime)
            {
                import std.datetime;
                p._callerTime =  Clock.currTime;
            }
            // Wire the new info into the list
            assert(p._prev is null);
            p._next = _root;
            if (_root) _root._prev = p;
            _root = p;
        }
        return result;
    }

    static if (hasMember!(Allocator, "expand"))
    bool expand(ref void[] b, size_t s)
    {
        up!"numExpand";
        static if (flags & Options.bytesSlack)
            const bytesSlackB4 = goodAllocSize(b.length) - b.length;
        auto result = parent.expand(b, s);
        if (result)
        {
            up!"numExpandOK";
            add!"bytesExpanded"(s);
            add!"bytesSlack"(goodAllocSize(b.length) - b.length - bytesSlackB4);
        }
        return result;
    }

    bool reallocate(ref void[] b, size_t s)
    {
        up!"numReallocate";
        const bytesSlackB4 = this.goodAllocSize(b.length) - b.length;
        const oldB = b.ptr;
        static if ((flags & Options.bytesMoved)
                || (flags & Options.bytesNotMoved)
                || (flags & Options.bytesUsed))
            const oldLength = b.length;
        static if (hasPerAllocationState)
            const reallocatingRoot = b.ptr && _root is &parent.prefix(b);
        if (!parent.reallocate(b, s)) return false;
        up!"numReallocateOK";
        add!"bytesSlack"(this.goodAllocSize(b.length) - b.length
            - bytesSlackB4);
        add!"bytesUsed"(Signed!size_t(b.length - oldLength));
        if (oldB == b.ptr)
        {
            // This was an in-place reallocation, yay
            up!"numReallocateInPlace";
            add!"bytesNotMoved"(oldLength);
            const Signed!size_t delta = b.length - oldLength;
            if (delta >= 0)
            {
                // Expansion
                add!"bytesAllocated"(delta);
                add!"bytesExpanded"(delta);
            }
            else
            {
                // Contraction
                add!"bytesContracted"(-delta);
            }
        }
        else
        {
            // This was a allocate-move-deallocate cycle
            add!"bytesAllocated"(b.length);
            add!"bytesMoved"(oldLength);
            static if (hasPerAllocationState)
            {
                // Stitch the pointers again, ho-hum
                auto p = &parent.prefix(b);
                if (p._next) p._next._prev = p;
                if (p._prev) p._prev._next = p;
                if (reallocatingRoot) _root = p;
            }
        }
        return true;
    }

    void deallocate(void[] b)
    {
        up!"numDeallocate";
        add!"bytesUsed"(-Signed!size_t(b.length));
        add!"bytesSlack"(-(this.goodAllocSize(b.length) - b.length));
        // Remove the node from the list
        static if (hasPerAllocationState)
        {
            auto p = &parent.prefix(b);
            if (p._next) p._next._prev = p._prev;
            if (p._prev) p._prev._next = p._next;
            if (_root is p) _root = p._next;
        }
        static if (hasMember!(Allocator, "deallocate"))
            parent.deallocate(b);
    }

    static if (hasMember!(Allocator, "deallocateAll"))
    void deallocateAll()
    {
        up!"numDeallocateAll";
        static if ((flags & Options.bytesUsed))
            _bytesUsed = 0;
        parent.deallocateAll();
        static if (hasPerAllocationState) _root = null;
    }
}

unittest
{
    void test(Allocator)()
    {
        import std.range : walkLength;
        import std.stdio : writeln;
        Allocator a;
        auto b1 = a.allocate(100);
        assert(a.numAllocate == 1);
        auto b2 = a.allocate(101);
        assert(a.numAllocate == 2);
        assert(a.bytesAllocated == 201);
        assert(a.bytesUsed == 201);
        auto b3 = a.allocate(202);
        assert(a.numAllocate == 3);
        assert(a.bytesAllocated == 403);

        assert(walkLength(a.byAllocation) == 3);

        foreach (ref e; a.byAllocation)
        {
            if (false) writeln(e);
        }

        a.deallocate(b2);
        assert(a.numDeallocate == 1);
        a.deallocate(b1);
        assert(a.numDeallocate == 2);
        a.deallocate(b3);
        assert(a.numDeallocate == 3);
        assert(a.numAllocate == a.numDeallocate);
        assert(a.bytesUsed == 0);
    }

    import std.experimental.allocator.mallocator;
    import std.experimental.allocator.free_list;
    test!(StatsCollector!Mallocator)();
    test!(StatsCollector!(FreeList!(Mallocator, 128)))();
}
