Ddoc

$(SPEC_S Garbage Collection,

	$(P D is a fully garbage collected language. That means that it is never
	necessary
	to free memory. Just allocate as needed, and the garbage collector will
	periodically return all unused memory to the pool of available memory.
	)

	$(P C and C++ programmers accustomed to explicitly managing memory
	allocation and
	deallocation will likely be skeptical of the benefits and efficacy of
	garbage collection. Experience both with new projects written with
	garbage collection in mind, and converting existing projects to garbage
	collection shows that:
	)

	$(UL 

	$(LI Garbage collected programs are faster. This is counterintuitive,
	but the reasons are:

	$(UL 
	    $(LI Reference counting is a common solution to solve explicit
	    memory allocation problems. The code to implement the increment and
	    decrement operations whenever assignments are made is one source
	    of slowdown. Hiding it behind smart pointer classes doesn't help
	    the speed. (Reference counting methods are not a general solution
	    anyway, as circular references never get deleted.)
	    )

	    $(LI Destructors are used to deallocate resources acquired by an object.
	    For most classes, this resource is allocated memory.
	    With garbage collection, most destructors then become empty and
	    can be discarded entirely.
	    )

	    $(LI All those destructors freeing memory can become significant when
	    objects are allocated on the stack. For each one, some mechanism must
	    be established so that if an exception happens, the destructors all
	    get called in each frame to release any memory they hold. If the
	    destructors become irrelevant, then there's no need to set up special
	    stack frames to handle exceptions, and the code runs faster.
	    )

	    $(LI All the code necessary to manage memory can add up to quite a
	    bit. The larger a program is, the less in the cache it is,
	    the more paging it does, and the slower
	    it runs.
	    )

	    $(LI Garbage collection kicks in only when memory gets tight. When
	    memory is not tight, the program runs at full speed and does not
	    spend any time freeing memory.
	    )

	    $(LI Modern garbage collectors are far more advanced now than the
	    older, slower ones. Generational, copying collectors eliminate much
	    of the inefficiency of early mark and sweep algorithms.
	    )

	    $(LI Modern garbage collectors do heap compaction. Heap compaction
	    tends to reduce the number of pages actively referenced by a program,
	    which means that memory accesses are more likely to be cache hits
	    and less swapping.
	    )

	    $(LI Garbage collected programs do not suffer from gradual deterioration
	    due to an accumulation of memory leaks.
	    )
	)
	)

	$(LI Garbage collectors reclaim unused memory, therefore they do not suffer
	from "memory leaks" which can cause long running applications to gradually
	consume more and more memory until they bring down the system. GC programs
	have longer term stability.
	)

	$(LI Garbage collected programs have fewer hard-to-find pointer bugs. This
	is because there are no dangling references to freed memory. There is no
	code to explicitly manage memory, hence no bugs in such code.
	)

	$(LI Garbage collected programs are faster to develop and debug, because
	there's no need for developing, debugging, testing, or maintaining the
	explicit deallocation code.
	)

	$(LI Garbage collected programs can be significantly smaller, because
	there is no code to manage deallocation, and there is no need for exception
	handlers to deallocate memory.
	)
	)

	$(P Garbage collection is not a panacea. There are some downsides:
	)

	$(UL 

	$(LI It is not predictable when a collection gets run, so the program
	can arbitrarily pause.
	)

	$(LI The time it takes for a collection to run is not bounded. While in
	practice it is very quick, this cannot be guaranteed.
	)

	$(LI All threads other than the collector thread must be halted while
	the collection is in progress.
	)

	$(LI Garbage collectors can keep around some memory that an explicit
	deallocator
	would not. In practice, this is not much of an issue since explicit
	deallocators usually have memory leaks causing them to eventually use
	far more memory, and because explicit deallocators do not normally
	return deallocated memory to the operating system anyway, instead just
	returning it to its own internal pool.
	)

	$(LI Garbage collection should be implemented as a basic operating
	system
	kernel service. But since they are not, garbage collecting programs must
	carry around with them the garbage collection implementation. While this
	can be a shared DLL, it is still there.
	)
	)

	$(P These constraints are addressed by techniques outlined
	in <a href="memory.html">Memory Management</a>.
	)

<h2>How Garbage Collection Works</h2>

	$(P The GC works by:)

	$(OL
	$(LI Looking for all the pointer 'roots' into GC allocated memory.)

	$(LI Recursively scanning all allocated memory pointed to by
	roots looking for more pointers into GC allocated memory.)

	$(LI Freeing all GC allocated memory that has no active pointers
	to it.)

	$(LI Possibly compacting the remaining used memory by copying the
	allocated objects (called a copying collector).)
	)

<h2>Interfacing Garbage Collected Objects With Foreign Code</h2>

	$(P The garbage collector looks for roots in:)
	$(OL
	$(LI its static data segment)
	$(LI the stacks and register contents of each thread)
	$(LI any roots added by std.gc.addRoot() or std.gc.addRange())
	)

	$(P If the only root of an object
	is held outside of this, then the collecter will miss it and free the
	memory.
	)

	$(P To avoid this from happening,)

	$(UL
	$(LI Maintain a root to the object in an area the collector does scan
	for roots.)

	$(LI Add a root to the object using std.gc.addRoot() or std.gc.addRange().)

	$(LI Reallocate and copy the object using the foreign code's storage
	allocator
	or using the C runtime library's malloc/free.
	)
	)

<h2>Pointers and the Garbage Collector</h2>

	$(P Pointers in D can be broadly divided into two categories: those that
	point to garbage collected memory, and those that do not. Examples
	of the latter are pointers created by calls to C's malloc(), pointers
	received from C library routines, pointers to static data,
	pointers to objects on the stack, etc. For those pointers, anything
	that is legal in C can be done with them.
	)

	$(P For garbage collected pointers and references, however, there are
	some
	restrictions. These restrictions are minor, but they are intended
	to enable the maximum flexibility in garbage collector design.
	)

	$(P Undefined behavior:)

	$(UL

	$(LI Do not xor pointers with other values, like the
	xor pointer linked list trick used in C.
	)

	$(LI Do not use the xor trick to swap two pointer values.
	)

	$(LI Do not store pointers into non-pointer variables using casts and
	other tricks.

------
void* p;
...
int x = cast(int)p;   // error: undefined behavior
------

	The garbage collector does not scan non-pointer types for roots.
	)

	$(LI Do not take advantage of alignment of pointers to store bit flags
	in the low order bits:

------
p = cast(void*)(cast(int)p | 1);  // error: undefined behavior
------
	)

	$(LI Do not store into pointers values that may point into the
	garbage collected heap:

------
p = cast(void*)12345678;   // error: undefined behavior
------

	A copying garbage collector may change this value.
	)

	$(LI Do not store magic values into pointers, other than $(TT null).
	)

	$(LI Do not write pointer values out to disk and read them back in
	again.
	)

	$(LI Do not use pointer values to compute a hash function. A copying
	garbage collector can arbitrarily move objects around in memory,
	thus invalidating
	the computed hash value.
	)

	$(LI Do not depend on the ordering of pointers:

------
if (p1 < p2)		// error: undefined behavior
    ...
------
	since, again, the garbage collector can move objects around in
	memory.
	)

	$(LI Do not add or subtract an offset to a pointer such that the result
	points outside of the bounds of the garbage collected object originally
	allocated.

------
char* p = new char[10];
char* q = p + 6;	// ok
q = p + 11;		// error: undefined behavior
q = p - 1;		// error: undefined behavior
------
	)

	$(LI Do not misalign pointers if those pointers may
	point into the gc heap, such as:

------
align (1) struct Foo
{   byte b;
    char* p;	// misaligned pointer
}
------

	Misaligned pointers may be used if the underlying hardware
	supports them $(B and) the pointer is never used to point
	into the gc heap.
	)

	$(LI Do not use byte-by-byte memory copies to copy pointer values.
	This may result in intermediate conditions where there is
	not a valid pointer, and if the gc pauses the thread in such a
	condition, it can corrupt memory.
	Most implementations of $(TT memcpy()) will work since the
	internal implementation of it does the copy in aligned chunks
	greater than or equal to a pointer size, but since this kind of
	implementation is not guaranteed by the C standard, use
	$(TT memcpy()) only with extreme caution.
	)
	)

	$(P Things that are reliable and can be done:)

	$(UL

	$(LI Use a union to share storage with a pointer:

------
union U { void* ptr; int value }
------
	)

	$(LI A pointer to the start of a garbage collected object need not
	be maintained if a pointer to the interior of the object exists.

------
char[] p = new char[10];
char[] q = p[3..6];
// q is enough to hold on to the object, don't need to keep
// p as well.
------
	)
	)

	$(P One can avoid using pointers anyway for most tasks. D provides
	features
	rendering most explicit pointer uses obsolete, such as reference
	objects,
	dynamic arrays, and garbage collection. Pointers
	are provided in order to interface successfully with C APIs and for
	some low level work.
	)

<h2>Working with the Garbage Collector</h2>

	$(P Garbage collection doesn't solve every memory deallocation problem.
	For
	example, if a root to a large data structure is kept, the garbage
	collector cannot reclaim it, even if it is never referred to again. To
	eliminate this problem, it is good practice to set a reference or
	pointer to an object to null when no longer needed.
	)

	$(P This advice applies only to static references or references embedded
	inside other objects. There is not much point for such stored on the
	stack to be nulled, since the collector doesn't scan for roots past the
	top of the stack, and because new stack frames are initialized anyway.
	)

<h2>References</h2>

	$(UL
	$(LI $(LINK2 http://en.wikipedia.org/wiki/Garbage_collection_%28computer_science%29, Wikipedia))
	$(LI $(LINK2 http://www.iecc.com/gclist/GC-faq.html, GC FAQ))
	$(LI $(LINK2 ftp://ftp.cs.utexas.edu/pub/garbage/gcsurvey.ps, Uniprocessor Garbage Collector Techniques))
	$(LI $(LINK2 http://www.amazon.com/exec/obidos/ASIN/0471941484/classicempire,
	Garbage Collection : Algorithms for Automatic Dynamic Memory Management))
	)

)

Macros:
	TITLE=Garbage Collection
	WIKI=Garbage

