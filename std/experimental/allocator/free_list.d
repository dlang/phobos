module std.experimental.allocator.free_list;

import std.experimental.allocator.common;

/**

$(WEB en.wikipedia.org/wiki/Free_list, Free list allocator), stackable on top of
another allocator. Allocation requests between $(D min) and $(D max) bytes are
rounded up to $(D max) and served from a singly-linked list of buffers
deallocated in the past. All other allocations are directed to $(D
ParentAllocator). Due to the simplicity of free list management, allocations
from the free list are fast.

If a program makes many allocations in the interval $(D [minSize, maxSize]) and
then frees most of them, the freelist may grow large, thus making memory
inaccessible to requests of other sizes. To prevent that, the $(D maxNodes)
parameter allows limiting the size of the free list. Alternatively, $(D
deallocateAll) cleans the free list.

$(D FreeList) attempts to reduce internal fragmentation and improve cache
locality by allocating multiple nodes at once, under the control of the $(D
batchCount) parameter. This makes $(D FreeList) an efficient front for small
object allocation on top of a large-block allocator. The default value of $(D
batchCount) is 8, which should amortize freelist management costs to negligible
in most cases.

One instantiation is of particular interest: $(D FreeList!(0,unbounded)) puts
every deallocation in the freelist, and subsequently serves any allocation from
the freelist (if not empty). There is no checking of size matching, which would
be incorrect for a freestanding allocator but is both correct and fast when an
owning allocator on top of the free list allocator (such as $(D Segregator)) is
already in charge of handling size checking.

*/
struct FreeList(ParentAllocator,
    size_t minSize, size_t maxSize = minSize,
    uint batchCount = 8, size_t maxNodes = unbounded)
{
    import std.conv : text;
    import std.exception : enforce;
    import std.traits : hasMember;

    static assert(minSize != unbounded, "Use minSize = 0 for no low bound.");
    static assert(maxSize >= (void*).sizeof,
        "Maximum size must accommodate a pointer.");

    static if (minSize != chooseAtRuntime)
    {
        alias min = minSize;
    }
    else
    {
        size_t _min = chooseAtRuntime;
        @property size_t min() const
        {
            assert(_min != chooseAtRuntime);
            return _min;
        }
        @property void min(size_t x)
        {
            enforce(x <= _max);
            _min = x;
        }
        static if (maxSize == chooseAtRuntime)
        {
            // Both bounds can be set, provide one function for setting both in
            // one shot.
            void setBounds(size_t low, size_t high)
            {
                enforce(low <= high && high >= (void*).sizeof);
                _min = low;
                _max = high;
            }
        }
    }

    private bool tooSmall(size_t n) const
    {
        static if (minSize == 0) return false;
        else return n < min;
    }

    static if (maxSize != chooseAtRuntime)
    {
        alias max = maxSize;
    }
    else
    {
        size_t _max;
        @property size_t max() const { return _max; }
        @property void max(size_t x)
        {
            enforce(x >= _min && x >= (void*).sizeof);
            _max = x;
        }
    }

    private bool tooLarge(size_t n) const
    {
        static if (maxSize == unbounded) return false;
        else return n > max;
    }

    private bool inRange(size_t n) const
    {
        static if (minSize == maxSize && minSize != chooseAtRuntime)
            return n == maxSize;
        else return !tooSmall(n) && !tooLarge(n);
    }

    version (StdDdoc)
    {
        /**
        Properties for getting and setting bounds. Setting a bound is only
        possible if the respective compile-time parameter has been set to $(D
        chooseAtRuntime). $(D setBounds) is defined only if both $(D minSize)
        and $(D maxSize) are set to $(D chooseAtRuntime).
        */
        @property size_t min();
        /// Ditto
        @property void min(size_t newMinSize);
        /// Ditto
        @property size_t max();
        /// Ditto
        @property void max(size_t newMaxSize);
        /// Ditto
        void setBounds(size_t newMin, size_t newMax);
        ///
        unittest
        {
            FreeList!(Mallocator, chooseAtRuntime, chooseAtRuntime) a;
            // Set the maxSize first so setting the minSize doesn't throw
            a.max = 128;
            a.min = 64;
            a.setBounds(64, 128); // equivalent
            assert(a.max == 128);
            assert(a.min == 64);
        }
    }

    /**
    The parent allocator. Depending on whether $(D ParentAllocator) holds state
    or not, this is a member variable or an alias for $(D ParentAllocator.it).
    */
    static if (stateSize!ParentAllocator) ParentAllocator parent;
    else alias parent = ParentAllocator.it;

    private struct Node { Node* next; }
    static assert(ParentAllocator.alignment >= Node.alignof);
    private Node* _root;
    private uint nodesAtATime = batchCount;

    static if (maxNodes != unbounded)
    {
        private size_t nodes;
        private void incNodes() { ++nodes; }
        private void decNodes() { assert(nodes); --nodes; }
        private bool nodesFull() { return nodes >= maxNodes; }
    }
    else
    {
        private static void incNodes() { }
        private static void decNodes() { }
        private enum bool nodesFull = false;
    }

    /**
    Alignment is defined as $(D parent.alignment). However, if $(D
    parent.alignment > maxSize), objects returned from the freelist will have a
    smaller _alignment, namely $(D maxSize) rounded up to the nearest multiple
    of 2. This allows $(D FreeList) to minimize internal fragmentation by
    allocating several small objects within an allocated block. Also, there is
    no disruption because no object has smaller size than its _alignment.
    */
    enum uint alignment = ParentAllocator.alignment;

    /**
    Returns $(D max) for sizes in the interval $(D [min, max]), and $(D
    parent.goodAllocSize(bytes)) otherwise.
    */
    size_t goodAllocSize(size_t bytes)
    {
        if (inRange(bytes)) return maxSize == unbounded ? bytes : max;
        return parent.goodAllocSize(bytes);
    }

    /**
    Allocates memory either off of the free list or from the parent allocator.
    */
    void[] allocate(size_t bytes)
    {
        assert(bytes < size_t.max / 2);
        if (!inRange(bytes)) return parent.allocate(bytes);
        // Round up allocation to max
        if (maxSize != unbounded) bytes = max;
        if (!_root) return allocateFresh(bytes);
        // Pop off the freelist
        auto result = (cast(ubyte*) _root)[0 .. bytes];
        _root = _root.next;
        decNodes();
        return result;
    }

    private void[] allocateFresh(const size_t bytes)
    {
        assert(!_root);
        assert(bytes == max || max == unbounded);
        assert(max > 0);
        if (nodesAtATime == 1)
        {
            // Easy case, just get it over with
            return parent.allocate(bytes);
        }
        static if (maxSize != unbounded && maxSize != chooseAtRuntime)
        {
            static assert((parent.alignment + max) % Node.alignof == 0,
                text("(", parent.alignment, " + ", max, ") % ",
                 Node.alignof));
        }
        else
        {
            assert((parent.alignment + bytes) % Node.alignof == 0,
                text("(", parent.alignment, " + ", bytes, ") % ",
                 Node.alignof));
        }

        auto data = parent.allocate(nodesAtATime * bytes);
        if (!data.ptr) return null;
        auto result = data[0 .. bytes];
        auto n = data[bytes .. $];
        _root = cast(Node*) n.ptr;
        for (;;)
        {
            if (n.length < bytes)
            {
                (cast(Node*) data.ptr).next = null;
                break;
            }
            (cast(Node*) data.ptr).next = cast(Node*) n.ptr;
            data = n;
            n = data[bytes .. $];
        }
        return result;
    }

    /**
    Forwards to $(parent.owns) if implemented.
    */
    static if (hasMember!(ParentAllocator, "owns"))
    bool owns(void[] b)
    {
        return parent.owns(b);
    }

    /**
    Forwards to $(D parent).
    */
    static if (hasMember!(ParentAllocator, "expand"))
    bool expand(void[] b, size_t s)
    {
        return parent.expand(b, s);
    }

    /// Ditto
    static if (hasMember!(ParentAllocator, "reallocate"))
    bool reallocate(void[] b, size_t s)
    {
        return parent.reallocate(b, s);
    }

    /**
    Intercepts deallocations and caches those of the appropriate size in the
    freelist. For all others, forwards to $(D parent.deallocate) or does nothing
    if $(D Parent) does not define $(D deallocate).
    */
    void deallocate(void[] block)
    {
        if (!nodesFull && inRange(block.length))
        {
            static if (minSize == 0)
            {
                // In this case a null pointer might have made it this far.
                if (block is null) return;
            }
            auto t = _root;
            _root = cast(Node*) block.ptr;
            _root.next = t;
            incNodes();
        }
        else
        {
            static if (is(typeof(parent.deallocate(block))))
                parent.deallocate(block);
        }
    }

    /**
    If $(D ParentAllocator) defines $(D deallocateAll), just forwards to it and
    reset the freelist. Otherwise, walks the list and frees each object in turn.
    */
    void deallocateAll()
    {
        static if (hasMember!(ParentAllocator, "deallocateAll"))
        {
            parent.deallocateAll();
        }
        else static if (hasMember!(ParentAllocator, "deallocate"))
        {
            for (auto n = _root; n; n = n.next)
            {
                parent.deallocate((cast(ubyte*)n)[0 .. max]);
            }
        }
        _root = null;
    }

    /// GC helper primitives.
    static if (hasMember!(ParentAllocator, "markAllAsUnused"))
    {
        void markAllAsUnused()
        {
            // Time to come clean about the stashed data.
            static if (hasMember!(ParentAllocator, "deallocate"))
            for (auto n = _root; n; n = n.next)
            {
                parent.deallocate((cast(ubyte*)n)[0 .. max]);
            }
            _root = null;
        }
        //
        bool markAsUsed(void[] b) { return parent.markAsUsed(b); }
        //
        void doneMarking() { parent.doneMarking(); }
    }
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    FreeList!(GCAllocator, 0, 8, 1) fl;
    assert(fl._root is null);
    auto b1 = fl.allocate(7);
    //assert(fl._root !is null);
    auto b2 = fl.allocate(8);
    assert(fl._root is null);
    fl.deallocate(b1);
    assert(fl._root !is null);
    auto b3 = fl.allocate(8);
    assert(fl._root is null);
}

