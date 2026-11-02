/**
 * The atomic module provides atomic struct support for lock-free
 * concurrent programming.
 *
 * Copyright: Copyright Roy David Margalit 2022 - 2025.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Roy David Margalit
 * Source:    $(DRUNTIMESRC core/_atomic.d)
 */
module std.atomic;

/** Atomic data like std::atomic

  Params:
	T	= Integral type or pointer for atomic operations

  Example:
  -------------------------
	__gshared Atomic!int a;
	assert(a == 0);
	assert(a++ == 0)
	assert(a == 1);
  -------------------------

*/
struct Atomic(T)
if (__traits(isIntegral, T) || isPointer!T)
{
	import core.atomic : atomicLoad, atomicStore, atomicExchange, atomicFetchAdd,
		atomicFetchSub, atomicCas = cas, atomicCasWeak = casWeak, atomicOp;

	private T val;

	/// Constructor
	this(T init) shared
	{
		val.atomicStore(init);
	}

	private shared(T)* ptr() shared
	{
		return &val;
	}

	/** Load the value from the atomic location with SC access
	  Params:
		mo     = Memory order

	  Returns: The stored value
	*/
	T load(MemoryOrder mo = MemoryOrder.seq)() shared
	{
		return val.atomicLoad!(mo.toCore);
	}

	/// ditto
	alias load this;


	/** Store the value to the atomic location
	  Params:
		mo     = Memory order
		newVal = Value to store to atomic
	*/
	void store(MemoryOrder mo = MemoryOrder.seq)(T newVal) shared
	{
		return val.atomicStore!(mo.toCore)(newVal);
	}

	/// Store using SC access
	alias opAssign = store;

	/** Atomically increment the value
	  Params:
		mo     = Memory order
		mod    = Value to add to atomic

	  Returns: The old stored value
	*/
	T fadd(MemoryOrder mo = MemoryOrder.seq)(T mod) shared
	{
		return atomicFetchAdd!(mo.toCore)(val, mod);
	}

	/** Atomically decrement the value
	  Params:
		mo     = Memory order
		mod    = Value to decrement from atomic

	  Returns: The old stored value
	*/
	T fsub(MemoryOrder mo = MemoryOrder.seq)(T mod) shared
	{
		return atomicFetchSub!(mo.toCore)(val, mod);
	}

	/** Atomically swap the value
	  Params:
		mo     = Memory order
		desired = New value to store

	  Returns: The old stored value
	*/
	T exchange(MemoryOrder mo = MemoryOrder.seq)(T desired) shared
	{
		return atomicExchange!(mo.toCore)(&val, desired);
	}

	/** Compare and swap
	  Params:
		mo     = Memory order on success
		fmo    = Memory order on failure
		oldVal = Expected value to preform the swap
		newVal = New value to store if condition holds

	  Returns: If the value was swapped
	*/
	bool cas(MemoryOrder mo = MemoryOrder.seq, MemoryOrder fmo = MemoryOrder.seq)(T oldVal, T newVal) shared
	{
		return atomicCas!(mo.toCore, fmo.toCore)(ptr, oldVal, newVal);
	}

	/** Compare and swap (May fail even if current value is equal to oldVal)
	  Params:
		mo     = Memory order on success
		fmo    = Memory order on failure
		oldVal = Expected value to preform the swap
		newVal = New value to store if condition holds

	  Returns: If the value was swapped
	*/
	bool casWeak(MemoryOrder mo = MemoryOrder.seq, MemoryOrder fmo = MemoryOrder.seq)(T oldVal,
			T newVal) shared
	{
		return atomicCasWeak!(mo.toCore, fmo.toCore)(ptr, oldVal, newVal);
	}

	/** Op assign with SC semantics
	  Params:
		op = Assignment operator
		rhs = Value to assign

	  Returns: Computation result
	*/
	T opOpAssign(string op)(T rhs) shared
	{
		return val.atomicOp!(op ~ `=`)(rhs);
	}

	/** Implicit conversion to FADD with SC access
	  Params:
		op = ++

	  Returns: Pre-incremented value
	*/
	T opUnary(string op)() shared if (op == `++`)
	{
		return fadd(1);
	}

	/** Implicit conversion to FSUB with SC access
	  Params:
		op = --

	  Returns: Pre-decremented value
	*/
	T opUnary(string op)() shared if (op == `--`)
	{
		return fsub(1);
	}

	/** Dereference atomic pointer with SC access
	  Params:
		op = *

	  Returns: Reference to the pointed location
	*/
	auto ref opUnary(string op)() shared if (op == `*`)
	{
		return *(load);
	}
}

