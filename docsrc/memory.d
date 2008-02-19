Ddoc

$(D_S Memory Management,

	$(P Any non-trivial program needs to allocate and free memory.
	Memory management techniques become more and more important as
	programs increase in complexity, size, and performance.
	D offers many options for managing memory.
	)

	$(P The three primary methods for allocating memory in D are:)

	$(OL
	$(LI Static data, allocated in the default data segment.)
	$(LI Stack data, allocated on the CPU program stack.)
	$(LI $(LINK2 garbage.html, Garbage collected data),
	allocated dynamically on the
	garbage collection heap.)
	)

	$(P The techniques for using them, as well
	as some advanced alternatives are:
	)

	$(UL
	$(LI $(LINK2 #copy-on-write, Strings (and Array) Copy-on-Write))
	$(LI <a href="#realtime">Real Time</a>)
	$(LI <a href="#smoothoperation">Smooth Operation</a>)
	$(LI <a href="#freelists">Free Lists</a>)
	$(LI <a href="#referencecounting">Reference Counting</a>)
	$(LI <a href="#newdelete">Explicit Class Instance Allocation</a>)
	$(LI <a href="#markrelease">Mark/Release</a>)
	$(LI <a href="#raii">RAII (Resource Acquisition Is Initialization)</a>)
	$(LI <a href="#stackclass">Allocating Class Instances On The Stack</a>)
	$(LI <a href="#uninitializedarrays">Allocating Uninitialized Arrays On The Stack</a>)
	$(LI $(LINK2 #isr, Interrupt Service Routines))
	)

<h2>$(LNAME2 copy-on-write, Strings (and Array) Copy-on-Write)</h2>

	$(P Consider the case of passing an array to a function, possibly
	modifying the contents of the array, and returning the modified
	array. Since arrays are passed by reference, not by value,
	a crucial issue is who owns the contents of the array?
	For example, a function to convert an array of characters to
	upper case:
	)

------
char[] toupper(char[] s)
{
    int i;

    for (i = 0; i < s.length; i++)
    {
	char c = s[i];
	if ('a' <= c && c <= 'z')
	    s[i] = c - (cast(char)'a' - 'A');
    }
    return s;
}
------

	$(P Note that the caller's version of s[] is also modified. This may
	be not at all what was intended, or worse, s[] may be a slice
	into a read-only section of memory.
	)

	$(P If a copy of s[] was always made by toupper(), then that will
	unnecessarily consume time and memory for strings that are already
	all upper case.
	)

	$(P The solution is to implement copy-on-write, which means that a copy
	is made only if the string needs to be modified. Some string
	processing languages do do this as the default behavior, but there
	is a huge cost to it. The string "abcdeF" will wind up being copied 5
	times by the function. To get the maximum efficiency using the protocol,
	it'll have to be done explicitly in the code. Here's toupper()
	rewritten to implement copy-on-write in an efficient manner:
	)

------
char[] toupper(char[] s)
{
    int changed;
    int i;

    changed = 0;
    for (i = 0; i < s.length; i++)
    {
	char c = s[i];
	if ('a' <= c && c <= 'z')
	{
	    if (!changed)
	    {   char[] r = new char[s.length];
		r[] = s;
		s = r;
		changed = 1;
	    }
	    s[i] = c - (cast(char)'a' - 'A');
	}
    }
    return s;
}
------

	$(P Copy-on-write is the protocol implemented by array processing
	functions in the D Phobos runtime library.
	)

<h2><a name="realtime">Real Time</a></h2>

	$(P Real time programming means that a program must be able to
	guarantee a maximum latency, or time to complete an operation.
	With most memory allocation schemes, including malloc/free and
	garbage collection, the latency is theoretically not bound.
	The most reliable way to guarantee latency is to preallocate
	all data that will be needed by the time critical portion.
	If no calls to allocate memory are done, the GC will not run
	and so will not cause the maximum latency to be exceeded.
	)

<h2><a name="smoothoperation">Smooth Operation</a></h2>

	$(P Related to real time programming is the need for a program to
	operate smoothly, without arbitrary pauses while the garbage
	collector stops everything to run a collection.
	An example of such a program would be an interactive shooter
	type game. Having the game play pause erratically, while not
	fatal to the program, can be annoying to the user.
	)

	$(P There are several techniques to eliminate or mitigate the effect:)

$(UL
	$(LI Preallocate all data needed before the part of the code
	that needs to be smooth is run.)

	$(LI Manually run a GC collection cycle at points in program
	execution where it is already paused. An example of such a place
	would be where the program has just displayed a prompt for user
	input and the user has not responded yet.
	This reduces the odds that a collection cycle will be needed
	during the smooth code.)

	$(LI Call std.gc.disable() before the smooth code is run, and
	std.gc.enable() afterwards. This will cause the GC to favor allocating
	more memory instead of running a collection pass.)
)

<h2><a name="freelists">Free Lists</a></h2>

	$(P Free lists are a great way to accelerate access to a frequently
	allocated and discarded type. The idea is simple - instead of
	deallocating an object when done with it, put it on a free list.
	When allocating, pull one off the free list first.
	)
------
class Foo
{
    static Foo freelist;		// start of free list

    static Foo allocate()
    {   Foo f;

	if (freelist)
	{   f = freelist;
	    freelist = f.next;
	}
	else
	    f = new Foo();
	return f;
    }

    static void deallocate(Foo f)
    {
	f.next = freelist;
	freelist = f;
    }

    Foo next;		// for use by FooFreeList
    ...
}

void test()
{
    Foo f = Foo.allocate();
    ...
    Foo.deallocate(f);
}
------

	Such free list approaches can be very high performance.

	$(UL 
	$(LI If used by multiple threads, the allocate() and
	deallocate() functions need to be synchronized.)

	$(LI The Foo constructor is not re-run by allocate() when
	allocating from the free list, so the allocator may need
	to reinitialize some of the members.)

	$(LI It is not necessary to practice RAII with this, since
	if any objects are not passed to deallocate() when done, because
	of a thrown exception, they'll eventually get picked up by
	the GC anyway.)
	)

<h2><a name="referencecounting">Reference Counting</a></h2>

	$(P The idea behind reference counting is to include a count
	field in the object. Increment it for each additional reference
	to it, and decrement it whenever a reference to it ceases.
	When the count hits 0, the object can be deleted.
	)

	$(P D doesn't provide any automated support for reference counting,
	it will have to be done explicitly.
	)

	$(P <a href="windows.html#com">Win32 COM programming</a>
	uses the members AddRef() and Release()
	to maintain the reference counts.
	)

<h2><a name="newdelete">Explicit Class Instance Allocation</a></h2>

	$(P D provides a means of creating custom allocators and deallocators
	for class instances. Normally, these would be allocated on the
	garbage collected heap, and deallocated when the collector decides
	to run. For specialized purposes, this can be handled by
	creating $(I NewDeclaration)s and $(I DeleteDeclaration)s.
	For example, to allocate using the C runtime library's
	$(TT malloc) and $(TT free):
	)

------
import std.c.stdlib;
import std.outofmemory;
import std.gc;

class Foo
{
    new(size_t sz)
    {
	void* p;

	p = std.c.stdlib.malloc(sz);
	if (!p)
	    throw new OutOfMemoryException();
	std.gc.addRange(p, p + sz);
	return p;
    }

    delete(void* p)
    {
	if (p)
	{   std.gc.removeRange(p);
	    std.c.stdlib.free(p);
	}
    }
}
------

	$(P The critical features of new() are:)

	$(UL 
	$(LI new() does not have a return type specified,
	but it is defined to be void*. new() must return
	a void*.)

	$(LI If new() cannot allocate memory, it must
	not return null, but must throw an exception.)

	$(LI The pointer returned from new() must be to memory
	aligned to the default alignment. This is 8 on win32
	systems.)

	$(LI The $(I size) parameter is needed in case the
	allocator is called from a class derived from Foo and is
	a larger size than Foo.)

	$(LI A null is not returned if storage cannot be allocated.
	Instead, an exception is thrown. Which exception gets thrown
	is up to the programmer, in this case, OutOfMemory() is.)

	$(LI When scanning memory for root pointers into the garbage
	collected heap, the static data segment and the stack are
	scanned automatically. The C heap is not. Therefore, if Foo
	or any class derived from Foo using the allocator contains
	any references to data allocated by the garbage collector, the
	GC needs to be notified. This is done with the std.gc.addRange()
	method.)

	$(LI No initialization of the memory is necessary, as code
	is automatically inserted after the call to new() to set the
	class instance members to their defaults and then the constructor
	(if any) is run.)
	)

	The critical features of delete() are:

	$(UL 
	$(LI The destructor (if any) has already been called on the
	argument p, so the data it points to should be assumed to
	be garbage.)

	$(LI The pointer p may be null.)

	$(LI If the GC was notified with std.gc.addRange(), a corresponding
	call to std.gc.removeRange() must happen in the deallocator.)

	$(LI If there is a delete(), there should be a corresponding new().)
	)

	$(P If memory is allocated using class specific allocators and deallocators,
	careful coding practices must be followed to avoid memory leaks
	and dangling references. In the presence of exceptions, it is
	particularly important to practice RAII to prevent memory leaks.
	)

	$(P Custom allocators and deallocators can be done for structs
	and unions, too.)

<h2><a name="markrelease">Mark/Release</a></h2>

	$(P Mark/Release is equivalent to a stack method of allocating and
	freeing memory. A 'stack' is created in memory. Objects are allocated
	by simply moving a pointer down the stack. Various points are
	'marked', and then whole sections of memory are released
	simply by resetting the stack pointer back to a marked point.
	)

------
import std.c.stdlib;
import std.outofmemory;

class Foo
{
    static void[] buffer;
    static int bufindex;
    static const int bufsize = 100;

    static this()
    {   void *p;

	p = malloc(bufsize);
	if (!p)
	    throw new OutOfMemoryException;
	std.gc.addRange(p, p + bufsize);
	buffer = p[0 .. bufsize];
    }

    static ~this()
    {
	if (buffer.length)
	{
	    std.gc.removeRange(buffer);
	    free(buffer);
	    buffer = null;
	}
    }

    new(size_t sz)
    {   void *p;

	p = &buffer[bufindex];
	bufindex += sz;
	if (bufindex > buffer.length)
	    throw new OutOfMemory;
	return p;
    }

    delete(void* p)
    {
	assert(0);
    }

    static int mark()
    {
	return bufindex;
    }

    static void release(int i)
    {
	bufindex = i;
    }
}

void test()
{
    int m = Foo.mark();
    Foo f1 = new Foo;		// allocate
    Foo f2 = new Foo;		// allocate
    ...
    Foo.release(m);		// deallocate f1 and f2
}
------

	$(P The allocation of buffer[] itself is added as
	a region to the GC, so there is no need for a separate
	call inside Foo.new() to do it.)

<h2><a name="raii">RAII (Resource Acquisition Is Initialization)</a></h2>

	$(P RAII techniques can be useful in avoiding memory leaks
	when using explicit allocators and deallocators.
	Adding the <a href="attribute.html#scope">scope attribute</a>
	to such classes can help.
	)

<h2><a name="stackclass">Allocating Class Instances On The Stack</a></h2>

	$(P Class instances are normally allocated on the garbage
	collected heap. However, if they:)

	$(UL
	$(LI are allocated as local symbols in a function)
	$(LI are allocated using $(B new))
	$(LI use $(B new) with no arguments)
	$(LI have the $(B scope) storage class)
	)

	$(P then they are allocated on the stack. This is more efficient
	than doing an allocate/free cycle on the instance. But be
	careful that any reference to the object does not survive
	the return of the function.)

---
class C { ... }

scope c = new C();	// c is allocated on the stack
---

	$(P If the class has a destructor, then that destructor is
	guaranteed to be run when the class object goes out of scope,
	even if the scope is exited via an exception.)


<h2><a name="uninitializedarrays">Allocating Uninitialized Arrays On The Stack</a></h2>

	$(P Arrays are always initialized in D. So, the following declaration:)

------
void foo()
{   byte[1024] buffer;

    fillBuffer(buffer);
    ...
}
------

	$(P will not be as fast as it might be since the buffer[] contents
	are always initialized. If careful profiling of the program shows
	that this initialization is a speed problem, it can be eliminated using
	a $(I VoidInitializer):
	)

------
void foo()
{   byte[1024] buffer = $(B void);

    fillBuffer(buffer);
    ...
}
------

	$(P Uninitialized data on the stack comes with some caveats that need
	to be carefully evaluated before using:
	)

	$(UL 

	$(LI The uninitialized data that is on the stack will get scanned by the
	garbage collector looking for any references to allocated memory. Since
	the uninitialized data consists of old D stack frames, it is highly
	likely that some of that garbage will look like references into the GC
	heap, and the GC memory will not get freed. This problem really does
	happen, and can be pretty frustrating to track down.)

	$(LI It's possible for a function to pass out of it a reference to data
	on that function's stack frame. By then allocating a new stack frame
	over the old data, and not initializing, the reference to the old data
	may still appear to be valid. The program will then behave erratically.
	Initializing all data on the stack frame will greatly increase the
	probability of forcing that bug into the open in a repeatable manner.)

	$(LI Uninitialized data can be a source of bugs and trouble, even when
	used correctly. One design goal of D is to improve reliability and
	portability by eliminating sources of undefined behavior, and
	uninitialized data is one huge source of undefined, unportable, erratic
	and unpredictable behavior. Hence this idiom should only be used after
	other opportunities for speed optimization are exhausted and if
	benchmarking shows that it really does speed up the overall execution.)

	)

<h2><a name="isr">Interrupt Service Routines</a></h2>

	$(P When the garbage collector does a collection pass, it must
	pause all running threads in order to scan their stacks and register
	contents for references to GC allocated objects.
	If an ISR (Interrupt Service Routine) thread is paused,
	this can break the program.
	)

	$(P Therefore, the ISR thread should not be paused.
	Threads created with the $(LINK2 phobos/std_thread.html, std.thread)
	functions will be paused. But threads created with C's
	$(TT _beginthread()) or equivalent won't be, the GC
	won't know they exist.
	)

	$(P For this to work successfully:)

	$(UL

	$(LI The ISR thread cannot allocate any memory using the GC.
	This means that the global $(TT new) cannot be used.
	Nor can dynamic arrays be resized, nor can any elements be
	added to associative arrays. Any use of the D runtime library
	should be examined for any possibility of allocating GC memory -
	or better yet, the ISR should not call any D runtime library
	functions at all.)

	$(LI The ISR cannot hold the sole reference to any GC allocated
	memory, otherwise the GC may free the memory while the ISR
	is still using it. The solution is to have one of the paused
	threads hold a reference to it too, or store a reference to
	it in global data.)

	)
)

Macros:
	TITLE=Memory Management
	WIKI=Memory

