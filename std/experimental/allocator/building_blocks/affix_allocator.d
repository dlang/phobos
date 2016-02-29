module std.experimental.allocator.building_blocks.affix_allocator;

/**

Allocator that adds some extra data before (of type $(D Prefix)) and/or after
(of type $(D Suffix)) any allocation made with its parent allocator. This is
useful for uses where additional allocation-related information is needed, such
as mutexes, reference counts, or walls for debugging memory corruption errors.

If $(D Prefix) is not $(D void), $(D Allocator) must guarantee an alignment at
least as large as $(D Prefix.alignof).

Suffixes are slower to get at because of alignment rounding, so prefixes should
be preferred. However, small prefixes blunt the alignment so if a large
alignment with a small affix is needed, suffixes should be chosen.

The following methods are defined if $(D Allocator) defines them, and forward to it: $(D deallocateAll), $(D empty), $(D owns).
 */
struct AffixAllocator(Allocator, Prefix, Suffix = void)
{
    import std.conv, std.experimental.allocator.common, std.traits;
    import std.algorithm : min;

    static assert(
        !stateSize!Prefix || Allocator.alignment >= Prefix.alignof,
        "AffixAllocator does not work with allocators offering a smaller"
        ~ " alignment than the prefix alignment.");
    static assert(alignment % Suffix.alignof == 0,
        "This restriction could be relaxed in the future.");

    /**
    If $(D Prefix) is $(D void), the alignment is that of the parent. Otherwise, the alignment is the same as the $(D Prefix)'s alignment.
    */
    enum uint alignment = isPowerOf2(stateSize!Prefix)
        ? min(stateSize!Prefix, Allocator.alignment)
        : (stateSize!Prefix ? Prefix.alignof : Allocator.alignment);

    /**
    If the parent allocator $(D Allocator) is stateful, an instance of it is
    stored as a member. Otherwise, $(D AffixAllocator) uses
    `Allocator.instance`. In either case, the name $(D _parent) is uniformly
    used for accessing the parent allocator.
    */
    static if (stateSize!Allocator) Allocator parent;
    else alias parent = Allocator.instance;

    private template Impl()
    {
        size_t goodAllocSize(size_t s)
        {
            auto a = actualAllocationSize(s);
            return roundUpToMultipleOf(parent.goodAllocSize(a)
                    - stateSize!Prefix - stateSize!Suffix,
                this.alignment);
        }

        private size_t actualAllocationSize(size_t s) const
        {
            assert(s > 0);
            static if (!stateSize!Suffix)
            {
                return s + stateSize!Prefix;
            }
            else
            {
                return
                    roundUpToMultipleOf(s + stateSize!Prefix, Suffix.alignof)
                    + stateSize!Suffix;
            }
        }

        private void[] actualAllocation(void[] b) const
        {
            assert(b !is null);
            return (b.ptr - stateSize!Prefix)
                [0 .. actualAllocationSize(b.length)];
        }

        void[] allocate(size_t bytes)
        {
            if (!bytes) return null;
            auto result = parent.allocate(actualAllocationSize(bytes));
            if (result is null) return null;
            static if (stateSize!Prefix)
            {
                assert(result.ptr.alignedAt(Prefix.alignof));
                emplace!Prefix(cast(Prefix*)result.ptr);
            }
            static if (stateSize!Suffix)
            {
                auto suffixP = result.ptr + result.length - Suffix.sizeof;
                assert(suffixP.alignedAt(Suffix.alignof));
                emplace!Suffix(cast(Suffix*)(suffixP));
            }
            return result[stateSize!Prefix .. stateSize!Prefix + bytes];
        }

        static if (hasMember!(Allocator, "allocateAll"))
        void[] allocateAll()
        {
            auto result = parent.allocateAll();
            if (result is null) return null;
            if (result.length < actualAllocationSize(1))
            {
                deallocate(result);
                return null;
            }
            static if (stateSize!Prefix)
            {
                assert(result.length > stateSize!Prefix);
                emplace!Prefix(cast(Prefix*)result.ptr);
                result = result[stateSize!Prefix .. $];
            }
            static if (stateSize!Suffix)
            {
                assert(result.length > stateSize!Suffix);
                // Ehm, find a properly aligned place for the suffix
                auto p = (result.ptr + result.length - stateSize!Suffix)
                    .alignDownTo(Suffix.alignof);
                assert(p > result.ptr);
                emplace!Suffix(cast(Suffix*) p);
                result = result[0 .. p - result.ptr];
            }
            return result;
        }

        static if (hasMember!(Allocator, "owns"))
        Ternary owns(void[] b)
        {
            if (b is null) return Ternary.no;
            return parent.owns(actualAllocation(b));
        }

        static if (hasMember!(Allocator, "resolveInternalPointer"))
        void[] resolveInternalPointer(void* p)
        {
            auto p1 = parent.resolveInternalPointer(p);
            if (p1 is null) return p1;
            p1 = p1[stateSize!Prefix .. $];
            auto p2 = (p1.ptr + p1.length - stateSize!Suffix)
                    .alignDownTo(Suffix.alignof);
            return p1[0 .. p2 - p1.ptr];
        }

        static if (!stateSize!Suffix && hasMember!(Allocator, "expand"))
        bool expand(ref void[] b, size_t delta)
        {
            if (!b.ptr)
            {
                b = allocate(delta);
                return b.length == delta;
            }
            auto t = actualAllocation(b);
            const result = parent.expand(t, delta);
            if (!result) return false;
            b = b.ptr[0 .. b.length + delta];
            return true;
        }

        static if (hasMember!(Allocator, "reallocate"))
        bool reallocate(ref void[] b, size_t s)
        {
            if (b is null)
            {
                b = allocate(s);
                return b.length == s;
            }
            auto t = actualAllocation(b);
            const result = parent.reallocate(t, actualAllocationSize(s));
            if (!result) return false; // no harm done
            b = t.ptr[stateSize!Prefix .. stateSize!Prefix + s];
            return true;
        }

        static if (hasMember!(Allocator, "deallocate"))
        bool deallocate(void[] b)
        {
            if (!b.ptr) return true;
            return parent.deallocate(actualAllocation(b));
        }

        /* The following methods are defined if $(D ParentAllocator) defines
        them, and forward to it: $(D deallocateAll), $(D empty).*/
        mixin(forwardToMember("parent",
            "deallocateAll", "empty"));

        // Extra functions
        static if (stateSize!Prefix)
            static ref Prefix prefix(void[] b)
            {
                assert(b.ptr && b.ptr.alignedAt(Prefix.alignof));
                return (cast(Prefix*)b.ptr)[-1];
            }
        static if (stateSize!Suffix)
            ref Suffix suffix(void[] b)
            {
                assert(b.ptr);
                auto p = b.ptr - stateSize!Prefix
                    + actualAllocationSize(b.length);
                assert(p && p.alignedAt(Suffix.alignof));
                return (cast(Suffix*) p)[-1];
            }
    }

