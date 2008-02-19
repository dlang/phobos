Ddoc

$(D_S Glossary,

$(DL
  $(DT $(LNAME2 ctfe, $(ACRONYM CTFE, Compile Time Function Evaluation)))
  $(DD Refers to the ability to execute regular D
    functions at compile time rather than at run time.)
  
  $(DT $(LNAME2 cow, $(ACRONYM COW, Copy On Write)))
  $(DD COW is a memory allocation strategy where arrays are copied
    if they are to be modified.
      )

  $(DT $(LNAME2 functor, Functor)) $(DD An user-defined type (struct or class) that defines the function call operator ($(DC opCall) in D) and as such can be used similarly to a function.)
  
  $(DT $(LNAME2 gc, $(ACRONYM GC, Garbage Collection)))
  $(DD Garbage collection is the common name for the
    term automatic memory management. Memory can be allocated and used,
    and the GC will automatically free any chunks of memory no longer
    referred to. In contrast, explicit memory management
    is where the programmer must carefully match up each allocation with
    one and only one free.
      )
  
  $(DT Higher-order function) $(DD A function that either accepts another function as a parameter, returns a function, or both.
      )
  
  $(DT Illegal)
  $(DD A code construct is illegal if it does not conform to the
    D language specification.
    This may be true even if the compiler or runtime fails to detect
    the error.
      )
  
	$(DT Implementation Defined Behavior)
	$(DD This is variation in behavior of the D language in a manner
	that is up to the implementor of the language.
	An example of implementation defined behavior would be the size in
	bytes of a pointer: on a 32 bit machine it would be 4 bytes, on
	a 64 bit machine it would be 8 bytes.
	Minimizing implementation defined behavior in the language will
	maximize the portability of code.
	)

	$(DT $(LNAME2 nrvo, $(ACRONYM NRVO, Named Return Value Optimization)))
	$(DD
	$(P NRVO is a technique invented by Walter Bright around
	1991 (the term for it was coined later) to minimize copying of struct
	data.
	Functions normally return their function return values in
	registers. For structs, however, they often are too big to
	fit in registers. The usual solution to this is to pass to
	the function a $(I hidden pointer) to a struct instance in the
	caller's stack frame, and the return value is copied there.
	For example:
	)
---
struct S { int a, b, c, d; }

S foo()
{
    S result;
    result.a = 3;
    return result;
}

void test()
{
    S s = foo();
}
---

	$(P is rewritten as:)

---
S* foo(S* hidden)
{
    S result;
    result.a = 3;
    *hidden = result;
    return hidden;
}

void test()
{
    S tmp;
    S s = *foo(&tmp);
}
---
	$(P This rewrite gives us an extra temporaty object $(TT tmp),
	and copies the struct contents twice.
	What NRVO does is recognize that the sole purpose of $(TT result)
	is to provide a return value, and so all references to $(TT result)
	can be replaced with $(TT *hidden).
	$(TT foo) is then rewritten as:
	)
---
S* foo(S* hidden)
{
    hidden.a = 3;
    return hidden;
}
---
	$(P A further optimization is done on the call to $(TT foo) to eliminate
	the other copy, giving:)
---
void test()
{
    S s;
    foo(&s);
}
---
	$(P The result is written directly into the destination $(TT s),
	instead of passing through two other instances.)
	)

	$(DT $(LNAME2 predicate, Predicate)) $(DD A function or
	delegate returning a Boolean result. Predicates can be nullary
	(take no arguments), unary (take one argument), binary (take
	two arguments), or n-ary (take n arguments). Usually
	predicates are mentioned within the context of higher-order
	functions, which accept predicates as parameters.)

	$(DT $(LNAME2 pod, $(ACRONYM POD, Plain Old Data)))
	$(DD Refers to a struct that contains no hidden members,
	does not have virtual functions, does not inherit,
	has no destructor,
	and can be initialized and copied via simple bit copies.
	D structs are POD.
	)

	$(DT $(LNAME2 raii, $(ACRONYM RAII, Resource Acquisition Is Initialization)))
	$(DD RAII refers to the technique of having the destructor
	of a class object called when the object goes out of scope.
	The destructor then releases any resources acquired by
	that object.
	RAII is commonly used for resources that are in short supply
	or that must have a predictable point when they are released.
	RAII objects in D are created using the $(TT scope) storage class.
	)

	$(DT $(LNAME2 sfinae, $(ACRONYM SFINAE, Substitution Failure Is Not An Error)))
	$(DD If template argument deduction results in a type
	that is not valid, that specialization of the template
	is not considered further. It is not a compile error.
	See also $(LINK2 http://www.semantics.org/once_weakly/w02_SFINAE.pdf, SFINAE).
	)

	$(DT $(LNAME2 tmp, $(ACRONYM TMP, Template Metaprogramming)))
	$(DD TMP is using the template features of the language to
	execute programs at compile time rather than runtime.)

	$(DT $(ACRONYM UB, Undefined Behavior))
	$(DD Undefined behavior happens when an illegal code construct is
	executed. Undefined behavior can include random, erratic results,
	crashes, faulting, etc.
	)

)

)

Macros:
	TITLE=Glossary
	WIKI=Glossary