/**
FreeList shared across threads. Allocation and deallocation are lock-free. The
parameters have the same semantics as for $(D FreeList).
*/
struct SharedFreeList(ParentAllocator,
    size_t minSize, size_t maxSize = minSize,
    uint batchCount = 8, size_t maxNodes = unbounded)
{
    import std.conv : text;
    import std.exception : enforce;
    import std.traits : hasMember;

    static assert(minSize != unbounded, "Use minSize = 0 for no low bound.");
    static assert(maxSize >= (void*).sizeof,
        "Maximum size must accommodate a pointer.");

    private import core.atomic;

    static if (minSize != chooseAtRuntime)
    {
        alias min = minSize;
    }
    else
    {
        shared size_t _min = chooseAtRuntime;
        @property size_t min() const shared
        {
            assert(_min != chooseAtRuntime);
            return _min;
        }
        @property void min(size_t x) shared
        {
            enforce(x <= max);
            enforce(cas(&_min, chooseAtRuntime, x),
                "SharedFreeList.min must be initialized exactly once.");
        }
        static if (maxSize == chooseAtRuntime)
        {
            // Both bounds can be set, provide one function for setting both in
            // one shot.
            void setBounds(size_t low, size_t high) shared
            {
                enforce(low <= high && high >= (void*).sizeof);
                enforce(cas(&_min, chooseAtRuntime, low),
                    "SharedFreeList.min must be initialized exactly once.");
                enforce(cas(&_max, chooseAtRuntime, high),
                    "SharedFreeList.max must be initialized exactly once.");
            }
        }
    }

    private bool tooSmall(size_t n) const shared
    {
        static if (minSize == 0) return false;
        else static if (minSize == chooseAtRuntime) return n < _min;
        else return n < minSize;
    }

    static if (maxSize != chooseAtRuntime)
    {
        alias max = maxSize;
    }
    else
    {
        shared size_t _max = chooseAtRuntime;
        @property size_t max() const shared { return _max; }
        @property void max(size_t x) shared
        {
            enforce(x >= _min && x >= (void*).sizeof);
            enforce(cas(&_max, chooseAtRuntime, x),
                "SharedFreeList.max must be initialized exactly once.");
        }
    }

    private bool tooLarge(size_t n) const shared
    {
        static if (maxSize == unbounded) return false;
        else static if (maxSize == chooseAtRuntime) return n > _max;
        else return n > maxSize;
    }

    private bool inRange(size_t n) const shared
    {
        static if (minSize == maxSize && minSize != chooseAtRuntime)
            return n == maxSize;
        else return !tooSmall(n) && !tooLarge(n);
    }

    static if (maxNodes != unbounded)
    {
        private shared size_t nodes;
        private void incNodes() shared
        {
            atomicOp!("+=")(nodes, 1);
        }
        private void decNodes() shared
        {
            assert(nodes);
            atomicOp!("-=")(nodes, 1);
        }
        private bool nodesFull() shared
        {
            return nodes >= maxNodes;
        }
    }
    else
    {
        private static void incNodes() { }
        private static void decNodes() { }
        private enum bool nodesFull = false;
    }

    version (StdDdoc)
    {
        /**
        Properties for getting (and possibly setting) the bounds. Setting bounds
        is allowed only once , and before any allocation takes place. Otherwise,
        the primitives have the same semantics as those of $(D FreeList).
        */
        @property size_t min();
        /// Ditto
        @property void min(size_t newMinSize);
        /// Ditto
        @property size_t max();
        /// Ditto
        @property void max(size_t newMaxSize);
        /// Ditto
        void setBounds(size_t newMin, size_t newMax);
        ///
        unittest
        {
            FreeList!(Mallocator, chooseAtRuntime, chooseAtRuntime) a;
            // Set the maxSize first so setting the minSize doesn't throw
            a.max = 128;
            a.min = 64;
            a.setBounds(64, 128); // equivalent
            assert(a.max == 128);
            assert(a.min == 64);
        }
    }

    /**
    The parent allocator. Depending on whether $(D ParentAllocator) holds state
    or not, this is a member variable or an alias for $(D ParentAllocator.it).
    */
    static if (stateSize!ParentAllocator) shared ParentAllocator parent;
    else alias parent = ParentAllocator.it;

    private struct Node { Node* next; }
    static assert(ParentAllocator.alignment >= Node.alignof);
    private Node* _root;
    private uint nodesAtATime = batchCount;

    /// Standard primitives.
    enum uint alignment = ParentAllocator.alignment;

    /// Ditto
    size_t goodAllocSize(size_t bytes) shared
    {
        if (inRange(bytes)) return maxSize == unbounded ? bytes : max;
        return parent.goodAllocSize(bytes);
    }

    /// Ditto
    bool owns(void[] b) shared const
    {
        if (inRange(b.length)) return true;
        static if (hasMember!(ParentAllocator, "owns"))
            return parent.owns(b);
        else
            return false;
    }

    /**
    Forwards to $(D parent), which must also support $(D shared) primitives.
    */
    static if (hasMember!(ParentAllocator, "expand"))
    bool expand(void[] b, size_t s)
    {
        return parent.expand(b, s);
    }

    /// Ditto
    static if (hasMember!(ParentAllocator, "reallocate"))
    bool reallocate(void[] b, size_t s)
    {
        return parent.reallocate(b, s);
    }

    /// Ditto
    void[] allocate(size_t bytes) shared
    {
        assert(bytes < size_t.max / 2);
        if (!inRange(bytes)) return parent.allocate(bytes);
        if (maxSize != unbounded) bytes = max;
        if (!_root) return allocateFresh(bytes);
        // Pop off the freelist
        shared Node* oldRoot = void, next = void;
        do
        {
            oldRoot = _root; // atomic load
            next = oldRoot.next; // atomic load
        }
        while (!cas(&_root, oldRoot, next));
        // great, snatched the root
        decNodes();
        return (cast(ubyte*) oldRoot)[0 .. bytes];
    }

    private void[] allocateFresh(const size_t bytes) shared
    {
        assert(bytes == max || max == unbounded);
        if (nodesAtATime == 1)
        {
            // Easy case, just get it over with
            return parent.allocate(bytes);
        }
        static if (maxSize != unbounded && maxSize != chooseAtRuntime)
        {
            static assert(
                (parent.alignment + max) % Node.alignof == 0,
                text("(", parent.alignment, " + ", max, ") % ",
                 Node.alignof));
        }
        else
        {
            assert((parent.alignment + bytes) % Node.alignof == 0,
                text("(", parent.alignment, " + ", bytes, ") % ",
                 Node.alignof));
        }

        auto data = parent.allocate(nodesAtATime * bytes);
        if (!data.ptr) return null;
        auto result = data[0 .. bytes];
        auto n = data[bytes .. $];
        auto newRoot = cast(shared Node*) n.ptr;
        shared Node* lastNode;
        for (;;)
        {
            if (n.length < bytes)
            {
                lastNode = cast(shared Node*) data.ptr;
                break;
            }
            (cast(Node*) data.ptr).next = cast(Node*) n.ptr;
            data = n;
            n = data[bytes .. $];
        }
        // Created the list, now wire the new nodes in considering another
        // thread might have also created some nodes.
        do
        {
            lastNode.next = _root;
        }
        while (!cas(&_root, lastNode.next, newRoot));
        return result;
    }

    /// Ditto
    void deallocate(void[] b) shared
    {
        if (!nodesFull && inRange(b.length))
        {
            auto newRoot = cast(shared Node*) b.ptr;
            shared Node* oldRoot;
            do
            {
                oldRoot = _root;
                newRoot.next = oldRoot;
            }
            while (!cas(&_root, oldRoot, newRoot));
            incNodes();
        }
        else
        {
            static if (is(typeof(parent.deallocate(block))))
                parent.deallocate(block);
        }
    }

    /// Ditto
    void deallocateAll() shared
    {
        static if (hasMember!(ParentAllocator, "deallocateAll"))
        {
            parent.deallocateAll();
        }
        else static if (hasMember!(ParentAllocator, "deallocate"))
        {
            for (auto n = _root; n; n = n.next)
            {
                parent.deallocate((cast(ubyte*)n)[0 .. max]);
            }
        }
        _root = null;
    }
}

unittest
{
    import core.thread, std.algorithm, std.concurrency, std.range,
        std.experimental.allocator.mallocator;

    static shared SharedFreeList!(Mallocator, 64, 128, 8, 100) a;

    assert(a.goodAllocSize(1) == platformAlignment);

    auto b = a.allocate(100);
    a.deallocate(b);

    static void fun(Tid tid, int i)
    {
        scope(exit) tid.send(true);
        auto b = cast(ubyte[]) a.allocate(100);
        b[] = cast(ubyte) i;

        assert(b.equal(repeat(cast(ubyte) i, b.length)));
        a.deallocate(b);
    }

    Tid[] tids;
    foreach (i; 0 .. 1000)
    {
        tids ~= spawn(&fun, thisTid, i);
    }

    foreach (i; 0 .. 1000)
    {
        assert(receiveOnly!bool);
    }
}

unittest
{
    import std.experimental.allocator.mallocator;
    shared SharedFreeList!(Mallocator, chooseAtRuntime, chooseAtRuntime,
        8, 100) a;
    auto b = a.allocate(64);
}