static import core.atomic;
/**
 * Specifies the memory ordering semantics of an atomic operation.
 *
 * See_Also:
 *     $(HTTP en.cppreference.com/w/cpp/atomic/memory_order)
 */
enum MemoryOrder
{
	/**
	 * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#monotonic, LLVM AtomicOrdering.Monotonic)
	 * and C++11/C11 `memory_order_relaxed`.
	 */
	rlx = cast(int) core.atomic.MemoryOrder.raw,
	/**
	 * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#acquire, LLVM AtomicOrdering.Acquire)
	 * and C++11/C11 `memory_order_acquire`.
	 */
	acq = cast(int) core.atomic.MemoryOrder.acq,
	/**
	 * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#release, LLVM AtomicOrdering.Release)
	 * and C++11/C11 `memory_order_release`.
	 */
	rel = cast(int) core.atomic.MemoryOrder.rel,
	/**
	 * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#acquirerelease, LLVM AtomicOrdering.AcquireRelease)
	 * and C++11/C11 `memory_order_acq_rel`.
	 */
	acq_rel = cast(int) core.atomic.MemoryOrder.acq_rel,
	/**
	 * Corresponds to $(LINK2 https://llvm.org/docs/Atomics.html#sequentiallyconsistent, LLVM AtomicOrdering.SequentiallyConsistent)
	 * and C++11/C11 `memory_order_seq_cst`.
	 */
	seq = cast(int) core.atomic.MemoryOrder.seq,
}

private auto toCore(MemoryOrder mo)
{
	static import core.atomic;
	return cast(core.atomic.MemoryOrder) mo;
}

@safe unittest
{
	shared Atomic!int a;
	assert(a == 0);
	assert(a.load == 0);
	assert(a.fadd!(MemoryOrder.rlx)(5) == 0);
	assert(a.load!(MemoryOrder.acq) == 5);
	assert(!a.casWeak(4, 5));
	assert(!a.cas(4, 5));
	assert(a.cas!(MemoryOrder.rel, MemoryOrder.acq)(5, 4));
	assert(a.fsub!(MemoryOrder.acq_rel)(2) == 4);
	assert(a.exchange!(MemoryOrder.acq_rel)(3) == 2);
	assert(a.load!(MemoryOrder.rlx) == 3);
	a.store!(MemoryOrder.rel)(7);
	assert(a.load == 7);
	a = 32;
	assert(a == 32);
	a += 5;
	assert(a == 37);
	assert(a++ == 37);
	assert(a == 38);
}

// static array of shared atomics
@safe unittest
{
	static shared(Atomic!int)[5] arr;
	arr[4] = 4;
	assert(arr[4].load == 4);
}

@system unittest
{
	import core.thread : Thread;

	shared(Atomic!int)[2] arr;

	void reltest() @safe
	{
		arr[0].store!(MemoryOrder.rel)(1);
		arr[1].store!(MemoryOrder.rel)(1);
	}

	void acqtest() @safe
	{
		while (arr[1].load!(MemoryOrder.acq) != 1) { }
		assert(arr[0].load!(MemoryOrder.acq) == 1);
	}

	auto t1 = new Thread(&acqtest);
	auto t2 = new Thread(&reltest);
	t2.start;
	t1.start;
	t2.join;
	t1.join;
}

@safe unittest
{
	shared Atomic!(shared(int)) a = 5;
	assert(a.load == shared(int)(5));
	a = 2;
	assert(a == 2);
}

@safe unittest
{
	shared Atomic!(shared(int)*) ptr = new shared(int);
	*ptr.load!(MemoryOrder.rlx)() = 5;
	assert(*ptr.load == 5);
	*(ptr.load) = 42;
	assert(*ptr.load == 42);
}

@safe unittest
{
	shared Atomic!(shared(int)*) ptr = new shared(int);
	*ptr = 5;
	assert(*ptr == 5);
	*ptr = 42;
	assert(*ptr == 42);
}

@safe unittest
{
	//shared Atomic!(shared(Atomic!(int))*) ptr = new shared(Atomic!int);
}

private enum bool isAggregateType(T) = is(T == struct) || is(T == union)
	|| is(T == class) || is(T == interface);
private enum bool isPointer(T) = is(T == U*, U) && !isAggregateType!T;