    version (StdDdoc)
    {
        /**
        Standard allocator methods. Each is defined if and only if the parent
        allocator defines the homonym method (except for $(D goodAllocSize),
        which may use the global default). Also, the methods will be $(D
        shared) if the parent allocator defines them as such.
        */
        size_t goodAllocSize(size_t);
        /// Ditto
        void[] allocate(size_t);
        /// Ditto
        Ternary owns(void[]);
        /// Ditto
        bool expand(ref void[] b, size_t delta);
        /// Ditto
        bool reallocate(ref void[] b, size_t s);
        /// Ditto
        bool deallocate(void[] b);
        /// Ditto
        bool deallocateAll();
        /// Ditto
        Ternary empty();

        /**
        The `instance` singleton is defined if and only if the parent allocator has no state and defines its own `it` object.
        */
        static AffixAllocator instance;

        /**
        Affix access functions offering mutable references to the affixes of a block previously allocated with this allocator. $(D b) may not be null. They are defined if and only if the corresponding affix is not $(D void).

        Precondition: $(D b !is null)
        */
        static ref Prefix prefix(void[] b);
        /// Ditto
        static ref Suffix suffix(void[] b);
    }
    else static if (is(typeof(Allocator.instance) == shared))
    {
        static shared AffixAllocator instance;
        shared { mixin Impl!(); }
    }
    else
    {
        mixin Impl!();
        static if (stateSize!Allocator == 0)
            static __gshared AffixAllocator instance;
    }
}

///
unittest
{
    import std.experimental.allocator.mallocator : Mallocator;
    // One word before and after each allocation.
    alias A = AffixAllocator!(Mallocator, size_t, size_t);
    auto b = A.instance.allocate(11);
    A.instance.prefix(b) = 0xCAFE_BABE;
    A.instance.suffix(b) = 0xDEAD_BEEF;
    assert(A.instance.prefix(b) == 0xCAFE_BABE
        && A.instance.suffix(b) == 0xDEAD_BEEF);
}

unittest
{
    import std.experimental.allocator.building_blocks.bitmapped_block
        : BitmappedBlock;
    import std.experimental.allocator.common : testAllocator;
    testAllocator!({
        auto a = AffixAllocator!(BitmappedBlock!128, ulong, ulong)
            (BitmappedBlock!128(new void[128 * 4096]));
        return a;
    });
}

unittest
{
    import std.experimental.allocator.mallocator : Mallocator;
    alias A = AffixAllocator!(Mallocator, size_t);
    auto b = A.instance.allocate(10);
    A.instance.prefix(b) = 10;
    assert(A.instance.prefix(b) == 10);

    import std.experimental.allocator.building_blocks.null_allocator
        : NullAllocator;
    alias B = AffixAllocator!(NullAllocator, size_t);
    b = B.instance.allocate(100);
    assert(b is null);
}
